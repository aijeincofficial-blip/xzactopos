import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/search.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/screens/products_screen.dart' show looksLikeBarcode;

import 'products_test.dart' show addProduct, leave, openHome;

String id(int n, [String prefix = '0190a000-0000-7000-8000-']) => '$prefix${n.toRadixString(16).padLeft(12, '0')}';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('search key folds case, accents and spaces', () {
    expect(searchKey('  PIÑA   Juice '), 'pina juice');
    expect(searchKey('Café Crème'), 'cafe creme');
    expect(searchWords('Kape  3'), ['kape', '3']);
    expect(searchWords('   '), isEmpty);
  });

  test('barcode-like input', () {
    expect(looksLikeBarcode('4800016644801'), isTrue);
    expect(looksLikeBarcode('12345678'), isTrue);
    expect(looksLikeBarcode('kape'), isFalse);
    expect(looksLikeBarcode('12'), isFalse);
  });

  group('store search', () {
    late DriftStore store;
    setUp(() async {
      store = DriftStore(AppDatabase(NativeDatabase.memory()));
      await store.ensureTenant('t', baseCurrency: 'PHP');
      var n = 0;
      for (final p in [
        ['Piña Juice', '111'],
        ['Kape 3-in-1', '4800016644801'],
        ['Kopiko Kape', null],
        ['Asukal Pula', null],
      ]) {
        n++;
        await store.saveProduct(
            ProductDraft(id: id(n), variantId: id(n, '0190a000-0000-7000-9000-'), name: p[0]!, price: 100, barcode: p[1]),
            opId: 'op$n');
      }
    });
    tearDown(() => store.close());

    Future<List<String>> names(String q) async => (await store.watchProducts(query: q).first).map((p) => p.name).toList();

    test('accents and case do not matter', () async {
      expect(await names('pina'), ['Piña Juice']);
      expect(await names('PIÑA'), ['Piña Juice']);
    });
    test('every word must match, in any order', () async {
      expect(await names('kape 3'), ['Kape 3-in-1']);
      expect(await names('3 kape'), ['Kape 3-in-1']);
      expect(await names('kape pula'), isEmpty);
    });
    test('names starting with the query come first', () async {
      expect(await names('kape'), ['Kape 3-in-1', 'Kopiko Kape']);
    });
    test('exact barcode matches', () async {
      expect(await names('4800016644801'), ['Kape 3-in-1']);
      expect((await store.findByBarcode('111'))?.name, 'Piña Juice');
      expect(await store.findByBarcode('999'), isNull);
    });
  });

  test('2,000 products: a search answers fast', () async {
    final store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('t', baseCurrency: 'PHP');
    await store.db.batch((b) {
      for (var i = 0; i < 2000; i++) {
        b.insert(store.db.products, ProductsCompanion.insert(id: id(i), name: 'Item $i', searchName: Value('item $i')));
        b.insert(store.db.variants,
            VariantsCompanion.insert(id: id(i, '0190a000-0000-7000-9000-'), productId: id(i), sku: 'S$i'));
      }
    });
    await store.watchProducts(query: 'item').first; // warm up
    final sw = Stopwatch()..start();
    final hits = await store.watchProducts(query: 'item 1999').first;
    sw.stop();
    // ignore: avoid_print
    print('search over 2000 products: ${sw.elapsedMilliseconds} ms');
    expect(hits.single.name, 'Item 1999');
    expect(sw.elapsedMilliseconds, lessThan(250), reason: 'target is under 100 ms on a phone');
    await store.close();
  });

  test('upgrading a v1 database fills the search column', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute("CREATE TABLE products (id TEXT NOT NULL PRIMARY KEY, category_id TEXT NULL, name TEXT NOT NULL, "
          "unit TEXT NOT NULL DEFAULT 'pc', tax_rate REAL NOT NULL DEFAULT 0, track_stock INTEGER NOT NULL DEFAULT 1, "
          "active INTEGER NOT NULL DEFAULT 1, photo_path TEXT NULL, updated_at TEXT NULL, deleted_at TEXT NULL)");
      raw.execute("INSERT INTO products (id, name) VALUES ('p1', 'Piña')");
      raw.execute('PRAGMA user_version = 1');
    }));
    final rows = await db.select(db.products).get();
    expect(rows.single.searchName, 'pina');
    await db.close();
  });

  group('scanner flow (keyboard-wedge scanners type the code and press Enter)', () {
    Future<void> scan(WidgetTester tester, String code) async {
      await tester.tap(find.byKey(const Key('scan-button')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('product-search')), code);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    testWidgets('a known barcode opens the product', (tester) async {
      await openHome(tester);
      await tester.tap(find.byKey(const Key('tab-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tile-products')));
      await tester.pumpAndSettle();
      await addProduct(tester, name: 'Kape 3-in-1', price: '12', barcode: '4800016644801');

      await scan(tester, '4800016644801');
      expect(find.text('Edit product'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Kape 3-in-1'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('an unknown barcode offers to add it, prefilled', (tester) async {
      final store = await openHome(tester);
      await tester.tap(find.byKey(const Key('tab-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tile-products')));
      await tester.pumpAndSettle();

      await scan(tester, '4800000000999');
      expect(find.text('New barcode'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-scanned')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '4800000000999'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('field-name')), 'Sardinas');
      await tester.enterText(find.byKey(const Key('field-price')), '26');
      await tester.tap(find.byKey(const Key('save-product')));
      await tester.pumpAndSettle();
      expect(find.text('Sardinas'), findsOneWidget);
      expect((await store.findByBarcode('4800000000999'))?.name, 'Sardinas');
      await leave(tester);
    });

    testWidgets('a name typed and submitted just filters, no dialog', (tester) async {
      await openHome(tester);
      await tester.tap(find.byKey(const Key('tab-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tile-products')));
      await tester.pumpAndSettle();
      await scan(tester, 'kape');
      expect(find.text('New barcode'), findsNothing);
      await leave(tester);
    });
  });
}
