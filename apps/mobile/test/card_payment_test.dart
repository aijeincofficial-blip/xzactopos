import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pay_test.dart' show openPay, textOf;
import 'products_test.dart' show leave;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('card payment tender records sale with card method and approval reference', (tester) async {
    final store = await openPay(tester); // 3 x 12.50 = 37.50

    // Switch payment method to Card
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();

    // The card reference field appears
    expect(find.byKey(const Key('pay-card-ref')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pay-card-ref')), 'TRACE-123456');
    await tester.pump();

    // Finish sale
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();

    // Receipt displays card payment
    expect(find.byKey(const Key('receipt-no')), findsOneWidget);
    expect(textOf(tester, 'receipt-total').data, '₱37.50');
    expect(find.byKey(const Key('receipt-card')), findsOneWidget);

    // Verify outbox op payload
    final op = (await store.nextOps()).single;
    expect(op.kind, 'record_sale');
    expect(op.payload['total'], 3750);
    final payments = (op.payload['payments'] as List).cast<Map<String, dynamic>>();
    expect(payments.length, 1);
    expect(payments.first['method'], 'card');
    expect(payments.first['amount'], 3750);
    expect(payments.first['reference'], 'TRACE-123456');

    await leave(tester);
  });
}
