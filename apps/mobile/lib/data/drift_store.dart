import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/search.dart';
import 'db.dart';
import 'drift_sales.dart';
import 'local_store.dart';

class DriftStore with DriftSales implements LocalStore {
  DriftStore(this.db);

  @override
  final AppDatabase db;
  String _base = 'PHP';

  static const _syncTables = ['categories', 'products', 'product_variants', 'variant_prices'];

  @override
  String get baseCurrency => _base;

  @override
  Future<bool> ensureTenant(String tenantId,
      {required String baseCurrency, String? locationId, bool discardUnsent = false}) async {
    _base = baseCurrency;
    this.locationId = locationId;
    final row = await (db.select(db.meta)..where((m) => m.key.equals('tenant_id'))).getSingleOrNull();
    if (row?.value == tenantId) return false;
    if (row != null && !discardUnsent) {
      final unsent = (await db.select(db.outbox).get()).length;
      if (unsent > 0) throw UnsentChangesException(unsent);
    }
    await db.transaction(() async {
      for (final t in db.allTables) {
        await db.delete(t).go();
      }
      await db.into(db.meta).insert(MetaCompanion.insert(key: 'tenant_id', value: tenantId));
    });
    return row != null;
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  static const _productSql = '''
    select p.id, v.id as variant_id, p.name, p.unit, v.sku, v.barcode, pr.price, p.photo_path, p.active,
           p.track_stock, p.tax_rate, v.cost, v.reorder_point,
           exists (select 1 from outbox o where o.entity_id = p.id) as pending
    from products p
    join variants v on v.product_id = p.id and v.is_default = 1 and v.deleted_at is null
    left join prices pr on pr.variant_id = v.id and pr.currency = ?1 and pr.deleted_at is null
    where p.deleted_at is null
  ''';

  ProductView _view(QueryRow r) => ProductView(
        id: r.read<String>('id'),
        variantId: r.read<String>('variant_id'),
        name: r.read<String>('name'),
        unit: r.read<String>('unit'),
        sku: r.read<String>('sku'),
        barcode: r.readNullable<String>('barcode'),
        price: r.readNullable<int>('price'),
        currency: _base,
        photoPath: r.readNullable<String>('photo_path'),
        active: r.read<bool>('active'),
        pending: r.read<bool>('pending'),
        trackStock: r.read<bool>('track_stock'),
        taxRate: r.read<double>('tax_rate'),
        cost: r.read<int>('cost'),
        reorderPoint: r.read<double>('reorder_point'),
      );

  /// Every word must appear in the name (accents ignored); an exact barcode or SKU also matches.
  /// Order: exact barcode, name starts with the query, then the rest by name.
  @override
  Stream<List<ProductView>> watchProducts({String query = ''}) {
    final raw = query.trim();
    final words = searchWords(raw);
    final vars = <Variable<Object>>[Variable.withString(_base), Variable.withString(raw), Variable.withString(searchKey(raw))];
    final wordSql = <String>[];
    for (final w in words) {
      vars.add(Variable.withString(w));
      wordSql.add("p.search_name like '%' || ?${vars.length} || '%'");
    }
    final where = words.isEmpty
        ? ''
        : ' and ((${wordSql.join(' and ')}) or v.barcode = ?2 or lower(v.sku) = lower(?2))';
    return db
        .customSelect(
          '$_productSql$where '
          "order by case when v.barcode = ?2 then 0 when p.search_name like ?3 || '%' then 1 else 2 end, "
          'p.search_name, p.id',
          variables: vars,
          readsFrom: {db.products, db.variants, db.prices, db.outbox},
        )
        .watch()
        .map((rows) => rows.map(_view).toList());
  }

  @override
  Future<ProductView?> findByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final rows = await db.customSelect('$_productSql and v.barcode = ?2 limit 1',
        variables: [Variable.withString(_base), Variable.withString(code)]).get();
    return rows.isEmpty ? null : _view(rows.first);
  }

