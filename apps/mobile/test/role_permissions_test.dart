import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/products_screen.dart';
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
      expect(scope.isSuperadmin, isFalse);
      expect(scope.canManageStock, isFalse);
      expect(scope.canManageCatalog, isFalse);
      expect(scope.canManageStaff, isFalse);
      expect(scope.canAccessExpenses, isFalse);
      expect(scope.canCloseDay, isFalse);
      expect(scope.canViewReports, isFalse);
      expect(scope.canCashDrop, isFalse);
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
      expect(scope.canManageCatalog, isFalse);
      expect(scope.canManageStaff, isFalse);
      expect(scope.canAccessExpenses, isFalse);
      expect(scope.canCloseDay, isFalse);
    });

    test('admin supervisor can run shift/reports/expenses/day-close but not stock/catalog/staff', () {
      final scope = CatalogScope(
        store: store,
        engine: engine,
        photos: photos,
        role: 'admin',
        position: 'supervisor',
        child: const SizedBox(),
      );

      expect(scope.isSupervisor, isTrue);
      expect(scope.isManager, isFalse);
      expect(scope.isSuperadmin, isFalse);
      expect(scope.isAdminOrSuperadmin, isTrue);
      expect(scope.canManageStock, isFalse);
      expect(scope.canManageCatalog, isFalse);
      expect(scope.canManageStaff, isFalse);
      expect(scope.canAccessExpenses, isTrue);
      expect(scope.canCloseDay, isTrue);
      expect(scope.canViewReports, isTrue);
      expect(scope.canCashDrop, isTrue);
    });

    test('manager/superadmin/solo owner has store management access', () {
      for (final (role, pos, expectSuper) in [
        ('admin', 'manager', false),
        ('superadmin', null, true),
        (null, null, true),
      ]) {
        final scope = CatalogScope(
          store: store,
          engine: engine,
          photos: photos,
          role: role,
          position: pos,
          child: const SizedBox(),
        );

        expect(scope.isCashier, isFalse);
        expect(scope.isWarehouse, isFalse);
        expect(scope.isSuperadmin, expectSuper);
        expect(scope.isAdminOrSuperadmin, isTrue);
        expect(scope.canManageStock, isTrue);
        expect(scope.canManageCatalog, isTrue);
        expect(scope.canManageStaff, isTrue);
        expect(scope.canAccessExpenses, isTrue);
        expect(scope.canCloseDay, isTrue);
        expect(scope.canViewReports, isTrue);
        expect(scope.canCashDrop, isTrue);
      }
    });

    test('access helpers resolve per-store admin position and pos module sync scope', () {
      final access = <String, dynamic>{
        'role': 'admin',
        'modules': {'inventory': true, 'pos': false, 'warehouse': false},
        'locations': [
          {'id': 's1', 'type': 'store', 'position': 'manager'},
          {'id': 's2', 'type': 'store', 'position': 'supervisor'},
        ],
      };

      expect(positionForAccess(access, 's1'), 'manager');
      expect(positionForAccess(access, 's2'), 'supervisor');
      expect(canManageStockForAccess(access, 's1'), isTrue);
      expect(canManageStockForAccess(access, 's2'), isFalse);
      expect(posEnabledForAccess(access), isFalse);
      expect(syncScopeForRole('admin', posEnabled: false), (store: false, warehouse: false));
      expect(syncScopeForRole('warehouse', posEnabled: false), (store: false, warehouse: true));
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

    testWidgets('admin/owner sees expenses and close-day tiles on TodayScreen (including supervisor)', (tester) async {
      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      final backend = FakeBackend(signedInAtStart: true)
        ..access = {
          'role': 'admin',
          'locations': [
            {'id': 's1', 'type': 'store', 'code': 'S1', 'name': 'Main', 'position': 'supervisor'},
          ],
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

    testWidgets('admin does NOT see Upgrade to Full Mode in Settings, while superadmin does', (tester) async {
      for (final (role, expected) in [('admin', findsNothing), ('superadmin', findsOneWidget)]) {
        final store = DriftStore(AppDatabase(NativeDatabase.memory()));
        final backend = FakeBackend(signedInAtStart: true)
          ..access = {
            'role': role,
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
              role: role,
              position: role == 'admin' ? 'manager' : null,
              child: SettingsScreen(backend: backend, storeName: 'Tindahan'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('settings-upgrade-full')), expected, reason: role);
        await store.close();
      }
    });

    testWidgets('cashier does not see Add product, Restock, or Cash Drop affordances', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      final backend = FakeBackend(signedInAtStart: true)
        ..access = {
          'user_id': 'u1',
          'role': 'cashier',
          'locations': [
            {'id': 's1', 'type': 'store', 'code': 'S1', 'name': 'Main'},
          ],
          'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
        };

      await tester.pumpWidget(
        App(backend: backend, openStore: ({bool safeMode = false}) => store, initialLocale: 'en'),
      );
      await tester.pumpAndSettle();

      await store.startShift(id: 'sh-1', cashierId: 'u1', openingCash: 10000, opId: 'op-shift-1');
      await tester.pumpAndSettle();

      // Empty sell screen must not invite cashier to add products.
      expect(find.byKey(const Key('sell-add-product')), findsNothing);

      // Stock screen hides restock action for cashiers.
      await tester.tap(find.byKey(const Key('tile-stock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open-restock')), findsNothing);

      // More screen hides restock/reports/expenses/staff/close-day/transfers/data for cashiers.
      await tester.tap(find.byKey(const Key('tab-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tile-restock')), findsNothing);
      expect(find.byKey(const Key('tile-reports')), findsNothing);
      expect(find.byKey(const Key('more-expenses')), findsNothing);
      expect(find.byKey(const Key('more-staff')), findsNothing);
      expect(find.byKey(const Key('more-close-day')), findsNothing);
      expect(find.byKey(const Key('tile-transfers')), findsNothing);
      expect(find.byKey(const Key('more-shift')), findsOneWidget);

      // Shift screen hides cash drop for cashiers.
      await tester.tap(find.byKey(const Key('more-shift')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shift-cash-drop-btn')), findsNothing);

      // Return to More -> Products: FAB to create product is hidden.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tile-products')));
      await tester.pumpAndSettle();
      expect(find.byType(ProductsScreen), findsOneWidget);
      expect(find.byKey(const Key('add-product')), findsNothing);

      await leave(tester);
    });

    testWidgets('supervisor admin sees reports/expenses/day-close but not restock/staff/add-product', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      final backend = FakeBackend(signedInAtStart: true)
        ..access = {
          'user_id': 'u-sup',
          'role': 'admin',
          'locations': [
            {'id': 's1', 'type': 'store', 'code': 'S1', 'name': 'Main', 'position': 'supervisor'},
          ],
          'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
        };

      await tester.pumpWidget(
        App(backend: backend, openStore: ({bool safeMode = false}) => store, initialLocale: 'en'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tile-stock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open-restock')), findsNothing);

      await tester.tap(find.byKey(const Key('tab-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tile-reports')), findsOneWidget);
      expect(find.byKey(const Key('more-expenses')), findsOneWidget);
      expect(find.byKey(const Key('more-close-day')), findsOneWidget);
      expect(find.byKey(const Key('tile-restock')), findsNothing);
      expect(find.byKey(const Key('more-staff')), findsNothing);
      expect(find.byKey(const Key('tile-transfers')), findsNothing);

      await tester.tap(find.byKey(const Key('tile-products')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-product')), findsNothing);

      await leave(tester);
    });

    testWidgets('pos module disabled hides POS tabs for owner and locks out cashier', (tester) async {
      final cashierStore = DriftStore(AppDatabase(NativeDatabase.memory()));
      final cashierBackend = FakeBackend(signedInAtStart: true)
        ..access = {
          'user_id': 'u-c',
          'role': 'cashier',
          'modules': {'inventory': true, 'pos': false, 'warehouse': false},
          'locations': [
            {'id': 's1', 'type': 'store', 'code': 'S1', 'name': 'Main'},
          ],
          'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
        };

      await tester.pumpWidget(
        App(backend: cashierBackend, openStore: ({bool safeMode = false}) => cashierStore, initialLocale: 'en'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos-disabled-title')), findsOneWidget);
      expect(find.byKey(const Key('pos-disabled-signout')), findsOneWidget);
      await leave(tester);
      await cashierStore.close();

      final ownerStore = DriftStore(AppDatabase(NativeDatabase.memory()));
      final ownerBackend = FakeBackend(signedInAtStart: true)
        ..access = {
          'user_id': 'u-o',
          'role': 'superadmin',
          'modules': {'inventory': true, 'pos': false, 'warehouse': false},
          'locations': [
            {'id': 's1', 'type': 'store', 'code': 'S1', 'name': 'Main'},
          ],
          'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
        };

      await tester.pumpWidget(
        App(backend: ownerBackend, openStore: ({bool safeMode = false}) => ownerStore, initialLocale: 'en'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tile-stock')), findsOneWidget);
      expect(find.byKey(const Key('tab-more')), findsOneWidget);
      expect(find.byKey(const Key('tile-sell')), findsNothing);
      expect(find.byKey(const Key('tab-today')), findsNothing);

      await tester.tap(find.byKey(const Key('tab-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('more-shift')), findsNothing);
      expect(find.byKey(const Key('more-services')), findsNothing);
      expect(find.byKey(const Key('tile-restock')), findsOneWidget);

      await leave(tester);
    });
  });
}
