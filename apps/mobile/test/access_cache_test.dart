import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/core/access_cache.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/sync/store_session.dart';

import 'widget_test.dart' show FakeBackend;

/// A backend whose access call can be made to fail like a phone with no signal (or like a server that answers "no").
class AccessBackend extends FakeBackend {
  AccessBackend() : super(signedInAtStart: true);
  Object? accessError;
  int accessCalls = 0;

  @override
  Future<Map<String, dynamic>?> myAccess() async {
    accessCalls++;
    if (accessError != null) throw accessError!;
    return access;
  }
}

Map<String, dynamic> accessOf({String? role, String user = 'u1'}) => {
      'user_id': user,
      'role': ?role,
      'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
    };

const _noSignal = SocketException('Failed host lookup');

Future<void> start(WidgetTester tester, AccessBackend backend) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  // a new database each time, like the app: the previous session closes its own
  await tester.pumpWidget(App(
      backend: backend, openStore: ({bool safeMode = false}) => DriftStore(AppDatabase(NativeDatabase.memory())), initialLocale: 'en'));
  await tester.pumpAndSettle();
}

Future<void> leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('the saved copy', () {
    test('is given back to the same user only', () async {
      final c = MemoryAccessCache();
      await c.write('u1', {'role': 'warehouse'});
      expect(await c.read('u1'), {'role': 'warehouse'});
      expect(await c.read('u2'), isNull);
      expect(await c.read(null), isNull);
    });

    test('is too old after 7 days, and not trusted when dated in the future', () async {
      var now = DateTime.utc(2026, 11, 9, 12);
      final c = MemoryAccessCache(now: () => now);
      await c.write('u1', {'role': 'admin'});
      now = DateTime.utc(2026, 11, 16, 11, 59);
      expect(await c.read('u1'), isNotNull, reason: 'a minute short of 7 days');
      now = DateTime.utc(2026, 11, 16, 12, 1);
      expect(await c.read('u1'), isNull, reason: 'a minute past 7 days');
      now = DateTime.utc(2026, 11, 9, 11, 0);
      expect(await c.read('u1'), isNull, reason: 'the clock went back an hour');
    });

    test('is replaced by the next write and gone after clear', () async {
      final c = MemoryAccessCache();
      await c.write('u1', {'role': 'cashier'});
      await c.write('u1', {'role': 'admin'});
      expect(await c.read('u1'), {'role': 'admin'});
      await c.clear();
      expect(await c.read('u1'), isNull);
    });

    test('a damaged copy is ignored, not an error', () {
      expect(decodeAccessCache('not json', 'u1', DateTime.now()), isNull);
      expect(decodeAccessCache(jsonEncode({'user_id': 'u1'}), 'u1', DateTime.now()), isNull);
    });
  });

  testWidgets('a phone that has been online opens with no signal', (tester) async {
    final b = AccessBackend()..access = accessOf();
    await start(tester, b);
    expect(find.byKey(const Key('tile-sell')), findsOneWidget);
    await leave(tester);

    b.accessError = _noSignal;
    await start(tester, b);
    expect(find.byKey(const Key('tile-sell')), findsOneWidget, reason: 'opened from the saved copy');
    await leave(tester);
  });

  testWidgets('a warehouse clerk opens on the warehouse home with no signal', (tester) async {
    final b = AccessBackend()..access = accessOf(role: 'warehouse');
    await start(tester, b);
    await leave(tester);
    b.accessError = _noSignal;
    await start(tester, b);
    expect(find.byKey(const Key('tab-receive')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a phone that never had the access still shows the error', (tester) async {
    final b = AccessBackend()
      ..access = accessOf()
      ..accessError = _noSignal;
    await start(tester, b);
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.byKey(const Key('tile-sell')), findsNothing);
    await leave(tester);
  });

  testWidgets('a copy saved for another user is never used', (tester) async {
    await accessCache.write('someone-else', accessOf(user: 'someone-else'));
    final b = AccessBackend()
      ..access = accessOf()
      ..accessError = _noSignal;
    await start(tester, b);
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a copy older than 7 days is not used', (tester) async {
    var now = DateTime.now();
    accessCache = MemoryAccessCache(now: () => now);
    await accessCache.write('u1', accessOf());
    now = now.add(const Duration(days: 8));
    final b = AccessBackend()
      ..access = accessOf()
      ..accessError = _noSignal;
    await start(tester, b);
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('when the server answers with an error the saved copy is not used', (tester) async {
    await accessCache.write('u1', accessOf());
    final b = AccessBackend()
      ..access = accessOf()
      ..accessError = const PostgrestException(message: 'boom', code: '500');
    await start(tester, b);
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.byKey(const Key('tile-sell')), findsNothing);
    await leave(tester);
  });

  testWidgets('when the server says there is no business, the saved copy is dropped', (tester) async {
    await accessCache.write('u1', accessOf());
    final b = AccessBackend(); // access stays null: signed in, no business
    await start(tester, b);
    expect(await accessCache.read('u1'), isNull);
    await leave(tester);
  });

  testWidgets('signing out drops the saved copy', (tester) async {
    final b = AccessBackend()..access = accessOf();
    await start(tester, b);
    expect(await tester.runAsync(() => accessCache.read('u1')), isNotNull);
    await b.signOut();
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => accessCache.read('u1')), isNull);
    await leave(tester);
  });

  testWidgets('running on the saved copy, the app asks again and switches to what the server says', (tester) async {
    await accessCache.write('u1', accessOf(role: 'cashier'));
    final b = AccessBackend()
      ..access = accessOf(role: 'warehouse')
      ..accessError = _noSignal;
    await start(tester, b);
    expect(find.byKey(const Key('tile-sell')), findsOneWidget, reason: 'the saved role until the server is reached');
    final calls = b.accessCalls;

    await tester.pump(const Duration(seconds: 61));
    expect(b.accessCalls, greaterThan(calls), reason: 'it tried again');
    expect(find.byKey(const Key('tile-sell')), findsOneWidget, reason: 'still no signal');

    b.accessError = null;
    await tester.pump(const Duration(seconds: 61));
    // the new session opens the device database in real time
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('tab-receive')), findsOneWidget, reason: 'the server says warehouse clerk now');
    expect(find.byKey(const Key('tile-sell')), findsNothing);
    final scope = CatalogScope.of(tester.element(find.byKey(const Key('tab-receive'))));
    expect(scope.role, 'warehouse');
    expect(scope.engine.pullsWarehouse, isTrue, reason: 'the sync engine was rebuilt for the new role, not kept from the saved one');
    expect(scope.engine.pullsStore, isFalse);
    final stopped = b.accessCalls;
    await tester.pump(const Duration(seconds: 130));
    expect(b.accessCalls, stopped, reason: 'it stops asking once the server has answered');
    await leave(tester);
  });
}
