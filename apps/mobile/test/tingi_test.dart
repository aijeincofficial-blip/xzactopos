import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;

const _loc = '0190a000-0000-7000-8000-0000000000e1';
const _pKaha = '0190a000-0000-7000-8000-000000000001';
const _vKaha = '0190a000-0000-7000-8000-0000000000a1';
const _pStick = '0190a000-0000-7000-8000-000000000002';
const _vStick = '0190a000-0000-7000-8000-0000000000a2';
const _pPack = '0190a000-0000-7000-8000-000000000003';
const _vPack = '0190a000-0000-7000-8000-0000000000a3';
const _pSachet = '0190a000-0000-7000-8000-000000000004';
const _vSachet = '0190a000-0000-7000-8000-0000000000a4';
const _pKape = '0190a000-0000-7000-8000-000000000005';
const _vKape = '0190a000-0000-7000-8000-0000000000a5';

const _names = {_vKaha: 'Yosi (kaha)', _vStick: 'Yosi (stick)', _vPack: 'Shampoo (pack)', _vSachet: 'Shampoo (sachet)', _vKape: 'Kape'};
const _products = {_vKaha: _pKaha, _vStick: _pStick, _vPack: _pPack, _vSachet: _pSachet, _vKape: _pKape};

/// half_up(n / d) written differently from the app's `halfUpDiv` (quotient and remainder), for the independent model.
int _roundHalfUp(BigInt n, BigInt d) {
  final q = n ~/ d;
  return (n.remainder(d) * BigInt.two >= d ? q + BigInt.one : q).toInt();
}

/// The documented cost rule, written again for the tests (whole quantities): adding [addQty] units worth [addValue].
int? modelBlend(int oldQty, int? oldCost, int addQty, int? addValue) {
  if (addValue == null) return oldCost;
  if (oldQty <= 0 || oldCost == null) return _roundHalfUp(BigInt.from(addValue), BigInt.from(addQty));
  return _roundHalfUp(BigInt.from(oldQty) * BigInt.from(oldCost) + BigInt.from(addValue), BigInt.from(oldQty + addQty));
}

class ServerLevel {
  int qty = 0;
  int? avg;
  bool counted = false;
  DateTime? at;
}

/// Behaves like sync_push (receive_stock, record_sale, set_tingi_link, open_pack, void_open_pack), sync_pull_pos (stock
/// levels with avg_cost, rows newer than 5 s held back), sync_pull_conversions and sync_pull_catalog (the variants with
/// their link). Once per op id; refusals leave nothing.
class TingiServer implements SyncApi {
  var clock = DateTime.utc(2026, 11, 8, 1);
  final applied = <String, Map<String, dynamic>>{};
  final levels = <String, ServerLevel>{};
  final links = <String, (String, int)>{};
  final conversions = <String, Map<String, dynamic>>{};
  final pushedKinds = <String>[];
  bool cashier = false;
  bool loseNextResponse = false;

  DateTime tick() => clock = clock.add(const Duration(seconds: 1));
  ServerLevel lvl(String v) => levels.putIfAbsent(v, ServerLevel.new);
  Map<String, dynamic> _rejected(String id, String hint) => {'op_id': id, 'status': 'rejected', 'code': '22023', 'hint': hint};

