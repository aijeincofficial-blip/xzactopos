import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'pay_test.dart' show textOf;
import 'products_test.dart' show leave, openHome;
import 'sales_store_test.dart' show level, posPage;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('line-item discount and price override can be applied and committed to sale items', (tester) async {
    final store = await openHome(tester);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape 3-in-1'), serverProduct(_p2, 'Asukal')],
      variants: [serverVariant(_v1, _p1, barcode: '4800016644801'), serverVariant(_v2, _p2)],
      prices: [serverPrice(_v1, 2000), serverPrice(_v2, 5000)], // 20.00 and 50.00
    ));
    await store.applyPullPos(posPage(levels: [
      level(_v1, 10, '2026-11-08T00:00:00+00:00'),
      level(_v2, 5, '2026-11-08T00:00:00+00:00'),
    ]));

    // Open Sell screen
    await tester.tap(find.byKey(const Key('tile-sell')));
    await tester.pumpAndSettle();

    // Add 2 Kape: 2 x 20.00 = 40.00
    await tester.tap(find.byKey(const Key('tile-$_p1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tile-$_p1')));
    await tester.pump();

    expect(textOf(tester, 'cart-total').data, '₱40.00');

    // Tap the cart line to open line edit modal
    await tester.tap(find.byKey(const Key('edit-line-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('line-discount-field')), findsOneWidget);
    // Enter 5.00 discount off this line: 40.00 - 5.00 = 35.00
    await tester.enterText(find.byKey(const Key('line-discount-field')), '5');
    await tester.tap(find.byKey(const Key('line-edit-save')));
    await tester.pumpAndSettle();

    // Verify line discount badge is rendered
    expect(find.byKey(const Key('line-discount-0')), findsOneWidget);
    expect(textOf(tester, 'cart-total').data, '₱35.00');

    // Proceed to pay
    await tester.tap(find.byKey(const Key('pay-button')));
    await tester.pumpAndSettle();

    // Pay screen shows 35.00 total
    expect(textOf(tester, 'pay-total').data, '₱35.00');
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();

    // Receipt verification
    expect(find.byKey(const Key('receipt-no')), findsOneWidget);
    expect(textOf(tester, 'receipt-total').data, '₱35.00');

    // Verify outbox op
    final op = (await store.nextOps()).single;
    expect(op.kind, 'record_sale');
    expect(op.payload['subtotal'], 3500);
    expect(op.payload['total'], 3500);
    final items = (op.payload['items'] as List).cast<Map<String, dynamic>>();
    expect(items.length, 1);
    expect(items.first['unit_price'], 2000);
    expect(items.first['discount'], 500);
    expect(items.first['line_total'], 3500);

    await leave(tester);
  });
}
