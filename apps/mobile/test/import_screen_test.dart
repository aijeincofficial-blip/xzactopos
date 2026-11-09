import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/export.dart';
import 'package:xzactopos_mobile/core/product_import.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

Future<void> openData(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab-more')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('tile-data')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tile-data')));
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('paste rows: the sheet counts the good ones, names the bad ones, and adds the good ones', (tester) async {
    final store = await openHome(tester);
    await openData(tester);
    await tester.tap(find.byKey(const Key('import-open')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('import-confirm'))).onPressed, isNull, reason: 'nothing pasted yet');

    await tester.enterText(
      find.byKey(const Key('import-text')),
      'name,price,barcode,cost,stock\nKape,12.50,4800016644801,9,24\nAsukal,abc\nSardinas,18,,14.5,\n',
    );
    await tester.pump();
    expect(find.text('2 products ready'), findsOneWidget);
    expect(find.text('1 row has a problem and is left out'), findsOneWidget);
    expect(find.text('Row 3: price is not a number'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('2 products added'), findsOneWidget);

    final all = await store.watchProducts().first;
    expect(all.map((p) => p.name).toSet(), {'Kape', 'Sardinas'});
    final kape = all.firstWhere((p) => p.name == 'Kape');
    expect((kape.price, kape.barcode, kape.cost), (1250, '4800016644801', 900));
    expect(await store.stockLeft(kape.variantId), 24, reason: 'the stock column becomes the opening stock');
    expect((await store.nextOps()).where((o) => o.kind == 'upsert_product'), hasLength(2));
    await leave(tester);
  });

  testWidgets('a barcode that is already used (or repeated in the paste) is skipped, not doubled', (tester) async {
    final store = await openHome(tester);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Gatas')],
      variants: [serverVariant(_v1, _p1, barcode: '4800000000001')],
      prices: [serverPrice(_v1, 2500)],
    ));
    await openData(tester);
    await tester.tap(find.byKey(const Key('import-open')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('import-text')),
      'Gatas ulit,30,4800000000001\nBago,10,4800000000002\nBago ulit,11,4800000000002\n',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('1 product added · 2 skipped: barcode already used'), findsOneWidget);
    expect((await store.watchProducts().first).map((p) => p.name).toSet(), {'Gatas', 'Bago'});
    await leave(tester);
  });

  testWidgets('the column names can be copied for a new spreadsheet', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await openHome(tester);
    await openData(tester);
    await tester.tap(find.byKey(const Key('import-template')));
    await tester.pumpAndSettle();
    expect(copied, productsCsvHeader);
    await leave(tester);
  });

  test('an exported product list can be pasted straight back in', () {
    // name, price, barcode, cost, stock, unit
    const csv = '$productsCsvHeader\r\nKape,12.50,4800016644801,9.00,24,pc\r\n"Itlog, malaki",9.00,,,,tray\r\n';
    final r = parseProductCsv(csv, 'PHP');
    expect(r.errors, isEmpty);
    expect(r.rows.map((e) => (e.name, e.price, e.barcode, e.cost, e.stock, e.unit)), [
      ('Kape', 1250, '4800016644801', 900, 24.0, 'pc'),
      ('Itlog, malaki', 900, null, null, null, 'tray'),
    ]);
  });
}
