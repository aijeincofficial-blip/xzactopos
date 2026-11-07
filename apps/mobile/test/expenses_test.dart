import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/backend.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'sales_store_test.dart' show posPage;
import 'widget_test.dart' show FakeBackend;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _cus = '0190a000-0000-7000-8000-0000000000c1';
const _loc = '0190a000-0000-7000-8000-0000000000e1';

/// A timestamp the way Postgres sends it (offset, microseconds), so the store must not rely on one text format.
String pgTs(DateTime t) => '${t.toUtc().toIso8601String().replaceFirst('Z', '')}+00:00';

SaleDraft cashSale(String id, int amount, {String method = 'cash', DateTime? at, String? customer}) => SaleDraft(
      id: id,
      soldAt: at ?? DateTime.now(),
      lines: [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: amount)],
      payments: [PaymentDraft(method, amount)],
      customerId: customer,
    );

/// Behaves like sync_push (record_expense / void_expense / close_day / utang payments), sync_pull_pos (utang ledger
/// only), sync_pull_expenses and sync_pull_day_closes: once per op id, refusals leave nothing, rows newer than 5 s
/// are held back, keyset pages by (updated_at, id).
class ExpenseServer implements SyncApi {
  var clock = DateTime.utc(2026, 11, 8, 1);
  final applied = <String, Map<String, dynamic>>{};
  final expenses = <String, Map<String, dynamic>>{};
  final closes = <String, Map<String, dynamic>>{};
  final ledger = <Map<String, dynamic>>[];
  final approvals = <String, (String, String)>{};
  final usedApprovals = <String>{};
  final expiredApprovals = <String>{};
  final pushedKinds = <String>[];
  bool requireApproval = false;
  bool loseNextResponse = false;
  String? transientKind;
  int pageSize = 100;

  DateTime tick() => clock = clock.add(const Duration(seconds: 1));
  String issueApproval(String action, String ref) {
    final id = '0190a000-0000-7000-8000-${(approvals.length + 1).toString().padLeft(12, '0')}';
    approvals[id] = (action, ref);
    return id;
  }

  String? _approvalProblem(String kind, String ref, Map<String, dynamic> p) {
    if (!requireApproval) return null;
    final a = p['approval_id'] as String?;
    if (a == null) return 'approval_required';
    final x = approvals[a];
    if (x == null || x.$1 != kind || x.$2 != ref) return 'approval_invalid';
    if (usedApprovals.contains(a)) return 'approval_used';
    if (expiredApprovals.contains(a)) return 'approval_expired';
    return null;
  }