  Map<String, dynamic> _push1(Map<String, dynamic> op) {
    final id = op['op_id'] as String;
    final kind = op['kind'] as String;
    if (applied.containsKey(id)) return {'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': true}};
    final p = op['payload'] as Map<String, dynamic>;
    final stockKinds = {'set_tingi_link', 'open_pack', 'void_open_pack', 'receive_stock'};
    if (cashier && stockKinds.contains(kind)) return _rejected(id, 'not_allowed');
    if (kind == 'open_pack') {
      final link = links[p['pack_variant_id']];
      if (link == null) return _rejected(id, 'no_tingi_link');
      if (p['piece_variant_id'] != link.$1 || p['pieces_per_pack'] != link.$2) return _rejected(id, 'link_changed');
      if (conversions.containsKey(p['id'])) return _rejected(id, 'id_conflict');
    } else if (kind == 'void_open_pack') {
      final c = conversions[p['conversion_id']];
      if (c == null) return _rejected(id, 'conversion_not_found');
      if (c['voided_at'] != null) return _rejected(id, 'already_voided');
    }
    final now = tick();
    final at = now.toIso8601String();
    switch (kind) {
      case 'receive_stock':
        final l = lvl(p['variant_id'] as String);
        final q = (p['qty'] as num).toInt();
        l.avg = modelBlend(l.qty, l.avg, q, p['unit_cost'] == null ? null : q * (p['unit_cost'] as int));
        l.qty += q;
        l.counted = true;
        l.at = now;
      case 'record_sale':
        for (final i in (p['items'] as List).cast<Map<String, dynamic>>()) {
          final l = lvl(i['variant_id'] as String);
          l.qty -= (i['qty'] as num).toInt();
          l.at = now;
        }
      case 'set_tingi_link':
        final piece = p['piece_variant_id'] as String?;
        if (piece == null) {
          links.remove(p['variant_id']);
        } else {
          links[p['variant_id'] as String] = (piece, p['pieces_per_pack'] as int);
        }
      case 'open_pack':
        final (piece, ratio) = links[p['pack_variant_id']]!;
        final packs = p['packs'] as int;
        final pack = lvl(p['pack_variant_id'] as String);
        final pc = lvl(piece);
        final a = pack.avg; // the seeded variants cost 0, so there is no fallback
        final total = a == null ? null : packs * a;
        pc.avg = modelBlend(pc.qty, pc.avg, packs * ratio, total);
        pack.qty -= packs;
        pc.qty += packs * ratio;
        pc.counted = true;
        pack.at = now;
        pc.at = now;
        conversions[p['id'] as String] = {
          'id': p['id'], 'location_id': _loc, 'pack_variant_id': p['pack_variant_id'], 'piece_variant_id': piece,
          'packs': packs, 'ratio': ratio, 'pieces': packs * ratio, 'pack_cost': a, 'total_cost': total,
          'piece_cost': total == null ? null : modelBlend(0, null, packs * ratio, total), 'note': p['note'],
          'converted_at': p['at'], 'created_by': 'u1', 'voided_at': null, 'void_reason': null, 'updated_at': at,
        };
      case 'void_open_pack':
        final c = conversions[p['conversion_id']]!;
        lvl(c['pack_variant_id'] as String)
          ..qty += c['packs'] as int
          ..at = now;
        lvl(c['piece_variant_id'] as String)
          ..qty -= c['pieces'] as int
          ..at = now;
        c['voided_at'] = at;
        c['void_reason'] = p['reason'];
        c['updated_at'] = at;
    }
    applied[id] = {'applied_at': at};
    return {'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': false}};
  }

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      pushedKinds.add(op['kind'] as String);
      out.add(_push1(op));
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
          for (final e in levels.entries)
            if (e.value.at != null && !e.value.at!.isAfter(upto))
              {
                'location_id': _loc, 'variant_id': e.key, 'qty_on_hand': e.value.qty, 'avg_cost': e.value.avg,
                'counted': e.value.counted, 'updated_at': e.value.at!.toIso8601String(),
              }
        ],
        'cursor': null,
        'has_more': false,
      },
      'customers': {'rows': [], 'cursor': null, 'has_more': false},
      'customer_ledger': {'rows': [], 'cursor': null, 'has_more': false},
    };
  }

  @override
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100}) async {
    final upto = tick().subtract(const Duration(seconds: 5));
    final rows = conversions.values.where((c) => !DateTime.parse(c['updated_at'] as String).isAfter(upto)).toList();
    return {
      'rows': [for (final r in rows) Map<String, dynamic>.of(r)],
      'cursor': {'ts': upto.toIso8601String(), 'k': ''},
      'has_more': false,
      'server_time': clock.toIso8601String(),
    };
  }

  /// The catalog as the server has it: the five products, the pack variants with their current link.
  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async => pullPage(
        products: [for (final v in _names.keys) serverProduct(_products[v]!, _names[v]!)],
        variants: [
          for (final v in _names.keys)
            {...serverVariant(v, _products[v]!), 'breaks_into_variant_id': links[v]?.$1, 'breaks_into_qty': links[v]?.$2}
        ],
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
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload) async {}
  @override
  Future<void> archiveProduct(String opId, String productId) async {}
  @override
  Future<void> uploadPhoto(String path, Uint8List jpeg) async {}
  @override
  Future<Uint8List> downloadPhoto(String path) async => Uint8List(0);
}

