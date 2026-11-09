import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/data/warehouse_models.dart';
import 'package:xzactopos_mobile/sync/store_session.dart' show syncScopeForRole;
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'sync_engine_test.dart' show FakeApi;

const _w1 = 'w1000000-0000-4000-8000-000000000001';
const _supA = 'a0000000-0000-4000-8000-0000000000a1';
const _po1 = 'p1000000-0000-4000-8000-000000000001';
const _rice = 'v1000000-0000-4000-8000-000000000001';
const _oil = 'v2000000-0000-4000-8000-000000000002';
const _salt = 'v3000000-0000-4000-8000-000000000003';

/// A server that behaves like the real one where it matters to the phone: it applies receipts with ITS OWN clock,
/// stamps the order and stock rows with that time, holds back rows newer than 5 s from a pull, pages by cursor, and never
/// sends drafts or (on the first pull) finished orders.
class FakeWarehouseServer extends FakeApi implements WarehouseApi {
  DateTime now = DateTime.utc(2026, 11, 9, 9, 0, 0);
  bool failPull = false;
  bool moduleOff = false;
  int errorOnNextPush = 0;

  final warehouses = <Map<String, dynamic>>[];
  final suppliers = <Map<String, dynamic>>[];
  final pos = <String, Map<String, dynamic>>{};
  final stock = <String, Map<String, dynamic>>{};

  final pushed = <Map<String, dynamic>>[]; // every op the server was sent, in order
  final pullCursors = <Map<String, dynamic>>[];
  int pullCalls = 0;
  int storePullCalls = 0;
  final _seen = <String, Map<String, dynamic>>{};
  int _grn = 0;

  String iso(DateTime t) => t.toUtc().toIso8601String();

  void seed() {
    final old = iso(now.subtract(const Duration(hours: 1)));
    warehouses.add({'id': _w1, 'code': 'W1', 'name': 'Warehouse One', 'bins_enabled': false, 'active': true, 'updated_at': old, 'deleted_at': null});
    suppliers.add({'id': _supA, 'name': 'Mega Rice Trading', 'contact_name': null, 'phone': null, 'email': null, 'notes': null, 'updated_at': old, 'deleted_at': null});
    pos[_po1] = _po(_po1, 'PO-1', 'ordered', old, [
      {'id': '$_po1-1', 'variant_id': _rice, 'qty_ordered': 100.0, 'qty_received': 0.0, 'unit_cost': 1000},
      {'id': '$_po1-2', 'variant_id': _oil, 'qty_ordered': 20.0, 'qty_received': 0.0, 'unit_cost': 5000},
    ]);
    stock['$_w1|$_rice'] = {'location_id': _w1, 'variant_id': _rice, 'qty_on_hand': 40.0, 'avg_cost': 1000, 'updated_at': old};
  }

  Map<String, dynamic> _po(String id, String no, String status, String at, List<Map<String, dynamic>> items) => {
        'id': id, 'po_no': no, 'warehouse_id': _w1, 'supplier_id': _supA, 'status': status, 'expected_at': null, 'notes': null,
        'updated_at': at, 'items': items,
      };

  /// Something else changes an order on the server (another clerk, the owner on the web).
  void setPoStatus(String id, String status) {
    pos[id]!['status'] = status;
    pos[id]!['updated_at'] = iso(now);
  }

