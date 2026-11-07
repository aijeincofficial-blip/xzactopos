import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';

import 'products_test.dart' show backend, leave, openHome;
import 'widget_test.dart' show FakeBackend, memoryStore;

Future<FakeBackend> openSignedOut(WidgetTester tester) async {
  final b = FakeBackend();
  await tester.pumpWidget(App(backend: b, openStore: memoryStore, initialLocale: 'en'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('I already have an account'));
  await tester.pumpAndSettle();
  return b;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('forgot password sends the link and never reveals whether the email has an account', (tester) async {
    final b = await openSignedOut(tester);
    expect(find.byKey(const Key('forgot-password')), findsOneWidget);
    await tester.tap(find.byKey(const Key('forgot-password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('forgot-email')), ' rosa@example.com ');
    await tester.tap(find.byKey(const Key('forgot-send')));
    await tester.pumpAndSettle();
    expect(b.resetsSentTo, ['rosa@example.com']);
    expect(find.text('If that email has an account, we sent a link to reset the password.'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a failing send shows the same message', (tester) async {
    final b = await openSignedOut(tester);
    b.resetError = Exception('unknown user');
    await tester.tap(find.byKey(const Key('forgot-password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('forgot-email')), 'nobody@example.com');
    await tester.tap(find.byKey(const Key('forgot-send')));
    await tester.pumpAndSettle();
    expect(find.text('If that email has an account, we sent a link to reset the password.'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the forgot link is only on the sign-in form, not sign-up', (tester) async {
    final b = FakeBackend();
    await tester.pumpWidget(App(backend: b, openStore: memoryStore, initialLocale: 'en'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forgot-password')), findsNothing);
    await leave(tester);
  });

  testWidgets('opening the reset link asks for a new password (twice, at least 6 characters)', (tester) async {
    final b = FakeBackend(signedInAtStart: true)
      ..access = {
        'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
      };
    await tester.pumpWidget(App(backend: b, openStore: memoryStore, initialLocale: 'en'));
    await tester.pumpAndSettle();
    b.recovery.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Choose a new password'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('new-password')), 'abc');
    await tester.tap(find.byKey(const Key('save-password')));
    await tester.pumpAndSettle();
    expect(find.text('At least 6 characters'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('new-password')), 'secret1');
    await tester.enterText(find.byKey(const Key('new-password-again')), 'secret2');
    await tester.tap(find.byKey(const Key('save-password')));
    await tester.pumpAndSettle();
    expect(find.text('The two passwords are different'), findsOneWidget);
    expect(b.passwordsSet, isEmpty);

    await tester.enterText(find.byKey(const Key('new-password-again')), 'secret1');
    await tester.tap(find.byKey(const Key('save-password')));
    await tester.pumpAndSettle();
    expect(b.passwordsSet, ['secret1']);
    expect(find.byKey(const Key('tile-sell')), findsOneWidget, reason: 'back to the app');
    await leave(tester);
  });

  testWidgets('a signed-in user changes their password from Home', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('btn-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-change-password')));
    await tester.tap(find.byKey(const Key('settings-change-password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('change-password-field')), '123');
    await tester.tap(find.byKey(const Key('change-password-save')));
    await tester.pumpAndSettle();
    expect(find.text('At least 6 characters'), findsOneWidget);
    expect(backend.passwordsSet, isEmpty);

    await tester.enterText(find.byKey(const Key('change-password-field')), 'newsecret');
    await tester.tap(find.byKey(const Key('change-password-save')));
    await tester.pumpAndSettle();
    expect(backend.passwordsSet, ['newsecret']);
    expect(find.text('Password changed'), findsOneWidget);
    await leave(tester);
  });
}
