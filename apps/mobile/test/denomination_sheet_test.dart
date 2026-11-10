import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/denomination_sheet.dart';

void main() {
  testWidgets('Denomination sheet: counts bills and coins, computes total, and applies count', (tester) async {
    double appliedTotal = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDenominationSheet(
                ctx,
                currency: 'PHP',
                onApply: (total) {
                  appliedTotal = total;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Bills & Coins Counter'), findsOneWidget);
    expect(find.byKey(const Key('denom-total-text')), findsOneWidget);

    // Initial total is 0.00
    expect(tester.widget<Text>(find.byKey(const Key('denom-total-text'))).data, '₱0.00');

    // Increment ₱1000 bill twice
    await tester.tap(find.byKey(const Key('denom-inc-bill_1000')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('denom-inc-bill_1000')));
    await tester.pumpAndSettle();

    // Increment ₱500 bill once
    await tester.tap(find.byKey(const Key('denom-inc-bill_500')));
    await tester.pumpAndSettle();

    // Increment ₱100 bill once
    await tester.tap(find.byKey(const Key('denom-inc-bill_100')));
    await tester.pumpAndSettle();

    // Check running total: 2000 + 500 + 100 = 2600.00
    expect(tester.widget<Text>(find.byKey(const Key('denom-total-text'))).data, '₱2,600.00');

    // Decrement ₱1000 once
    await tester.tap(find.byKey(const Key('denom-dec-bill_1000')));
    await tester.pumpAndSettle();

    // Now total is 1000 + 500 + 100 = 1600.00
    expect(tester.widget<Text>(find.byKey(const Key('denom-total-text'))).data, '₱1,600.00');

    // Tap Apply Count
    await tester.tap(find.byKey(const Key('apply-denomination-btn')));
    await tester.pumpAndSettle();

    // Sheet is closed and applied total is 1600.0
    expect(appliedTotal, 1600.0);
    expect(find.text('Bills & Coins Counter'), findsNothing);
  });

  testWidgets('Denomination sheet: clear button resets all counts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDenominationSheet(
                ctx,
                currency: 'PHP',
                onApply: (_) {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('denom-inc-bill_100')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('denom-total-text'))).data, '₱100.00');

    // Tap Clear
    await tester.tap(find.byKey(const Key('denom-clear-btn')));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const Key('denom-total-text'))).data, '₱0.00');
  });
}
