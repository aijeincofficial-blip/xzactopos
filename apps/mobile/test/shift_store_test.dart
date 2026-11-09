import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/shift_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'expenses_test.dart' show cashSale, pgTs;
import 'sales_store_test.dart' show posPage;
import 'sync_engine_test.dart' show FakeApi;

// F-05m: cashier shifts on the phone: open and close offline, the X reading, sync with the server.

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _loc = '0190a000-0000-7000-8000-0000000000e1';
const _cus = '0190a000-0000-7000-8000-0000000000c1';
const _juan = 'user-juan';
const _pia = 'user-pia';

/// A server that behaves like the real one where it matters to the phone: opens and closes shifts once per op id, computes its
/// own expected cash, refuses a second open shift, holds back rows younger than 5 s and pages a pull by (updated_at, id).
class ShiftServer extends FakeApi implements ShiftApi {
  DateTime now = DateTime.utc(2026, 11, 9, 9);
  int serverExpected = 0;
  final shifts = <String, Map<String, dynamic>>{};
  final pushed = <Map<String, dynamic>>[];
  final pulls = <Map<String, dynamic>?>[];
  final _done = <String, Map<String, dynamic>>{};

  String iso(DateTime t) => t.toUtc().toIso8601String();

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    if (offline) throw Exception('no signal');
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      pushed.add(op);
      final opId = op['op_id'] as String;
      if (_done.containsKey(opId)) {
        out.add({'op_id': opId, 'status': 'ok', 'result': {..._done[opId]!, 'replay': true}});
        continue;
      }
      final p = (op['payload'] as Map).cast<String, dynamic>();
      switch (op['kind']) {
        case 'open_shift':
          if (shifts.values.any((s) => s['cashier_id'] == _juan && s['closed_at'] == null)) {
            out.add({'op_id': opId, 'status': 'rejected', 'hint': 'shift_already_open'});
            continue;
          }
          shifts[p['id'] as String] = {
            'id': p['id'], 'location_id': p['location_id'], 'cashier_id': _juan, 'currency': 'PHP ', 'opening_cash': p['opening_cash'],
            'opened_at': p['opened_at'], 'closed_at': null, 'expected_cash': null, 'server_expected_cash': null,
            'counted_cash': null, 'difference': null, 'note': null, 'closed_by': null, 'updated_at': iso(now),
          };
          _done[opId] = {'shift_id': p['id'], 'opened_at': p['opened_at'], 'applied_at': iso(now)};
        case 'close_shift':
          final s = shifts[p['id']];
          if (s == null) {
            out.add({'op_id': opId, 'status': 'rejected', 'hint': 'shift_not_found'});
            continue;
          }
          s
            ..['closed_at'] = p['closed_at']
            ..['expected_cash'] = p['expected_cash']
            ..['server_expected_cash'] = serverExpected
            ..['counted_cash'] = p['counted_cash']
            ..['difference'] = (p['counted_cash'] as int) - (p['expected_cash'] as int)
            ..['note'] = p['note']
            ..['closed_by'] = _juan
            ..['updated_at'] = iso(now);
          _done[opId] = {'shift_id': p['id'], 'difference': s['difference'], 'server_expected_cash': serverExpected, 'applied_at': iso(now)};
        default:
          out.add({'op_id': opId, 'status': 'rejected', 'hint': 'unknown_kind'});
          continue;
      }
      out.add({'op_id': opId, 'status': 'ok', 'result': {..._done[opId]!, 'replay': false}});
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>> pullShifts(Map<String, dynamic>? cursor, {int limit = 100}) async {
    if (offline) throw Exception('no signal');
    pulls.add(cursor);
    final horizon = now.subtract(const Duration(seconds: 5));
    final rows = shifts.values
        .where((s) => !DateTime.parse(s['updated_at'] as String).isAfter(horizon))
        .where((s) => cursor == null || (s['updated_at'] as String).compareTo(cursor['ts'] as String) > 0)
        .toList()
      ..sort((a, b) => (a['updated_at'] as String).compareTo(b['updated_at'] as String));
    final page = rows.take(limit).toList();
    return {
      'rows': page,
      'cursor': page.isEmpty ? cursor : {'ts': page.last['updated_at'], 'k': page.last['id']},
      'has_more': rows.length > limit,
    };
  }

