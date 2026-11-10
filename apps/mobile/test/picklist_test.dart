import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xzactopos_mobile/backend.dart';
import 'package:xzactopos_mobile/data/bin_models.dart';
import 'package:xzactopos_mobile/data/transfer_models.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/picklist_screen.dart';

import 'widget_test.dart' show FakeBackend;

class _FakePickListBackend extends FakeBackend implements BinApi {
  _FakePickListBackend({
    required this.draftTransfers,
    required this.pickList,
  });

  final List<TransferHeader> draftTransfers;
  PickListSummary pickList;
  final List<Map<String, dynamic>> pickCalls = [];

  @override
  Future<List<TransferHeader>> fetchDraftTransfers(String warehouseId) async => draftTransfers;

  @override
  Future<PickListSummary?> fetchPickListForTransfer(String transferId) async => pickList;

  @override
  Future<String> generatePickList(String transferId) async => pickList.id;

  @override
  Future<void> confirmPickItem({
    required String pickListId,
    required String itemId,
    required double qtyPicked,
    String? shortReason,
  }) async {
    pickCalls.add({
      'pick_list_id': pickListId,
      'item_id': itemId,
      'qty_picked': qtyPicked,
      'short_reason': shortReason,
    });
    // Update local state to reflect pick
    final updatedItems = pickList.items.map((i) {
      if (i.id == itemId) {
        return PickListItem(
          id: i.id,
          pickListId: i.pickListId,
          variantId: i.variantId,
          sku: i.sku,
          productName: i.productName,
          binId: i.binId,
          binCode: i.binCode,
          locationInfo: i.locationInfo,
          qtyRequested: i.qtyRequested,
          qtyPicked: qtyPicked,
          shortReason: shortReason,
        );
      }
      return i;
    }).toList();
    pickList = PickListSummary(
      id: pickList.id,
      warehouseId: pickList.warehouseId,
      transferId: pickList.transferId,
      pickListNo: pickList.pickListNo,
      status: 'in_progress',
      createdAt: pickList.createdAt,
      items: updatedItems,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  testWidgets('PickListScreen shows draft transfers, opens pick list, and confirms item pick', (tester) async {
    final transfer = TransferHeader(
      id: 'trf-101',
      transferNo: 'TRF-261110-0001',
      fromLocationId: 'wh-main',
      fromLocationName: 'Main Bodega',
      toLocationId: 'str-01',
      toLocationName: 'Downtown Branch',
      status: 'draft',
      items: const [
        TransferItem(
          id: 'ti-1',
          transferId: 'trf-101',
          variantId: 'var-1',
          sku: 'SKU-BEER-CAN',
          productName: 'San Miguel Pale Pilsen',
          unit: 'can',
          qtyShipped: 10,
        ),
      ],
    );

    final pickList = PickListSummary(
      id: 'pck-201',
      warehouseId: 'wh-main',
      transferId: 'trf-101',
      pickListNo: 'PCK-261110-0001',
      status: 'pending',
      createdAt: DateTime.now().toIso8601String(),
      items: const [
        PickListItem(
          id: 'pli-1',
          pickListId: 'pck-201',
          variantId: 'var-1',
          sku: 'SKU-BEER-CAN',
          productName: 'San Miguel Pale Pilsen',
          binId: 'bin-b02',
          binCode: 'B-02-1',
          locationInfo: 'Aisle B - Rack 02 - Shelf 1',
          qtyRequested: 10,
          qtyPicked: 0,
        ),
      ],
    );

    final backend = _FakePickListBackend(
      draftTransfers: [transfer],
      pickList: pickList,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: PickListScreen(
          backend: backend,
          warehouseId: 'wh-main',
          warehouseName: 'Main Bodega',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify draft transfers list
    expect(find.text('Pick Lists'), findsOneWidget);
    expect(find.text('Main Bodega'), findsOneWidget);
    expect(find.text('TRF-261110-0001'), findsOneWidget);
    expect(find.text('To: Downtown Branch'), findsOneWidget);

    // Open pick list for this transfer
    await tester.tap(find.byKey(const Key('open-picklist-btn-TRF-261110-0001')));
    await tester.pumpAndSettle();

    // Verify pick list details
    expect(find.byKey(const Key('picklist-no')), findsOneWidget);
    expect(find.text('PCK-261110-0001'), findsOneWidget);
    expect(find.text('San Miguel Pale Pilsen'), findsOneWidget);
    expect(find.text('SKU: SKU-BEER-CAN'), findsOneWidget);
    expect(find.text('B-02-1 (Aisle B - Rack 02 - Shelf 1)'), findsOneWidget);
    expect(find.text('Picked: 0.0 / 10.0'), findsOneWidget);

    // Tap Pick Item button
    await tester.tap(find.byKey(const Key('pick-btn-SKU-BEER-CAN')));
    await tester.pumpAndSettle();

    // Sheet should open with pre-filled quantity
    expect(find.byKey(const Key('pick-confirm-btn')), findsOneWidget);
    expect(find.byKey(const Key('pick-qty-value')), findsOneWidget);
    expect(find.text('10.0'), findsOneWidget);

    // Confirm pick
    await tester.tap(find.byKey(const Key('pick-confirm-btn')));
    await tester.pumpAndSettle();

    // Verify backend call was made
    expect(backend.pickCalls.length, 1);
    expect(backend.pickCalls.first['pick_list_id'], 'pck-201');
    expect(backend.pickCalls.first['item_id'], 'pli-1');
    expect(backend.pickCalls.first['qty_picked'], 10.0);
  });
}
