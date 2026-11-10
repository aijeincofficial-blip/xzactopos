import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xzactopos_mobile/backend.dart';
import 'package:xzactopos_mobile/data/transfer_models.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/transfers_screen.dart';

class _FakeTransferBackend implements Backend {
  final List<TransferHeader> incoming = [];
  final List<TransferHeader> history = [];
  final List<Map<String, dynamic>> receivedCalls = [];

  @override
  Future<List<TransferHeader>> fetchIncomingTransfers(String locationId) async => incoming;

  @override
  Future<List<TransferHeader>> fetchTransferHistory(String locationId) async => history;

  @override
  Future<void> receiveTransfer({
    required String transferId,
    required List<Map<String, dynamic>> items,
  }) async {
    receivedCalls.add({
      'transfer_id': transferId,
      'items': items,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  test('TransferHeader.fromJson parses JSON correctly', () {
    final json = {
      'id': 'trf-101',
      'transfer_no': 'TRF-261110-0001',
      'from_location_id': 'loc-w1',
      'to_location_id': 'loc-s1',
      'status': 'shipped',
      'notes': 'Urgent restock',
      'shipped_at': '2026-11-10T10:00:00Z',
      'received_at': null,
      'has_discrepancy': false,
      'from_location': {'id': 'loc-w1', 'name': 'Main Warehouse'},
      'to_location': {'id': 'loc-s1', 'name': 'Store Branch 1'},
      'transfer_items': [
        {
          'id': 'item-1',
          'transfer_id': 'trf-101',
          'variant_id': 'var-1',
          'qty_shipped': 20,
          'qty_received': null,
          'variant': {
            'sku': 'SKU-001',
            'barcode': '480001',
            'product': {'name': 'Instant Noodles', 'unit': 'pack'}
          }
        },
        {
          'id': 'item-2',
          'transfer_id': 'trf-101',
          'variant_id': 'var-2',
          'qty_shipped': 10,
          'qty_received': null,
          'variant': {
            'sku': 'SKU-002',
            'barcode': '480002',
            'product': {'name': 'Canned Sardines', 'unit': 'can'}
          }
        }
      ]
    };

    final header = TransferHeader.fromJson(json);
    expect(header.id, 'trf-101');
    expect(header.transferNo, 'TRF-261110-0001');
    expect(header.fromLocationName, 'Main Warehouse');
    expect(header.toLocationName, 'Store Branch 1');
    expect(header.isShipped, true);
    expect(header.items.length, 2);
    expect(header.items[0].productName, 'Instant Noodles');
    expect(header.items[0].qtyShipped, 20.0);
    expect(header.items[1].productName, 'Canned Sardines');
    expect(header.items[1].qtyShipped, 10.0);
  });

  testWidgets('TransfersScreen shows incoming shipments and opens receive screen', (tester) async {
    final backend = _FakeTransferBackend();
    final item = const TransferItem(
      id: 'i-1',
      transferId: 'trf-1',
      variantId: 'v-1',
      productName: 'Mineral Water 500ml',
      barcode: '123456',
      unit: 'bottle',
      qtyShipped: 15,
    );
    final header = TransferHeader(
      id: 'trf-1',
      transferNo: 'TRF-001',
      fromLocationId: 'w-1',
      fromLocationName: 'Central Depot',
      toLocationId: 's-1',
      toLocationName: 'Store 1',
      status: 'shipped',
      shippedAt: DateTime.utc(2026, 11, 10, 8, 0),
      items: [item],
    );
    backend.incoming.add(header);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TransfersScreen(backend: backend, locationId: 's-1'),
    ));

    await tester.pumpAndSettle();

    // Verify transfer card displays manifest number and origin
    expect(find.text('TRF-001'), findsOneWidget);
    expect(find.textContaining('Central Depot'), findsOneWidget);

    // Tap receive button
    final receiveBtn = find.byKey(const Key('receive-transfer-trf-1'));
    expect(receiveBtn, findsOneWidget);
    await tester.tap(receiveBtn);
    await tester.pumpAndSettle();

    // Now in TransferReceiveScreen
    expect(find.text('Mineral Water 500ml'), findsOneWidget);
    expect(find.byKey(const Key('confirm-receive-button')), findsOneWidget);

    // Tap confirm receipt
    await tester.tap(find.byKey(const Key('confirm-receive-button')));
    await tester.pumpAndSettle();

    expect(backend.receivedCalls.length, 1);
    expect(backend.receivedCalls.first['transfer_id'], 'trf-1');
    final submittedItems = backend.receivedCalls.first['items'] as List<dynamic>;
    expect(submittedItems.length, 1);
    expect(submittedItems.first['variant_id'], 'v-1');
    expect(submittedItems.first['qty_received'], 15.0);
  });
}
