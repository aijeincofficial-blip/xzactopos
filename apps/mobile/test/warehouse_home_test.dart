import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart' show ProductDraft;
import 'package:xzactopos_mobile/data/warehouse_models.dart';

import 'widget_test.dart' show FakeBackend;

const _w1 = 'w1000000-0000-4000-8000-000000000001';
const _w2 = 'w2000000-0000-4000-8000-000000000002';
const _sup = 'a0000000-0000-4000-8000-0000000000a1';
const _po1 = 'p1000000-0000-4000-8000-000000000001';
const _po2 = 'p2000000-0000-4000-8000-000000000002';
const _p1 = 'c1000000-0000-4000-8000-000000000001';
const _rice = 'v1000000-0000-4000-8000-000000000001';
const _p2 = 'c2000000-0000-4000-8000-000000000002';
const _oil = 'v2000000-0000-4000-8000-000000000002';

const _at = '2026-11-09T09:00:00Z';

Map<String, dynamic> _t(List<Map<String, dynamic>> rows) => {'rows': rows, 'cursor': null, 'has_more': false};

Map<String, dynamic> _pull({
  List<Map<String, dynamic>> warehouses = const [],
  List<Map<String, dynamic>> stock = const [],
  List<Map<String, dynamic>> pos = const [],
  List<Map<String, dynamic>> bins = const [],
  List<Map<String, dynamic>> binStock = const [],
}) =>
    {
      'server_time': '2026-11-09T10:00:00Z',
      'warehouses': _t(warehouses),
      'bins': _t(bins),
      'bin_stock_levels': _t(binStock),
      'stock_levels': _t(stock),
      'suppliers': _t([
        {'id': _sup, 'name': 'Mega Rice Trading', 'contact_name': null, 'phone': null, 'email': null, 'notes': null, 'updated_at': _at, 'deleted_at': null},
      ]),
      'purchase_orders': _t(pos),
    };

Map<String, dynamic> _wh(String id, String code, {bool bins = false}) =>
    {'id': id, 'code': code, 'name': 'Bodega $code', 'bins_enabled': bins, 'active': true, 'updated_at': _at, 'deleted_at': null};

Map<String, dynamic> _po(String id, String no, String wh) => {
      'id': id, 'po_no': no, 'warehouse_id': wh, 'supplier_id': _sup, 'status': 'ordered', 'expected_at': null, 'notes': null, 'updated_at': _at,
      'items': [
        {'id': '$id-i1', 'variant_id': _rice, 'qty_ordered': 100, 'qty_received': 0, 'unit_cost': 1000},
        {'id': '$id-i2', 'variant_id': _oil, 'qty_ordered': 20, 'qty_received': 0, 'unit_cost': 5000},
      ],
    };

Map<String, dynamic> _bin(String id, String wh, String code) => {
      'id': id, 'warehouse_id': wh, 'zone_id': null, 'code': code, 'aisle': null, 'rack': null, 'shelf': null, 'position': null,
      'type': 'shelf', 'max_qty': null, 'active': true, 'updated_at': _at, 'deleted_at': null,
    };

Map<String, dynamic> _stock(String wh, String v, num q) => {'location_id': wh, 'variant_id': v, 'qty_on_hand': q, 'avg_cost': 1000, 'updated_at': _at};

/// Opens the app signed in as [role] with [seed] applied to the device store before the first screen.
Future<DriftStore> open(WidgetTester tester, {String? role = 'warehouse', String locale = 'en', Size? size, bool two = true, Future<void> Function(DriftStore)? before, bool bins = false, FakeBackend Function()? makeBackend, bool spinnerOk = false}) async {
  tester.view.physicalSize = size ?? const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final store = DriftStore(AppDatabase(NativeDatabase.memory()));
  await store.ensureTenant('t1', baseCurrency: 'PHP');
  await store.saveProduct(const ProductDraft(id: _p1, variantId: _rice, name: 'Rice 25kg', price: 1200), opId: 'op-1');
  await store.saveProduct(const ProductDraft(id: _p2, variantId: _oil, name: 'Cooking oil', price: 900), opId: 'op-2');
  await store.applyPullWarehouse(_pull(
    warehouses: [_wh(_w1, 'W1', bins: bins), if (two) _wh(_w2, 'W2')],
    bins: [if (bins) _bin('b1000000-0000-4000-8000-000000000001', _w1, 'A-01'), if (bins) _bin('b2000000-0000-4000-8000-000000000002', _w1, 'B-02')],
    binStock: [if (bins) {'bin_id': 'b1000000-0000-4000-8000-000000000001', 'variant_id': _rice, 'qty_on_hand': 40, 'updated_at': _at}, if (bins) {'bin_id': 'b2000000-0000-4000-8000-000000000002', 'variant_id': _oil, 'qty_on_hand': 5, 'updated_at': _at}],
    stock: [_stock(_w1, _rice, 40), if (two) _stock(_w2, _oil, 5)],
    pos: [_po(_po1, 'PO-1', _w1), if (two) _po(_po2, 'PO-2', _w2)],
  ));
  if (before != null) await before(store);
  final backend = (makeBackend?.call() ?? FakeBackend(signedInAtStart: true))
    ..signedInAtStart = true
    ..access = {
      'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
      'role': ?role,
    };
  await tester.pumpWidget(App(backend: backend, openStore: ({bool safeMode = false}) => store, initialLocale: locale));
  if (spinnerOk) {
    // a hidden tab may be showing a progress spinner, which never lets pumpAndSettle finish
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  } else {
    await tester.pumpAndSettle();
  }
  return store;
}

