import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show backend, leave;
import 'widget_test.dart' show FakeBackend;

const _a = '0190a000-0000-7000-8000-0000000000e1';
const _b = '0190a000-0000-7000-8000-0000000000e2';
const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

Future<DriftStore> openStores(WidgetTester tester, {required List<Map<String, String>> stores}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final store = DriftStore(AppDatabase(NativeDatabase.memory()));
  backend = FakeBackend(signedInAtStart: true)
    ..access = {
      'tenant': {'id': 't1', 'name': 'Tindahan ni Nena', 'base_currency': 'PHP'},
      'locations': [for (final s in stores) {'id': s['id'], 'type': 'store', 'code': s['code'], 'name': s['name']}],
    };
  await tester.pumpWidget(App(backend: backend, openStore: ({bool safeMode = false}) => store, initialLocale: 'en'));
  await tester.pumpAndSettle();
  await store.applyPull(pullPage(
    products: [serverProduct(_p1, 'Kape')],
    variants: [serverVariant(_v1, _p1)],
    prices: [serverPrice(_v1, 1000)],
  ));
  return store;
}

const _two = [
  {'id': _a, 'code': 'S01', 'name': 'Poblacion'},
  {'id': _b, 'code': 'S02', 'name': 'Palengke'},
];

SaleDraft sale(String id, int cents) => SaleDraft(
      id: id,
      soldAt: DateTime.now(),
      lines: [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: cents)],
      payments: [PaymentDraft('cash', cents)],
    );

String strip(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('today-strip-total'))).data!;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('a one-store user never sees the store chip', (tester) async {
    await openStores(tester, stores: const [
      {'id': _a, 'code': 'S01', 'name': 'Poblacion'},
    ]);
    expect(find.byKey(const Key('store-chip')), findsNothing);
    await leave(tester);
  });

  testWidgets('with two stores the chip names the current one; switching changes what Sell and Today show', (tester) async {
    final store = await openStores(tester, stores: _two);
    expect(find.byKey(const Key('store-chip')), findsOneWidget);
    expect(find.text('Poblacion'), findsOneWidget, reason: 'the first store is active by default');
    expect(store.activeLocationId, _a);

    await store.commitSale(sale('s-a', 2000), opId: 'o-a'); // sold at Poblacion
    await tester.pumpAndSettle();
    expect(strip(tester), '₱20.00');

    await tester.tap(find.byKey(const Key('store-chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-$_a')), findsOneWidget);
    expect(find.byKey(const Key('store-$_b')), findsOneWidget);
    await tester.tap(find.byKey(const Key('store-$_b')));
    await tester.pumpAndSettle();

    expect(store.activeLocationId, _b);
    expect(find.text('Now selling at Palengke'), findsOneWidget);
    expect(find.text('Palengke'), findsWidgets, reason: 'the chip follows');
    expect(strip(tester), '₱0.00', reason: "Palengke has sold nothing; Poblacion's sale is not counted here");

    await store.commitSale(sale('s-b', 500), opId: 'o-b');
    await tester.pumpAndSettle();
    expect(strip(tester), '₱5.00');
    final ops = (await store.nextOps()).where((o) => o.kind == 'record_sale').toList();
    expect(ops.map((o) => o.payload['location_id']), [_a, _b], reason: 'each sale keeps the store it was rung up at');
    await leave(tester);
  });

  testWidgets('picking the store that is already active changes nothing', (tester) async {
    final store = await openStores(tester, stores: _two);
    await tester.tap(find.byKey(const Key('store-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('store-$_a')));
    await tester.pumpAndSettle();
    expect(store.activeLocationId, _a);
    expect(find.textContaining('Now selling at'), findsNothing);
    await leave(tester);
  });

  testWidgets('More shows the chip too', (tester) async {
    await openStores(tester, stores: _two);
    await tester.tap(find.byKey(const Key('tab-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-chip')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a supervisor approval for a refused expense asks for the refused op\'s store', (tester) async {
    final store = await openStores(tester, stores: _two);
    backend.pinSet = '1234';
    await store.setActiveStore(_b);
    await store.recordExpense(id: 'e1', amount: 900, category: 'other', opId: 'oe1');
    await store.db.customUpdate("update outbox set status = 'failed', last_error = 'approval_required' where entity_id = 'e1'",
        updates: {store.db.outbox});
    await tester.tap(find.byKey(const Key('tab-more')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('more-expenses')));
    await tester.tap(find.byKey(const Key('more-expenses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-e1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('approval-pin')), '1234');
    await tester.tap(find.byKey(const Key('approval-ok')));
    await tester.pumpAndSettle();
    expect(backend.approvalLocations, [_b]);
    await leave(tester);
  });

  testWidgets('an utang payment can be taken in cash or by e-wallet; the choice goes in the op', (tester) async {
    final store = await openStores(tester, stores: _two);
    await store.saveCustomer(id: 'c1', name: 'Aling Rosa', opId: 'oc1');
    await store.adjustUtang(customerId: 'c1', amount: 5000, opId: 'oa1');
    await tester.tap(find.byKey(const Key('tile-utang')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-row-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-payment')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const Key('utang-method')), matching: find.text('GCash / Maya')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('utang-amount')), '20');
    await tester.tap(find.byKey(const Key('utang-save')));
    await tester.pumpAndSettle();
    final pay = (await store.nextOps()).lastWhere((o) => o.kind == 'record_utang_payment').payload;
    expect((pay['amount'], pay['method'], pay['location_id']), (2000, 'ewallet', _a));
    await leave(tester);
  });

  testWidgets('with a sale in progress the switch asks first: cancel, keep the sale, or clear it', (tester) async {
    final store = await openStores(tester, stores: _two);
    await tester.pumpAndSettle(); // the pulled product reaches the Sell tiles
    await tester.tap(find.byKey(const Key('tile-$_p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-line-0')), findsOneWidget);

    Future<void> pickB() async {
      await tester.tap(find.byKey(const Key('store-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('store-$_b')));
      await tester.pumpAndSettle();
    }

    // cancel: nothing changes
    await pickB();
    expect(find.text('Switch store?'), findsOneWidget);
    expect(find.textContaining('1 item'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.activeLocationId, _a);
    expect(find.byKey(const Key('cart-line-0')), findsOneWidget);

    // keep: the store changes, the sale stays
    await pickB();
    await tester.tap(find.byKey(const Key('switch-keep')));
    await tester.pumpAndSettle();
    expect(store.activeLocationId, _b);
    expect(find.byKey(const Key('cart-line-0')), findsOneWidget);

    // clear: back to the first store with the sale thrown away
    await tester.tap(find.byKey(const Key('store-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('store-$_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-clear')));
    await tester.pumpAndSettle();
    expect(store.activeLocationId, _a);
    expect(find.byKey(const Key('cart-line-0')), findsNothing);
    expect(find.text('Tap an item to add it'), findsOneWidget);

    // an empty cart switches without a question
    await pickB();
    expect(find.text('Switch store?'), findsNothing);
    expect(store.activeLocationId, _b);
    await leave(tester);
  });
}
