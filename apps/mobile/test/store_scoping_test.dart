import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/store_session.dart' show storesOf;

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'expenses_test.dart' show pgTs;

// F-01: one active store per device; every store-sensitive read and write follows it.

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';
const _cus = '0190a000-0000-7000-8000-0000000000c1';
const _a = '0190a000-0000-7000-8000-0000000000e1';
const _b = '0190a000-0000-7000-8000-0000000000e2';
const _x = '0190a000-0000-7000-8000-0000000000e9'; // a store of the tenant this user is not assigned to

const _storeA = StoreRef(id: _a, name: 'Tindahan A');
const _storeB = StoreRef(id: _b, name: 'Tindahan B');

SaleDraft _sale(String id, String variant, int amount, {String method = 'cash', String? wallet, String? customer}) => SaleDraft(
      id: id,
      soldAt: DateTime.now(),
      lines: [SaleLine(variantId: variant, name: 'Item', qty: 1, unitPrice: amount)],
      payments: [PaymentDraft(method, amount, wallet: wallet)],
      customerId: customer,
    );

Map<String, dynamic> _level(String loc, String variant, num qty) => {
      'location_id': loc, 'variant_id': variant, 'qty_on_hand': qty, 'avg_cost': null, 'counted': true,
      'updated_at': '2026-11-08T00:00:00+00:00',
    };

Map<String, dynamic> _ledger(String id, int amount, {String kind = 'payment', String? loc, String? method}) => {
      'id': id, 'customer_id': _cus, 'kind': kind, 'amount': amount, 'sale_id': null, 'note': null,
      'occurred_at': pgTs(DateTime.now()), 'created_at': '2026-11-08T00:00:00+00:00',
      'location_id': ?loc, 'method': ?method,
    };

Map<String, dynamic> _pos({
  List<Map<String, dynamic>> levels = const [],
  List<Map<String, dynamic>> ledger = const [],
  List<Map<String, dynamic>> customers = const [],
  List<Map<String, dynamic>> expiry = const [],
}) {
  Map<String, dynamic> t(List rows) => {'rows': rows, 'cursor': {'ts': '2026-11-08T00:00:00+00:00', 'k': 'z'}, 'has_more': false};
  return {
    'server_time': '2026-11-08T00:00:10+00:00',
    'stock_levels': t(levels),
    'customers': t(customers),
    'customer_ledger': t(ledger),
    'stock_expiry': t(expiry),
  };
}

Map<String, dynamic> _serverSale(String id, String no, int total, {String? loc}) => {
      'id': id, 'location_id': ?loc, 'local_no': no, 'status': 'completed', 'subtotal': total, 'discount': 0, 'tax': 0,
      'total': total, 'customer_id': null, 'sold_at': pgTs(DateTime.now()), 'voided_at': null, 'void_reason': null,
      'items': [
        {'variant_id': _v1, 'name': 'Kape', 'qty': 1, 'unit_price': total, 'unit_cost': 0, 'discount': 0, 'tax': 0,
         'line_total': total, 'tracked': true},
      ],
      'payments': [
        {'method': 'cash', 'amount': total, 'tendered': total, 'reference': null},
      ],
    };

