import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzactopos_mobile/backend.dart';
import 'package:xzactopos_mobile/core/pin_auth.dart';
import 'package:xzactopos_mobile/core/supervisor_pin_dialog.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';

import 'widget_test.dart' show FakeBackend;

class _FakeSupervisorBackend extends FakeBackend {
  bool onlineApproveSucceeds = true;
  String? lastAction;
  String? lastPin;

  @override
  Future<ApprovalResult> approveSupervisorAction({
    required String action,
    required String refId,
    required String pin,
    String? locationId,
    String? approverId,
  }) async {
    lastAction = action;
    lastPin = pin;
    if (onlineApproveSucceeds) {
      return ApprovalResult.ok(
        approvalId: 'appr-uuid-1234',
        approvedBy: 'Boss Maria',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    } else {
      return const ApprovalResult.refused('pin_wrong');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullOfflinePins({String? locationId}) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('showSupervisorPinDialog enters digits on keypad and returns online approval', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final backend = _FakeSupervisorBackend();
    SupervisorApprovalResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showSupervisorPinDialog(
                  context,
                  backend: backend,
                  action: 'void_sale',
                  refId: 'sale-99',
                  locationId: 'loc-1',
                );
              },
              child: const Text('Open PIN'),
            ),
          ),
        ),
      ),
    );

    // Open PIN dialog
    await tester.tap(find.text('Open PIN'));
    await tester.pumpAndSettle();

    // Keypad digits 1, 2, 3, 4
    await tester.tap(find.byKey(const Key('keypad-1')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('keypad-2')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('keypad-3')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('keypad-4')));
    await tester.pumpAndSettle();

    // Verify backend received call
    expect(backend.lastAction, 'void_sale');
    expect(backend.lastPin, '1234');
    expect(result, isNotNull);
    expect(result!.approvalId, 'appr-uuid-1234');
    expect(result!.approvedBy, 'Boss Maria');
    expect(result!.isOffline, isFalse);
  });

  testWidgets('showSupervisorPinDialog falls back to offline cached PBKDF2 hash on network error', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const locId = 'loc-test-store';

    // Seed offline pin
    final saltB64 = 'c2FsdHNhbHRzYWx0MTIz';
    final hash = PinCrypto.hashPin('8888', saltB64, iterations: 1000);
    await SupervisorPinStorage.savePins(locId, [
      SupervisorPin(
        userId: 'usr-offline-super',
        displayName: 'Offline Supervisor',
        role: 'manager',
        pinHash: hash,
      ),
    ]);

    // Backend that throws network exception
    final backend = _ThrowingSupervisorBackend();
    SupervisorApprovalResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showSupervisorPinDialog(
                  context,
                  backend: backend,
                  action: 'void_sale',
                  refId: 'sale-offline-1',
                  locationId: locId,
                );
              },
              child: const Text('Open PIN'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open PIN'));
    await tester.pumpAndSettle();

    // Enter matching offline PIN 8888
    await tester.tap(find.byKey(const Key('keypad-8')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('keypad-8')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('keypad-8')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('keypad-8')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isOffline, isTrue);
    expect(result!.offlineApproval!['approver_id'], 'usr-offline-super');
    expect(result!.offlineApproval!['action'], 'void_sale');
    expect(result!.offlineApproval!['ref_id'], 'sale-offline-1');
  });
}

class _ThrowingSupervisorBackend extends FakeBackend {
  @override
  Future<ApprovalResult> approveSupervisorAction({
    required String action,
    required String refId,
    required String pin,
    String? locationId,
    String? approverId,
  }) async {
    throw Exception('No network connectivity');
  }

  @override
  Future<List<Map<String, dynamic>>> pullOfflinePins({String? locationId}) async => [];
}
