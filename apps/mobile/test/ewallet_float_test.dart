import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'expenses_test.dart' show cashSale, pgTs;
import 'sales_store_test.dart' show posPage;
import 'services_test.dart' show floatOf;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _loc = '0190a000-0000-7000-8000-0000000000e1';

SaleDraft sale(String id, List<PaymentDraft> pays, {DateTime? at}) => SaleDraft(
      id: id,
      soldAt: at ?? DateTime.now(),
      lines: [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: pays.fold(0, (a, p) => a + p.amount))],
      payments: pays,
    );

/// Behaves like sync_push for sales, expenses and service entries (P8-15 float rules, written out again here) and like
/// sync_pull_service's `floats`: once per op id, refusals leave nothing, the balance per wallet read now. Other pulls are
/// empty.
class FloatServer implements SyncApi {
  var clock = DateTime.utc(2026, 11, 8, 1);
  final applied = <String, Map<String, dynamic>>{};
  final sales = <String, Map<String, dynamic>>{};
  final expenses = <String, Map<String, dynamic>>{};
  final txns = <String, Map<String, dynamic>>{};

  /// Op kinds refused for good (e.g. a supervisor without an approval).
  final refuse = <String>{};
  bool loseNextResponse = false;

  DateTime tick() => clock = clock.add(const Duration(seconds: 1));

