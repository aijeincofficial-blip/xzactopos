import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'expenses_test.dart' show ExpenseServer, cashSale, pgTs;

// P8-14: opening cash (sukli) in the day close.

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _loc = '0190a000-0000-7000-8000-0000000000e1';
const _otherLoc = '0190a000-0000-7000-8000-0000000000e2';

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
  DateTime daysAgo(int n) {
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day - n, 12);
  }

  var seq = 0;

  /// A close as sync_pull_day_closes sends it (made on another device or earlier).
  Map<String, dynamic> serverClose(String id, DateTime day, int counted,
          {required DateTime closedAt, String? loc = _loc, int? opening}) =>
      {
        'id': id, 'location_id': loc, 'day': dayKey(day), 'currency': 'PHP ', 'opening_cash': ?opening,
        'expected_cash': counted, 'counted_cash': counted, 'difference': 0, 'server_expected_cash': counted,
        'note': null, 'closed_by': 'u1', 'approved_by': null, 'closed_at': pgTs(closedAt),
        'updated_at': '2026-11-08T00:00:${(seq++).toString().padLeft(2, '0')}+00:00',
      };
  Future<void> pull(List<Map<String, dynamic>> rows) => store.applyPullDayCloses({
        'rows': rows,
        'cursor': {'ts': '2026-11-08T00:00:59+00:00', 'k': 'z'},
        'has_more': false,
      });

  group('defaultOpeningCash', () {
    test('is 0 with no earlier close', () async {
      expect(await store.defaultOpeningCash(today()), 0);
      await pull([serverClose('t1', today(), 4000, closedAt: DateTime.now())]);
      expect(await store.defaultOpeningCash(today()), 0, reason: 'a close of the same day is not an opening');
    });

    test('is the counted cash of the newest earlier close; same-day, later-day and other-store closes are ignored', () async {
      final noon = daysAgo(0);
      await pull([
        serverClose('d3', daysAgo(3), 3000, closedAt: daysAgo(3).add(const Duration(hours: 8))),
        serverClose('d1a', daysAgo(1), 5000, closedAt: daysAgo(1).add(const Duration(hours: 8))),
        serverClose('d1b', daysAgo(1), 5100, closedAt: daysAgo(1).add(const Duration(hours: 9))), // re-count: newest
        serverClose('d0', daysAgo(0), 9999, closedAt: noon), // today itself
        serverClose('dx', daysAgo(1), 8888, closedAt: daysAgo(1).add(const Duration(hours: 10)), loc: _otherLoc),
      ]);
      expect(await store.defaultOpeningCash(today()), 5100);
      expect(await store.defaultOpeningCash(daysAgo(1)), 3000, reason: 'only days before the asked day');
      expect(await store.defaultOpeningCash(daysAgo(3)), 0);
      // a close of a later day (as seen from 2 days ago) does not count for that day
      expect(await store.defaultOpeningCash(daysAgo(2)), 3000);
    });

    test('follows the newest closed_at, a close without a store counts, and a local close is used the next day', () async {
      await pull([
        serverClose('d1', daysAgo(1), 5000, closedAt: daysAgo(1).add(const Duration(hours: 8))),
        // a late count of an older day, made after yesterday's close: the newest count of the drawer
        serverClose('d2late', daysAgo(2), 4200, closedAt: daysAgo(1).add(const Duration(hours: 9)), loc: null),
      ]);
      expect(await store.defaultOpeningCash(today()), 4200);
      await store.closeDay(id: 'c0', day: today(), countedCash: 6100, opId: 'o1');
      expect(await store.defaultOpeningCash(today()), 4200, reason: 'today\'s own close is not today\'s opening');
      expect(await store.defaultOpeningCash(today().add(const Duration(days: 1))), 6100, reason: 'it is tomorrow\'s');
    });
  });

  group('expectedCash', () {
    test('adds the default opening, or the one asked for; 0 gives the day\'s cash flow alone', () async {
      await store.commitSale(cashSale('s1', 1200), opId: 'o1');
      await store.recordExpense(id: 'e1', amount: 2000, category: 'other', opId: 'o2');
      expect(await store.expectedCash(today()), 1200 - 2000, reason: 'no earlier close: opening 0, as before P8-14');

      await pull([serverClose('d1', daysAgo(1), 50000, closedAt: daysAgo(1).add(const Duration(hours: 9)))]);
      expect(await store.expectedCash(today()), 50000 + 1200 - 2000);
      expect(await store.watchExpectedCash(today()).first, 49200);
      expect(await store.expectedCash(today(), openingCash: 30000), 30000 - 800);
      expect(await store.watchExpectedCash(today(), openingCash: 30000).first, 29200);
      expect(await store.expectedCash(today(), openingCash: 0), -800);
      await expectLater(store.expectedCash(today(), openingCash: -1), throwsArgumentError);
      expect(() => store.watchExpectedCash(today(), openingCash: -1), throwsArgumentError);
    });

    test('the watched figure moves when an earlier close arrives', () async {
      final seen = <int>[];
      final sub = store.watchExpectedCash(today()).listen(seen.add);
      await pumpEventQueue();
      await pull([serverClose('d1', daysAgo(1), 7000, closedAt: daysAgo(1).add(const Duration(hours: 9)))]);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.first, 0);
      expect(seen.last, 7000);
    });
  });

  group('closeDay', () {
    test('uses the default opening: row, view and payload agree (difference = counted - expected incl. opening)', () async {
      await pull([serverClose('d1', daysAgo(1), 50000, closedAt: daysAgo(1).add(const Duration(hours: 9)))]);
      await store.recordExpense(id: 'e1', amount: 300, category: 'other', opId: 'o1'); // a day with only an expense
      await store.closeDay(id: 'c1', day: today(), countedCash: 49600, opId: 'o2');
      final d = (await store.watchLatestDayClose(today()).first)!;
      expect((d.openingCash, d.expectedCash, d.countedCash, d.difference), (50000, 49700, 49600, -100));
      final op = (await store.nextOps()).last;
      expect(op.kind, 'close_day');
      expect(op.payload..remove('closed_at'), {
        'id': 'c1', 'day': dayKey(today()), 'opening_cash': 50000, 'expected_cash': 49700, 'counted_cash': 49600,
        'location_id': _loc,
      });
    });

    test('an opening typed by the owner replaces the default; a negative one is refused', () async {
      await pull([serverClose('d1', daysAgo(1), 50000, closedAt: daysAgo(1).add(const Duration(hours: 9)))]);
      await store.commitSale(cashSale('s1', 1000), opId: 'o1');
      await store.closeDay(id: 'c1', day: today(), countedCash: 21000, openingCash: 20000, opId: 'o2');
      final d = (await store.watchLatestDayClose(today()).first)!;
      expect((d.openingCash, d.expectedCash, d.difference), (20000, 21000, 0));
      expect((await store.nextOps()).last.payload['opening_cash'], 20000);
      expect(d.expectedCash, await store.expectedCash(today(), openingCash: 20000), reason: 'same figure as the screen shows');

      await store.closeDay(id: 'c2', day: today(), countedCash: 900, openingCash: 0, opId: 'o3');
      final p = (await store.nextOps()).last.payload;
      expect((p['opening_cash'], p['expected_cash']), (0, 1000));
      expect(() => store.closeDay(id: 'c3', day: today(), countedCash: 1, openingCash: -5, opId: 'o4'), throwsArgumentError);
      expect((await store.nextOps()).length, 3, reason: 'nothing queued for the refused close');
    });

    test('pulled closes carry opening_cash (missing = 0) and replace the local copy', () async {
      await store.closeDay(id: 'c1', day: today(), countedCash: 500, openingCash: 400, opId: 'o1');
      await pull([
        serverClose('c1', today(), 500, closedAt: DateTime.now(), opening: 400),
        serverClose('old', daysAgo(5), 100, closedAt: daysAgo(5)),
      ]);
      final rows = {for (final r in await store.db.select(store.db.dayCloses).get()) r.id: r};
      expect((rows['c1']!.openingCash, rows['c1']!.updatedAt != null), (400, true));
      expect(rows['old']!.openingCash, 0, reason: 'a server before P8-14 sends no opening_cash');
    });

    test('through a sync the server gets the opening cash and the pulled copy keeps it', () async {
      final server = ExpenseServer();
      final engine = SyncEngine(store, server);
      await pull([serverClose('d1', daysAgo(1), 50000, closedAt: daysAgo(1).add(const Duration(hours: 9)))]);
      await store.commitSale(cashSale('s1', 2500), opId: 'o1');
      await store.closeDay(id: 'c1', day: today(), countedCash: 52500, opId: 'o2');
      await engine.syncNow();
      expect((server.closes['c1']!['opening_cash'], server.closes['c1']!['expected_cash']), (50000, 52500));
      server.clock = server.clock.add(const Duration(seconds: 30));
      await engine.syncNow();
      final d = (await store.watchLatestDayClose(today()).first)!;
      expect((d.pending, d.openingCash, d.difference), (false, 50000, 0));
      engine.dispose();
    });
  });

  test('upgrading a v10 database keeps every close (opening 0) and adds the opening cash', () async {
    final dir = Directory.systemTemp.createTempSync('xzpos_v10_');
    final file = File('${dir.path}/app.sqlite');
    final v10 = DriftStore(AppDatabase(NativeDatabase(file)));
    await seed(v10);
    await v10.commitSale(cashSale('s1', 3000), opId: 'o1');
    await v10.closeDay(id: 'c1', day: daysAgo(1), countedCash: 2900, openingCash: 0, opId: 'o2');
    await v10.db.customStatement('alter table day_closes drop column opening_cash');
    await v10.db.customStatement('PRAGMA user_version = 10');
    await v10.close();

    final v11 = DriftStore(AppDatabase(NativeDatabase(file)));
    await v11.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc); // same tenant: nothing cleared
    final version = await v11.db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, v11.db.schemaVersion);
    final old = (await v11.db.select(v11.db.dayCloses).get()).single;
    expect((old.id, old.openingCash, old.countedCash, old.difference), ('c1', 0, 2900, 2900));
    expect((await v11.nextOps()).map((o) => o.opId), ['o1', 'o2'], reason: 'unsent ops survive');
    expect((await v11.getSale('s1'))!.summary.total, 3000);
    expect(await v11.defaultOpeningCash(today()), 2900, reason: 'yesterday\'s count is today\'s opening');
    await v11.closeDay(id: 'c2', day: today(), countedCash: 2900, opId: 'o3');
    expect((await v11.watchLatestDayClose(today()).first)!.openingCash, 2900);
    await v11.close();
    dir.deleteSync(recursive: true);
  });
}