Future<void> _seedCatalog(DriftStore s) => s.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape'), serverProduct(_p2, 'Asukal')],
      variants: [serverVariant(_v1, _p1), serverVariant(_v2, _p2)],
      prices: [serverPrice(_v1, 1000), serverPrice(_v2, 2000)],
    ));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;
  DateTime today() => DateTime.now();

  Future<Map<String, int>> floats() async =>
      {for (final f in await store.watchWalletFloat().first) f.wallet: f.balance};
  Future<List<String>> saleIds() async => [for (final s in await store.watchSales().first) s.id]..sort();
  Future<double?> listQty(String variant) async =>
      (await store.watchStockList().first).firstWhere((r) => r.product.variantId == variant).qty;

  group('two stores', () {
    setUp(() async {
      store = DriftStore(AppDatabase(NativeDatabase.memory()));
      await store.ensureTenant('tenant-a', baseCurrency: 'PHP', stores: const [_storeA, _storeB]);
      await _seedCatalog(store);
    });
    tearDown(() => store.close());

    test('the first assigned store is active; only assigned stores can be picked; the choice is kept', () async {
      expect(store.activeLocationId, _a);
      expect(await store.myStores(), const [_storeA, _storeB]);
      expect(await store.watchActiveStore().first, _a);

      await expectLater(store.setActiveStore(_x), throwsArgumentError);
      expect((store.activeLocationId, await store.meta('active_location_id')), (_a, _a), reason: 'a refused pick changes nothing');

      await store.setActiveStore(_b);
      expect((store.activeLocationId, await store.watchActiveStore().first), (_b, _b));
      // next sign-in on this device: the same stores, the choice stays
      await store.ensureTenant('tenant-a', baseCurrency: 'PHP', stores: const [_storeA, _storeB]);
      expect(store.activeLocationId, _b);
      // the user lost store B: back to the first one they still have
      await store.ensureTenant('tenant-a', baseCurrency: 'PHP', stores: const [_storeA]);
      expect(store.activeLocationId, _a);
      expect(await store.myStores(), const [_storeA]);
      await expectLater(store.setActiveStore(_b), throwsArgumentError);
    });

    test('switching the store changes Today, sales, expected cash, stock, float, expenses, services and quick tiles', () async {
      await store.applyPullPos(_pos(levels: [_level(_a, _v1, 10), _level(_b, _v1, 4)]));
      await store.applyPullService({
        'rows': const [],
        'floats': [
          {'location_id': _a, 'wallet': 'gcash', 'balance': 10000, 'txn_count': 1, 'updated_at': null},
          {'location_id': _b, 'wallet': 'gcash', 'balance': 3000, 'txn_count': 1, 'updated_at': null},
        ],
        'server_time': '2026-11-08T00:00:10+00:00',
        'cursor': null,
      });

      // store A: two sales of Kape (cash, e-wallet into gcash) and a cash expense
      await store.commitSale(_sale('a1', _v1, 1000), opId: 'oa1');
      await store.commitSale(_sale('a2', _v1, 500, method: 'ewallet', wallet: 'gcash'), opId: 'oa2');
      await store.recordExpense(id: 'ea', amount: 300, category: 'other', opId: 'oea');
      // store B: two sales of Asukal and a cash-in
      await store.setActiveStore(_b);
      await store.commitSale(_sale('b1', _v2, 2000), opId: 'ob1');
      await store.commitSale(_sale('b2', _v2, 1500), opId: 'ob2');
      await store.recordServiceTxn(id: 'tb', kind: 'cash_in', wallet: 'gcash', amount: 1000, fee: 20, opId: 'otb');

      Future<void> expectB() async {
        final t = await store.watchToday().first;
        expect((t.count, t.total, t.cash, t.ewallet), (2, 3500, 3500, 0));
        expect(await saleIds(), ['b1', 'b2']);
        expect(await store.expectedCash(today(), openingCash: 0), 3500 + 1020);
        expect(await store.stockLeft(_v1), 4);
        expect((await store.watchStock().first)[_v1], 4);
        expect(await listQty(_v1), 4);
        expect(await floats(), {'gcash': 3000 - 1000});
        expect((await store.watchTodayExpenses().first).total, 0);
        expect((await store.watchTodayServices().first).count, 1);
        expect((await store.quickItems()).first.variantId, _v2, reason: 'B sells Asukal most');
      }

      Future<void> expectA() async {
        final t = await store.watchToday().first;
        expect((t.count, t.total, t.cash, t.ewallet), (2, 1500, 1000, 500));
        expect(await saleIds(), ['a1', 'a2']);
        expect(await store.expectedCash(today(), openingCash: 0), 1000 - 300);
        expect(await store.stockLeft(_v1), 8);
        expect((await store.watchStock().first)[_v1], 8);
        expect(await listQty(_v1), 8);
        expect(await floats(), {'gcash': 10000 + 500});
        expect((await store.watchTodayExpenses().first).total, 300);
        expect((await store.watchTodayServices().first).count, 0);
        expect((await store.quickItems()).first.variantId, _v1, reason: 'A sells Kape most');
      }

      await expectB();
      await store.setActiveStore(_a);
      await expectA();
      await store.setActiveStore(_b);
      await expectB();
    });

    test('a watched figure follows a store switch without subscribing again', () async {
      await store.commitSale(_sale('a1', _v1, 1000), opId: 'oa1');
      final seen = <int>[];
      final sub = store.watchToday().listen((t) => seen.add(t.total));
      final cash = <int>[];
      final sub2 = store.watchExpectedCash(today(), openingCash: 0).listen(cash.add);
      await pumpEventQueue();
      await store.setActiveStore(_b);
      await pumpEventQueue();
      await store.commitSale(_sale('b1', _v2, 2000), opId: 'ob1');
      await pumpEventQueue();
      await sub.cancel();
      await sub2.cancel();
      expect(seen.first, 1000);
      expect(seen.last, 2000);
      expect(seen, contains(0), reason: 'store B before its first sale');
      expect((cash.first, cash.last), (1000, 2000));
    });

    test('ops queued for store A keep store A after switching to B; a void puts stock back at the sale\'s store', () async {
      await store.applyPullPos(_pos(levels: [_level(_a, _v1, 10), _level(_b, _v1, 4)]));
      await store.commitSale(_sale('a1', _v1, 1000), opId: 'oa1');
      await store.recordExpense(id: 'ea', amount: 300, category: 'other', opId: 'oea');
      await store.receiveStock(variantId: _v1, qty: 3, opId: 'ora');
      await store.setExpiry(variantId: _v1, expiresOn: DateTime(today().year + 1, 1, 15), opId: 'oxa');
      await store.closeDay(id: 'dca', day: today(), countedCash: 700, openingCash: 0, opId: 'oda');
      final before = [for (final o in await store.nextOps()) (o.opId, jsonEncode(o.payload))];
      expect([for (final o in await store.nextOps()) o.payload['location_id']], everyElement(_a));

      await store.setActiveStore(_b);
      expect([for (final o in await store.nextOps()) (o.opId, jsonEncode(o.payload))], before, reason: 'switching touches no op');
      expect(await store.stockLeft(_v1), 4, reason: 'B sees its own stock');
      expect((await store.watchStockList().first).firstWhere((r) => r.product.variantId == _v1).expiresOn, isNull,
          reason: 'A\'s expiry date is A\'s');
      expect(await store.watchLatestDayClose(today()).first, isNull, reason: 'A\'s close is A\'s');

      await store.voidSale('a1', opId: 'va1');
      final v = (await store.nextOps()).last;
      expect((v.kind, v.payload['location_id']), ('void_sale', _a), reason: 'the void names the sale\'s store');
      expect(await store.stockLeft(_v1), 4, reason: 'B unchanged');
      await store.setActiveStore(_a);
      expect(await store.stockLeft(_v1), 10 + 3, reason: 'the cancelled sale\'s stock is back at A');
      expect((await store.watchLatestDayClose(today()).first)!.countedCash, 700);
    });

    test('utang payments: per store, cash vs e-wallet; balances stay tenant-wide', () async {
      await store.applyPullPos(_pos(
        customers: [
          {'id': _cus, 'name': 'Rosa', 'phone': null, 'due_on': null, 'updated_at': '2026-11-08T00:00:00+00:00', 'deleted_at': null},
        ],
        ledger: [
          _ledger('g0', 5000, kind: 'charge', loc: _a),
          _ledger('g1', -400, loc: _a, method: 'cash'),
          _ledger('g2', -700, loc: _b, method: 'cash'),
          _ledger('g3', -250, loc: _a, method: 'ewallet'),
        ],
      ));
      await store.recordUtangPayment(customerId: _cus, amount: 100, opId: 'pa1');
      await store.recordUtangPayment(customerId: _cus, amount: 50, method: 'ewallet', opId: 'pa2');
      expect(() => store.recordUtangPayment(customerId: _cus, amount: 10, method: 'card', opId: 'px'), throwsArgumentError);
      await store.setActiveStore(_b);
      await store.recordUtangPayment(customerId: _cus, amount: 30, opId: 'pb1');

      expect(await store.expectedCash(today(), openingCash: 0), 700 + 30, reason: 'B: only B\'s cash payments');
      final balanceB = (await store.watchCustomers().first).single.balance;
      await store.setActiveStore(_a);
      expect(await store.expectedCash(today(), openingCash: 0), 400 + 100, reason: 'A: e-wallet payments are not cash');
      expect((await store.watchCustomers().first).single.balance, balanceB, reason: 'one balance for every store');
      expect(balanceB, 5000 - 400 - 700 - 250 - 100 - 50 - 30);

      final ops = {for (final o in await store.nextOps()) o.opId: o.payload};
      expect(ops.keys, ['pa1', 'pa2', 'pb1'], reason: 'nothing queued for the refused method');
      expect((ops['pa1']!['location_id'], ops['pa1']!['method']), (_a, 'cash'));
      expect((ops['pa2']!['location_id'], ops['pa2']!['method']), (_a, 'ewallet'));
      expect((ops['pb1']!['location_id'], ops['pb1']!['method']), (_b, 'cash'));
    });

    test('pulled rows of every store are kept and shown at their own store only', () async {
      await store.applyPullSales({
        'rows': [_serverSale('sa', 'X-0001', 1200, loc: _a), _serverSale('sb', 'X-0002', 800, loc: _b)],
        'cursor': {'ts': '2026-11-08T00:00:00+00:00', 'k': 'z'},
        'has_more': false,
      });
      await store.applyPullPos(_pos(expiry: [
        {'location_id': _a, 'variant_id': _v1, 'expires_on': '2027-01-01', 'updated_at': '2026-11-08T00:00:00+00:00'},
        {'location_id': _b, 'variant_id': _v1, 'expires_on': '2027-02-02', 'updated_at': '2026-11-08T00:00:00+00:00'},
        {'location_id': _a, 'variant_id': _v2, 'expires_on': '2027-03-03', 'updated_at': '2026-11-08T00:00:00+00:00'},
      ], levels: [_level(_a, _v1, 1), _level(_b, _v1, 1), _level(_a, _v2, 1), _level(_b, _v2, 1)]));
      expect(await store.db.select(store.db.stockExpiry).get(), hasLength(3), reason: 'every store the user can see');
      Future<(DateTime?, DateTime?)> dates() async {
        final rows = await store.watchStockList().first;
        DateTime? d(String v) => rows.firstWhere((r) => r.product.variantId == v).expiresOn;
        return (d(_v1), d(_v2));
      }

      expect(await saleIds(), ['sa']);
      expect((await store.watchToday().first).total, 1200);
      expect(await dates(), (DateTime(2027, 1, 1), DateTime(2027, 3, 3)));
      await store.setActiveStore(_b);
      expect(await saleIds(), ['sb']);
      expect((await store.watchToday().first).total, 800);
      expect(await dates(), (DateTime(2027, 2, 2), null));
    });

    test('tingi openings and their stock belong to the store where the pack was opened', () async {
      await store.applyPullPos(_pos(levels: [_level(_a, _v1, 5), _level(_b, _v1, 5)]));
      await store.setTingiLink(variantId: _v1, pieceVariantId: _v2, piecesPerPack: 10, opId: 'tl');
      await store.openPack(id: 'cv1', packVariantId: _v1, packs: 2, opId: 'op1');
      expect((await store.nextOps()).last.payload['location_id'], _a);
      final day = (DateTime(today().year, today().month, today().day), DateTime(today().year, today().month, today().day + 1));
      expect((await store.watchConversions(from: day.$1, to: day.$2).first).map((c) => c.id), ['cv1']);
      expect((await store.stockLeft(_v1), await store.stockLeft(_v2)), (3, 20));
      await store.setActiveStore(_b);
      expect(await store.watchConversions(from: day.$1, to: day.$2).first, isEmpty);
      expect((await store.stockLeft(_v1), await store.stockLeft(_v2)), (5, 0));
      await store.voidOpenPack(conversionId: 'cv1', opId: 'op2'); // undone while B is active: back at A
      expect((await store.stockLeft(_v1), await store.stockLeft(_v2)), (5, 0));
      await store.setActiveStore(_a);
      expect((await store.stockLeft(_v1), await store.stockLeft(_v2)), (5, 0));
    });
  });

  group('one store', () {
    setUp(() async {
      store = DriftStore(AppDatabase(NativeDatabase.memory()));
      await store.ensureTenant('tenant-a', baseCurrency: 'PHP', stores: const [_storeA]);
      await _seedCatalog(store);
    });
    tearDown(() => store.close());

    test('needs no choice and behaves as before: rows that name no store are its own', () async {
      expect(store.activeLocationId, _a);
      expect(await store.myStores(), const [_storeA]);
      // an older server's rows name no store or method
      await store.applyPullSales({
        'rows': [_serverSale('s0', 'X-0001', 1200)],
        'cursor': {'ts': '2026-11-08T00:00:00+00:00', 'k': 'z'},
        'has_more': false,
      });
      await store.applyPullPos(_pos(ledger: [_ledger('g1', -400)]));
      await store.commitSale(_sale('s1', _v1, 1000), opId: 'o1');
      expect(await saleIds(), ['s0', 's1']);
      expect(await store.expectedCash(today(), openingCash: 0), 1200 + 1000 + 400);
      expect((await store.nextOps()).single.payload['location_id'], _a);
      final rows = await store.db.select(store.db.serverLedger).get();
      expect((rows.single.locationId, rows.single.method), (_a, 'cash'));
    });

    test('a user with no store (warehouse only, or nothing given) sees everything, unfiltered, like before F-01', () async {
      await store.commitSale(_sale('s1', _v1, 1000), opId: 'o1');
      await store.ensureTenant('tenant-a', baseCurrency: 'PHP', stores: const []);
      expect(store.activeLocationId, isNull);
      expect(await saleIds(), ['s1']);
      await store.commitSale(_sale('s2', _v1, 500), opId: 'o2');
      expect((await store.nextOps()).last.payload.containsKey('location_id'), isFalse,
          reason: 'no store to name: the server picks the user\'s only store or refuses (location_required)');
      expect(await saleIds(), ['s1', 's2']);
    });
  });

  test('storesOf keeps the stores of the access payload, in its order, and leaves warehouses out', () {
    expect(
      storesOf({
        'locations': [
          {'id': _a, 'type': 'store', 'code': 'S01', 'name': 'Tindahan A'},
          {'id': 'w', 'type': 'warehouse', 'code': 'W01', 'name': 'Bodega'},
          {'id': _b, 'type': 'store', 'code': 'S02', 'name': null},
        ],
      }),
      const [_storeA, StoreRef(id: _b, name: 'S02')],
    );
    expect(storesOf(const {}), isEmpty);
  });

  group('upgrading a v12 database', () {
    /// Takes a v13 database file back to the v12 layout (no store columns, expiry keyed by variant) and closes it.
    Future<void> toV12(DriftStore s) async {
      final db = s.db;
      await db.customStatement('drop index if exists sales_location_sold_at');
      for (final (t, c) in [
        ('sales', 'location_id'), ('local_movements', 'location_id'), ('local_ledger', 'location_id'),
        ('local_ledger', 'method'), ('server_ledger', 'location_id'), ('server_ledger', 'method'),
        ('local_float_effects', 'location_id'),
      ]) {
        await db.customStatement('alter table $t drop column $c');
      }
      await db.customStatement('create table se_old (variant_id TEXT NOT NULL PRIMARY KEY, location_id TEXT NULL, '
          'expires_on TEXT NULL, updated_at TEXT NULL)');
      await db.customStatement(
          "insert into se_old select variant_id, nullif(location_id, ''), expires_on, updated_at from stock_expiry");
      await db.customStatement('drop table stock_expiry');
      await db.customStatement('alter table se_old rename to stock_expiry');
      await db.customStatement("insert or replace into sync_cursors values ('sales', '{}'), ('customer_ledger', '{}'), "
          "('stock_expiry', '{}'), ('stock_levels', '{}')");
      await db.customStatement('PRAGMA user_version = 12');
      await s.close();
    }

    test('two stores: every row and unsent op is kept; local rows take their store from their op', () async {
      final dir = Directory.systemTemp.createTempSync('xzpos_v12_');
      final file = File('${dir.path}/app.sqlite');
      final v12 = DriftStore(AppDatabase(NativeDatabase(file)));
      await v12.ensureTenant('tenant-a', baseCurrency: 'PHP', stores: const [_storeA, _storeB]);
      await _seedCatalog(v12);
      await v12.applyPullPos(_pos(
        levels: [_level(_a, _v1, 10), _level(_b, _v1, 4)],
        customers: [
          {'id': _cus, 'name': 'Rosa', 'phone': null, 'due_on': null, 'updated_at': '2026-11-08T00:00:00+00:00', 'deleted_at': null},
        ],
        ledger: [_ledger('g1', -400, loc: _b, method: 'cash')],
      ));
      await v12.commitSale(_sale('a1', _v1, 1000), opId: 'oa1');
      await v12.commitSale(_sale('a2', _v1, 500, method: 'ewallet', wallet: 'gcash'), opId: 'oa2');
      await v12.setActiveStore(_b);
      await v12.commitSale(_sale('b1', _v1, 2000), opId: 'ob1');
      await v12.recordUtangPayment(customerId: _cus, amount: 100, opId: 'pb1');
      await v12.setExpiry(variantId: _v1, expiresOn: DateTime(today().year + 1, 5, 1), opId: 'xb1');
      final ops = [for (final o in await v12.nextOps()) (o.opId, jsonEncode(o.payload))];
      await toV12(v12);

      final v13 = DriftStore(AppDatabase(NativeDatabase(file)));
      await v13.ensureTenant('tenant-a', baseCurrency: 'PHP', stores: const [_storeA, _storeB]); // same tenant: nothing cleared
      final version = await v13.db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, v13.db.schemaVersion);
      expect([for (final o in await v13.nextOps()) (o.opId, jsonEncode(o.payload))], ops, reason: 'unsent ops survive unchanged');
      expect({for (final s in await v13.db.select(v13.db.sales).get()) s.id: s.locationId}, {'a1': _a, 'a2': _a, 'b1': _b});
      expect({for (final m in await v13.db.select(v13.db.localMovements).get()) m.opId: m.locationId},
          {'oa1': _a, 'oa2': _a, 'ob1': _b});
      expect([for (final l in await v13.db.select(v13.db.localLedger).get()) (l.opId, l.locationId, l.method)],
          [('pb1', _b, 'cash')]);
      expect([for (final f in await v13.db.select(v13.db.localFloatEffects).get()) (f.opId, f.locationId)], [('oa2', _a)]);
      expect([for (final e in await v13.db.select(v13.db.stockExpiry).get()) (e.locationId, e.variantId)], [(_b, _v1)]);
      final ledger = (await v13.db.select(v13.db.serverLedger).get()).single;
      expect((ledger.locationId, ledger.method), (null, 'cash'), reason: 'unknown until the re-pull brings it');
      final cursors = (await v13.cursors()).keys.toSet();
      expect(cursors, contains('stock_levels'), reason: 'the other cursors stay');
      expect(cursors.intersection({'sales', 'customer_ledger', 'stock_expiry'}), isEmpty,
          reason: 'sales, the ledger and expiry dates come again');

      expect(v13.activeLocationId, _b, reason: 'the store chosen before the upgrade');
      expect(await _saleIdsOf(v13), ['b1']);
      expect(await v13.stockLeft(_v1), 4 - 1);
      await v13.setActiveStore(_a);
      expect(await _saleIdsOf(v13), ['a1', 'a2']);
      expect(await v13.stockLeft(_v1), 10 - 2);
      await v13.close();
      dir.deleteSync(recursive: true);
    });

    test('one store: rows that cannot tell their store (op already sent) are given the only store', () async {
      final dir = Directory.systemTemp.createTempSync('xzpos_v12s_');
      final file = File('${dir.path}/app.sqlite');
      final v12 = DriftStore(AppDatabase(NativeDatabase(file)));
      await v12.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _a);
      await _seedCatalog(v12);
      await v12.applyPullPos(_pos(ledger: [_ledger('g1', -400, loc: _a)]));
      await v12.commitSale(_sale('s1', _v1, 1000), opId: 'o1');
      await v12.opDone('o1'); // sent: its payload is gone
      await v12.commitSale(_sale('s2', _v1, 700), opId: 'o2');
      await toV12(v12);

      final v13 = DriftStore(AppDatabase(NativeDatabase(file)));
      await v13.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _a);
      expect({for (final s in await v13.db.select(v13.db.sales).get()) s.id: s.locationId}, {'s1': _a, 's2': _a});
      expect((await v13.db.select(v13.db.serverLedger).get()).single.locationId, _a);
      expect(await _saleIdsOf(v13), ['s1', 's2']);
      expect(await v13.expectedCash(today(), openingCash: 0), 1000 + 700 + 400, reason: 'exactly as before the upgrade');
      expect((await v13.nextOps()).map((o) => o.opId), ['o2']);
      await v13.close();
      dir.deleteSync(recursive: true);
    });
  });
}

Future<List<String>> _saleIdsOf(DriftStore s) async => [for (final x in await s.watchSales().first) x.id]..sort();
