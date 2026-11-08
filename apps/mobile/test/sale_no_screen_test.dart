import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'products_test.dart' show leave, openHome;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

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
}
