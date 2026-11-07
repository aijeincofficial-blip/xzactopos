import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;
import 'widget_test.dart' show FakeBackend;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';

Future<void> seed(DriftStore store) => store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape 3-in-1'), serverProduct(_p2, 'Asukal 1/4')],
      variants: [
        {...serverVariant(_v1, _p1), 'reorder_point': 5},
        serverVariant(_v2, _p2),
      ],
      prices: [serverPrice(_v1, 1200), serverPrice(_v2, 1500)],
    ));

Future<DriftStore> openStock(WidgetTester tester) async {
  final store = await openHome(tester);
  await seed(store);
  await tester.tap(find.byKey(const Key('tile-stock')));
  await tester.pumpAndSettle();
  return store;
}

Future<void> act(WidgetTester tester, String productId, String action) async {
  await tester.tap(find.byKey(Key('stock-$productId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(action)));
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('never-counted products say so, with no warning', (tester) async {
    await openStock(tester);
    expect(find.text('Not counted'), findsNWidgets(2));
    expect(find.text('Running low'), findsNothing);
    await leave(tester);
  });

  testWidgets('stock in: shows at once, goes low against the reorder point, queues one op', (tester) async {
    final store = await openStock(tester);
    await act(tester, _p1, 'action-stock-in');
    await tester.enterText(find.byKey(const Key('stockin-qty')), '4');
    await tester.enterText(find.byKey(const Key('stockin-cost')), '9.50');
    await tester.tap(find.byKey(const Key('stockin-save')));
    await tester.pumpAndSettle();

    expect(find.text('4'), findsOneWidget);
    expect(find.text('Running low'), findsOneWidget);
    final op = (await store.nextOps()).single;
    expect(op.kind, 'receive_stock');
    expect(op.payload['qty'], 4.0);
    expect(op.payload['unit_cost'], 950);

    // the "Low" filter lists only it
    await tester.tap(find.byKey(const Key('filter-low')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock-$_p1')), findsOneWidget);
    expect(find.byKey(const Key('stock-$_p2')), findsNothing);
    await leave(tester);
  });

  testWidgets('bad stock-in numbers are refused', (tester) async {
    final store = await openStock(tester);
    await act(tester, _p1, 'action-stock-in');
    await tester.enterText(find.byKey(const Key('stockin-qty')), '0');
    await tester.tap(find.byKey(const Key('stockin-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number, like 12.50'), findsOneWidget);
    expect(await store.nextOps(), isEmpty);
    await leave(tester);
  });

  testWidgets('a count writes the difference and keeps the reason', (tester) async {
    final store = await openStock(tester);
    await store.receiveStock(variantId: _v2, qty: 20, opId: 'r2');
    await tester.pumpAndSettle();
    await act(tester, _p2, 'action-count');
    expect(tester.widget<TextField>(find.byKey(const Key('count-qty'))).controller!.text, '20');
    await tester.enterText(find.byKey(const Key('count-qty')), '17');
    await tester.tap(find.byKey(const Key('reason-damage')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('count-save')));
    await tester.pumpAndSettle();

    expect(find.text('17'), findsOneWidget);
    final op = (await store.nextOps()).last;
    expect(op.kind, 'adjust_stock');
    expect(op.payload['counted'], 17.0);
    expect(op.payload['reason'], 'damage');
    await leave(tester);
  });

  testWidgets('Home shows how many are running low, and the Sell screen warns', (tester) async {
    final store = await openHome(tester);
    await seed(store);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-badge')), findsNothing);
    await store.receiveStock(variantId: _v1, qty: 3, opId: 'r1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-badge')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tile-sell')));
    await tester.pumpAndSettle();
    expect(find.text('3 left, running low'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a cashier can look at stock but not change it', (tester) async {
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    final backend = FakeBackend(signedInAtStart: true)
      ..access = {
        'role': 'cashier',
        'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
      };
    await tester.pumpWidget(App(backend: backend, openStore: ({bool safeMode = false}) => store, initialLocale: 'en'));
    await tester.pumpAndSettle();
    await seed(store);
    await tester.tap(find.byKey(const Key('tile-stock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stock-$_p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('action-stock-in')), findsNothing);
    await leave(tester);
  });

  test('a product saved with a reorder point sends it and keeps it on the phone', () async {
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('t', baseCurrency: 'PHP');
    await store.saveProduct(
        const ProductDraft(id: _p1, variantId: _v1, name: 'Kape', price: 1200, reorderPoint: 6), opId: 'o1');
    expect(((await store.nextOps()).single.payload['variant'] as Map)['reorder_point'], 6.0);
    expect((await store.watchProducts().first).single.reorderPoint, 6);
    await store.close();
  });
}
