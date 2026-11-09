import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/staff_models.dart';

import 'widget_test.dart' show FakeBackend;

// Staff on the phone: the list, adding a cashier, switching a person off, clearing a PIN. Online only.

class StaffBackend extends FakeBackend implements StaffApi {
  StaffBackend() : super(signedInAtStart: true);
  var people = <StaffMember>[
    const StaffMember(userId: 'u1', username: 'ana', fullName: 'Ana Owner', role: 'superadmin', active: true, stores: ['Main']),
    const StaffMember(userId: 'u2', username: 'pia', fullName: 'Pia Cruz', role: 'cashier', active: true, stores: ['Main']),
  ];
  var stores = <StaffStore>[const StaffStore('s1', 'Main')];
  Object? failWith;
  final created = <Map<String, String>>[];
  final activeCalls = <String>[];
  final pinCalls = <String>[];

  @override
  Future<List<StaffMember>> listStaff() async {
    if (failWith != null) throw failWith!;
    return List.of(people);
  }

  @override
  Future<List<StaffStore>> listStores() async => stores;

  @override
  Future<String> createCashier({required String username, required String fullName, required String password, required String locationId}) async {
    if (failWith != null) throw failWith!;
    created.add({'username': username, 'name': fullName, 'password': password, 'store': locationId});
    people = [...people, StaffMember(userId: 'n${created.length}', username: username, fullName: fullName, role: 'cashier', active: true)];
    return 'n${created.length}';
  }

  @override
  Future<void> setActive(String userId, bool active) async {
    activeCalls.add('$userId:$active');
    if (failWith != null) throw failWith!;
    people = [
      for (final p in people)
        if (p.userId == userId)
          StaffMember(userId: p.userId, username: p.username, fullName: p.fullName, role: p.role, active: active, stores: p.stores)
        else
          p,
    ];
  }

  @override
  Future<void> clearPin(String userId) async {
    pinCalls.add(userId);
  }
}

Future<StaffBackend> openStaff(WidgetTester tester, {String? role = 'superadmin', StaffBackend? backend, String locale = 'en'}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final store = DriftStore(AppDatabase(NativeDatabase.memory()));
  final b = backend ?? StaffBackend();
  b.access = {
    'user_id': 'u1',
    'tenant': {'id': 't1', 'name': 'Tindahan', 'slug': 'tindahan', 'base_currency': 'PHP'},
    'role': ?role,
  };
  await tester.pumpWidget(App(backend: b, openStore: ({bool safeMode = false}) => store, initialLocale: locale));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tab-more')));
  await tester.pumpAndSettle();
  if (find.byKey(const Key('more-staff')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('more-staff')));
    await tester.pumpAndSettle();
  }
  return b;
}

Future<void> leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