  @override
  Future<int> productCount() async {
    final c = db.products.id.count();
    final q = db.selectOnly(db.products)
      ..addColumns([c])
      ..where(db.products.deletedAt.isNull());
    return (await q.getSingle()).read(c) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Local writes + outbox, one transaction each
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveProduct(ProductDraft d, {required String opId}) {
    return db.transaction(() async {
      final existing = await (db.select(db.variants)..where((v) => v.id.equals(d.variantId))).getSingleOrNull();
      final sku = (d.sku != null && d.sku!.isNotEmpty) ? d.sku! : (existing?.sku ?? _provisionalSku(d.variantId));

      await db.into(db.products).insertOnConflictUpdate(ProductsCompanion(
            id: Value(d.id),
            name: Value(d.name.trim()),
            searchName: Value(searchKey(d.name)),
            unit: Value(d.unit),
            deletedAt: const Value(null),
          ));
      await db.into(db.variants).insertOnConflictUpdate(VariantsCompanion(
            id: Value(d.variantId),
            productId: Value(d.id),
            sku: Value(sku),
            barcode: Value((d.barcode == null || d.barcode!.trim().isEmpty) ? null : d.barcode!.trim()),
            isDefault: const Value(true),
            cost: d.cost == null ? const Value.absent() : Value(d.cost!),
            reorderPoint: d.reorderPoint == null ? const Value.absent() : Value(d.reorderPoint!),
            deletedAt: const Value(null),
          ));
      await db.into(db.prices).insertOnConflictUpdate(PricesCompanion(
            variantId: Value(d.variantId),
            currency: Value(_base),
            price: Value(d.price),
            deletedAt: const Value(null),
          ));
      await _enqueue(opId, 'upsert_product', d.id, d.toPayload());
      // "How many do you have now?" becomes an `opening` stock movement on the server; once per variant
      if (d.openingQty != null && d.openingQty! > 0) {
        final oid = openingOpId(d.variantId);
        final already = await (db.select(db.localMovements)..where((m) => m.opId.equals(oid))).get();
        final queued = await (db.select(db.outbox)..where((o) => o.opId.equals(oid))).get();
        if (already.isEmpty && queued.isEmpty) {
          await db.into(db.localMovements).insert(
              LocalMovementsCompanion.insert(opId: oid, variantId: d.variantId, qty: d.openingQty!, counts: const Value(true)));
          await _enqueue(oid, 'post_opening_stock', d.id, {'variant_id': d.variantId, 'qty': d.openingQty});
        }
      }
    });
  }

  @override
  Future<void> archiveProduct(String productId, {required String opId}) {
    return db.transaction(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await (db.update(db.products)..where((p) => p.id.equals(productId)))
          .write(ProductsCompanion(deletedAt: Value(now)));
      final variantIds = await (db.select(db.variants)..where((v) => v.productId.equals(productId)))
          .map((v) => v.id)
          .get();
      await (db.update(db.variants)..where((v) => v.productId.equals(productId)))
          .write(VariantsCompanion(deletedAt: Value(now)));
      await (db.update(db.prices)..where((p) => p.variantId.isIn(variantIds)))
          .write(PricesCompanion(deletedAt: Value(now)));
      await _enqueue(opId, 'archive_product', productId, {'product_id': productId});
    });
  }

  /// Shown until the server assigns the real one; same rule as upsert_product (P- + last 12 hex of the variant id).
  String _provisionalSku(String variantId) =>
      'P-${variantId.replaceAll('-', '').substring(20).toUpperCase()}';

  @override
  Future<void> enqueue(String opId, String kind, String entityId, Map<String, dynamic> payload) =>
      _enqueue(opId, kind, entityId, payload);

