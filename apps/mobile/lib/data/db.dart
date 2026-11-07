import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/search.dart';
import 'web_connection_stub.dart' if (dart.library.js_interop) 'web_connection.dart';

part 'db.g.dart';

/// The op id of the one opening-stock entry of a variant. Fixed per variant, so asking twice can never count twice.
String openingOpId(String variantId) => variantId.length == 36
    ? '${variantId.substring(0, 14)}8${variantId.substring(15)}'
    : 'open:$variantId';

// Local mirror of the server catalog (sync_pull_catalog rows), plus sync bookkeeping.
// Ids are the server UUIDs as text. Money is integer minor units. Server timestamps are kept as the raw
// ISO strings the server sent, so nothing is lost to local DateTime precision.

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();

  /// searchKey(name): lower case, no accents. Written with every name change (schema v2).
  TextColumn get searchName => text().withDefault(const Constant(''))();
  TextColumn get unit => text().withDefault(const Constant('pc'))();
  RealColumn get taxRate => real().withDefault(const Constant(0))();
  BoolColumn get trackStock => boolean().withDefault(const Constant(true))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get photoPath => text().nullable()();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'variants_barcode', columns: {#barcode})
@TableIndex(name: 'variants_product', columns: {#productId})
class Variants extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get sku => text()();
  TextColumn get barcode => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(true))();
  IntColumn get cost => integer().withDefault(const Constant(0))();
  RealColumn get reorderPoint => real().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Prices extends Table {
  TextColumn get variantId => text()();
  TextColumn get currency => text()();
  IntColumn get price => integer()();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {variantId, currency};
}

/// One cursor per server table: {"ts": ..., "k": ...} as returned by sync_pull_catalog.
class SyncCursors extends Table {
  TextColumn get tableKey => text()();
  TextColumn get cursorJson => text()();

  @override
  Set<Column> get primaryKey => {tableKey};
}

/// Ops waiting to reach the server. status: pending | failed (permanent; shown as "needs attention").
class Outbox extends Table {
  TextColumn get opId => text()();
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {opId},
      ];
}

/// Opening stock typed when a product is added. Held on the device until the stock ledger exists (Phase 4).
class OpeningStock extends Table {
  TextColumn get variantId => text()();
  RealColumn get qty => real()();

  @override
  Set<Column> get primaryKey => {variantId};
}

/// Photo bytes waiting to be uploaded, keyed by the upload_photo op (schema v3).
class PhotoUploads extends Table {
  TextColumn get opId => text()();
  TextColumn get productId => text()();
  TextColumn get path => text()();
  BlobColumn get bytes => blob()();

  @override
  Set<Column> get primaryKey => {opId};
}

/// Last photo seen per product (its storage path and JPEG bytes), so lists work offline (schema v3).
class PhotoCache extends Table {
  TextColumn get productId => text()();
  TextColumn get path => text()();
  BlobColumn get bytes => blob()();

  @override
  Set<Column> get primaryKey => {productId};
}

// ---- Phase 3: sales, stock and utang (schema v4) ----

/// Utang customers (server copy plus local edits; edits go through the outbox).
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Utang ledger rows pulled from the server. charge > 0, payment < 0.
class ServerLedger extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get kind => text()();
  IntColumn get amount => integer()();
  TextColumn get saleId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Utang entries made on this device. They count in balances until the server's copy has been pulled
/// (`confirmedAfter` = the time the server applied the op; removed once a pull has passed it).
class LocalLedger extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opId => text()();
  TextColumn get customerId => text()();
  TextColumn get kind => text()();
  IntColumn get amount => integer()();
  TextColumn get saleId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get confirmedAfter => text().nullable()();
}

/// Server stock level per store and variant (sync_pull_pos).
class StockLevels extends Table {
  TextColumn get locationId => text()();
  TextColumn get variantId => text()();
  RealColumn get qty => real()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {locationId, variantId};
}

/// Stock movements made on this device, counted like [LocalLedger] until the server level has caught up.
class LocalMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opId => text()();
  TextColumn get variantId => text()();
  RealColumn get qty => real()();
  TextColumn get confirmedAfter => text().nullable()();
}

/// Sales made on this device (receipts). Not pulled from the server.
@TableIndex(name: 'sales_sold_at', columns: {#soldAt})
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get localNo => text()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  IntColumn get subtotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  TextColumn get customerId => text().nullable()();
  TextColumn get soldAt => text()();
  TextColumn get voidedAt => text().nullable()();
  TextColumn get voidReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'sale_items_sale', columns: {#saleId})
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get saleId => text()();
  TextColumn get variantId => text()();
  TextColumn get name => text()();
  RealColumn get qty => real()();
  IntColumn get unitPrice => integer()();
  IntColumn get unitCost => integer().withDefault(const Constant(0))();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get lineTotal => integer()();
  BoolColumn get tracked => boolean().withDefault(const Constant(true))();
}

@TableIndex(name: 'sale_payments_sale', columns: {#saleId})
class SalePayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get saleId => text()();
  TextColumn get method => text()();
  IntColumn get amount => integer()();
  IntColumn get tendered => integer().nullable()();
  TextColumn get reference => text().nullable()();
}

/// Small key/value facts about this device's data (e.g. which tenant it belongs to).
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Categories, Products, Variants, Prices, SyncCursors, Outbox, OpeningStock, Meta, PhotoUploads, PhotoCache,
  Customers, ServerLedger, LocalLedger, StockLevels, LocalMovements, Sales, SaleItems, SalePayments,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Device database: SQLite file on Android, sqlite3.wasm + IndexedDB/OPFS in the browser.
  /// [safeMode] (web only) skips workers and runs SQLite in the page; used when the normal open fails.
  factory AppDatabase.open({bool safeMode = false}) {
    if (safeMode && kIsWeb) return AppDatabase(safeWebConnection(_name));
    return AppDatabase(driftDatabase(
      name: _name,
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ));
  }

  static const _name = 'xzactopos';

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(products, products.searchName);
            for (final p in await select(products).get()) {
              await (update(products)..where((x) => x.id.equals(p.id)))
                  .write(ProductsCompanion(searchName: Value(searchKey(p.name))));
            }
          }
          if (from < 3) {
            await m.createTable(photoUploads);
            await m.createTable(photoCache);
          }
          if (from < 4) {
            for (final t in <TableInfo<Table, dynamic>>[
              customers, serverLedger, localLedger, stockLevels, localMovements, sales, saleItems, salePayments,
            ]) {
              await m.createTable(t);
            }
            // opening stock typed before Phase 3 was kept on the device only: turn it into real ops now
            final hasOpening = await customSelect(
                    "select 1 from sqlite_master where type = 'table' and name = 'opening_stock'")
                .get();
            for (final o in hasOpening.isEmpty ? <OpeningStockData>[] : await select(openingStock).get()) {
              final v = await (select(variants)..where((x) => x.id.equals(o.variantId))).getSingleOrNull();
              if (v == null || o.qty <= 0) continue;
              final opId = openingOpId(o.variantId);
              await into(localMovements).insert(
                  LocalMovementsCompanion.insert(opId: opId, variantId: o.variantId, qty: o.qty));
              await into(outbox).insert(OutboxCompanion.insert(
                opId: opId,
                kind: 'post_opening_stock',
                entityId: v.productId,
                payload: jsonEncode({'variant_id': o.variantId, 'qty': o.qty}),
                createdAt: DateTime.now().toUtc(),
              ));
            }
            if (hasOpening.isNotEmpty) await delete(openingStock).go();
          }
        },
      );
}
