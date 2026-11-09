import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;
import 'sales_store_test.dart' show level, posPage;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';

/// Home -> Sell with Kape (12.50) and Asukal (45.00) in stock, one Kape in the cart, on the Pay screen.
Future<DriftStore> openPay(WidgetTester tester, {int kape = 3}) async {
  final store = await openHome(tester);
  await store.applyPull(pullPage(
    products: [serverProduct(_p1, 'Kape 3-in-1'), serverProduct(_p2, 'Asukal')],
    variants: [serverVariant(_v1, _p1, barcode: '4800016644801'), serverVariant(_v2, _p2)],
    prices: [serverPrice(_v1, 1250), serverPrice(_v2, 4500)],
  ));
  await store.applyPullPos(posPage(levels: [level(_v1, 10, '2026-11-08T00:00:00+00:00'), level(_v2, 5, '2026-11-08T00:00:00+00:00')]));
  await tester.tap(find.byKey(const Key('tile-sell')));
  await tester.pumpAndSettle();
  for (var i = 0; i < kape; i++) {
    await tester.tap(find.byKey(const Key('tile-$_p1')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('pay-button')));
  await tester.pumpAndSettle();
  return store;
}

Text textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key)));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('exact cash is one tap: the sale is saved, stock drops, the receipt shows the number', (tester) async {
    final store = await openPay(tester); // 3 x 12.50 = 37.50
    expect(textOf(tester, 'pay-total').data, '₱37.50');
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('receipt-no')), findsOneWidget);
    expect(textOf(tester, 'receipt-total').data, '₱37.50');
    expect(find.byKey(const Key('receipt-change')), findsNothing);
    final op = (await store.nextOps()).single;
    expect(op.kind, 'record_sale');
    expect(op.payload['total'], 3750);
    expect(await store.stockLeft(_v1), 7);

    // "New sale" returns to an empty cart
    await tester.tap(find.byKey(const Key('receipt-next')));
    await tester.pumpAndSettle();
    expect(find.text('Tap an item to add it'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('cash received shows the change in big type and records the tendered amount', (tester) async {
    final store = await openPay(tester);
    await tester.tap(find.byKey(const Key('quick-5000')));
    await tester.pump();
    expect(textOf(tester, 'pay-change').data, '₱12.50');

    await tester.enterText(find.byKey(const Key('received-field')), '100');
    await tester.pump();
    expect(textOf(tester, 'pay-change').data, '₱62.50');
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'receipt-change').data, '₱62.50');
    final pay = ((await store.nextOps()).single.payload['payments'] as List).single as Map;
    expect(pay, {'method': 'cash', 'amount': 3750, 'tendered': 10000});
    await leave(tester);
  });

  testWidgets('quick amounts only offer bills that cover the total', (tester) async {
    await openPay(tester);
    expect(find.byKey(const Key('quick-5000')), findsOneWidget);
    expect(find.byKey(const Key('quick-10000')), findsOneWidget);
    expect(find.byKey(const Key('quick-2000')), findsNothing, reason: '₱20 does not cover ₱37.50');
    await leave(tester);
  });

  testWidgets('paying less than the total puts the rest on utang and needs a customer', (tester) async {
    final store = await openPay(tester);
    await tester.enterText(find.byKey(const Key('received-field')), '20');
    await tester.pumpAndSettle(); // lets the card scroll into view
    expect(find.text('₱17.50 goes on utang'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('pay-done'))).onPressed, isNull, reason: 'no customer yet');

    await tester.tap(find.byKey(const Key('choose-customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('customer-name')), 'Aling Rosa');
    await tester.tap(find.byKey(const Key('customer-save')));
    await tester.pumpAndSettle();
    expect(find.text('Aling Rosa'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'receipt-utang').data, '₱17.50');
    expect(find.text("Aling Rosa's utang balance: ₱17.50"), findsOneWidget);

    final ops = await store.nextOps();
    expect(ops.map((o) => o.kind), ['upsert_customer', 'record_sale']);
    final pays = ops.last.payload['payments'] as List;
    expect(pays, [
      {'method': 'cash', 'amount': 2000, 'tendered': 2000},
      {'method': 'utang', 'amount': 1750},
    ]);
    expect(ops.last.payload['customer_id'], isNotNull);
    await leave(tester);
  });

  testWidgets('"All on utang" puts the whole sale on a customer already in the list', (tester) async {
    final store = await openPay(tester, kape: 1);
    await store.saveCustomer(id: 'c-1', name: 'Berto', opId: 'oc');
    await tester.tap(find.byKey(const Key('all-utang')));
    await tester.pumpAndSettle();
    expect(find.text('₱12.50 goes on utang'), findsOneWidget);
    await tester.tap(find.byKey(const Key('choose-customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-c-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();
    final pays = ((await store.nextOps()).last.payload['payments'] as List);
    expect(pays, [
      {'method': 'utang', 'amount': 1250}
    ]);
    expect((await store.watchCustomers().first).single.balance, 1250);
    await leave(tester);
  });

  testWidgets('on a small phone, "All on utang" brings the who-owes button into view above the keypad', (tester) async {
    final store = await openPay(tester, kape: 6);
    tester.view.physicalSize = const Size(1080, 1700); // a short phone: the keypad covers the lower part
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    await store.saveCustomer(id: 'c-9', name: 'Nena', opId: 'oc9');
    await tester.tap(find.byKey(const Key('all-utang')));
    await tester.pumpAndSettle();
    final visible = tester.getRect(find.byType(ListView).first);
    final button = tester.getRect(find.byKey(const Key('choose-customer')));
    expect(button.bottom, lessThanOrEqualTo(visible.bottom), reason: 'the button the sale is waiting for must not be below the visible area');
    expect(button.top, greaterThanOrEqualTo(visible.top));
    await leave(tester);
  });

  testWidgets('e-wallet payment records no tendered amount and no change', (tester) async {
    final store = await openPay(tester, kape: 1);
    await tester.tap(find.text('GCash / Maya'));
    await tester.pump();
    expect(find.byKey(const Key('quick-5000')), findsNothing, reason: 'bills are for cash');
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();
    final pay = ((await store.nextOps()).single.payload['payments'] as List).single as Map;
    expect(pay, {'method': 'ewallet', 'amount': 1250, 'wallet': 'gcash'}, reason: 'GCash is the wallet unless another is chosen');
    expect((await store.watchWalletFloat().first).firstWhere((f) => f.wallet == 'gcash').balance, 1250,
        reason: 'the money arrived in the wallet');
    await leave(tester);
  });

  testWidgets('choosing Maya sends the payment to the Maya float; cash never names a wallet', (tester) async {
    final store = await openPay(tester, kape: 1);
    expect(find.byKey(const Key('pay-wallet-maya')), findsNothing, reason: 'the chooser is only for e-wallet');
    await tester.tap(find.text('GCash / Maya'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('pay-wallet-maya')));
    await tester.tap(find.byKey(const Key('pay-wallet-maya')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('pay-done')));
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();
    final pay = ((await store.nextOps()).single.payload['payments'] as List).single as Map;
    expect(pay['wallet'], 'maya');
    final floats = await store.watchWalletFloat().first;
    expect(floats.firstWhere((f) => f.wallet == 'maya').balance, 1250);
    expect(floats.where((f) => f.wallet == 'gcash').every((f) => f.balance == 0), isTrue);
    await leave(tester);
  });

  testWidgets('a cash sale has no wallet in its payment', (tester) async {
    final store = await openPay(tester, kape: 1);
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();
    final pay = ((await store.nextOps()).single.payload['payments'] as List).single as Map;
    expect(pay.containsKey('wallet'), isFalse);
    await leave(tester);
  });

  testWidgets('a peso discount lowers the total; it cannot go below zero', (tester) async {
    final store = await openPay(tester, kape: 1);
    await tester.tap(find.text('Discount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('discount-field')), '2.50');
    await tester.pump();
    expect(textOf(tester, 'pay-total').data, '₱10.00');
    await tester.enterText(find.byKey(const Key('discount-field')), '99');
    await tester.pump();
    expect(textOf(tester, 'pay-total').data, '₱0.00');
    expect(tester.widget<FilledButton>(find.byKey(const Key('pay-done'))).onPressed, isNull, reason: 'nothing to pay');

    await tester.enterText(find.byKey(const Key('discount-field')), '2.50');
    await tester.pump();
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();
    final p = (await store.nextOps()).single.payload;
    expect((p['subtotal'], p['discount'], p['total']), (1250, 250, 1000));
    expect(find.text('−₱2.50'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('tapping Finish twice records one sale', (tester) async {
    final store = await openPay(tester, kape: 1);
    final done = find.byKey(const Key('pay-done'));
    await tester.tap(done);
    await tester.tap(done, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect((await store.nextOps()), hasLength(1));
    await leave(tester);
  });
}
