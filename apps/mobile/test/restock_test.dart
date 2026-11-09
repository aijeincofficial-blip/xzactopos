import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/screens/restock.dart';

import 'products_test.dart' show leave;
import 'stock_screen_test.dart' show act, openStock;

const _p1 = '0190a000-0000-7000-8000-000000000001';

StockRow row(String id, double? qty, double reorder, {int cost = 0}) => StockRow(
      product: ProductView(
        id: id,
        variantId: 'v-$id',
        name: 'Item $id',
        unit: 'pc',
        sku: id,
        price: 1000,
        currency: 'PHP',
        active: true,
        pending: false,
        trackStock: true,
        taxRate: 0,
        cost: cost,
        reorderPoint: reorder,
      ),
      qty: qty,
      reorderPoint: reorder,
      pending: false,
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('buildRestock', () {
    test('only low products, emptiest first, back up to twice the reorder point', () {
      final lines = buildRestock([
        row('a', 4, 5, cost: 900), // low: buy 6
        row('b', 20, 5), // fine
        row('c', 0, 10), // empty: buy 20
        row('d', null, 5), // never counted: no warning, not listed
        row('e', 3, 0), // no reorder point: not listed
      ]);
      expect(lines.map((l) => l.row.product.id), ['c', 'a']);
      expect(lines.map((l) => l.suggested), [20, 6]);
      expect(lines.last.estimate, 5400);
      expect(lines.first.estimate, 0, reason: 'no cost known');
    });

    test('always suggests at least one', () {
      expect(buildRestock([row('a', 5, 5)]).single.suggested, 5);
      expect(buildRestock([row('a', 0.4, 0.4)]).single.suggested, 1);
    });
  });

  testWidgets('the list shows what is low, can be unticked and copied; empty says nothing is low', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final store = await openStock(tester);
    await tester.tap(find.byKey(const Key('open-restock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('restock-empty')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await act(tester, _p1, 'action-stock-in');
    await tester.enterText(find.byKey(const Key('stockin-qty')), '4');
    await tester.enterText(find.byKey(const Key('stockin-cost')), '9.50');
    await tester.tap(find.byKey(const Key('stockin-save')));
    await tester.pumpAndSettle();
    expect(await store.stockLeft('0190a000-0000-7000-8000-0000000000a1'), 4);

    await tester.tap(find.byKey(const Key('open-restock')));
    await tester.pumpAndSettle();
    expect(find.text('Kape 3-in-1'), findsOneWidget);
    expect(find.text('Buy 6'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);

    await tester.tap(find.byKey(const Key('restock-copy')));
    await tester.pump();
    expect(find.text('List copied. Paste it into a message.'), findsOneWidget);
    expect(copied, 'Shopping list\n• Kape 3-in-1 × 6');

    await tester.tap(find.byKey(const Key('restock-check-0190a000-0000-7000-8000-0000000000a1')));
    await tester.pump();
    expect(find.text('0 items'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('restock-copy'))).onPressed, isNull);
    await leave(tester);
  });
}
