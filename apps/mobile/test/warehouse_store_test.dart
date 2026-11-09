import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/data/warehouse_models.dart';

const _w1 = 'w1000000-0000-4000-8000-000000000001';
const _w2 = 'w2000000-0000-4000-8000-000000000002';
const _supA = 'a0000000-0000-4000-8000-0000000000a1';
const _po1 = 'p1000000-0000-4000-8000-000000000001';
const _po2 = 'p2000000-0000-4000-8000-000000000002';
const _rice = 'v1000000-0000-4000-8000-000000000001';
const _oil = 'v2000000-0000-4000-8000-000000000002';
const _salt = 'v3000000-0000-4000-8000-000000000003';
const _binRcv = 'b1000000-0000-4000-8000-000000000001';
const _binA = 'b2000000-0000-4000-8000-000000000002';

// a pulled table: rows, the cursor after them, and whether more is waiting
Map<String, dynamic> _t(List<Map<String, dynamic>> rows, {bool more = false, String? ts}) => {
      'rows': rows,
      'cursor': rows.isEmpty ? null : {'ts': ts ?? '2026-11-09T09:00:00Z', 'k': 'k${rows.length}'},
      'has_more': more,
    };

Map<String, dynamic> _pull({
  List<Map<String, dynamic>> warehouses = const [],
  List<Map<String, dynamic>> bins = const [],
  List<Map<String, dynamic>> binStock = const [],
  List<Map<String, dynamic>> stock = const [],
  List<Map<String, dynamic>> suppliers = const [],
  List<Map<String, dynamic>> pos = const [],
  String serverTime = '2026-11-09T10:00:00Z',
  bool more = false,
}) =>
    {
      'server_time': serverTime,
      'warehouses': _t(warehouses, more: more),
      'bins': _t(bins),
      'bin_stock_levels': _t(binStock),
      'stock_levels': _t(stock),
      'suppliers': _t(suppliers),
      'purchase_orders': _t(pos),
    };

Map<String, dynamic> _wh(String id, String code, {bool bins = false, bool active = true, String? deletedAt}) => {
      'id': id, 'code': code, 'name': 'Warehouse $code', 'bins_enabled': bins, 'active': active,
      'updated_at': '2026-11-09T09:00:00Z', 'deleted_at': deletedAt,
    };

Map<String, dynamic> _sup(String id, String name, {String? deletedAt}) => {
      'id': id, 'name': name, 'contact_name': 'Ana', 'phone': '0917', 'email': null, 'notes': null,
      'updated_at': '2026-11-09T09:00:00Z', 'deleted_at': deletedAt,
    };

Map<String, dynamic> _bin(String id, String wh, String code, {String? deletedAt}) => {
      'id': id, 'warehouse_id': wh, 'zone_id': null, 'code': code, 'aisle': null, 'rack': null, 'shelf': null, 'position': null,
      'type': 'shelf', 'max_qty': null, 'active': true, 'updated_at': '2026-11-09T09:00:00Z', 'deleted_at': deletedAt,
    };

Map<String, dynamic> _stock(String wh, String variant, num qty, {String at = '2026-11-09T09:00:00Z'}) =>
    {'location_id': wh, 'variant_id': variant, 'qty_on_hand': qty, 'avg_cost': 1000, 'updated_at': at};

Map<String, dynamic> _binStock(String bin, String variant, num qty) =>
    {'bin_id': bin, 'variant_id': variant, 'qty_on_hand': qty, 'updated_at': '2026-11-09T09:00:00Z'};

Map<String, dynamic> _po(String id, String no, String wh, {String status = 'ordered', String at = '2026-11-09T09:00:00Z', List<Map<String, dynamic>>? items}) => {
      'id': id, 'po_no': no, 'warehouse_id': wh, 'supplier_id': _supA, 'status': status, 'expected_at': null, 'notes': null,
      'updated_at': at,
      'items': items ??
          [
            {'id': '$id-i1', 'variant_id': _rice, 'qty_ordered': 100, 'qty_received': 0, 'unit_cost': 1000},
            {'id': '$id-i2', 'variant_id': _oil, 'qty_ordered': 20, 'qty_received': 0, 'unit_cost': 5000},
          ],
    };

