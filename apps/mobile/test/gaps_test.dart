import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/backend.dart' show isAuthExpired;
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage;
import 'products_test.dart' show leave;
import 'widget_test.dart' show FakeBackend;

const _v1 = '0190a000-0000-7000-8000-0000000000a1';

SaleDraft sale(String id) => SaleDraft(
      id: id,
      soldAt: DateTime.now(),
      lines: const [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: 1000)],
      payments: const [PaymentDraft('cash', 1000)],
    );

/// Survives the session closing it on a retry, like opening the same database file again would.
class KeepOpenStore extends DriftStore {
  KeepOpenStore() : super(AppDatabase(NativeDatabase.memory()));
  @override
  Future<void> close() async {}
}

class AuthFailApi implements SyncApi {
  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async => throw const AuthExpired();
  @override
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async => pullPage();
  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async => throw const AuthExpired();
  @override
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload) async => throw const AuthExpired();
  @override
  Future<void> archiveProduct(String opId, String productId) async {}
  @override
  Future<void> uploadPhoto(String path, Uint8List jpeg) async {}
  @override
  Future<Uint8List> downloadPhoto(String path) async => Uint8List(0);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('B4: the receipt follows the sending state', () {
    test('pending turns off by itself once the sale is confirmed', () async {
      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      await store.ensureTenant('t', baseCurrency: 'PHP');
      await store.commitSale(sale('s1'), opId: 'op1');
      final seen = <bool>[];
      final sub = store.watchSale('s1').listen((d) => seen.add(d!.summary.pending));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await store.opDone('op1');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(seen.first, isTrue);
      expect(seen.last, isFalse);
      await sub.cancel();
      await store.close();
    });
  });

  group('A5: unsent changes are never thrown away by a business switch', () {
    late KeepOpenStore store;
    setUp(() async {
      store = KeepOpenStore();
      await store.ensureTenant('t0', baseCurrency: 'PHP');
      await store.commitSale(sale('s1'), opId: 'op1');
    });

    test('another business is refused while ops are waiting, same business is fine', () async {
      expect(await store.ensureTenant('t0', baseCurrency: 'PHP'), isFalse);
      await expectLater(store.ensureTenant('t1', baseCurrency: 'PHP'), throwsA(isA<UnsentChangesException>().having((e) => e.count, 'count', 1)));
      expect(await store.getSale('s1'), isNotNull, reason: 'nothing was wiped');
    });

    test('once everything is sent, or the user discards, the switch clears the device', () async {
      await store.ensureTenant('t0', baseCurrency: 'PHP');
      expect(await store.ensureTenant('t1', baseCurrency: 'PHP', discardUnsent: true), isTrue);
      expect(await store.getSale('s1'), isNull);

      await store.commitSale(sale('s2'), opId: 'op2');
      await store.opDone('op2');
      expect(await store.ensureTenant('t2', baseCurrency: 'PHP'), isTrue, reason: 'nothing unsent, so no question');
    });

    testWidgets('the app explains it and offers sign out or discard', (tester) async {
      final backend = FakeBackend(signedInAtStart: true)
        ..access = {
          'tenant': {'id': 't-other', 'name': 'Ibang Tindahan', 'base_currency': 'PHP'},
        };
      await tester.pumpWidget(App(backend: backend, openStore: ({bool safeMode = false}) => store, initialLocale: 'en'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unsent-body')), findsOneWidget);
      expect(find.textContaining('1 change from another business'), findsOneWidget);
      expect(find.byKey(const Key('tile-sell')), findsNothing);

      await tester.tap(find.byKey(const Key('unsent-discard')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tile-sell')), findsOneWidget);
      expect(await store.getSale('s1'), isNull);
      await leave(tester);
    });
  });

  group('A3: an ended session is not "offline"', () {
    test('the engine asks for a sign-in and keeps the queue', () async {
      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      await store.ensureTenant('t', baseCurrency: 'PHP');
      await store.commitSale(sale('s1'), opId: 'op1');
      final engine = SyncEngine(store, AuthFailApi());
      await engine.syncNow();
      expect(engine.status.value.phase, SyncPhase.needsSignIn);
      expect((await store.nextOps()).map((o) => o.opId), ['op1']);
      engine.dispose();
      await store.close();
    });

    test('which server answers count as an ended session', () {
      expect(isAuthExpired('PGRST301', 'x'), isTrue);
      expect(isAuthExpired(null, 'JWT expired'), isTrue);
      expect(isAuthExpired('22023', 'bad value'), isFalse);
      expect(isAuthExpired('42501', 'not allowed'), isFalse);
    });
  });
}
