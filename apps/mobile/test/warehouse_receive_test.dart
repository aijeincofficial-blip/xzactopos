import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/warehouse_models.dart';
import 'package:xzactopos_mobile/screens/warehouse_receive.dart';

import 'warehouse_home_test.dart' show leave, open;

const _po1 = 'p1000000-0000-4000-8000-000000000001';
const _rice = 'v1000000-0000-4000-8000-000000000001';
const _oil = 'v2000000-0000-4000-8000-000000000002';
const _w1 = 'w1000000-0000-4000-8000-000000000001';

/// Lets saves and stream reads finish: the device database answers in real time, the screens run on the test clock.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<void> openOrder(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('order-$_po1')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('receive-start')));
  await settle(tester);
}

Future<List<WhReceiptView>> receipts(WidgetTester tester, DriftStore store) async =>
    (await tester.runAsync(() => store.watchReceipts(_w1).first))!;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('quantities and costs are read the way a clerk types them', () {
    expect(parseQty('12'), 12);
    expect(parseQty(' 12,5 '), 12.5);
    expect(parseQty('abc'), isNull);
    expect(parseQty(''), isNull);
    expect(parseCostMinor('12.50'), 1250);
    expect(parseCostMinor('0.1'), 10);
    expect(parseCostMinor(''), isNull);
    expect(parseCostMinor('x'), isNull);
  });

  testWidgets('the receive form starts with what is still expected on each line', (tester) async {
    await open(tester);
    await openOrder(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('qty-$_po1-i1'))).controller!.text, '100');
    expect(tester.widget<TextField>(find.byKey(const Key('qty-$_po1-i2'))).controller!.text, '20');
    expect(find.text('Rice 25kg'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('saving receives the typed quantities, skips empty lines and keeps the invoice cost', (tester) async {
    final store = await open(tester);
    await openOrder(tester);
    await tester.enterText(find.byKey(const Key('qty-$_po1-i1')), '60');
    await tester.enterText(find.byKey(const Key('cost-$_po1-i1')), '12.50');
    await tester.enterText(find.byKey(const Key('qty-$_po1-i2')), '');
    await tester.enterText(find.byKey(const Key('field-ref')), 'DR-77');
    await tester.tap(find.byKey(const Key('receive-save')));
    await settle(tester);

    final list = await receipts(tester, store);
    expect(list, hasLength(1));
    expect(list.single.kind, 'po');
    expect(list.single.deliveryRef, 'DR-77');
    expect([for (final l in list.single.lines) (l.variantId, l.qty, l.unitCost)], [(_rice, 60.0, 1250)]);
    final po = (await tester.runAsync(() => store.purchaseOrder(_po1)))!;
    expect(po.remainingTotal, 60);
    expect(find.text('Receipt saved. It will sync when you are online.'), findsOneWidget);
    expect(find.byKey(const Key('receive-save')), findsNothing, reason: 'back on the order');
    await leave(tester);
  });

  testWidgets('more than ordered is allowed but warned about', (tester) async {
    final store = await open(tester);
    await openOrder(tester);
    expect(find.byKey(const Key('over-$_po1-i1')), findsNothing);
    await tester.enterText(find.byKey(const Key('qty-$_po1-i1')), '130');
    await tester.pump();
    expect(find.byKey(const Key('over-$_po1-i1')), findsOneWidget);
    expect(find.text('More than ordered. The extra will be flagged.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receive-save')));
    await settle(tester);
    expect((await receipts(tester, store)).single.lines.first.qty, 130);
    await leave(tester);
  });

  testWidgets('nothing typed, or something that is not a number, is refused and nothing is saved', (tester) async {
    final store = await open(tester);
    await openOrder(tester);
    await tester.enterText(find.byKey(const Key('qty-$_po1-i1')), '');
    await tester.enterText(find.byKey(const Key('qty-$_po1-i2')), '');
    await tester.tap(find.byKey(const Key('receive-save')));
    await settle(tester);
    expect(find.text('Enter a quantity for at least one product.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('qty-$_po1-i1')), 'abc');
    await tester.tap(find.byKey(const Key('receive-save')));
    await settle(tester);
    expect(find.text('Enter a quantity greater than zero.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('qty-$_po1-i1')), '5');
    await tester.enterText(find.byKey(const Key('cost-$_po1-i1')), 'free');
    await tester.tap(find.byKey(const Key('receive-save')));
    await settle(tester);
    expect(find.text('The cost is not a valid amount.'), findsOneWidget);
    expect(await receipts(tester, store), isEmpty);
    await leave(tester);
  });

  testWidgets('an order received in full offers no more receiving', (tester) async {
    await open(tester, before: (s) async {
      await s.receiveAgainstPo(
        poId: _po1,
        lines: [const ReceiptLine(variantId: _rice, qty: 100), const ReceiptLine(variantId: _oil, qty: 20)],
        opId: 'rcv-all',
      );
    });
    expect(find.textContaining('Fully received'), findsOneWidget);
    await tester.tap(find.byKey(const Key('order-$_po1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receive-start')), findsNothing);
    await leave(tester);
  });

  testWidgets('a delivery with no order: pick products, set quantities, save', (tester) async {
    final store = await open(tester);
    await tester.tap(find.byKey(const Key('walkin-start')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('walkin-search')), 'oil');
    await settle(tester);
    await tester.tap(find.byKey(const Key('pick-$_oil')));
    await settle(tester);
    expect(find.byKey(const Key('walkin-line-$_oil')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('qty-$_oil')), '8');
    await tester.enterText(find.byKey(const Key('field-notes')), 'Came without papers');
    await tester.tap(find.byKey(const Key('receive-save')));
    await settle(tester);

    final r = (await receipts(tester, store)).single;
    expect(r.kind, 'walkin');
    expect(r.warehouseId, _w1);
    expect(r.notes, 'Came without papers');
    expect([for (final l in r.lines) (l.variantId, l.qty)], [(_oil, 8.0)]);
    expect(find.text('Receipt saved. It will sync when you are online.'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a delivery with no order needs at least one product, and a product can be removed', (tester) async {
    final store = await open(tester);
    await tester.tap(find.byKey(const Key('walkin-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receive-save')));
    await settle(tester);
    expect(find.text('Enter a quantity for at least one product.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('walkin-search')), 'rice');
    await settle(tester);
    await tester.tap(find.byKey(const Key('pick-$_rice')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('remove-$_rice')));
    await settle(tester);
    expect(find.byKey(const Key('walkin-line-$_rice')), findsNothing);
    expect(await receipts(tester, store), isEmpty);
    await leave(tester);
  });

  testWidgets('after a part delivery the form starts with what is left, and zero lines are not sent', (tester) async {
    final store = await open(tester, before: (s) => s.receiveAgainstPo(poId: _po1, lines: [const ReceiptLine(variantId: _rice, qty: 30)], opId: 'rcv-part'));
    await openOrder(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('qty-$_po1-i1'))).controller!.text, '70');
    await tester.enterText(find.byKey(const Key('qty-$_po1-i1')), '0');
    await tester.enterText(find.byKey(const Key('qty-$_po1-i2')), '5');
    await tester.tap(find.byKey(const Key('receive-save')));
    await settle(tester);
    final newest = (await receipts(tester, store)).first;
    expect([for (final l in newest.lines) (l.variantId, l.qty)], [(_oil, 5.0)]);
    await leave(tester);
  });

  testWidgets('a delivery with no order keeps the supplier, adds a product once and refuses zero', (tester) async {
    final store = await open(tester);
    await tester.tap(find.byKey(const Key('walkin-start')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('field-supplier')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mega Rice Trading').last);
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.enterText(find.byKey(const Key('walkin-search')), 'rice');
      await settle(tester);
      await tester.tap(find.byKey(const Key('pick-$_rice')));
      await settle(tester);
    }
    expect(find.byKey(const Key('qty-$_rice')), findsOneWidget, reason: 'the same product is one line');
    await tester.enterText(find.byKey(const Key('qty-$_rice')), '0');
    await tester.tap(find.byKey(const Key('receive-save')));
    await settle(tester);
    expect(find.text('Enter a quantity greater than zero.'), findsOneWidget);
    expect(await receipts(tester, store), isEmpty);

    await tester.enterText(find.byKey(const Key('qty-$_rice')), '3');
    await tester.tap(find.byKey(const Key('receive-save')));
    await settle(tester);
    final r = (await receipts(tester, store)).single;
    expect(r.supplierId, 'a0000000-0000-4000-8000-0000000000a1');
    expect(r.lines, hasLength(1));
    await leave(tester);
  });

  testWidgets('Filipino receive button', (tester) async {
    await open(tester, locale: 'fil');
    await tester.tap(find.byKey(const Key('order-$_po1')));
    await tester.pumpAndSettle();
    expect(find.text('Tanggapin ang mga paninda'), findsOneWidget);
    await leave(tester);
  });
}
