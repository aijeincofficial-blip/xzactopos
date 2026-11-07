import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'sales_store_test.dart' show level, posPage;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';
const _loc = '0190a000-0000-7000-8000-0000000000e1';

SaleDraft sale(String id, String variant, double qty) => SaleDraft(
      id: id,
      soldAt: DateTime.now(),
      lines: [SaleLine(variantId: variant, name: 'Item', qty: qty, unitPrice: 1000, unitCost: 400)],
      payments: [PaymentDraft('cash', (qty * 1000).round())],
    );

/// Applies receive/adjust ops like the server does: a count's delta comes from the server level, replays do nothing.
class StockServer implements SyncApi {
  double stock = 0;
  bool counted = false;
  DateTime? changedAt;
  var clock = DateTime.utc(2026, 11, 8, 1);
  final done = <String, Map<String, dynamic>>{};
  bool loseNextResponse = false;
  int adjustCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      final id = op['op_id'] as String;
      final p = op['payload'] as Map<String, dynamic>;
      if (!done.containsKey(id)) {
        clock = clock.add(const Duration(seconds: 1));
        if (op['kind'] == 'receive_stock') {
          stock += (p['qty'] as num).toDouble();
        } else if (op['kind'] == 'record_sale') {
          for (final i in p['items'] as List) {
            stock -= (i['qty'] as num).toDouble();
          }
          changedAt = clock;
          done[id] = {'applied_at': clock.toIso8601String()};
          out.add({'op_id': id, 'status': 'ok', 'result': done[id]});
          continue;
        } else if (op['kind'] == 'adjust_stock') {
          adjustCalls++;
          stock = (p['counted'] as num).toDouble();
        }
        counted = true;
        changedAt = clock;
        done[id] = {'applied_at': clock.toIso8601String()};
      }
      out.add({'op_id': id, 'status': 'ok', 'result': done[id]});
    }
    if (loseNextResponse) {
      loseNextResponse = false;
      throw Exception('connection lost');
    }
    return out;
  }

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
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async {
    clock = clock.add(const Duration(seconds: 1));
    final held = changedAt != null && changedAt!.isAfter(clock.subtract(const Duration(seconds: 5)));
    return {
      'server_time': clock.toIso8601String(),
      'stock_levels': {
        'rows': [
          if (changedAt != null && !held)
            {
              'location_id': _loc, 'variant_id': _v1, 'qty_on_hand': stock, 'avg_cost': null,
              'counted': counted, 'updated_at': changedAt!.toIso8601String(),
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
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async => pullPage();
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

  Future<void> seed({double reorder = 0}) => store.applyPull(pullPage(
        products: [serverProduct(_p1, 'Kape'), serverProduct(_p2, 'Asukal')],
        variants: [
          {...serverVariant(_v1, _p1, barcode: '111'), 'reorder_point': reorder},
          serverVariant(_v2, _p2),
        ],
        prices: [serverPrice(_v1, 1500), serverPrice(_v2, 4500)],
      ));

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
    await seed();
  });
  tearDown(() => store.close());

  group('stock in', () {
    test('shows at once, counts the product, and queues one op', () async {
      expect(await store.watchStock().first, isEmpty, reason: 'nothing counted yet');
      await store.receiveStock(variantId: _v1, qty: 24, cost: 900, opId: 'r1');
      expect(await store.stockLeft(_v1), 24);
      expect(await store.watchStock().first, {_v1: 24.0});
      final op = (await store.nextOps()).single;
      expect(op.kind, 'receive_stock');
      expect(op.payload, {'variant_id': _v1, 'qty': 24.0, 'unit_cost': 900, 'location_id': _loc});
    });

    test('cost is optional and a zero quantity is refused', () async {
      await store.receiveStock(variantId: _v1, qty: 2, opId: 'r1');
      expect((await store.nextOps()).single.payload.containsKey('unit_cost'), isFalse);
      expect(() => store.receiveStock(variantId: _v1, qty: 0, opId: 'r2'), throwsArgumentError);
    });
  });

  group('counting', () {
    test('the difference from what the phone shows is written, also after a sale', () async {
      await store.applyPullPos(posPage(levels: [level(_v1, 10, '2026-11-08T00:00:00+00:00')]));
      await store.commitSale(sale('s1', _v1, 3), opId: 'o1');
      expect(await store.stockLeft(_v1), 7);
      await store.adjustStock(variantId: _v1, counted: 5, reason: 'damage', opId: 'c1');
      expect(await store.stockLeft(_v1), 5);
      final op = (await store.nextOps()).last;
      expect(op.kind, 'adjust_stock');
      expect(op.payload, {'variant_id': _v1, 'counted': 5.0, 'reason': 'damage', 'location_id': _loc});
    });

    test('counting what is already shown queues nothing', () async {
      await store.receiveStock(variantId: _v1, qty: 4, opId: 'r1');
      await store.adjustStock(variantId: _v1, counted: 4, opId: 'c1');
      expect((await store.nextOps()).map((o) => o.kind), ['receive_stock']);
    });

    test('a first count starts a never-counted product, even after sales made it negative', () async {
      await store.commitSale(sale('s1', _v1, 1), opId: 'o1');
      expect(await store.stockLeft(_v1), -1);
      expect(await store.watchStock().first, isEmpty, reason: 'a sale alone does not make it counted');
      await store.adjustStock(variantId: _v1, counted: 4, opId: 'c1');
      expect(await store.stockLeft(_v1), 4);
      expect(await store.watchStock().first, {_v1: 4.0});
    });

    test('a negative count is refused', () {
      expect(() => store.adjustStock(variantId: _v1, counted: -1, opId: 'c1'), throwsArgumentError);
    });
  });

  group('stock list', () {
    test('not counted shows no quantity; low items come first; search narrows', () async {
      await store.applyPull(pullPage(
        products: [serverProduct(_p1, 'Kape')],
        variants: [{...serverVariant(_v1, _p1), 'reorder_point': 5}],
        prices: [serverPrice(_v1, 1500)],
      ));
      var rows = await store.watchStockList().first;
      expect(rows.map((r) => r.product.name), ['Asukal', 'Kape']);
      expect(rows.every((r) => !r.counted && r.qty == null && !r.low), isTrue);

      await store.receiveStock(variantId: _v2, qty: 20, opId: 'r2');
      await store.receiveStock(variantId: _v1, qty: 4, opId: 'r1'); // 4 <= reorder point 5
      rows = await store.watchStockList().first;
      expect(rows.map((r) => r.product.name), ['Kape', 'Asukal'], reason: 'low first');
      expect(rows.first.low, isTrue);
      expect(rows.last.low, isFalse);
      expect(rows.first.pending, isTrue);

      expect((await store.watchStockList(query: 'asuk').first).map((r) => r.product.name), ['Asukal']);
    });

    test('products that do not track stock are not listed', () async {
      await store.applyPull(pullPage(
        products: [{...serverProduct(_p1, 'Kape'), 'track_stock': false}],
        variants: [serverVariant(_v1, _p1)],
      ));
      expect((await store.watchStockList().first).map((r) => r.product.name), ['Asukal']);
    });
  });

  test('a sale copies the average cost the server reported', () async {
    await store.applyPullPos({
      ...posPage(levels: [level(_v1, 10, '2026-11-08T00:00:00+00:00')]),
      'stock_levels': {
        'rows': [
          {'location_id': _loc, 'variant_id': _v1, 'qty_on_hand': 10, 'avg_cost': 700, 'counted': true, 'updated_at': '2026-11-08T00:00:00+00:00'}
        ],
        'cursor': null,
        'has_more': false,
      },
    });
    await store.commitSale(sale('s1', _v1, 1), opId: 'o1');
    expect(((await store.nextOps()).single.payload['items'] as List).single['unit_cost'], 700);
    await store.commitSale(sale('s2', _v2, 1), opId: 'o2');
    expect(((await store.nextOps()).last.payload['items'] as List).single['unit_cost'], 400, reason: 'no average yet: the line cost');
  });

  test('upgrading a v4 database adds the flags and asks for the stock levels again', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE stock_levels (location_id TEXT NOT NULL, variant_id TEXT NOT NULL, qty REAL NOT NULL, '
          'updated_at TEXT NOT NULL, PRIMARY KEY (location_id, variant_id))');
      raw.execute('CREATE TABLE local_movements (id INTEGER PRIMARY KEY AUTOINCREMENT, op_id TEXT NOT NULL, '
          'variant_id TEXT NOT NULL, qty REAL NOT NULL, confirmed_after TEXT NULL)');
      raw.execute('CREATE TABLE outbox (op_id TEXT NOT NULL UNIQUE, seq INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, '
          "entity_id TEXT NOT NULL, payload TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', "
          'attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT NULL, created_at INTEGER NOT NULL)');
      raw.execute('CREATE TABLE sync_cursors (table_key TEXT NOT NULL PRIMARY KEY, cursor_json TEXT NOT NULL)');
      raw.execute("INSERT INTO stock_levels VALUES ('l', 'v1', 5, '2026-11-08T00:00:00Z')");
      raw.execute("INSERT INTO local_movements (op_id, variant_id, qty) VALUES ('open-op', 'v1', 3), ('sale-op', 'v1', -1)");
      raw.execute("INSERT INTO outbox (op_id, kind, entity_id, payload, created_at) VALUES ('open-op', 'post_opening_stock', 'p1', '{}', 0)");
      raw.execute("INSERT INTO sync_cursors VALUES ('stock_levels', '{}'), ('customers', '{}')");
      raw.execute('PRAGMA user_version = 4');
    }));
    final old = DriftStore(db);
    expect((await db.select(db.stockLevels).get()).single.counted, isFalse);
    final moves = await db.select(db.localMovements).get();
    expect({for (final m in moves) m.opId: m.counts}, {'open-op': true, 'sale-op': false});
    expect((await old.cursors()).keys, ['customers'], reason: 'stock levels will be pulled again');
    await old.close();
  });

  group('round trip with a server', () {
    test('stock in and a count reach the server once, even when a reply is lost; numbers match after', () async {
      final server = StockServer();
      final engine = SyncEngine(store, server);
      await store.receiveStock(variantId: _v1, qty: 24, opId: 'r1');
      await store.commitSale(sale('s1', _v1, 4), opId: 'o1');
      await store.adjustStock(variantId: _v1, counted: 18, opId: 'c1'); // local says 20 -> delta -2

      server.loseNextResponse = true;
      await engine.syncNow();
      expect((await store.watchOutboxCounts().first).pending, greaterThan(0));
      await engine.syncNow(); // retry, same op ids
      expect(server.adjustCalls, 1, reason: 'the count was applied once');
      expect(server.stock, 18);
      expect((await store.watchOutboxCounts().first).pending, 0);
      expect(await store.stockLeft(_v1), 18);

      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      expect(await store.stockLeft(_v1), 18, reason: 'same number once the server level arrives');
      expect(await store.db.select(store.db.localMovements).get(), isEmpty);
      expect(await store.watchStock().first, {_v1: 18.0});
      engine.dispose();
    });
  });
}