  // ---- push ----
  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    if (offline) throw Exception('no signal');
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      pushed.add(op);
      if (errorOnNextPush > 0) {
        errorOnNextPush--;
        out.add({'op_id': op['op_id'], 'status': 'error', 'code': '40001'});
        return out; // a transient error stops the batch, like the real sync_push
      }
      out.add(_apply(op));
    }
    return out;
  }

  Map<String, dynamic> _apply(Map<String, dynamic> op) {
    final id = op['op_id'] as String;
    final kind = op['kind'] as String;
    final p = (op['payload'] as Map).cast<String, dynamic>();
    if (_seen.containsKey(id)) return {'op_id': id, 'status': 'ok', 'result': {..._seen[id]!, 'replay': true}};
    Map<String, dynamic> reject(String hint) => {'op_id': id, 'status': 'rejected', 'code': 'P0001', 'hint': hint};
    final at = iso(now);
    if (kind == 'receive_po') {
      final po = pos[p['po_id']];
      if (po == null) return reject('not_found');
      if (po['status'] != 'ordered' && po['status'] != 'partly_received') return reject('invalid_state');
      final items = (po['items'] as List).cast<Map<String, dynamic>>();
      for (final l in (p['items'] as List).cast<Map<String, dynamic>>()) {
        final line = items.where((i) => i['variant_id'] == l['variant_id']).toList();
        if (line.isEmpty) return reject('not_on_po');
      }
      for (final l in (p['items'] as List).cast<Map<String, dynamic>>()) {
        final line = items.firstWhere((i) => i['variant_id'] == l['variant_id']);
        line['qty_received'] = (line['qty_received'] as double) + (l['qty'] as num).toDouble();
        _addStock(po['warehouse_id'] as String, l['variant_id'] as String, (l['qty'] as num).toDouble(), at);
      }
      final open = items.any((i) => (i['qty_received'] as double) < (i['qty_ordered'] as double));
      po['status'] = open ? 'partly_received' : 'received';
      po['updated_at'] = at;
      final result = {'grn_id': id, 'grn_no': 'GRN-${++_grn}', 'po_status': po['status'], 'has_discrepancy': false, 'without_po': false, 'applied_at': at};
      _seen[id] = result;
      return {'op_id': id, 'status': 'ok', 'result': result};
    }
    if (kind == 'receive_without_po') {
      for (final l in (p['items'] as List).cast<Map<String, dynamic>>()) {
        _addStock(p['warehouse_id'] as String, l['variant_id'] as String, (l['qty'] as num).toDouble(), at);
      }
      final result = {'grn_id': id, 'grn_no': 'GRN-${++_grn}', 'po_status': null, 'has_discrepancy': false, 'without_po': true, 'applied_at': at};
      _seen[id] = result;
      return {'op_id': id, 'status': 'ok', 'result': result};
    }
    return reject('unknown_kind');
  }

  void _addStock(String wh, String variant, double qty, String at) {
    final k = '$wh|$variant';
    final row = stock[k];
    if (row == null) {
      stock[k] = {'location_id': wh, 'variant_id': variant, 'qty_on_hand': qty, 'avg_cost': null, 'updated_at': at};
    } else {
      row['qty_on_hand'] = (row['qty_on_hand'] as double) + qty;
      row['updated_at'] = at;
    }
  }

  // ---- pull ----
  Map<String, dynamic> _table(List<Map<String, dynamic>> rows, Object? cursor, int limit, String Function(Map<String, dynamic>) key,
      {bool Function(Map<String, dynamic>)? firstPullOnly}) {
    final held = now.subtract(const Duration(seconds: 5));
    final ts = cursor is Map ? DateTime.parse(cursor['ts'] as String) : null;
    final k = cursor is Map ? cursor['k'] as String : null;
    final list = rows.where((r) {
      final at = DateTime.parse(r['updated_at'] as String);
      if (at.isAfter(held)) return false;
      if (ts == null) return firstPullOnly == null || firstPullOnly(r);
      final c = at.compareTo(ts);
      return c > 0 || (c == 0 && key(r).compareTo(k!) > 0);
    }).toList()
      ..sort((a, b) {
        final c = DateTime.parse(a['updated_at'] as String).compareTo(DateTime.parse(b['updated_at'] as String));
        return c != 0 ? c : key(a).compareTo(key(b));
      });
    final page = list.take(limit).toList();
    final last = page.isEmpty ? null : page.last;
    return {
      'rows': [for (final r in page) Map<String, dynamic>.from(r)],
      'cursor': last == null ? cursor : {'ts': last['updated_at'], 'k': key(last)},
      'has_more': list.length > limit,
    };
  }

  @override
  Future<Map<String, dynamic>> pullWarehouse(Map<String, dynamic> cursors, {int limit = 500}) async {
    pullCalls++;
    pullCursors.add(Map<String, dynamic>.from(cursors));
    if (offline || failPull) throw Exception('server error');
    if (moduleOff) return <String, dynamic>{};
    return {
      'server_time': iso(now),
      'warehouses': _table(warehouses, cursors['warehouses'], limit, (r) => r['id'] as String),
      'bins': _table(const [], cursors['bins'], limit, (r) => r['id'] as String),
      'bin_stock_levels': _table(const [], cursors['bin_stock_levels'], limit, (r) => r['bin_id'] as String),
      'stock_levels': _table(stock.values.toList(), cursors['stock_levels'], limit, (r) => '${r['location_id']}|${r['variant_id']}'),
      'suppliers': _table(suppliers, cursors['suppliers'], limit, (r) => r['id'] as String),
      'purchase_orders': _table(pos.values.where((p) => p['status'] != 'draft').toList(), cursors['purchase_orders'], limit,
          (r) => r['id'] as String,
          firstPullOnly: (r) => r['status'] == 'ordered' || r['status'] == 'partly_received'),
    };
  }

  // the store's own pulls: counted so a warehouse-only phone can be shown not to make them
  @override
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async {
    storePullCalls++;
    return {};
  }

  @override
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100}) async {
    storePullCalls++;
    return {'rows': <dynamic>[], 'has_more': false};
  }

  @override
  Future<Map<String, dynamic>> pullExpenses(Map<String, dynamic>? cursor, {int limit = 100}) async {
    storePullCalls++;
    return {'rows': <dynamic>[], 'has_more': false};
  }

  @override
  Future<Map<String, dynamic>> pullDayCloses(Map<String, dynamic>? cursor, {int limit = 100}) async {
    storePullCalls++;
    return {'rows': <dynamic>[], 'has_more': false};
  }

  @override
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100}) async {
    storePullCalls++;
    return {'rows': <dynamic>[], 'has_more': false};
  }

  @override
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100}) async {
    storePullCalls++;
    return {'rows': <dynamic>[], 'has_more': false};
  }
}

