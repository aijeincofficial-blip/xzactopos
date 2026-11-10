import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/backend.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'sales_store_test.dart' show level, posPage;
import 'widget_test.dart' show FakeBackend;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

class _ApprovalFakeBackend extends FakeBackend {
  _ApprovalFakeBackend() : super(signedInAtStart: true);

  final List<Map<String, dynamic>> approvedActions = [];

  @override
  Future<ApprovalResult> approveSupervisorAction({
    required String action,
    required String refId,
    required String pin,
    String? locationId,
    String? approverId,
  }) async {
    if (pin == '1234') {
      approvedActions.add({
        'action': action,
        'ref_id': refId,
        'location_id': locationId,
        'approver_id': approverId,
      });
      return ApprovalResult.ok(
        approvalId: 'appr-test-1234',
        approvedBy: 'Boss Supervisor',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );
    }
    return const ApprovalResult.refused('pin_wrong');
  }
}

Future<DriftStore> openPayWithCashier(WidgetTester tester, {FakeBackend? backend}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final store = DriftStore(AppDatabase(NativeDatabase.memory()));
  final b = backend ?? FakeBackend(signedInAtStart: true);
  b.access = {
    'tenant': {'id': 't1', 'name': 'Tindahan ni Nena', 'base_currency': 'PHP'},
    'role': 'cashier',
  };
  await tester.pumpWidget(App(backend: b, openStore: ({bool safeMode = false}) => store, initialLocale: 'en'));
  await tester.pumpAndSettle();

  await store.applyPull(pullPage(
    products: [serverProduct(_p1, 'Corned Beef')],
    variants: [serverVariant(_v1, _p1, barcode: '4800016644801')],
    prices: [serverPrice(_v1, 10000)], // 100.00
  ));
  await store.applyPullPos(posPage(levels: [level(_v1, 10, '2026-11-08T00:00:00+00:00')]));
  await tester.tap(find.byKey(const Key('tile-sell')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('tile-$_p1')));
  await tester.pump();

  await tester.tap(find.byKey(const Key('pay-button')));
  await tester.pumpAndSettle();
  return store;
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

  testWidgets('Cashier requires supervisor PIN for discount, approves and commits sale with approvalId', (tester) async {
    final backend = _ApprovalFakeBackend();
    final store = await openPayWithCashier(tester, backend: backend);

    // Expand discount tile
    await tester.tap(find.byIcon(Icons.local_offer_outlined));
    await tester.pumpAndSettle();

    // Enter discount: 20.00
    await tester.enterText(find.byKey(const Key('discount-field')), '20.00');
    await tester.pumpAndSettle();

    // Supervisor override banner and button should appear for cashier
    expect(find.byKey(const Key('discount-supervisor-required')), findsOneWidget);
    expect(find.byKey(const Key('discount-approve-btn')), findsOneWidget);

    // Scroll so discount-approve-btn is fully above the bottom amount pad
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Tap Approve button to open Supervisor PIN dialog
    await tester.tap(find.byKey(const Key('discount-approve-btn')));
    await tester.pumpAndSettle();

    // Keypad dialog should appear
    expect(find.byKey(const Key('keypad-1')), findsOneWidget);

    // Enter correct PIN: 1234
    await tester.tap(find.byKey(const Key('keypad-1')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('keypad-2')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('keypad-3')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('keypad-4')));
    await tester.pumpAndSettle();

    // Verify backend received approval request
    expect(backend.approvedActions.length, 1);
    expect(backend.approvedActions.first['action'], 'sale_discount');

    // Dialog closes and green approved badge is shown
    expect(find.byKey(const Key('discount-approved-badge')), findsOneWidget);
    expect(find.textContaining('Boss Supervisor'), findsOneWidget);

    // Now tap Finish to complete checkout
    await tester.tap(find.byKey(const Key('pay-done')));
    await tester.pumpAndSettle();

    // Receipt screen reached
    expect(find.byKey(const Key('receipt-no')), findsOneWidget);

    // Verify operation payload contains approval_id
    final ops = await store.nextOps();
    final saleOp = ops.firstWhere((o) => o.kind == 'record_sale');
    expect(saleOp.payload['approval_id'], 'appr-test-1234');
    expect(saleOp.payload['discount'], 2000);
    expect(saleOp.payload['total'], 8000);

    await leave(tester);
  });
}
