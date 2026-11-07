import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/backend.dart';

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
  @override
  Future<Map<String, dynamic>?> myAccess() async => access;
  @override
  Future<void> provisionSoloStore({
    required String tenantId,
    required String locationId,
    required String storeName,
    required String locale,
  }) async {
    calls.add({'tenant': tenantId, 'location': locationId, 'name': storeName, 'locale': locale});
    access = {
      'tenant': {'name': storeName},
    };
  }
}

void main() {
  testWidgets('signed-in user with no store names it and lands on Home', (tester) async {
    final backend = FakeBackend(signedInAtStart: true);
    await tester.pumpWidget(App(backend: backend));
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
  });

  testWidgets('language switch changes the screen text', (tester) async {
    await tester.pumpWidget(App(backend: FakeBackend(signedInAtStart: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('Name your store'), findsOneWidget);
  });

  testWidgets('signed-out user sees the sign-up form', (tester) async {
    await tester.pumpWidget(App(backend: FakeBackend()));
    await tester.pumpAndSettle();
    expect(find.text('Gumawa ng account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
