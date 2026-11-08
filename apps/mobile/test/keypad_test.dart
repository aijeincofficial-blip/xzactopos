import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/local_store.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

Future<void> press(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    final key = find.byKey(Key('key-${k == 'x' ? 'del' : k}'));
    await tester.ensureVisible(key); // a short screen scrolls the pad
    await tester.tap(key);
    await tester.pump();
  }
}

String display(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('keypad-display'))).data!;

Future<void> openKeypad(WidgetTester tester) async {
  await tester.tap(find.text('Keypad'));
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('the pad builds an amount: two decimals at most, no leading zeros, backspace', (tester) async {
    await openHome(tester);
    await openKeypad(tester);
    expect(display(tester), '₱0.00');
    await tester.ensureVisible(find.byKey(const Key('keypad-add')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('keypad-add'))).onPressed, isNull, reason: 'nothing typed');
    await press(tester, '1.259');
    expect(display(tester), '1.25', reason: 'a third decimal is ignored');
    await press(tester, 'x');
    await press(tester, 'x');
    expect(display(tester), '1.');
    await press(tester, 'x');
    await press(tester, 'x');
    expect(display(tester), '₱0.00');
    await press(tester, '05');
    expect(display(tester), '5', reason: '0 then 5 is 5');
    await press(tester, '..');
    expect(display(tester), '5.', reason: 'only one point');
    await leave(tester);
  });

  testWidgets('a typed amount joins the cart on one hidden no-stock product, adds up, and stays out of the tiles', (tester) async {
    final store = await openHome(tester);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 1000)],
    ));
    await openKeypad(tester);
    await press(tester, '12.5');
    await tester.ensureVisible(find.byKey(const Key('keypad-add')));
    await tester.tap(find.byKey(const Key('keypad-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-line-0')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('cart-total'))).data, '₱12.50');
    expect(display(tester), '₱0.00', reason: 'the pad clears after adding');

    await press(tester, '5');
    await tester.ensureVisible(find.byKey(const Key('keypad-add')));
    await tester.tap(find.byKey(const Key('keypad-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-line-1')), findsNothing, reason: 'amounts add up on one line');
    expect(tester.widget<Text>(find.byKey(const Key('cart-total'))).data, '₱17.50');

    final ops = (await store.nextOps()).where((o) => o.kind == 'upsert_product' && (o.payload['variant'] as Map)['sku'] == openAmountSku);
    expect(ops, hasLength(1), reason: 'the hidden product is made once');
    expect(ops.single.payload['track_stock'], false);
    expect(await store.quickItems().then((l) => l.map((p) => p.name).toList()), ['Kape']);

    await tester.tap(find.text('Items'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-$_p1')), findsOneWidget);
    expect(find.descendant(of: find.byType(GridView), matching: find.text('Other item')), findsNothing, reason: 'not offered as a tile');
    await leave(tester);
  });
}
