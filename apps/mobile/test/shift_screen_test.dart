import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/core/export.dart';
import 'package:xzactopos_mobile/core/shift_printer.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/shift_models.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';

import 'widget_test.dart' show FakeBackend;

// F-05m: the shift screens: start, X reading, close with the count, Z report, history, sharing.

const _loc = '0190a000-0000-7000-8000-0000000000e1';

class FakeText implements TextSharer {
  final texts = <String>[];
  @override
  Future<void> shareText(String text) async => texts.add(text);
}

class FakeShiftPrinter implements ShiftPrinter {
  final printed = <String>[];
  final shared = <String>[];

  @override
  bool get available => true;

  @override
  Future<void> printShift({
    required String storeName,
    required String currency,
    required String locale,
    required ShiftView shift,
    XReading? xReading,
    required AppLocalizations t,
  }) async {
    printed.add(shift.id);
  }

  @override
  Future<void> shareShiftPdf({
    required String storeName,
    required String currency,
    required String locale,
    required ShiftView shift,
    XReading? xReading,
    required AppLocalizations t,
  }) async {
    shared.add(shift.id);
  }
}

/// A backend that can say what the server thinks the shift's cash should be.
class ShiftBackend extends FakeBackend implements ShiftApi {
  ShiftBackend() : super(signedInAtStart: true);
  int? server;
  final asked = <String>[];

  /// When set, the answer waits for it (the server is slow).
  Completer<int?>? hold;

  @override
  Future<Map<String, dynamic>> pullShifts(Map<String, dynamic>? cursor, {int limit = 100}) async => {'rows': <dynamic>[], 'has_more': false};

  @override
  Future<int?> shiftExpectedNow(String shiftId) async {
    asked.add(shiftId);
    if (hold != null) return hold!.future;
    return server;
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
  late FakeShiftPrinter fakePrinter;

  setUp(() {
    fakePrinter = FakeShiftPrinter();
    shiftPrinter = fakePrinter;
  });

  tearDown(() {
    shiftPrinter = const PdfShiftPrinter();
  });

  testWidgets('the owner and a cashier both find Shift under More; the Sell screen shows whether one is open', (tester) async {
    await openApp(tester);
    expect(find.byKey(const Key('shift-chip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more-shift')), findsOneWidget);
    await leave(tester);

    await openApp(tester, role: 'cashier');
    await tester.tap(find.byKey(const Key('tab-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more-shift')), findsOneWidget, reason: 'a cashier has a shift too');
    await leave(tester);
  });

  testWidgets('with no shift open: start one with the cash in the drawer', (tester) async {
    final store = await openApp(tester);
    await openShiftScreen(tester);
    expect(find.byKey(const Key('shift-none')), findsOneWidget);
    expect(find.byKey(const Key('shift-no-history')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('shift-opening')), '200');
    await tester.tap(find.byKey(const Key('shift-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shift-none')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('shift-expected'))).data, '₱200.00');
    final op = (await store.nextOps()).single;
    expect([op.kind, op.payload['opening_cash']], ['open_shift', 20000]);
    await leave(tester);
  });

