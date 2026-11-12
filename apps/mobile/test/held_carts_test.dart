import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/screens/cart.dart';
import 'package:xzactopos_mobile/screens/held_carts.dart';

import 'products_test.dart' show leave;
import 'sell_test.dart' show openSell, total;

const _p1 = ProductView(
  id: '0190a000-0000-7000-8000-000000000001',
  variantId: '0190a000-0000-7000-8000-0000000000a1',
  name: 'Kape 3-in-1',
  unit: 'pcs',
  sku: 'KAPE-1',
  price: 1500,
  currency: 'PHP',
  active: true,
  pending: false,
);

const _p2 = ProductView(
  id: '0190a000-0000-7000-8000-000000000002',
  variantId: '0190a000-0000-7000-8000-0000000000a2',
  name: 'Pandesal Pack',
  unit: 'pack',
  sku: 'PAN-1',
  price: 4500,
  currency: 'PHP',
  active: true,
  pending: false,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('HeldCarts persists per active store and preserves line price overrides and discounts', () async {
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    addTearDown(store.close);
    await store.ensureTenant(
      't1',
      baseCurrency: 'PHP',
      locationId: 's1',
      stores: const [
        StoreRef(id: 's1', name: 'Central Store'),
        StoreRef(id: 's2', name: 'Express Branch'),
      ],
    );

    final cart = Cart(store);
    final held = HeldCarts(store);
    await held.restore();

    cart.add(_p1, qty: 2);
    cart.setUnitPrice(0, 1400);
    cart.setDiscount(0, 300);
    expect(cart.subtotal, 2500);

    final parked = await held.parkCurrent(cart, label: 'Ate Maria');
    expect(parked, isNotNull);
    expect(cart.isEmpty, isTrue);
    expect(held.count, 1);

    // Switching to s2 isolates held carts per store
    await store.setActiveStore('s2');
    await held.restore();
    expect(held.isEmpty, isTrue);

    // Switching back to s1 restores Ate Maria with exact override and discount
    await store.setActiveStore('s1');
    final reloaded = HeldCarts(store);
    await reloaded.restore();
    expect(reloaded.count, 1);
    expect(reloaded.items.first.label, 'Ate Maria');
    expect(reloaded.items.first.subtotal, 2500);

    // Start a new cart on s1, then resume Ate Maria -> active cart swaps into held list
    cart.add(_p2, qty: 1);
    final res = await reloaded.resume(parked!.id, cart, swapLabel: 'Walk-in');
    expect(res.swapped, isTrue);
    expect(cart.subtotal, 2500);
    expect(cart.lines.single.unitPrice, 1400);
    expect(cart.lines.single.discount, 300);
    expect(reloaded.count, 1);
    expect(reloaded.items.single.label, 'Walk-in');
    expect(reloaded.items.single.subtotal, 4500);
  });

  testWidgets('SellScreen parks, swaps, and discards held carts cleanly on a 360dp phone', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await openSell(tester);
    expect(find.byKey(const Key('hold-cart-btn')), findsNothing);
    expect(find.byKey(const Key('held-carts-btn')), findsNothing);

    // Add Kape 3-in-1 (12.50) x2 = 25.00
    await tester.tap(find.byKey(const Key('tile-0190a000-0000-7000-8000-000000000001')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tile-0190a000-0000-7000-8000-000000000001')));
    await tester.pump();
    expect(total(tester), '₱25.00');
    expect(find.byKey(const Key('hold-cart-btn')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Park with customer label
    await tester.tap(find.byKey(const Key('hold-cart-btn')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('hold-cart-note')), 'Kuya Ben');
    await tester.tap(find.byKey(const Key('confirm-hold-cart')));
    await tester.pumpAndSettle();

    expect(total(tester), '₱0.00');
    expect(find.byKey(const Key('held-carts-btn')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Start another cart: Asukal (45.00)
    await tester.tap(find.byKey(const Key('tile-0190a000-0000-7000-8000-000000000002')));
    await tester.pump();
    expect(total(tester), '₱45.00');

    // Open Held sales sheet and resume Kuya Ben -> swaps Asukal onto hold
    await tester.tap(find.byKey(const Key('held-carts-btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('held-carts-sheet')), findsOneWidget);
    expect(find.text('Kuya Ben'), findsOneWidget);

    final resumeBtn = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('resume-held-'),
    );
    await tester.tap(resumeBtn);
    await tester.pumpAndSettle();

    expect(total(tester), '₱25.00');
    expect(find.byKey(const Key('held-carts-btn')), findsOneWidget, reason: 'swapped cart remains on hold');

    // Open Held sales sheet and discard the swapped cart
    await tester.tap(find.byKey(const Key('held-carts-btn')));
    await tester.pumpAndSettle();
    final discardBtn = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('discard-held-'),
    );
    await tester.tap(discardBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('held-carts-btn')), findsNothing);
    expect(tester.takeException(), isNull);
    await leave(tester);
  });
}
