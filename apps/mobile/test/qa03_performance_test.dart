import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/customer_picker.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

class _CountingSyncBackend implements SyncApi, OfflinePinApi {
  int pinPullCalls = 0;

  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async => {};

  @override
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async => {};

  @override
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100}) async => {};

  @override
  Future<Map<String, dynamic>> pullExpenses(Map<String, dynamic>? cursor, {int limit = 100}) async => {};

  @override
  Future<Map<String, dynamic>> pullDayCloses(Map<String, dynamic>? cursor, {int limit = 100}) async => {};

  @override
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100}) async => {};

  @override
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100}) async => {};

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async => [];

  @override
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload) async {}

  @override
  Future<void> archiveProduct(String opId, String productId) async {}

  @override
  Future<void> uploadPhoto(String path, Uint8List jpeg) async {}

  @override
  Future<Uint8List> downloadPhoto(String path) async => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> pullOfflinePins({String? locationId}) async {
    pinPullCalls++;
    return const [];
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const expectedIndexes = [
    'idx_products_active_search',
    'idx_variants_product_deleted',
    'idx_variants_sku',
    'idx_variants_breaks_into',
    'idx_prices_variant_currency',
    'idx_stock_levels_variant_loc',
    'idx_stock_expiry_variant_loc',
    'idx_outbox_entity',
    'idx_outbox_status',
    'idx_server_ledger_customer',
    'idx_local_ledger_customer_op',
    'idx_local_movements_variant_op',
    'idx_shifts_cashier_closed',
  ];

  test('schema v18 creates all 13 performance indexes on fresh install and upgrade', () async {
    final fresh = AppDatabase(NativeDatabase.memory());
    await fresh.customSelect('SELECT 1').get();
    expect(fresh.schemaVersion, 18);

    final freshIndexes = {
      for (final r in await fresh.customSelect("SELECT name FROM sqlite_master WHERE type = 'index'").get())
        r.read<String>('name'),
    };
    for (final idx in expectedIndexes) {
      expect(freshIndexes, contains(idx), reason: 'fresh install should create $idx');
    }
    await fresh.close();

    // Verify real v17 -> v18 file upgrade recreates dropped indexes cleanly.
    final tmpDir = Directory.systemTemp.createTempSync('qa03_v17_upgrade_');
    final dbFile = File('${tmpDir.path}/pos.sqlite');
    try {
      final v17 = AppDatabase(NativeDatabase(dbFile));
      await v17.customSelect('SELECT 1').get();
      for (final idx in expectedIndexes) {
        await v17.customStatement('DROP INDEX IF EXISTS $idx');
      }
      await v17.customStatement('PRAGMA user_version = 17');
      await v17.close();

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      await upgraded.customSelect('SELECT 1').get();
      final version = (await upgraded.customSelect('PRAGMA user_version').getSingle()).data.values.single;
      expect(version, 18);
      final upgradedIndexes = {
        for (final r in await upgraded.customSelect("SELECT name FROM sqlite_master WHERE type = 'index'").get())
          r.read<String>('name'),
      };
      for (final idx in expectedIndexes) {
        expect(upgradedIndexes, contains(idx), reason: 'upgrade from v17 should create $idx');
      }
      await upgraded.close();
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('batched applyPull, applyPullSales, and single-variant averageCost preserve correctness', () async {
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('t-qa03', baseCurrency: 'PHP', locationId: 'loc-1');

    await store.applyPull({
      'categories': {'rows': const []},
      'products': {
        'rows': [
          {'id': 'p1', 'name': 'Rice 25kg', 'updated_at': '2026-11-14T00:00:00Z'},
          {'id': 'p2', 'name': 'Sugar 1kg', 'updated_at': '2026-11-14T00:00:00Z'},
        ],
      },
      'product_variants': {
        'rows': [
          {'id': 'v1', 'product_id': 'p1', 'name': 'Sack', 'sku': 'RICE-25', 'updated_at': '2026-11-14T00:00:00Z'},
          {'id': 'v2', 'product_id': 'p2', 'name': 'Pack', 'sku': 'SUG-1', 'updated_at': '2026-11-14T00:00:00Z'},
        ],
      },
      'variant_prices': {
        'rows': [
          {'variant_id': 'v1', 'currency': 'PHP', 'price': 125000, 'updated_at': '2026-11-14T00:00:00Z'},
          {'variant_id': 'v2', 'currency': 'PHP', 'price': 8500, 'updated_at': '2026-11-14T00:00:00Z'},
        ],
      },
    });

    await store.applyPullPos({
      'stock_levels': {
        'rows': [
          {'location_id': 'loc-1', 'variant_id': 'v1', 'qty_on_hand': 10, 'avg_cost': 90000, 'updated_at': '2026-11-14T00:00:00Z'},
          {'location_id': 'loc-1', 'variant_id': 'v2', 'qty_on_hand': 5, 'avg_cost': 6000, 'updated_at': '2026-11-14T00:00:00Z'},
        ],
      },
    });

    // Receive additional stock for v1 and verify averageCost only inspects/reflects v1.
    await store.receiveStock(
      variantId: 'v1',
      qty: 10,
      cost: 110000,
      opId: 'op-recv-v1',
    );
    expect(await store.averageCost('v1'), 100000);
    expect(await store.averageCost('v2'), 6000);

    await store.applyPullSales({
      'rows': [
        {
          'id': 's1',
          'location_id': 'loc-1',
          'local_no': 'L-0001',
          'sale_no': 'S-0001',
          'status': 'completed',
          'subtotal': 125000,
          'discount': 0,
          'tax': 0,
          'total': 125000,
          'sold_at': '2026-11-14T01:00:00Z',
          'items': [
            {
              'variant_id': 'v1',
              'name': 'Rice 25kg',
              'qty': 1,
              'unit_price': 125000,
              'unit_cost': 90000,
              'discount': 0,
              'tax': 0,
              'line_total': 125000,
            },
          ],
          'payments': [
            {'method': 'cash', 'amount': 125000},
          ],
        },
      ],
      'cursor': {'ts': '2026-11-14T01:00:00Z', 'id': 's1'},
    });

    final receipt = await store.getSale('s1');
    expect(receipt?.saleNo, 'S-0001');
    expect(receipt?.items.single.name, 'Rice 25kg');
    await store.close();
  });

  test('SyncEngine throttles offline PIN pulls within 15 minutes', () async {
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant(
      't-qa03',
      baseCurrency: 'PHP',
      stores: const [StoreRef(id: 'loc-1', name: 'Main')],
    );
    final api = _CountingSyncBackend();
    final engine = SyncEngine(store, api);

    await engine.syncNow();
    expect(api.pinPullCalls, 1);

    await engine.syncNow();
    expect(api.pinPullCalls, 1, reason: 'second sync within 15m should reuse cached offline PINs');

    engine.dispose();
    await store.close();
  });

  testWidgets('CustomerPicker debounces search and virtualizes list rows', (tester) async {
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('t-qa03', baseCurrency: 'PHP', locationId: 'loc-1');
    await store.applyPullPos({
      'customers': {
        'rows': [
          for (var i = 0; i < 100; i++)
            {'id': 'c-$i', 'name': 'Customer ${i.toString().padLeft(3, '0')}', 'updated_at': '2026-11-14T00:00:00Z'},
        ],
      },
    });

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: (ctx) {
        return Center(
          child: ElevatedButton(
            onPressed: () => pickCustomer(ctx, store),
            child: const Text('Open'),
          ),
        );
      })),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Virtualized ListView.builder only builds visible viewport rows, not all 100 upfront.
    expect(find.byKey(const Key('customer-c-0')), findsOneWidget);
    expect(find.byKey(const Key('customer-c-99')), findsNothing);

    await tester.enterText(find.byKey(const Key('customer-search')), '099');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-c-99')), findsOneWidget);

    await store.close();
  });
}
