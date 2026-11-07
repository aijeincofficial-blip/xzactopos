import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show backend, leave, openHome;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

Future<DriftStore> openToday(WidgetTester tester) async {
  final store = await openHome(tester);
  await store.applyPull(pullPage(
    products: [serverProduct(_p1, 'Kape')],
    variants: [serverVariant(_v1, _p1)],
    prices: [serverPrice(_v1, 1000)],
  ));
  await tester.tap(find.byKey(const Key('tile-today')));
  await tester.pumpAndSettle();
  return store;
}

Future<void> addExpense(WidgetTester tester, String amount, {String? category}) async {
  await tester.tap(find.byKey(const Key('expense-add')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('expense-amount')), amount);
  if (category != null) await tester.tap(find.byKey(Key('expense-cat-$category')));
  await tester.tap(find.byKey(const Key('expense-save')));
  await tester.pumpAndSettle();
}

String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('add an expense: shown at once, counted in the total, queued as one op; a bad amount is refused', (tester) async {
    final store = await openToday(tester);
    expect(text(tester, 'today-expenses'), '₱0.00');
    await tester.tap(find.byKey(const Key('tile-expenses')));
    await tester.pumpAndSettle();
    expect(find.text('No expenses today'), findsOneWidget);

    await tester.tap(find.byKey(const Key('expense-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expense-amount')), '0');
    await tester.tap(find.byKey(const Key('expense-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense-save')), findsOneWidget, reason: 'dialog stays open');
    expect(await store.nextOps(), isEmpty);

    await tester.enterText(find.byKey(const Key('expense-amount')), '12.50');
    await tester.tap(find.byKey(const Key('expense-cat-transport')));
    await tester.enterText(find.byKey(const Key('expense-note')), 'tricycle');
    await tester.tap(find.byKey(const Key('expense-save')));
    await tester.pumpAndSettle();

    expect(text(tester, 'expenses-total'), '₱12.50');
    expect(find.text('Transport'), findsOneWidget);
    expect(find.textContaining('tricycle'), findsOneWidget);
    final ops = await store.nextOps();
    expect(ops.map((o) => o.kind), ['record_expense']);
    expect(ops.single.payload['amount'], 1250);
    expect(ops.single.payload['category'], 'transport');
    await leave(tester);
  });

  testWidgets('cancelling an expense strikes it out and takes it off the total', (tester) async {
    final store = await openToday(tester);
    await tester.tap(find.byKey(const Key('tile-expenses')));
    await tester.pumpAndSettle();
    await addExpense(tester, '5');
    final id = (await store.watchExpenses(from: DateTime(2000), to: DateTime(2100)).first).single.id;

    await tester.tap(find.byKey(Key('expense-$id')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expense-void-reason')), 'mali');
    await tester.tap(find.byKey(const Key('expense-void-yes')));
    await tester.pumpAndSettle();

    expect(text(tester, 'expenses-total'), '₱0.00');
    expect(find.textContaining('Cancelled'), findsOneWidget);
    expect((await store.nextOps()).map((o) => o.kind), ['record_expense', 'void_expense']);
    await leave(tester);
  });

  testWidgets('day close: expected cash, live short/over, saved as a record, can be counted again', (tester) async {
    final store = await openToday(tester);
    await store.commitSale(
      SaleDraft(
        id: 's1',
        soldAt: DateTime.now(),
        lines: const [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: 1000)],
        payments: const [PaymentDraft('cash', 1000)],
      ),
      opId: 'o1',
    );
    await tester.tap(find.byKey(const Key('tile-expenses')));
    await tester.pumpAndSettle();
    await addExpense(tester, '3');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tile-close-day')));
    await tester.pumpAndSettle();
    expect(text(tester, 'close-expected'), '₱7.00');

    await tester.enterText(find.byKey(const Key('close-counted')), '6');
    await tester.pump();
    expect(text(tester, 'close-diff'), 'Short by ₱1.00');
    await tester.enterText(find.byKey(const Key('close-counted')), '7');
    await tester.pump();
    expect(text(tester, 'close-diff'), 'Exact. Nothing short or over.');
    await tester.enterText(find.byKey(const Key('close-counted')), '8.50');
    await tester.pump();
    expect(text(tester, 'close-diff'), 'Over by ₱1.50');

    await tester.tap(find.byKey(const Key('close-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('close-saved')), findsOneWidget);
    expect(text(tester, 'close-saved-diff'), 'Over by ₱1.50');
    final close = (await store.nextOps()).where((o) => o.kind == 'close_day').single;
    expect((close.payload['expected_cash'], close.payload['counted_cash']), (700, 850));

    await tester.tap(find.byKey(const Key('close-again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('close-counted')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a refused expense asks for a supervisor PIN and is sent again with the approval', (tester) async {
    final store = await openToday(tester);
    backend.pinSet = '1234';
    await tester.tap(find.byKey(const Key('tile-expenses')));
    await tester.pumpAndSettle();
    await addExpense(tester, '9');
    final e = (await store.watchExpenses(from: DateTime(2000), to: DateTime(2100)).first).single;
    // the server refused it: a supervisor needs an approval
    await store.db.customUpdate("update outbox set status = 'failed', last_error = 'approval_required' where entity_id = '${e.id}'", updates: {store.db.outbox});
    await tester.pumpAndSettle();
    expect(find.byKey(Key('needs-pin-${e.id}')), findsOneWidget);

    await tester.tap(find.byKey(Key('expense-${e.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('approval-pin')), '0000');
    await tester.tap(find.byKey(const Key('approval-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Wrong PIN. Try again.'), findsOneWidget);
    expect(await store.failedOps(), hasLength(1), reason: 'still waiting');

    await tester.enterText(find.byKey(const Key('approval-pin')), '1234');
    await tester.tap(find.byKey(const Key('approval-ok')));
    await tester.pumpAndSettle();
    expect(backend.approvalCalls, [('record_expense', e.id), ('record_expense', e.id)]);
    expect(await store.failedOps(), isEmpty);
    expect((await store.nextOps()).single.payload['approval_id'], isNotNull);
    await leave(tester);
  });

  testWidgets('with no signal the PIN cannot be checked, and the PIN is never kept', (tester) async {
    final store = await openToday(tester);
    backend.pinSet = '1234';
    await tester.tap(find.byKey(const Key('tile-expenses')));
    await tester.pumpAndSettle();
    await addExpense(tester, '9');
    final e = (await store.watchExpenses(from: DateTime(2000), to: DateTime(2100)).first).single;
    await store.db.customUpdate("update outbox set status = 'failed', last_error = 'approval_required' where entity_id = '${e.id}'", updates: {store.db.outbox});
    await tester.pumpAndSettle();
    backend.offline = true;
    await tester.tap(find.byKey(Key('expense-${e.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('approval-pin')), '1234');
    await tester.tap(find.byKey(const Key('approval-ok')));
    await tester.pumpAndSettle();
    expect(find.text('No signal. The PIN can only be checked online.'), findsOneWidget);
    final rows = await store.db.customSelect("select group_concat(payload, '|') as p from outbox").getSingle();
    expect(rows.read<String?>('p') ?? '', isNot(contains('1234')));
    await leave(tester);
  });
}
