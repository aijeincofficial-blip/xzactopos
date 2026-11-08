import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/utang_statement.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage;
import 'sales_store_test.dart' show posPage;

const _loc = '0190a000-0000-7000-8000-0000000000e1';
const _rosa = '0190a000-0000-7000-8000-0000000000c1';
const _berto = '0190a000-0000-7000-8000-0000000000c2';

Map<String, dynamic> customerRow(String id, String name, {String? due, String? phone, String at = '2026-11-08T00:00:00+00:00'}) =>
    {'id': id, 'name': name, 'phone': phone, 'due_on': due, 'updated_at': at, 'deleted_at': null};

Map<String, dynamic> charge(String id, String customer, int amount, {String kind = 'charge'}) => {
      'id': id, 'customer_id': customer, 'kind': kind, 'amount': amount, 'sale_id': null, 'note': null,
      'occurred_at': '2026-11-01T02:00:00+00:00', 'created_at': '2026-11-01T02:00:00+00:00',
    };

/// Behaves like sync_push (upsert_customer, set_utang_due) and the customers part of sync_pull_pos: once per op id, a
/// changed date moves the row's updated_at, rows newer than 5 s are held back. [refuse] makes set_utang_due refused.
class DueServer implements SyncApi {
  var clock = DateTime.utc(2026, 11, 8, 1);
  final applied = <String, Map<String, dynamic>>{};
  final customers = <String, Map<String, dynamic>>{};
  final pushed = <String>[];
  String? refuse;
  bool loseNextResponse = false;

