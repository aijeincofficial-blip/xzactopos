import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'sales_store_test.dart' show level, posPage;

const _loc = '0190a000-0000-7000-8000-0000000000e1';
const _other = '0190a000-0000-7000-8000-0000000000e2';
const _pGatas = '0190a000-0000-7000-8000-000000000001';
const _vGatas = '0190a000-0000-7000-8000-0000000000a1';
const _pTinapay = '0190a000-0000-7000-8000-000000000002';
const _vTinapay = '0190a000-0000-7000-8000-0000000000a2';
const _pItlog = '0190a000-0000-7000-8000-000000000003';
const _vItlog = '0190a000-0000-7000-8000-0000000000a3';
const _pKeso = '0190a000-0000-7000-8000-000000000004';
const _vKeso = '0190a000-0000-7000-8000-0000000000a4';

const _names = {_vGatas: 'Gatas', _vTinapay: 'Tinapay', _vItlog: 'Itlog', _vKeso: 'Keso'};
const _products = {_vGatas: _pGatas, _vTinapay: _pTinapay, _vItlog: _pItlog, _vKeso: _pKeso};

Map<String, dynamic> expiryRow(String variant, String? date, {String loc = _loc, String at = '2026-11-08T00:00:00+00:00'}) =>
    {'location_id': loc, 'variant_id': variant, 'expires_on': date, 'updated_at': at};

Map<String, dynamic> withExpiry(Map<String, dynamic> page, List<Map<String, dynamic>> rows) => {
      ...page,
      'stock_expiry': {'rows': rows, 'cursor': rows.isEmpty ? null : {'ts': '2026-11-08T00:00:00+00:00', 'k': 'x'}, 'has_more': false},
    };

SaleDraft sale(String id, String variant, int qty) => SaleDraft(
      id: id,
      soldAt: DateTime.now(),
      lines: [SaleLine(variantId: variant, name: _names[variant] ?? 'Item', qty: qty.toDouble(), unitPrice: 1000)],
      payments: [PaymentDraft('cash', qty * 1000)],
    );

/// Behaves like sync_push (receive_stock with the earlier-date rule, set_expiry, record_sale) and sync_pull_pos (stock levels
/// and the stock_expiry section, rows newer than 5 s held back). Once per op id; [refuse] refuses set_expiry.
class ExpiryServer implements SyncApi {
  var clock = DateTime.utc(2026, 11, 8, 1);
  final applied = <String, Map<String, dynamic>>{};
  final qty = <String, int>{};
  final levelAt = <String, DateTime>{};
  final expiry = <String, String?>{};
  final expiryAt = <String, DateTime>{};
  final pushed = <String>[];
  String? refuse;
  bool loseNextResponse = false;