Future<T> _first<T>(Stream<T> s) => s.first;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;

  setUp(() {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
  });
  tearDown(() => store.close());

  Future<void> loadBasics({bool bins = false}) => store.applyPullWarehouse(_pull(
        warehouses: [_wh(_w1, 'W1', bins: bins), _wh(_w2, 'W2')],
        bins: bins ? [_bin(_binRcv, _w1, 'RECEIVING'), _bin(_binA, _w1, 'A-01-1')] : const [],
        binStock: bins ? [_binStock(_binRcv, _rice, 40)] : const [],
        stock: [_stock(_w1, _rice, 40), _stock(_w2, _oil, 5)],
        suppliers: [_sup(_supA, 'Mega Rice Trading')],
        pos: [_po(_po1, 'PO-1', _w1), _po(_po2, 'PO-2', _w2)],
      ));

  group('applyPullWarehouse and the reads', () {
    test('warehouses: active ones by code, with whether they use bins', () async {
      await store.applyPullWarehouse(_pull(warehouses: [
        _wh(_w2, 'W2', bins: true),
        _wh(_w1, 'W1'),
        _wh('w3', 'W3', active: false),
        _wh('w4', 'W4', deletedAt: '2026-11-09T08:00:00Z'),
      ]));
      final list = await _first(store.watchWarehouses());
      expect([for (final w in list) (w.code, w.binsEnabled)], [('W1', false), ('W2', true)]);
    });

    test('bins and suppliers: archived ones are hidden, the rest sorted', () async {
      await store.applyPullWarehouse(_pull(
        bins: [_bin('b3', _w1, 'Z-9'), _bin(_binA, _w1, 'A-01-1'), _bin('b4', _w1, 'OLD', deletedAt: '2026-11-09T08:00:00Z'), _bin('b5', _w2, 'ELSEWHERE')],
        suppliers: [_sup('s2', 'Zed Foods'), _sup(_supA, 'Mega Rice Trading'), _sup('s3', 'Gone', deletedAt: '2026-11-09T08:00:00Z')],
      ));
      expect([for (final b in await _first(store.watchBins(_w1))) b.code], ['A-01-1', 'Z-9']);
      expect([for (final s in await _first(store.watchSuppliers())) s.name], ['Mega Rice Trading', 'Zed Foods']);
    });

    test('open orders of one warehouse, with lines, supplier name and what is left to receive', () async {
      await loadBasics();
      final list = await _first(store.watchOpenPurchaseOrders(_w1));
      expect(list.map((p) => p.poNo), ['PO-1']);
      final po = list.single;
      expect(po.supplierName, 'Mega Rice Trading');
      expect([for (final i in po.items) (i.variantId, i.ordered, i.received, i.remaining)], [(_rice, 100.0, 0.0, 100.0), (_oil, 20.0, 0.0, 20.0)]);
      expect(po.remainingTotal, 120);
      expect(po.completeHere, false);
      expect(po.hasPending, false);
    });

    test('an order that was received or cancelled on the server leaves the open list, and the device forgets it', () async {
      await loadBasics();
      await store.applyPullWarehouse(_pull(pos: [_po(_po1, 'PO-1', _w1, status: 'received', at: '2026-11-09T09:30:00Z')]));
      expect(await _first(store.watchOpenPurchaseOrders(_w1)), isEmpty);
      expect(await store.purchaseOrder(_po1), isNull, reason: 'finished orders are not kept');
      await store.applyPullWarehouse(_pull(pos: [_po(_po2, 'PO-2', _w2, status: 'cancelled', at: '2026-11-09T09:40:00Z')]));
      expect(await _first(store.watchOpenPurchaseOrders(_w2)), isEmpty);
    });

    test('a pulled order replaces its lines instead of adding to them', () async {
      await loadBasics();
      await store.applyPullWarehouse(_pull(pos: [
        _po(_po1, 'PO-1', _w1, status: 'partly_received', at: '2026-11-09T09:30:00Z', items: [
          {'id': 'x1', 'variant_id': _rice, 'qty_ordered': 100, 'qty_received': 60, 'unit_cost': 1000},
        ]),
      ]));
      final po = (await _first(store.watchOpenPurchaseOrders(_w1))).single;
      expect(po.status, 'partly_received');
      expect([for (final i in po.items) (i.variantId, i.received, i.remaining)], [(_rice, 60.0, 40.0)]);
    });

    test('warehouse stock and bin stock', () async {
      await loadBasics(bins: true);
      expect([for (final r in await _first(store.watchWarehouseStock(_w1))) (r.variantId, r.qty, r.pending)], [(_rice, 40.0, 0.0)]);
      expect([for (final r in await _first(store.watchBinStock(_w1))) (r.binCode, r.variantId, r.qty)], [('RECEIVING', _rice, 40.0)]);
    });

    test('the cursors are kept under their own names, apart from the store pull', () async {
      await store.db.into(store.db.syncCursors).insert(SyncCursorsCompanion.insert(tableKey: 'stock_levels', cursorJson: jsonEncode({'ts': 'pos', 'k': 'pos'})));
      await loadBasics();
      final c = await store.warehouseCursors();
      expect(c.keys.toSet(), {'warehouses', 'stock_levels', 'suppliers', 'purchase_orders'}, reason: 'a table with no rows has no cursor yet');
      expect(c['stock_levels'], {'ts': '2026-11-09T09:00:00Z', 'k': 'k2'});
      expect((await store.cursors())['stock_levels'], {'ts': 'pos', 'k': 'pos'}, reason: 'the store pull\'s cursor is untouched');
    });

    test('an empty page keeps the cursor it had', () async {
      await loadBasics();
      final before = await store.warehouseCursors();
      await store.applyPullWarehouse(_pull());
      expect(await store.warehouseCursors(), before);
    });
  });

  group('the active warehouse', () {
    test('with no warehouse yet there is none', () async {
      expect(await store.activeWarehouse(), isNull);
      expect(await _first(store.watchActiveWarehouse()), isNull);
    });

    test('with several, the first by code until the clerk chooses; the choice is remembered', () async {
      await loadBasics();
      expect((await store.activeWarehouse())!.code, 'W1');
      await store.setActiveWarehouse(_w2);
      expect((await store.activeWarehouse())!.code, 'W2');
      expect((await _first(store.watchActiveWarehouse()))!.id, _w2);
      expect(await store.meta('active_warehouse_id'), _w2);
    });

    test('the stream follows a change at once', () async {
      await loadBasics();
      final seen = <String?>[];
      final sub = store.watchActiveWarehouse().listen((w) => seen.add(w?.code));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.setActiveWarehouse(_w2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(seen.first, 'W1');
      expect(seen.last, 'W2');
    });

    test('unrelated changes to the device notes do not re-announce the same warehouse', () async {
      await loadBasics();
      var emitted = 0;
      final sub = store.watchActiveWarehouse().listen((_) => emitted++);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.setMeta('something_else', 'x');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(emitted, 1);
    });

    test('a remembered warehouse the user no longer has falls back to the first one', () async {
      await loadBasics();
      await store.setActiveWarehouse(_w2);
      await store.applyPullWarehouse(_pull(warehouses: [_wh(_w2, 'W2', deletedAt: '2026-11-09T10:00:00Z')]));
      expect((await store.activeWarehouse())!.code, 'W1');
    });

    test('an unknown warehouse cannot be chosen', () async {
      await loadBasics();
      await store.setActiveWarehouse('nope');
      expect((await store.activeWarehouse())!.code, 'W1');
      expect(await store.meta('active_warehouse_id'), isNull);
    });

    test('signing in to another business forgets the choice', () async {
      await store.ensureTenant('tenant-a', baseCurrency: 'PHP');
      await loadBasics();
      await store.setActiveWarehouse(_w2);
      await store.ensureTenant('tenant-b', baseCurrency: 'PHP', discardUnsent: true);
      expect(await store.meta('active_warehouse_id'), isNull);
      expect(await store.activeWarehouse(), isNull);
    });
  });

  group('receiving against an order', () {
    test('queues receive_po with the exact payload, and the op id is the receipt id', () async {
      await loadBasics();
      await store.receiveAgainstPo(
        poId: _po1,
        lines: const [ReceiptLine(variantId: _rice, qty: 60, unitCost: 1050), ReceiptLine(variantId: _oil, qty: 5)],
        deliveryRef: 'DR-9',
        notes: 'dock 3',
        opId: 'op-1',
      );
      final ops = await store.nextOps();
      expect(ops.map((o) => o.kind), ['receive_po']);
      expect(ops.single.opId, 'op-1');
      expect(ops.single.entityId, _po1);
      expect(ops.single.payload, {
        'po_id': _po1,
        'items': [
          {'variant_id': _rice, 'qty': 60.0, 'unit_cost': 1050},
          {'variant_id': _oil, 'qty': 5.0},
        ],
        'notes': 'dock 3',
        'delivery_ref': 'DR-9',
      });
    });

    test('blank notes and delivery number are left out', () async {
      await loadBasics();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 1)], deliveryRef: '  ', notes: '', opId: 'op-1');
      expect((await store.nextOps()).single.payload.keys.toSet(), {'po_id', 'items'});
    });

    test('the order shows what is left at once, and stock rises at once', () async {
      await loadBasics();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 60)], opId: 'op-1');
      final po = (await _first(store.watchOpenPurchaseOrders(_w1))).single;
      final rice = po.items.firstWhere((i) => i.variantId == _rice);
      expect((rice.receivedOnServer, rice.pending, rice.received, rice.remaining), (0.0, 60.0, 60.0, 40.0));
      expect(po.hasPending, true);
      expect(po.status, 'ordered', reason: 'the status is the server\'s until it answers');
      final stock = (await _first(store.watchWarehouseStock(_w1))).firstWhere((r) => r.variantId == _rice);
      expect((stock.qty, stock.pending), (100.0, 60.0));
    });

    test('two receipts add up', () async {
      await loadBasics();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 30)], opId: 'op-1');
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 25)], opId: 'op-2');
      final po = (await _first(store.watchOpenPurchaseOrders(_w1))).single;
      expect(po.items.firstWhere((i) => i.variantId == _rice).remaining, 45);
      expect((await _first(store.watchWarehouseStock(_w1))).firstWhere((r) => r.variantId == _rice).qty, 95);
    });

    test('over-delivery is allowed; what is left never goes below zero', () async {
      await loadBasics();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 130), ReceiptLine(variantId: _oil, qty: 20)], opId: 'op-1');
      final po = (await _first(store.watchOpenPurchaseOrders(_w1))).single;
      expect(po.items.firstWhere((i) => i.variantId == _rice).remaining, 0);
      expect(po.remainingTotal, 0);
      expect(po.completeHere, true);
      expect((await _first(store.watchWarehouseStock(_w1))).firstWhere((r) => r.variantId == _rice).qty, 170);
    });

    test('with bins, the goods show in the RECEIVING bin until the server copy arrives', () async {
      await loadBasics(bins: true);
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 60)], opId: 'op-1');
      final bins = await _first(store.watchBinStock(_w1));
      expect([for (final b in bins) (b.binCode, b.variantId, b.qty)], [('RECEIVING', _rice, 100.0)]);
    });

    test('a new product received into a bin warehouse appears in RECEIVING too', () async {
      await loadBasics(bins: true);
      await store.receiveWithoutPo(warehouseId: _w1, lines: const [ReceiptLine(variantId: _salt, qty: 7)], opId: 'op-1');
      final bins = await _first(store.watchBinStock(_w1));
      expect({for (final b in bins) b.variantId: b.qty}, {_rice: 40.0, _salt: 7.0});
    });

    test('nothing is recorded or queued when a check fails', () async {
      await loadBasics();
      Future<String> code(Future<void> Function() f) async {
        try {
          await f();
          return 'no error';
        } on WarehouseReceiptException catch (e) {
          return e.code;
        }
      }

      const ok = ReceiptLine(variantId: _rice, qty: 1);
      expect(await code(() => store.receiveAgainstPo(poId: 'nope', lines: const [ok], opId: 'e1')), 'unknown_order');
      expect(await code(() => store.receiveAgainstPo(poId: _po1, lines: const [], opId: 'e2')), 'no_lines');
      expect(await code(() => store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _salt, qty: 1)], opId: 'e3')), 'not_on_order');
      expect(await code(() => store.receiveAgainstPo(poId: _po1, lines: const [ok, ok], opId: 'e4')), 'duplicate_line');
      expect(await code(() => store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 0)], opId: 'e5')), 'qty_invalid');
      expect(await code(() => store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: -2)], opId: 'e6')), 'qty_invalid');
      expect(await code(() => store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: double.nan)], opId: 'e7')), 'qty_invalid');
      expect(await code(() => store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 1000000000)], opId: 'e8')), 'qty_invalid');
      expect(await code(() => store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 1, unitCost: -5)], opId: 'e9')), 'cost_invalid');
      // a good line before a bad one must not be kept
      expect(await code(() => store.receiveAgainstPo(poId: _po1, lines: const [ok, ReceiptLine(variantId: _oil, qty: 0)], opId: 'e10')), 'qty_invalid');
      expect(await store.nextOps(), isEmpty);
      expect((await _first(store.watchOpenPurchaseOrders(_w1))).single.hasPending, false);
      expect(await _first(store.watchReceipts(_w1)), isEmpty);
    });

    test('an order that is no longer open on the server cannot be received', () async {
      await loadBasics();
      await store.db.customStatement("update purchase_orders set status = 'cancelled' where id = '$_po1'");
      await expectLater(
          store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 1)], opId: 'e1'),
          throwsA(isA<WarehouseReceiptException>().having((e) => e.code, 'code', 'order_closed')));
    });

    test('the receipt list shows what was received here, newest first, until the server number arrives', () async {
      await loadBasics();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 10)], deliveryRef: 'DR-1', opId: 'op-1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await store.receiveWithoutPo(warehouseId: _w1, supplierId: _supA, lines: const [ReceiptLine(variantId: _salt, qty: 3, unitCost: 300)], opId: 'op-2');
      final list = await _first(store.watchReceipts(_w1));
      expect([for (final r in list) (r.opId, r.kind, r.poNo, r.confirmed, r.grnNo)], [('op-2', 'walkin', null, false, null), ('op-1', 'po', 'PO-1', false, null)]);
      expect(list.last.deliveryRef, 'DR-1');
      expect([for (final l in list.first.lines) (l.variantId, l.qty, l.unitCost)], [(_salt, 3.0, 300)]);
      expect(await _first(store.watchReceipts(_w2)), isEmpty, reason: 'receipts belong to their warehouse');
    });
  });

  group('receiving without an order', () {
    test('queues receive_without_po and raises stock at once', () async {
      await loadBasics();
      await store.receiveWithoutPo(
        warehouseId: _w1,
        supplierId: _supA,
        lines: const [ReceiptLine(variantId: _salt, qty: 7, unitCost: 300)],
        deliveryRef: 'WALK-1',
        opId: 'op-1',
      );
      final op = (await store.nextOps()).single;
      expect(op.kind, 'receive_without_po');
      expect(op.entityId, _w1);
      expect(op.payload, {
        'warehouse_id': _w1,
        'supplier_id': _supA,
        'items': [
          {'variant_id': _salt, 'qty': 7.0, 'unit_cost': 300}
        ],
        'delivery_ref': 'WALK-1',
      });
      final salt = (await _first(store.watchWarehouseStock(_w1))).firstWhere((r) => r.variantId == _salt);
      expect((salt.qty, salt.pending), (7.0, 7.0));
    });

    test('the supplier is optional, and an unknown warehouse is refused', () async {
      await loadBasics();
      await store.receiveWithoutPo(warehouseId: _w2, lines: const [ReceiptLine(variantId: _oil, qty: 2)], opId: 'op-1');
      expect((await store.nextOps()).single.payload.containsKey('supplier_id'), false);
      await expectLater(
          store.receiveWithoutPo(warehouseId: 'nope', lines: const [ReceiptLine(variantId: _oil, qty: 2)], opId: 'op-2'),
          throwsA(isA<WarehouseReceiptException>().having((e) => e.code, 'code', 'unknown_warehouse')));
      await expectLater(
          store.receiveWithoutPo(warehouseId: _w2, lines: const [ReceiptLine(variantId: _oil, qty: 2), ReceiptLine(variantId: _oil, qty: 1)], opId: 'op-3'),
          throwsA(isA<WarehouseReceiptException>().having((e) => e.code, 'code', 'duplicate_line')));
    });
  });

  group('acknowledgement and settling', () {
    // 60 of 100 rice received here; the server applied it at 10:00:00 and answered
    Future<void> receiveAndAck({String applied = '2026-11-09T10:00:00Z'}) async {
      await loadBasics();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 60)], opId: 'op-1');
      await store.warehouseOpApplied('op-1', applied, result: {'grn_no': 'GRN-261109-0001'});
      await store.opDone('op-1');
    }

    double riceRemaining(List<PurchaseOrderView> l) => l.single.items.firstWhere((i) => i.variantId == _rice).remaining;
    double riceStock(List<WhStockRow> l) => l.firstWhere((r) => r.variantId == _rice).qty;

    Map<String, dynamic> caughtUp({String serverTime = '2026-11-09T10:01:00Z', bool more = false, String at = '2026-11-09T10:00:00Z'}) => _pull(
          serverTime: serverTime,
          more: more,
          stock: [_stock(_w1, _rice, 100, at: at)],
          pos: [
            _po(_po1, 'PO-1', _w1, status: 'partly_received', at: at, items: [
              {'id': '$_po1-i1', 'variant_id': _rice, 'qty_ordered': 100, 'qty_received': 60, 'unit_cost': 1000},
              {'id': '$_po1-i2', 'variant_id': _oil, 'qty_ordered': 20, 'qty_received': 0, 'unit_cost': 5000},
            ])
          ],
        );

    test('after the server answers, the receipt shows its number and the effect still counts', () async {
      await receiveAndAck();
      final r = (await _first(store.watchReceipts(_w1))).single;
      expect((r.confirmed, r.grnNo), (true, 'GRN-261109-0001'));
      expect(riceRemaining(await _first(store.watchOpenPurchaseOrders(_w1))), 40);
      expect(riceStock(await _first(store.watchWarehouseStock(_w1))), 100);
    });

    test('a pull that has not caught up keeps the effect: the number does not dip or jump', () async {
      await receiveAndAck();
      // the server's copy is still the old one (updated before the receipt)
      await store.applyPullWarehouse(_pull(serverTime: '2026-11-09T10:01:00Z', stock: [_stock(_w1, _rice, 40, at: '2026-11-09T09:59:00Z')]));
      expect(riceRemaining(await _first(store.watchOpenPurchaseOrders(_w1))), 40);
      expect(riceStock(await _first(store.watchWarehouseStock(_w1))), 100);
    });

    test('a pull that has caught up settles the effect, and the numbers are the server\'s (not counted twice)', () async {
      await receiveAndAck();
      await store.applyPullWarehouse(caughtUp());
      final po = (await _first(store.watchOpenPurchaseOrders(_w1))).single;
      expect(po.hasPending, false);
      expect(po.items.firstWhere((i) => i.variantId == _rice).receivedOnServer, 60);
      expect(riceRemaining([po]), 40, reason: 'still 40 left, not 100 - 60 - 60');
      expect(riceStock(await _first(store.watchWarehouseStock(_w1))), 100, reason: 'still 100, not 160');
    });

    test('settled receipts stay in the list, now with their number', () async {
      await receiveAndAck();
      await store.applyPullWarehouse(caughtUp());
      final r = (await _first(store.watchReceipts(_w1))).single;
      expect((r.opId, r.confirmed, r.grnNo), ('op-1', true, 'GRN-261109-0001'));
    });

    test('the server\'s 5 second hold-back is respected: a pull taken right after the receipt does not settle it', () async {
      await receiveAndAck(applied: '2026-11-09T10:00:57Z');
      await store.applyPullWarehouse(caughtUp(serverTime: '2026-11-09T10:01:00Z', at: '2026-11-09T10:00:57Z'));
      expect((await _first(store.watchOpenPurchaseOrders(_w1))).single.hasPending, true);
    });

    test('an unfinished pull (more pages waiting) does not settle anything', () async {
      await receiveAndAck();
      await store.applyPullWarehouse(caughtUp(more: true));
      expect((await _first(store.watchOpenPurchaseOrders(_w1))).single.hasPending, true);
    });

    test('settling needs the order AND the stock to have caught up', () async {
      await receiveAndAck();
      // the order caught up, the stock row did not
      await store.applyPullWarehouse(_pull(serverTime: '2026-11-09T10:01:00Z', pos: [
        _po(_po1, 'PO-1', _w1, status: 'partly_received', at: '2026-11-09T10:00:00Z', items: [
          {'id': '$_po1-i1', 'variant_id': _rice, 'qty_ordered': 100, 'qty_received': 60, 'unit_cost': 1000},
        ]),
      ]));
      expect((await _first(store.watchOpenPurchaseOrders(_w1))).single.hasPending, true);
    });

    test('settling also needs the order itself to have caught up, not just the stock', () async {
      await receiveAndAck();
      // the stock row caught up, the order's copy is still the old one
      await store.applyPullWarehouse(_pull(serverTime: '2026-11-09T10:01:00Z', stock: [_stock(_w1, _rice, 100, at: '2026-11-09T10:00:00Z')]));
      final po = (await _first(store.watchOpenPurchaseOrders(_w1))).single;
      expect(po.hasPending, true);
      expect(riceRemaining([po]), 40, reason: 'still counted once, not twice');
    });

    test('a walk-in settles once the stock row has caught up', () async {
      await loadBasics();
      await store.receiveWithoutPo(warehouseId: _w1, lines: const [ReceiptLine(variantId: _salt, qty: 7)], opId: 'op-1');
      await store.warehouseOpApplied('op-1', '2026-11-09T10:00:00Z', result: {'grn_no': 'GRN-261109-0002'});
      await store.opDone('op-1');
      await store.applyPullWarehouse(_pull(serverTime: '2026-11-09T10:01:00Z', stock: [_stock(_w1, _rice, 40, at: '2026-11-09T09:00:00Z')]));
      expect((await _first(store.watchWarehouseStock(_w1))).firstWhere((r) => r.variantId == _salt).pending, 7);
      await store.applyPullWarehouse(_pull(serverTime: '2026-11-09T10:01:00Z', stock: [_stock(_w1, _salt, 7, at: '2026-11-09T10:00:00Z')]));
      final salt = (await _first(store.watchWarehouseStock(_w1))).firstWhere((r) => r.variantId == _salt);
      expect((salt.qty, salt.pending), (7.0, 0.0));
    });

    test('a receipt the server has not applied is never settled by a pull', () async {
      await loadBasics();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 60)], opId: 'op-1');
      await store.applyPullWarehouse(caughtUp()); // someone else's receipt moved the server copy; ours is still unsent
      final po = (await _first(store.watchOpenPurchaseOrders(_w1))).single;
      expect(po.hasPending, true);
      expect(riceRemaining([po]), 0, reason: '100 ordered - 60 on the server - 60 here');
    });

    test('a confirmed effect that never settles is dropped after a day', () async {
      await receiveAndAck();
      await store.applyPullWarehouse(_pull(serverTime: '2026-11-10T11:00:00Z'));
      expect((await _first(store.watchOpenPurchaseOrders(_w1))).single.hasPending, false);
    });

    test('old settled receipts are cleaned up after 30 days', () async {
      await receiveAndAck();
      await store.applyPullWarehouse(caughtUp());
      await store.applyPullWarehouse(_pull(serverTime: '2026-12-20T10:00:00Z'));
      expect(await _first(store.watchReceipts(_w1)), isEmpty);
    });

    test('a finished order is kept while one of its receipts is unsettled, then forgotten', () async {
      await receiveAndAck();
      final finished = _pull(serverTime: '2026-11-09T10:01:00Z', stock: [_stock(_w1, _rice, 100, at: '2026-11-09T10:00:00Z')], pos: [
        _po(_po1, 'PO-1', _w1, status: 'received', at: '2026-11-09T10:00:00Z', items: [
          {'id': '$_po1-i1', 'variant_id': _rice, 'qty_ordered': 100, 'qty_received': 100, 'unit_cost': 1000},
        ])
      ]);
      await store.applyPullWarehouse(finished);
      expect(await _first(store.watchOpenPurchaseOrders(_w1)), isEmpty);
      expect(await store.purchaseOrder(_po1), isNull, reason: 'settled in the same pull, so nothing keeps the order');
    });
  });

  group('finished orders and unsettled receipts', () {
    test('a finished order is kept while a receipt that depends on it is not settled, then forgotten', () async {
      await loadBasics();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 100), ReceiptLine(variantId: _oil, qty: 20)], opId: 'op-1');
      await store.warehouseOpApplied('op-1', '2026-11-09T10:00:00Z', result: {'grn_no': 'GRN-1'});
      await store.opDone('op-1');
      // the order is already finished on the server, but the stock rows have not caught up yet: the receipt is unsettled
      Map<String, dynamic> finished(Map<String, dynamic> stockRows) => _pull(serverTime: '2026-11-09T10:01:00Z', pos: [
            _po(_po1, 'PO-1', _w1, status: 'received', at: '2026-11-09T10:00:00Z', items: [
              {'id': '$_po1-i1', 'variant_id': _rice, 'qty_ordered': 100, 'qty_received': 100, 'unit_cost': 1000},
              {'id': '$_po1-i2', 'variant_id': _oil, 'qty_ordered': 20, 'qty_received': 20, 'unit_cost': 5000},
            ])
          ])..addAll(stockRows);
      await store.applyPullWarehouse(finished({}));
      expect(await store.purchaseOrder(_po1), isNotNull, reason: 'the receipt still needs the order to judge "caught up"');
      expect(await _first(store.watchOpenPurchaseOrders(_w1)), isEmpty, reason: 'but it is not listed as open');
      await store.applyPullWarehouse(finished({
        'stock_levels': _t([_stock(_w1, _rice, 140, at: '2026-11-09T10:00:00Z'), _stock(_w1, _oil, 20, at: '2026-11-09T10:00:00Z')])
      }));
      expect(await store.purchaseOrder(_po1), isNull);
    });
  });

  group('a pull without a cursor is a snapshot of the open orders', () {
    // the server's first pull sends only open orders, so an order that finished meanwhile is simply not mentioned
    Future<void> resetCursors() => store.db.delete(store.db.syncCursors).go();

    test('an order the snapshot no longer lists is forgotten', () async {
      await loadBasics();
      await resetCursors();
      await store.applyPullWarehouse(_pull(pos: [_po(_po2, 'PO-2', _w2)]));
      expect(await store.purchaseOrder(_po1), isNull, reason: 'finished elsewhere: gone');
      expect((await _first(store.watchOpenPurchaseOrders(_w2))).map((p) => p.poNo), ['PO-2']);
    });

    test('a delta pull (with a cursor) never forgets an order just because it is not in it', () async {
      await loadBasics();
      await store.applyPullWarehouse(_pull(pos: [_po(_po2, 'PO-2', _w2, at: '2026-11-09T09:30:00Z')]));
      expect(await store.purchaseOrder(_po1), isNotNull);
    });

    test('a snapshot over several pages forgets nothing until its last page', () async {
      await loadBasics();
      await resetCursors();
      Map<String, dynamic> page(String id, String no, {required bool more}) {
        final r = _pull(pos: [_po(id, no, _w1, at: '2026-11-09T09:10:00Z')]);
        (r['purchase_orders'] as Map<String, dynamic>)['has_more'] = more;
        return r;
      }

      await store.applyPullWarehouse(page('p3000000-0000-4000-8000-000000000003', 'PO-3', more: true));
      expect(await store.purchaseOrder(_po1), isNotNull, reason: 'the snapshot is not complete yet');
      await store.applyPullWarehouse(page(_po1, 'PO-1', more: false));
      expect(await store.purchaseOrder(_po1), isNotNull, reason: 'it was on the second page');
      expect(await store.purchaseOrder('p3000000-0000-4000-8000-000000000003'), isNotNull, reason: 'and the order from the first page is kept too');
      expect(await store.purchaseOrder(_po2), isNull, reason: 'on neither page: gone');
    });

    test('once a snapshot is complete, later delta pulls are ordinary again and forget nothing', () async {
      await loadBasics();
      await resetCursors();
      Map<String, dynamic> page(String id, String no, String at, {required bool more}) {
        final r = _pull(pos: [_po(id, no, _w1, at: at)]);
        (r['purchase_orders'] as Map<String, dynamic>)['has_more'] = more;
        return r;
      }

      const p3 = 'p3000000-0000-4000-8000-000000000003';
      const p4 = 'p4000000-0000-4000-8000-000000000004';
      const p5 = 'p5000000-0000-4000-8000-000000000005';
      await store.applyPullWarehouse(page(p3, 'PO-3', '2026-11-09T09:10:00Z', more: true));
      await store.applyPullWarehouse(page(_po1, 'PO-1', '2026-11-09T09:11:00Z', more: false)); // the snapshot is complete
      await store.applyPullWarehouse(page(p4, 'PO-4', '2026-11-09T09:20:00Z', more: false)); // a delta
      await store.applyPullWarehouse(page(p5, 'PO-5', '2026-11-09T09:30:00Z', more: false)); // another delta
      for (final id in [p3, _po1, p4, p5]) {
        expect(await store.purchaseOrder(id), isNotNull, reason: '$id must still be here');
      }
    });

    test('an order a receipt still depends on leaves the open list but is kept for the receipt', () async {
      await loadBasics();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 60)], opId: 'op-1');
      await store.warehouseOpApplied('op-1', '2026-11-09T10:00:00Z', result: {'grn_no': 'GRN-1'});
      await store.opDone('op-1');
      await resetCursors();
      await store.applyPullWarehouse(_pull(serverTime: '2026-11-09T10:00:02Z', pos: [_po(_po2, 'PO-2', _w2)]));
      expect(await _first(store.watchOpenPurchaseOrders(_w1)), isEmpty, reason: 'no longer open on the server');
      expect(await store.purchaseOrder(_po1), isNotNull, reason: 'the unsettled receipt still needs it');
    });

    test('a pull with no order table (the module is off) forgets nothing', () async {
      await loadBasics();
      await resetCursors();
      await store.applyPullWarehouse(<String, dynamic>{});
      expect(await store.purchaseOrder(_po1), isNotNull);
    });
  });

  group('refused and parked receipts', () {
    test('a refused receipt that is discarded takes its effect away', () async {
      await loadBasics();
      await store.receiveAgainstPo(poId: _po1, lines: const [ReceiptLine(variantId: _rice, qty: 60)], opId: 'op-1');
      await store.opFailed('op-1', 'invalid_state');
      expect((await store.failedOps()).map((o) => o.opId), ['op-1']);
      expect((await _first(store.watchOpenPurchaseOrders(_w1))).single.hasPending, true, reason: 'parked: still counted until the user decides');
      await store.discardFailed('op-1');
      final po = (await _first(store.watchOpenPurchaseOrders(_w1))).single;
      expect(po.hasPending, false);
      expect(po.remainingTotal, 120);
      expect((await _first(store.watchWarehouseStock(_w1))).firstWhere((r) => r.variantId == _rice).qty, 40);
      expect(await _first(store.watchReceipts(_w1)), isEmpty);
    });

    test('discarding a walk-in takes its stock away', () async {
      await loadBasics();
      await store.receiveWithoutPo(warehouseId: _w1, lines: const [ReceiptLine(variantId: _salt, qty: 7)], opId: 'op-1');
      await store.opFailed('op-1', 'location_denied');
      await store.discardFailed('op-1');
      expect((await _first(store.watchWarehouseStock(_w1))).any((r) => r.variantId == _salt), false);
    });
  });

  group('another business on this phone, and the schema upgrade', () {
    test('signing in to a different business clears the warehouse data', () async {
      await store.ensureTenant('tenant-a', baseCurrency: 'PHP');
      await loadBasics();
      await store.receiveWithoutPo(warehouseId: _w1, lines: const [ReceiptLine(variantId: _salt, qty: 7)], opId: 'op-1');
      await store.ensureTenant('tenant-b', baseCurrency: 'PHP', discardUnsent: true);
      expect(await _first(store.watchWarehouses()), isEmpty);
      expect(await _first(store.watchSuppliers()), isEmpty);
      expect(await _first(store.watchOpenPurchaseOrders(_w1)), isEmpty);
      expect(await _first(store.watchReceipts(_w1)), isEmpty);
      expect(await store.warehouseCursors(), isEmpty);
    });

    test('a version 14 device upgrades with every row and unsent op kept', () async {
      final dir = await Directory.systemTemp.createTemp('wh_migrate');
      final file = File('${dir.path}/app.db');
      try {
        final v15 = DriftStore(AppDatabase(NativeDatabase(file)));
        await v15.ensureTenant('tenant-a', baseCurrency: 'PHP');
        await v15.applyPullWarehouse(_pull(warehouses: [_wh(_w1, 'W1')]));
        await v15.db.into(v15.db.customers).insert(CustomersCompanion.insert(id: 'c1', name: 'Aling Nena'));
        await v15.saveProduct(
            const ProductDraft(id: 'f0000000-0000-4000-8000-000000000001', variantId: 'f1000000-0000-4000-8000-000000000001', name: 'Kape', price: 1000),
            opId: 'op-keep');
        // take the file back to the v14 layout: none of the warehouse tables, version 14
        for (final t in ['warehouses', 'wh_bins', 'wh_bin_stock', 'wh_stock', 'suppliers', 'purchase_orders', 'po_items', 'wh_receipts', 'wh_receipt_items']) {
          await v15.db.customStatement('DROP TABLE IF EXISTS $t');
        }
        await v15.db.customStatement('PRAGMA user_version = 14');
        await v15.close();

        final upgraded = DriftStore(AppDatabase(NativeDatabase(file)));
        await upgraded.ensureTenant('tenant-a', baseCurrency: 'PHP');
        final version = await upgraded.db.customSelect('PRAGMA user_version').getSingle();
        expect(version.data.values.single, 15);
        expect([for (final o in await upgraded.nextOps()) o.opId], ['op-keep'], reason: 'unsent ops survive');
        expect((await upgraded.db.select(upgraded.db.customers).get()).map((c) => c.name), ['Aling Nena']);
        expect(await _first(upgraded.watchWarehouses()), isEmpty, reason: 'new and empty: the first pull fills it');
        expect(await upgraded.warehouseCursors(), isEmpty, reason: 'no cursor yet, so the first pull brings everything');
        await upgraded.applyPullWarehouse(_pull(warehouses: [_wh(_w1, 'W1')]));
        expect((await _first(upgraded.watchWarehouses())).map((w) => w.code), ['W1']);
        await upgraded.close();
      } finally {
        try {
          await dir.delete(recursive: true);
        } on FileSystemException {
          // Windows may still hold the SQLite file for a moment; a leftover temp folder is harmless
        }
      }
    });
  });
}