  testWidgets('a number that is not an amount is refused and nothing is started', (tester) async {
    final store = await openApp(tester);
    await openShiftScreen(tester);
    await tester.enterText(find.byKey(const Key('shift-opening')), 'abc');
    await tester.tap(find.byKey(const Key('shift-start')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount.'), findsOneWidget);
    expect(await store.nextOps(), isEmpty);
    await leave(tester);
  });

  testWidgets('the X reading shows what explains the cash expected, and sharing it sends the same words', (tester) async {
    final fake = FakeText();
    textSharer = fake;
    addTearDown(() => textSharer = const SystemTextSharer());
    final store = await openApp(tester);
    await store.ensureTenant('t1', baseCurrency: 'PHP', locationId: _loc);
    await store.startShift(id: 'sh-1', cashierId: 'u1', openingCash: 20000, opId: 'op-open');
    await store.recordExpense(id: 'e1', amount: 2500, category: 'utilities', opId: 'o1');
    await store.recordServiceTxn(id: 'v1', kind: 'cash_in', wallet: 'gcash', amount: 2000, fee: 50, opId: 'o2');
    await openShiftScreen(tester);
    expect(tester.widget<Text>(find.byKey(const Key('shift-expected'))).data, '₱195.50');
    expect(tester.widget<Text>(find.byKey(const Key('x-opening'))).data, '₱200.00');
    expect(tester.widget<Text>(find.byKey(const Key('x-paid-out'))).data, '₱25.00');
    expect(tester.widget<Text>(find.byKey(const Key('x-service'))).data, '₱20.50');
    await tester.tap(find.byKey(const Key('shift-share-x')));
    await tester.pump();
    expect(fake.texts.single, contains('Tindahan'));
    expect(fake.texts.single, contains('Opening cash: ₱200.00'));
    expect(fake.texts.single, contains('Cash that should be in the drawer: ₱195.50'));
    await leave(tester);
  });

  testWidgets('closing: the count against the phone\'s figure, then the Z report', (tester) async {
    final store = await openApp(tester);
    await store.startShift(id: 'sh-1', cashierId: 'u1', openingCash: 20000, opId: 'op-open');
    await openShiftScreen(tester);
    await tester.tap(find.byKey(const Key('shift-close')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('close-sheet-source'))).data, 'Figure from this phone');
    await tester.enterText(find.byKey(const Key('close-sheet-counted')), '195');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('close-sheet-diff'))).data, 'Short by ₱5.00');
    await tester.enterText(find.byKey(const Key('close-sheet-note')), 'gave wrong change');
    await tester.tap(find.byKey(const Key('close-sheet-confirm')));
    await tester.pumpAndSettle();
    // the Z report
    expect(find.byKey(const Key('z-slip')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('z-expected'))).data, '₱200.00');
    expect(tester.widget<Text>(find.byKey(const Key('z-counted'))).data, '₱195.00');
    expect(tester.widget<Text>(find.byKey(const Key('z-diff'))).data, 'Short by ₱5.00');
    expect(find.text('gave wrong change'), findsOneWidget);
    final s = (await store.shift('sh-1'))!;
    expect([s.isOpen, s.expectedCash, s.countedCash, s.difference], [false, 20000, 19500, -500]);
    expect((await store.nextOps()).last.kind, 'close_shift');
    await leave(tester);
  });

  testWidgets('a count that is not an amount is refused and the shift stays open', (tester) async {
    final store = await openApp(tester);
    await store.startShift(id: 'sh-1', cashierId: 'u1', opId: 'op-open');
    await openShiftScreen(tester);
    await tester.tap(find.byKey(const Key('shift-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-sheet-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount.'), findsOneWidget);
    expect((await store.shift('sh-1'))!.isOpen, isTrue);
    await leave(tester);
  });

  testWidgets('online, the close uses the server\'s figure when the server knows the shift', (tester) async {
    final b = ShiftBackend()..server = 25000;
    final store = await openApp(tester, backend: b);
    await store.startShift(id: 'sh-1', cashierId: 'u1', openingCash: 20000, opId: 'op-open');
    await store.opDone('op-open'); // the server has it
    await openShiftScreen(tester);
    await tester.tap(find.byKey(const Key('shift-close')));
    await tester.pumpAndSettle();
    expect(b.asked, ['sh-1']);
    expect(tester.widget<Text>(find.byKey(const Key('close-sheet-source'))).data, 'Figure from the server');
    expect(tester.widget<Text>(find.byKey(const Key('close-sheet-expected'))).data, '₱250.00');
    await tester.enterText(find.byKey(const Key('close-sheet-counted')), '250');
    await tester.tap(find.byKey(const Key('close-sheet-confirm')));
    await tester.pumpAndSettle();
    expect((await store.shift('sh-1'))!.expectedCash, 25000);
    await leave(tester);
  });

  testWidgets('a shift the server has not heard of yet is not asked about, and a silent server falls back to the phone', (tester) async {
    final b = ShiftBackend()..server = 25000;
    final store = await openApp(tester, backend: b);
    await store.startShift(id: 'sh-1', cashierId: 'u1', openingCash: 20000, opId: 'op-open'); // still unsent
    await openShiftScreen(tester);
    await tester.tap(find.byKey(const Key('shift-close')));
    await tester.pumpAndSettle();
    expect(b.asked, isEmpty);
    expect(tester.widget<Text>(find.byKey(const Key('close-sheet-source'))).data, 'Figure from this phone');
    await leave(tester);

    final b2 = ShiftBackend(); // server null: it cannot say
    final store2 = await openApp(tester, backend: b2);
    await store2.startShift(id: 'sh-2', cashierId: 'u1', openingCash: 100, opId: 'op-2');
    await store2.opDone('op-2');
    await openShiftScreen(tester);
    await tester.tap(find.byKey(const Key('shift-close')));
    await tester.pumpAndSettle();
    expect(b2.asked, ['sh-2']);
    expect(tester.widget<Text>(find.byKey(const Key('close-sheet-source'))).data, 'Figure from this phone');
    await leave(tester);
  });

  testWidgets('the history lists closed shifts, a tap opens the report, and a different server figure is called out', (tester) async {
    final store = await openApp(tester);
    await store.startShift(id: 'sh-1', cashierId: 'u1', openingCash: 1000, opId: 'op-open', at: DateTime.now().subtract(const Duration(hours: 5)));
    await store.closeShift(id: 'sh-1', countedCash: 900, expectedCash: 1000, opId: 'op-close', at: DateTime.now().subtract(const Duration(hours: 1)));
    await store.shiftOpApplied('op-close', null, result: {'shift_id': 'sh-1', 'server_expected_cash': 1500});
    await openShiftScreen(tester);
    expect(find.byKey(const Key('shift-row-sh-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('shift-row-sh-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('z-diff'))).data, 'Short by ₱1.00');
    expect(find.byKey(const Key('z-server-differs')), findsOneWidget);
    expect(find.textContaining('₱15.00'), findsWidgets);
    await leave(tester);
  });

  testWidgets('the next shift starts from what the last one counted', (tester) async {
    final store = await openApp(tester);
    await store.startShift(id: 'sh-1', cashierId: 'u1', openingCash: 20000, opId: 'op-open', at: DateTime.now().subtract(const Duration(hours: 5)));
    await store.closeShift(id: 'sh-1', countedCash: 19500, expectedCash: 20000, opId: 'op-close', at: DateTime.now().subtract(const Duration(hours: 1)));
    await openShiftScreen(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('shift-opening'))).controller!.text, '195.00');
    await leave(tester);
  });

  testWidgets('while the server is being asked, the close cannot be confirmed yet', (tester) async {
    final b = ShiftBackend()..hold = Completer<int?>();
    final store = await openApp(tester, backend: b);
    await store.startShift(id: 'sh-1', cashierId: 'u1', openingCash: 20000, opId: 'op-open');
    await store.opDone('op-open');
    await openShiftScreen(tester);
    await tester.tap(find.byKey(const Key('shift-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Text>(find.byKey(const Key('close-sheet-source'))).data, 'Checking with the server...');
    expect(tester.widget<FilledButton>(find.byKey(const Key('close-sheet-confirm'))).onPressed, isNull);
    b.hold!.complete(21000);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('close-sheet-confirm'))).onPressed, isNotNull);
    expect(tester.widget<Text>(find.byKey(const Key('close-sheet-expected'))).data, '₱210.00');
    await leave(tester);
  });

  testWidgets('a cashier sees only their own shifts in the history, an admin sees all of them on this phone', (tester) async {
    for (final (role, sees) in [('cashier', false), ('admin', true)]) {
      final store = await openApp(tester, role: role);
      await store.startShift(id: 'theirs', cashierId: 'someone-else', openingCash: 100, opId: 'op-1', at: DateTime.now().subtract(const Duration(hours: 5)));
      await store.closeShift(id: 'theirs', countedCash: 90, expectedCash: 100, opId: 'op-2', at: DateTime.now().subtract(const Duration(hours: 2)));
      await store.startShift(id: 'mine', cashierId: 'u1', openingCash: 100, opId: 'op-3', at: DateTime.now().subtract(const Duration(hours: 1)));
      await store.closeShift(id: 'mine', countedCash: 100, expectedCash: 100, opId: 'op-4', at: DateTime.now().subtract(const Duration(minutes: 10)));
      await openShiftScreen(tester);
      expect(find.byKey(const Key('shift-row-mine')), findsOneWidget, reason: role);
      expect(find.byKey(const Key('shift-row-theirs')), sees ? findsOneWidget : findsNothing, reason: role);
      await leave(tester);
    }
  });

  testWidgets('the shift screen fits a 360 px phone, in Filipino, open and not', (tester) async {
    final store = await openApp(tester, locale: 'fil', size: const Size(945, 2048));
    await openShiftScreen(tester);
    expect(find.text('Simulan ang shift'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await store.startShift(id: 'sh-1', cashierId: 'u1', openingCash: 5000, opId: 'op-open');
    await tester.pumpAndSettle();
    expect(find.text('Isara ang shift'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await leave(tester);
  });

  testWidgets('print and PDF buttons are present on X and Z readings and trigger ShiftPrinter', (tester) async {
    final store = await openApp(tester);
    await store.startShift(id: 'sh-1', cashierId: 'u1', openingCash: 1000, opId: 'op-open');
    await store.opDone('op-open');
    await openShiftScreen(tester);

    // Verify Print and PDF buttons on X reading
    expect(find.byKey(const Key('shift-print-x')), findsOneWidget);
    expect(find.byKey(const Key('shift-pdf-x')), findsOneWidget);

    await tester.tap(find.byKey(const Key('shift-print-x')));
    await tester.pumpAndSettle();
    expect(fakePrinter.printed, contains('sh-1'));

    await tester.tap(find.byKey(const Key('shift-pdf-x')));
    await tester.pumpAndSettle();
    expect(fakePrinter.shared, contains('sh-1'));

    // Close the shift
    await tester.tap(find.byKey(const Key('shift-close')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('close-sheet-counted')), '10.00');
    await tester.tap(find.byKey(const Key('close-sheet-confirm')));
    await tester.pumpAndSettle();

    // Now on ShiftSlipScreen (Z report)
    expect(find.byKey(const Key('z-print')), findsOneWidget);
    expect(find.byKey(const Key('z-pdf')), findsOneWidget);

    await tester.tap(find.byKey(const Key('z-print')));
    await tester.pumpAndSettle();
    expect(fakePrinter.printed, contains('sh-1'));

    await tester.tap(find.byKey(const Key('z-pdf')));
    await tester.pumpAndSettle();
    expect(fakePrinter.shared, contains('sh-1'));

    await leave(tester);
  });

  testWidgets('admin sees other open cashier shifts and can close them as supervisor', (tester) async {
    final store = await openApp(tester, role: 'admin');
    // Start an open shift for someone else
    await store.startShift(
      id: 'sh-other',
      cashierId: 'cashier-maria',
      openingCash: 5000,
      opId: 'op-other',
      at: DateTime.now().subtract(const Duration(hours: 3)),
    );
    await store.opDone('op-other');

    await openShiftScreen(tester);

    // Admin sees the other cashier's open shift
    expect(find.byKey(const Key('shift-other-open-header')), findsOneWidget);
    expect(find.byKey(const Key('shift-open-card-sh-other')), findsOneWidget);
    expect(find.byKey(const Key('shift-supervisor-close-sh-other')), findsOneWidget);

    // Admin can tap close to close the cashier's shift
    await tester.tap(find.byKey(const Key('shift-supervisor-close-sh-other')));
    await tester.pumpAndSettle();

    // The close sheet opens for sh-other
    expect(find.byKey(const Key('close-sheet-counted')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('close-sheet-counted')), '50.00');
    await tester.enterText(find.byKey(const Key('close-sheet-note')), 'Supervisor closed end of day');
    await tester.tap(find.byKey(const Key('close-sheet-confirm')));
    await tester.pumpAndSettle();

    // Lands on Z report
    expect(find.byKey(const Key('z-diff')), findsOneWidget);
    expect(find.text('Supervisor closed end of day'), findsOneWidget);

    await leave(tester);
  });
}
