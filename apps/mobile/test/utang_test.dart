import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

Future<DriftStore> openUtang(WidgetTester tester) async {
  final store = await openHome(tester);
  await store.applyPull(pullPage(
    products: [serverProduct(_p1, 'Kape')],
    variants: [serverVariant(_v1, _p1)],
    prices: [serverPrice(_v1, 1000)],
  ));
  await store.saveCustomer(id: 'c-rosa', name: 'Aling Rosa', phone: '0917', opId: 'oc1');
  await store.saveCustomer(id: 'c-berto', name: 'Berto', opId: 'oc2');
  await store.saveCustomer(id: 'c-carmen', name: 'Carmen', opId: 'oc3');
  Future<void> owe(String sale, String c, int centavos) => store.commitSale(
        SaleDraft(
          id: sale,
          soldAt: DateTime.now(),
          lines: [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: centavos)],
          payments: [PaymentDraft('utang', centavos)],
          customerId: c,
        ),
        opId: 'op-$sale',
      );
  await owe('s1', 'c-rosa', 15000);
  await owe('s2', 'c-berto', 4000);
  await tester.tap(find.byKey(const Key('tile-utang')));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('lists who owes, biggest first, with the total', (tester) async {
    await openUtang(tester);
    expect(tester.widget<Text>(find.byKey(const Key('utang-total'))).data, '₱190.00');
    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).map((l) => (l.title as Text).data).toList();
    expect(rows, ['Aling Rosa', 'Berto', 'Carmen']);
    expect(find.text('Fully paid'), findsOneWidget, reason: 'Carmen owes nothing');
    await leave(tester);
  });

  testWidgets('search narrows the list', (tester) async {
    await openUtang(tester);
    await tester.enterText(find.byKey(const Key('utang-search')), 'ber');
    await tester.pumpAndSettle();
    expect(find.text('Berto'), findsOneWidget);
    expect(find.text('Aling Rosa'), findsNothing);
    await leave(tester);
  });

  testWidgets('recording a payment lowers the balance at once and queues one op', (tester) async {
    final store = await openUtang(tester);
    await tester.tap(find.byKey(const Key('customer-row-c-rosa')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('customer-balance'))).data, '₱150.00');
    expect(find.text('Took on utang'), findsOneWidget);

    await tester.tap(find.byKey(const Key('record-payment')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('utang-amount'))).controller!.text, '150.00', reason: 'defaults to the full balance');
    await tester.enterText(find.byKey(const Key('utang-amount')), '50');
    await tester.enterText(find.byKey(const Key('utang-note')), 'bayad sa tindahan');
    await tester.tap(find.byKey(const Key('utang-save')));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const Key('customer-balance'))).data, '₱100.00');
    expect(find.text('Paid'), findsOneWidget);
    final op = (await store.nextOps()).last;
    expect(op.kind, 'record_utang_payment');
    expect(op.payload['amount'], 5000);
    expect(op.payload['note'], 'bayad sa tindahan');
    await leave(tester);
  });

  testWidgets('paying more than the balance is refused with the amount owed', (tester) async {
    final store = await openUtang(tester);
    await tester.tap(find.byKey(const Key('customer-row-c-berto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-payment')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('utang-amount')), '41');
    await tester.tap(find.byKey(const Key('utang-save')));
    await tester.pumpAndSettle();
    expect(find.text('That is more than they owe (₱40.00)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('utang-amount')), 'abc');
    await tester.tap(find.byKey(const Key('utang-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number, like 12.50'), findsOneWidget);
    expect((await store.nextOps()).where((o) => o.kind == 'record_utang_payment'), isEmpty);
    await leave(tester);
  });

  testWidgets('paying in full settles the customer; there is nothing left to record', (tester) async {
    await openUtang(tester);
    await tester.tap(find.byKey(const Key('customer-row-c-berto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-payment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('utang-save')));
    await tester.pumpAndSettle();
    expect(find.text('Fully paid'), findsOneWidget);
    expect(find.byKey(const Key('record-payment')), findsNothing);
    await leave(tester);
  });

  testWidgets('a new customer can be added from the list', (tester) async {
    final store = await openUtang(tester);
    await tester.tap(find.byKey(const Key('add-customer')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('customer-name')), 'Dodong');
    await tester.tap(find.byKey(const Key('customer-save')));
    await tester.pumpAndSettle();
    expect(find.text('Dodong'), findsOneWidget);
    expect((await store.nextOps()).where((o) => o.kind == 'upsert_customer').length, 4);
    await leave(tester);
  });
}