  Map<String, dynamic> _push1(Map<String, dynamic> op) {
    final id = op['op_id'] as String;
    final kind = op['kind'] as String;
    if (applied.containsKey(id)) return {'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': true}};
    final p = op['payload'] as Map<String, dynamic>;
    final ref = (kind == 'void_expense' ? p['expense_id'] : p['id']) as String?;
    if (ref != null && {'record_expense', 'void_expense', 'close_day'}.contains(kind)) {
      final problem = _approvalProblem(kind, ref, p);
      if (problem != null) return {'op_id': id, 'status': 'rejected', 'code': '42501', 'hint': problem};
    }
    final now = tick().toIso8601String();
    switch (kind) {
      case 'record_utang_payment':
        ledger.add({
          'id': 'L${ledger.length + 1}', 'customer_id': p['customer_id'], 'kind': 'payment', 'amount': -(p['amount'] as int),
          'sale_id': null, 'note': null, 'occurred_at': pgTs(DateTime.parse(p['occurred_at'] as String)), 'created_at': now,
        });
      case 'record_expense':
        expenses[ref!] = {
          'id': ref, 'location_id': p['location_id'], 'amount': p['amount'], 'currency': 'PHP', 'category': p['category'],
          'note': p['note'], 'paid_from': p['paid_from'] ?? 'cash', 'spent_at': pgTs(DateTime.parse(p['spent_at'] as String)),
          'created_by': 'u1', 'approved_by': p['approval_id'] == null ? null : 'boss', 'voided_at': null,
          'void_reason': null, 'void_approved_by': null, 'updated_at': now,
        };
      case 'void_expense':
        final e = expenses[ref];
        if (e == null) return {'op_id': id, 'status': 'rejected', 'code': '22023', 'hint': 'expense_not_found'};
        if (e['voided_at'] == null) {
          e['voided_at'] = now;
          e['void_reason'] = p['reason'];
          e['updated_at'] = now;
        }
      case 'close_day':
        closes[ref!] = {
          'id': ref, 'location_id': p['location_id'], 'day': p['day'], 'currency': 'PHP', 'expected_cash': p['expected_cash'],
          'counted_cash': p['counted_cash'], 'difference': (p['counted_cash'] as int) - (p['expected_cash'] as int),
          'server_expected_cash': (p['expected_cash'] as int) + 7, 'note': p['note'], 'closed_by': 'u1',
          'approved_by': null, 'closed_at': pgTs(DateTime.parse(p['closed_at'] as String)), 'updated_at': now,
        };
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

  Map<String, dynamic> _page(Iterable<Map<String, dynamic>> all, Map<String, dynamic>? cursor) {
    final now = tick();
    final upto = now.subtract(const Duration(seconds: 5));
    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      final c = (a['updated_at'] as String).compareTo(b['updated_at'] as String);
      return c != 0 ? c : (a['id'] as String).compareTo(b['id'] as String);
    }

    final rows = all.where((r) {
      if (DateTime.parse(r['updated_at'] as String).isAfter(upto)) return false;
      if (cursor == null) return true;
      return cmp(r, {'updated_at': cursor['ts'], 'id': cursor['k']}) > 0;
    }).toList()
      ..sort(cmp);
    final page = rows.take(pageSize).map((r) => Map<String, dynamic>.of(r)).toList();
    return {
      'rows': page,
      'cursor': page.isEmpty ? cursor : {'ts': page.last['updated_at'], 'k': page.last['id']},
      'has_more': rows.length > pageSize,
      'server_time': now.toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> pullExpenses(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      _page(expenses.values, cursor);
  @override
  Future<Map<String, dynamic>> pullDayCloses(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      _page(closes.values, cursor);
  @override
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};

  @override
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async {
    final now = tick();
    final upto = now.subtract(const Duration(seconds: 5));
    return posPage(
      ledger: [for (final l in ledger) if (!DateTime.parse(l['created_at'] as String).isAfter(upto)) l],
      serverTime: now.toIso8601String(),
    );
  }

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
  Future<List<ExpenseView>> todays() {
    final n = DateTime.now();
    return store.watchExpenses(from: DateTime(n.year, n.month, n.day), to: DateTime(n.year, n.month, n.day + 1)).first;
  }

  group('recording and voiding', () {
    test('an expense shows at once, counts in today, and queues one record_expense op', () async {
      final at = DateTime.now();
      await store.recordExpense(id: 'e1', amount: 15000, category: 'utilities', note: '  Meralco ', spentAt: at, opId: 'o1');
      final e = (await todays()).single;
      expect((e.amount, e.category, e.paidFrom, e.note, e.voided, e.pending, e.rejectedHint),
          (15000, 'utilities', 'cash', 'Meralco', false, true, null));
      final t = await store.watchTodayExpenses().first;
      expect((t.count, t.total, t.cash, t.ewallet), (1, 15000, 15000, 0));
      final op = (await store.nextOps()).single;
      expect(op.kind, 'record_expense');
      expect(op.entityId, 'e1');
      expect(op.payload, {
        'id': 'e1', 'amount': 15000, 'category': 'utilities', 'paid_from': 'cash', 'note': 'Meralco',
        'spent_at': at.toUtc().toIso8601String(), 'location_id': _loc,
      });
    });

    test('an approval id rides in the op; bad input is refused before anything is written', () async {
      await store.recordExpense(id: 'e1', amount: 500, category: 'transport', paidFrom: 'ewallet', approvalId: 'ap-1', opId: 'o1');
      expect((await store.nextOps()).single.payload['approval_id'], 'ap-1');
      expect(() => store.recordExpense(id: 'e2', amount: 0, category: 'other', opId: 'o2'), throwsArgumentError);
      expect(() => store.recordExpense(id: 'e2', amount: 1, category: 'food', opId: 'o2'), throwsArgumentError);
      expect(() => store.recordExpense(id: 'e2', amount: 1, category: 'other', paidFrom: 'card', opId: 'o2'), throwsArgumentError);
      await expectLater(store.recordExpense(id: 'e1', amount: 1, category: 'other', opId: 'o3'), throwsStateError);
      expect(await store.nextOps(), hasLength(1));
    });

    test('a void takes the expense out of the totals, is queued, and happens once', () async {
      await store.recordExpense(id: 'e1', amount: 1500, category: 'other', opId: 'o1');
      await store.recordExpense(id: 'e2', amount: 400, category: 'transport', paidFrom: 'ewallet', opId: 'o2');
      await store.voidExpense(expenseId: 'e1', reason: ' mali ', opId: 'o3');
      final list = await todays();
      expect(list.firstWhere((e) => e.id == 'e1').voided, isTrue);
      expect(list.firstWhere((e) => e.id == 'e1').voidReason, 'mali');
      final t = await store.watchTodayExpenses().first;
      expect((t.count, t.total, t.cash, t.ewallet), (1, 400, 0, 400));
      expect((await store.nextOps()).last.payload, {'expense_id': 'e1', 'reason': 'mali'});
      await expectLater(store.voidExpense(expenseId: 'e1', opId: 'o4'), throwsStateError);
      await expectLater(store.voidExpense(expenseId: 'nope', opId: 'o5'), throwsStateError);
    });

    test('watchExpenses keeps to the asked range, newest first', () async {
      await store.recordExpense(id: 'old', amount: 100, category: 'other', spentAt: yesterday(), opId: 'o1');
      await store.recordExpense(id: 'a', amount: 200, category: 'other', spentAt: today().subtract(const Duration(seconds: 2)), opId: 'o2');
      await store.recordExpense(id: 'b', amount: 300, category: 'other', spentAt: today(), opId: 'o3');
      expect((await todays()).map((e) => e.id), ['b', 'a']);
      expect((await store.watchTodayExpenses().first).total, 500);
    });
  });

  group('expected cash', () {
    test('cash sales + utang payments - cash expenses, for that day only', () async {
      await store.saveCustomer(id: _cus, name: 'Rosa', opId: 'oc');
      await store.commitSale(cashSale('s1', 10000), opId: 'o1');
      await store.commitSale(cashSale('s2', 2000, method: 'ewallet'), opId: 'o2'); // not cash
      await store.commitSale(cashSale('s3', 3000, method: 'utang', customer: _cus), opId: 'o3'); // not cash
      await store.commitSale(cashSale('s4', 5000), opId: 'o4');
      await store.voidSale('s4', opId: 'o5'); // voided: out
      await store.commitSale(cashSale('s5', 900, at: yesterday()), opId: 'o6'); // yesterday: out
      await store.recordUtangPayment(customerId: _cus, amount: 1500, opId: 'o7'); // in
      await store.adjustUtang(customerId: _cus, amount: -200, opId: 'o8'); // not cash
      await store.applyPullPos(posPage(ledger: [
        // payments from another device, in the server's own time format
        {'id': 'g1', 'customer_id': _cus, 'kind': 'payment', 'amount': -700, 'sale_id': null, 'note': null,
         'occurred_at': pgTs(today()), 'created_at': '2026-11-08T00:00:00+00:00'},
        {'id': 'g2', 'customer_id': _cus, 'kind': 'payment', 'amount': -800, 'sale_id': null, 'note': null,
         'occurred_at': pgTs(yesterday()), 'created_at': '2026-11-08T00:00:00+00:00'},
      ], serverTime: '2026-11-07T00:00:00+00:00')); // early horizon: local entries stay
      await store.recordExpense(id: 'e1', amount: 2500, category: 'utilities', opId: 'o9'); // in
      await store.recordExpense(id: 'e2', amount: 1000, category: 'transport', paidFrom: 'ewallet', opId: 'o10'); // e-wallet
      await store.recordExpense(id: 'e3', amount: 600, category: 'other', opId: 'o11');
      await store.voidExpense(expenseId: 'e3', opId: 'o12'); // voided
      await store.recordExpense(id: 'e4', amount: 300, category: 'other', spentAt: yesterday(), opId: 'o13'); // yesterday

      expect(await store.expectedCash(today()), 10000 + 1500 + 700 - 2500);
      expect(await store.watchExpectedCash(today()).first, 9700);
      expect(await store.expectedCash(yesterday()), 900 + 800 - 300);
    });

    test('property: equals an independent sum over random days of sales, payments, expenses and voids', () async {
      for (final k in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final s = DriftStore(AppDatabase(NativeDatabase.memory()));
        await buildRandomDay(s, k);
        await s.close();
      }
    });

    test('property, through a sync: unchanged before, during and after the server copies arrive', () async {
      for (final k in [11, 12, 13]) {
        final s = DriftStore(AppDatabase(NativeDatabase.memory()));
        final server = ExpenseServer();
        final engine = SyncEngine(s, server);
        final want = await buildRandomDay(s, k);
        await engine.syncNow(); // pushed; server rows still held back
        expect(await s.expectedCash(DateTime.now()), want, reason: 'seed $k after the push');
        expect((await s.watchOutboxCounts().first).pending, 0);
        server.clock = server.clock.add(const Duration(seconds: 30));
        await engine.syncNow(); // server copies arrive, local effects drop
        expect(await s.expectedCash(DateTime.now()), want, reason: 'seed $k after the pull');
        expect(await s.db.select(s.db.localLedger).get(), isEmpty, reason: 'utang payments now come from the server copy');
        expect((await s.db.select(s.db.expenses).get()).every((e) => e.updatedAt != null), isTrue,
            reason: 'every expense is the server copy now');
        engine.dispose();
        await s.close();
      }
    });
  });

  group('day close', () {
    test('stores the expected cash of that moment, the count and the difference, and queues close_day', () async {
      await store.commitSale(cashSale('s1', 12000), opId: 'o1');
      await store.recordExpense(id: 'e1', amount: 2000, category: 'other', opId: 'o2');
      expect(await store.watchLatestDayClose(today()).first, isNull);
      await store.closeDay(id: 'd1', day: today(), countedCash: 9800, note: 'kulang', opId: 'o3');
      final d = (await store.watchLatestDayClose(today()).first)!;
      expect((d.day, d.expectedCash, d.countedCash, d.difference, d.note, d.pending, d.serverExpectedCash),
          (dayKey(today()), 10000, 9800, -200, 'kulang', true, null));
      final op = (await store.nextOps()).last;
      expect(op.kind, 'close_day');
      expect(op.payload..remove('closed_at'), {
        'id': 'd1', 'day': dayKey(today()), 'expected_cash': 10000, 'counted_cash': 9800, 'note': 'kulang', 'location_id': _loc,
      });
    });

    test('a re-count is another close and the newest is shown; other days are untouched', () async {
      await store.closeDay(id: 'd1', day: today(), countedCash: 100, opId: 'o1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await store.closeDay(id: 'd2', day: today(), countedCash: 0, approvalId: 'ap-9', opId: 'o2');
      expect((await store.watchLatestDayClose(today()).first)!.id, 'd2');
      expect((await store.nextOps()).last.payload['approval_id'], 'ap-9');
      expect(await store.watchLatestDayClose(yesterday()).first, isNull);
      expect(() => store.closeDay(id: 'd3', day: today(), countedCash: -1, opId: 'o3'), throwsArgumentError);
      await expectLater(store.closeDay(id: 'd1', day: today(), countedCash: 1, opId: 'o4'), throwsStateError);
    });
  });

  group('sync', () {
    late ExpenseServer server;
    late SyncEngine engine;
    setUp(() {
      server = ExpenseServer();
      engine = SyncEngine(store, server);
    });
    tearDown(() => engine.dispose());

    test('record, void and close reach the server once even when a reply is lost; the server copies replace ours', () async {
      await store.recordExpense(id: 'e1', amount: 1500, category: 'other', opId: 'o1');
      await store.recordExpense(id: 'e2', amount: 700, category: 'rent', opId: 'o2');
      await store.voidExpense(expenseId: 'e1', reason: 'mali', opId: 'o3');
      await store.closeDay(id: 'd1', day: today(), countedCash: 0, opId: 'o4');
      server.loseNextResponse = true;
      await engine.syncNow();
      expect(server.applied, hasLength(4), reason: 'applied once although the phone never heard back');
      expect((await store.watchOutboxCounts().first).pending, 4);
      await engine.syncNow(); // same op ids: replays
      expect(server.applied, hasLength(4));
      expect(server.pushedKinds.where((k) => k == 'record_expense'), hasLength(4), reason: 'two sends of two ops');
      expect((await store.watchOutboxCounts().first).pending, 0);
      expect((await todays()).every((e) => !e.pending), isTrue);
      expect((await store.watchTodayExpenses().first).total, 700);

      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      final rows = await store.db.select(store.db.expenses).get();
      expect(rows.map((e) => (e.id, e.updatedAt != null, e.voidedAt != null)).toSet(), {('e1', true, true), ('e2', true, false)});
      expect((await store.watchTodayExpenses().first).total, 700, reason: 'same total from the server copies');
      final d = (await store.watchLatestDayClose(today()).first)!;
      expect((d.pending, d.serverExpectedCash), (false, d.expectedCash + 7), reason: 'the server figure came with the pull');
      expect((await store.cursors()).keys, containsAll(['expenses', 'day_closes']));
    });

    test('a refused approval parks the op for the user; a new approval sends it again, once', () async {
      server.requireApproval = true;
      await store.recordExpense(id: 'e1', amount: 1500, category: 'other', opId: 'o1');
      await store.closeDay(id: 'd1', day: today(), countedCash: 50, opId: 'o2');
      await engine.syncNow();
      final failed = await store.failedOps();
      expect(failed.map((o) => (o.kind, o.lastError)), [('record_expense', 'approval_required'), ('close_day', 'approval_required')]);
      expect(needsApproval(failed.first.lastError), isTrue);
      final e = (await todays()).single;
      expect((e.pending, e.rejectedHint), (true, 'approval_required'));
      expect((await store.watchLatestDayClose(today()).first)!.rejectedHint, 'approval_required');

      final pushes = server.pushedKinds.length;
      await engine.syncNow();
      expect(server.pushedKinds.length, pushes, reason: 'a refused op is not retried on its own');

      await store.requeueWithApproval(opId: 'o1', approvalId: server.issueApproval('record_expense', 'e1'));
      await store.requeueWithApproval(opId: 'o2', approvalId: server.issueApproval('record_expense', 'd1')); // wrong action
      await engine.syncNow();
      expect(server.expenses.keys, ['e1']);
      expect((await todays()).single.rejectedHint, isNull);
      expect((await store.failedOps()).single.lastError, 'approval_invalid');
      await expectLater(store.requeueWithApproval(opId: 'o1', approvalId: 'x'), throwsStateError, reason: 'o1 is gone');
    });

    test('an expired approval can be discarded: the expense disappears, a refused void is taken back', () async {
      server.requireApproval = true;
      final a1 = server.issueApproval('record_expense', 'e1');
      await store.recordExpense(id: 'e1', amount: 1500, category: 'other', approvalId: a1, opId: 'o1');
      final a2 = server.issueApproval('record_expense', 'e2');
      server.expiredApprovals.add(a2);
      await store.recordExpense(id: 'e2', amount: 900, category: 'other', approvalId: a2, opId: 'o2');
      await engine.syncNow();
      expect((await store.failedOps()).single.lastError, 'approval_expired');
      await store.discardFailed('o2');
      expect((await todays()).map((e) => e.id), ['e1']);

      await store.voidExpense(expenseId: 'e1', opId: 'o3'); // no approval
      await engine.syncNow();
      expect((await store.failedOps()).single.lastError, 'approval_required');
      expect((await todays()).single.voided, isTrue);
      await store.discardFailed('o3');
      expect((await todays()).single.voided, isFalse, reason: 'the server never voided it');
      expect((await store.watchTodayExpenses().first).total, 1500);
    });

    test('a temporary server error keeps the op queued and in order', () async {
      await store.closeDay(id: 'd1', day: today(), countedCash: 0, opId: 'o1');
      await store.recordExpense(id: 'e1', amount: 100, category: 'other', opId: 'o2');
      server.transientKind = 'close_day';
      await engine.syncNow();
      expect(server.applied, isEmpty, reason: 'the expense after the close was not applied early');
      expect((await store.watchOutboxCounts().first).pending, 2);
      server.transientKind = null;
      await engine.syncNow();
      expect(server.applied, hasLength(2));
    });

    test('pulls page by cursor, wait out the hold-back, and keep a void that is still on its way', () async {
      server.pageSize = 2;
      Map<String, dynamic> row(String id, int amount) => {
            'id': id, 'location_id': _loc, 'amount': amount, 'currency': 'PHP', 'category': 'other', 'note': null,
            'paid_from': 'cash', 'spent_at': pgTs(today()), 'created_by': 'u2', 'approved_by': null, 'voided_at': null,
            'void_reason': null, 'void_approved_by': null, 'updated_at': server.tick().toIso8601String(),
          };
      for (var i = 1; i <= 4; i++) {
        server.expenses['x$i'] = row('x$i', 100 * i);
      }
      server.clock = server.clock.add(const Duration(seconds: 30));
      server.expenses['x5'] = row('x5', 500)..['updated_at'] = server.clock.add(const Duration(seconds: 3)).toIso8601String();
      await engine.syncNow();
      expect((await todays()).map((e) => e.id).toSet(), {'x1', 'x2', 'x3', 'x4'}, reason: 'two pages; x5 is too new');
      expect((await todays()).every((e) => !e.pending), isTrue);

      await store.voidExpense(expenseId: 'x1', opId: 'v1'); // not sent yet ...
      server.expenses['x1']!['note'] = 'edited elsewhere';
      server.expenses['x1']!['updated_at'] = server.tick().toIso8601String();
      server.clock = server.clock.add(const Duration(seconds: 30));
      for (var more = true; more;) {
        // ... while the unvoided server copy comes
        final res = await server.pullExpenses((await store.cursors())['expenses'] as Map<String, dynamic>?);
        await store.applyPullExpenses(res);
        more = res['has_more'] == true;
      }
      final x1 = (await todays()).firstWhere((e) => e.id == 'x1');
      expect((x1.voided, x1.note, x1.pending), (true, 'edited elsewhere', true), reason: 'our void is kept');
      expect((await todays()).map((e) => e.id), contains('x5'));
      expect((await store.watchTodayExpenses().first).total, 200 + 300 + 400 + 500);

      await engine.syncNow();
      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      final after = (await todays()).firstWhere((e) => e.id == 'x1');
      expect((after.voided, after.pending), (true, false));
      expect((await store.db.select(store.db.expenses).get()).firstWhere((e) => e.id == 'x1').updatedAt, isNotNull);
      expect(server.expenses['x1']!['voided_at'], isNotNull);
    });
  });

  test('upgrading a v5 database keeps every row and adds the expense and day close tables', () async {
    final dir = Directory.systemTemp.createTempSync('xzpos_v5_');
    final file = File('${dir.path}/app.sqlite');
    final v5 = DriftStore(AppDatabase(NativeDatabase(file)));
    await seed(v5);
    await v5.saveCustomer(id: _cus, name: 'Rosa', opId: 'oc');
    await v5.commitSale(cashSale('s1', 4000), opId: 'o1');
    await v5.recordUtangPayment(customerId: _cus, amount: 500, opId: 'o2');
    await v5.db.customStatement('drop table expenses');
    await v5.db.customStatement('drop table day_closes');
    await v5.db.customStatement('drop table service_txns');
    await v5.db.customStatement('drop table wallet_float');
    await v5.db.customStatement('drop table local_float_effects');
    await v5.db.customStatement('PRAGMA user_version = 5');
    await v5.close();

    final v6 = DriftStore(AppDatabase(NativeDatabase(file)));
    await v6.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc); // same tenant: nothing cleared
    expect((await v6.getSale('s1'))!.summary.total, 4000);
    expect((await v6.watchCustomers().first).single.name, 'Rosa');
    expect((await v6.nextOps()).map((o) => o.opId), ['oc', 'o1', 'o2'], reason: 'unsent ops survive');
    expect(await v6.productCount(), 1);
    await v6.recordExpense(id: 'e1', amount: 1000, category: 'other', opId: 'o3');
    await v6.closeDay(id: 'd1', day: today(), countedCash: 3500, opId: 'o4');
    expect(await v6.expectedCash(today()), 4000 + 500 - 1000);
    expect((await v6.watchLatestDayClose(today()).first)!.difference, 3500 - 3500);
    final version = await v6.db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 8);
    await v6.close();
    dir.deleteSync(recursive: true);
  });

  test('the supervisor flow never stores a PIN: only the approval id travels', () async {
    const pin = '90817263';
    final backend = FakeBackend();
    expect((await backend.setMyPin(pin)).ok, isTrue);
    expect((await backend.approveSupervisorAction(action: 'record_expense', refId: 'e1', pin: '0000')).hint, 'pin_wrong');

    // the UI makes the id first, asks for the approval, then queues the op with the approval id
    final a = await backend.approveSupervisorAction(action: 'record_expense', refId: 'e1', pin: pin, locationId: _loc);
    expect(a.ok, isTrue);
    await store.recordExpense(id: 'e1', amount: 1500, category: 'other', approvalId: a.approvalId, opId: 'o1');
    final b = await backend.approveSupervisorAction(action: 'void_expense', refId: 'e1', pin: pin);
    await store.voidExpense(expenseId: 'e1', approvalId: b.approvalId, opId: 'o2');
    final c = await backend.approveSupervisorAction(action: 'close_day', refId: 'd1', pin: pin);
    await store.closeDay(id: 'd1', day: today(), countedCash: 0, approvalId: c.approvalId, opId: 'o3');

    expect(backend.approvalCalls, [('record_expense', 'e1'), ('record_expense', 'e1'), ('void_expense', 'e1'), ('close_day', 'd1')]);
    for (final op in await store.nextOps()) {
      expect(op.payload.keys.any((k) => k.contains('pin')), isFalse);
      expect(op.payload['approval_id'], isNotNull);
    }
    // every cell of every local table
    for (final t in store.db.allTables) {
      for (final row in await store.db.customSelect('select * from "${t.actualTableName}"').get()) {
        for (final v in row.data.values) {
          final text = v is Uint8List ? utf8.decode(v, allowMalformed: true) : '$v';
          expect(text.contains(pin), isFalse, reason: 'PIN found in ${t.actualTableName}');
          expect(text.toLowerCase().contains('"pin"'), isFalse, reason: 'a pin field in ${t.actualTableName}');
        }
      }
    }

    backend.offline = true;
    await expectLater(backend.approveSupervisorAction(action: 'close_day', refId: 'd2', pin: pin), throwsException,
        reason: 'no signal, no approval: the UI says the supervisor PIN needs signal');
  });

  test('ApprovalResult reads both server answers', () {
    final ok = ApprovalResult.fromJson(
        {'ok': true, 'approval_id': 'a1', 'approved_by': 'u9', 'expires_at': '2026-11-08T13:00:00.123456+00:00'});
    expect((ok.ok, ok.approvalId, ok.approvedBy, ok.expiresAt!.toUtc().hour, ok.hint), (true, 'a1', 'u9', 13, null));
    final no = ApprovalResult.fromJson({'ok': false, 'hint': 'pin_locked'});
    expect((no.ok, no.approvalId, no.hint), (false, null, 'pin_locked'));
  });
}

/// Builds a random day on [s] (seeded) and checks expectedCash against a sum kept here, independently of SQL.
/// Returns the expected value for today.
Future<int> buildRandomDay(DriftStore s, int seed) async {
  await s.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
  await s.applyPull(pullPage(
    products: [serverProduct(_p1, 'Kape')],
    variants: [serverVariant(_v1, _p1)],
    prices: [serverPrice(_v1, 1000)],
  ));
  await s.saveCustomer(id: _cus, name: 'Rosa', opId: 'oc-$seed');
  final r = Random(seed);
  final sales = <String, (int cash, bool today)>{};
  final voidedSales = <String>{};
  final expenses = <String, (int amount, bool cash, bool today)>{};
  final voidedExpenses = <String>{};
  var payments = 0;
  var n = 0;
  String id(String p) => '$p-$seed-${n++}';

  for (var step = 0; step < 60; step++) {
    final today = r.nextInt(5) != 0; // one in five lands on yesterday
    final at = today ? DateTime.now() : DateTime.now().subtract(const Duration(days: 1));
    switch (r.nextInt(6)) {
      case 0 || 1: // a sale with a random split
        final qty = 1 + r.nextInt(4);
        final price = 100 + r.nextInt(4900);
        final total = qty * price;
        final cash = switch (r.nextInt(4)) { 0 => total, 1 => 0, 2 => r.nextInt(total + 1), _ => total ~/ 2 };
        final rest = total - cash;
        final restMethod = r.nextBool() ? 'ewallet' : 'utang';
        final sid = id('s');
        await s.commitSale(
          SaleDraft(
            id: sid,
            soldAt: at,
            lines: [SaleLine(variantId: _v1, name: 'Kape', qty: qty.toDouble(), unitPrice: price)],
            payments: [if (cash > 0) PaymentDraft('cash', cash), if (rest > 0) PaymentDraft(restMethod, rest)],
            customerId: restMethod == 'utang' && rest > 0 ? _cus : null,
          ),
          opId: id('o'),
        );
        sales[sid] = (cash, today);
      case 2: // void a random sale
        final open = sales.keys.where((k) => !voidedSales.contains(k)).toList();
        if (open.isEmpty) break;
        final sid = open[r.nextInt(open.length)];
        await s.voidSale(sid, opId: id('o'));
        voidedSales.add(sid);
      case 3: // utang payment (always now)
        final amt = 1 + r.nextInt(3000);
        await s.recordUtangPayment(customerId: _cus, amount: amt, opId: id('o'));
        payments += amt;
      case 4: // expense
        final amt = 1 + r.nextInt(5000);
        final cash = r.nextInt(3) != 0;
        final eid = id('e');
        await s.recordExpense(
            id: eid, amount: amt, category: expenseCategories[r.nextInt(expenseCategories.length)],
            paidFrom: cash ? 'cash' : 'ewallet', spentAt: at, opId: id('o'));
        expenses[eid] = (amt, cash, today);
      case 5: // void a random expense
        final open = expenses.keys.where((k) => !voidedExpenses.contains(k)).toList();
        if (open.isEmpty) break;
        final eid = open[r.nextInt(open.length)];
        await s.voidExpense(expenseId: eid, opId: id('o'));
        voidedExpenses.add(eid);
    }
  }

  var want = payments;
  sales.forEach((k, v) {
    if (v.$2 && !voidedSales.contains(k)) want += v.$1;
  });
  expenses.forEach((k, v) {
    if (v.$2 && v.$3 && !voidedExpenses.contains(k)) want -= v.$1;
  });
  expect(await s.expectedCash(DateTime.now()), want, reason: 'seed $seed');
  // and yesterday on its own: no utang payments were made then
  var wantY = 0;
  sales.forEach((k, v) {
    if (!v.$2 && !voidedSales.contains(k)) wantY += v.$1;
  });
  expenses.forEach((k, v) {
    if (v.$2 && !v.$3 && !voidedExpenses.contains(k)) wantY -= v.$1;
  });
  expect(await s.expectedCash(DateTime.now().subtract(const Duration(days: 1))), wantY, reason: 'seed $seed yesterday');
  return want;
}