  DateTime tick() => clock = clock.add(const Duration(seconds: 1));

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      final id = op['op_id'] as String;
      final p = op['payload'] as Map<String, dynamic>;
      pushed.add(op['kind'] as String);
      if (applied.containsKey(id)) {
        out.add({'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': true}});
        continue;
      }
      if (op['kind'] == 'set_utang_due' && refuse != null) {
        out.add({'op_id': id, 'status': 'rejected', 'code': '42501', 'hint': refuse});
        continue;
      }
      final at = tick().toIso8601String();
      switch (op['kind']) {
        case 'upsert_customer':
          customers[p['id'] as String] = customerRow(p['id'] as String, p['name'] as String, at: at);
        case 'set_utang_due':
          final c = customers[p['customer_id']]!;
          if (c['due_on'] != p['due_on']) {
            c['due_on'] = p['due_on'];
            c['updated_at'] = at;
          }
      }
      applied[id] = {'applied_at': at};
      out.add({'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': false}});
    }
    if (loseNextResponse) {
      loseNextResponse = false;
      throw Exception('connection lost');
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async {
    final now = tick();
    final upto = now.subtract(const Duration(seconds: 5));
    final rows = [
      for (final c in customers.values)
        if (!DateTime.parse(c['updated_at'] as String).isAfter(upto)) Map<String, dynamic>.of(c)
    ];
    return {
      'server_time': now.toIso8601String(),
      'stock_levels': {'rows': [], 'cursor': null, 'has_more': false},
      'customers': {'rows': rows, 'cursor': null, 'has_more': false},
      'customer_ledger': {'rows': [], 'cursor': null, 'has_more': false},
    };
  }

  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async => pullPage();
  @override
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullExpenses(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullDayCloses(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100}) async =>
      {'rows': <dynamic>[], 'has_more': false};
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
  final today = dateOnly(DateTime.now());
  DateTime inDays(int n) => DateTime(today.year, today.month, today.day + n);

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
  });
  tearDown(() => store.close());

  Future<CustomerView> rosa(DriftStore s) async => (await s.watchCustomers().first).firstWhere((c) => c.id == _rosa);

  group('setting a due date', () {
    setUp(() => store.applyPullPos(posPage(customers: [customerRow(_rosa, 'Aling Rosa', phone: '0917')])));

    test('shows at once (date only) and queues one set_utang_due op for the customer; clearing works the same', () async {
      await store.setUtangDue(customerId: _rosa, dueOn: DateTime(today.year, today.month, today.day + 7, 15, 45), opId: 'd1');
      final c = await rosa(store);
      expect((c.dueOn, c.pending), (inDays(7), true));
      final op = (await store.nextOps()).single;
      expect((op.kind, op.entityId), ('set_utang_due', _rosa));
      expect(op.payload, {'customer_id': _rosa, 'due_on': dayKey(inDays(7))});

      await store.setUtangDue(customerId: _rosa, dueOn: null, opId: 'd2');
      expect((await rosa(store)).dueOn, isNull);
      expect((await store.nextOps()).last.payload, {'customer_id': _rosa, 'due_on': null});
    });

    test('a date too far away or an unknown customer is refused before anything is written', () async {
      expect(() => store.setUtangDue(customerId: _rosa, dueOn: inDays(utangDueMaxDays + 1), opId: 'x1'), throwsArgumentError);
      expect(() => store.setUtangDue(customerId: _rosa, dueOn: inDays(-utangDueMaxDays - 1), opId: 'x2'), throwsArgumentError);
      await expectLater(store.setUtangDue(customerId: 'nobody', dueOn: inDays(3), opId: 'x3'), throwsStateError);
      expect(await store.nextOps(), isEmpty);
      await store.setUtangDue(customerId: _rosa, dueOn: inDays(utangDueMaxDays), opId: 'ok1');
      await store.setUtangDue(customerId: _rosa, dueOn: inDays(-3), opId: 'ok2'); // a promise already missed
      expect((await store.nextOps()).map((o) => o.opId), ['ok1', 'ok2']);
    });

    test('saving the name later keeps the date', () async {
      await store.setUtangDue(customerId: _rosa, dueOn: inDays(2), opId: 'd1');
      await store.saveCustomer(id: _rosa, name: 'Rosa Cruz', opId: 'c1');
      expect(((await rosa(store)).name, (await rosa(store)).dueOn), ('Rosa Cruz', inDays(2)));
    });
  });

  group('overdue', () {
    // a fixed "today": 2026-11-08
    final day = DateTime(2026, 11, 8);
    setUp(() => store.applyPullPos(posPage(
          customers: [
            customerRow('c-yday', 'Yolly', due: '2026-11-07'), // owes, due yesterday: overdue 1 day
            customerRow('c-today', 'Tess', due: '2026-11-08'), // owes, due today: not overdue yet
            customerRow('c-old', 'Odet', due: '2026-11-03'), // owes, 5 days late: first
            customerRow('c-paid', 'Pilar', due: '2026-11-01'), // paid up: not overdue
            customerRow('c-ahead', 'Ambo', due: '2026-11-02'), // paid ahead: not overdue
            customerRow('c-none', 'Nida'), // owes, no date: not overdue
            customerRow('c-tie', 'Abe', due: '2026-11-03'), // same date as Odet: by name
          ],
          ledger: [
            charge('g1', 'c-yday', 1500), charge('g2', 'c-today', 900), charge('g3', 'c-old', 3000),
            charge('g4', 'c-paid', 2000), charge('g5', 'c-paid', -2000, kind: 'payment'),
            charge('g6', 'c-ahead', -500, kind: 'payment'), charge('g7', 'c-none', 700), charge('g8', 'c-tie', 100),
          ],
        )));

    test('lists who owes and is past the date, most overdue first; due today is not overdue, yesterday is', () async {
      final list = await store.watchOverdueCustomers(today: day).first;
      expect(list.map((c) => c.name), ['Abe', 'Odet', 'Yolly']);
      expect(list.map((c) => c.daysOverdue(day)), [5, 5, 1]);
      expect(await store.overdueCount(today: day), 3);

      final all = {for (final c in await store.watchCustomers().first) c.id: c};
      expect(all['c-today']!.overdue(day), isFalse, reason: 'due today');
      expect(all['c-today']!.overdue(DateTime(2026, 11, 9, 0, 1)), isTrue, reason: 'one minute into the next day');
      expect(all['c-today']!.daysOverdue(DateTime(2026, 11, 9, 23, 59)), 1);
      expect(all['c-yday']!.overdue(DateTime(2026, 11, 8, 23, 59)), isTrue);
      expect((all['c-paid']!.overdue(day), all['c-ahead']!.overdue(day), all['c-none']!.overdue(day)), (false, false, false));
      expect(all['c-paid']!.daysOverdue(day), 0);
      expect(all['c-old']!.dueOn, DateTime(2026, 11, 3));
    });

    test('paying in full takes her off the list at once; moving the date does too', () async {
      await store.recordUtangPayment(customerId: 'c-yday', amount: 1500, opId: 'p1');
      expect((await store.watchOverdueCustomers(today: day).first).map((c) => c.name), ['Abe', 'Odet']);
      await store.setUtangDue(customerId: 'c-old', dueOn: inDays(5), opId: 'd1'); // after the fixed day
      expect((await store.watchOverdueCustomers(today: day).first).map((c) => c.name), ['Abe']);
      expect(await store.overdueCount(today: DateTime(2026, 11, 3)), 0, reason: 'nobody is late on the 3rd');
    });
  });

  group('sync', () {
    late DueServer server;
    late SyncEngine engine;
    setUp(() async {
      server = DueServer();
      engine = SyncEngine(store, server);
      await store.saveCustomer(id: _rosa, name: 'Aling Rosa', opId: 'c1');
      await store.saveCustomer(id: _berto, name: 'Berto', opId: 'c2');
    });
    tearDown(() => engine.dispose());

    test('reaches the server once even when the reply is lost; the server copy replaces the local one', () async {
      await store.setUtangDue(customerId: _rosa, dueOn: inDays(4), opId: 'd1');
      server.loseNextResponse = true;
      await engine.syncNow();
      expect((await store.watchOutboxCounts().first).pending, greaterThan(0));
      await engine.syncNow(); // the same op ids again
      expect((await store.watchOutboxCounts().first).pending, 0);
      expect(server.pushed.where((k) => k == 'set_utang_due'), hasLength(2), reason: 'sent twice, applied once');
      expect(server.customers[_rosa]!['due_on'], dayKey(inDays(4)));
      expect((await rosa(store)).dueOn, inDays(4), reason: 'unchanged while the server copy is held back');

      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      final c = await rosa(store);
      expect((c.dueOn, c.pending), (inDays(4), false));
      final row = (await store.db.select(store.db.customers).get()).firstWhere((x) => x.id == _rosa);
      expect(row.updatedAt, isNotNull, reason: 'the server copy arrived');
    });

    test('while an op is unsent the pulled row does not overwrite the local date', () async {
      await engine.syncNow();
      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      await store.setUtangDue(customerId: _rosa, dueOn: inDays(9), opId: 'd1');
      await store.applyPullPos(await server.pullPos({})); // the server copy, still without the date
      expect((await rosa(store)).dueOn, inDays(9));
      server.customers[_berto]!['due_on'] = dayKey(inDays(1)); // a date set on another device
      server.customers[_berto]!['updated_at'] = server.clock.toIso8601String();
      server.clock = server.clock.add(const Duration(seconds: 30));
      await store.applyPullPos(await server.pullPos({}));
      expect((await store.watchCustomers().first).firstWhere((c) => c.id == _berto).dueOn, inDays(1),
          reason: 'a date set elsewhere arrives through the customers pull');
    });

    test('a refused op is parked; discarding it brings the server date back', () async {
      await store.setUtangDue(customerId: _rosa, dueOn: inDays(2), opId: 'd1');
      await engine.syncNow();
      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      server.refuse = 'not_allowed';
      await store.setUtangDue(customerId: _rosa, dueOn: inDays(6), opId: 'd2');
      await engine.syncNow();
      expect((await store.failedOps()).map((o) => (o.kind, o.lastError)), [('set_utang_due', 'not_allowed')]);
      expect((await rosa(store)).dueOn, inDays(6), reason: 'refused but not discarded: still shown');
      await store.discardFailed('d2');
      await engine.syncNow();
      final c = await rosa(store);
      expect((c.dueOn, c.pending), (inDays(2), false), reason: 'the re-pull brought the server date');
    });
  });

  test('upgrading a v8 database keeps every customer and unsent op, adds due_on and pulls customers again', () async {
    final dir = Directory.systemTemp.createTempSync('xzpos_v8_');
    final file = File('${dir.path}/app.sqlite');
    final v8 = DriftStore(AppDatabase(NativeDatabase(file)));
    await v8.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
    await v8.applyPullPos(posPage(customers: [customerRow(_rosa, 'Aling Rosa', phone: '0917')], ledger: [charge('g1', _rosa, 2500)]));
    await v8.recordUtangPayment(customerId: _rosa, amount: 500, opId: 'p1');
    await v8.db.customStatement('alter table customers drop column due_on');
    await v8.db.customStatement("insert or replace into sync_cursors values ('customers', '{}'), ('stock_levels', '{}')");
    await v8.db.customStatement('PRAGMA user_version = 8');
    await v8.close();

    final v9 = DriftStore(AppDatabase(NativeDatabase(file)));
    await v9.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc); // same tenant: nothing cleared
    final c = await rosa(v9);
    expect((c.name, c.phone, c.balance, c.dueOn), ('Aling Rosa', '0917', 2000, null));
    expect((await v9.nextOps()).map((o) => o.opId), ['p1'], reason: 'unsent ops survive');
    // F-01 (schema v13): the upgrade also passes the v13 step, which pulls the utang ledger again (it now carries the
    // store and payment method), so only stock_levels keeps its cursor
    expect((await v9.cursors()).keys.toSet(), {'stock_levels'},
        reason: 'customers are pulled again for the date (and the ledger for its store); the other cursors stay');
    final version = await v9.db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, v9.db.schemaVersion);
    await v9.setUtangDue(customerId: _rosa, dueOn: inDays(3), opId: 'd1');
    expect((await rosa(v9)).dueOn, inDays(3));
    await v9.close();
    dir.deleteSync(recursive: true);
  });

  group('statement text', () {
    const labels = StatementLabels(
      title: 'Utang statement',
      balance: 'Balance',
      dueOn: 'Due on',
      recent: 'Recent',
      charge: 'Took on utang',
      payment: 'Paid',
      adjust: 'Adjustment',
    );
    LedgerEntryView e(String kind, int amount, DateTime at) => LedgerEntryView(kind: kind, amount: amount, at: at, pending: false);
    const customer = CustomerView(id: 'c1', name: ' Aling Rosa ', phone: '09171234567', balance: 15050, pending: false);

    test('store, customer, balance, due date and the newest lines with signed amounts; never the phone number', () {
      final text = utangStatementText(
        storeName: 'Tindahan ni Nena',
        customer: CustomerView(
            id: 'c1', name: 'Aling Rosa', phone: '09171234567', balance: 15050, pending: false, dueOn: DateTime(2026, 11, 15)),
        ledger: [
          e('payment', -5000, DateTime(2026, 11, 7, 9)),
          e('charge', 20000, DateTime(2026, 11, 1, 18, 30)),
          e('adjust', 50, DateTime(2026, 11, 8, 8)),
        ],
        currency: 'PHP',
        locale: 'en',
        labels: labels,
      );
      expect(
          text,
          'Tindahan ni Nena\n'
          'Utang statement: Aling Rosa\n'
          'Balance: ₱150.50\n'
          'Due on: 2026-11-15\n'
          '\n'
          'Recent:\n'
          '2026-11-08  Adjustment  +₱0.50\n'
          '2026-11-07  Paid  -₱50.00\n'
          '2026-11-01  Took on utang  +₱200.00');
      expect(text.contains('0917'), isFalse);
    });

    test('no due date, no lines: just the balance; a balance paid ahead shows a minus', () {
      expect(
          utangStatementText(
              storeName: ' Sari-sari ', customer: customer, ledger: const [], currency: 'PHP', locale: 'en', labels: labels),
          'Sari-sari\nUtang statement: Aling Rosa\nBalance: ₱150.50');
      expect(
          utangStatementText(
              storeName: 'S',
              customer: const CustomerView(id: 'c', name: 'Ben', balance: -250, pending: false),
              ledger: const [],
              currency: 'PHP',
              locale: 'en',
              labels: labels),
          'S\nUtang statement: Ben\nBalance: -₱2.50');
    });

    test('at most the 10 newest lines, newest first; same moment keeps the given order', () {
      final ledger = [
        for (var d = 1; d <= 12; d++) e('charge', d * 100, DateTime(2026, 10, d, 12)),
        e('payment', -100, DateTime(2026, 10, 12, 12)), // same moment as the 12th charge, given after it
      ];
      final lines = utangStatementText(
              storeName: 'S', customer: customer, ledger: ledger, currency: 'PHP', locale: 'en', labels: labels)
          .split('\n');
      final body = lines.sublist(lines.indexOf('Recent:') + 1);
      expect(body, hasLength(statementMaxLines));
      expect(body.first, '2026-10-12  Took on utang  +₱12.00');
      expect(body[1], '2026-10-12  Paid  -₱1.00');
      expect(body.last, '2026-10-04  Took on utang  +₱4.00');
    });

    test('Filipino labels and locale, a large amount with thousands separators', () {
      const fil = StatementLabels(
          title: 'Listahan ng utang', balance: 'Utang', dueOn: 'Babayaran sa', recent: 'Huling tala',
          charge: 'Umutang', payment: 'Nagbayad', adjust: 'Inayos');
      final text = utangStatementText(
        storeName: 'Tindahan',
        customer: CustomerView(id: 'c', name: 'Berto', balance: 123456789, pending: false, dueOn: DateTime(2027, 1, 5)),
        ledger: [e('charge', 123456789, DateTime(2026, 12, 24, 20))],
        currency: 'PHP',
        locale: 'fil',
        labels: fil,
      );
      expect(
          text,
          'Tindahan\nListahan ng utang: Berto\nUtang: ₱1,234,567.89\nBabayaran sa: 2027-01-05\n\n'
          'Huling tala:\n2026-12-24  Umutang  +₱1,234,567.89');
    });
  });
}
