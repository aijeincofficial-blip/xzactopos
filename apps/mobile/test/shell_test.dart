import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('opens on Sell with the five tabs; Reports is there for the owner', (tester) async {
    await openHome(tester);
    expect(find.byKey(const Key('sell-search')), findsOneWidget);
    for (final k in ['tile-sell', 'tile-stock', 'tile-utang', 'tile-reports', 'tab-more']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    await leave(tester);
  });

  testWidgets('the Today strip on Sell shows the day and opens Today', (tester) async {
    final store = await openHome(tester);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 1000)],
    ));
    expect(tester.widget<Text>(find.byKey(const Key('today-strip-total'))).data, '₱0.00');
    await store.commitSale(
      SaleDraft(
        id: 's1',
        soldAt: DateTime.now(),
        lines: const [SaleLine(variantId: _v1, name: 'Kape', qty: 2, unitPrice: 1000)],
        payments: const [PaymentDraft('cash', 2000)],
      ),
      opId: 'o1',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('today-strip-total'))).data, '₱20.00');
    expect(tester.widget<Text>(find.byKey(const Key('today-strip-count'))).data, '1 sale');

    await tester.tap(find.byKey(const Key('tile-today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-total')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('More lists the other tools and opens them', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('tab-more')));
    await tester.pumpAndSettle();
    for (final k in ['tile-products', 'tile-restock', 'more-today', 'more-expenses', 'more-services', 'more-close-day', 'tile-data', 'tile-settings']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    await tester.ensureVisible(find.byKey(const Key('more-expenses')));
    await tester.tap(find.byKey(const Key('more-expenses')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense-add')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the phone back button goes to Sell first, from any other tab', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('tile-stock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock-search')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sell-search')), findsOneWidget);
    expect(find.byKey(const Key('stock-search')), findsNothing);
    await leave(tester);
  });
}
