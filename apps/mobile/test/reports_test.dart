import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';

import 'products_test.dart' show backend, leave, openHome;
import 'widget_test.dart' show FakeBackend;

String day(int daysAgo) => DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: daysAgo)));

Map<String, dynamic> sample() => {
      'days': [
        {'day': day(2), 'net': 5000, 'txns': 2},
        {'day': day(0), 'net': 10000, 'txns': 3},
      ],
      'totals': {'net': 15000, 'gross': 16000, 'discount': 1000, 'cogs': 9000, 'txns': 5, 'cash': 9000, 'ewallet': 3000, 'utang': 3000},
      'top_items': [
        {'variant_id': 'v1', 'name': 'Kape 3-in-1', 'qty': 12, 'revenue': 9000},
        {'variant_id': 'v2', 'name': 'Sardinas', 'qty': 2.5, 'revenue': 6000},
      ],
      'utang': {
        'owed': 4600,
        'customers': [
          {'id': 'c1', 'name': 'Aling Rosa', 'balance': 3000},
          {'id': 'c2', 'name': 'Berto', 'balance': 1600},
        ],
      },
    };

Future<void> openReports(WidgetTester tester, {Map<String, dynamic>? data, Object? error}) async {
  await openHome(tester);
  backend.report = data;
  backend.reportError = error;
  await tester.tap(find.byKey(const Key('tab-more'))); // Reports now lives in the More grid
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('tile-reports')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tile-reports')));
  await tester.pumpAndSettle();
}

String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('shows the totals, a bar for every day (empty days too), best sellers and utang', (tester) async {
    await openReports(tester, data: sample());
    expect(text(tester, 'report-net'), '₱150.00');
    expect(text(tester, 'report-txns'), '5 sales');
    expect(text(tester, 'report-profit'), 'Estimated profit: ₱60.00');
    expect(text(tester, 'report-cash'), '₱90.00');
    expect(text(tester, 'report-ewallet'), '₱30.00');
    expect(text(tester, 'report-utang'), '₱30.00');
    for (var i = 0; i < 7; i++) {
      await tester.scrollUntilVisible(find.byKey(Key('day-${day(i)}')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(Key('day-${day(i)}')), findsOneWidget, reason: 'day $i ago is listed');
    }
    await tester.scrollUntilVisible(find.byKey(const Key('top-0')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Kape 3-in-1'), findsOneWidget);
    expect(find.text('12 sold'), findsOneWidget);
    expect(find.text('2.5 sold'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('debtor-1')), 300, scrollable: find.byType(Scrollable).first);
    expect(text(tester, 'report-owed'), 'Owed to you: ₱46.00');
    expect(find.text('Aling Rosa'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the 30-day switch asks for 30 days', (tester) async {
    await openReports(tester, data: sample());
    expect(backend.reportCalls.last.$2.difference(backend.reportCalls.last.$1).inDays, 6);
    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(backend.reportCalls.last.$2.difference(backend.reportCalls.last.$1).inDays, 29);
    await tester.scrollUntilVisible(find.byKey(Key('day-${day(29)}')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(Key('day-${day(29)}')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('offline: the last report is shown with its date; with none, a clear message', (tester) async {
    await openReports(tester, data: sample());
    expect(find.byKey(const Key('report-offline')), findsNothing);

    backend.reportError = Exception('no signal');
    await tester.tap(find.byKey(const Key('report-refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-offline')), findsOneWidget);
    expect(find.textContaining('No signal. Showing the last report from'), findsOneWidget);
    expect(text(tester, 'report-net'), '₱150.00');

    await tester.tap(find.text('30 days')); // never fetched for 30 days
    await tester.pumpAndSettle();
    expect(find.textContaining('Reports need a signal the first time'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a quiet period shows zeros and "no sales"', (tester) async {
    final empty = {
      'days': [],
      'totals': {'net': 0, 'gross': 0, 'discount': 0, 'cogs': 0, 'txns': 0, 'cash': 0, 'ewallet': 0, 'utang': 0},
      'top_items': [],
      'utang': {'owed': 0, 'customers': []},
    };
    await openReports(tester, data: empty);
    expect(text(tester, 'report-net'), '₱0.00');
    expect(find.byKey(const Key('report-profit')), findsNothing, reason: 'no cost, no profit line');
    await tester.scrollUntilVisible(find.text('No sales in this period.'), 300, scrollable: find.byType(Scrollable).first);
    await leave(tester);
  });

  testWidgets('the report says how many sales are not sent yet', (tester) async {
    final store = await openHome(tester);
    backend.report = sample();
    await store.saveCustomer(id: 'c-1', name: 'Rosa', opId: 'o1');
    await tester.tap(find.byKey(const Key('tab-more'))); // Reports now lives in the More grid
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('tile-reports')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tile-reports')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-not-sent')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('cashiers do not see the Reports tile', (tester) async {
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    final b = FakeBackend(signedInAtStart: true)
      ..access = {
        'role': 'cashier',
        'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
      };
    await tester.pumpWidget(App(backend: b, openStore: ({bool safeMode = false}) => store, initialLocale: 'en'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-sell')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-products')), findsOneWidget, reason: 'More is there');
    expect(find.byKey(const Key('tile-reports')), findsNothing);
    await leave(tester);
  });

  testWidgets('expenses come off the profit, but stock purchases do not (they are already in cost of goods)', (tester) async {
    final data = sample()
      ..['expenses'] = {
        'total': 5500,
        'cash': 5500,
        'ewallet': 0,
        'count': 3,
        'by_category': [
          {'category': 'stock_purchase', 'amount': 4000, 'count': 1},
          {'category': 'utilities', 'amount': 1000, 'count': 1},
          {'category': 'transport', 'amount': 500, 'count': 1},
        ],
        'days': [],
      };
    await openReports(tester, data: data);
    expect(text(tester, 'report-profit'), 'Estimated profit: ₱60.00', reason: 'sales minus cost of goods, unchanged');
    expect(text(tester, 'report-expenses'), 'Expenses (not stock): ₱15.00');
    expect(text(tester, 'report-net-profit'), 'Profit after expenses: ₱45.00');
    expect(text(tester, 'report-stock-bought'), 'Stock bought: ₱40.00');
    await leave(tester);
  });

  testWidgets('no expenses, or an older server without them, shows no expense lines', (tester) async {
    await openReports(tester, data: sample());
    expect(find.byKey(const Key('report-net-profit')), findsNothing);
    await leave(tester);
  });
}