Future<T> _first<T>(Stream<T> s) => s.first;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;
  late FakeWarehouseServer server;
  late SyncEngine engine;

  SyncEngine makeEngine({bool pullsStore = false, bool pullsWarehouse = true, int pageLimit = 500}) =>
      SyncEngine(store, server, pullsStore: pullsStore, pullsWarehouse: pullsWarehouse, pageLimit: pageLimit, idleInterval: const Duration(hours: 1), pokeDelay: const Duration(hours: 1));

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    server = FakeWarehouseServer()..seed();
    engine = makeEngine();
    await store.ensureTenant('tenant-a', baseCurrency: 'PHP');
  });
  tearDown(() async {
    engine.dispose();
    await store.close();
  });

  // numbers a clerk sees
  Future<double> riceLeft() async => (await _first(store.watchOpenPurchaseOrders(_w1))).single.items.firstWhere((i) => i.variantId == _rice).remaining;
  Future<double> riceStock() async => (await _first(store.watchWarehouseStock(_w1))).firstWhere((r) => r.variantId == _rice).qty;
  Future<bool> hasPending() async => (await _first(store.watchOpenPurchaseOrders(_w1))).single.hasPending;
  Map<String, dynamic> push(String id) => server.pushed.firstWhere((o) => o['op_id'] == id);

  group('what a phone pulls', () {
    test('a warehouse phone fills its store from the pull', () async {
      await engine.syncNow();
      expect(engine.status.value.phase, SyncPhase.idle);
      expect((await _first(store.watchWarehouses())).map((w) => w.code), ['W1']);
      expect((await _first(store.watchSuppliers())).map((s) => s.name), ['Mega Rice Trading']);
      expect((await _first(store.watchOpenPurchaseOrders(_w1))).map((p) => p.poNo), ['PO-1']);
      expect(await riceStock(), 40);
    });

    test('a store phone never asks for warehouse data', () async {
      engine.dispose();
      engine = makeEngine(pullsStore: true, pullsWarehouse: false);
      await engine.syncNow();
      expect(server.pullCalls, 0);
      expect(await _first(store.watchWarehouses()), isEmpty);
    });

    test('a warehouse phone skips the store pulls (it has no store), but still gets the catalog', () async {
      await engine.syncNow();
      expect(server.storePullCalls, 0);
      expect(server.pulledWith, isNotEmpty, reason: 'product names and barcodes come from the catalog pull');
    });

    test('a phone for a store AND a warehouse does both', () async {
      engine.dispose();
      engine = makeEngine(pullsStore: true, pullsWarehouse: true);
      await engine.syncNow();
      expect(server.storePullCalls, greaterThan(0));
      expect(server.pullCalls, greaterThan(0));
    });

    test('cursors are kept and sent on the next pull, so only changes come back', () async {
      await engine.syncNow();
      expect(server.pullCursors.first, isEmpty);
      await engine.syncNow();
      expect(server.pullCursors.last.keys, containsAll(['warehouses', 'stock_levels', 'suppliers', 'purchase_orders']));
    });

    test('a long pull is fetched page by page until it is complete', () async {
      for (var i = 0; i < 5; i++) {
        server.suppliers.add({'id': 's$i', 'name': 'Supplier $i', 'contact_name': null, 'phone': null, 'email': null, 'notes': null,
            'updated_at': server.iso(server.now.subtract(Duration(minutes: 10 - i))), 'deleted_at': null});
      }
      engine.dispose();
      engine = makeEngine(pageLimit: 2);
      await engine.syncNow();
      expect(await _first(store.watchSuppliers()), hasLength(6));
      expect(server.pullCalls, 3, reason: '6 suppliers at 2 per page = 3 calls');
    });

    test('a server that has switched the warehouse module off does not leave the phone stuck', () async {
      server.moduleOff = true;
      await engine.syncNow();
      expect(engine.status.value.phase, SyncPhase.idle);
    });
  });

  group('who pulls what', () {
    test('only a warehouse clerk pulls warehouse data, and then no store data', () {
      expect(syncScopeForRole('warehouse'), (store: false, warehouse: true));
    });

    test('everyone else pulls store data and never asks for warehouse data', () {
      for (final role in ['superadmin', 'admin', 'cashier', null, 'something-new']) {
        expect(syncScopeForRole(role), (store: true, warehouse: false), reason: '$role');
      }
    });
  });

  group('a receipt made offline', () {
    test('is queued, shown at once, sent when the signal returns, and the numbers stay right at every step', () async {
      await engine.syncNow(); // the phone has the order
      server.offline = true;
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 60, unitCost: 1050)], deliveryRef: 'DR-1', opId: 'op-1');
      // 1. offline: shown at once
      expect(await riceLeft(), 40);
      expect(await riceStock(), 100);
      await engine.syncNow();
      expect(engine.status.value.phase, SyncPhase.offline);
      expect((await store.nextOps()).map((o) => o.opId), ['op-1'], reason: 'still queued');
      expect(await riceLeft(), 40, reason: 'nothing changed on screen while offline');

      // 2. the signal returns at 09:00:00 server time: the server applies it, answers, and the phone pulls
      server.offline = false;
      server.now = DateTime.utc(2026, 11, 9, 9, 0, 0);
      await engine.syncNow();
      expect(await store.nextOps(), isEmpty, reason: 'the server has it');
      final r = (await _first(store.watchReceipts(_w1))).single;
      expect((r.confirmed, r.grnNo), (true, 'GRN-1'));
      // the pull happened right after the receipt: the server holds the new rows back for 5 s, so our effect still counts
      expect(await hasPending(), true);
      expect(await riceLeft(), 40, reason: 'no dip and no jump');
      expect(await riceStock(), 100);

      // 3. a moment later the server's rows arrive: the effect is dropped and the numbers are the server's, not doubled
      server.now = DateTime.utc(2026, 11, 9, 9, 0, 10);
      await engine.syncNow();
      expect(await hasPending(), false);
      expect(await riceLeft(), 40);
      expect(await riceStock(), 100);
      expect((await _first(store.watchOpenPurchaseOrders(_w1))).single.status, 'partly_received');
    });

    test('the server receives exactly what the clerk entered, and the receipt id is the op id', () async {
      await engine.syncNow();
      await store.receiveAgainstPo(
          poId: _po1,
          lines: const [ReceiptLine(variantId: _rice, qty: 60, unitCost: 1050), ReceiptLine(variantId: _oil, qty: 5)],
          deliveryRef: 'DR-9',
          notes: 'dock 3',
          opId: 'op-1');
      await engine.syncNow();
      final op = push('op-1');
      expect(op['kind'], 'receive_po');
      expect(op['payload'], {
        'po_id': _po1,
        'items': [
          {'variant_id': _rice, 'qty': 60.0, 'unit_cost': 1050},
          {'variant_id': _oil, 'qty': 5.0},
        ],
        'notes': 'dock 3',
        'delivery_ref': 'DR-9',
      });
    });

    test('a walk-in goes the same way', () async {
      await engine.syncNow();
      server.now = DateTime.utc(2026, 11, 9, 9, 0, 0);
      await store.receiveWithoutPo(warehouseId: _w1, supplierId: _supA, lines: const [ReceiptLine(variantId: _salt, qty: 7)], deliveryRef: 'WALK-1', opId: 'op-w');
      await engine.syncNow();
      expect(push('op-w')['kind'], 'receive_without_po');
      expect((await _first(store.watchWarehouseStock(_w1))).firstWhere((r) => r.variantId == _salt).qty, 7);
      server.now = DateTime.utc(2026, 11, 9, 9, 0, 10);
      await engine.syncNow();
      final salt = (await _first(store.watchWarehouseStock(_w1))).firstWhere((r) => r.variantId == _salt);
      expect((salt.qty, salt.pending), (7.0, 0.0), reason: 'the server row replaced the effect: not 14');
    });

    test('sending it twice is harmless: the server says replay and the phone settles it once', () async {
      await engine.syncNow();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 60)], opId: 'op-1');
      await engine.syncNow();
      // the phone lost the answer: it queues the same op again (as a retry after a dropped connection would)
      await store.db.into(store.db.outbox).insert(OutboxCompanion.insert(
          opId: 'op-1-again', kind: 'receive_po', entityId: _po1, payload: '{}', createdAt: DateTime.now().toUtc()));
      await store.db.customStatement("update outbox set op_id = 'op-1', payload = ? where op_id = 'op-1-again'",
          ['{"po_id":"$_po1","items":[{"variant_id":"$_rice","qty":60.0}]}']);
      await engine.syncNow();
      expect(await store.nextOps(), isEmpty);
      server.now = DateTime.utc(2026, 11, 9, 9, 0, 20);
      await engine.syncNow();
      expect(await riceLeft(), 40, reason: 'received once, not twice');
      expect(await riceStock(), 100);
    });

    test('two receipts queued offline are sent in order and both settle', () async {
      await engine.syncNow();
      server.offline = true;
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 30)], opId: 'op-1');
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 25)], opId: 'op-2');
      await engine.syncNow();
      server.offline = false;
      await engine.syncNow();
      expect(server.pushed.map((o) => o['op_id']), ['op-1', 'op-2']);
      server.now = DateTime.utc(2026, 11, 9, 9, 0, 30);
      await engine.syncNow();
      expect(await hasPending(), false);
      expect(await riceLeft(), 45);
      expect(await riceStock(), 95);
    });

    test('a product change queued before a receipt is sent before it', () async {
      await engine.syncNow();
      await store.saveProduct(
          const ProductDraft(id: 'f0000000-0000-4000-8000-000000000001', variantId: 'f1000000-0000-4000-8000-000000000001', name: 'Kape', price: 1000),
          opId: 'op-product');
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 1)], opId: 'op-receipt');
      await engine.syncNow();
      expect([for (final c in server.calls) c.split(':').first], ['upsert'], reason: 'the product op used its own call');
      expect(server.pushed.map((o) => o['op_id']), ['op-receipt']);
      expect(await store.nextOps(), isEmpty);
    });
  });

  group('refusals and trouble', () {
    test('a receipt the server refuses is parked with its reason, keeps counting until the clerk decides, and does not block others', () async {
      await engine.syncNow();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 60)], opId: 'op-1');
      await store.receiveWithoutPo(warehouseId: _w1, lines: const [ReceiptLine(variantId: _salt, qty: 3)], opId: 'op-2');
      server.setPoStatus(_po1, 'cancelled'); // the owner cancelled the order on the web meanwhile
      await engine.syncNow();
      final failed = await store.failedOps();
      expect([for (final o in failed) (o.opId, o.lastError)], [('op-1', 'invalid_state')]);
      expect(await store.nextOps(), isEmpty, reason: 'the walk-in behind it was still sent');
      expect(push('op-2')['kind'], 'receive_without_po');
      expect((await _first(store.watchReceipts(_w1))).where((r) => r.opId == 'op-1').single.confirmed, false);
      // the clerk discards it: the effect goes, and the next pull brings the server's own numbers
      await store.discardFailed('op-1');
      server.now = DateTime.utc(2026, 11, 9, 9, 1, 0);
      await engine.syncNow();
      expect(await _first(store.watchOpenPurchaseOrders(_w1)), isEmpty, reason: 'the order is cancelled on the server, so it is gone');
      expect((await _first(store.watchReceipts(_w1))).map((r) => r.opId), ['op-2']);
    });

    test('a transient server error stops the batch and keeps every op queued, in order', () async {
      await engine.syncNow();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 30)], opId: 'op-1');
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 25)], opId: 'op-2');
      server.errorOnNextPush = 1;
      await engine.syncNow();
      expect(engine.status.value.phase, SyncPhase.offline);
      expect((await store.nextOps()).map((o) => o.opId), ['op-1', 'op-2']);
      expect(await store.failedOps(), isEmpty, reason: 'a transient error is not a refusal');
      await engine.syncNow();
      expect(await store.nextOps(), isEmpty);
      expect(server.pushed.where((o) => o['op_id'] == 'op-1').length, 2, reason: 'sent again with the same op id');
    });

    test('a pull that fails after the push does not lose the receipt: confirmed, not yet settled, settled next time', () async {
      await engine.syncNow();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 60)], opId: 'op-1');
      server.failPull = true;
      await engine.syncNow();
      expect(engine.status.value.phase, SyncPhase.offline);
      expect((await _first(store.watchReceipts(_w1))).single.grnNo, 'GRN-1', reason: 'the push succeeded and was recorded');
      expect(await riceLeft(), 40);
      server.failPull = false;
      server.now = DateTime.utc(2026, 11, 9, 9, 0, 30);
      await engine.syncNow();
      expect(await hasPending(), false);
      expect(await riceLeft(), 40);
      expect(await riceStock(), 100);
    });

    test('another clerk\'s receipt on the same order is added to ours, not mixed up with it', () async {
      await engine.syncNow();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 30)], opId: 'op-1');
      // before our phone sends anything, someone else received 20 on the server
      server.pos[_po1]!['items'][0]['qty_received'] = 20.0;
      server.pos[_po1]!['status'] = 'partly_received';
      server.pos[_po1]!['updated_at'] = server.iso(DateTime.utc(2026, 11, 9, 8, 59, 0));
      server.stock['$_w1|$_rice']!['qty_on_hand'] = 60.0;
      server.stock['$_w1|$_rice']!['updated_at'] = server.iso(DateTime.utc(2026, 11, 9, 8, 59, 0));
      server.offline = true;
      await engine.syncNow(); // offline: only a failed attempt
      server.offline = false;
      await store.opFailed('op-1', 'x'); // (parking and un-parking is not what is under test)
      await store.db.customStatement("update outbox set status = 'pending' where op_id = 'op-1'");
      await engine.syncNow();
      server.now = DateTime.utc(2026, 11, 9, 9, 1, 0);
      await engine.syncNow();
      expect(await riceLeft(), 50, reason: '100 ordered - 20 (other clerk) - 30 (ours)');
      expect(await riceStock(), 40 + 20 + 30);
      expect(await hasPending(), false);
    });
  });
}