  Future<void> _enqueue(String opId, String kind, String entityId, Map<String, dynamic> payload) {
    return db.into(db.outbox).insert(OutboxCompanion.insert(
          opId: opId,
          kind: kind,
          entityId: entityId,
          payload: jsonEncode(payload),
          createdAt: DateTime.now().toUtc(),
        ));
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> cursors() async {
    final rows = await db.select(db.syncCursors).get();
    return {for (final r in rows) r.tableKey: jsonDecode(r.cursorJson)};
  }

  @override
  Future<void> applyPull(Map<String, dynamic> response) {
    return db.transaction(() async {
      // products with unsent changes, and their variants: keep the local copy for now
      final pendingOps = await db.select(db.outbox).get();
      final skipProducts = <String>{};
      final skipVariants = <String>{};
      for (final op in pendingOps) {
        skipProducts.add(op.entityId);
        final variant = (jsonDecode(op.payload) as Map<String, dynamic>)['variant'];
        if (variant is Map && variant['id'] is String) skipVariants.add(variant['id'] as String);
      }
      if (skipProducts.isNotEmpty) {
        final local = await (db.select(db.variants)..where((v) => v.productId.isIn(skipProducts))).get();
        skipVariants.addAll(local.map((v) => v.id));
      }

      List<Map<String, dynamic>> rowsOf(String table) =>
          (((response[table] as Map?)?['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();

      for (final r in rowsOf('categories')) {
        await db.into(db.categories).insertOnConflictUpdate(CategoriesCompanion.insert(
              id: r['id'] as String,
              parentId: Value(r['parent_id'] as String?),
              name: r['name'] as String,
              updatedAt: Value(r['updated_at'] as String?),
              deletedAt: Value(r['deleted_at'] as String?),
            ));
      }
      for (final r in rowsOf('products')) {
        if (skipProducts.contains(r['id'])) continue;
        await db.into(db.products).insertOnConflictUpdate(ProductsCompanion.insert(
              id: r['id'] as String,
              categoryId: Value(r['category_id'] as String?),
              name: r['name'] as String,
              searchName: Value(searchKey(r['name'] as String)),
              unit: Value(r['unit'] as String? ?? 'pc'),
              taxRate: Value((r['tax_rate'] as num?)?.toDouble() ?? 0),
              trackStock: Value(r['track_stock'] as bool? ?? true),
              active: Value(r['active'] as bool? ?? true),
              photoPath: Value(r['photo_path'] as String?),
              updatedAt: Value(r['updated_at'] as String?),
              deletedAt: Value(r['deleted_at'] as String?),
            ));
      }
      for (final r in rowsOf('product_variants')) {
        if (skipVariants.contains(r['id']) || skipProducts.contains(r['product_id'])) continue;
        await db.into(db.variants).insertOnConflictUpdate(VariantsCompanion.insert(
              id: r['id'] as String,
              productId: r['product_id'] as String,
              sku: r['sku'] as String,
              barcode: Value(r['barcode'] as String?),
              isDefault: Value(r['is_default'] as bool? ?? true),
              cost: Value((r['cost'] as num?)?.toInt() ?? 0),
              reorderPoint: Value((r['reorder_point'] as num?)?.toDouble() ?? 0),
              active: Value(r['active'] as bool? ?? true),
              updatedAt: Value(r['updated_at'] as String?),
              deletedAt: Value(r['deleted_at'] as String?),
            ));
      }
      for (final r in rowsOf('variant_prices')) {
        if (skipVariants.contains(r['variant_id'])) continue;
        await db.into(db.prices).insertOnConflictUpdate(PricesCompanion.insert(
              variantId: r['variant_id'] as String,
              currency: (r['currency'] as String).trim(),
              price: (r['price'] as num).toInt(),
              updatedAt: Value(r['updated_at'] as String?),
              deletedAt: Value(r['deleted_at'] as String?),
            ));
      }

      for (final t in _syncTables) {
        final cursor = (response[t] as Map?)?['cursor'];
        if (cursor is Map) {
          await db
              .into(db.syncCursors)
              .insertOnConflictUpdate(SyncCursorsCompanion.insert(tableKey: t, cursorJson: jsonEncode(cursor)));
        }
      }
    });
  }

  OutboxOp _op(OutboxData o) => OutboxOp(
        opId: o.opId,
        kind: o.kind,
        entityId: o.entityId,
        payload: (jsonDecode(o.payload) as Map).cast<String, dynamic>(),
        attempts: o.attempts,
        lastError: o.lastError,
      );

  @override
  Future<List<OutboxOp>> nextOps({int limit = 50}) async {
    final rows = await (db.select(db.outbox)
          ..where((o) => o.status.equals('pending'))
          ..orderBy([(o) => OrderingTerm.asc(o.seq)])
          ..limit(limit))
        .get();
    return rows.map(_op).toList();
  }

  @override
  Future<void> opDone(String opId) => (db.delete(db.outbox)..where((o) => o.opId.equals(opId))).go();

  @override
  Future<void> opFailed(String opId, String error) => (db.update(db.outbox)..where((o) => o.opId.equals(opId)))
      .write(OutboxCompanion(status: const Value('failed'), lastError: Value(error)));

  @override
  Future<void> opRetryLater(String opId, String error) => db.customUpdate(
        'update outbox set attempts = attempts + 1, last_error = ?1 where op_id = ?2',
        variables: [Variable.withString(error), Variable.withString(opId)],
        updates: {db.outbox},
      );

  @override
  Stream<OutboxCounts> watchOutboxCounts() => db
      .customSelect(
        "select coalesce(sum(status = 'pending'), 0) as p, coalesce(sum(status = 'failed'), 0) as f from outbox",
        readsFrom: {db.outbox},
      )
      .watchSingle()
      .map((r) => OutboxCounts(r.read<int>('p'), r.read<int>('f')));

  @override
  Future<List<OutboxOp>> failedOps() async {
    final rows = await (db.select(db.outbox)
          ..where((o) => o.status.equals('failed'))
          ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
        .get();
    return rows.map(_op).toList();
  }

  // ---------------------------------------------------------------------------
  // Photos
  // ---------------------------------------------------------------------------

  @override
  Future<String> setPhoto(String productId, String variantId, Uint8List jpeg, {required String opId}) {
    return db.transaction(() async {
      final tenant = (await (db.select(db.meta)..where((m) => m.key.equals('tenant_id'))).getSingle()).value;
      final path = '$tenant/$productId/$opId.jpg';
      await db.into(db.photoUploads).insert(
          PhotoUploadsCompanion.insert(opId: opId, productId: productId, path: path, bytes: jpeg));
      await db.into(db.photoCache).insertOnConflictUpdate(
          PhotoCacheCompanion.insert(productId: productId, path: path, bytes: jpeg));
      await (db.update(db.products)..where((p) => p.id.equals(productId)))
          .write(ProductsCompanion(photoPath: Value(path)));
      await _enqueue(opId, 'upload_photo', productId, {'product_id': productId, 'variant_id': variantId, 'path': path});
      return path;
    });
  }

  @override
  Future<Uint8List?> cachedPhoto(String productId, String path) async {
    final row = await (db.select(db.photoCache)
          ..where((c) => c.productId.equals(productId) & c.path.equals(path)))
        .getSingleOrNull();
    return row?.bytes;
  }

  @override
  Future<void> cachePhoto(String productId, String path, Uint8List bytes) => db
      .into(db.photoCache)
      .insertOnConflictUpdate(PhotoCacheCompanion.insert(productId: productId, path: path, bytes: bytes));

  @override
  Future<Uint8List?> pendingPhoto(String opId) async =>
      (await (db.select(db.photoUploads)..where((u) => u.opId.equals(opId))).getSingleOrNull())?.bytes;

  @override
  Future<void> photoUploaded(String opId) => (db.delete(db.photoUploads)..where((u) => u.opId.equals(opId))).go();

  @override
  Future<void> close() => db.close();

  @override
  Future<void> discardFailed(String opId) {
    return db.transaction(() async {
      final op = await (db.select(db.outbox)..where((o) => o.opId.equals(opId))).getSingleOrNull();
      if (op == null) return;
      await opDone(opId);
      await photoUploaded(opId);
      await (db.delete(db.localMovements)..where((m) => m.opId.equals(opId))).go();
      await (db.delete(db.localLedger)..where((m) => m.opId.equals(opId))).go();
      await (db.delete(db.localFloatEffects)..where((m) => m.opId.equals(opId))).go();
      if (op.kind == 'record_sale') await deleteSaleRows(op.entityId);
      await undoLocalOp(op.kind, op.entityId); // expenses, day closes, service entries
      final stillPending = await (db.select(db.outbox)..where((o) => o.entityId.equals(op.entityId))).get();
      final product = await (db.select(db.products)..where((p) => p.id.equals(op.entityId))).getSingleOrNull();
      // never reached the server: remove the local-only rows
      if (stillPending.isEmpty && product != null && product.updatedAt == null) {
        final vids = await (db.select(db.variants)..where((v) => v.productId.equals(op.entityId))).map((v) => v.id).get();
        await (db.delete(db.prices)..where((p) => p.variantId.isIn(vids))).go();
        await (db.delete(db.openingStock)..where((s) => s.variantId.isIn(vids))).go();
        await (db.delete(db.localMovements)..where((m) => m.variantId.isIn(vids))).go();
        await (db.delete(db.variants)..where((v) => v.productId.equals(op.entityId))).go();
        await (db.delete(db.products)..where((p) => p.id.equals(op.entityId))).go();
      }
      // re-pull everything so local rows match the server again
      await db.delete(db.syncCursors).go();
    });
  }
}
