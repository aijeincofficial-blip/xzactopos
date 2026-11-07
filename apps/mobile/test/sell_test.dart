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
const _p3 = '0190a000-0000-7000-8000-000000000003';
const _v3 = '0190a000-0000-7000-8000-0000000000a3';

Future<DriftStore> openSell(WidgetTester tester) async {
  final store = await openHome(tester);
  await store.applyPull(pullPage(
    products: [serverProduct(_p1, 'Kape 3-in-1'), serverProduct(_p2, 'Asukal'), serverProduct(_p3, 'Walang Presyo')],
    variants: [serverVariant(_v1, _p1, barcode: '4800016644801'), serverVariant(_v2, _p2), serverVariant(_v3, _p3)],
    prices: [serverPrice(_v1, 1250), serverPrice(_v2, 4500)],
  ));
  await store.applyPullPos(posPage(levels: [level(_v1, 10, '2026-11-08T00:00:00+00:00'), level(_v2, 0, '2026-11-08T00:00:00+00:00')]));
  await tester.tap(find.byKey(const Key('tile-sell')));
  await tester.pumpAndSettle();
  return store;
}

String total(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('cart-total'))).data!;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('quick tiles show the products; tapping adds to the cart and again adds one more', (tester) async {
    await openSell(tester);
    expect(find.text('Tap an item to add it'), findsOneWidget);
    expect(find.byKey(const Key('tile-$_p1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tile-$_p1')));
    await tester.pump();
    expect(find.byKey(const Key('cart-line-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tile-$_p1')));
    await tester.pump();
    expect(find.byKey(const Key('cart-line-1')), findsNothing, reason: 'same product, same line');
    expect(total(tester), '₱25.00');
    expect(find.text('1 item'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('search by name and tap a result; scan a barcode and press Enter', (tester) async {
    await openSell(tester);
    await tester.enterText(find.byKey(const Key('sell-search')), 'asuk');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('result-$_p2')));
    await tester.pumpAndSettle();
    expect(total(tester), '₱45.00');

    await tester.enterText(find.byKey(const Key('sell-search')), '4800016644801');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(total(tester), '₱57.50');
    expect(find.text('2 items'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('sell-search'))).controller!.text, isEmpty,
        reason: 'ready for the next scan');
    await leave(tester);
  });

  testWidgets('an unknown barcode says so and offers to add the product', (tester) async {
    await openSell(tester);
    await tester.enterText(find.byKey(const Key('sell-search')), '4800000000999');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No product has barcode 4800000000999'), findsOneWidget);
    expect(find.text('Add product'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('plus, minus, the quantity keypad and removing a line', (tester) async {
    await openSell(tester);
    await tester.tap(find.byKey(const Key('tile-$_p1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('plus-0')));
    await tester.pump();
    expect(total(tester), '₱25.00');

    await tester.tap(find.byKey(const Key('qty-0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('qty-field')), '5');
    await tester.tap(find.byKey(const Key('qty-ok')));
    await tester.pumpAndSettle();
    expect(total(tester), '₱62.50');

    await tester.tap(find.byKey(const Key('qty-0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('qty-field')), '0.5');
    await tester.tap(find.byKey(const Key('qty-ok')));
    await tester.pumpAndSettle();
    expect(total(tester), '₱6.25');

    await tester.tap(find.byKey(const Key('minus-0')));
    await tester.pump();
    expect(find.byKey(const Key('cart-line-0')), findsNothing, reason: 'going to zero or below removes the line');
    expect(find.text('Tap an item to add it'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the cart survives leaving the screen, and Clear asks first', (tester) async {
    await openSell(tester);
    await tester.tap(find.byKey(const Key('tile-$_p1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tile-stock'))); // leave Sell for another tab, then come back
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tile-sell')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-line-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-cart')));
    await tester.pumpAndSettle();
    expect(find.text('Clear this sale?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clear-yes')));
    await tester.pumpAndSettle();
    expect(find.text('Tap an item to add it'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('stock left is shown; none left is a warning, not a block', (tester) async {
    await openSell(tester);
    expect(find.text('10 left'), findsOneWidget);
    expect(find.text('None left (you can still sell)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tile-$_p2')));
    await tester.pump();
    expect(find.byKey(const Key('cart-line-0')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a product without a price cannot be added', (tester) async {
    await openSell(tester);
    await tester.enterText(find.byKey(const Key('sell-search')), 'walang');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('result-$_p3')));
    await tester.pumpAndSettle();
    expect(find.text('Set a price for this product first'), findsOneWidget);
    expect(find.byKey(const Key('cart-line-0')), findsNothing);
    await leave(tester);
  });

  testWidgets('on a phone the keyboard does not pop up over the items by itself', (tester) async {
    tester.view.physicalSize = const Size(411 * 2.625, 800 * 2.625);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await openSell(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('sell-search'))).autofocus, isFalse);
    expect(find.byKey(const Key('tile-$_p1')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('on a wide screen the search box is ready for a USB scanner', (tester) async {
    await openSell(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('sell-search'))).autofocus, isTrue);
    await leave(tester);
  });

  testWidgets('holding a tile pins it as a favorite; holding again unpins it', (tester) async {
    await openSell(tester);
    expect(find.byKey(const Key('pin-$_p1')), findsNothing);
    await tester.longPress(find.byKey(const Key('tile-$_p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pin-$_p1')), findsOneWidget);
    expect(find.text('Pinned Kape 3-in-1 to the top'), findsOneWidget);
    await tester.longPress(find.byKey(const Key('tile-$_p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pin-$_p1')), findsNothing);
    await leave(tester);
  });
}