String shown(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data ?? '';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('owners and managers find Staff under More; cashiers and warehouse staff do not', (tester) async {
    for (final role in ['superadmin', 'admin']) {
      await openStaff(tester, role: role);
      expect(find.byKey(const Key('staff-add')), findsOneWidget, reason: role);
      await leave(tester);
    }
    for (final role in ['cashier', 'warehouse']) {
      await openStaff(tester, role: role);
      expect(find.byKey(const Key('more-staff')), findsNothing, reason: role);
      await leave(tester);
    }
  });

  testWidgets('lists everyone with role, store and the name a cashier signs in with', (tester) async {
    await openStaff(tester);
    expect(find.text('Pia Cruz'), findsOneWidget);
    expect(find.textContaining('Signs in as pia.tindahan'), findsOneWidget);
    expect(find.textContaining('Owner · Main'), findsOneWidget);
    expect(find.textContaining('Signs in as ana'), findsNothing, reason: 'only cashiers sign in by username');
    await leave(tester);
  });

  testWidgets('adds a cashier: the server gets the store, the list shows the new login', (tester) async {
    final b = await openStaff(tester);
    await tester.tap(find.byKey(const Key('staff-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('staff-username')), 'Lito');
    await tester.enterText(find.byKey(const Key('staff-fullname')), 'Lito Reyes');
    await tester.enterText(find.byKey(const Key('staff-password')), 'secret-pass-1');
    await tester.tap(find.byKey(const Key('staff-create')));
    await tester.pumpAndSettle();
    expect(b.created.single, {'username': 'lito', 'name': 'Lito Reyes', 'password': 'secret-pass-1', 'store': 's1'});
    expect(shown(tester, 'staff-message'), contains('lito.tindahan'));
    expect(find.text('Lito Reyes'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a bad username or a short password never reaches the server', (tester) async {
    final b = await openStaff(tester);
    await tester.tap(find.byKey(const Key('staff-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('staff-username')), 'a b');
    await tester.enterText(find.byKey(const Key('staff-password')), 'secret-pass-1');
    await tester.tap(find.byKey(const Key('staff-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staff-add-error')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('staff-username')), 'lito');
    await tester.enterText(find.byKey(const Key('staff-password')), 'short');
    await tester.tap(find.byKey(const Key('staff-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staff-add-error')), findsOneWidget);
    expect(b.created, isEmpty);
    await leave(tester);
  });

  testWidgets('the server refusing a duplicate name is explained and the sheet stays open', (tester) async {
    final b = await openStaff(tester);
    await tester.tap(find.byKey(const Key('staff-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('staff-username')), 'pia');
    await tester.enterText(find.byKey(const Key('staff-password')), 'secret-pass-1');
    b.failWith = const StaffException('duplicate');
    await tester.tap(find.byKey(const Key('staff-create')));
    await tester.pumpAndSettle();
    expect(shown(tester, 'staff-add-error'), 'That username is taken.');
    expect(find.byKey(const Key('staff-create')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('switching a person off and on again', (tester) async {
    final b = await openStaff(tester);
    await tester.tap(find.byKey(const Key('staff-menu-pia')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('staff-toggle-pia')));
    await tester.pumpAndSettle();
    expect(b.activeCalls, ['u2:false']);
    expect(find.textContaining('Off'), findsOneWidget);
    await tester.tap(find.byKey(const Key('staff-menu-pia')));
    await tester.pumpAndSettle();
    expect(find.text('Switch on'), findsOneWidget);
    await tester.tap(find.byKey(const Key('staff-toggle-pia')));
    await tester.pumpAndSettle();
    expect(b.activeCalls, ['u2:false', 'u2:true']);
    await leave(tester);
  });

  testWidgets('you cannot switch yourself off: no menu on your own row', (tester) async {
    await openStaff(tester);
    expect(find.byKey(const Key('staff-menu-ana')), findsNothing);
    expect(find.byKey(const Key('staff-menu-pia')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('only the owner can clear a PIN; a manager does not see it', (tester) async {
    final b = await openStaff(tester);
    await tester.tap(find.byKey(const Key('staff-menu-pia')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('staff-pin-pia')));
    await tester.pumpAndSettle();
    expect(b.pinCalls, ['u2']);
    expect(shown(tester, 'staff-message'), 'PIN cleared.');
    await leave(tester);

    await openStaff(tester, role: 'admin');
    await tester.tap(find.byKey(const Key('staff-menu-pia')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staff-toggle-pia')), findsOneWidget);
    expect(find.byKey(const Key('staff-pin-pia')), findsNothing);
    await leave(tester);
  });

  testWidgets('with no signal the list says so and can be retried', (tester) async {
    final b = StaffBackend()..failWith = const StaffOffline();
    await openStaff(tester, backend: b);
    expect(find.byKey(const Key('staff-error')), findsOneWidget);
    b.failWith = null;
    await tester.tap(find.byKey(const Key('staff-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Pia Cruz'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a refused switch-off shows the reason and changes nothing', (tester) async {
    final b = await openStaff(tester);
    b.failWith = const StaffException('manage_denied');
    await tester.tap(find.byKey(const Key('staff-menu-pia')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('staff-toggle-pia')));
    await tester.pumpAndSettle();
    expect(shown(tester, 'staff-message'), 'You cannot do this.');
    expect(find.textContaining('Off'), findsNothing);
    await leave(tester);
  });

  testWidgets('Filipino labels', (tester) async {
    await openStaff(tester, locale: 'fil');
    expect(find.text('Magdagdag ng kahera'), findsOneWidget);
    expect(find.textContaining('Nagsa-sign in bilang pia.tindahan'), findsOneWidget);
    await leave(tester);
  });

  test('the sign-in name: a typed username.storecode becomes the account address, a real email stays', () {
    expect(loginEmail('Pia.Tindahan'), 'pia.tindahan@pos.invalid');
    expect(loginEmail(' owner@shop.com '), 'owner@shop.com');
    expect(staffLogin('pia', 'tindahan'), 'pia.tindahan');
  });
}
