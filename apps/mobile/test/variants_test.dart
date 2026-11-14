import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';
import 'package:xzactopos_mobile/screens/cart.dart';
import 'package:xzactopos_mobile/screens/product_form_screen.dart';
import 'package:xzactopos_mobile/screens/sell_screen.dart';
import 'package:xzactopos_mobile/sync/photo_loader.dart';
import 'package:xzactopos_mobile/sync/store_session.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'widget_test.dart' show FakeBackend;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Multi-variant products (F-03)', () {
    test('groupProducts clusters variants under productId and displayName formats non-default names', () {
      const reg = ProductView(
        id: 'p1',
        variantId: 'v1',
        name: 'Iced Latte',
        unit: 'cup',
        sku: 'LATTE-R',
        variantName: 'Regular',
        isDefault: true,
        variantCount: 2,
        price: 12000,
        currency: 'PHP',
        active: true,
        pending: false,
      );
      const large = ProductView(
        id: 'p1',
        variantId: 'v2',
        name: 'Iced Latte',
        unit: 'cup',
        sku: 'LATTE-L',
        variantName: 'Large',
        isDefault: false,
        variantCount: 2,
        price: 15000,
        currency: 'PHP',
        active: true,
        pending: false,
      );
      const single = ProductView(
        id: 'p2',
        variantId: 'v3',
        name: 'PandesaL',
        unit: 'pc',
        sku: 'PAN-1',
        variantName: 'Default',
        isDefault: true,
        variantCount: 1,
        price: 500,
        currency: 'PHP',
        active: true,
        pending: false,
      );

      expect(reg.displayName, 'Iced Latte (Regular)');
      expect(large.displayName, 'Iced Latte (Large)');
      expect(single.displayName, 'PandesaL');

      final groups = groupProducts([large, single, reg]);
      expect(groups.length, 2);
      expect(groups[0].productId, 'p1');
      expect(groups[0].primary.variantId, 'v1');
      expect(groups[0].variants.length, 2);
      expect(groups[1].productId, 'p2');

      final line = CartLine(large, 2);
      expect(line.toSaleLine().name, 'Iced Latte (Large)');
    });

    test('DriftStore saves multi-variant drafts with per-variant barcode and opening stock', () async {
      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      await store.ensureTenant('t1', baseCurrency: 'PHP', locationId: 's1');

      await store.saveProduct(
        const ProductDraft(
          id: 'p-latte',
          variantId: 'v-reg',
          name: 'Iced Latte',
          price: 12000,
          variants: [
            VariantDraft(
              id: 'v-reg',
              name: 'Regular',
              barcode: '48000001',
              price: 12000,
              openingQty: 10,
              isDefault: true,
            ),
            VariantDraft(
              id: 'v-lrg',
              name: 'Large',
              barcode: '48000002',
              price: 15000,
              openingQty: 4,
              isDefault: false,
            ),
          ],
        ),
        opId: 'op-save-latte',
      );

      final variants = await store.productVariants('p-latte');
      expect(variants.map((v) => v.variantName).toList(), ['Regular', 'Large']);

      final hitLarge = await store.findByBarcode('48000002');
      expect(hitLarge?.variantId, 'v-lrg');
      expect(hitLarge?.displayName, 'Iced Latte (Large)');

      final stock = await store.watchStockList().first;
      final regStock = stock.firstWhere((r) => r.product.variantId == 'v-reg');
      final lrgStock = stock.firstWhere((r) => r.product.variantId == 'v-lrg');
      expect(regStock.qty, 10);
      expect(lrgStock.qty, 4);

      await store.close();
    });

    testWidgets('ProductFormScreen creates a multi-variant product and SellScreen opens variant picker', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      await store.ensureTenant('t1', baseCurrency: 'PHP', locationId: 's1');
      final backend = FakeBackend(signedInAtStart: true)
        ..access = {
          'user_id': 'u1',
          'role': 'superadmin',
          'tenant': {'id': 't1', 'name': 'Tindahan', 'base_currency': 'PHP'},
          'locations': [
            {'id': 's1', 'type': 'store', 'code': 'S1', 'name': 'Main'},
          ],
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
            role: 'superadmin',
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const Key('open-pf'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CatalogScope.of(context).wrap(const ProductFormScreen()),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-pf')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('field-name')), 'Iced Latte');
      await tester.ensureVisible(find.byKey(const Key('pf-add-variant')));
      await tester.tap(find.byKey(const Key('pf-add-variant')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('pf-variant-name-0')), 'Regular');
      await tester.enterText(find.byKey(const Key('pf-variant-price-0')), '120');
      await tester.enterText(find.byKey(const Key('pf-variant-stock-0')), '8');
      await tester.enterText(find.byKey(const Key('pf-variant-name-1')), 'Large');
      await tester.enterText(find.byKey(const Key('pf-variant-price-1')), '150');
      await tester.enterText(find.byKey(const Key('pf-variant-stock-1')), '5');

      await tester.tap(find.byKey(const Key('save-product')));
      await tester.pumpAndSettle();

      final saved = await store.watchProducts().first;
      expect(saved.length, 2);
      final large = saved.firstWhere((v) => v.variantName == 'Large');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: CatalogScope(
            store: store,
            engine: engine,
            photos: photos,
            role: 'superadmin',
            child: SellScreen(backend: backend, storeName: 'Tindahan'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grouped under single tile on SellScreen; tapping opens variant picker sheet.
      expect(find.text('2 sizes'), findsOneWidget);
      await tester.tap(find.text('Iced Latte'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('variant-picker-sheet')), findsOneWidget);
      await tester.tap(find.byKey(Key('pick-variant-${large.variantId}')));
      await tester.pumpAndSettle();

      expect(find.text('×1'), findsOneWidget);

      await store.close();
    });
  });
}
