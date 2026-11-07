import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';

import 'products_test.dart' show leave, openHome;

/// Adds "Yosi" (price 100) sold by piece: 20 pieces per pack, piece price 8, through the product form.
Future<(DriftStore, ProductView, ProductView)> addTingiProduct(WidgetTester tester) async {
  final store = await openHome(tester);
  await tester.tap(find.byKey(const Key('tile-products')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('add-product')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('field-name')), 'Yosi');
  await tester.enterText(find.byKey(const Key('field-price')), '100');
  final list = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(find.byKey(const Key('tingi-switch')), 200, scrollable: list);
  await tester.tap(find.byKey(const Key('tingi-switch')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(const Key('tingi-price')), 200, scrollable: list);
  await tester.enterText(find.byKey(const Key('tingi-pieces')), '20');
  await tester.enterText(find.byKey(const Key('tingi-price')), '8');
  await tester.tap(find.byKey(const Key('save-product')));
  await tester.pumpAndSettle();
  final all = await store.watchProducts().first;
  final pack = all.firstWhere((p) => p.name == 'Yosi');
  final piece = all.firstWhere((p) => p.name == 'Yosi (piece)');
  return (store, pack, piece);
}

Future<void> openStockAction(WidgetTester tester, ProductView pack, String action) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tile-stock')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('stock-${pack.id}')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(Key(action)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(action)));
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('the product form creates the piece product and links it to the pack', (tester) async {
    final (store, pack, piece) = await addTingiProduct(tester);
    expect(piece.price, 800);
    final linked = (await store.watchProducts().first).firstWhere((p) => p.id == pack.id);
    expect((linked.sellsByPiece, linked.piecesPerPack, linked.breaksIntoVariantId), (true, 20, piece.variantId));
    expect((await store.nextOps()).map((o) => o.kind), containsAllInOrder(['upsert_product', 'upsert_product', 'set_tingi_link']));
    await leave(tester);
  });

  testWidgets('open a pack: the preview, the warning when fewer were counted, and the stock moves', (tester) async {
    final (store, pack, piece) = await addTingiProduct(tester);
    await store.receiveStock(variantId: pack.variantId, qty: 2, cost: 10000, opId: 'in1');
    await openStockAction(tester, pack, 'action-open-pack');

    await tester.enterText(find.byKey(const Key('openpack-qty')), '3');
    await tester.pump();
    expect(find.byKey(const Key('openpack-warn')), findsOneWidget, reason: 'only 2 counted, still allowed');
    await tester.enterText(find.byKey(const Key('openpack-qty')), '1');
    await tester.pump();
    expect(find.byKey(const Key('openpack-warn')), findsNothing);
    expect(find.text('That makes 20 × Yosi (piece)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('openpack-ok')));
    await tester.pumpAndSettle();
    expect(find.text('20 pieces added to stock'), findsOneWidget);
    expect(await store.stockLeft(pack.variantId), 1);
    expect(await store.stockLeft(piece.variantId), 20);
    expect((await store.nextOps()).last.kind, 'open_pack');
    await leave(tester);
  });

  testWidgets('a bad pack count is refused, and an opening can be undone from the history', (tester) async {
    final (store, pack, piece) = await addTingiProduct(tester);
    await store.receiveStock(variantId: pack.variantId, qty: 2, cost: 10000, opId: 'in1');
    await openStockAction(tester, pack, 'action-open-pack');
    await tester.enterText(find.byKey(const Key('openpack-qty')), '0');
    await tester.tap(find.byKey(const Key('openpack-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('openpack-qty')), findsOneWidget, reason: 'dialog stays open');
    await tester.enterText(find.byKey(const Key('openpack-qty')), '1');
    await tester.tap(find.byKey(const Key('openpack-ok')));
    await tester.pumpAndSettle();
    expect(await store.stockLeft(piece.variantId), 20);

    await tester.tap(find.byKey(Key('stock-${pack.id}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('action-pack-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('action-pack-history')));
    await tester.pumpAndSettle();
    expect(find.text('1 pack → 20 × Yosi (piece)'), findsOneWidget);
    final c = (await store.watchConversions(from: DateTime(2000), to: DateTime(2100)).first).single;
    await tester.tap(find.byKey(Key('pack-${c.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pack-void-yes')));
    await tester.pumpAndSettle();
    expect(await store.stockLeft(piece.variantId), 0);
    expect(await store.stockLeft(pack.variantId), 2);
    expect(find.textContaining('Undone'), findsOneWidget);
    await leave(tester);
  });
}
