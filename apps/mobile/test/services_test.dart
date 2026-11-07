import 'dart:convert';
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
import 'expenses_test.dart' show buildRandomDay, cashSale, pgTs;
import 'sales_store_test.dart' show posPage;
import 'widget_test.dart' show FakeBackend;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _loc = '0190a000-0000-7000-8000-0000000000e1';

// The money rule written out again for the tests (independent of serviceCashEffect / serviceFloatEffect and the SQL).
int cashOf(String kind, int amount, int fee, int? price) {
  if (kind == 'cash_in') return amount + fee;
  if (kind == 'cash_out') return fee - amount;
  if (kind == 'load') return price!;
  if (kind == 'float_topup') return -amount;
  if (kind == 'float_withdraw') return amount;
  return 0;
}

int floatOf(String kind, int amount) {
  if (kind == 'cash_in' || kind == 'load' || kind == 'float_withdraw') return -amount;
  return amount;
}

/// Behaves like sync_push (record_service_txn / void_service_txn; other kinds are just accepted) and sync_pull_service:
/// once per op id, refusals leave nothing, rows newer than 5 s held back, keyset pages by (updated_at, id), and `floats`
/// = the balance per wallet of every entry not voided, read now (never held back).
class ServiceServer implements SyncApi {
  var clock = DateTime.utc(2026, 11, 8, 1);
  final applied = <String, Map<String, dynamic>>{};
  final txns = <String, Map<String, dynamic>>{};
  final approvals = <String, (String, String)>{};
  final usedApprovals = <String>{};
  final pushedKinds = <String>[];

  /// The signed-in user is a store supervisor: float top-up / withdraw and voids need an approval.
  bool requireApproval = false;

  /// The signed-in user is a cashier: float ops and voids are refused.
  bool cashier = false;
  bool loseNextResponse = false;
  String? transientKind;
  int pageSize = 100;

  DateTime tick() => clock = clock.add(const Duration(seconds: 1));
  String issueApproval(String action, String ref) {
    final id = '0190a000-0000-7000-8000-${(approvals.length + 1).toString().padLeft(12, '0')}';
    approvals[id] = (action, ref);
    return id;
  }

  Map<String, dynamic> _rejected(String id, String hint) => {'op_id': id, 'status': 'rejected', 'code': '42501', 'hint': hint};

  String? _approvalProblem(String action, String ref, Map<String, dynamic> p) {
    final a = p['approval_id'] as String?;
    if (a == null) return 'approval_required';
    final x = approvals[a];
    if (x == null || x.$1 != action || x.$2 != ref) return 'approval_invalid';
    if (usedApprovals.contains(a)) return 'approval_used';
    return null;
  }

