import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/backend.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';

DriftStore memoryStore({bool safeMode = false}) => DriftStore(AppDatabase(NativeDatabase.memory()));

class FakeBackend implements Backend {
  FakeBackend({this.signedInAtStart = false});
  bool signedInAtStart;
  Map<String, dynamic>? access;
  final calls = <Map<String, String>>[];
  final _ctrl = StreamController<bool>.broadcast();

  @override
  bool get signedIn => signedInAtStart;
  @override
  Stream<bool> get signedInChanges => _ctrl.stream;
  @override
  Future<void> signIn(String email, String password) async => _ctrl.add(true);
  @override
  Future<bool> signUp(String email, String password) async {
    _ctrl.add(true);
    return true;
  }

  @override
  Future<void> signOut() async => _ctrl.add(false);
  final resetsSentTo = <String>[];
  final passwordsSet = <String>[];
  Object? resetError;
  final recovery = StreamController<void>.broadcast();
  @override
  Future<void> sendPasswordReset(String email) async {
    if (resetError != null) throw resetError!;
    resetsSentTo.add(email);
  }
  @override
  Future<void> updatePassword(String newPassword) async => passwordsSet.add(newPassword);
  @override
  Stream<void> get passwordRecovery => recovery.stream;
  @override
  Future<Map<String, dynamic>?> myAccess() async => access;
  Map<String, dynamic>? report;
  Object? reportError;
  final reportCalls = <(DateTime, DateTime)>[];
  @override
  Future<Map<String, dynamic>> reportSummary(DateTime from, DateTime to) async {
    reportCalls.add((from, to));
    if (reportError != null) throw reportError!;
    return report ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async => {};
  @override
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullExpenses(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullDayCloses(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async => {};
  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async =>
      [for (final o in ops) {'op_id': o['op_id'], 'status': 'ok', 'result': <String, dynamic>{}}];

  // Supervisor PIN, like set_my_pin / approve_supervisor_action. The fake keeps the PIN in memory only (as the server
  // keeps its hash); calls are recorded WITHOUT the PIN so tests can check nothing else ever saw it.
  String? pinSet;
  bool offline = false;
  final approvalCalls = <(String action, String refId)>[];
  var _approvals = 0;
  @override
  Future<PinResult> setMyPin(String newPin, {String? currentPin}) async {
    if (offline) throw Exception('no signal');
    if (!RegExp(r'^[0-9]{4,8}$').hasMatch(newPin)) return const PinResult.refused('pin_invalid');
    if (pinSet != null && currentPin == null) return const PinResult.refused('pin_required');
    if (pinSet != null && currentPin != pinSet) return const PinResult.refused('pin_wrong');
    pinSet = newPin;
    return const PinResult.ok();
  }

  @override
  Future<ApprovalResult> approveSupervisorAction({
    required String action,
    required String refId,
    required String pin,
    String? locationId,
    String? approverId,
  }) async {
    if (offline) throw Exception('no signal');
    approvalCalls.add((action, refId));
    if (pinSet == null) return const ApprovalResult.refused('pin_not_set');
    if (pin != pinSet) return const ApprovalResult.refused('pin_wrong');
    _approvals++;
    return ApprovalResult.ok(
      approvalId: '0190a000-0000-7000-8000-${_approvals.toString().padLeft(12, 'f')}',
      approvedBy: approverId ?? 'me',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 12)),
    );
  }

  final pushed = <String>[];
  @override
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload) async => pushed.add('upsert_product');
  @override
  Future<void> archiveProduct(String opId, String productId) async => pushed.add('archive_product');
  final uploaded = <String>[];
  @override
  Future<void> uploadPhoto(String path, Uint8List jpeg) async => uploaded.add(path);
  @override
  Future<Uint8List> downloadPhoto(String path) => Future.error(Exception('no photos in this fake'));

  @override
  Future<void> provisionSoloStore({
    required String tenantId,
    required String locationId,
    required String storeName,
    required String locale,
  }) async {
    calls.add({'tenant': tenantId, 'location': locationId, 'name': storeName, 'locale': locale});
    access = {
      'tenant': {'id': tenantId, 'name': storeName, 'base_currency': 'PHP'},
    };
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('signed-in user with no store names it and lands on Home', (tester) async {
    final backend = FakeBackend(signedInAtStart: true);
    await tester.pumpWidget(App(backend: backend, openStore: memoryStore));
    await tester.pumpAndSettle();

    // Filipino is the default language
    expect(find.text('Ano ang pangalan ng tindahan mo?'), findsOneWidget);

    // Empty name is refused
    await tester.tap(find.text('Simulan ang pagbebenta'));
    await tester.pump();
    expect(find.text('Pakisulat po ito'), findsOneWidget);
    expect(backend.calls, isEmpty);

    await tester.enterText(find.byType(TextFormField), '  Aling Nena  ');
    await tester.tap(find.text('Simulan ang pagbebenta'));
    await tester.pumpAndSettle();

    expect(backend.calls, hasLength(1));
    expect(backend.calls.single['name'], 'Aling Nena');
    expect(backend.calls.single['locale'], 'fil');
    expect(backend.calls.single['tenant']!.length, 36); // client-made UUID
    expect(find.text('Maligayang pagdating, Aling Nena!'), findsOneWidget);
    expect(find.text('Wala pang produkto sa phone na ito'), findsOneWidget);

    // leave the session so the store closes and sync timers stop
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('language switch changes the screen text', (tester) async {
    await tester.pumpWidget(App(backend: FakeBackend(signedInAtStart: true), openStore: memoryStore));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('Name your store'), findsOneWidget);
  });

  testWidgets('signed-out user sees the sign-up form', (tester) async {
    await tester.pumpWidget(App(backend: FakeBackend(), openStore: memoryStore));
    await tester.pumpAndSettle();
    expect(find.text('Gumawa ng account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
