import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';
const _cus = '0190a000-0000-7000-8000-0000000000c1';
const _loc = '0190a000-0000-7000-8000-0000000000e1';

Map<String, dynamic> posPage({
  List<Map<String, dynamic>> levels = const [],
  List<Map<String, dynamic>> customers = const [],
  List<Map<String, dynamic>> ledger = const [],
  String serverTime = '2026-11-08T01:00:10+00:00',
  bool more = false,
}) {
  Map<String, dynamic> t(List rows, String k) => {
        'rows': rows,
        'cursor': rows.isEmpty ? null : {'ts': '2026-11-08T00:00:00+00:00', 'k': k},
        'has_more': more,
      };
  return {
    'server_time': serverTime,
    'stock_levels': t(levels, 'l'),
    'customers': t(customers, 'c'),
    'customer_ledger': t(ledger, 'g'),
  };
}

Map<String, dynamic> level(String variant, num qty, String at) =>
    {'location_id': _loc, 'variant_id': variant, 'qty_on_hand': qty, 'updated_at': at};

SaleDraft sale(String id, List<SaleLine> lines, List<PaymentDraft> pays, {int discount = 0, String? customerId, DateTime? at}) =>
    SaleDraft(id: id, soldAt: at ?? DateTime.now(), lines: lines, payments: pays, discount: discount, customerId: customerId);