  Map<String, dynamic> _push1(Map<String, dynamic> op) {
    final id = op['op_id'] as String;
    final kind = op['kind'] as String;
    if (applied.containsKey(id)) return {'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': true}};
    if (refuse.contains(kind)) return {'op_id': id, 'status': 'rejected', 'code': '42501', 'hint': 'approval_required'};
    final p = op['payload'] as Map<String, dynamic>;
    switch (kind) {
      case 'record_sale':
        sales[p['id'] as String] = {'voided': false, 'payments': p['payments']};
      case 'void_sale':
        sales[p['sale_id']]?['voided'] = true;
      case 'record_expense':
        expenses[p['id'] as String] = {
          'paid_from': p['paid_from'] ?? 'cash', 'wallet': p['wallet'], 'amount': p['amount'], 'voided': false,
        };
      case 'void_expense':
        expenses[p['expense_id']]?['voided'] = true;
      case 'record_service_txn':
        txns[p['id'] as String] = {'kind': p['kind'], 'wallet': p['wallet'], 'amount': p['amount'], 'voided': false};
      case 'void_service_txn':
        txns[p['txn_id']]?['voided'] = true;
    }
    applied[id] = {'applied_at': tick().toIso8601String()};
    return {'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': false}};
  }

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    final out = [for (final op in ops) _push1(op)];
    if (loseNextResponse) {
      loseNextResponse = false;
      throw Exception('connection lost');
    }
    return out;
  }

  /// The server's balance per wallet (what the wallet_float triggers keep).
  Map<String, int> floats() {
    final m = <String, int>{};
    void add(String w, int v) => m[w] = (m[w] ?? 0) + v;
    for (final s in sales.values.where((s) => s['voided'] == false)) {
      for (final p in (s['payments'] as List).cast<Map<String, dynamic>>()) {
        if (p['method'] == 'ewallet' && p['wallet'] != null) add(p['wallet'] as String, p['amount'] as int);
      }
    }
    for (final e in expenses.values.where((e) => e['voided'] == false)) {
      if (e['paid_from'] == 'ewallet' && e['wallet'] != null) add(e['wallet'] as String, -(e['amount'] as int));
    }
    for (final t in txns.values.where((t) => t['voided'] == false)) {
      add(t['wallet'] as String, floatOf(t['kind'] as String, t['amount'] as int));
    }
    return m;
  }

  @override
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100}) async {
    final now = tick();
    return {
      'rows': <dynamic>[],
      'floats': [
        for (final e in floats().entries)
          {'location_id': _loc, 'wallet': e.key, 'balance': e.value, 'negative': e.value < 0, 'txn_count': 0,
           'updated_at': now.toIso8601String()},
      ],
      'cursor': cursor,
      'has_more': false,
      'server_time': now.toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullExpenses(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullDayCloses(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async =>
      posPage(serverTime: tick().toIso8601String());
  @override
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async => pullPage();
  @override
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload) async {}
  @override
  Future<void> archiveProduct(String opId, String productId) async {}
  @override
  Future<void> uploadPhoto(String path, Uint8List jpeg) async {}
  @override
  Future<Uint8List> downloadPhoto(String path) async => Uint8List(0);
}

/// What the tests made, for the independent float sum: (wallet, signed effect) per record that still counts.
class MixModel {
  final sales = <String, (List<PaymentDraft>, bool)>{};
  final expenses = <String, (String, String?, int, bool)>{};
  final txns = <String, (String, String, int, bool)>{};

  Map<String, int> floats() {
    final m = <String, int>{};
    void add(String w, int v) => m[w] = (m[w] ?? 0) + v;
    for (final (pays, voided) in sales.values) {
      if (voided) continue;
      for (final p in pays) {
        if (p.method == 'ewallet' && p.wallet != null) add(p.wallet!, p.amount);
      }
    }
    for (final (from, wallet, amount, voided) in expenses.values) {
      if (!voided && from == 'ewallet' && wallet != null) add(wallet, -amount);
    }
    for (final (kind, wallet, amount, voided) in txns.values) {
      if (!voided) add(wallet, floatOf(kind, amount));
    }
    return m;
  }

  /// Cash in the drawer from these records: sales cash - cash expenses - float top-ups (an adjustment moves no cash).
  int cash() {
    var c = 0;
    for (final (pays, voided) in sales.values) {
      if (!voided) c += pays.where((p) => p.method == 'cash').fold(0, (a, p) => a + p.amount);
    }
    for (final (from, _, amount, voided) in expenses.values) {
      if (!voided && from == 'cash') c -= amount;
    }
    for (final (kind, _, amount, voided) in txns.values) {
      if (!voided && kind == 'float_topup') c -= amount;
    }
    return c;
  }
}

/// Random sales (1-3 payments, cash or e-wallet, named wallet or none), expenses (cash or e-wallet, named or none),
/// float top-ups and adjustments, and voids of each, on [s] (seeded). Returns the model.
Future<MixModel> randomMix(DriftStore s, int seed, {int steps = 70}) async {
  final r = Random(seed);
  final m = MixModel();
  var n = 0;
  String id(String p) => '$p-$seed-${n++}';
  String? wallet() => r.nextInt(4) == 0 ? null : paymentWallets[r.nextInt(3)];
  for (var step = 0; step < steps; step++) {
    final roll = r.nextInt(10);
    if (roll < 4) {
      final parts = 1 + r.nextInt(3);
      final pays = [
        for (var i = 0; i < parts; i++)
          r.nextBool() ? PaymentDraft('cash', 1 + r.nextInt(20000)) : PaymentDraft('ewallet', 1 + r.nextInt(20000), wallet: wallet())
      ];
      final sid = id('s');
      await s.commitSale(sale(sid, pays), opId: id('os'));
      m.sales[sid] = (pays, false);
    } else if (roll < 6) {
      final from = r.nextBool() ? 'ewallet' : 'cash';
      final w = from == 'ewallet' ? wallet() : null;
      final amount = 1 + r.nextInt(15000);
      final eid = id('e');
      await s.recordExpense(id: eid, amount: amount, category: 'other', paidFrom: from, wallet: w, opId: id('oe'));
      m.expenses[eid] = (from, w, amount, false);
    } else if (roll < 7) {
      final kind = r.nextBool() ? 'float_topup' : 'float_adjust';
      final w = serviceWallets[r.nextInt(4)];
      final amount = (1 + r.nextInt(50000)) * (kind == 'float_adjust' && r.nextBool() ? -1 : 1);
      final tid = id('t');
      await s.recordServiceTxn(
          id: tid, kind: kind, wallet: w, amount: amount, note: kind == 'float_adjust' ? 'bilang' : null, opId: id('ot'));
      m.txns[tid] = (kind, w, amount, false);
    } else {
      // void something still open
      final which = r.nextInt(3);
      if (which == 0) {
        final open = m.sales.entries.where((e) => !e.value.$2).toList();
        if (open.isEmpty) continue;
        final e = open[r.nextInt(open.length)];
        await s.voidSale(e.key, opId: id('vs'));
        m.sales[e.key] = (e.value.$1, true);
      } else if (which == 1) {
        final open = m.expenses.entries.where((e) => !e.value.$4).toList();
        if (open.isEmpty) continue;
        final e = open[r.nextInt(open.length)];
        await s.voidExpense(expenseId: e.key, opId: id('ve'));
        final (f, w, a, _) = e.value;
        m.expenses[e.key] = (f, w, a, true);
      } else {
        final open = m.txns.entries.where((e) => !e.value.$4).toList();
        if (open.isEmpty) continue;
        final e = open[r.nextInt(open.length)];
        await s.voidServiceTxn(txnId: e.key, opId: id('vt'));
        final (k, w, a, _) = e.value;
        m.txns[e.key] = (k, w, a, true);
      }
    }
  }
  return m;
}

Map<String, int> _nonZero(Map<String, int> m) => {...m}..removeWhere((_, v) => v == 0);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;

  Future<void> seed(DriftStore s) async {
    await s.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
    await s.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 1000)],
    ));
  }

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await seed(store);
  });
  tearDown(() => store.close());

  DateTime today() => DateTime.now();
  Future<Map<String, int>> floats(DriftStore s) async =>
      {for (final f in await s.watchWalletFloat().first) f.wallet: f.balance};
  Future<List<ExpenseView>> todaysExpenses() {
    final n = DateTime.now();
    return store.watchExpenses(from: DateTime(n.year, n.month, n.day), to: DateTime(n.year, n.month, n.day + 1)).first;
  }

  group('sales', () {
    test('an e-wallet payment that names its wallet moves that float at once; the op carries wallet only when given',
        () async {
      await store.commitSale(
          sale('s1', const [
            PaymentDraft('cash', 2000, tendered: 5000),
            PaymentDraft('ewallet', 1500, wallet: 'gcash'),
            PaymentDraft('ewallet', 500),
          ]),
          opId: 'o1');
      final f = await store.watchWalletFloat().first;
      expect([for (final x in f) (x.wallet, x.balance, x.pending)], [('gcash', 1500, true)]);
      expect((await store.nextOps()).single.payload['payments'], [
        {'method': 'cash', 'amount': 2000, 'tendered': 5000},
        {'method': 'ewallet', 'amount': 1500, 'wallet': 'gcash'},
        {'method': 'ewallet', 'amount': 500},
      ]);
      final d = (await store.getSale('s1'))!;
      expect([for (final p in d.payments) (p.method, p.wallet)], [('cash', null), ('ewallet', 'gcash'), ('ewallet', null)]);
      expect(await store.expectedCash(today(), openingCash: 0), 2000, reason: 'e-wallet money is never drawer cash');
      final t = await store.watchToday().first;
      expect((t.cash, t.ewallet), (2000, 2000), reason: 'totals by method are unchanged');
    });

    test('a sale with no wallet anywhere behaves exactly as before', () async {
      await store.commitSale(sale('s1', const [PaymentDraft('ewallet', 900)]), opId: 'o1');
      expect((await store.nextOps()).single.payload['payments'], [
        {'method': 'ewallet', 'amount': 900}
      ]);
      expect(await store.watchWalletFloat().first, isEmpty);
      expect(await store.db.select(store.db.localFloatEffects).get(), isEmpty);
    });

    test('cancelling takes exactly the named e-wallet payments back out of their floats', () async {
      await store.commitSale(
          sale('s1', const [
            PaymentDraft('ewallet', 1500, wallet: 'gcash'),
            PaymentDraft('ewallet', 700, wallet: 'maya'),
            PaymentDraft('ewallet', 300),
            PaymentDraft('cash', 100),
          ]),
          opId: 'o1');
      await store.commitSale(sale('s2', const [PaymentDraft('ewallet', 400, wallet: 'gcash')]), opId: 'o2');
      expect(await floats(store), {'gcash': 1900, 'maya': 700});
      await store.voidSale('s1', opId: 'o3');
      expect(await floats(store), {'gcash': 400, 'maya': 0});
      final rows = await (store.db.select(store.db.localFloatEffects)..where((e) => e.opId.equals('o3'))).get();
      expect([for (final e in rows) (e.txnId, e.wallet, e.amount)], [('s1', 'gcash', -1500), ('s1', 'maya', -700)]);
    });

    test('bad wallets are refused before anything is written', () async {
      Future<void> bad(Future<void> Function() f) => expectLater(f, throwsArgumentError);
      await bad(() => store.commitSale(sale('x', const [PaymentDraft('cash', 100, wallet: 'gcash')]), opId: 'o'));
      await bad(() => store.commitSale(sale('x', const [PaymentDraft('ewallet', 100, wallet: 'load')]), opId: 'o'));
      await bad(() => store.commitSale(sale('x', const [PaymentDraft('ewallet', 100, wallet: 'paypal')]), opId: 'o'));
      await bad(() => store.recordExpense(id: 'x', amount: 1, category: 'other', wallet: 'gcash', opId: 'o'));
      await bad(() => store.recordExpense(id: 'x', amount: 1, category: 'other', paidFrom: 'ewallet', wallet: 'load', opId: 'o'));
      expect(await store.nextOps(), isEmpty);
      expect(await store.watchSales().first, isEmpty);
      expect(await store.watchWalletFloat().first, isEmpty);
    });
  });

  group('expenses', () {
    test('an e-wallet expense that names its wallet takes it out of the float; a void puts it back', () async {
      await store.recordExpense(id: 'e1', amount: 900, category: 'utilities', paidFrom: 'ewallet', wallet: 'maya', opId: 'o1');
      await store.recordExpense(id: 'e2', amount: 300, category: 'other', paidFrom: 'ewallet', opId: 'o2');
      await store.recordExpense(id: 'e3', amount: 200, category: 'other', opId: 'o3');
      final ops = await store.nextOps();
      expect(ops[0].payload, containsPair('wallet', 'maya'));
      expect(ops[1].payload.containsKey('wallet'), isFalse, reason: 'no wallet given: no key, as before');
      expect(ops[2].payload.containsKey('wallet'), isFalse);
      final f = await store.watchWalletFloat().first;
      expect([for (final x in f) (x.wallet, x.balance, x.negative, x.pending)], [('maya', -900, true, true)]);
      expect({for (final e in await todaysExpenses()) e.id: e.wallet}, {'e1': 'maya', 'e2': null, 'e3': null});
      expect(await store.expectedCash(today(), openingCash: 0), -200, reason: 'only the cash expense leaves the drawer');

      await store.voidExpense(expenseId: 'e1', opId: 'o4');
      await store.voidExpense(expenseId: 'e2', opId: 'o5');
      expect(await floats(store), {'maya': 0});
      expect(await store.db.select(store.db.localFloatEffects).get(), hasLength(2), reason: 'record and void of e1 only');
    });
  });

  group('sync', () {
    late FloatServer server;
    late SyncEngine engine;
    setUp(() {
      server = FloatServer();
      engine = SyncEngine(store, server);
    });
    tearDown(() => engine.dispose());

    test('a balance read before the ops were applied does not swallow them; one read after does, never twice', () async {
      await store.commitSale(sale('s1', const [PaymentDraft('ewallet', 1000, wallet: 'gcash')]), opId: 'o1');
      await store.recordExpense(id: 'e1', amount: 250, category: 'other', paidFrom: 'ewallet', wallet: 'gcash', opId: 'o2');
      final early = await server.pullService(null); // read before the ops reached the server (empty)
      for (final op in await store.nextOps()) {
        final res = (await server.syncPush([
          {'op_id': op.opId, 'kind': op.kind, 'payload': op.payload}
        ])).single;
        await store.posOpApplied(op.opId, (res['result'] as Map)['applied_at'] as String);
        await store.opDone(op.opId);
      }
      await store.applyPullService(early); // the stale balance arrives late
      expect(await floats(store), {'gcash': 750}, reason: 'the old balance does not include them: still counted');
      expect(await store.db.select(store.db.localFloatEffects).get(), hasLength(2));
      await engine.syncNow(); // a balance read after them
      expect(await floats(store), {'gcash': 750}, reason: 'now carried by the server balance, not counted twice');
      expect(await store.db.select(store.db.localFloatEffects).get(), isEmpty);

      await store.voidSale('s1', opId: 'o3'); // unsent: counts on top of the pulled balance
      expect(await floats(store), {'gcash': -250});
      await engine.syncNow();
      expect(await floats(store), {'gcash': -250});
      expect(server.floats(), {'gcash': -250});
    });

    test('random sales, expenses, float moves and voids: the float is right before, during and after a sync', () async {
      for (final k in [41, 42, 43, 44]) {
        final s = DriftStore(AppDatabase(NativeDatabase.memory()));
        await seed(s);
        final srv = FloatServer();
        final eng = SyncEngine(s, srv);
        final m = await randomMix(s, k);
        final want = _nonZero(m.floats());
        expect(_nonZero(await floats(s)), want, reason: 'seed $k before');
        expect(await s.expectedCash(today(), openingCash: 0), m.cash(), reason: 'seed $k cash');

        srv.loseNextResponse = true;
        await eng.syncNow(); // applied, reply lost: nothing confirmed
        expect(_nonZero(await floats(s)), want, reason: 'seed $k lost reply');
        await eng.syncNow(); // replays (no double count on the server), then the balance
        expect(_nonZero(srv.floats()), want, reason: 'seed $k: the server applied each op once');
        expect(_nonZero(await floats(s)), want, reason: 'seed $k after the sync');
        expect(await s.db.select(s.db.localFloatEffects).get(), isEmpty, reason: 'seed $k: the balance covers every op');
        expect(await s.expectedCash(today(), openingCash: 0), m.cash(), reason: 'seed $k cash after');
        eng.dispose();
        await s.close();
      }
    });

    test('discarding a refused expense, void or sale takes its float effect back', () async {
      server.refuse.addAll({'record_expense', 'void_sale'});
      await store.commitSale(sale('s1', const [PaymentDraft('ewallet', 1000, wallet: 'maya')]), opId: 'o1');
      await store.recordExpense(id: 'e1', amount: 400, category: 'other', paidFrom: 'ewallet', wallet: 'maya', opId: 'o2');
      await store.voidSale('s1', opId: 'o3');
      await engine.syncNow();
      expect((await store.failedOps()).map((o) => o.opId), ['o2', 'o3']);
      expect(await floats(store), {'maya': -400}, reason: 'refused but not discarded: still shown');

      await store.discardFailed('o2');
      expect(await floats(store), {'maya': 0}, reason: 'the expense never happened');
      expect(await todaysExpenses(), isEmpty);
      await store.discardFailed('o3');
      await engine.syncNow();
      expect(await floats(store), {'maya': 1000}, reason: 'the server never cancelled the sale');
      expect(server.floats(), {'maya': 1000});

      // a refused sale: its payment's effect goes with it
      server.refuse.add('record_sale');
      await store.commitSale(sale('s2', const [PaymentDraft('ewallet', 250, wallet: 'gcash')]), opId: 'o4');
      await engine.syncNow();
      expect(await floats(store), {'maya': 1000, 'gcash': 250});
      await store.discardFailed('o4');
      expect(await floats(store), {'maya': 1000});
    });
  });

  test('pulled sales and expenses carry the wallet, replace local rows and move no local float', () async {
    final at = pgTs(today());
    await store.applyPullSales({
      'rows': [
        {
          'id': 'srv-s1', 'local_no': 'ABC-261108-0001', 'status': 'completed', 'subtotal': 2000, 'discount': 0, 'tax': 0,
          'total': 2000, 'customer_id': null, 'sold_at': at, 'voided_at': null, 'void_reason': null, 'updated_at': at,
          'items': [
            {'variant_id': _v1, 'name': 'Kape', 'qty': 2, 'unit_price': 1000, 'unit_cost': 0, 'discount': 0, 'tax': 0,
             'line_total': 2000, 'tracked': true}
          ],
          'payments': [
            {'method': 'ewallet', 'amount': 1200, 'tendered': null, 'reference': null, 'wallet': 'maya'},
            // an older server sends no wallet key at all
            {'method': 'ewallet', 'amount': 800, 'tendered': null, 'reference': null},
          ],
        }
      ],
      'cursor': {'ts': at, 'k': 'srv-s1'},
      'has_more': false,
    });
    expect([for (final p in (await store.getSale('srv-s1'))!.payments) p.wallet], ['maya', null]);

    await store.recordExpense(id: 'e1', amount: 500, category: 'other', paidFrom: 'ewallet', wallet: 'gcash', opId: 'o1');
    Map<String, dynamic> exp(String id, String? wallet) => {
          'id': id, 'location_id': _loc, 'amount': 500, 'currency': 'PHP', 'category': 'other', 'note': null,
          'paid_from': 'ewallet', 'wallet': wallet, 'spent_at': at, 'created_by': 'u1', 'approved_by': null,
          'voided_at': null, 'void_reason': null, 'void_approved_by': null, 'updated_at': at,
        };
    await store.applyPullExpenses({
      'rows': [exp('e1', 'gcash'), exp('e9', 'other')],
      'cursor': {'ts': at, 'k': 'e9'},
      'has_more': false,
    });
    expect({for (final e in await todaysExpenses()) e.id: (e.wallet, e.amount)}, {'e1': ('gcash', 500), 'e9': ('other', 500)});
    expect(await floats(store), {'gcash': -500},
        reason: 'only this device\'s unsent expense counts locally; pulled rows come into the float through the balance');
  });

  test('upgrading a v11 database keeps every row and adds the wallet columns', () async {
    final dir = Directory.systemTemp.createTempSync('xzpos_v11_');
    final file = File('${dir.path}/app.sqlite');
    final v11 = DriftStore(AppDatabase(NativeDatabase(file)));
    await seed(v11);
    await v11.commitSale(cashSale('s1', 4000, method: 'ewallet'), opId: 'o1');
    await v11.recordExpense(id: 'e1', amount: 1000, category: 'other', paidFrom: 'ewallet', opId: 'o2');
    await v11.db.customStatement('alter table sale_payments drop column wallet');
    await v11.db.customStatement('alter table expenses drop column wallet');
    await v11.db.customStatement('PRAGMA user_version = 11');
    await v11.close();

    final v12 = DriftStore(AppDatabase(NativeDatabase(file)));
    await v12.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc); // same tenant: nothing cleared
    final version = await v12.db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, v12.db.schemaVersion);
    final s1 = (await v12.getSale('s1'))!;
    expect((s1.summary.total, s1.payments.single.method, s1.payments.single.wallet), (4000, 'ewallet', null));
    final n = DateTime.now();
    final e1 = (await v12.watchExpenses(from: DateTime(n.year, n.month, n.day), to: DateTime(n.year, n.month, n.day + 1)).first)
        .single;
    expect((e1.amount, e1.paidFrom, e1.wallet), (1000, 'ewallet', null));
    expect((await v12.nextOps()).map((o) => o.opId), ['o1', 'o2'], reason: 'unsent ops survive');
    await v12.commitSale(sale('s2', const [PaymentDraft('ewallet', 600, wallet: 'gcash')]), opId: 'o3');
    expect(await floats(v12), {'gcash': 600});
    await v12.close();
    dir.deleteSync(recursive: true);
  });
}
