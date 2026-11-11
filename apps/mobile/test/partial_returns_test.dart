import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'sales_store_test.dart' show level, line, posPage, sale;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';
const _cus = '0190a000-0000-7000-8000-0000000000c1';
const _loc = '0190a000-0000-7000-8000-0000000000e1';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape'), serverProduct(_p2, 'Asukal')],
      variants: [serverVariant(_v1, _p1, barcode: '111'), serverVariant(_v2, _p2)],
      prices: [serverPrice(_v1, 5000), serverPrice(_v2, 10000)],
    ));
    await store.applyPullPos(posPage(
      levels: [
        level(_v1, 10, '2026-11-08T00:00:00+00:00'),
        level(_v2, 5, '2026-11-08T00:00:00+00:00'),
      ],
      customers: [
        {
          'id': _cus,
          'name': 'Aling Nena',
          'phone': '09171234567',
          'credit_limit': 500000,
          'due_date': null,
          'updated_at': '2026-11-08T00:00:00+00:00',
          'deleted_at': null,
        },
      ],
    ));
  });

  tearDown(() => store.close());

  test('partial return restores stock, computes pro-rata cart discount, queues outbox op, and blocks full void', () async {
    // 2x Kape @ 50.00 (100.00) + 1x Asukal @ 100.00 (100.00) = 200.00 subtotal - 20.00 discount = 180.00 total
    await store.commitSale(
      sale(
        's-ret-1',
        [
          line(_v1, 2, 5000, name: 'Kape'),
          line(_v2, 1, 10000, name: 'Asukal'),
        ],
        const [PaymentDraft('cash', 18000, tendered: 20000)],
        discount: 2000,
      ),
      opId: 'op-sale-1',
    );
    expect(await store.stockLeft(_v1), 8);
    expect(await store.stockLeft(_v2), 4);

    // Return 1x Kape: lineSub = 5000, cartDisc share = round(2000 * 5000 / 20000) = 500 -> refund = 4500
    final refunded1 = await store.returnSaleItems(
      's-ret-1',
      items: const [SaleReturnLine(variantId: _v1, qty: 1)],
      refundMethod: 'cash',
      reason: 'Damaged sachet',
      opId: 'op-ret-1',
    );
    expect(refunded1, 4500);
    expect(await store.stockLeft(_v1), 9);

    final afterFirst = (await store.getSale('s-ret-1'))!;
    expect(afterFirst.refundedTotal, 4500);
    expect(afterFirst.hasPartialReturns, isTrue);
    expect(afterFirst.hasReturnableItems, isTrue);
    final kapeItem = afterFirst.items.firstWhere((i) => i.variantId == _v1);
    expect(kapeItem.returnedQty, 1);
    expect(kapeItem.remainingQty, 1);

    // Full void is blocked once partial returns exist
    await expectLater(
      store.voidSale('s-ret-1', opId: 'op-void-blocked'),
      throwsA(isA<StateError>()),
    );

    // Over-returning beyond remaining qty throws StateError
    await expectLater(
      store.returnSaleItems(
        's-ret-1',
        items: const [SaleReturnLine(variantId: _v1, qty: 2)],
        refundMethod: 'cash',
        opId: 'op-ret-over',
      ),
      throwsA(isA<StateError>()),
    );

    // Returning the rest of the sale reconciles exact remaining centavos (18000 - 4500 = 13500)
    final refunded2 = await store.returnSaleItems(
      's-ret-1',
      items: const [
        SaleReturnLine(variantId: _v1, qty: 1),
        SaleReturnLine(variantId: _v2, qty: 1),
      ],
      refundMethod: 'cash',
      opId: 'op-ret-2',
    );
    expect(refunded2, 13500);
    expect(await store.stockLeft(_v1), 10);
    expect(await store.stockLeft(_v2), 5);

    final afterAll = (await store.getSale('s-ret-1'))!;
    expect(afterAll.refundedTotal, 18000);
    expect(afterAll.hasReturnableItems, isFalse);

    final ops = await store.nextOps(limit: 10);
    final returnOps = ops.where((o) => o.kind == 'return_sale_items').toList();
    expect(returnOps.length, 2);
    expect(returnOps.first.payload['refund_method'], 'cash');
    expect(returnOps.first.payload['reason'], 'Damaged sachet');
  });

  test('utang partial return credits customer balance offline', () async {
    await store.commitSale(
      sale(
        's-utang-1',
        [line(_v1, 2, 5000, name: 'Kape')],
        const [PaymentDraft('utang', 10000)],
        customerId: _cus,
      ),
      opId: 'op-sale-u1',
    );
    final customersBefore = await store.watchCustomers().first;
    expect(customersBefore.single.balance, 10000);

    final refunded = await store.returnSaleItems(
      's-utang-1',
      items: const [SaleReturnLine(variantId: _v1, qty: 1)],
      refundMethod: 'utang',
      opId: 'op-ret-u1',
    );
    expect(refunded, 5000);

    final customersAfter = await store.watchCustomers().first;
    expect(customersAfter.single.balance, 5000);
  });
}
