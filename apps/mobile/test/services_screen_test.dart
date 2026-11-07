import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';

import 'products_test.dart' show leave, openHome;

Future<DriftStore> openServices(WidgetTester tester) async {
  final store = await openHome(tester);
  await tester.tap(find.byKey(const Key('tile-today')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tile-services')));
  await tester.pumpAndSettle();
  return store;
}

Future<void> enter(WidgetTester tester, String action, Map<String, String> fields, {String? wallet}) async {
  await tester.tap(find.byKey(Key(action)));
  await tester.pumpAndSettle();
  if (wallet != null) await tester.tap(find.byKey(Key('wallet-$wallet')));
  for (final e in fields.entries) {
    await tester.enterText(find.byKey(Key(e.key)), e.value);
  }
  await tester.tap(find.byKey(const Key('service-save')));
  await tester.pumpAndSettle();
}

String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('cash in: the fee is today\'s income, the wallet float goes down and is flagged, one op is queued', (tester) async {
    final store = await openServices(tester);
    expect(find.text('No load or e-wallet entries today'), findsOneWidget);
    await enter(tester, 'service-cash-in', {'service-amount': '500', 'service-fee': '10', 'service-ref': '09171234567'}, wallet: 'gcash');

    expect(text(tester, 'services-fees'), '₱10.00');
    expect(text(tester, 'float-gcash'), '-₱500.00');
    expect(find.text('Needs a top-up'), findsOneWidget);
    expect(find.textContaining('Cash in · GCash'), findsOneWidget);
    expect(find.textContaining('09171234567'), findsOneWidget);
    final ops = await store.nextOps();
    expect(ops.map((o) => o.kind), ['record_service_txn']);
    expect((ops.single.payload['amount'], ops.single.payload['fee'], ops.single.payload['wallet']), (50000, 1000, 'gcash'));
    await leave(tester);
  });

  testWidgets('load: income is price minus what the wallet paid; a price under the load amount is refused', (tester) async {
    final store = await openServices(tester);
    await tester.tap(find.byKey(const Key('service-load')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('service-amount')), '50');
    await tester.enterText(find.byKey(const Key('service-price')), '40');
    await tester.tap(find.byKey(const Key('service-save')));
    await tester.pumpAndSettle();
    expect(find.text('The price must be at least the load amount'), findsOneWidget);
    expect(await store.nextOps(), isEmpty);

    await tester.enterText(find.byKey(const Key('service-price')), '55');
    await tester.tap(find.byKey(const Key('service-save')));
    await tester.pumpAndSettle();
    expect(text(tester, 'services-fees'), '₱5.00');
    expect(text(tester, 'float-load'), '-₱50.00');
    expect((await store.nextOps()).single.payload['price'], 5500);
    await leave(tester);
  });

  testWidgets('float: top up from the drawer, then a correction needs a note; cancelling an entry puts the money back', (tester) async {
    final store = await openServices(tester);
    await tester.tap(find.byKey(const Key('service-float')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('float-kind-float_topup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wallet-gcash')));
    await tester.enterText(find.byKey(const Key('service-amount')), '1000');
    await tester.tap(find.byKey(const Key('service-save')));
    await tester.pumpAndSettle();
    expect(text(tester, 'float-gcash'), '₱1,000.00');

    await tester.tap(find.byKey(const Key('service-float')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('float-kind-float_adjust')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('service-amount')), '-50');
    await tester.tap(find.byKey(const Key('service-save')));
    await tester.pumpAndSettle();
    expect(find.text('A note is needed'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('service-note')), 'sobra sa app');
    await tester.tap(find.byKey(const Key('service-save')));
    await tester.pumpAndSettle();
    expect(text(tester, 'float-gcash'), '₱950.00');

    final topup = (await store.watchServiceTxns(from: DateTime(2000), to: DateTime(2100)).first).firstWhere((e) => e.kind == 'float_topup');
    await tester.tap(find.byKey(Key('service-${topup.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('service-void-yes')));
    await tester.pumpAndSettle();
    expect(text(tester, 'float-gcash'), '-₱50.00');
    expect(find.textContaining('Cancelled'), findsOneWidget);
    expect((await store.nextOps()).last.kind, 'void_service_txn', reason: 'the cancel is queued after the entries');
    expect(await store.failedOps(), isEmpty);
    await leave(tester);
  });
}
