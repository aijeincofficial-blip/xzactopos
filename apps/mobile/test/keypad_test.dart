import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/screens/cart.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'pay_test.dart' show openPay;
import 'products_test.dart' show leave, openHome;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

Future<void> press(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    final key = find.byKey(Key('key-${k == 'x' ? 'del' : k}'));
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
}

String received(WidgetTester tester) => tester.widget<TextField>(find.byKey(const Key('received-field'))).controller!.text;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('the pad on Pay types the amount received: two decimals at most, no leading zeros, backspace', (tester) async {
    await openPay(tester); // 3 x 12.50 = 37.50
    expect(received(tester), '');
    await press(tester, '50');
    expect(received(tester), '50');
    expect(tester.widget<Text>(find.byKey(const Key('pay-change'))).data, '₱12.50', reason: '50 received for 37.50');

    await press(tester, 'xx');
    expect(received(tester), '');
    await press(tester, '1.259');
    expect(received(tester), '1.25', reason: 'a third decimal is ignored');
    await press(tester, 'xx');
    expect(received(tester), '1.', reason: 'a half-typed amount like "1." is kept while typing');
    await press(tester, 'xx');
    await press(tester, '05');
    expect(received(tester), '5', reason: '0 then 5 is 5');
    await press(tester, '..');
    expect(received(tester), '5.', reason: 'only one point');
    await leave(tester);
  });

  testWidgets('long-pressing backspace clears the amount', (tester) async {
    await openPay(tester);
    await press(tester, '123');
    expect(received(tester), '123');
    final del = find.byKey(const Key('key-del'));
    await tester.ensureVisible(del);
    await tester.longPress(del);
    await tester.pump();
    expect(received(tester), '');
    await leave(tester);
  });

  testWidgets('the hidden open-amount product: made once, no stock count, off the quick tiles; amounts add up on one cart line', (tester) async {
    final store = await openHome(tester);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 1000)],
    ));
    final a = await store.openAmountProduct(name: 'Other item');
    final b = await store.openAmountProduct(name: 'Other item');
    expect(b.variantId, a.variantId, reason: 'the same product every time');
    expect(a.trackStock, isFalse);

    final ops = (await store.nextOps()).where((o) => o.kind == 'upsert_product' && (o.payload['variant'] as Map)['sku'] == openAmountSku);
    expect(ops, hasLength(1));
    expect(ops.single.payload['track_stock'], false);
    expect((await store.quickItems()).map((p) => p.name).toList(), ['Kape']);

    final cart = Cart(store);
    cart.addOpenAmount(a, 1250);
    cart.addOpenAmount(a, 500);
    expect(cart.lines, hasLength(1));
    expect(cart.subtotal, 1750);
    await leave(tester);
  });
}
