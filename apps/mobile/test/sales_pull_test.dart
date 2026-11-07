import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'products_test.dart' show leave, openHome;
import 'sales_sync_test.dart' show PosServer;

const _v1 = '0190a000-0000-7000-8000-0000000000a1';

Map<String, dynamic> pulled(String id, String no, {String status = 'completed', int total = 2000, String sold = '2026-11-08T02:00:00+00:00', bool tracked = true}) => {
      'id': id,
      'local_no': no,
      'status': status,
      'subtotal': total,
      'discount': 0,
      'tax': 0,
      'total': total,
      'customer_id': null,
      'sold_at': sold,
      'voided_at': status == 'voided' ? '2026-11-08T05:00:00+00:00' : null,
      'void_reason': null,
      'updated_at': '2026-11-08T02:00:01+00:00',
      'items': [
        {'variant_id': _v1, 'name': 'Kape', 'qty': 2, 'unit_price': total ~/ 2, 'unit_cost': 400, 'discount': 0, 'tax': 0, 'line_total': total, 'tracked': tracked}
      ],
      'payments': [
        {'method': 'cash', 'amount': total, 'tendered': total + 500, 'reference': null}
      ],
    };

Map<String, dynamic> page(List<Map<String, dynamic>> rows, {bool more = false}) => {
      'rows': rows,
      'cursor': rows.isEmpty ? null : {'ts': '2026-11-08T02:00:01+00:00', 'k': rows.last['id']},
      'has_more': more,
      'server_time': '2026-11-08T03:00:00+00:00',
    };

class SalesPullServer extends PosServer {
  final pages = <Map<String, dynamic>>[];
  final cursorsSeen = <Map<String, dynamic>?>[];
  @override
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100}) async {
    cursorsSeen.add(cursor);
    return pages.isEmpty ? {'rows': <dynamic>[], 'has_more': false} : pages.removeAt(0);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('t', baseCurrency: 'PHP');
  });
  tearDown(() => store.close());

  test('pulled sales show as receipts with lines, payments and the cash handed over', () async {
    await store.applyPullSales(page([pulled('s1', 'AAA-261108-0001')]));
    final d = (await store.getSale('s1'))!;
    expect(d.summary.localNo, 'AAA-261108-0001');
    expect(d.items.single.name, 'Kape');
    expect(d.payments.single.tendered, 2500);
    expect(d.change, 500);
    expect(d.summary.pending, isFalse, reason: 'it came from the server');
    expect((await store.cursors())['sales'], {'ts': '2026-11-08T02:00:01+00:00', 'k': 's1'});
  });

  test('server timestamps are normalised, so "today" works for sales from other devices', () async {
    final now = DateTime.now().toUtc();
    await store.applyPullSales(page([pulled('s1', 'X-1', sold: '${now.toIso8601String().split('.').first}+00:00')]));
    final t = await store.watchToday().first;
    expect(t.count, 1);
    expect(t.total, 2000);
    expect(t.cash, 2000);
  });

  test('a cancel from another device arrives and leaves today\'s totals', () async {
    final now = DateTime.now().toUtc().toIso8601String().split('.').first;
    await store.applyPullSales(page([pulled('s1', 'X-1', sold: '$now+00:00')]));
    await store.applyPullSales(page([pulled('s1', 'X-1', status: 'voided', sold: '$now+00:00')]));
    expect((await store.getSale('s1'))!.summary.voided, isTrue);
    expect((await store.watchToday().first).count, 0);
    expect(await store.db.select(store.db.saleItems).get(), hasLength(1), reason: 'lines are replaced, not doubled');
  });

  test('a sale with an unsent change here is not overwritten', () async {
    await store.commitSale(
      SaleDraft(
          id: 's1',
          soldAt: DateTime.now(),
          lines: const [SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: 1000)],
          payments: const [PaymentDraft('cash', 1000)]),
      opId: 'op1',
    );
    final localNo = (await store.getSale('s1'))!.summary.localNo;
    await store.applyPullSales(page([pulled('s1', 'SERVER-1', total: 9999)]));
    expect((await store.getSale('s1'))!.summary.localNo, localNo);
    expect((await store.getSale('s1'))!.summary.total, 1000);
  });

  test('a cancelled pulled sale puts back only the products that track stock', () async {
    await store.applyPullSales(page([pulled('s1', 'X-1', tracked: false)]));
    await store.voidSale('s1', opId: 'v1');
    expect(await store.stockLeft(_v1), 0, reason: 'an untracked product has no stock to give back');
  });

  test('the engine pulls sales after the rest, page by page, resuming from the saved cursor', () async {
    final server = SalesPullServer()
      ..pages.addAll([
        page([pulled('s1', 'X-1')], more: true),
        page([pulled('s2', 'X-2')]),
      ]);
    final engine = SyncEngine(store, server);
    await engine.syncNow();
    expect((await store.getSale('s1')), isNotNull);
    expect((await store.getSale('s2')), isNotNull);
    expect(server.cursorsSeen.first, isNull, reason: 'first pull: server applies its 30-day window');
    expect(server.cursorsSeen.last, {'ts': '2026-11-08T02:00:01+00:00', 'k': 's1'});

    await engine.syncNow(); // a later run starts from where the last one ended
    expect(server.cursorsSeen.last, isNotNull);
    engine.dispose();
  });

  testWidgets('Today lists a sale made on another device and its receipt opens', (tester) async {
    final s = await openHome(tester);
    final now = DateTime.now().toUtc().toIso8601String().split('.').first;
    await s.applyPullSales(page([pulled('s1', 'OTHER-261108-0007', sold: '$now+00:00')]));
    await tester.tap(find.byKey(const Key('tile-today')));
    await tester.pumpAndSettle();
    expect(find.textContaining('OTHER-261108-0007'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sale-s1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receipt-no')), findsOneWidget);
    await leave(tester);
  });
}
