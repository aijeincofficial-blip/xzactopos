import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xzactopos_mobile/core/receipt_printer.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

import 'products_test.dart' show leave, openHome;

const _v1 = '0190a000-0000-7000-8000-0000000000a1';

ReceiptLabels labels() => ReceiptLabels(
      number: (n) => 'Receipt no. $n',
      subtotal: 'Subtotal',
      discount: 'Discount',
      total: 'Total',
      cashReceived: 'Cash received',
      ewallet: 'GCash / Maya',
      change: 'Change',
      onUtang: 'On utang',
      cancelled: 'CANCELLED',
      thanks: 'Thank you!',
    );

SaleDetail detail({bool voided = false, int discount = 0, bool utang = false}) => SaleDetail(
      summary: SaleSummary(
          id: 's1', localNo: 'ABC-261108-0001', status: voided ? 'voided' : 'completed', total: 4000 - discount, soldAt: DateTime(2026, 11, 8, 10, 30), pending: false),
      subtotal: 4000,
      discount: discount,
      tax: 0,
      items: const [SaleItemView('Piña Juice 250ml', 2, 1500, 3000), SaleItemView('Kape', 0.5, 2000, 1000)],
      payments: [
        SalePaymentView('cash', utang ? 1000 : 4000 - discount, 5000, null),
        if (utang) const SalePaymentView('utang', 3000, null, null),
      ],
    );

class RecordingPrinter implements ReceiptPrinter {
  final printed = <String>[];
  final shared = <String>[];
  ReceiptLabels? lastLabels;
  Object? failWith;
  @override
  bool get available => true;
  @override
  Future<void> print(SaleDetail sale, {required String storeName, required String currency, required String locale, required ReceiptLabels labels}) async {
    if (failWith != null) throw failWith!;
    lastLabels = labels;
    printed.add('${sale.summary.localNo}|$storeName|$currency|$locale');
  }

  @override
  Future<void> share(SaleDetail sale, {required String storeName, required String currency, required String locale, required ReceiptLabels labels}) async {
    lastLabels = labels;
    shared.add(sale.summary.localNo);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  tearDown(() => receiptPrinter = const NoPrinter());

  group('the receipt PDF', () {
    setUpAll(() => initializeDateFormatting('fil'));

    Future<List<int>> build(SaleDetail d) => buildReceiptPdf(d, storeName: 'Tindahan ni Aling Nena', currency: 'PHP', locale: 'fil', labels: labels());

    test('is a real PDF, for plain, discounted, utang and cancelled sales', () async {
      for (final d in [detail(), detail(discount: 500), detail(utang: true), detail(voided: true)]) {
        final bytes = await build(d);
        expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
        expect(bytes.length, greaterThan(800));
      }
    });

    test('a discounted sale prints more lines than a plain one', () async {
      expect((await build(detail(discount: 500))).length, greaterThan((await build(detail())).length));
    });

    test('the page is a 58 mm roll', () {
      expect(receiptPageFormat.width, closeTo(58 * 72 / 25.4, 0.01));
    });
  });

  testWidgets('the receipt has Print and Share when a printer is available, and passes what to print', (tester) async {
    final printer = RecordingPrinter();
    receiptPrinter = printer;
    final store = await openHome(tester);
    await store.commitSale(
      SaleDraft(
          id: 's1',
          soldAt: DateTime.now(),
          lines: const [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: 1000)],
          payments: const [PaymentDraft('cash', 1000)]),
      opId: 'op1',
    );
    await tester.tap(find.byKey(const Key('tile-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sale-s1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('receipt-print')));
    await tester.pumpAndSettle();
    expect(printer.printed.single, matches(RegExp(r'^[A-Z0-9]{3}-\d{6}-0001\|Tindahan ni Nena\|PHP\|en$')));
    await tester.tap(find.byKey(const Key('receipt-share')));
    await tester.pumpAndSettle();
    expect(printer.shared, hasLength(1));

    printer.failWith = Exception('no printer');
    await tester.tap(find.byKey(const Key('receipt-print')));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the printer. Try Share instead.'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('no printer, no buttons', (tester) async {
    final store = await openHome(tester);
    await store.commitSale(
      SaleDraft(
          id: 's1',
          soldAt: DateTime.now(),
          lines: const [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: 1000)],
          payments: const [PaymentDraft('cash', 1000)]),
      opId: 'op1',
    );
    await tester.tap(find.byKey(const Key('tile-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sale-s1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receipt-print')), findsNothing);
    await leave(tester);
  });

  testWidgets('receipt screen shows custom header, footer, and store address and forwards them to printer', (tester) async {
    final printer = RecordingPrinter();
    receiptPrinter = printer;
    final store = await openHome(
      tester,
      access: const {
        'role': 'superadmin',
        'tenant': {
          'id': 't1',
          'name': 'Tindahan ni Nena',
          'base_currency': 'PHP',
          'receipt_header': 'TIN 999-888-777',
          'receipt_footer': 'Maraming salamat suki!',
        },
        'locations': [
          {
            'id': 's1',
            'type': 'store',
            'code': 'S01',
            'name': 'Poblacion Main',
            'address': '45 Mabini St, Poblacion',
          },
        ],
      },
    );
    await store.commitSale(
      SaleDraft(
          id: 's-brand',
          soldAt: DateTime.now(),
          lines: const [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: 1000)],
          payments: const [PaymentDraft('cash', 1000)]),
      opId: 'op-brand',
    );
    await tester.tap(find.byKey(const Key('tile-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sale-s-brand')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('receipt-store-address')), findsOneWidget);
    expect(find.text('45 Mabini St, Poblacion'), findsOneWidget);
    expect(find.byKey(const Key('receipt-custom-header')), findsOneWidget);
    expect(find.text('TIN 999-888-777'), findsOneWidget);
    expect(find.byKey(const Key('receipt-custom-footer')), findsOneWidget);
    expect(find.text('Maraming salamat suki!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('receipt-print')));
    await tester.pumpAndSettle();
    expect(printer.lastLabels?.storeAddress, '45 Mabini St, Poblacion');
    expect(printer.lastLabels?.receiptHeader, 'TIN 999-888-777');
    expect(printer.lastLabels?.receiptFooter, 'Maraming salamat suki!');
    await leave(tester);
  });
}
