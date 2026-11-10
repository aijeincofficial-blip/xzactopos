import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/data/transfer_models.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/transfer_create_screen.dart';
import 'package:xzactopos_mobile/sync/photo_loader.dart';
import 'package:xzactopos_mobile/sync/store_session.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'widget_test.dart' show FakeBackend;

class _FakeOutboundTransferBackend extends FakeBackend {
  final List<TransferLocationRef> destinations;
  final List<Map<String, dynamic>> createCalls = [];

  _FakeOutboundTransferBackend({required this.destinations});

  @override
  Future<List<TransferLocationRef>> fetchTransferDestinations(String currentBranchId) async =>
      destinations;

  @override
  Future<String> createAndShipTransfer({
    required String fromLocationId,
    required String toLocationId,
    required List<TransferDraftLine> items,
    String? notes,
    bool shipNow = true,
  }) async {
    createCalls.add({
      'from_location_id': fromLocationId,
      'to_location_id': toLocationId,
      'items': items,
      'notes': notes,
      'ship_now': shipNow,
    });
    return 'trf-test-999';
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  testWidgets('TransferCreateScreen selects destination, adds items and ships transfer', (tester) async {
    final destinations = [
      const TransferLocationRef(
        id: 'loc-branch-2',
        code: 'BR-02',
        name: 'Makati Branch',
        type: 'store',
      ),
    ];

    final backend = _FakeOutboundTransferBackend(destinations: destinations);
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('tenant-1', baseCurrency: 'PHP', stores: []);

    // Seed product into store
    await store.saveProduct(
      const ProductDraft(
        id: 'prod-101',
        variantId: 'prod-101',
        name: 'Lucky Me Pancit Canton',
        sku: 'SKU-LUCKY-CANTON',
        unit: 'pack',
        price: 1500,
        cost: 1200,
      ),
      opId: 'op-seed-1',
    );

    final engine = SyncEngine(store, backend);
    final photos = PhotoLoader(store, backend);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: CatalogScope(
          store: store,
          engine: engine,
          photos: photos,
          child: TransferCreateScreen(
            backend: backend,
            originLocationId: 'loc-origin-1',
            originName: 'Main Store',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and destination picker
    expect(find.text('New Outbound Transfer'), findsOneWidget);
    expect(find.text('Main Store'), findsOneWidget);
    expect(find.byKey(const Key('transfer-destination-picker')), findsOneWidget);

    // Tap Add Product
    await tester.tap(find.byKey(const Key('transfer-add-item-btn')));
    await tester.pumpAndSettle();

    // Select the seeded product
    expect(find.byKey(const Key('product-choice-prod-101')), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-choice-prod-101')));
    await tester.pumpAndSettle();

    // Product line should now appear on screen
    expect(find.text('Lucky Me Pancit Canton'), findsOneWidget);
    expect(find.byKey(const Key('line-plus-prod-101')), findsOneWidget);

    // Increment quantity to 2
    await tester.tap(find.byKey(const Key('line-plus-prod-101')));
    await tester.pumpAndSettle();

    // Add notes
    await tester.enterText(find.byKey(const Key('transfer-notes-field')), 'Emergency stock replenishment');
    await tester.pumpAndSettle();

    // Ship transfer
    await tester.tap(find.byKey(const Key('transfer-submit-ship')));
    await tester.pumpAndSettle();

    // Verify backend received the call
    expect(backend.createCalls.length, 1);
    expect(backend.createCalls.first['from_location_id'], 'loc-origin-1');
    expect(backend.createCalls.first['to_location_id'], 'loc-branch-2');
    expect(backend.createCalls.first['notes'], 'Emergency stock replenishment');
    final items = backend.createCalls.first['items'] as List<TransferDraftLine>;
    expect(items.length, 1);
    expect(items.first.variantId, 'prod-101');
    expect(items.first.qty, 2.0);

    await store.close();
  });
}
