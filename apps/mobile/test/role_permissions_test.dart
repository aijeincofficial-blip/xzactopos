import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/settings_screen.dart';
import 'package:xzactopos_mobile/screens/today_screen.dart';
import 'package:xzactopos_mobile/sync/photo_loader.dart';
import 'package:xzactopos_mobile/sync/store_session.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'products_test.dart' show leave;
import 'widget_test.dart' show FakeBackend;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('CatalogScope role permissions', () {
    late DriftStore store;
    late SyncEngine engine;
    late PhotoLoader photos;

    setUp(() {
      store = DriftStore(AppDatabase(NativeDatabase.memory()));
      engine = SyncEngine(store, FakeBackend());
      photos = PhotoLoader(store, FakeBackend());
    });

    tearDown(() async {
      await store.close();
    });

    test('cashier role has restricted permissions', () {
      final scope = CatalogScope(
        store: store,
        engine: engine,
        photos: photos,
        canManageStock: false,
        role: 'cashier',
        child: const SizedBox(),
      );

      expect(scope.isCashier, isTrue);
      expect(scope.isWarehouse, isFalse);
      expect(scope.isAdminOrSuperadmin, isFalse);
      expect(scope.canManageStock, isFalse);
      expect(scope.canAccessExpenses, isFalse);
      expect(scope.canCloseDay, isFalse);
    });

    test('warehouse role can manage stock but not admin expenses/day-close', () {
      final scope = CatalogScope(
        store: store,
        engine: engine,
        photos: photos,
        canManageStock: true,
        role: 'warehouse',
        child: const SizedBox(),
      );

      expect(scope.isCashier, isFalse);
      expect(scope.isWarehouse, isTrue);
      expect(scope.isAdminOrSuperadmin, isFalse);
      expect(scope.canManageStock, isTrue);
      expect(scope.canAccessExpenses, isFalse);
      expect(scope.canCloseDay, isFalse);
    });

    test('admin/superadmin/solo owner has full access', () {
      for (final role in ['admin', 'superadmin', null]) {
        final scope = CatalogScope(
          store: store,
          engine: engine,
          photos: photos,
          canManageStock: true,
          role: role,
          child: const SizedBox(),
        );

        expect(scope.isCashier, isFalse);
        expect(scope.isWarehouse, isFalse);
        expect(scope.isAdminOrSuperadmin, isTrue);
        expect(scope.canManageStock, isTrue);
        expect(scope.canAccessExpenses, isTrue);
        expect(scope.canCloseDay, isTrue);
      }
    });
  });

  group('Widget role-based UI tests', () {
    testWidgets('cashier does not see expenses and close-day tiles on TodayScreen', (tester) async {
      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      final backend = FakeBackend(signedInAtStart: true)
        ..access = {
          'role': 'cashier',
          'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
        };

      await tester.pumpWidget(
        App(backend: backend, openStore: ({bool safeMode = false}) => store, initialLocale: 'en'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-today')));
      await tester.pumpAndSettle();

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byKey(const Key('tile-expenses')), findsNothing);
      expect(find.byKey(const Key('tile-close-day')), findsNothing);

      await leave(tester);
    });

    testWidgets('admin/owner sees expenses and close-day tiles on TodayScreen', (tester) async {
      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      final backend = FakeBackend(signedInAtStart: true)
        ..access = {
          'role': 'admin',
          'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
        };

      await tester.pumpWidget(
        App(backend: backend, openStore: ({bool safeMode = false}) => store, initialLocale: 'en'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-today')));
      await tester.pumpAndSettle();

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byKey(const Key('tile-expenses')), findsOneWidget);
      expect(find.byKey(const Key('tile-close-day')), findsOneWidget);

      await leave(tester);
    });

    testWidgets('cashier does not see Upgrade to Full Mode in Settings', (tester) async {
      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      final backend = FakeBackend(signedInAtStart: true)
        ..access = {
          'role': 'cashier',
          'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
        };

      final engine = SyncEngine(store, backend);
      final photos = PhotoLoader(store, backend);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: CatalogScope(
            store: store,
            engine: engine,
            photos: photos,
            canManageStock: false,
            role: 'cashier',
            child: SettingsScreen(backend: backend, storeName: 'Tindahan'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-upgrade-full')), findsNothing);
      await store.close();
    });

    testWidgets('admin/owner sees Upgrade to Full Mode in Settings', (tester) async {
      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      final backend = FakeBackend(signedInAtStart: true)
        ..access = {
          'role': 'admin',
          'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
        };

      final engine = SyncEngine(store, backend);
      final photos = PhotoLoader(store, backend);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: CatalogScope(
            store: store,
            engine: engine,
            photos: photos,
            canManageStock: true,
            role: 'admin',
            child: SettingsScreen(backend: backend, storeName: 'Tindahan'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-upgrade-full')), findsOneWidget);
      await store.close();
    });
  });
}
