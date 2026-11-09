import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/pin.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/supervisor_pin.dart';
import 'package:xzactopos_mobile/sync/photo_loader.dart';
import 'package:xzactopos_mobile/sync/store_session.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

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
}
