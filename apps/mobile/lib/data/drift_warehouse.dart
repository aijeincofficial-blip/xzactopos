import 'dart:convert';

import 'package:drift/drift.dart';

import 'db.dart';
import 'warehouse_models.dart';

/// The warehouse side of the device store (F-13h H2).
///
/// Every number is "the server's copy + receipts made here that the server's copy has not caught up on". A receipt is one
/// row in `wh_receipts` (with its lines in `wh_receipt_items`). While [WhReceipts.settled] is false the row also counts as
/// an effect: the order's remaining falls and the stock rises. The effect is dropped (settled) only when
///   1. the server answered the op ([warehouseOpApplied] stores its own time of the receipt, `confirmedAfter`),
///   2. a COMPLETE pull has gone past that time less the server's 5 second hold-back, and
///   3. the pulled copy of the order (for an order receipt) and of every stock row the receipt touched is at least as new
///      as that time,
/// so a number never dips or counts twice while a receipt is in flight. A confirmed effect older than a day is dropped
/// regardless (a row the server stopped sending, for example after access changed, must not count forever).
/// A receipt the server has not answered is never settled by a pull. Only the server's clock is used, never the phone's.
mixin DriftWarehouse implements WarehouseStore {
  AppDatabase get db;
  Future<void> enqueue(String opId, String kind, String entityId, Map<String, dynamic> payload);
  Future<String?> meta(String key);
  Future<void> setMeta(String key, String? value);

  static String _iso(DateTime t) => t.toUtc().toIso8601String();
  static double _r3(double v) => (v * 1000).round() / 1000;
  static const _openStatuses = ['ordered', 'partly_received'];

  /// Pulled keys, kept apart from the store pull's (both have a `stock_levels`).
  static const _pullTables = ['warehouses', 'bins', 'bin_stock_levels', 'stock_levels', 'suppliers', 'purchase_orders'];
  static const _cursorPrefix = 'wh:';

  /// A signal that fires when any of [reads] changes, then [load] runs. Drift shares one stream between queries with the same
  /// SQL text, and keeps the table list of the FIRST one; so the SQL carries the table names, or a second watcher on other
  /// tables would never hear about its own writes.
  Stream<void> _signal(Set<TableInfo> reads) {
    final key = (reads.map((t) => t.actualTableName).toList()..sort()).join('_');
    return db.customSelect('select 1 as watch_$key', readsFrom: reads).watch();
  }

  Stream<List<T>> _watch<T>(Set<TableInfo> reads, Future<List<T>> Function() load) => _signal(reads).asyncMap((_) => load());

  // ---------------------------------------------------------------------------
  // The active warehouse
  // ---------------------------------------------------------------------------

  static const _activeWarehouseKey = 'active_warehouse_id';

  static WarehouseView _view(Warehouse w) => WarehouseView(id: w.id, code: w.code, name: w.name, binsEnabled: w.binsEnabled);

  Future<List<Warehouse>> _liveWarehouses() => (db.select(db.warehouses)
        ..where((w) => w.deletedAt.isNull() & w.active.equals(true))
        ..orderBy([(w) => OrderingTerm.asc(w.code)]))
      .get();

  @override
  Future<WarehouseView?> activeWarehouse() async {
    final all = await _liveWarehouses();
    if (all.isEmpty) return null;
    final chosen = await meta(_activeWarehouseKey);
    return _view(all.firstWhere((w) => w.id == chosen, orElse: () => all.first));
  }

  @override
  Stream<WarehouseView?> watchActiveWarehouse() =>
      _signal({db.warehouses, db.meta}).asyncMap((_) => activeWarehouse()).distinct();

  @override
  Future<void> setActiveWarehouse(String warehouseId) async {
    if ((await _liveWarehouses()).any((w) => w.id == warehouseId)) await setMeta(_activeWarehouseKey, warehouseId);
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  @override
  Stream<List<WarehouseView>> watchWarehouses() => (db.select(db.warehouses)
        ..where((w) => w.deletedAt.isNull() & w.active.equals(true))
        ..orderBy([(w) => OrderingTerm.asc(w.code)]))
      .watch()
      .map((rows) => [for (final w in rows) WarehouseView(id: w.id, code: w.code, name: w.name, binsEnabled: w.binsEnabled)]);

  @override
  Stream<List<BinView>> watchBins(String warehouseId) => (db.select(db.whBins)
        ..where((b) => b.warehouseId.equals(warehouseId) & b.deletedAt.isNull() & b.active.equals(true))
        ..orderBy([(b) => OrderingTerm.asc(b.code)]))
      .watch()
      .map((rows) => [
            for (final b in rows)
              BinView(
                  id: b.id,
                  warehouseId: b.warehouseId,
                  code: b.code,
                  aisle: b.aisle,
                  rack: b.rack,
                  shelf: b.shelf,
                  position: b.position,
                  type: b.type,
                  maxQty: b.maxQty)
          ]);

  @override
  Stream<List<SupplierView>> watchSuppliers() => (db.select(db.suppliers)..where((s) => s.deletedAt.isNull())).watch().map((rows) {
        final list = [
          for (final s in rows) SupplierView(id: s.id, name: s.name, contactName: s.contactName, phone: s.phone, email: s.email)
        ];
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  /// Received on this device and not in the server's copy yet, per order and product.
  Future<Map<String, Map<String, double>>> _pendingByOrder() async {
    final rows = await db.customSelect('''
      select r.po_id as po_id, i.variant_id as variant_id, sum(i.qty) as q
      from wh_receipts r join wh_receipt_items i on i.op_id = r.op_id
      where r.settled = 0 and r.po_id is not null
      group by r.po_id, i.variant_id''', readsFrom: {db.whReceipts, db.whReceiptItems}).get();
    final out = <String, Map<String, double>>{};
    for (final r in rows) {
      (out[r.read<String>('po_id')] ??= {})[r.read<String>('variant_id')] = r.read<double>('q');
    }
    return out;
  }

  /// Received on this device and not in the server's copy yet, per product, in one warehouse.
  Future<Map<String, double>> _pendingInWarehouse(String warehouseId) async {
    final rows = await db.customSelect('''
      select i.variant_id as variant_id, sum(i.qty) as q
      from wh_receipts r join wh_receipt_items i on i.op_id = r.op_id
      where r.settled = 0 and r.warehouse_id = ?1
      group by i.variant_id''', variables: [Variable<String>(warehouseId)], readsFrom: {db.whReceipts, db.whReceiptItems}).get();
    return {for (final r in rows) r.read<String>('variant_id'): r.read<double>('q')};
  }

  Future<List<PurchaseOrderView>> _viewOrders(List<PurchaseOrder> pos) async {
    if (pos.isEmpty) return const [];
    final pending = await _pendingByOrder();
    final suppliers = {for (final s in await db.select(db.suppliers).get()) s.id: s.name};
    final items = await (db.select(db.poItems)..where((i) => i.poId.isIn([for (final p in pos) p.id]))).get();
    final byPo = <String, List<PoItem>>{};
    for (final i in items) {
      (byPo[i.poId] ??= []).add(i);
    }
    return [
      for (final p in pos)
        PurchaseOrderView(
          id: p.id,
          poNo: p.poNo,
          warehouseId: p.warehouseId,
          supplierId: p.supplierId,
          supplierName: suppliers[p.supplierId],
          status: p.status,
          expectedAt: p.expectedAt,
          notes: p.notes,
          items: [
            for (final i in (byPo[p.id] ?? const <PoItem>[]))
              PoLineView(
                id: i.id,
                variantId: i.variantId,
                ordered: i.qtyOrdered,
                receivedOnServer: i.qtyReceived,
                pending: pending[p.id]?[i.variantId] ?? 0,
                unitCost: i.unitCost,
              )
          ],
        )
    ];
  }

  @override
  Stream<List<PurchaseOrderView>> watchOpenPurchaseOrders(String warehouseId) =>
      _watch({db.purchaseOrders, db.poItems, db.whReceipts, db.whReceiptItems, db.suppliers}, () async {
        final pos = await (db.select(db.purchaseOrders)
              ..where((p) => p.warehouseId.equals(warehouseId) & p.status.isIn(_openStatuses))
              ..orderBy([(p) => OrderingTerm.asc(p.poNo)]))
            .get();
        return _viewOrders(pos);
      });

  @override
  Future<PurchaseOrderView?> purchaseOrder(String id) async {
    final p = await (db.select(db.purchaseOrders)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (p == null) return null;
    return (await _viewOrders([p])).single;
  }

  @override
  Stream<PurchaseOrderView?> watchPurchaseOrder(String id) =>
      _signal({db.purchaseOrders, db.poItems, db.whReceipts, db.whReceiptItems, db.suppliers}).asyncMap((_) => purchaseOrder(id));

  @override
  Stream<List<WhStockRow>> watchWarehouseStock(String warehouseId) =>
      _watch({db.whStock, db.whReceipts, db.whReceiptItems}, () async {
        final pending = await _pendingInWarehouse(warehouseId);
        final pulled = {
          for (final r in await (db.select(db.whStock)..where((s) => s.locationId.equals(warehouseId))).get()) r.variantId: r.qty
        };
        final out = <WhStockRow>[];
        for (final v in {...pulled.keys, ...pending.keys}) {
          final p = pending[v] ?? 0;
          final qty = _r3((pulled[v] ?? 0) + p);
          if (qty != 0 || p != 0) out.add(WhStockRow(variantId: v, qty: qty, pending: _r3(p)));
        }
        out.sort((a, b) => a.variantId.compareTo(b.variantId));
        return out;
      });

  @override
  Stream<List<BinStockRow>> watchBinStock(String warehouseId) =>
      _watch({db.whBins, db.whBinStock, db.warehouses, db.whReceipts, db.whReceiptItems}, () async {
        final bins = await (db.select(db.whBins)..where((b) => b.warehouseId.equals(warehouseId) & b.deletedAt.isNull())).get();
        final byId = {for (final b in bins) b.id: b};
        final qty = <String, double>{}; // 'bin|variant' -> qty
        for (final r in await (db.select(db.whBinStock)..where((s) => s.binId.isIn(byId.keys))).get()) {
          qty['${r.binId}|${r.variantId}'] = r.qty;
        }
        // goods received here go to the RECEIVING bin on the server; show them there until its copy arrives
        final wh = await (db.select(db.warehouses)..where((w) => w.id.equals(warehouseId))).getSingleOrNull();
        if (wh != null && wh.binsEnabled) {
          final receiving = bins.where((b) => b.code.toUpperCase() == 'RECEIVING').toList();
          if (receiving.isNotEmpty) {
            for (final e in (await _pendingInWarehouse(warehouseId)).entries) {
              final k = '${receiving.first.id}|${e.key}';
              qty[k] = _r3((qty[k] ?? 0) + e.value);
            }
          }
        }
        final out = <BinStockRow>[];
        for (final e in qty.entries) {
          if (e.value == 0) continue;
          final parts = e.key.split('|');
          out.add(BinStockRow(binId: parts[0], binCode: byId[parts[0]]!.code, variantId: parts[1], qty: e.value));
        }
        out.sort((a, b) => a.binCode.compareTo(b.binCode) != 0 ? a.binCode.compareTo(b.binCode) : a.variantId.compareTo(b.variantId));
        return out;
      });

  @override
  Stream<List<WhReceiptView>> watchReceipts(String warehouseId, {int limit = 30}) =>
      _watch({db.whReceipts, db.whReceiptItems}, () async {
        final rows = await (db.select(db.whReceipts)
              ..where((r) => r.warehouseId.equals(warehouseId))
              ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
              ..limit(limit))
            .get();
        if (rows.isEmpty) return const <WhReceiptView>[];
        final items = await (db.select(db.whReceiptItems)..where((i) => i.opId.isIn([for (final r in rows) r.opId]))..orderBy([(i) => OrderingTerm.asc(i.id)])).get();
        final byOp = <String, List<ReceiptLine>>{};
        for (final i in items) {
          (byOp[i.opId] ??= []).add(ReceiptLine(variantId: i.variantId, qty: i.qty, unitCost: i.unitCost));
        }
        return [
          for (final r in rows)
            WhReceiptView(
              opId: r.opId,
              kind: r.kind,
              warehouseId: r.warehouseId,
              poId: r.poId,
              poNo: r.poNo,
              supplierId: r.supplierId,
              deliveryRef: r.deliveryRef,
              notes: r.notes,
              createdAt: DateTime.parse(r.createdAt),
              grnNo: r.grnNo,
              lines: byOp[r.opId] ?? const [],
              confirmed: r.confirmedAfter != null,
            )
        ];
      });

  // ---------------------------------------------------------------------------
  // Local writes
  // ---------------------------------------------------------------------------

  /// Checks and tidies the lines of a delivery; throws [WarehouseReceiptException] before anything is written.
  List<ReceiptLine> _cleanLines(List<ReceiptLine> lines, {Set<String>? onOrder}) {
    if (lines.isEmpty) throw const WarehouseReceiptException('no_lines');
    final seen = <String>{};
    final out = <ReceiptLine>[];
    for (final l in lines) {
      final qty = l.qty.isFinite ? _r3(l.qty) : 0.0;
      if (qty <= 0 || qty >= 1000000000) throw const WarehouseReceiptException('qty_invalid');
      if (l.unitCost != null && l.unitCost! < 0) throw const WarehouseReceiptException('cost_invalid');
      if (onOrder != null && !onOrder.contains(l.variantId)) throw const WarehouseReceiptException('not_on_order');
      if (!seen.add(l.variantId)) throw const WarehouseReceiptException('duplicate_line');
      out.add(ReceiptLine(variantId: l.variantId, qty: qty, unitCost: l.unitCost));
    }
    return out;
  }

  static String? _blankToNull(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  Future<void> _record({
    required String opId,
    required String kind,
    required String warehouseId,
    String? poId,
    String? poNo,
    String? supplierId,
    String? deliveryRef,
    String? notes,
    required List<ReceiptLine> lines,
    required String opKind,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await db.into(db.whReceipts).insert(WhReceiptsCompanion.insert(
          opId: opId,
          kind: kind,
          warehouseId: warehouseId,
          poId: Value(poId),
          poNo: Value(poNo),
          supplierId: Value(supplierId),
          deliveryRef: Value(deliveryRef),
          notes: Value(notes),
          createdAt: _iso(DateTime.now()),
        ));
    for (final l in lines) {
      await db.into(db.whReceiptItems).insert(WhReceiptItemsCompanion.insert(
          opId: opId, variantId: l.variantId, qty: l.qty, unitCost: Value(l.unitCost)));
    }
    await enqueue(opId, opKind, entityId, payload);
  }

  @override
  Future<void> receiveAgainstPo({
    required String poId,
    required List<ReceiptLine> lines,
    String? deliveryRef,
    String? notes,
    required String opId,
  }) {
    return db.transaction(() async {
      final po = await (db.select(db.purchaseOrders)..where((p) => p.id.equals(poId))).getSingleOrNull();
      if (po == null) throw const WarehouseReceiptException('unknown_order');
      if (!_openStatuses.contains(po.status)) throw const WarehouseReceiptException('order_closed');
      final onOrder = {for (final i in await (db.select(db.poItems)..where((x) => x.poId.equals(poId))).get()) i.variantId};
      final clean = _cleanLines(lines, onOrder: onOrder);
      final ref = _blankToNull(deliveryRef);
      final note = _blankToNull(notes);
      await _record(
        opId: opId,
        kind: 'po',
        warehouseId: po.warehouseId,
        poId: poId,
        poNo: po.poNo,
        supplierId: po.supplierId,
        deliveryRef: ref,
        notes: note,
        lines: clean,
        opKind: 'receive_po',
        entityId: poId,
        payload: {
          'po_id': poId,
          'items': [for (final l in clean) l.toJson()],
          'notes': ?note,
          'delivery_ref': ?ref,
        },
      );
    });
  }

  @override
  Future<void> receiveWithoutPo({
    required String warehouseId,
    String? supplierId,
    required List<ReceiptLine> lines,
    String? deliveryRef,
    String? notes,
    required String opId,
  }) {
    return db.transaction(() async {
      final wh = await (db.select(db.warehouses)..where((w) => w.id.equals(warehouseId))).getSingleOrNull();
      if (wh == null || wh.deletedAt != null || !wh.active) throw const WarehouseReceiptException('unknown_warehouse');
      final clean = _cleanLines(lines);
      final ref = _blankToNull(deliveryRef);
      final note = _blankToNull(notes);
      final supplier = _blankToNull(supplierId);
      await _record(
        opId: opId,
        kind: 'walkin',
        warehouseId: warehouseId,
        supplierId: supplier,
        deliveryRef: ref,
        notes: note,
        lines: clean,
        opKind: 'receive_without_po',
        entityId: warehouseId,
        payload: {
          'warehouse_id': warehouseId,
          'supplier_id': ?supplier,
          'items': [for (final l in clean) l.toJson()],
          'notes': ?note,
          'delivery_ref': ?ref,
        },
      );
    });
  }

  /// A refused receipt that the user discarded: its record and effect go.
  Future<void> discardWarehouseOp(String opId) async {
    await (db.delete(db.whReceiptItems)..where((i) => i.opId.equals(opId))).go();
    await (db.delete(db.whReceipts)..where((r) => r.opId.equals(opId))).go();
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> warehouseCursors() async {
    final rows = await (db.select(db.syncCursors)..where((c) => c.tableKey.like('$_cursorPrefix%'))).get();
    return {for (final c in rows) c.tableKey.substring(_cursorPrefix.length): jsonDecode(c.cursorJson)};
  }

  @override
  Future<void> warehouseOpApplied(String opId, String? appliedAt, {Map<String, dynamic>? result}) async {
    final grn = result?['grn_no'];
    await (db.update(db.whReceipts)..where((r) => r.opId.equals(opId))).write(WhReceiptsCompanion(
      confirmedAfter: Value(appliedAt ?? _iso(DateTime.now())),
      grnNo: grn is String && grn.isNotEmpty ? Value(grn) : const Value.absent(),
    ));
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> response, String table) =>
      (((response[table] as Map?)?['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();

  static double _num(Object? v) => (v as num).toDouble();

  /// Orders seen so far in a snapshot pull that is still running (meta key; JSON list of ids).
  static const _snapshotKey = 'wh_po_seen';

  @override
  Future<void> applyPullWarehouse(Map<String, dynamic> response) {
    return db.transaction(() async {
      // A pull WITHOUT a cursor (the first one, or after the cursors were dropped to start over) sends only the orders that
      // are open on the server, so an order that finished meanwhile is simply not mentioned. Such a pull is therefore a
      // snapshot: when it is complete (it may take several pages) the orders it did not list are forgotten.
      final hadOrderCursor =
          await (db.select(db.syncCursors)..where((c) => c.tableKey.equals('${_cursorPrefix}purchase_orders'))).getSingleOrNull() != null;
      final snapshotRow = await (db.select(db.meta)..where((m) => m.key.equals(_snapshotKey))).getSingleOrNull();
      final snapshot = (!hadOrderCursor || snapshotRow != null) && response['purchase_orders'] is Map;

      for (final r in _rows(response, 'warehouses')) {
        await db.into(db.warehouses).insertOnConflictUpdate(WarehousesCompanion.insert(
              id: r['id'] as String,
              code: r['code'] as String,
              name: r['name'] as String,
              binsEnabled: Value(r['bins_enabled'] == true),
              active: Value(r['active'] != false),
              updatedAt: Value(r['updated_at'] as String?),
              deletedAt: Value(r['deleted_at'] as String?),
            ));
      }
      for (final r in _rows(response, 'bins')) {
        await db.into(db.whBins).insertOnConflictUpdate(WhBinsCompanion.insert(
              id: r['id'] as String,
              warehouseId: r['warehouse_id'] as String,
              zoneId: Value(r['zone_id'] as String?),
              code: r['code'] as String,
              aisle: Value(r['aisle'] as String?),
              rack: Value(r['rack'] as String?),
              shelf: Value(r['shelf'] as String?),
              position: Value(r['position'] as String?),
              type: Value((r['type'] as String?) ?? 'shelf'),
              maxQty: Value(r['max_qty'] == null ? null : _num(r['max_qty'])),
              active: Value(r['active'] != false),
              updatedAt: Value(r['updated_at'] as String?),
              deletedAt: Value(r['deleted_at'] as String?),
            ));
      }
      for (final r in _rows(response, 'bin_stock_levels')) {
        await db.into(db.whBinStock).insertOnConflictUpdate(WhBinStockCompanion.insert(
            binId: r['bin_id'] as String, variantId: r['variant_id'] as String, qty: _num(r['qty_on_hand']), updatedAt: r['updated_at'] as String));
      }
      for (final r in _rows(response, 'stock_levels')) {
        await db.into(db.whStock).insertOnConflictUpdate(WhStockCompanion.insert(
              locationId: r['location_id'] as String,
              variantId: r['variant_id'] as String,
              qty: _num(r['qty_on_hand']),
              avgCost: Value((r['avg_cost'] as num?)?.toInt()),
              updatedAt: r['updated_at'] as String,
            ));
      }
      for (final r in _rows(response, 'suppliers')) {
        await db.into(db.suppliers).insertOnConflictUpdate(SuppliersCompanion.insert(
              id: r['id'] as String,
              name: r['name'] as String,
              contactName: Value(r['contact_name'] as String?),
              phone: Value(r['phone'] as String?),
              email: Value(r['email'] as String?),
              notes: Value(r['notes'] as String?),
              updatedAt: Value(r['updated_at'] as String?),
              deletedAt: Value(r['deleted_at'] as String?),
            ));
      }
      for (final r in _rows(response, 'purchase_orders')) {
        final id = r['id'] as String;
        await db.into(db.purchaseOrders).insertOnConflictUpdate(PurchaseOrdersCompanion.insert(
              id: id,
              poNo: r['po_no'] as String,
              warehouseId: r['warehouse_id'] as String,
              supplierId: r['supplier_id'] as String,
              status: r['status'] as String,
              expectedAt: Value(r['expected_at'] as String?),
              notes: Value(r['notes'] as String?),
              updatedAt: r['updated_at'] as String,
            ));
        // the server sends the order whole: replace its lines
        await (db.delete(db.poItems)..where((i) => i.poId.equals(id))).go();
        for (final i in ((r['items'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
          await db.into(db.poItems).insert(PoItemsCompanion.insert(
                id: i['id'] as String,
                poId: id,
                variantId: i['variant_id'] as String,
                qtyOrdered: _num(i['qty_ordered']),
                qtyReceived: _num(i['qty_received']),
                unitCost: Value((i['unit_cost'] as num?)?.toInt()),
              ));
        }
      }
      if (snapshot) await _reconcileSnapshot(response, snapshotRow?.value);
      for (final t in _pullTables) {
        final cursor = (response[t] as Map?)?['cursor'];
        if (cursor is Map) {
          await db.into(db.syncCursors).insertOnConflictUpdate(
              SyncCursorsCompanion.insert(tableKey: '$_cursorPrefix$t', cursorJson: jsonEncode(cursor)));
        }
      }

      final more = _pullTables.any((t) => (response[t] as Map?)?['has_more'] == true);
      final st = response['server_time'];
      if (!more && st is String) {
        await _settle(DateTime.parse(st));
      }
    });
  }

  /// Remembers the orders a snapshot pull listed; when its last page has arrived, forgets the local orders it did not list.
  /// An order an unsettled receipt still needs (to judge "caught up") is not deleted but marked `closed`, which takes it off
  /// the open list; the usual clean-up removes it once the receipt has settled.
  Future<void> _reconcileSnapshot(Map<String, dynamic> response, String? seenJson) async {
    final seen = <String>{
      if (seenJson != null) ...(jsonDecode(seenJson) as List).cast<String>(),
      for (final r in _rows(response, 'purchase_orders')) r['id'] as String,
    };
    final more = (response['purchase_orders'] as Map)['has_more'] == true;
    if (more) {
      await db.into(db.meta).insertOnConflictUpdate(MetaCompanion.insert(key: _snapshotKey, value: jsonEncode(seen.toList())));
      return;
    }
    final needed = {
      for (final r in await (db.select(db.whReceipts)..where((x) => x.settled.equals(false) & x.poId.isNotNull())).get()) r.poId!
    };
    for (final p in await db.select(db.purchaseOrders).get()) {
      if (seen.contains(p.id)) continue;
      if (needed.contains(p.id)) {
        await (db.update(db.purchaseOrders)..where((x) => x.id.equals(p.id))).write(const PurchaseOrdersCompanion(status: Value('closed')));
      } else {
        await (db.delete(db.poItems)..where((i) => i.poId.equals(p.id))).go();
        await (db.delete(db.purchaseOrders)..where((x) => x.id.equals(p.id))).go();
      }
    }
    await (db.delete(db.meta)..where((m) => m.key.equals(_snapshotKey))).go();
  }

  /// Drops the effect of receipts the server's copy has caught up on, forgets old receipts and finished orders.
  Future<void> _settle(DateTime serverTime) async {
    final horizon = serverTime.subtract(const Duration(seconds: 5));
    final open = await (db.select(db.whReceipts)..where((r) => r.settled.equals(false) & r.confirmedAfter.isNotNull())).get();
    for (final r in open) {
      final at = DateTime.parse(r.confirmedAfter!);
      var settle = serverTime.difference(at) > const Duration(days: 1);
      if (!settle && !at.isAfter(horizon)) {
        settle = await _caughtUp(r, at);
      }
      if (settle) {
        await (db.update(db.whReceipts)..where((x) => x.opId.equals(r.opId))).write(const WhReceiptsCompanion(settled: Value(true)));
      }
    }

    // old settled receipts (by the server's clock)
    final cutoff = _iso(serverTime.subtract(const Duration(days: 30)));
    final old = await (db.select(db.whReceipts)..where((r) => r.settled.equals(true) & r.confirmedAfter.isSmallerThanValue(cutoff))).get();
    for (final r in old) {
      await discardWarehouseOp(r.opId);
    }

    // a finished order is only kept while an unsettled receipt still refers to it
    final keep = {
      for (final r in await (db.select(db.whReceipts)..where((x) => x.settled.equals(false) & x.poId.isNotNull())).get()) r.poId!
    };
    final finished = await (db.select(db.purchaseOrders)..where((p) => p.status.isNotIn(_openStatuses))).get();
    for (final p in finished) {
      if (keep.contains(p.id)) continue;
      await (db.delete(db.poItems)..where((i) => i.poId.equals(p.id))).go();
      await (db.delete(db.purchaseOrders)..where((x) => x.id.equals(p.id))).go();
    }
  }

  /// The pulled copy of the order and of every stock row this receipt touched is at least as new as [at].
  Future<bool> _caughtUp(WhReceipt r, DateTime at) async {
    if (r.poId != null) {
      final po = await (db.select(db.purchaseOrders)..where((p) => p.id.equals(r.poId!))).getSingleOrNull();
      if (po == null || DateTime.parse(po.updatedAt).isBefore(at)) return false;
    }
    final items = await (db.select(db.whReceiptItems)..where((i) => i.opId.equals(r.opId))).get();
    for (final i in items) {
      final s = await (db.select(db.whStock)..where((x) => x.locationId.equals(r.warehouseId) & x.variantId.equals(i.variantId))).getSingleOrNull();
      if (s == null || DateTime.parse(s.updatedAt).isBefore(at)) return false;
    }
    return true;
  }
}
