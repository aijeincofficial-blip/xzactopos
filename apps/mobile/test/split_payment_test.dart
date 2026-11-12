import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pay_test.dart' show openPay, textOf;
import 'products_test.dart' show leave;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('split payment combines cash and ewallet tenders in one sale', (tester) async {
    final store = await openPay(tester); // 3 x 12.50 = 37.50

    // Enter partial cash tender of 20.00
    await tester.enterText(find.byKey(const Key('received-field')), '20');
    await tester.pumpAndSettle();

    // Split button appears; tap it to lock 20.00 cash and switch remaining 17.50 to e-wallet
    final splitBtn = find.byKey(const Key('pay-add-split'));
    expect(splitBtn, findsOneWidget);
    await tester.ensureVisible(splitBtn);
    await tester.tap(splitBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pay-split-list')), findsOneWidget);
    expect(textOf(tester, 'pay-remaining').data, '₱17.50');

    // Complete sale with remaining 17.50 on default GCash wallet
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('receipt-no')), findsOneWidget);
    expect(textOf(tester, 'receipt-total').data, '₱37.50');

    final op = (await store.nextOps()).single;
    expect(op.kind, 'record_sale');
    expect(op.payload['total'], 3750);
    final payments = (op.payload['payments'] as List).cast<Map<String, dynamic>>();
    expect(payments, [
      {'method': 'cash', 'amount': 2000, 'tendered': 2000},
      {'method': 'ewallet', 'amount': 1750, 'wallet': 'gcash'},
    ]);

    await leave(tester);
  });

  testWidgets('removing a locked split tender restores full remaining balance', (tester) async {
    await openPay(tester); // 37.50

    await tester.enterText(find.byKey(const Key('received-field')), '15');
    await tester.pumpAndSettle();

    final splitBtn = find.byKey(const Key('pay-add-split'));
    await tester.ensureVisible(splitBtn);
    await tester.tap(splitBtn);
    await tester.pumpAndSettle();

    expect(textOf(tester, 'pay-remaining').data, '₱22.50');

    await tester.tap(find.byKey(const Key('pay-remove-split-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pay-split-list')), findsNothing);

    await leave(tester);
  });
}
