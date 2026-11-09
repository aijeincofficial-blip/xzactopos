import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'products_test.dart' show leave, openHome;

String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

Future<void> openClose(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab-more')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('more-close-day')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('more-close-day')));
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('day close starts from yesterday\'s count, can be changed, and is saved with the opening cash', (tester) async {
    final store = await openHome(tester);
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    await store.closeDay(id: 'old-close', day: yesterday, countedCash: 50000, opId: 'o-old');

    await openClose(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('close-opening'))).controller!.text, '500.00',
        reason: 'what was counted last night stayed in the drawer');
    expect(text(tester, 'close-expected'), '₱500.00');

    await tester.enterText(find.byKey(const Key('close-counted')), '480');
    await tester.pump();
    expect(text(tester, 'close-diff'), 'Short by ₱20.00');

    await tester.enterText(find.byKey(const Key('close-opening')), '100');
    await tester.pump();
    await tester.pump(); // the expected-cash stream follows the new opening
    expect(text(tester, 'close-expected'), '₱100.00');
    expect(text(tester, 'close-diff'), 'Over by ₱380.00');

    await tester.ensureVisible(find.byKey(const Key('close-save')));
    await tester.tap(find.byKey(const Key('close-save')));
    await tester.pumpAndSettle();
    expect(text(tester, 'close-saved-opening'), 'Started with ₱100.00');

    final close = (await store.nextOps()).where((o) => o.kind == 'close_day').last;
    expect((close.payload['opening_cash'], close.payload['expected_cash'], close.payload['counted_cash']), (10000, 10000, 48000));
    await leave(tester);
  });

  testWidgets('with no earlier close the opening starts empty (zero)', (tester) async {
    await openHome(tester);
    await openClose(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('close-opening'))).controller!.text, '');
    expect(text(tester, 'close-expected'), '₱0.00');
    await leave(tester);
  });
}
