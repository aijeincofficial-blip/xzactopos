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

  /// Tingi (schema v8): one of this pack variant breaks into [breaksIntoQty] of that piece variant. Both or neither.
  TextColumn get breaksIntoVariantId => text().nullable()();
  IntColumn get breaksIntoQty => integer().nullable()();

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

  /// The date the customer promised to pay, 'YYYY-MM-DD' (schema v9, P8-10); null = none. Text compares as a date.
  TextColumn get dueOn => text().nullable()();

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
  IntColumn get avgCost => integer().nullable()();

  /// Someone has told the system how many there are (opening stock, stock in, a count). Sales alone do not count.
  BoolColumn get counted => boolean().withDefault(const Constant(false))();
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

  /// Opening stock, stock in or a count: makes the product "counted". A sale does not.
  BoolColumn get counts => boolean().withDefault(const Constant(false))();
  TextColumn get confirmedAfter => text().nullable()();

  /// Stock in with a cost (schema v8): centavos per unit; moves the average cost like the server's receipt.
  IntColumn get unitCost => integer().nullable()();

  /// Pieces from an opened pack (schema v8): the value they carry in centavos; moves the piece's average cost.
  IntColumn get totalCost => integer().nullable()();
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

  /// The store wallet an `ewallet` payment went into: gcash | maya | other (schema v12, P8-15); null = not named.
  TextColumn get wallet => text().nullable()();
}

// ---- Phase 8: expenses and the day close (schema v6) ----

