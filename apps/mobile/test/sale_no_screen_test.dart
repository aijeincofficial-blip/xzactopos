import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/export.dart';
import 'package:xzactopos_mobile/core/utang_statement.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/settings_screen.dart';
import 'package:xzactopos_mobile/screens/utang_screen.dart';
import 'package:xzactopos_mobile/sync/photo_loader.dart';
import 'package:xzactopos_mobile/sync/store_session.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;
import 'widget_test.dart' show FakeBackend;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

class _TrackingFakeBackend extends FakeBackend implements DeviceApi {
  _TrackingFakeBackend() : super(signedInAtStart: true);
  final List<({String id, String? name, String? platform})> registrations = [];

  @override
  Future<Map<String, dynamic>> registerDevice(String id, {String? name, String? platform}) async {
    registrations.add((id: id, name: name, platform: platform));
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'user_id': userId,
      'first_seen_at': '2026-11-12T00:00:00Z',
      'last_seen_at': '2026-11-12T00:00:00Z',
    };
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('Today and the receipt show the local number until the server gives its own, then the server number', (tester) async {
    final store = await openHome(tester);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 1000)],
    ));
    await store.commitSale(
      SaleDraft(
        id: 's1',
        soldAt: DateTime.now(),
        lines: const [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: 1000)],
        payments: const [PaymentDraft('cash', 1000)],
      ),
      opId: 'o1',
    );
    final local = (await store.getSale('s1'))!.summary.localNo;
    expect((await store.getSale('s1'))!.provisional, isTrue);

    await tester.tap(find.byKey(const Key('tile-today')));
    await tester.pumpAndSettle();
    expect(find.textContaining(local), findsWidgets, reason: 'offline: the number this phone gave');
    await tester.tap(find.byKey(const Key('sale-s1')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('receipt-no'))).data, 'Receipt no. $local');

    // the server confirms the sale and sends its own number
    await store.posOpApplied('o1', DateTime.now().toUtc().toIso8601String(), result: {'sale_id': 's1', 'sale_no': 'S01-261108-0007'});
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('receipt-no'))).data, 'Receipt no. S01-261108-0007');
    expect((await store.getSale('s1'))!.provisional, isFalse);
    expect((await store.getSale('s1'))!.summary.localNo, local, reason: 'the local number is kept');

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('S01-261108-0007'), findsWidgets, reason: 'the Today list follows');
    await leave(tester);
  });

  testWidgets('Utang ledger, statement, and CSV switch from provisional local number to confirmed server sale_no', (tester) async {
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('t1', baseCurrency: 'PHP');
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Bigas')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 5500)],
    ));
    await store.saveCustomer(id: 'c1', name: 'Aling Nena', phone: '09170001111', opId: 'op-c1');
    await store.commitSale(
      SaleDraft(
        id: 's-utang',
        soldAt: DateTime(2026, 11, 12, 10, 30),
        customerId: 'c1',
        lines: const [SaleLine(variantId: _v1, name: 'Bigas', qty: 1, unitPrice: 5500)],
        payments: const [PaymentDraft('utang', 5500)],
      ),
      opId: 'op-sale-u',
    );
    final localNo = (await store.getSale('s-utang'))!.summary.localNo;

    final backend = FakeBackend(signedInAtStart: true);
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
          role: 'superadmin',
          child: const UtangScreen(storeName: 'Central Store'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open customer detail
    await tester.tap(find.text('Aling Nena'));
    await tester.pumpAndSettle();
    expect(find.textContaining(localNo), findsOneWidget);

    // Server confirms sale with official sale_no
    await store.posOpApplied(
      'op-sale-u',
      DateTime.now().toUtc().toIso8601String(),
      result: {'sale_id': 's-utang', 'sale_no': 'S01-261112-0042'},
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('S01-261112-0042'), findsOneWidget);

    final ledger = await store.watchLedger('c1').first;
    expect(ledger.single.localNo, localNo);
    expect(ledger.single.saleNo, 'S01-261112-0042');
    expect(ledger.single.displayNo, 'S01-261112-0042');

    final csv = utangLedgerCsv(ledger, 'PHP');
    expect(csv, contains('receipt_no,sale_no'));
    expect(csv, contains('$localNo,S01-261112-0042'));

    final statement = utangStatementText(
      storeName: 'Central Store',
      customer: const CustomerView(id: 'c1', name: 'Aling Nena', balance: 5500, pending: false),
      ledger: ledger,
      currency: 'PHP',
      locale: 'en',
      labels: const StatementLabels(
        title: 'Utang statement',
        balance: 'Balance',
        dueOn: 'Due on',
        recent: 'Recent',
        charge: 'Took on utang',
        payment: 'Paid',
        adjust: 'Adjustment',
      ),
    );
    expect(statement, contains('Took on utang (S01-261112-0042)'));

    await store.close();
  });

  testWidgets('SettingsScreen shows short terminal ID and renames terminal with forced registration', (tester) async {
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('t1', baseCurrency: 'PHP');
    final fullId = await store.deviceId();
    final shortSuffix = fullId.replaceAll('-', '').toUpperCase().substring(fullId.replaceAll('-', '').length - 8);

    final backend = _TrackingFakeBackend();
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
          role: 'superadmin',
          child: SettingsScreen(backend: backend, storeName: 'Central Store'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-device-name')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('settings-device-name'))).data, 'This Phone');
    expect(tester.widget<Text>(find.byKey(const Key('settings-device-id'))).data, 'Terminal ID #$shortSuffix');

    await tester.ensureVisible(find.byKey(const Key('settings-rename-device')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-rename-device')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('device-name-field')), 'Counter 2 Android');
    await tester.tap(find.byKey(const Key('device-name-save')));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const Key('settings-device-name'))).data, 'Counter 2 Android');
    expect(await store.meta(SyncEngine.deviceNameKey), 'Counter 2 Android');
    expect(backend.registrations, isNotEmpty);
    expect(backend.registrations.last.id, fullId);
    expect(backend.registrations.last.name, 'Counter 2 Android');

    await store.close();
  });
}
