import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;
import 'sales_store_test.dart' show level, posPage;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

Future<DriftStore> openToday(WidgetTester tester) async {
  final store = await openHome(tester);
  await store.applyPull(pullPage(
    products: [serverProduct(_p1, 'Kape')],
    variants: [serverVariant(_v1, _p1)],
    prices: [serverPrice(_v1, 1000)],
  ));
  await store.applyPullPos(posPage(levels: [level(_v1, 10, '2026-11-08T00:00:00+00:00')]));
  await store.saveCustomer(id: 'c-rosa', name: 'Aling Rosa', opId: 'oc');
  Future<void> sell(String id, int qty, List<PaymentDraft> pays, {String? customer}) => store.commitSale(
        SaleDraft(
          id: id,
          soldAt: DateTime.now(),
          lines: [SaleLine(variantId: _v1, name: 'Kape', qty: qty.toDouble(), unitPrice: 1000)],
          payments: pays,
          customerId: customer,
        ),
        opId: 'op-$id',
      );
  await sell('s1', 2, [const PaymentDraft('cash', 2000, tendered: 5000)]);
  await sell('s2', 1, [const PaymentDraft('ewallet', 1000)]);
  await sell('s3', 3, [const PaymentDraft('cash', 1000), const PaymentDraft('utang', 2000)], customer: 'c-rosa');
  await tester.tap(find.byKey(const Key('tile-today')));
  await tester.pumpAndSettle();
  return store;
}

String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('shows today\'s takings split by how they were paid', (tester) async {
    await openToday(tester);
    expect(text(tester, 'today-total'), '₱60.00');
    expect(text(tester, 'today-count'), '3 sales');
    expect(text(tester, 'today-cash'), '₱30.00');
    expect(text(tester, 'today-ewallet'), '₱10.00');
    expect(text(tester, 'today-utang'), '₱20.00');
    expect(find.byKey(const Key('sale-s3')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('cancelling a sale from its receipt puts stock back and drops it from the totals', (tester) async {
    final store = await openToday(tester);
    expect(await store.stockLeft(_v1), 4);

    await tester.tap(find.byKey(const Key('sale-s3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receipt-utang')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-sale')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this sale?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-sale-yes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('receipt-cancelled')), findsOneWidget);
    expect(find.byKey(const Key('cancel-sale')), findsNothing, reason: 'cannot cancel twice');
    expect(await store.stockLeft(_v1), 7);
    expect((await store.watchCustomers().first).single.balance, 0);
    expect((await store.nextOps()).last.kind, 'void_sale');

    // this receipt was opened from the list (not just sold): its own back arrow, not "New Transaction"
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(text(tester, 'today-total'), '₱30.00');
    expect(text(tester, 'today-count'), '2 sales');
    expect(text(tester, 'today-utang'), '₱0.00');
    expect(find.textContaining('CANCELLED'), findsOneWidget, reason: 'still listed, marked cancelled');
    await leave(tester);
  });

  testWidgets('"No, keep it" leaves the sale alone', (tester) async {
    final store = await openToday(tester);
    await tester.ensureVisible(find.byKey(const Key('sale-s1'))); // the cards above push older sales below the fold
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sale-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-sale')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No, keep it'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receipt-cancelled')), findsNothing);
    expect((await store.nextOps()).where((o) => o.kind == 'void_sale'), isEmpty);
    await leave(tester);
  });

  testWidgets('with no sales the screen says so', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('tile-today')));
    await tester.pumpAndSettle();
    expect(find.text('No sales yet today.'), findsOneWidget);
    expect(text(tester, 'today-count'), 'No sales');
    await leave(tester);
  });

  testWidgets('filters receipts by search text and completed or cancelled status pills', (tester) async {
    final store = await openToday(tester);
    await store.voidSale('s2', opId: 'op-void-s2', reason: 'wrong item');
    await tester.pumpAndSettle();

    // Search by customer name
    await tester.enterText(find.byKey(const Key('today-search')), 'Rosa');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sale-s3')), findsOneWidget);
    expect(find.byKey(const Key('sale-s1')), findsNothing);

    // Clear search
    await tester.tap(find.byKey(const Key('today-search-clear')));
    await tester.pumpAndSettle();

    // Filter to Cancelled only
    await tester.ensureVisible(find.byKey(const Key('today-status-cancelled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today-status-cancelled')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sale-s2')), findsOneWidget);
    expect(find.byKey(const Key('sale-s3')), findsNothing);

    // Filter to Completed only
    await tester.tap(find.byKey(const Key('today-status-completed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sale-s3')), findsOneWidget);
    expect(find.byKey(const Key('sale-s2')), findsNothing);

    await leave(tester);
  });
}