  DateTime tick() => clock = clock.add(const Duration(seconds: 1));

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      final id = op['op_id'] as String;
      final kind = op['kind'] as String;
      final p = op['payload'] as Map<String, dynamic>;
      pushed.add(kind);
      if (applied.containsKey(id)) {
        out.add({'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': true}});
        continue;
      }
      if (kind == 'set_expiry' && refuse != null) {
        out.add({'op_id': id, 'status': 'rejected', 'code': '42501', 'hint': refuse});
        continue;
      }
      final now = tick();
      switch (kind) {
        case 'receive_stock':
          final v = p['variant_id'] as String;
          final before = qty[v] ?? 0;
          qty[v] = before + (p['qty'] as num).toInt();
          levelAt[v] = now;
          final d = p['expires_on'] as String?;
          if (d != null) {
            final old = expiry[v];
            expiry[v] = before > 0 && old != null && old.compareTo(d) < 0 ? old : d;
            expiryAt[v] = now; // a receipt with a date always moves updated_at
          }
        case 'set_expiry':
          final v = p['variant_id'] as String;
          if (expiry[v] != p['expires_on']) {
            expiry[v] = p['expires_on'] as String?;
            expiryAt[v] = now;
          }
        case 'record_sale':
          for (final i in (p['items'] as List).cast<Map<String, dynamic>>()) {
            final v = i['variant_id'] as String;
            qty[v] = (qty[v] ?? 0) - (i['qty'] as num).toInt();
            levelAt[v] = now;
          }
      }
      applied[id] = {'applied_at': now.toIso8601String()};
      out.add({'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': false}});
    }
    if (loseNextResponse) {
      loseNextResponse = false;
      throw Exception('connection lost');
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async {
    final now = tick();
    final upto = now.subtract(const Duration(seconds: 5));
    return {
      'server_time': now.toIso8601String(),
      'stock_levels': {
        'rows': [
          for (final v in qty.keys)
            if (!levelAt[v]!.isAfter(upto))
              {'location_id': _loc, 'variant_id': v, 'qty_on_hand': qty[v], 'avg_cost': null, 'counted': true,
               'updated_at': levelAt[v]!.toIso8601String()}
        ],
        'cursor': null,
        'has_more': false,
      },
      'customers': {'rows': [], 'cursor': null, 'has_more': false},
      'customer_ledger': {'rows': [], 'cursor': null, 'has_more': false},
      'stock_expiry': {
        'rows': [
          for (final v in expiry.keys)
            if (!expiryAt[v]!.isAfter(upto)) expiryRow(v, expiry[v], at: expiryAt[v]!.toIso8601String())
        ],
        'cursor': null,
        'has_more': false,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async => pullPage(
        products: [for (final v in _names.keys) serverProduct(_products[v]!, _names[v]!)],
        variants: [for (final v in _names.keys) serverVariant(v, _products[v]!)],
        prices: [for (final v in _names.keys) serverPrice(v, 1000)],
      );
  @override
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullExpenses(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullDayCloses(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload) async {}
  @override
  Future<void> archiveProduct(String opId, String productId) async {}
  @override
  Future<void> uploadPhoto(String path, Uint8List jpeg) async {}
  @override
  Future<Uint8List> downloadPhoto(String path) async => Uint8List(0);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;
  final today = dateOnly(DateTime.now());
  DateTime inDays(int n) => DateTime(today.year, today.month, today.day + n);

  Future<void> seed(DriftStore s) async {
    await s.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
    await s.applyPull(pullPage(
      products: [for (final v in _names.keys) serverProduct(_products[v]!, _names[v]!)],
      variants: [for (final v in _names.keys) serverVariant(v, _products[v]!)],
      prices: [for (final v in _names.keys) serverPrice(v, 1000)],
    ));
  }

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await seed(store);
  });
  tearDown(() => store.close());

  Future<StockRow> row(DriftStore s, String v) async =>
      (await s.watchStockList().first).firstWhere((r) => r.product.variantId == v);

  group('setting a date', () {
    test('shows on the stock row at once (date only) and queues one set_expiry op; clearing works the same', () async {
      await store.setExpiry(variantId: _vGatas, expiresOn: DateTime(today.year, today.month, today.day + 5, 18), opId: 'e1');
      final r = await row(store, _vGatas);
      expect((r.expiresOn, r.pending), (inDays(5), true));
      final op = (await store.nextOps()).single;
      expect((op.kind, op.entityId), ('set_expiry', _vGatas));
      expect(op.payload, {'variant_id': _vGatas, 'expires_on': dayKey(inDays(5)), 'location_id': _loc});

      await store.setExpiry(variantId: _vGatas, expiresOn: null, opId: 'e2');
      expect((await row(store, _vGatas)).expiresOn, isNull);
      expect((await store.nextOps()).last.payload, {'variant_id': _vGatas, 'expires_on': null, 'location_id': _loc});
    });

    test('dates outside 2000 .. 10 years and unknown products are refused before anything is written', () async {
      expect(() => store.setExpiry(variantId: _vGatas, expiresOn: DateTime(1999, 12, 31), opId: 'x1'), throwsArgumentError);
      expect(() => store.setExpiry(variantId: _vGatas, expiresOn: inDays(expiryMaxDaysAhead + 1), opId: 'x2'), throwsArgumentError);
      expect(() => store.receiveStock(variantId: _vGatas, qty: 1, expiresOn: DateTime(1990), opId: 'x3'), throwsArgumentError);
      await expectLater(store.setExpiry(variantId: 'nope', expiresOn: inDays(3), opId: 'x4'), throwsStateError);
      expect(await store.nextOps(), isEmpty);
      expect(await store.db.select(store.db.stockExpiry).get(), isEmpty);
      await store.setExpiry(variantId: _vGatas, expiresOn: DateTime(2000, 1, 1), opId: 'ok1');
      await store.setExpiry(variantId: _vGatas, expiresOn: inDays(-3), opId: 'ok2'); // already expired: allowed
      await store.setExpiry(variantId: _vGatas, expiresOn: inDays(expiryMaxDaysAhead), opId: 'ok3');
      expect((await store.nextOps()).map((o) => o.opId), ['ok1', 'ok2', 'ok3']);
    });
  });

  test('the row helpers: today is expiring soon, not expired; yesterday is expired; the window is inclusive', () {
    const p = ProductView(id: 'p', variantId: 'v', name: 'X', unit: 'pc', sku: 'X', currency: 'PHP', active: true, pending: false);
    StockRow r(DateTime? d) => StockRow(product: p, qty: 3, reorderPoint: 0, pending: false, expiresOn: d);
    final day = DateTime(2026, 11, 8, 15, 30); // the time of day does not matter
    final t = r(DateTime(2026, 11, 8));
    expect((t.expired(day), t.expiringSoon(day), t.daysLeft(day)), (false, true, 0));
    final y = r(DateTime(2026, 11, 7));
    expect((y.expired(day), y.expiringSoon(day), y.daysLeft(day)), (true, false, -1));
    expect(r(DateTime(2026, 11, 15)).expiringSoon(day), isTrue, reason: '7 days away');
    expect(r(DateTime(2026, 11, 16)).expiringSoon(day), isFalse, reason: '8 days away');
    expect(r(DateTime(2026, 11, 16)).expiringSoon(day, days: 8), isTrue);
    expect((r(null).expired(day), r(null).expiringSoon(day), r(null).daysLeft(day)), (false, false, null));
    expect(r(DateTime(2027, 3, 29)).daysLeft(DateTime(2027, 3, 27, 23)), 2, reason: 'calendar days, DST-proof');
  });

  group('stock in with a date (the earlier-date rule, as the server does it)', () {
    test('empty shelf: the new date; stock on hand: the earlier one; sold out: replaced', () async {
      await store.receiveStock(variantId: _vGatas, qty: 10, expiresOn: DateTime(2026, 12, 31), opId: 'r1');
      expect((await row(store, _vGatas)).expiresOn, DateTime(2026, 12, 31));
      await store.receiveStock(variantId: _vGatas, qty: 5, expiresOn: DateTime(2027, 3, 1), opId: 'r2');
      expect((await row(store, _vGatas)).expiresOn, DateTime(2026, 12, 31), reason: 'a later batch keeps the earlier date');
      await store.receiveStock(variantId: _vGatas, qty: 5, expiresOn: DateTime(2026, 12, 15), opId: 'r3');
      expect((await row(store, _vGatas)).expiresOn, DateTime(2026, 12, 15), reason: 'an earlier batch wins');
      await store.receiveStock(variantId: _vGatas, qty: 2, opId: 'r4');
      expect((await row(store, _vGatas)).expiresOn, DateTime(2026, 12, 15), reason: 'no date: left alone');
      await store.commitSale(sale('s1', _vGatas, 22), opId: 's1');
      await store.receiveStock(variantId: _vGatas, qty: 6, expiresOn: DateTime(2027, 6, 1), opId: 'r5');
      expect((await row(store, _vGatas)).expiresOn, DateTime(2027, 6, 1), reason: 'the shelf was empty: replaced');
      await store.setExpiry(variantId: _vGatas, expiresOn: null, opId: 'e1');
      await store.receiveStock(variantId: _vGatas, qty: 1, expiresOn: DateTime(2027, 9, 1), opId: 'r6');
      expect((await row(store, _vGatas)).expiresOn, DateTime(2027, 9, 1), reason: 'no date stored: taken');
      expect(await store.stockLeft(_vGatas), 7, reason: 'the quantities are as always');

      final ops = await store.nextOps();
      expect(ops.firstWhere((o) => o.opId == 'r2').payload,
          {'variant_id': _vGatas, 'qty': 5.0, 'location_id': _loc, 'expires_on': '2027-03-01'},
          reason: 'the batch date is sent as given; the server applies the rule itself');
      expect(ops.firstWhere((o) => o.opId == 'r4').payload.containsKey('expires_on'), isFalse);
    });
  });

  group('expiring list', () {
    test('only counted stock on hand, within the window or already past, soonest first', () async {
      final day = DateTime(2026, 11, 8);
      await store.applyPullPos(withExpiry(
        posPage(levels: [
          level(_vGatas, 4, '2026-11-08T00:00:00+00:00'),
          level(_vTinapay, 2, '2026-11-08T00:00:00+00:00'),
          level(_vItlog, 0, '2026-11-08T00:00:00+00:00'),
          level(_vKeso, 6, '2026-11-08T00:00:00+00:00'),
        ]),
        [
          expiryRow(_vGatas, '2026-11-08'), // today: expiring soon
          expiryRow(_vTinapay, '2026-11-05'), // already expired: listed first
          expiryRow(_vItlog, '2026-11-09'), // none left: not listed
          expiryRow(_vKeso, '2026-11-20'), // 12 days away: outside the 7-day window
        ],
      ));
      final list = await store.watchExpiring(today: day).first;
      expect(list.map((r) => r.product.name), ['Tinapay', 'Gatas']);
      expect(list.map((r) => (r.expired(day), r.daysLeft(day))), [(true, -3), (false, 0)]);
      expect(await store.expiringCount(today: day), 2);
      expect((await store.watchExpiring(withinDays: 14, today: day).first).map((r) => r.product.name),
          ['Tinapay', 'Gatas', 'Keso']);

      await store.commitSale(sale('s1', _vTinapay, 2), opId: 's1');
      expect((await store.watchExpiring(today: day).first).map((r) => r.product.name), ['Gatas'],
          reason: 'sold out: off the list at once');
      await store.receiveStock(variantId: _vItlog, qty: 12, opId: 'r1');
      expect((await store.watchExpiring(today: day).first).map((r) => r.product.name), ['Gatas', 'Itlog'],
          reason: 'back in stock, still carrying its date');
    });

    test('a product nobody counted is left out even with a date', () async {
      await store.commitSale(sale('s1', _vKeso, 1), opId: 's1'); // sales alone do not count it
      await store.setExpiry(variantId: _vKeso, expiresOn: inDays(1), opId: 'e1');
      expect(await store.expiringCount(), 0);
    });
  });

  group('pull', () {
    test('this store\'s dates arrive; other stores are skipped; an unsent op keeps the local date; null clears', () async {
      await store.applyPullPos(withExpiry(posPage(), [
        expiryRow(_vGatas, '2026-12-01'),
        expiryRow(_vTinapay, '2026-11-30', loc: _other),
      ]));
      expect((await row(store, _vGatas)).expiresOn, DateTime(2026, 12, 1));
      expect((await row(store, _vTinapay)).expiresOn, isNull, reason: 'another store');
      expect((await store.cursors()).keys, contains('stock_expiry'));

      await store.setExpiry(variantId: _vGatas, expiresOn: DateTime(2026, 11, 25), opId: 'e1');
      await store.applyPullPos(withExpiry(posPage(), [expiryRow(_vGatas, '2026-12-01')]));
      expect((await row(store, _vGatas)).expiresOn, DateTime(2026, 11, 25), reason: 'held while the op is unsent');
      await store.opDone('e1');
      await store.applyPullPos(withExpiry(posPage(), [expiryRow(_vGatas, null, at: '2026-11-08T01:00:00+00:00')]));
      expect((await row(store, _vGatas)).expiresOn, isNull, reason: 'the server copy (cleared elsewhere) replaces it');
    });
  });

  group('sync', () {
    late ExpiryServer server;
    late SyncEngine engine;
    setUp(() {
      server = ExpiryServer();
      engine = SyncEngine(store, server);
    });
    tearDown(() => engine.dispose());

    test('dates and receipts reach the server once even when a reply is lost; the server copy replaces the local one',
        () async {
      await store.receiveStock(variantId: _vGatas, qty: 10, expiresOn: inDays(30), opId: 'r1');
      await store.receiveStock(variantId: _vGatas, qty: 5, expiresOn: inDays(60), opId: 'r2');
      await store.setExpiry(variantId: _vTinapay, expiresOn: inDays(2), opId: 'e1');
      final before = ((await row(store, _vGatas)).expiresOn, (await row(store, _vTinapay)).expiresOn);
      expect(before, (inDays(30), inDays(2)));

      server.loseNextResponse = true;
      await engine.syncNow();
      expect((await store.watchOutboxCounts().first).pending, greaterThan(0));
      await engine.syncNow(); // the same op ids again
      expect((await store.watchOutboxCounts().first).pending, 0);
      expect(server.pushed.where((k) => k == 'receive_stock'), hasLength(4), reason: 'sent twice, applied once each');
      expect((server.qty[_vGatas], server.expiry[_vGatas], server.expiry[_vTinapay]),
          (15, dayKey(inDays(30)), dayKey(inDays(2))));
      expect(((await row(store, _vGatas)).expiresOn, (await row(store, _vTinapay)).expiresOn), before);

      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      expect(((await row(store, _vGatas)).expiresOn, (await row(store, _vTinapay)).expiresOn), before,
          reason: 'the same dates once the server copies arrive');
      final rows = await store.db.select(store.db.stockExpiry).get();
      expect(rows.every((r) => r.updatedAt != null), isTrue, reason: 'both rows are the server\'s now');
      expect((await row(store, _vGatas)).pending, isFalse);
      expect(await store.stockLeft(_vGatas), 15);
    });

    test('a phone that guessed the rule differently gets the server date on the next pull', () async {
      await store.receiveStock(variantId: _vGatas, qty: 3, expiresOn: inDays(10), opId: 'r1');
      await engine.syncNow();
      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      // another device sold the 3 meanwhile: the server's shelf is empty, this phone does not know yet
      server.qty[_vGatas] = 0;
      server.levelAt[_vGatas] = server.clock;
      await store.receiveStock(variantId: _vGatas, qty: 4, expiresOn: inDays(40), opId: 'r2');
      expect((await row(store, _vGatas)).expiresOn, inDays(10), reason: 'the phone thinks 3 are on hand');
      await engine.syncNow();
      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      expect(server.expiry[_vGatas], dayKey(inDays(40)), reason: 'the server saw an empty shelf');
      expect((await row(store, _vGatas)).expiresOn, inDays(40), reason: 'and its date replaced the phone\'s guess');
    });

    test('a refused date is parked; discarding it takes the local date back to the server\'s', () async {
      await store.setExpiry(variantId: _vGatas, expiresOn: inDays(9), opId: 'e1');
      await engine.syncNow();
      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      server.refuse = 'not_allowed';
      await store.setExpiry(variantId: _vGatas, expiresOn: inDays(3), opId: 'e2');
      await store.setExpiry(variantId: _vTinapay, expiresOn: inDays(4), opId: 'e3');
      await engine.syncNow();
      expect((await store.failedOps()).map((o) => (o.kind, o.lastError)),
          [('set_expiry', 'not_allowed'), ('set_expiry', 'not_allowed')]);
      expect((await row(store, _vGatas)).expiresOn, inDays(3), reason: 'refused but not discarded: still shown');

      await store.discardFailed('e3');
      expect((await row(store, _vTinapay)).expiresOn, isNull, reason: 'never on the server: gone at once');
      await store.discardFailed('e2');
      await engine.syncNow();
      final r = await row(store, _vGatas);
      expect((r.expiresOn, r.pending), (inDays(9), false), reason: 'the re-pull brought the server date');
    });
  });

  test('upgrading a v9 database keeps every row and adds the stock_expiry table', () async {
    final dir = Directory.systemTemp.createTempSync('xzpos_v9_');
    final file = File('${dir.path}/app.sqlite');
    final v9 = DriftStore(AppDatabase(NativeDatabase(file)));
    await seed(v9);
    await v9.receiveStock(variantId: _vGatas, qty: 4, opId: 'r1');
    await v9.commitSale(sale('s1', _vGatas, 1), opId: 's1');
    await v9.db.customStatement('drop table stock_expiry');
    await v9.db.customStatement("insert or replace into sync_cursors values ('stock_levels', '{}')");
    await v9.db.customStatement('PRAGMA user_version = 9');
    await v9.close();

    final v10 = DriftStore(AppDatabase(NativeDatabase(file)));
    await v10.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc); // same tenant: nothing cleared
    expect((await v10.getSale('s1'))!.summary.total, 1000);
    expect(await v10.stockLeft(_vGatas), 3);
    expect((await v10.nextOps()).map((o) => o.opId), ['r1', 's1'], reason: 'unsent ops survive');
    expect((await v10.cursors()).keys, contains('stock_levels'), reason: 'other cursors stay');
    final version = await v10.db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, v10.db.schemaVersion);
    await v10.setExpiry(variantId: _vGatas, expiresOn: inDays(3), opId: 'e1');
    expect((await row(v10, _vGatas)).expiresOn, inDays(3));
    await v10.close();
    dir.deleteSync(recursive: true);
  });
}