  Map<String, dynamic> _push1(Map<String, dynamic> op) {
    final id = op['op_id'] as String;
    final kind = op['kind'] as String;
    if (applied.containsKey(id)) return {'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': true}};
    final p = op['payload'] as Map<String, dynamic>;
    if (kind == 'record_service_txn') {
      final k = p['kind'] as String;
      final moves = k == 'float_topup' || k == 'float_withdraw';
      if (cashier && (moves || k == 'float_adjust')) return _rejected(id, 'not_allowed');
      if (requireApproval && k == 'float_adjust') return _rejected(id, 'not_allowed');
      if (requireApproval && moves) {
        final problem = _approvalProblem(kind, p['id'] as String, p);
        if (problem != null) return _rejected(id, problem);
      }
      if (txns.containsKey(p['id'])) return _rejected(id, 'id_conflict');
    } else if (kind == 'void_service_txn') {
      if (cashier) return _rejected(id, 'not_allowed');
      if (requireApproval) {
        final problem = _approvalProblem(kind, p['txn_id'] as String, p);
        if (problem != null) return _rejected(id, problem);
      }
      if (!txns.containsKey(p['txn_id'])) return _rejected(id, 'txn_not_found');
    }
    final now = tick().toIso8601String();
    if (kind == 'record_service_txn') {
      txns[p['id'] as String] = {
        'id': p['id'], 'location_id': p['location_id'], 'kind': p['kind'], 'wallet': p['wallet'], 'amount': p['amount'],
        'fee': p['fee'] ?? 0, 'price': p['price'], 'currency': 'PHP', 'ref': p['ref'], 'note': p['note'],
        'txn_at': pgTs(DateTime.parse(p['txn_at'] as String)), 'created_by': 'u1',
        'approved_by': p['approval_id'] == null ? null : 'boss', 'voided_at': null, 'void_reason': null,
        'void_approved_by': null, 'updated_at': now,
      };
    } else if (kind == 'void_service_txn') {
      final t = txns[p['txn_id']]!;
      if (t['voided_at'] == null) {
        t['voided_at'] = now;
        t['void_reason'] = p['reason'];
        t['updated_at'] = now;
      }
    }
    if (p['approval_id'] != null) usedApprovals.add(p['approval_id'] as String);
    applied[id] = {'applied_at': now};
    return {'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': false}};
  }

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      pushedKinds.add(op['kind'] as String);
      if (op['kind'] == transientKind) {
        out.add({'op_id': op['op_id'], 'status': 'error', 'code': '40001'});
        return out;
      }
      out.add(_push1(op));
    }
    if (loseNextResponse) {
      loseNextResponse = false;
      throw Exception('connection lost');
    }
    return out;
  }

  /// The server's balance per wallet (what the wallet_float trigger keeps).
  Map<String, int> floats() {
    final m = <String, int>{};
    for (final t in txns.values) {
      final w = t['wallet'] as String;
      m[w] = (m[w] ?? 0) + (t['voided_at'] == null ? floatOf(t['kind'] as String, t['amount'] as int) : 0);
    }
    return m;
  }

  @override
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100}) async {
    final now = tick();
    final upto = now.subtract(const Duration(seconds: 5));
    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      final c = (a['updated_at'] as String).compareTo(b['updated_at'] as String);
      return c != 0 ? c : (a['id'] as String).compareTo(b['id'] as String);
    }

    final rows = txns.values.where((r) {
      if (DateTime.parse(r['updated_at'] as String).isAfter(upto)) return false;
      if (cursor == null) return true;
      return cmp(r, {'updated_at': cursor['ts'], 'id': cursor['k']}) > 0;
    }).toList()
      ..sort(cmp);
    final page = rows.take(pageSize).map((r) => Map<String, dynamic>.of(r)).toList();
    return {
      'rows': page,
      'floats': [
        for (final e in floats().entries)
          {'location_id': _loc, 'wallet': e.key, 'balance': e.value, 'negative': e.value < 0, 'txn_count': 0,
           'updated_at': now.toIso8601String()},
      ],
      'cursor': page.isEmpty ? cursor : {'ts': page.last['updated_at'], 'k': page.last['id']},
      'has_more': rows.length > pageSize,
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

/// One entry the tests made, for the independent sums.
class MadeTxn {
  MadeTxn(this.id, this.kind, this.wallet, this.amount, this.fee, this.price, this.today);
  final String id;
  final String kind;
  final String wallet;
  final int amount;
  final int fee;
  final int? price;
  final bool today;
  bool voided = false;
  int get cash => cashOf(kind, amount, fee, price);
  int get float => floatOf(kind, amount);
}

/// Records [steps] random service entries and voids on [s] (seeded). Returns what was made.
Future<List<MadeTxn>> randomServices(DriftStore s, int seed, {int steps = 80, bool yesterdayToo = true, String tag = ''}) async {
  final r = Random(seed);
  final made = <MadeTxn>[];
  var n = 0;
  String id(String p) => '$p$tag-$seed-${n++}';
  for (var step = 0; step < steps; step++) {
    if (made.any((m) => !m.voided) && r.nextInt(5) == 0) {
      final open = made.where((m) => !m.voided).toList();
      final m = open[r.nextInt(open.length)];
      await s.voidServiceTxn(txnId: m.id, reason: 'mali', opId: id('sv'));
      m.voided = true;
      continue;
    }
    final today = !yesterdayToo || r.nextInt(5) != 0;
    final at = today ? DateTime.now() : DateTime.now().subtract(const Duration(days: 1));
    final kind = serviceKinds[r.nextInt(serviceKinds.length)];
    final wallet = switch (kind) {
      'cash_in' || 'cash_out' => ['gcash', 'maya', 'other'][r.nextInt(3)],
      'load' => r.nextBool() ? 'load' : 'gcash',
      _ => serviceWallets[r.nextInt(4)],
    };
    var amount = 1 + r.nextInt(500000);
    if (kind == 'float_adjust' && r.nextBool()) amount = -amount;
    final fee = (kind == 'cash_in' || kind == 'cash_out') ? r.nextInt(2500) : 0;
    final price = kind == 'load' ? amount + r.nextInt(300) : null;
    final tid = id('st');
    await s.recordServiceTxn(
      id: tid, kind: kind, wallet: wallet, amount: amount, fee: fee, price: price,
      ref: r.nextBool() ? '09${r.nextInt(999999999)}' : null, note: kind == 'float_adjust' ? 'bilang' : null,
      txnAt: at, opId: id('sr'),
    );
    made.add(MadeTxn(tid, kind, wallet, amount, kind == 'load' ? price! - amount : fee, price, today));
  }
  return made;
}

Map<String, int> modelFloats(List<MadeTxn> made) {
  final m = <String, int>{};
  for (final x in made) {
    m[x.wallet] = (m[x.wallet] ?? 0) + (x.voided ? 0 : x.float);
  }
  return m;
}

int modelCash(List<MadeTxn> made, {required bool today}) =>
    made.where((m) => !m.voided && m.today == today).fold(0, (a, m) => a + m.cash);

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
  DateTime yesterday() => DateTime.now().subtract(const Duration(days: 1));
  Future<List<ServiceTxnView>> todays() {
    final n = DateTime.now();
    return store.watchServiceTxns(from: DateTime(n.year, n.month, n.day), to: DateTime(n.year, n.month, n.day + 1)).first;
  }

  Future<Map<String, int>> floats(DriftStore s) async =>
      {for (final f in await s.watchWalletFloat().first) f.wallet: f.balance};

  group('recording and voiding', () {
    test('every kind shows at once, moves the float and the drawer, and queues one record_service_txn op', () async {
      final at = DateTime.now();
      await store.recordServiceTxn(
          id: 't1', kind: 'cash_in', wallet: 'gcash', amount: 50000, fee: 1500, ref: ' 0917 123 4567 ', txnAt: at, opId: 'o1');
      final op = (await store.nextOps()).single;
      expect((op.kind, op.entityId), ('record_service_txn', 't1'));
      expect(op.payload, {
        'id': 't1', 'kind': 'cash_in', 'wallet': 'gcash', 'amount': 50000, 'fee': 1500, 'ref': '0917 123 4567',
        'txn_at': at.toUtc().toIso8601String(), 'location_id': _loc,
      });
      await store.recordServiceTxn(id: 't2', kind: 'cash_out', wallet: 'maya', amount: 20000, fee: 500, opId: 'o2');
      await store.recordServiceTxn(id: 't3', kind: 'load', wallet: 'load', amount: 4800, price: 5000, opId: 'o3');
      await store.recordServiceTxn(id: 't4', kind: 'float_topup', wallet: 'gcash', amount: 100000, opId: 'o4');
      await store.recordServiceTxn(id: 't5', kind: 'float_withdraw', wallet: 'maya', amount: 5000, opId: 'o5');
      await store.recordServiceTxn(id: 't6', kind: 'float_adjust', wallet: 'load', amount: -200, note: ' count fix ', opId: 'o6');

      final load = (await todays()).firstWhere((t) => t.id == 't3');
      expect((load.fee, load.price, load.cashEffect, load.floatEffect, load.pending), (200, 5000, 5000, -4800, true));
      expect((await store.nextOps())[2].payload, containsPair('price', 5000));
      expect((await store.nextOps())[2].payload, containsPair('fee', 200));
      expect((await store.nextOps())[5].payload, containsPair('note', 'count fix'));

      final f = await store.watchWalletFloat().first;
      expect([for (final x in f) (x.wallet, x.balance, x.negative, x.pending)],
          [('gcash', 50000, false, true), ('maya', 15000, false, true), ('load', -5000, true, true)]);
      final t = await store.watchTodayServices().first;
      expect((t.count, t.fees, t.cashIn, t.cashOut, t.loadSales, t.cash), (3, 2200, 50000, 20000, 5000, -58000));
      expect(await store.expectedCash(today()), 51500 - 19500 + 5000 - 100000 + 5000);
    });

    test('bad input is refused before anything is written; an approval id rides in the op', () async {
      Future<void> bad(Future<void> Function() f) => expectLater(f, throwsArgumentError);
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'remit', wallet: 'gcash', amount: 1, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'cash_in', wallet: 'paypal', amount: 1, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'cash_in', wallet: 'load', amount: 1, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'cash_in', wallet: 'gcash', amount: 0, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'cash_out', wallet: 'gcash', amount: -5, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'cash_in', wallet: 'gcash', amount: 5, fee: -1, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'float_topup', wallet: 'gcash', amount: 5, fee: 1, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'load', wallet: 'load', amount: 5, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'load', wallet: 'load', amount: 5, price: 4, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'load', wallet: 'load', amount: 5, price: 9, fee: 1, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'cash_in', wallet: 'gcash', amount: 5, price: 9, opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'float_adjust', wallet: 'gcash', amount: 5, note: '  ', opId: 'o'));
      await bad(() => store.recordServiceTxn(id: 'x', kind: 'float_adjust', wallet: 'gcash', amount: 0, note: 'x', opId: 'o'));
      expect(await store.nextOps(), isEmpty);
      expect(await store.watchWalletFloat().first, isEmpty);

      await store.recordServiceTxn(id: 't1', kind: 'float_topup', wallet: 'maya', amount: 900, approvalId: 'ap-1', opId: 'o1');
      expect((await store.nextOps()).single.payload['approval_id'], 'ap-1');
      await expectLater(store.recordServiceTxn(id: 't1', kind: 'cash_in', wallet: 'gcash', amount: 1, opId: 'o2'), throwsStateError);
      await store.recordServiceTxn(id: 't2', kind: 'load', wallet: 'load', amount: 100, price: 110, fee: 10, opId: 'o3');
      await store.recordServiceTxn(id: 't3', kind: 'cash_in', wallet: 'gcash', amount: 100, ref: '9' * 250, opId: 'o4');
      expect((await todays()).firstWhere((t) => t.id == 't3').ref!.length, 200);
    });

    test('a void takes the entry back out of the float, the totals and expected cash, once', () async {
      await store.recordServiceTxn(id: 't1', kind: 'cash_in', wallet: 'gcash', amount: 50000, fee: 1500, opId: 'o1');
      await store.recordServiceTxn(id: 't2', kind: 'cash_out', wallet: 'gcash', amount: 3000, fee: 100, opId: 'o2');
      await store.voidServiceTxn(txnId: 't1', reason: ' maling numero ', approvalId: 'ap-2', opId: 'o3');
      final t1 = (await todays()).firstWhere((t) => t.id == 't1');
      expect((t1.voided, t1.voidReason), (true, 'maling numero'));
      expect((await store.nextOps()).last.payload, {'txn_id': 't1', 'reason': 'maling numero', 'approval_id': 'ap-2'});
      expect(await floats(store), {'gcash': 3000});
      final t = await store.watchTodayServices().first;
      expect((t.count, t.fees, t.cash), (1, 100, -2900));
      expect(await store.expectedCash(today()), -2900);
      await expectLater(store.voidServiceTxn(txnId: 't1', opId: 'o4'), throwsStateError);
      await expectLater(store.voidServiceTxn(txnId: 'nope', opId: 'o5'), throwsStateError);
    });

    test('watchServiceTxns keeps to the asked range, newest first; yesterday is out of today', () async {
      await store.recordServiceTxn(id: 'old', kind: 'cash_in', wallet: 'gcash', amount: 100, fee: 10, txnAt: yesterday(), opId: 'o1');
      await store.recordServiceTxn(
          id: 'a', kind: 'cash_in', wallet: 'gcash', amount: 200, txnAt: today().subtract(const Duration(seconds: 2)), opId: 'o2');
      await store.recordServiceTxn(id: 'b', kind: 'load', wallet: 'load', amount: 300, price: 320, txnAt: today(), opId: 'o3');
      expect((await todays()).map((t) => t.id), ['b', 'a']);
      expect((await store.watchTodayServices().first).fees, 20);
      expect(await store.expectedCash(yesterday()), 110);
      expect(await store.expectedCash(today()), 200 + 320);
      expect(await floats(store), {'gcash': -300, 'load': -300}, reason: 'the float is not per day');
    });
  });

  group('property', () {
    test('expected cash and floats equal independent sums with sales, utang, expenses and services mixed', () async {
      for (final k in [21, 22, 23, 24, 25, 26]) {
        final s = DriftStore(AppDatabase(NativeDatabase.memory()));
        final base = await buildRandomDay(s, k); // sales, splits, voids, utang payments, expenses (checked there)
        final baseY = await s.expectedCash(yesterday());
        final made = await randomServices(s, k);
        expect(await s.expectedCash(today()), base + modelCash(made, today: true), reason: 'seed $k today');
        expect(await s.expectedCash(yesterday()), baseY + modelCash(made, today: false), reason: 'seed $k yesterday');
        expect(await floats(s), modelFloats(made), reason: 'seed $k floats');
        final t = await s.watchTodayServices().first;
        final open = made.where((m) => !m.voided && m.today);
        expect((t.count, t.fees),
            (open.where((m) => customerServiceKinds.contains(m.kind)).length, open.fold<int>(0, (a, m) => a + m.fee)),
            reason: 'seed $k totals');
        await s.close();
      }
    });

    test('through a sync: unchanged before, during and after the server copies and balances arrive', () async {
      for (final k in [31, 32, 33]) {
        final s = DriftStore(AppDatabase(NativeDatabase.memory()));
        await seed(s);
        final server = ServiceServer();
        final engine = SyncEngine(s, server);
        await s.commitSale(cashSale('s-$k', 12000), opId: 'os-$k');
        final made = await randomServices(s, k, steps: 60, yesterdayToo: false);
        final wantCash = 12000 + modelCash(made, today: true);
        final wantFloats = modelFloats(made);
        expect(await s.expectedCash(today()), wantCash);
        expect(await floats(s), wantFloats);

        server.loseNextResponse = true;
        await engine.syncNow(); // applied, reply lost: nothing confirmed, no pull this run
        expect(await floats(s), wantFloats, reason: 'seed $k: lost reply');
        await engine.syncNow(); // replays, then the balance (rows still held back)
        expect(await s.expectedCash(today()), wantCash, reason: 'seed $k after the push');
        expect(await floats(s), wantFloats, reason: 'seed $k after the push');
        expect(await s.db.select(s.db.localFloatEffects).get(), isEmpty, reason: 'the pulled balance covers every op');
        expect(server.floats()..removeWhere((_, v) => v == 0), {...wantFloats}..removeWhere((_, v) => v == 0),
            reason: 'the server agrees');

        server.clock = server.clock.add(const Duration(seconds: 30));
        await engine.syncNow(); // the rows arrive and replace ours
        expect(await s.expectedCash(today()), wantCash, reason: 'seed $k after the pull');
        expect(await floats(s), wantFloats, reason: 'seed $k after the pull');
        expect((await s.db.select(s.db.serviceTxns).get()).every((t) => t.updatedAt != null), isTrue);
        expect((await s.watchOutboxCounts().first).pending, 0);

        // more work after the sync counts on top of the pulled balance
        await s.recordServiceTxn(id: 'late-$k', kind: 'cash_in', wallet: 'gcash', amount: 700, fee: 20, opId: 'ol-$k');
        expect((await floats(s))['gcash'], (wantFloats['gcash'] ?? 0) - 700);
        expect(await s.expectedCash(today()), wantCash + 720);
        engine.dispose();
        await s.close();
      }
    });
  });

  group('sync', () {
    late ServiceServer server;
    late SyncEngine engine;
    setUp(() {
      server = ServiceServer();
      engine = SyncEngine(store, server);
    });
    tearDown(() => engine.dispose());

    test('a balance read before an op was applied does not swallow it; one read after does', () async {
      await store.recordServiceTxn(id: 't1', kind: 'float_topup', wallet: 'gcash', amount: 1000, opId: 'o1');
      final early = await server.pullService(null); // read before the op reached the server
      // the op is applied and confirmed (as the engine's push does), then the old balance arrives
      final op = (await store.nextOps()).single;
      final res = (await server.syncPush([
        {'op_id': op.opId, 'kind': op.kind, 'payload': op.payload}
      ])).single;
      await store.posOpApplied(op.opId, (res['result'] as Map)['applied_at'] as String);
      await store.opDone(op.opId);
      await store.applyPullService(early);
      expect(await floats(store), {'gcash': 1000}, reason: 'the old balance does not include the top-up: still counted');
      expect(await store.db.select(store.db.localFloatEffects).get(), hasLength(1));
      await engine.syncNow(); // a balance read after it
      expect(await floats(store), {'gcash': 1000});
      expect(await store.db.select(store.db.localFloatEffects).get(), isEmpty, reason: 'now the server balance carries it');
    });

    test('a supervisor refusal parks the op; requeue with an approval sends it once; discard takes it back', () async {
      server.requireApproval = true;
      await store.recordServiceTxn(id: 't1', kind: 'cash_in', wallet: 'gcash', amount: 5000, fee: 50, opId: 'o1');
      await store.recordServiceTxn(id: 't2', kind: 'float_topup', wallet: 'gcash', amount: 20000, opId: 'o2');
      await store.recordServiceTxn(id: 't3', kind: 'float_withdraw', wallet: 'maya', amount: 300, opId: 'o3');
      await engine.syncNow();
      final failed = await store.failedOps();
      expect(failed.map((o) => (o.kind, o.lastError)),
          [('record_service_txn', 'approval_required'), ('record_service_txn', 'approval_required')]);
      expect(needsApproval(failed.first.lastError), isTrue);
      final t2 = (await todays()).firstWhere((t) => t.id == 't2');
      expect((t2.pending, t2.rejectedHint), (true, 'approval_required'));
      expect(await floats(store), {'gcash': -5000 + 20000, 'maya': -300}, reason: 'refused but not discarded: still shown');

      final pushes = server.pushedKinds.length;
      await engine.syncNow();
      expect(server.pushedKinds.length, pushes, reason: 'a refused op is not retried on its own');

      await store.requeueWithApproval(opId: 'o2', approvalId: server.issueApproval('record_service_txn', 't2'));
      await engine.syncNow();
      expect(server.txns.keys.toSet(), {'t1', 't2'});
      expect((await todays()).firstWhere((t) => t.id == 't2').rejectedHint, isNull);
      await store.discardFailed('o3');
      expect((await todays()).map((t) => t.id).toSet(), {'t1', 't2'});
      expect(await floats(store), {'gcash': 15000}, reason: 'the discarded withdraw is gone from the float');
      expect(await store.expectedCash(today()), 5050 - 20000);

      await store.voidServiceTxn(txnId: 't1', opId: 'o4'); // no approval
      await engine.syncNow();
      expect((await store.failedOps()).single.lastError, 'approval_required');
      expect((await floats(store))['gcash'], 20000);
      await store.discardFailed('o4');
      expect((await todays()).firstWhere((t) => t.id == 't1').voided, isFalse, reason: 'the server never voided it');
      expect(await floats(store), {'gcash': 15000});
      expect(await store.expectedCash(today()), 5050 - 20000);
    });

    test('a cashier can record services but a float move is refused for good', () async {
      server.cashier = true;
      await store.recordServiceTxn(id: 't1', kind: 'load', wallet: 'load', amount: 1000, price: 1000, opId: 'o1');
      await store.recordServiceTxn(id: 't2', kind: 'float_adjust', wallet: 'load', amount: 500, note: 'x', opId: 'o2');
      await engine.syncNow();
      expect((await store.failedOps()).map((o) => o.lastError), ['not_allowed']);
      expect(needsApproval('not_allowed'), isFalse);
      await expectLater(store.requeueWithApproval(opId: 'o1', approvalId: 'a'), throwsStateError, reason: 'o1 was applied');
      await store.discardFailed('o2');
      expect(await floats(store), {'load': -1000});
    });

    test('a temporary server error keeps the ops queued and in order', () async {
      await store.recordServiceTxn(id: 't1', kind: 'cash_in', wallet: 'gcash', amount: 100, opId: 'o1');
      await store.voidServiceTxn(txnId: 't1', opId: 'o2');
      server.transientKind = 'record_service_txn';
      await engine.syncNow();
      expect(server.applied, isEmpty, reason: 'the void was not sent before its entry');
      expect((await store.watchOutboxCounts().first).pending, 2);
      server.transientKind = null;
      await engine.syncNow();
      expect(server.applied, hasLength(2));
      expect(server.txns['t1']!['voided_at'], isNotNull);
      expect(await floats(store), {'gcash': 0});
    });

    test('pulls page by cursor, wait out the hold-back, and keep a void still on its way', () async {
      server.pageSize = 2;
      Map<String, dynamic> row(String id, int amount) => {
            'id': id, 'location_id': _loc, 'kind': 'cash_in', 'wallet': 'gcash', 'amount': amount, 'fee': 10,
            'price': null, 'currency': 'PHP', 'ref': '0917', 'note': null, 'txn_at': pgTs(today()), 'created_by': 'u2',
            'approved_by': null, 'voided_at': null, 'void_reason': null, 'void_approved_by': null,
            'updated_at': server.tick().toIso8601String(),
          };
      for (var i = 1; i <= 4; i++) {
        server.txns['x$i'] = row('x$i', 100 * i);
      }
      server.clock = server.clock.add(const Duration(seconds: 30));
      server.txns['x5'] = row('x5', 500)..['updated_at'] = server.clock.add(const Duration(seconds: 3)).toIso8601String();
      await engine.syncNow();
      expect((await todays()).map((t) => t.id).toSet(), {'x1', 'x2', 'x3', 'x4'}, reason: 'two pages; x5 is too new');
      expect(await floats(store), {'gcash': -1500}, reason: 'the balance is not held back (x5 included)');
      expect((await store.cursors()).keys, contains('service_txns'));

      await store.voidServiceTxn(txnId: 'x1', opId: 'v1'); // not sent yet ...
      server.txns['x1']!['updated_at'] = server.tick().toIso8601String();
      server.clock = server.clock.add(const Duration(seconds: 30));
      for (var more = true; more;) {
        final res = await server.pullService((await store.cursors())['service_txns'] as Map<String, dynamic>?);
        await store.applyPullService(res);
        more = res['has_more'] == true;
      }
      final x1 = (await todays()).firstWhere((t) => t.id == 'x1');
      expect((x1.voided, x1.pending), (true, true), reason: 'our void is kept');
      expect(await floats(store), {'gcash': -1500 + 100}, reason: 'the unsent void counts on top of the balance');
      expect((await store.watchTodayServices().first).cash, 200 + 300 + 400 + 500 + 40);

      await engine.syncNow();
      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      final after = (await todays()).firstWhere((t) => t.id == 'x1');
      expect((after.voided, after.pending), (true, false));
      expect(await floats(store), {'gcash': -1400});
      expect(await store.db.select(store.db.localFloatEffects).get(), isEmpty);
    });
  });

  test('upgrading a v6 database keeps every row and adds the service tables', () async {
    final dir = Directory.systemTemp.createTempSync('xzpos_v6_');
    final file = File('${dir.path}/app.sqlite');
    final v6 = DriftStore(AppDatabase(NativeDatabase(file)));
    await seed(v6);
    await v6.commitSale(cashSale('s1', 4000), opId: 'o1');
    await v6.recordExpense(id: 'e1', amount: 1000, category: 'other', opId: 'o2');
    await v6.closeDay(id: 'd1', day: today(), countedCash: 3000, opId: 'o3');
    await v6.db.customStatement('drop table service_txns');
    await v6.db.customStatement('drop table wallet_float');
    await v6.db.customStatement('drop table local_float_effects');
    await v6.db.customStatement('PRAGMA user_version = 6');
    await v6.close();

    final v7 = DriftStore(AppDatabase(NativeDatabase(file)));
    await v7.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc); // same tenant: nothing cleared
    expect((await v7.getSale('s1'))!.summary.total, 4000);
    expect((await v7.watchLatestDayClose(today()).first)!.countedCash, 3000);
    expect((await v7.nextOps()).map((o) => o.opId), ['o1', 'o2', 'o3'], reason: 'unsent ops survive');
    await v7.recordServiceTxn(id: 't1', kind: 'cash_in', wallet: 'gcash', amount: 2000, fee: 20, opId: 'o4');
    expect(await v7.expectedCash(today()), 4000 - 1000 + 2020);
    expect(await floats(v7), {'gcash': -2000});
    final version = await v7.db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 8);
    final idx = await v7.db.customSelect("select name from sqlite_master where type = 'index' and name = 'service_txns_txn_at'").get();
    expect(idx, hasLength(1));
    await v7.close();
    dir.deleteSync(recursive: true);
  });

  test('the supervisor flow for float moves and voids never stores a PIN', () async {
    const pin = '73519046';
    final backend = FakeBackend();
    expect((await backend.setMyPin(pin)).ok, isTrue);
    final a = await backend.approveSupervisorAction(action: 'record_service_txn', refId: 't1', pin: pin, locationId: _loc);
    await store.recordServiceTxn(id: 't1', kind: 'float_topup', wallet: 'gcash', amount: 1000, approvalId: a.approvalId, opId: 'o1');
    final b = await backend.approveSupervisorAction(action: 'void_service_txn', refId: 't1', pin: pin);
    await store.voidServiceTxn(txnId: 't1', approvalId: b.approvalId, opId: 'o2');
    for (final op in await store.nextOps()) {
      expect(op.payload.keys.any((k) => k.contains('pin')), isFalse);
      expect(op.payload['approval_id'], isNotNull);
    }
    for (final t in store.db.allTables) {
      for (final row in await store.db.customSelect('select * from "${t.actualTableName}"').get()) {
        for (final v in row.data.values) {
          final text = v is Uint8List ? utf8.decode(v, allowMalformed: true) : '$v';
          expect(text.contains(pin), isFalse, reason: 'PIN found in ${t.actualTableName}');
        }
      }
    }
  });

  test('the money helpers match the documented table', () {
    for (final k in serviceKinds) {
      final amount = k == 'float_adjust' ? -700 : 1000;
      final fee = customerServiceKinds.contains(k) && k != 'load' ? 25 : 0;
      final price = k == 'load' ? 1040 : null;
      expect(serviceCashEffect(k, amount, k == 'load' ? 40 : fee, price), cashOf(k, amount, k == 'load' ? 40 : fee, price), reason: k);
      expect(serviceFloatEffect(k, amount), floatOf(k, amount), reason: k);
      if (k != 'float_adjust') {
        expect(serviceCashEffect(k, amount, k == 'load' ? 40 : fee, price) + serviceFloatEffect(k, amount), k == 'load' ? 40 : fee,
            reason: '$k: cash + float move by the fee');
      }
    }
  });
}
