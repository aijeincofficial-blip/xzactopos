import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart' show StoreRef;

import 'widget_test.dart' show FakeBackend;

/// Signed in with a store already set up, English UI.
late FakeBackend backend;

/// Tests open on a phone-sized screen (the screens are taller now: amount pad, receipt ticket). A test that needs
/// the 800x600 default (a wide screen) sets this to false first and it is restored afterwards.
bool phoneSizedScreen = true;

Future<DriftStore> openHome(WidgetTester tester, {Map<String, dynamic>? access}) async {
  if (phoneSizedScreen) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }
  final store = DriftStore(AppDatabase(NativeDatabase.memory()));
  backend = FakeBackend(signedInAtStart: true)
    ..access = access ??
        {
          'tenant': {'id': 't1', 'name': 'Tindahan ni Nena', 'base_currency': 'PHP'},
        };
  await tester.pumpWidget(App(backend: backend, openStore: ({bool safeMode = false}) => store, initialLocale: 'en'));
  await tester.pumpAndSettle();
  return store;
}

Future<void> leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

Future<void> addProduct(WidgetTester tester, {required String name, required String price, String? barcode}) async {
  await tester.tap(find.byKey(const Key('add-product')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('field-name')), name);
  await tester.enterText(find.byKey(const Key('field-price')), price);
  if (barcode != null) await tester.enterText(find.byKey(const Key('field-barcode')), barcode);
  await tester.tap(find.byKey(const Key('save-product')));
  await tester.pumpAndSettle();
}

/// A store that cannot open, like the shared-worker storage in a browser that blocks it.
class BrokenStore extends DriftStore {
  BrokenStore() : super(AppDatabase(NativeDatabase.memory()));
  @override
  Future<bool> ensureTenant(String tenantId,
          {required String baseCurrency,
          String? locationId,
          String? userId,
          List<StoreRef>? stores,
          bool discardUnsent = false}) =>
      Future.error(StateError('TypeError: Failed to fetch'));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('if the normal store cannot open, the app falls back to safe mode', (tester) async {
    final modes = <bool>[];
    final backend = FakeBackend(signedInAtStart: true)
      ..access = {
        'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
      };
    await tester.pumpWidget(App(
      backend: backend,
      initialLocale: 'en',
      openStore: ({bool safeMode = false}) {
        modes.add(safeMode);
        return safeMode ? DriftStore(AppDatabase(NativeDatabase.memory())) : BrokenStore();
      },
    ));
    await tester.pumpAndSettle();
    expect(modes, [false, true]);
    expect(find.byKey(const Key('tile-sell')), findsOneWidget, reason: 'the app is open on its Sell tab');
    await leave(tester);
  });

  testWidgets('if both fail, the tindera sees a clear message and can try again', (tester) async {
    var calls = 0;
    final backend = FakeBackend(signedInAtStart: true)
      ..access = {
        'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
      };
    await tester.pumpWidget(App(
      backend: backend,
      initialLocale: 'en',
      openStore: ({bool safeMode = false}) {
        calls++;
        return calls <= 2 ? BrokenStore() : DriftStore(AppDatabase(NativeDatabase.memory()));
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the data on this phone.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('store-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-sell')), findsOneWidget, reason: 'the app is open on its Sell tab');
    await leave(tester);
  });

  testWidgets('add a product from Home in a few taps; it is listed and queued', (tester) async {
    final store = await openHome(tester);
    await tester.tap(find.byKey(const Key('tab-more'))); // Products is in the More grid
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tile-products')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No products yet'), findsOneWidget);

    await addProduct(tester, name: 'Kape 3-in-1', price: '12.50', barcode: '4800016644801');

    expect(find.text('Kape 3-in-1'), findsOneWidget);
    expect(find.text('₱12.50'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsWidgets); // not sent yet
    final ops = await store.nextOps();
    expect(ops, hasLength(1));
    expect(ops.single.payload['price'], 1250);
    expect((ops.single.payload['variant'] as Map)['barcode'], '4800016644801');
    await leave(tester);
  });

  testWidgets('name and a valid price are required', (tester) async {
    final store = await openHome(tester);
    await tester.tap(find.byKey(const Key('tab-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tile-products')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-product')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();
    expect(find.text('Please fill this in'), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('field-name')), 'Asukal');
    await tester.enterText(find.byKey(const Key('field-price')), '1.234');
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number, like 12.50'), findsOneWidget);
    expect(await store.nextOps(), isEmpty);
    await leave(tester);
  });

  testWidgets('edit price, refuse a barcode already used, then remove', (tester) async {
    final store = await openHome(tester);
    await tester.tap(find.byKey(const Key('tab-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tile-products')));
    await tester.pumpAndSettle();
    await addProduct(tester, name: 'Kape', price: '12', barcode: '111');
    await addProduct(tester, name: 'Asukal', price: '45');

    // second product cannot take the first one's barcode
    await tester.tap(find.text('Asukal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-barcode')), '111');
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();
    expect(find.text('This barcode is already used by Kape'), findsOneWidget);

    // fix it: clear the barcode, change the price
    await tester.enterText(find.byKey(const Key('field-barcode')), '');
    await tester.enterText(find.byKey(const Key('field-price')), '47.50');
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();
    expect(find.text('₱47.50'), findsOneWidget);

    // search narrows the list
    await tester.enterText(find.byKey(const Key('product-search')), 'kap');
    await tester.pumpAndSettle();
    expect(find.text('Asukal'), findsNothing);
    expect(find.text('Kape'), findsOneWidget);

    // remove Kape
    await tester.tap(find.text('Kape'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archive-product')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Kape'), findsNothing);

    // everything was saved in order; sync may already have sent some of it
    final waiting = (await store.nextOps()).map((o) => o.kind).toList();
    expect([...backend.pushed, ...waiting], ['upsert_product', 'upsert_product', 'upsert_product', 'archive_product']);
    await leave(tester);
  });
}