  @override
  Future<int?> shiftExpectedNow(String shiftId) async => offline ? null : serverExpected;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 1000)],
    ));
  });
  tearDown(() => store.close());

  Future<T> first<T>(Stream<T> s) => s.first;

  group('opening a shift', () {
    test('is saved at once and queued for the server', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, openingCash: 20000, opId: 'op-open');
      final s = (await store.openShift(_juan))!;
      expect([s.id, s.openingCash, s.isOpen, s.pending, s.locationId, s.currency], ['sh-1', 20000, true, true, _loc, 'PHP']);
      final ops = await store.nextOps();
      expect(ops.single.kind, 'open_shift');
      expect(ops.single.payload, {'id': 'sh-1', 'location_id': _loc, 'opening_cash': 20000, 'opened_at': ops.single.payload['opened_at']});
      expect(DateTime.parse(ops.single.payload['opened_at'] as String).difference(DateTime.now().toUtc()).inSeconds.abs(), lessThan(30));
    });

    test('the watch follows the open shift and goes empty after the close', () async {
      final seen = <String?>[];
      final sub = store.watchOpenShift(_juan).listen((s) => seen.add(s?.id));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-open');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await store.closeShift(id: 'sh-1', countedCash: 0, expectedCash: 0, opId: 'op-close');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sub.cancel();
      expect(seen, [null, 'sh-1', null]);
    });

    test('a cashier with a shift open cannot open another; another cashier can', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-1');
      await expectLater(store.startShift(id: 'sh-2', cashierId: _juan, opId: 'op-2'),
          throwsA(isA<ShiftException>().having((e) => e.code, 'code', 'shift_already_open')));
      await store.startShift(id: 'sh-3', cashierId: _pia, opId: 'op-3');
      expect((await store.nextOps()).map((o) => o.opId), ['op-1', 'op-3'], reason: 'the refused one queued nothing');
    });

    test('an id that is already used, or opening cash below zero, is refused', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-1');
      await store.closeShift(id: 'sh-1', countedCash: 0, expectedCash: 0, opId: 'op-c');
      await expectLater(store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-2'),
          throwsA(isA<ShiftException>().having((e) => e.code, 'code', 'id_used')));
      expect(() => store.startShift(id: 'sh-9', cashierId: _juan, openingCash: -1, opId: 'op-9'), throwsArgumentError);
    });

    test('the next shift can start once the last one is closed', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-1');
      await store.closeShift(id: 'sh-1', countedCash: 0, expectedCash: 0, opId: 'op-c');
      await store.startShift(id: 'sh-2', cashierId: _juan, opId: 'op-2');
      expect((await store.openShift(_juan))!.id, 'sh-2');
    });
  });

  group('the X reading', () {
    test('adds up this shift: opening cash, cash sales, utang taken, cash expenses, load, and counts the rest', () async {
      final opened = DateTime.now().subtract(const Duration(hours: 1));
      await store.startShift(id: 'sh-1', cashierId: _juan, openingCash: 20000, opId: 'op-open', at: opened);
      await store.saveCustomer(id: _cus, name: 'Rosa', opId: 'oc');
      await store.commitSale(cashSale('s1', 10000), opId: 'o1'); // cash
      await store.commitSale(cashSale('s2', 2000, method: 'ewallet'), opId: 'o2'); // not cash
      await store.commitSale(cashSale('s3', 3000, method: 'utang', customer: _cus), opId: 'o3'); // not cash
      await store.commitSale(cashSale('s4', 5000), opId: 'o4');
      await store.voidSale('s4', opId: 'o5'); // voided: out
      await store.commitSale(cashSale('s5', 900, at: DateTime.now().subtract(const Duration(hours: 2))), opId: 'o6'); // before the shift
      await store.recordUtangPayment(customerId: _cus, amount: 1500, opId: 'o7');
      await store.recordExpense(id: 'e1', amount: 2500, category: 'utilities', opId: 'o8');
      await store.recordExpense(id: 'e2', amount: 1000, category: 'transport', paidFrom: 'ewallet', opId: 'o9'); // not cash
      await store.recordServiceTxn(id: 'v1', kind: 'cash_in', wallet: 'gcash', amount: 2000, fee: 50, opId: 'o10');

      final x = (await store.xReading('sh-1'))!;
      expect([x.openingCash, x.cashSales, x.utangCash, x.expensesCash, x.serviceCash], [20000, 10000, 1500, 2500, 2050]);
      expect(x.expected, 20000 + 10000 + 1500 - 2500 + 2050);
      expect([x.salesCount, x.grossSales, x.ewalletSales, x.utangSales], [3, 15000, 2000, 3000]);
    });

    test('utang cash that another phone took counts, in the time format of the server, and a voided or e-wallet expense does not', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, openingCash: 0, opId: 'op-open', at: DateTime.now().subtract(const Duration(hours: 1)));
      await store.saveCustomer(id: _cus, name: 'Rosa', opId: 'oc');
      await store.applyPullPos(posPage(ledger: [
        {'id': 'g1', 'customer_id': _cus, 'kind': 'payment', 'amount': -700, 'sale_id': null, 'note': null,
         'occurred_at': pgTs(DateTime.now()), 'created_at': '2026-11-08T00:00:00+00:00', 'method': 'cash'},
        {'id': 'g2', 'customer_id': _cus, 'kind': 'payment', 'amount': -800, 'sale_id': null, 'note': null,
         'occurred_at': pgTs(DateTime.now().subtract(const Duration(hours: 3))), 'created_at': '2026-11-08T00:00:00+00:00', 'method': 'cash'},
      ], serverTime: '2026-11-07T00:00:00+00:00'));
      await store.recordExpense(id: 'e1', amount: 600, category: 'other', opId: 'o1');
      await store.voidExpense(expenseId: 'e1', opId: 'o2');
      await store.recordExpense(id: 'e2', amount: 400, category: 'other', paidFrom: 'ewallet', opId: 'o3');
      final x = (await store.xReading('sh-1'))!;
      expect(x.utangCash, 700, reason: 'the one before the shift is out');
      expect(x.expensesCash, 0);
    });

    test('leaves out cash sales that other phones made', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-open', at: DateTime.now().subtract(const Duration(hours: 1)));
      await store.commitSale(cashSale('mine', 4000), opId: 'o1');
      final at = DateTime.now().toUtc().toIso8601String();
      await store.db.into(store.db.sales).insert(SalesCompanion.insert(
          id: 'theirs', locationId: const Value(_loc), localNo: 'X-1', subtotal: 7000, total: 7000, soldAt: at, deviceId: const Value('another-phone')));
      await store.db.into(store.db.salePayments).insert(SalePaymentsCompanion.insert(saleId: 'theirs', method: 'cash', amount: 7000));
      final x = (await store.xReading('sh-1'))!;
      expect(x.cashSales, 4000);
      expect(x.salesCount, 1);
    });

    test('reading it changes nothing: no op is queued and the shift stays open', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-open');
      await store.xReading('sh-1');
      expect((await store.nextOps()).length, 1);
      expect((await store.openShift(_juan))!.isOpen, isTrue);
    });

    test('a closed shift is read up to its close, not beyond', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-open', at: DateTime.now().subtract(const Duration(hours: 2)));
      await store.commitSale(cashSale('s1', 1000, at: DateTime.now().subtract(const Duration(minutes: 90))), opId: 'o1');
      await store.closeShift(id: 'sh-1', countedCash: 1000, expectedCash: 1000, opId: 'op-c', at: DateTime.now().subtract(const Duration(hours: 1)));
      await store.commitSale(cashSale('s2', 5000), opId: 'o2'); // after the close
      expect((await store.xReading('sh-1'))!.cashSales, 1000);
    });

    test('an unknown shift has no reading', () async {
      expect(await store.xReading('nope'), isNull);
    });
  });

  group('closing a shift', () {
    test('records the count and the difference, and queues one close', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, openingCash: 5000, opId: 'op-open');
      await store.closeShift(id: 'sh-1', countedCash: 4900, expectedCash: 5000, note: '  short a hundred  ', opId: 'op-close');
      final s = (await store.shift('sh-1'))!;
      expect([s.isOpen, s.countedCash, s.expectedCash, s.difference, s.note], [false, 4900, 5000, -100, 'short a hundred']);
      final close = (await store.nextOps()).last;
      expect(close.kind, 'close_shift');
      expect(close.payload, {'id': 'sh-1', 'counted_cash': 4900, 'expected_cash': 5000, 'closed_at': close.payload['closed_at'], 'note': 'short a hundred'});
    });

    test('an unknown or already closed shift is refused, and so is a negative count', () async {
      await expectLater(store.closeShift(id: 'nope', countedCash: 0, expectedCash: 0, opId: 'o'),
          throwsA(isA<ShiftException>().having((e) => e.code, 'code', 'shift_not_found')));
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-open');
      expect(() => store.closeShift(id: 'sh-1', countedCash: -1, expectedCash: 0, opId: 'o'), throwsArgumentError);
      await store.closeShift(id: 'sh-1', countedCash: 0, expectedCash: 0, opId: 'op-c');
      await expectLater(store.closeShift(id: 'sh-1', countedCash: 0, expectedCash: 0, opId: 'op-c2'),
          throwsA(isA<ShiftException>().having((e) => e.code, 'code', 'shift_closed')));
      expect((await store.nextOps()).length, 2, reason: 'only the first close is queued');
    });

    test('a long note is cut to 200 characters and a blank one is dropped', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-open');
      await store.closeShift(id: 'sh-1', countedCash: 0, expectedCash: 0, note: 'x' * 300, opId: 'op-c');
      expect((await store.shift('sh-1'))!.note!.length, 200);
      await store.startShift(id: 'sh-2', cashierId: _pia, opId: 'op-open2');
      await store.closeShift(id: 'sh-2', countedCash: 0, expectedCash: 0, note: '   ', opId: 'op-c2');
      expect((await store.shift('sh-2'))!.note, isNull);
    });

    test('the history lists shifts newest first', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-1', at: DateTime.now().subtract(const Duration(days: 2)));
      await store.closeShift(id: 'sh-1', countedCash: 0, expectedCash: 0, opId: 'op-c1', at: DateTime.now().subtract(const Duration(days: 2, hours: -1)));
      await store.startShift(id: 'sh-2', cashierId: _juan, opId: 'op-2', at: DateTime.now().subtract(const Duration(hours: 1)));
      expect([for (final s in await first(store.watchShifts())) s.id], ['sh-2', 'sh-1']);
    });
  });

  group('sync', () {
    late ShiftServer server;
    late SyncEngine engine;

    setUp(() {
      server = ShiftServer();
      engine = SyncEngine(store, server);
    });

    test('opening and closing go to the server in order, and the server\'s own figure comes back', () async {
      server.serverExpected = 5050;
      await store.startShift(id: 'sh-1', cashierId: _juan, openingCash: 5000, opId: 'op-open');
      await store.closeShift(id: 'sh-1', countedCash: 4900, expectedCash: 5000, opId: 'op-close');
      await engine.syncNow();
      expect(server.pushed.map((o) => o['kind']), ['open_shift', 'close_shift']);
      expect(await store.nextOps(), isEmpty);
      final s = (await store.shift('sh-1'))!;
      expect([s.pending, s.expectedCash, s.serverExpectedCash, s.serverDisagrees], [false, 5000, 5050, true]);
    });

    test('a shift closed offline waits, then goes through after the signal comes back', () async {
      server.offline = true;
      await store.startShift(id: 'sh-1', cashierId: _juan, openingCash: 100, opId: 'op-open');
      await store.closeShift(id: 'sh-1', countedCash: 100, expectedCash: 100, opId: 'op-close');
      await engine.syncNow(); // no signal: the engine backs off and keeps the ops
      expect((await store.nextOps()).length, 2);
      expect((await store.shift('sh-1'))!.pending, isTrue);
      server.offline = false;
      await engine.syncNow();
      expect(await store.nextOps(), isEmpty);
      expect(server.shifts['sh-1']!['counted_cash'], 100);
    });

    test('a shift opened on another phone comes in with the pull', () async {
      server.shifts['far'] = {
        'id': 'far', 'location_id': _loc, 'cashier_id': _juan, 'currency': 'PHP ', 'opening_cash': 3000,
        'opened_at': '2026-11-09T07:00:00+00:00', 'closed_at': null, 'expected_cash': null, 'server_expected_cash': null,
        'counted_cash': null, 'difference': null, 'note': null, 'closed_by': null, 'updated_at': '2026-11-09T07:00:00+00:00',
      };
      await engine.syncNow();
      final s = (await store.openShift(_juan))!;
      expect([s.id, s.openingCash, s.pending], ['far', 3000, false]);
      expect((await store.shiftCursor())!['k'], 'far', reason: 'the next pull continues after this row');
    });

    test('the pull never undoes a change of this phone that is still unsent', () async {
      await store.startShift(id: 'sh-1', cashierId: _juan, openingCash: 100, opId: 'op-open');
      await engine.syncNow();
      server.now = server.now.add(const Duration(minutes: 1));
      server.offline = true;
      await store.closeShift(id: 'sh-1', countedCash: 90, expectedCash: 100, opId: 'op-close');
      server.offline = false;
      // the server still has the shift open; a pull must not reopen it on the phone while the close is unsent
      await store.applyPullShifts(await server.pullShifts(null));
      expect((await store.shift('sh-1'))!.isOpen, isFalse);
      await engine.syncNow();
      expect((await store.shift('sh-1'))!.countedCash, 90);
    });

    test('a refused open is shown as refused, and discarding it takes the shift off the phone', () async {
      // the server already has an open shift for this cashier (opened on another phone) that this phone has not heard of
      server.shifts['x'] = {
        'id': 'x', 'location_id': _loc, 'cashier_id': _juan, 'currency': 'PHP ', 'opening_cash': 0,
        'opened_at': '2026-11-09T06:00:00+00:00', 'closed_at': null, 'expected_cash': null, 'server_expected_cash': null,
        'counted_cash': null, 'difference': null, 'note': null, 'closed_by': null, 'updated_at': '2026-11-09T06:00:00+00:00',
      };
      await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-open');
      await engine.syncNow();
      expect((await store.shift('sh-1'))!.rejectedHint, 'shift_already_open');
      await store.discardFailed('op-open');
      expect(await store.shift('sh-1'), isNull);
      expect(await store.nextOps(), isEmpty);
    });
  });

  test('the shifts of another business never stay on the phone', () async {
    await store.startShift(id: 'sh-1', cashierId: _juan, opId: 'op-1');
    await store.ensureTenant('tenant-b', baseCurrency: 'PHP', locationId: _loc, discardUnsent: true);
    expect(await store.openShift(_juan), isNull);
    expect(await store.shiftCursor(), isNull);
  });

  test('a version 15 device upgrades with every row and unsent op kept', () async {
    final dir = await Directory.systemTemp.createTemp('shift_migrate');
    final file = File('${dir.path}/app.db');
    try {
      final v16 = DriftStore(AppDatabase(NativeDatabase(file)));
      await v16.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
      await v16.saveCustomer(id: 'c1', name: 'Aling Nena', opId: 'op-keep');
      await v16.startShift(id: 'gone', cashierId: _juan, opId: 'op-shift');
      await v16.db.customStatement('DROP TABLE IF EXISTS shifts');
      await v16.db.customStatement('PRAGMA user_version = 15');
      await v16.close();

      final upgraded = DriftStore(AppDatabase(NativeDatabase(file)));
      await upgraded.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
      final version = await upgraded.db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, upgraded.db.schemaVersion);
      expect([for (final o in await upgraded.nextOps()) o.opId], containsAll(['op-keep', 'op-shift']), reason: 'unsent ops survive');
      expect(await upgraded.openShift(_juan), isNull, reason: 'the new table starts empty; the first pull fills it');
      await upgraded.startShift(id: 'again', cashierId: _juan, opId: 'op-again');
      expect((await upgraded.openShift(_juan))!.id, 'again');
      await upgraded.close();
    } finally {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold the SQLite file for a moment; a leftover temp folder is harmless
      }
    }
  });
}