Future<void> tab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('a warehouse clerk lands on the warehouse home, not the store tabs', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('tab-receive')), findsOneWidget);
    expect(find.byKey(const Key('tile-sell')), findsNothing);
    expect(find.text('W1 · Bodega W1'), findsOneWidget);
    await leave(tester);
  });

  for (final role in ['admin', 'cashier', 'superadmin', null]) {
    testWidgets('role $role keeps the store home', (tester) async {
      await open(tester, role: role);
      expect(find.byKey(const Key('tab-receive')), findsNothing);
      expect(find.byKey(const Key('tile-sell')), findsOneWidget);
      await leave(tester);
    });
  }

  testWidgets('the receive tab lists the open orders of the active warehouse only', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('order-$_po1')), findsOneWidget);
    expect(find.byKey(const Key('order-$_po2')), findsNothing);
    expect(find.textContaining('PO-1 · Mega Rice Trading'), findsOneWidget);
    expect(find.textContaining('120 left to receive'), findsOneWidget);
    expect(find.byKey(const Key('no-receipts')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('an empty warehouse says so', (tester) async {
    final store = await open(tester, two: false);
    await store.applyPullWarehouse({
      ..._pull(warehouses: [_wh(_w1, 'W1')]),
      'purchase_orders': _t([{..._po(_po1, 'PO-1', _w1), 'status': 'received', 'updated_at': '2026-11-09T09:30:00Z'}]),
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-orders')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a receipt made here shows as waiting to sync and lowers what is left', (tester) async {
    await open(tester, before: (s) => s.receiveAgainstPo(poId: _po1, lines: [const ReceiptLine(variantId: _rice, qty: 100)], opId: 'rcv-1'));
    expect(find.byKey(const Key('order-pending')), findsOneWidget);
    expect(find.textContaining('20 left to receive'), findsOneWidget);
    expect(find.byKey(const Key('receipt-rcv-1')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('an order opens to its lines with product names and progress', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('order-$_po1')));
    await tester.pumpAndSettle();
    expect(find.text('Rice 25kg'), findsOneWidget);
    expect(find.text('0 of 100 received'), findsOneWidget);
    expect(find.text('Cooking oil'), findsOneWidget);
    expect(find.text('0 of 20 received'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the warehouse picker appears only with two warehouses and the choice is remembered', (tester) async {
    final store = await open(tester);
    await tester.tap(find.byKey(const Key('warehouse-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('warehouse-$_w2')));
    await tester.pumpAndSettle();
    expect(find.text('W2 · Bodega W2'), findsOneWidget);
    expect(find.text('Working in Bodega W2'), findsOneWidget);
    expect(find.byKey(const Key('order-$_po2')), findsOneWidget);
    expect(find.byKey(const Key('order-$_po1')), findsNothing);
    expect((await store.activeWarehouse())!.id, _w2);
    await leave(tester);
  });

  testWidgets('with one warehouse the chip does not open a picker', (tester) async {
    await open(tester, two: false);
    await tester.tap(find.byKey(const Key('warehouse-chip')));
    await tester.pumpAndSettle();
    expect(find.text('Choose warehouse'), findsNothing);
    await tab(tester, 'tab-more');
    expect(find.byKey(const Key('more-switch')), findsNothing);
    await leave(tester);
  });

  testWidgets('the stock tab lists products with quantities and searches by name', (tester) async {
    await open(tester);
    await tab(tester, 'tab-stock');
    expect(find.text('Rice 25kg'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('Cooking oil'), findsNothing, reason: 'that stock is in the other warehouse');
    await tester.enterText(find.byKey(const Key('stock-search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-stock')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('stock-search')), 'ric');
    await tester.pumpAndSettle();
    expect(find.text('Rice 25kg'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('in a warehouse with bins a stock row shows where the product sits', (tester) async {
    await open(tester, bins: true);
    await tab(tester, 'tab-stock');
    await tester.tap(find.byKey(const Key('stock-$_rice')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bin-row-b1000000-0000-4000-8000-000000000001')), findsOneWidget);
    expect(find.text('A-01'), findsOneWidget);
    expect(find.byKey(const Key('bin-row-b2000000-0000-4000-8000-000000000002')), findsNothing, reason: 'that bin holds another product');
    await leave(tester);
  });

  testWidgets('without bins a stock row does nothing when tapped', (tester) async {
    await open(tester);
    await tab(tester, 'tab-stock');
    await tester.tap(find.byKey(const Key('stock-$_rice')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await leave(tester);
  });

  testWidgets('goods received here show as on the way in on the stock tab', (tester) async {
    await open(tester, before: (s) => s.receiveAgainstPo(poId: _po1, lines: [const ReceiptLine(variantId: _rice, qty: 10)], opId: 'rcv-2'));
    await tab(tester, 'tab-stock');
    expect(find.text('10 on the way in'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the count tab is honest that counting is not on the phone yet', (tester) async {
    await open(tester);
    await tab(tester, 'tab-count');
    expect(find.byKey(const Key('count-soon')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('more offers the switch (two warehouses) and settings', (tester) async {
    await open(tester);
    await tab(tester, 'tab-more');
    expect(find.byKey(const Key('more-switch')), findsOneWidget);
    await tester.tap(find.byKey(const Key('more-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    await leave(tester);
  });

  testWidgets('Filipino labels', (tester) async {
    await open(tester, locale: 'fil');
    expect(find.text('Tanggapin'), findsOneWidget);
    expect(find.text('Bilang'), findsOneWidget);
    expect(find.text('Mga bukas na order'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a 360px phone shows every tab without overflow', (tester) async {
    await open(tester, size: const Size(720, 1280));
    for (final k in ['tab-receive', 'tab-count', 'tab-stock', 'tab-more']) {
      await tab(tester, k);
    }
    expect(tester.takeException(), isNull);
    await leave(tester);
  });
}
