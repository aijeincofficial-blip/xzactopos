import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xzactopos_mobile/backend.dart';
import 'package:xzactopos_mobile/data/bin_models.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/putaway_screen.dart';

class _FakePutawayBackend implements Backend {
  final List<ReceivingStockItem> receivingItems;
  final List<WarehouseBin> bins;
  final List<Map<String, dynamic>> putawayCalls = [];

  _FakePutawayBackend({
    required this.receivingItems,
    required this.bins,
  });

  @override
  Future<List<ReceivingStockItem>> fetchReceivingStock(String warehouseId) async =>
      receivingItems;

  @override
  Future<List<WarehouseBin>> fetchWarehouseBins(String warehouseId) async => bins;

  @override
  Future<void> executePutaway({
    required String warehouseId,
    required String fromBinId,
    required String toBinId,
    required String variantId,
    required double qty,
  }) async {
    putawayCalls.add({
      'warehouse_id': warehouseId,
      'from_bin_id': fromBinId,
      'to_bin_id': toBinId,
      'variant_id': variantId,
      'qty': qty,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  testWidgets('PutawayScreen shows receiving items and moves stock to bin', (tester) async {
    final receivingItems = [
      const ReceivingStockItem(
        binId: 'bin-rcv-1',
        binCode: 'RECEIVING',
        variantId: 'var-101',
        sku: 'SKU-RICE-25KG',
        productName: 'Sinandomeng Rice 25kg',
        qtyOnHand: 15.0,
      ),
    ];

    final bins = [
      const WarehouseBin(
        id: 'bin-rcv-1',
        code: 'RECEIVING',
        zoneName: 'Receiving Zone',
        type: 'floor',
      ),
      const WarehouseBin(
        id: 'bin-a01-1',
        code: 'A-01-1',
        zoneName: 'General Storage',
        aisle: 'A',
        rack: '01',
        shelf: '1',
        type: 'shelf',
      ),
    ];

    final backend = _FakePutawayBackend(
      receivingItems: receivingItems,
      bins: bins,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: PutawayScreen(
          backend: backend,
          warehouseId: 'wh-main',
          warehouseName: 'Main Bodega',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and product item shown
    expect(find.text('Put-Away'), findsOneWidget);
    expect(find.text('Main Bodega'), findsOneWidget);
    expect(find.text('Sinandomeng Rice 25kg'), findsOneWidget);
    expect(find.text('SKU: SKU-RICE-25KG • Bin: RECEIVING'), findsOneWidget);
    expect(find.text('Available: 15.0'), findsOneWidget);

    // Tap Put Away button
    await tester.tap(find.byKey(const Key('putaway-btn-var-101')));
    await tester.pumpAndSettle();

    // Sheet should open with dialog title and destination bin
    expect(find.text('Put Away Item to Bin'), findsOneWidget);
    expect(find.byKey(const Key('putaway-bin-dropdown')), findsOneWidget);
    expect(find.byKey(const Key('putaway-confirm-btn')), findsOneWidget);

    // Confirm put-away
    await tester.tap(find.byKey(const Key('putaway-confirm-btn')));
    await tester.pumpAndSettle();

    // Verify backend call was made with proper parameters
    expect(backend.putawayCalls.length, 1);
    expect(backend.putawayCalls.first['warehouse_id'], 'wh-main');
    expect(backend.putawayCalls.first['from_bin_id'], 'bin-rcv-1');
    expect(backend.putawayCalls.first['to_bin_id'], 'bin-a01-1');
    expect(backend.putawayCalls.first['variant_id'], 'var-101');
    expect(backend.putawayCalls.first['qty'], 15.0);
  });
}
