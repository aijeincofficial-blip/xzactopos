import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzactopos_mobile/core/pin.dart';
import 'package:xzactopos_mobile/core/pin_auth.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/receipt_screen.dart';
import 'package:xzactopos_mobile/screens/supervisor_pin.dart';
import 'package:xzactopos_mobile/sync/photo_loader.dart';
import 'package:xzactopos_mobile/sync/store_session.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'sales_store_test.dart' show level, line, posPage, sale;
import 'widget_test.dart' show FakeBackend;

DriftStore _newStore() => DriftStore(AppDatabase(NativeDatabase.memory()));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('LocalStore offline PIN storage', () {
    test('saveOfflinePins and getOfflinePins round-trip per location', () async {
      final store = _newStore();
      await store.ensureTenant('t1', baseCurrency: 'PHP', locationId: 'loc-1');

      final pins = [
        {
          'user_id': '0190a000-0000-7000-8000-000000000001',
          'username': 'supervisor_maria',
          'full_name': 'Maria Santos',
          'role': 'admin',
          'position': 'supervisor',
          'pin_hash': hashPinPbkdf2('1234', 'c2FsdHNhbHRzYWx0MTIz', 1000),
        },
      ];

      await store.saveOfflinePins('loc-1', pins);
      final retrieved = await store.getOfflinePins(locationId: 'loc-1');
      expect(retrieved, hasLength(1));
      expect(retrieved.first['username'], 'supervisor_maria');
      expect(retrieved.first['user_id'], '0190a000-0000-7000-8000-000000000001');

      // Different location has no pins yet
      final other = await store.getOfflinePins(locationId: 'loc-2');
      expect(other, isEmpty);
    });

    test('requeueWithApproval attaches offlineApproval map to outbox op', () async {
      final store = _newStore();
      await store.ensureTenant('t1', baseCurrency: 'PHP', locationId: 'loc-1');

      await store.recordExpense(id: 'e1', amount: 500, category: 'transport', opId: 'o1');
      await store.opFailed('o1', 'approval_required');

      final offlineMap = {
        'approver_id': '0190a000-0000-7000-8000-000000000001',
        'approved_at': '2026-11-09T00:00:00.000Z',
        'action': 'record_expense',
        'ref_id': 'e1',
      };

      await store.requeueWithApproval(opId: 'o1', offlineApproval: offlineMap);

      final ops = await store.nextOps();
      expect(ops, hasLength(1));
      expect(ops.first.attempts, 0);
      expect(ops.first.lastError, isNull);
      expect(ops.first.payload['offline_approval'], offlineMap);
    });

    test('requeueWithApproval throws if neither approvalId nor offlineApproval given', () async {
      final store = _newStore();
      await store.ensureTenant('t1', baseCurrency: 'PHP', locationId: 'loc-1');

      await store.recordExpense(id: 'e1', amount: 500, category: 'transport', opId: 'o1');
      await store.opFailed('o1', 'approval_required');

      expect(() => store.requeueWithApproval(opId: 'o1'), throwsArgumentError);
    });
  });

  group('askSupervisorApproval dialog', () {
    testWidgets('online approval calls approveSupervisorAction', (tester) async {
      final store = _newStore();
      await store.ensureTenant('t1', baseCurrency: 'PHP', locationId: 'loc-1');
      final backend = FakeBackend();
      backend.pinSet = '4321';

      SupervisorApprovalResult? result;

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CatalogScope(
          store: store,
          engine: SyncEngine(store, backend),
          photos: PhotoLoader(store, backend),
          child: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await askSupervisorApproval(
                    ctx,
                    backend,
                    action: 'record_expense',
                    refId: 'e1',
                    locationId: 'loc-1',
                  );
                },
                child: const Text('Ask'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('approval-pin')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('approval-pin')), '4321');
      await tester.tap(find.byKey(const Key('approval-ok')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.isOffline, isFalse);
      expect(result!.approvalId, isNotNull);
      expect(backend.approvalCalls, [('record_expense', 'e1')]);
    });

    testWidgets('offline fallback verifies against cached supervisor PIN', (tester) async {
      final store = _newStore();
      await store.ensureTenant('t1', baseCurrency: 'PHP', locationId: 'loc-1');

      // Cache an offline supervisor hash (PIN 8888)
      await store.saveOfflinePins('loc-1', [
        {
          'user_id': '0190a000-0000-7000-8000-000000000009',
          'username': 'boss_ken',
          'full_name': 'Ken Tanaka',
          'role': 'admin',
          'position': 'manager',
          'pin_hash': hashPinPbkdf2('8888', 'c2FsdHNhbHRzYWx0MTIz', 1000),
        },
      ]);

      final backend = FakeBackend();
      backend.offline = true; // Simulates no signal

      SupervisorApprovalResult? result;

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CatalogScope(
          store: store,
          engine: SyncEngine(store, backend),
          photos: PhotoLoader(store, backend),
          child: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await askSupervisorApproval(
                    ctx,
                    backend,
                    action: 'void_sale',
                    refId: 's1',
                    locationId: 'loc-1',
                  );
                },
                child: const Text('Ask'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();

      // Enter wrong PIN first
      await tester.enterText(find.byKey(const Key('approval-pin')), '9999');
      await tester.tap(find.byKey(const Key('approval-ok')));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.text('Wrong PIN. Try again.'), findsOneWidget);

      // Enter correct supervisor PIN (8888)
      await tester.enterText(find.byKey(const Key('approval-pin')), '8888');
      await tester.tap(find.byKey(const Key('approval-ok')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.isOffline, isTrue);
      expect(result!.approvalId, isNull);
      expect(result!.approvedBy, '0190a000-0000-7000-8000-000000000009');
      expect(result!.offlineApproval!['approver_id'], '0190a000-0000-7000-8000-000000000009');
      expect(result!.offlineApproval!['action'], 'void_sale');
      expect(result!.offlineApproval!['ref_id'], 's1');
      expect(result!.offlineApproval!['approved_at'], isNotNull);
    });
  });

  group('Offline PIN sync and end-to-end cashier overrides (F-06)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SupervisorPinStorage.resetInMemoryFailures();
    });

    test('SyncEngine syncNow automatically caches offline PIN hashes and pushes return_sale_items', () async {
      const p1 = '0190a000-0000-7000-8000-000000000001';
      const v1 = '0190a000-0000-7000-8000-0000000000a1';
      final store = _newStore();
      await store.ensureTenant('t1', baseCurrency: 'PHP', locationId: 'loc-sync-1');
      await store.applyPull(pullPage(
        products: [serverProduct(p1, 'Sardines')],
        variants: [serverVariant(v1, p1)],
        prices: [serverPrice(v1, 3000)],
      ));
      await store.applyPullPos(posPage(levels: [level(v1, 10, '2026-11-08T00:00:00+00:00')]));

      final backend = _OfflinePinSyncBackend(
        offlinePins: [
          {
            'user_id': '0190a000-0000-7000-8000-000000000077',
            'username': 'sara_sup',
            'full_name': 'Sara Supervisor',
            'role': 'admin',
            'position': 'supervisor',
            'pin_hash': hashPinPbkdf2('7777', 'c2FsdHNhbHRzYWx0MTIz', 1000),
          },
        ],
      );
      final engine = SyncEngine(store, backend);

      // 1. Initial online sync pulls and caches offline PINs before any PIN dialog opens
      await engine.syncNow();
      final cachedInDrift = await store.getOfflinePins(locationId: 'loc-sync-1');
      expect(cachedInDrift, hasLength(1));
      expect(cachedInDrift.first['user_id'], '0190a000-0000-7000-8000-000000000077');

      // 2. Commit a sale and a partial return with offlineApproval, then push via SyncEngine
      await store.commitSale(
        sale('s-sync-1', [line(v1, 2, 3000, name: 'Sardines')], const [PaymentDraft('cash', 6000)]),
        opId: 'op-sale-1',
      );
      await store.returnSaleItems(
        's-sync-1',
        items: const [SaleReturnLine(variantId: v1, qty: 1)],
        refundMethod: 'cash',
        offlineApproval: const {
          'approver_id': '0190a000-0000-7000-8000-000000000077',
          'approved_at': '2026-11-12T00:00:00Z',
          'action': 'void_sale',
          'ref_id': 's-sync-1',
        },
        opId: 'op-ret-1',
      );

      await engine.syncNow();
      final returnPush = backend.pushedOps.firstWhere((o) => o['kind'] == 'return_sale_items');
      expect((returnPush['payload'] as Map)['offline_approval'], isNotNull);
      expect(await store.nextOps(), isEmpty);
      expect(await store.failedOps(), isEmpty);
    });

    testWidgets('ReceiptScreen cashier cancel sale offline attaches offline_approval to void_sale op', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      const p1 = '0190a000-0000-7000-8000-000000000001';
      const v1 = '0190a000-0000-7000-8000-0000000000a1';
      const loc = 'loc-void-offline';
      final store = _newStore();
      await store.ensureTenant('t1', baseCurrency: 'PHP', locationId: loc);
      await store.applyPull(pullPage(
        products: [serverProduct(p1, 'Kape')],
        variants: [serverVariant(v1, p1)],
        prices: [serverPrice(v1, 5000)],
      ));
      await store.applyPullPos(posPage(levels: [level(v1, 10, '2026-11-08T00:00:00+00:00')]));
      await store.commitSale(
        sale('sale-void-1', [line(v1, 1, 5000, name: 'Kape')], const [PaymentDraft('cash', 5000)]),
        opId: 'op-sale-void-1',
      );

      // Seed offline PINs in Drift only (proving showSupervisorPinDialog reads Drift cache too)
      await store.saveOfflinePins(loc, [
        {
          'user_id': '0190a000-0000-7000-8000-000000000088',
          'username': 'maria_mgr',
          'full_name': 'Maria Manager',
          'role': 'admin',
          'position': 'manager',
          'pin_hash': hashPinPbkdf2('2580', 'c2FsdHNhbHRzYWx0MTIz', 1000),
        },
        {
          'user_id': '0190a000-0000-7000-8000-000000000099',
          'username': 'juan_cashier',
          'full_name': 'Juan Cashier',
          'role': 'cashier',
          'position': null,
          'pin_hash': hashPinPbkdf2('4444', 'c2FsdHNhbHRzYWx0MTIz', 1000),
        },
      ]);

      final backend = FakeBackend();
      backend.offline = true;

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: CatalogScope(
          store: store,
          engine: SyncEngine(store, backend),
          photos: PhotoLoader(store, backend),
          role: 'cashier',
          child: const ReceiptScreen(saleId: 'sale-void-1'),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Cancel sale on ReceiptScreen -> confirm dialog
      await tester.scrollUntilVisible(
        find.byKey(const Key('cancel-sale')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('cancel-sale')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-sale-yes')));
      await tester.pumpAndSettle();

      // Cashier own PIN 4444 is rejected
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('keypad-4')));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('supervisor-pin-error')), findsOneWidget);

      // Manager PIN 2580 succeeds offline
      for (final d in ['2', '5', '8', '0']) {
        await tester.tap(find.byKey(Key('keypad-$d')));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();

      final ops = await store.nextOps();
      final voidOp = ops.firstWhere((o) => o.kind == 'void_sale');
      final off = voidOp.payload['offline_approval'] as Map<String, dynamic>?;
      expect(off, isNotNull);
      expect(off!['approver_id'], '0190a000-0000-7000-8000-000000000088');
      expect(off['action'], 'void_sale');
      expect(off['ref_id'], 'sale-void-1');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await store.close();
    });
  });
}

class _OfflinePinSyncBackend extends FakeBackend {
  _OfflinePinSyncBackend({required this.offlinePins});

  final List<Map<String, dynamic>> offlinePins;
  final List<Map<String, dynamic>> pushedOps = [];

  @override
  Future<List<Map<String, dynamic>>> pullOfflinePins({String? locationId}) async => offlinePins;

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    pushedOps.addAll(ops);
    return [
      for (final o in ops)
        {
          'op_id': o['op_id'],
          'status': 'ok',
          'result': {'applied_at': '2026-11-12T00:00:01Z'},
        },
    ];
  }
}
