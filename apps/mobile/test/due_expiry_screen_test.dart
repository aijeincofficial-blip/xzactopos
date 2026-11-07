import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/export.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

class FakeText implements TextSharer {
  final texts = <String>[];
  @override
  Future<void> shareText(String text) async => texts.add(text);
}

DateTime dayOffset(int days) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day).add(Duration(days: days));
}

Future<DriftStore> homeWithDebtor(WidgetTester tester) async {
  final store = await openHome(tester);
  await store.saveCustomer(id: 'c1', name: 'Aling Rosa', phone: '09171234567', opId: 'oc1');
  await store.adjustUtang(customerId: 'c1', amount: 15000, note: 'listahan', opId: 'oa1');
  return store;
}

Future<void> openCustomer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tile-utang')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('customer-row-c1')));
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('a pay-by date can be set from the picker and cleared; one op each', (tester) async {
    final store = await homeWithDebtor(tester);
    await openCustomer(tester);
    expect(find.byKey(const Key('customer-due')), findsNothing);

    await tester.tap(find.byKey(const Key('set-due')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-due')), findsOneWidget);
    expect((await store.watchCustomers().first).single.dueOn, dayOffset(7), reason: 'the picker starts a week ahead');
    expect((await store.nextOps()).last.kind, 'set_utang_due');

    await tester.tap(find.byKey(const Key('clear-due')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-due')), findsNothing);
    expect((await store.watchCustomers().first).single.dueOn, isNull);
    await leave(tester);
  });

  testWidgets('overdue customers are marked, filtered, and counted on Home', (tester) async {
    final store = await homeWithDebtor(tester);
    await store.setUtangDue(customerId: 'c1', dueOn: dayOffset(-3), opId: 'od1');
    await tester.pumpAndSettle();
    expect(find.text('1 overdue'), findsOneWidget, reason: 'Home tile');

    await tester.tap(find.byKey(const Key('tile-utang')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overdue-c1')), findsOneWidget);
    expect(find.text('3 days overdue'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-utang-overdue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-row-c1')), findsOneWidget);

    await store.setUtangDue(customerId: 'c1', dueOn: dayOffset(0), opId: 'od2'); // due today is not overdue
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-row-c1')), findsNothing);
    expect(find.text('Nobody is overdue'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the statement is shared as text: balance, no phone number, no notes', (tester) async {
    final fake = FakeText();
    textSharer = fake;
    addTearDown(() => textSharer = const SystemTextSharer());
    await homeWithDebtor(tester);
    await openCustomer(tester);
    await tester.tap(find.byKey(const Key('send-statement')));
    await tester.pumpAndSettle();
    final text = fake.texts.single;
    expect(text, contains('Utang statement: Aling Rosa'));
    expect(text, contains('₱150.00'));
    expect(text, isNot(contains('09171234567')));
    expect(text, isNot(contains('listahan')));
    await leave(tester);
  });

  testWidgets('expiry on Stock: shown on the row, counted on Home, filterable, settable from the picker', (tester) async {
    final store = await openHome(tester);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Gatas')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 2500)],
    ));
    await store.receiveStock(variantId: _v1, qty: 5, opId: 'in1');
    await tester.tap(find.byKey(const Key('tile-stock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-expiring')), findsNothing, reason: 'no dates yet');

    // set it from the action sheet; the picker starts 90 days ahead, so it is not "soon" yet
    await tester.tap(find.byKey(const Key('stock-$_p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('action-set-expiry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expiry-$_p1')), findsOneWidget);
    expect(find.byKey(const Key('filter-expiring')), findsNothing);
    expect((await store.nextOps()).last.kind, 'set_expiry');

    await store.setExpiry(variantId: _v1, expiresOn: dayOffset(3), opId: 'ex1');
    await tester.pumpAndSettle();
    expect(find.text('Expires in 3 days'), findsOneWidget);
    expect(find.text('Expiring (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-expiring')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock-$_p1')), findsOneWidget);

    await store.setExpiry(variantId: _v1, expiresOn: dayOffset(-2), opId: 'ex2');
    await tester.pumpAndSettle();
    expect(find.text('Expired 2 days ago'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 expiring'), findsOneWidget, reason: 'Home tile');
    await leave(tester);
  });
}
