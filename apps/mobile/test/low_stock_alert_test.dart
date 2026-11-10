import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;
import 'sales_store_test.dart' show level, posPage;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('low-stock badge and reorder alert are displayed, action sheet offers restock transfer', (tester) async {
    final store = await openHome(tester);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape 3-in-1'), serverProduct(_p2, 'Asukal')],
      variants: [
        {...serverVariant(_v1, _p1), 'reorder_point': 10},
        serverVariant(_v2, _p2),
      ],
      prices: [serverPrice(_v1, 1200), serverPrice(_v2, 1500)],
    ));
    // Receive 3 units of Kape (below reorder point of 10)
    await store.applyPullPos(posPage(levels: [
      level(_v1, 3, '2026-11-08T00:00:00+00:00'),
      level(_v2, 20, '2026-11-08T00:00:00+00:00'),
    ]));

    // Open Stock screen
    await tester.tap(find.byKey(const Key('tile-stock')));
    await tester.pumpAndSettle();

    // Verify low-stock badge and reorder alert on Kape
    expect(find.byKey(const Key('low-stock-badge-$_p1')), findsOneWidget);
    expect(find.byKey(const Key('reorder-alert-$_p1')), findsOneWidget);
    expect(find.text('Below reorder threshold (3 / min 10)'), findsOneWidget);

    // Asukal is healthy, so no badge
    expect(find.byKey(const Key('low-stock-badge-$_p2')), findsNothing);

    // Tap on Kape to open action sheet
    await tester.tap(find.byKey(const Key('stock-$_p1')));
    await tester.pumpAndSettle();

    // Verify request restock transfer action is offered
    expect(find.byKey(const Key('action-request-transfer')), findsOneWidget);

    // Tap restock transfer
    await tester.tap(find.byKey(const Key('action-request-transfer')));
    await tester.pumpAndSettle();

    // Verify TransferCreateScreen is opened with pre-filled line
    expect(find.text('New Outbound Transfer'), findsOneWidget);
    expect(find.text('Kape 3-in-1'), findsOneWidget);

    await leave(tester);
  });
}