SaleDraft pieceSale(String id, String variant, int qty) => SaleDraft(
      id: id,
      soldAt: DateTime.now(),
      lines: [SaleLine(variantId: variant, name: _names[variant] ?? 'Item', qty: qty.toDouble(), unitPrice: 700)],
      payments: [PaymentDraft('cash', qty * 700)],
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;

  Future<void> seed(DriftStore s, {bool untrackedSachet = false}) async {
    await s.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
    await s.applyPull(pullPage(
      products: [
        for (final v in _names.keys)
          {...serverProduct(_products[v]!, _names[v]!), if (v == _vSachet && untrackedSachet) 'track_stock': false}
      ],
      variants: [for (final v in _names.keys) serverVariant(v, _products[v]!)],
      prices: [for (final v in _names.keys) serverPrice(v, 1000)],
    ));
  }

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await seed(store);
  });
  tearDown(() => store.close());

  Future<List<ConversionView>> todays(DriftStore s) {
    final n = DateTime.now();
    return s.watchConversions(from: DateTime(n.year, n.month, n.day), to: DateTime(n.year, n.month, n.day + 1)).first;
  }

  group('the link', () {
    test('shows on the product at once and queues one set_tingi_link op; clearing works the same way', () async {
      await store.setTingiLink(variantId: _vKaha, pieceVariantId: _vStick, piecesPerPack: 20, opId: 'l1');
      final kaha = (await store.watchProducts(query: 'kaha').first).single;
      expect((kaha.sellsByPiece, kaha.breaksIntoVariantId, kaha.piecesPerPack, kaha.pieceName, kaha.pending),
          (true, _vStick, 20, 'Yosi (stick)', true));
      final op = (await store.nextOps()).single;
      expect((op.kind, op.entityId), ('set_tingi_link', _pKaha));
      expect(op.payload, {'variant_id': _vKaha, 'piece_variant_id': _vStick, 'pieces_per_pack': 20});
      expect((await store.tingiPiece(_vKaha))!.name, 'Yosi (stick)');
      expect(await store.tingiPiece(_vStick), isNull, reason: 'the piece itself has no link');
      final row = (await store.watchStockList(query: 'kaha').first).single;
      expect((row.product.piecesPerPack, row.product.pieceName), (20, 'Yosi (stick)'));

      await store.clearTingiLink(variantId: _vKaha, opId: 'l2');
      final cleared = (await store.watchProducts(query: 'kaha').first).single;
      expect((cleared.sellsByPiece, cleared.breaksIntoVariantId, cleared.piecesPerPack), (false, null, null));
      expect((await store.nextOps()).last.payload, {'variant_id': _vKaha, 'piece_variant_id': null, 'pieces_per_pack': null});
    });

    test('bad links are refused before anything is written', () async {
      await store.setTingiLink(variantId: _vKaha, pieceVariantId: _vStick, piecesPerPack: 20, opId: 'l1');
      expect(() => store.setTingiLink(variantId: _vPack, pieceVariantId: _vPack, piecesPerPack: 2, opId: 'x1'), throwsArgumentError);
      expect(() => store.setTingiLink(variantId: _vPack, pieceVariantId: _vSachet, piecesPerPack: 0, opId: 'x2'), throwsArgumentError);
      expect(() => store.setTingiLink(variantId: _vPack, pieceVariantId: _vSachet, opId: 'x3'), throwsArgumentError);
      expect(() => store.setTingiLink(variantId: _vPack, pieceVariantId: _vSachet, piecesPerPack: 10001, opId: 'x4'),
          throwsArgumentError);
      await expectLater(store.setTingiLink(variantId: _vStick, pieceVariantId: _vSachet, piecesPerPack: 2, opId: 'x5'),
          throwsStateError, reason: 'a piece cannot also be a pack');
      await expectLater(store.setTingiLink(variantId: _vPack, pieceVariantId: _vKaha, piecesPerPack: 2, opId: 'x6'),
          throwsStateError, reason: 'a pack cannot also be a piece');
      await expectLater(store.setTingiLink(variantId: _vPack, pieceVariantId: 'nope', piecesPerPack: 2, opId: 'x7'),
          throwsStateError);
      expect((await store.nextOps()).map((o) => o.opId), ['l1']);
      expect((await store.watchProducts(query: 'pack').first).single.sellsByPiece, isFalse);
    });

    test('a piece that keeps no stock count is refused', () async {
      final s = DriftStore(AppDatabase(NativeDatabase.memory()));
      await seed(s, untrackedSachet: true);
      await expectLater(s.setTingiLink(variantId: _vPack, pieceVariantId: _vSachet, piecesPerPack: 12, opId: 'x'),
          throwsStateError);
      await s.close();
    });
  });

  group('opening a pack', () {
    setUp(() => store.setTingiLink(variantId: _vKaha, pieceVariantId: _vStick, piecesPerPack: 20, opId: 'l1'));

    test('moves both stock numbers at once, carries the pack cost into the pieces and queues one open_pack op', () async {
      await store.receiveStock(variantId: _vKaha, qty: 5, cost: 10350, opId: 'r1');
      expect(await store.averageCost(_vKaha), 10350, reason: 'the unsent stock in already sets the average on the phone');
      final at = DateTime.now();
      final opened = await store.openPack(id: 'c1', packVariantId: _vKaha, packs: 1, note: ' bukas ', at: at, opId: 'o1');
      expect((opened.pieces, opened.packCost, opened.totalCost, opened.pieceCost, opened.pieceVariantId),
          (20, 10350, 10350, 518, _vStick));
      expect((await store.stockLeft(_vKaha), await store.stockLeft(_vStick)), (4.0, 20.0));
      expect(await store.watchStock().first, {_vKaha: 4.0, _vStick: 20.0}, reason: 'the pieces are counted now');
      expect(await store.averageCost(_vStick), 518);
      expect(await store.averageCost(_vKaha), 10350, reason: 'opening never moves the pack average');

      final op = (await store.nextOps()).last;
      expect((op.kind, op.entityId), ('open_pack', 'c1'));
      expect(op.payload, {
        'id': 'c1', 'pack_variant_id': _vKaha, 'packs': 1, 'piece_variant_id': _vStick, 'pieces_per_pack': 20,
        'note': 'bukas', 'at': at.toUtc().toIso8601String(), 'location_id': _loc,
      });
      final c = (await todays(store)).single;
      expect((c.packName, c.pieceName, c.packs, c.ratio, c.pieces, c.totalCost, c.pieceCost, c.pending, c.voided),
          ('Yosi (kaha)', 'Yosi (stick)', 1, 20, 20, 10350, 518, true, false));

      // a stick sold now carries the cost the server will also have: 5.18
      await store.commitSale(pieceSale('s1', _vStick, 3), opId: 'o2');
      expect(((await store.nextOps()).last.payload['items'] as List).single['unit_cost'], 518);
      expect(await store.stockLeft(_vStick), 17);
    });

    test('a second opening blends with the pieces on hand; with no cost known the pieces keep theirs', () async {
      await store.receiveStock(variantId: _vKaha, qty: 3, cost: 10350, opId: 'r1');
      await store.openPack(id: 'c1', packVariantId: _vKaha, packs: 1, opId: 'o1');
      await store.openPack(id: 'c2', packVariantId: _vKaha, packs: 2, opId: 'o2');
      expect(await store.averageCost(_vStick), 518, reason: '(20 x 518 + 20700) / 60 = 517.67 -> 518');
      await store.setTingiLink(variantId: _vPack, pieceVariantId: _vSachet, piecesPerPack: 12, opId: 'l2');
      final none = await store.openPack(id: 'c3', packVariantId: _vPack, packs: 1, opId: 'o3');
      expect((none.packCost, none.totalCost, none.pieceCost), (null, null, null));
      expect(await store.averageCost(_vSachet), isNull);
      expect(await store.stockLeft(_vSachet), 12);
    });

    test('opening more than counted is allowed (the pack goes below zero, like a sale)', () async {
      await store.receiveStock(variantId: _vKaha, qty: 1, cost: 9000, opId: 'r1');
      await store.openPack(id: 'c1', packVariantId: _vKaha, packs: 3, opId: 'o1');
      expect((await store.stockLeft(_vKaha), await store.stockLeft(_vStick)), (-2.0, 60.0));
    });

    test('refused when there is no link, the piece is archived, or packs is out of range', () async {
      expect(() => store.openPack(id: 'c1', packVariantId: _vKaha, packs: 0, opId: 'x1'), throwsArgumentError);
      expect(() => store.openPack(id: 'c1', packVariantId: _vKaha, packs: tingiMaxPacks + 1, opId: 'x2'), throwsArgumentError);
      await expectLater(store.openPack(id: 'c1', packVariantId: _vKape, packs: 1, opId: 'x3'), throwsStateError);
      await expectLater(store.openPack(id: 'c1', packVariantId: _vStick, packs: 1, opId: 'x4'), throwsStateError);
      await store.archiveProduct(_pStick, opId: 'a1');
      await expectLater(store.openPack(id: 'c1', packVariantId: _vKaha, packs: 1, opId: 'x5'), throwsStateError);
      expect((await store.nextOps()).map((o) => o.kind), ['set_tingi_link', 'archive_product']);
      expect(await store.db.select(store.db.localMovements).get(), isEmpty);
    });

    test('a void puts the packs back and takes the pieces out, once; the averages stay', () async {
      await store.receiveStock(variantId: _vKaha, qty: 2, cost: 10000, opId: 'r1');
      await store.openPack(id: 'c1', packVariantId: _vKaha, packs: 1, opId: 'o1');
      await store.commitSale(pieceSale('s1', _vStick, 5), opId: 'o2');
      await store.voidOpenPack(conversionId: 'c1', reason: ' mali ', opId: 'v1');
      expect((await store.stockLeft(_vKaha), await store.stockLeft(_vStick)), (2.0, -5.0),
          reason: 'the sticks already sold leave the piece below zero');
      expect((await store.averageCost(_vKaha), await store.averageCost(_vStick)), (10000, 500));
      final c = (await todays(store)).single;
      expect((c.voided, c.voidReason), (true, 'mali'));
      final op = (await store.nextOps()).last;
      expect((op.kind, op.entityId), ('void_open_pack', 'c1'));
      expect(op.payload, {'conversion_id': 'c1', 'reason': 'mali'});
      await expectLater(store.voidOpenPack(conversionId: 'c1', opId: 'v2'), throwsStateError);
      await expectLater(store.voidOpenPack(conversionId: 'nope', opId: 'v3'), throwsStateError);
    });
  });

  group('sync', () {
    late TingiServer server;
    late SyncEngine engine;
    setUp(() {
      server = TingiServer();
      engine = SyncEngine(store, server);
    });
    tearDown(() => engine.dispose());

    test('link, stock in, opening, sale and void reach the server once even when a reply is lost; nothing counts twice',
        () async {
      await store.setTingiLink(variantId: _vKaha, pieceVariantId: _vStick, piecesPerPack: 20, opId: 'l1');
      await store.receiveStock(variantId: _vKaha, qty: 5, cost: 10350, opId: 'r1');
      await store.openPack(id: 'c1', packVariantId: _vKaha, packs: 2, opId: 'o1');
      await store.commitSale(pieceSale('s1', _vStick, 7), opId: 's1');
      await store.openPack(id: 'c2', packVariantId: _vKaha, packs: 1, opId: 'o2');
      await store.voidOpenPack(conversionId: 'c2', opId: 'v2');
      final before = (await store.stockLeft(_vKaha), await store.stockLeft(_vStick), await store.averageCost(_vStick));
      expect(before, (3.0, 33.0, 518));

      server.loseNextResponse = true;
      await engine.syncNow();
      expect((await store.watchOutboxCounts().first).pending, greaterThan(0));
      await engine.syncNow(); // the same op ids again: the server applies nothing twice
      expect((await store.watchOutboxCounts().first).pending, 0);
      expect(server.pushedKinds.where((k) => k == 'open_pack'), hasLength(4), reason: 'sent twice, applied once each');
      expect((server.levels[_vKaha]!.qty, server.levels[_vStick]!.qty, server.levels[_vStick]!.avg), (3, 33, 518));
      expect(server.conversions.keys.toSet(), {'c1', 'c2'});
      expect((await store.stockLeft(_vKaha), await store.stockLeft(_vStick), await store.averageCost(_vStick)), before,
          reason: 'unchanged while the server copy is held back');

      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      expect((await store.stockLeft(_vKaha), await store.stockLeft(_vStick), await store.averageCost(_vStick)), before,
          reason: 'the same numbers once the server levels arrive');
      expect(await store.db.select(store.db.localMovements).get(), isEmpty, reason: 'the local effects were dropped');
      final rows = await todays(store);
      expect({for (final c in rows) c.id: (c.voided, c.pending)}, {'c1': (false, false), 'c2': (true, false)});
      final kaha = (await store.watchProducts(query: 'kaha').first).single;
      expect((kaha.piecesPerPack, kaha.pending), (20, false), reason: 'the link came back from the server');
    });

    test('a refused opening parks the op; discard takes the stock effects and the row back', () async {
      await store.setTingiLink(variantId: _vKaha, pieceVariantId: _vStick, piecesPerPack: 20, opId: 'l1');
      await engine.syncNow();
      server.links[_vKaha] = (_vStick, 10); // another device changed the ratio meanwhile
      await store.receiveStock(variantId: _vKaha, qty: 2, cost: 5000, opId: 'r1');
      await store.openPack(id: 'c1', packVariantId: _vKaha, packs: 1, opId: 'o1');
      await engine.syncNow();
      final failed = (await store.failedOps()).single;
      expect((failed.kind, failed.lastError), ('open_pack', 'link_changed'));
      expect((await todays(store)).single.rejectedHint, 'link_changed');
      expect(await store.stockLeft(_vStick), 20, reason: 'refused but not discarded: still shown');

      await store.discardFailed('o1');
      expect(await todays(store), isEmpty);
      expect((await store.stockLeft(_vKaha), await store.stockLeft(_vStick)), (2.0, 0.0));
      await engine.syncNow();
      expect((await store.watchProducts(query: 'kaha').first).single.piecesPerPack, 10,
          reason: 'the re-pull brought the server link');
    });

    test('a cashier cannot link or open; discarding the link goes back to the server copy', () async {
      server.cashier = true;
      await store.setTingiLink(variantId: _vKaha, pieceVariantId: _vStick, piecesPerPack: 20, opId: 'l1');
      await engine.syncNow();
      expect((await store.failedOps()).map((o) => (o.kind, o.lastError)), [('set_tingi_link', 'not_allowed')]);
      await store.discardFailed('l1');
      await engine.syncNow();
      expect((await store.watchProducts(query: 'kaha').first).single.sellsByPiece, isFalse);
    });

    test('a void still on its way is kept when the server copy of the opening arrives first', () async {
      await store.setTingiLink(variantId: _vKaha, pieceVariantId: _vStick, piecesPerPack: 20, opId: 'l1');
      await store.openPack(id: 'c1', packVariantId: _vKaha, packs: 1, opId: 'o1');
      await engine.syncNow();
      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      await store.voidOpenPack(conversionId: 'c1', opId: 'v1');
      await store.applyPullConversions(await server.pullConversions(null)); // the not-voided server copy
      expect((await todays(store)).single.voided, isTrue);
      await engine.syncNow();
      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      expect(((await todays(store)).single.voided, (await todays(store)).single.pending), (true, false));
      expect((await store.stockLeft(_vKaha), await store.stockLeft(_vStick)), (0.0, 0.0));
    });
  });

  test('property: phone stock and costs equal an independent model, before and after a sync, value within the bound',
      () async {
    final server = TingiServer();
    final engine = SyncEngine(store, server);
    final r = Random(808);
    final qty = <String, int>{};
    final avg = <String, int?>{};
    final open = <(String, String, String, int, int)>[]; // id, pack, piece, packs, pieces
    final ratios = {_vKaha: 1 + r.nextInt(40), _vPack: 1 + r.nextInt(40)};
    final pieceOf = {_vKaha: _vStick, _vPack: _vSachet};
    await store.setTingiLink(variantId: _vKaha, pieceVariantId: _vStick, piecesPerPack: ratios[_vKaha]!, opId: 'l1');
    await store.setTingiLink(variantId: _vPack, pieceVariantId: _vSachet, piecesPerPack: ratios[_vPack]!, opId: 'l2');
    var n = 0;
    var valueChecks = 0;
    var opens = 0;
    for (var step = 0; step < 160; step++) {
      final pack = r.nextBool() ? _vKaha : _vPack;
      final piece = pieceOf[pack]!;
      final x = r.nextDouble();
      final id = 'p${n++}';
      if (x < 0.25) {
        final q = 1 + r.nextInt(5);
        final cost = r.nextInt(10) < 8 ? 1 + r.nextInt(99999) : null;
        await store.receiveStock(variantId: pack, qty: q.toDouble(), cost: cost, opId: id);
        avg[pack] = modelBlend(qty[pack] ?? 0, avg[pack], q, cost == null ? null : q * cost);
        qty[pack] = (qty[pack] ?? 0) + q;
      } else if (x < 0.35) {
        final q = 1 + r.nextInt(30);
        final cost = r.nextBool() ? 1 + r.nextInt(5000) : null;
        await store.receiveStock(variantId: piece, qty: q.toDouble(), cost: cost, opId: id);
        avg[piece] = modelBlend(qty[piece] ?? 0, avg[piece], q, cost == null ? null : q * cost);
        qty[piece] = (qty[piece] ?? 0) + q;
      } else if (x < 0.65) {
        final packs = 1 + r.nextInt(3);
        final pieces = packs * ratios[pack]!;
        final q0 = qty[piece] ?? 0;
        final a0 = avg[piece];
        final total = avg[pack] == null ? null : packs * avg[pack]!;
        final opened = await store.openPack(id: id, packVariantId: pack, packs: packs, opId: '$id-op');
        expect(opened.totalCost, total, reason: 'total = packs x pack average ($id)');
        avg[piece] = modelBlend(q0, a0, pieces, total);
        qty[pack] = (qty[pack] ?? 0) - packs;
        qty[piece] = q0 + pieces;
        open.add((id, pack, piece, packs, pieces));
        opens++;
        if (total != null && q0 >= 0 && (q0 == 0 || a0 != null)) {
          // value of the pack and the pieces: the pack lost exactly `total`; the pieces may be off by half a centavo each
          final diff = qty[piece]! * avg[piece]! - (q0 * (a0 ?? 0)) - total;
          expect(2 * diff.abs() <= qty[piece]!, isTrue, reason: 'value bound at $id: diff $diff for ${qty[piece]} pieces');
          valueChecks++;
        }
      } else if (x < 0.85) {
        final q = 1 + r.nextInt(12);
        await store.commitSale(pieceSale(id, piece, q), opId: '$id-op');
        final sent = ((await store.nextOps(limit: 1000)).last.payload['items'] as List).single['unit_cost'];
        expect(sent, avg[piece] ?? 0, reason: 'the sale cost is the model average ($id)');
        qty[piece] = (qty[piece] ?? 0) - q;
      } else if (open.isNotEmpty) {
        final o = open.removeAt(r.nextInt(open.length));
        await store.voidOpenPack(conversionId: o.$1, opId: '$id-op');
        qty[o.$2] = (qty[o.$2] ?? 0) + o.$4;
        qty[o.$3] = (qty[o.$3] ?? 0) - o.$5;
      }
      if (step % 20 == 19) {
        // sync now and then: the numbers must not move when the server copies arrive (or while they are held back)
        await engine.syncNow();
        server.clock = server.clock.add(Duration(seconds: r.nextBool() ? 30 : 1));
      }
      for (final v in [_vKaha, _vStick, _vPack, _vSachet]) {
        expect(await store.stockLeft(v), (qty[v] ?? 0).toDouble(), reason: 'qty of ${_names[v]} after step $step');
        expect(await store.averageCost(v), avg[v], reason: 'average of ${_names[v]} after step $step');
      }
    }
    expect(opens, greaterThan(30));
    expect(valueChecks, greaterThan(10));
    await engine.syncNow();
    server.clock = server.clock.add(const Duration(seconds: 30));
    await engine.syncNow();
    expect(await store.db.select(store.db.localMovements).get(), isEmpty);
    for (final v in [_vKaha, _vStick, _vPack, _vSachet]) {
      expect((server.levels[v]?.qty ?? 0, server.levels[v]?.avg), (qty[v] ?? 0, avg[v]), reason: 'server ${_names[v]}');
      expect((await store.stockLeft(v), await store.averageCost(v)), ((qty[v] ?? 0).toDouble(), avg[v]),
          reason: 'phone ${_names[v]} after the sync');
    }
    engine.dispose();
  });

  test('the cost helpers follow the documented rule (worked example with a remainder)', () {
    expect(conversionAvgCost(oldQty: 0, pieces: 20, totalCost: 10350), 518, reason: '517.5 rounds half up');
    expect(conversionAvgCost(oldQty: 20, oldCost: 518, pieces: 40, totalCost: 20700), 518);
    expect(conversionAvgCost(oldQty: 5, oldCost: 500, pieces: 20, totalCost: 10350), 514, reason: '12850 / 25 exactly');
    expect(conversionAvgCost(oldQty: -3, oldCost: 900, pieces: 12, totalCost: 600), 50, reason: 'a level below zero resets');
    expect(conversionAvgCost(oldQty: 10, oldCost: null, pieces: 12, totalCost: 600), 50, reason: 'no old cost resets');
    expect(conversionAvgCost(oldQty: 10, oldCost: 70, pieces: 12, totalCost: null), 70, reason: 'no cost carried: unchanged');
    expect(receiptAvgCost(oldQty: 10, oldCost: 100, qty: 10, unitCost: 200), 150);
    expect(receiptAvgCost(oldQty: 1, oldCost: 100, qty: 2, unitCost: 101), 101, reason: '100.67');
    expect(receiptAvgCost(oldQty: 2.5, oldCost: 333, qty: 0.5, unitCost: 100), 294, reason: '(832.5 + 50) / 3 = 294.17');
    expect(halfUpDiv(BigInt.from(5), BigInt.from(2)), 3);
    expect(halfUpDiv(BigInt.from(7), BigInt.from(3)), 2);
    // big values stay exact (web builds have 53-bit ints)
    expect(conversionAvgCost(oldQty: 1000000, oldCost: 9999999, pieces: 1000000, totalCost: 9999999000000), 9999999);
  });

  test('upgrading a v7 database keeps every row, adds the link and cost columns and the conversions table', () async {
    final dir = Directory.systemTemp.createTempSync('xzpos_v7_');
    final file = File('${dir.path}/app.sqlite');
    final v7 = DriftStore(AppDatabase(NativeDatabase(file)));
    await seed(v7);
    await v7.receiveStock(variantId: _vKaha, qty: 4, opId: 'r1');
    await v7.commitSale(pieceSale('s1', _vKaha, 1), opId: 's1');
    await v7.db.customStatement('drop table conversions');
    for (final (t, c) in [
      ('variants', 'breaks_into_variant_id'), ('variants', 'breaks_into_qty'),
      ('local_movements', 'unit_cost'), ('local_movements', 'total_cost'),
    ]) {
      await v7.db.customStatement('alter table $t drop column $c');
    }
    await v7.db.customStatement("insert or replace into sync_cursors values ('product_variants', '{}'), ('products', '{}')");
    await v7.db.customStatement('PRAGMA user_version = 7');
    await v7.close();

    final v8 = DriftStore(AppDatabase(NativeDatabase(file)));
    await v8.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc); // same tenant: nothing cleared
    expect((await v8.getSale('s1'))!.summary.total, 700);
    expect(await v8.stockLeft(_vKaha), 3);
    expect((await v8.nextOps()).map((o) => o.opId), ['r1', 's1'], reason: 'unsent ops survive');
    expect((await v8.cursors()).keys, contains('products'));
    expect((await v8.cursors()).keys, isNot(contains('product_variants')), reason: 'variants are pulled again for the link');
    final version = await v8.db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, v8.db.schemaVersion);
    await v8.setTingiLink(variantId: _vKaha, pieceVariantId: _vStick, piecesPerPack: 20, opId: 'l1');
    await v8.openPack(id: 'c1', packVariantId: _vKaha, packs: 1, opId: 'o1');
    expect((await v8.stockLeft(_vKaha), await v8.stockLeft(_vStick)), (2.0, 20.0));
    final idx = await v8.db.customSelect("select name from sqlite_master where type = 'index' and name = 'conversions_converted_at'").get();
    expect(idx, hasLength(1));
    await v8.close();
    dir.deleteSync(recursive: true);
  });
}
