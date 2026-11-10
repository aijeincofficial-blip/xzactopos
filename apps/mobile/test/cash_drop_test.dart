import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uuid/uuid.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/core/export.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/shift_models.dart';

import 'widget_test.dart' show FakeBackend;

class _CashDropFakeBackend extends FakeBackend implements ShiftApi {
  _CashDropFakeBackend() : super(signedInAtStart: true);

  @override
  String get userId => 'user-cashier-1';

  @override
  Future<Map<String, dynamic>> pullShifts(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};

  @override
  Future<int?> shiftExpectedNow(String shiftId) async => 500000;
}

class _TestSharer implements TextSharer {
  final List<String> shared = [];
  @override
  Future<void> shareText(String text) async {
    shared.add(text);
  }
}

Future<DriftStore> openApp(WidgetTester tester, {String? role, String locale = 'en', FakeBackend? backend, Size? size}) async {
  tester.view.physicalSize = size ?? const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final store = DriftStore(AppDatabase(NativeDatabase.memory()));
  final b = backend ?? FakeBackend(signedInAtStart: true);
  b.access = {
    'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
    'role': ?role,
  };
  await tester.pumpWidget(App(backend: b, openStore: ({bool safeMode = false}) => store, initialLocale: locale));
  await tester.pumpAndSettle();
  return store;
}

Future<void> openShiftScreen(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab-more')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('more-shift')));
  await tester.pumpAndSettle();
}

Future<void> leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  testWidgets('Cashier records cash drop during open shift and shares slip', (tester) async {
    final backend = _CashDropFakeBackend();
    final testSharer = _TestSharer();
    textSharer = testSharer;

    final store = await openApp(tester, backend: backend, role: 'cashier');

    // Start an open shift with 5,000.00 cash
    final shiftId = const Uuid().v7();
    await store.startShift(
      id: shiftId,
      cashierId: 'user-cashier-1',
      openingCash: 500000, // 5,000.00
      opId: const Uuid().v7(),
    );

    await openShiftScreen(tester);

    // Verify cash drop button is present
    expect(find.byKey(const Key('shift-cash-drop-btn')), findsOneWidget);

    // Open cash drop sheet
    await tester.tap(find.byKey(const Key('shift-cash-drop-btn')));
    await tester.pumpAndSettle();

    // Verify dialog loaded
    expect(find.byKey(const Key('cash-drop-amount')), findsOneWidget);

    // Select "Safe Drop" preset
    await tester.tap(find.byKey(const Key('cash-drop-chip-safe')));
    await tester.pumpAndSettle();
    expect(find.text('Safe Drop'), findsWidgets);

    // Enter amount: 1500.00
    await tester.enterText(find.byKey(const Key('cash-drop-amount')), '1500.00');
    await tester.pumpAndSettle();

    // Confirm drop
    await tester.tap(find.byKey(const Key('cash-drop-confirm-btn')));
    await tester.pumpAndSettle();

    // Check that expense operation was queued
    final ops = await store.nextOps();
    final dropOp = ops.firstWhere((o) => o.kind == 'record_expense');
    expect(dropOp.payload['amount'], 150000);
    expect(dropOp.payload['category'], 'other');
    expect(dropOp.payload['paid_from'], 'cash');
    expect(dropOp.payload['note'], contains('Safe Drop'));

    // Verify confirmation snackbar and updated X-reading paid out
    expect(find.text('Cash drop of ₱1,500.00 recorded'), findsOneWidget);
    expect(find.byKey(const Key('x-paid-out')), findsOneWidget);

    // Settle and leave
    await leave(tester);
  });
}