SaleLine line(String variant, double qty, int price, {String name = 'Item', bool tracked = true, double tax = 0}) =>
    SaleLine(variantId: variant, name: name, qty: qty, unitPrice: price, unitCost: price ~/ 2, tracked: tracked, taxRate: tax);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape'), serverProduct(_p2, 'Asukal')],
      variants: [serverVariant(_v1, _p1, barcode: '111'), serverVariant(_v2, _p2)],
      prices: [serverPrice(_v1, 1500), serverPrice(_v2, 4500)],
    ));
  });
  tearDown(() => store.close());

  group('line math', () {
    test('quantity x price rounds half up in whole centavos', () {
      expect(line(_v1, 2, 1250).lineTotal, 2500);
      expect(line(_v1, 0.5, 4500).lineTotal, 2250);
      // 0.003 x 500 = 1.5 -> 2 (floating point would say 1.4999999999999998)
      expect(line(_v1, 0.003, 500).lineTotal, 2);
      expect(line(_v1, 1.25, 1001).lineTotal, 1251);
    });

    test('tax is the part of the price that is tax', () {
      expect(line(_v1, 1, 11200, tax: 0.12).lineTax, 1200);
      expect(line(_v1, 1, 1000).lineTax, 0);
    });

    test('draft totals', () {
      final d = sale('s', [line(_v1, 2, 1500), line(_v2, 1, 4500)], const [], discount: 500);
      expect(d.subtotal, 7500);
      expect(d.total, 7000);
    });
  });

  group('committing a sale', () {
    test('writes sale, lines, payments, stock effect and one outbox op together', () async {
      await store.applyPullPos(posPage(levels: [level(_v1, 10, '2026-11-08T00:00:00+00:00')]));
      final r = await store.commitSale(
        sale('s1', [line(_v1, 2, 1500, name: 'Kape')], [const PaymentDraft('cash', 3000, tendered: 5000)]),
        opId: 'op-s1',
      );
      expect(r.localNo, matches(RegExp(r'^[A-Z0-9]{3}-\d{6}-0001$')));

      final detail = (await store.getSale('s1'))!;
      expect(detail.summary.total, 3000);
      expect(detail.items.single.name, 'Kape');
      expect(detail.change, 2000);
      expect(detail.summary.pending, isTrue);

      expect(await store.stockLeft(_v1), 8);
      final op = (await store.nextOps()).single;
      expect(op.kind, 'record_sale');
      expect(op.entityId, 's1');
      expect(op.payload['location_id'], _loc);
      expect(op.payload['total'], 3000);
      expect((op.payload['items'] as List).single['line_total'], 3000);
      expect((op.payload['payments'] as List).single, {'method': 'cash', 'amount': 3000, 'tendered': 5000});
    });

    test('receipt numbers count up through the day and keep the device code', () async {
      final a = await store.commitSale(sale('a', [line(_v1, 1, 100)], [const PaymentDraft('cash', 100)]), opId: 'oa');
      final b = await store.commitSale(sale('b', [line(_v1, 1, 100)], [const PaymentDraft('cash', 100)]), opId: 'ob');
      expect(a.localNo.substring(0, 3), b.localNo.substring(0, 3));
      expect(a.localNo.endsWith('-0001'), isTrue);
      expect(b.localNo.endsWith('-0002'), isTrue);
    });

    test('a failed commit leaves nothing behind and does not use up a receipt number', () async {
      await store.commitSale(sale('dup', [line(_v1, 1, 100)], [const PaymentDraft('cash', 100)]), opId: 'o1');
      await expectLater(
        store.commitSale(sale('dup', [line(_v1, 5, 100)], [const PaymentDraft('cash', 500)]), opId: 'o2'),
        throwsA(anything),
      );
      expect((await store.nextOps()).map((o) => o.opId), ['o1']);
      expect(await store.stockLeft(_v1), -1);
      final next = await store.commitSale(sale('ok', [line(_v1, 1, 100)], [const PaymentDraft('cash', 100)]), opId: 'o3');
      expect(next.localNo.endsWith('-0002'), isTrue, reason: 'the failed attempt did not consume 0002');
    });

    test('bad drafts are refused before anything is written', () {
      expect(() => store.commitSale(sale('x', [], const []), opId: 'o'), throwsArgumentError);
      expect(() => store.commitSale(sale('x', [line(_v1, 1, 100)], [const PaymentDraft('cash', 90)]), opId: 'o'),
          throwsArgumentError);
      expect(() => store.commitSale(sale('x', [line(_v1, 1, 100)], [const PaymentDraft('utang', 100)]), opId: 'o'),
          throwsArgumentError, reason: 'utang needs a customer');
    });

    test('products that do not track stock take nothing from stock', () async {
      await store.commitSale(sale('s', [line(_v1, 3, 100, tracked: false)], [const PaymentDraft('cash', 300)]), opId: 'o');
      expect(await store.stockLeft(_v1), 0);
    });
  });

  group('utang', () {
    setUp(() async {
      await store.saveCustomer(id: _cus, name: 'Aling Rosa', phone: '0917', opId: 'oc');
    });

    test('a split sale puts the unpaid part on the customer; payments lower it', () async {
      await store.commitSale(
        sale('s1', [line(_v1, 2, 1500)], [const PaymentDraft('cash', 2000, tendered: 2000), const PaymentDraft('utang', 1000)],
            customerId: _cus),
        opId: 'o1',
      );
      expect((await store.watchCustomers().first).single.balance, 1000);
      await store.recordUtangPayment(customerId: _cus, amount: 400, note: 'bayad', opId: 'o2');
      final c = (await store.watchCustomers().first).single;
      expect(c.balance, 600);
      expect(c.pending, isTrue);

      final history = await store.watchLedger(_cus).first;
      expect(history.map((e) => e.kind), containsAll(['charge', 'payment']));
      expect(history.every((e) => e.pending), isTrue);
    });

    test('customers with a balance are listed first, biggest first', () async {
      await store.saveCustomer(id: 'c2', name: 'Berto', opId: 'oc2');
      await store.saveCustomer(id: 'c3', name: 'Carmen', opId: 'oc3');
      await store.commitSale(sale('a', [line(_v1, 1, 500)], [const PaymentDraft('utang', 500)], customerId: 'c3'), opId: 'oa');
      await store.commitSale(sale('b', [line(_v1, 1, 900)], [const PaymentDraft('utang', 900)], customerId: _cus), opId: 'ob');
      expect((await store.watchCustomers().first).map((c) => c.name), ['Aling Rosa', 'Carmen', 'Berto']);
    });

    test('a server ledger row and its local effect never count twice', () async {
      await store.commitSale(sale('s1', [line(_v1, 1, 1000)], [const PaymentDraft('utang', 1000)], customerId: _cus), opId: 'o1');
      await store.posOpApplied('o1', '2026-11-08T01:00:00+00:00');
      // the pull that brings the row also clears the local effect
      await store.applyPullPos(posPage(ledger: [
        {
          'id': 'g1', 'customer_id': _cus, 'kind': 'charge', 'amount': 1000, 'sale_id': 's1', 'note': null,
          'occurred_at': '2026-11-08T01:00:00+00:00', 'created_at': '2026-11-08T01:00:00+00:00',
        }
      ]));
      expect((await store.watchCustomers().first).single.balance, 1000);
      expect(await store.db.select(store.db.localLedger).get(), isEmpty);
    });
  });

  group('stock shown on the screen', () {
    test('server level + effects the server has not caught up on, never twice', () async {
      await store.applyPullPos(posPage(levels: [level(_v1, 10, '2026-11-08T00:00:00+00:00')]));
      await store.commitSale(sale('s1', [line(_v1, 2, 100)], [const PaymentDraft('cash', 200)]), opId: 'o1');
      expect(await store.stockLeft(_v1), 8);

      // op accepted at 01:00:00, but the pull is too early to contain it (hold-back): still 8, not 10
      await store.posOpApplied('o1', '2026-11-08T01:00:00+00:00');
      await store.applyPullPos(posPage(levels: [], serverTime: '2026-11-08T01:00:03+00:00'));
      expect(await store.stockLeft(_v1), 8);

      // a complete pull whose level row is older than the op: keep counting the effect
      await store.applyPullPos(posPage(serverTime: '2026-11-08T01:10:00+00:00'));
      expect(await store.stockLeft(_v1), 8);

      // a pull in several pages is not complete: effect stays
      await store.applyPullPos(posPage(levels: [level(_v1, 8, '2026-11-08T01:00:00+00:00')], serverTime: '2026-11-08T01:20:00+00:00', more: true));
      expect(await store.stockLeft(_v1), 6, reason: 'transient while more pages follow');

      // the complete pull with the new level: the effect is dropped and the number is right
      await store.applyPullPos(posPage(serverTime: '2026-11-08T01:30:00+00:00'));
      expect(await store.stockLeft(_v1), 8);
      expect(await store.db.select(store.db.localMovements).get(), isEmpty);
    });

    test('watchStock lists every variant with a count', () async {
      await store.applyPullPos(posPage(levels: [level(_v1, 5, '2026-11-08T00:00:00+00:00')]));
      await store.commitSale(sale('s1', [line(_v1, 1, 100), line(_v2, 2, 100)], [const PaymentDraft('cash', 300)]), opId: 'o1');
      expect(await store.watchStock().first, {_v1: 4.0, _v2: -2.0});
    });
  });

  group('cancelling a sale', () {
    test('puts stock and utang back and queues one op', () async {
      await store.saveCustomer(id: _cus, name: 'Aling Rosa', opId: 'oc');
      await store.applyPullPos(posPage(levels: [level(_v1, 10, '2026-11-08T00:00:00+00:00')]));
      await store.commitSale(sale('s1', [line(_v1, 3, 100)], [const PaymentDraft('utang', 300)], customerId: _cus), opId: 'o1');
      expect(await store.stockLeft(_v1), 7);

      await store.voidSale('s1', opId: 'o2', reason: 'mali');
      expect(await store.stockLeft(_v1), 10);
      expect((await store.watchCustomers().first).single.balance, 0);
      expect((await store.getSale('s1'))!.summary.voided, isTrue);
      expect((await store.nextOps()).map((o) => o.kind), ['upsert_customer', 'record_sale', 'void_sale']);
      await expectLater(store.voidSale('s1', opId: 'o3'), throwsStateError);
    });

    test('cancelled sales are left out of today\'s totals', () async {
      await store.commitSale(sale('a', [line(_v1, 1, 1000)], [const PaymentDraft('cash', 1000)]), opId: 'oa');
      await store.commitSale(sale('b', [line(_v1, 1, 500)], [const PaymentDraft('ewallet', 500)]), opId: 'ob');
      await store.voidSale('b', opId: 'ov');
      final t = await store.watchToday().first;
      expect((t.count, t.total, t.cash, t.ewallet), (1, 1000, 1000, 0));
    });
  });

  group('quick items', () {
    test('most sold first, topped up with the rest', () async {
      await store.commitSale(sale('a', [line(_v2, 5, 100)], [const PaymentDraft('cash', 500)]), opId: 'oa');
      await store.commitSale(sale('b', [line(_v1, 1, 100)], [const PaymentDraft('cash', 100)]), opId: 'ob');
      expect((await store.quickItems()).map((p) => p.variantId), [_v2, _v1]);
      expect((await store.quickItems(limit: 1)).single.variantId, _v2);
    });
  });

  group('opening stock', () {
    test('typed at product add: one real op, shown as stock, never asked twice', () async {
      const draft = ProductDraft(id: 'p9', variantId: '0190a000-0000-7000-8000-0000000000a9', name: 'Itlog', price: 900, openingQty: 30);
      await store.saveProduct(draft, opId: 'op-a');
      await store.saveProduct(draft, opId: 'op-b');
      final kinds = (await store.nextOps()).map((o) => o.kind).toList();
      expect(kinds.where((k) => k == 'post_opening_stock'), hasLength(1));
      expect(await store.stockLeft(draft.variantId), 30);
    });

    test('opening stock saved by an older version is turned into ops on upgrade', () async {
      final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
        raw.execute('CREATE TABLE variants (id TEXT NOT NULL PRIMARY KEY, product_id TEXT NOT NULL, sku TEXT NOT NULL, '
            'barcode TEXT NULL, is_default INTEGER NOT NULL DEFAULT 1, cost INTEGER NOT NULL DEFAULT 0, '
            'reorder_point REAL NOT NULL DEFAULT 0, active INTEGER NOT NULL DEFAULT 1, updated_at TEXT NULL, deleted_at TEXT NULL)');
        raw.execute('CREATE TABLE outbox (op_id TEXT NOT NULL UNIQUE, seq INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, '
            "entity_id TEXT NOT NULL, payload TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', "
            'attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT NULL, created_at INTEGER NOT NULL)');
        raw.execute('CREATE TABLE opening_stock (variant_id TEXT NOT NULL PRIMARY KEY, qty REAL NOT NULL)');
        raw.execute("INSERT INTO variants (id, product_id, sku) VALUES ('v1', 'p1', 'S1')");
        raw.execute("INSERT INTO opening_stock VALUES ('v1', 12), ('gone', 5)");
        raw.execute('PRAGMA user_version = 3');
      }));
      final old = DriftStore(db);
      final ops = await old.nextOps();
      expect(ops.single.kind, 'post_opening_stock');
      expect(ops.single.entityId, 'p1');
      expect(await old.stockLeft('v1'), 12);
      expect(await db.select(db.openingStock).get(), isEmpty);
      await old.close();
    });
  });
}
