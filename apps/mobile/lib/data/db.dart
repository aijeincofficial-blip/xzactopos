import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/search.dart';
import 'web_connection_stub.dart' if (dart.library.js_interop) 'web_connection.dart';

part 'db.g.dart';

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

/// Small key/value facts about this device's data (e.g. which tenant it belongs to).
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Categories, Products, Variants, Prices, SyncCursors, Outbox, OpeningStock, Meta, PhotoUploads, PhotoCache,
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
  int get schemaVersion => 3;

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
        },
      );
}