/// Money the store spent: made here (sent by a record_expense op) or pulled from the server (sync_pull_expenses).
/// A void sets [voidedAt] (a void_expense op); nothing is ever deleted. [updatedAt] is the server's, null until the
/// server's copy has been pulled. "Pending" is not stored: it is "this id still has an op in the outbox".
@TableIndex(name: 'expenses_spent_at', columns: {#spentAt})
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get locationId => text().nullable()();
  IntColumn get amount => integer()();
  TextColumn get currency => text()();
  TextColumn get category => text()();
  TextColumn get paidFrom => text().withDefault(const Constant('cash'))();

  /// The store wallet an `ewallet` expense was paid from: gcash | maya | other (schema v12, P8-15); null = not named.
  TextColumn get wallet => text().nullable()();
  TextColumn get note => text().nullable()();

  /// UTC ISO-8601, normalised (the same format as `sales.sold_at`), so text comparison orders correctly.
  TextColumn get spentAt => text()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get approvedBy => text().nullable()();
  TextColumn get voidedAt => text().nullable()();
  TextColumn get voidReason => text().nullable()();
  TextColumn get voidApprovedBy => text().nullable()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cash counts at the end of a day (close_day ops, sync_pull_day_closes). Several per day are allowed (a re-count);
/// the newest [closedAt] is the one shown. Append-only like the server table.
@TableIndex(name: 'day_closes_day', columns: {#day})
class DayCloses extends Table {
  TextColumn get id => text()();
  TextColumn get locationId => text().nullable()();

  /// The business day, YYYY-MM-DD (device local date = tenant timezone for the solo store).
  TextColumn get day => text()();
  TextColumn get currency => text()();
  IntColumn get expectedCash => integer()();
  IntColumn get countedCash => integer()();
  IntColumn get difference => integer()();

  /// What the server computed from its own data when it applied the close; null until pulled.
  IntColumn get serverExpectedCash => integer().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get closedBy => text().nullable()();
  TextColumn get approvedBy => text().nullable()();
  TextColumn get closedAt => text()();
  TextColumn get updatedAt => text().nullable()();

  /// Cash the drawer started the day with (sukli), centavos >= 0 (schema v11, P8-14). Part of [expectedCash].
  IntColumn get openingCash => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---- Phase 8: load / e-wallet services (schema v7) ----

/// Load / e-wallet service entries (cash-in, cash-out, load, float moves): made here (record_service_txn op) or pulled
/// (sync_pull_service). A void sets [voidedAt] (void_service_txn op); nothing is deleted. [updatedAt] is the server's,
/// null until the server's copy has been pulled. Money model: `serviceCashEffect` / `serviceFloatEffect` in
/// sales_models.dart.
@TableIndex(name: 'service_txns_txn_at', columns: {#txnAt})
class ServiceTxns extends Table {
  TextColumn get id => text()();
  TextColumn get locationId => text().nullable()();

  /// cash_in | cash_out | load | float_topup | float_withdraw | float_adjust
  TextColumn get kind => text()();

  /// gcash | maya | load | other
  TextColumn get wallet => text()();

  /// Centavos; > 0, except a float_adjust (signed, never 0).
  IntColumn get amount => integer()();
  IntColumn get fee => integer().withDefault(const Constant(0))();

  /// Cash the customer paid for a load (load only).
  IntColumn get price => integer().nullable()();
  TextColumn get currency => text()();

  /// Customer reference (phone, wallet reference no.). Sensitive: shown in the list only.
  TextColumn get ref => text().nullable()();
  TextColumn get note => text().nullable()();

  /// UTC ISO-8601, normalised (same format as `sales.sold_at`).
  TextColumn get txnAt => text()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get approvedBy => text().nullable()();
  TextColumn get voidedAt => text().nullable()();
  TextColumn get voidReason => text().nullable()();
  TextColumn get voidApprovedBy => text().nullable()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The server's float balance per store and wallet, as of the last sync_pull_service (`floats`).
class WalletFloats extends Table {
  @override
  String get tableName => 'wallet_float';

  TextColumn get locationId => text()();
  TextColumn get wallet => text()();
  IntColumn get balance => integer()();
  IntColumn get txnCount => integer().withDefault(const Constant(0))();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {locationId, wallet};
}

/// Float effects of service ops made on this device (a record, or the reversal of a void), counted on top of
/// [WalletFloats] until a pulled balance covers them (`confirmedAfter` = when the server applied the op; dropped once a
/// float snapshot at or after that time has been pulled). Like `local_movements` for stock.
class LocalFloatEffects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opId => text()();
  TextColumn get txnId => text()();
  TextColumn get wallet => text()();
  IntColumn get amount => integer()();
  TextColumn get confirmedAfter => text().nullable()();
}

// ---- Phase 8: tingi / repack (schema v8) ----

/// Opened packs (open_pack op, sync_pull_conversions): one pack variant out, its pieces in. Made here or pulled; a void
/// sets [voidedAt] (void_open_pack op), nothing is deleted. [updatedAt] is the server's, null until pulled. The stock
/// effects themselves live in `local_movements` (by op id) until the server's levels cover them.
@TableIndex(name: 'conversions_converted_at', columns: {#convertedAt})
class Conversions extends Table {
  TextColumn get id => text()();
  TextColumn get locationId => text().nullable()();
  TextColumn get packVariantId => text()();
  TextColumn get pieceVariantId => text()();
  IntColumn get packs => integer()();

  /// Pieces per pack at the time of opening.
  IntColumn get ratio => integer()();
  IntColumn get pieces => integer()();

  /// Centavos: pack cost used, packs x pack cost, half_up(total / pieces). Null when no cost was known.
  IntColumn get packCost => integer().nullable()();
  IntColumn get totalCost => integer().nullable()();
  IntColumn get pieceCost => integer().nullable()();
  TextColumn get note => text().nullable()();

  /// UTC ISO-8601, normalised (same format as `sales.sold_at`).
  TextColumn get convertedAt => text()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get voidedAt => text().nullable()();
  TextColumn get voidReason => text().nullable()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---- Phase 8: expiry dates (schema v10) ----

/// The earliest expiry date on the shelf per variant (P8-11; one date, no lots), for this device's store. Written here by
/// set_expiry / receive_stock (then [updatedAt] is null: a local edit not yet confirmed) or pulled (sync_pull_pos
/// `stock_expiry`, the server's updated_at). [expiresOn] 'YYYY-MM-DD', null = cleared. Keyed by variant only: a device
/// works for one store (pulled rows of other stores are skipped when the device knows its store).
class StockExpiry extends Table {
  @override
  String get tableName => 'stock_expiry';

  TextColumn get variantId => text()();
  TextColumn get locationId => text().nullable()();
  TextColumn get expiresOn => text().nullable()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {variantId};
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
  Expenses, DayCloses, ServiceTxns, WalletFloats, LocalFloatEffects, Conversions, StockExpiry,
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
  int get schemaVersion => 12;

  /// Adds a column unless it is there already (a database made by a newer build and stepped back in a test, or a
  /// table an earlier step created with today's definition). Skips a table that does not exist.
  Future<void> _addColumnIfMissing(Migrator m, TableInfo table, GeneratedColumn column) async {
    final cols = await customSelect('PRAGMA table_info(${table.actualTableName})').get();
    if (cols.isEmpty || cols.any((c) => c.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }

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
                  LocalMovementsCompanion.insert(opId: opId, variantId: o.variantId, qty: o.qty, counts: const Value(true)));
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
          if (from >= 4 && from < 5) {
            await m.addColumn(stockLevels, stockLevels.avgCost);
            await m.addColumn(stockLevels, stockLevels.counted);
            await m.addColumn(localMovements, localMovements.counts);
            await customStatement(
                "update local_movements set counts = 1 where op_id in (select op_id from outbox where kind = 'post_opening_stock')");
            // levels pulled before the flag existed must come again
            await customStatement("delete from sync_cursors where table_key = 'stock_levels'");
          }
          if (from < 6) {
            // new tables only; every existing row stays as it is
            await m.createTable(expenses);
            await m.createTable(dayCloses);
          }
          if (from < 7) {
            // new tables only; every existing row stays as it is (createTable is IF NOT EXISTS)
            await m.createTable(serviceTxns);
            await m.createTable(walletFloats);
            await m.createTable(localFloatEffects);
            await customStatement('CREATE INDEX IF NOT EXISTS service_txns_txn_at ON service_txns (txn_at)');
            // the v6 step created its tables without their indexes
            await customStatement('CREATE INDEX IF NOT EXISTS expenses_spent_at ON expenses (spent_at)');
            await customStatement('CREATE INDEX IF NOT EXISTS day_closes_day ON day_closes (day)');
          }
          if (from < 8) {
            // additive only: the tingi link on variants, costs on local movements, a conversions table
            await _addColumnIfMissing(m, variants, variants.breaksIntoVariantId);
            await _addColumnIfMissing(m, variants, variants.breaksIntoQty);
            await _addColumnIfMissing(m, localMovements, localMovements.unitCost);
            await _addColumnIfMissing(m, localMovements, localMovements.totalCost);
            await m.createTable(conversions);
            await customStatement('CREATE INDEX IF NOT EXISTS conversions_converted_at ON conversions (converted_at)');
            // variants pulled before the link existed must come again so the link columns are filled
            final hasCursors = await customSelect(
                    "select 1 from sqlite_master where type = 'table' and name = 'sync_cursors'")
                .get();
            if (hasCursors.isNotEmpty) {
              await customStatement("delete from sync_cursors where table_key = 'product_variants'");
            }
          }
          if (from < 9) {
            // additive only: the promised payment date on customers (every row kept, the date starts empty)
            await _addColumnIfMissing(m, customers, customers.dueOn);
            // customers pulled before the column existed come again, so a date set elsewhere is not missed
            final hasCursors = await customSelect(
                    "select 1 from sqlite_master where type = 'table' and name = 'sync_cursors'")
                .get();
            if (hasCursors.isNotEmpty) {
              await customStatement("delete from sync_cursors where table_key = 'customers'");
            }
          }
          if (from < 10) {
            // a new table only (IF NOT EXISTS); every existing row stays. No cursor yet, so the first pull brings every date.
            await m.createTable(stockExpiry);
          }
          if (from < 11) {
            // additive only: the opening cash of a day close (every row kept with 0, what closes before P8-14 meant). The
            // server's earlier closes have opening_cash 0 as well, so no re-pull is needed.
            await _addColumnIfMissing(m, dayCloses, dayCloses.openingCash);
          }
          if (from < 12) {
            // additive only: the wallet of an e-wallet sale payment / expense (every row kept with none, what rows before
            // P8-15 meant; the server's earlier rows have no wallet either, so no re-pull is needed)
            await _addColumnIfMissing(m, salePayments, salePayments.wallet);
            await _addColumnIfMissing(m, expenses, expenses.wallet);
          }
        },
      );
}
