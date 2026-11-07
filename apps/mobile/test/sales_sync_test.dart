import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _cus = '0190a000-0000-7000-8000-0000000000c1';
const _loc = '0190a000-0000-7000-8000-0000000000e1';

/// A tiny server that behaves like sync_push / sync_pull_pos: ops are applied once per op id (a replay returns the
/// stored result), stock and utang are derived from what was applied.
class PosServer implements SyncApi {
  final applied = <String, Map<String, dynamic>>{}; // op id -> result
  final sales = <String, Map<String, dynamic>>{}; // sale id -> payload
  final customers = <String>{};
  double stock = 0;
  DateTime? stockAt; // when stock last changed
  int ledger = 0; // utang owed in total
  final batches = <int>[];
  var clock = DateTime.utc(2026, 11, 8, 1);

  /// When set, the next push applies everything but "loses" the response (the phone sees a network error).
  bool loseNextResponse = false;
  String? rejectKind;
  bool transientOnSale = false;

  DateTime tick() => clock = clock.add(const Duration(seconds: 1));

  Map<String, dynamic> _apply(Map<String, dynamic> op) {
    final id = op['op_id'] as String;
    if (applied.containsKey(id)) return {...applied[id]!, 'replay': true};
    final p = op['payload'] as Map<String, dynamic>;
    final now = tick();
    final at = now.toIso8601String();
    switch (op['kind']) {
      case 'record_sale':
        stockAt = now;
        sales[p['id'] as String] = p;
        for (final i in p['items'] as List) {
          stock -= (i['qty'] as num).toDouble();
        }
        for (final pay in p['payments'] as List) {
          if (pay['method'] == 'utang') ledger += pay['amount'] as int;
        }
      case 'void_sale':
        stockAt = now;
        final s = sales[p['sale_id']]!;
        for (final i in s['items'] as List) {
          stock += (i['qty'] as num).toDouble();
        }
        for (final pay in s['payments'] as List) {
          if (pay['method'] == 'utang') ledger -= pay['amount'] as int;
        }
        s['voided'] = true;
      case 'upsert_customer':
        customers.add(p['id'] as String);
      case 'record_utang_payment':
        ledger -= p['amount'] as int;
      case 'post_opening_stock':
        stockAt = now;
        stock += (p['qty'] as num).toDouble();
    }
    return applied[id] = {'applied_at': at};
  }

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    batches.add(ops.length);
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      if (op['kind'] == rejectKind) {
        out.add({'op_id': op['op_id'], 'status': 'rejected', 'hint': 'customer_required'});
        continue;
      }
      if (transientOnSale && op['kind'] == 'record_sale') {
        out.add({'op_id': op['op_id'], 'status': 'error', 'code': '40001'});
        return out; // a batch stops at the first transient error
      }
      out.add({'op_id': op['op_id'], 'status': 'ok', 'result': _apply(op)});
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
    return {
      'server_time': now.toIso8601String(),
      'stock_levels': {
        // like the real pull: a row changed in the last 5 seconds is held back
        'rows': [
          if (stockAt != null && !stockAt!.isAfter(now.subtract(const Duration(seconds: 5))))
            {'location_id': _loc, 'variant_id': _v1, 'qty_on_hand': stock, 'updated_at': stockAt!.toIso8601String()}
        ],
        'cursor': {'ts': now.toIso8601String(), 'k': 'l'},
        'has_more': false,
      },
      'customers': {'rows': [], 'cursor': null, 'has_more': false},
      'customer_ledger': {'rows': [], 'cursor': null, 'has_more': false},
    };
  }

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

SaleDraft sale(String id, int qty, List<PaymentDraft> pays, {String? customer}) => SaleDraft(
      id: id,
      soldAt: DateTime.now(),
      lines: [SaleLine(variantId: _v1, name: 'Kape', qty: qty.toDouble(), unitPrice: 1000, unitCost: 500)],
      payments: pays,
      customerId: customer,
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;
  late PosServer server;
  late SyncEngine engine;

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    server = PosServer();
    engine = SyncEngine(store, server);
    await store.ensureTenant('tenant-a', baseCurrency: 'PHP', locationId: _loc);
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 1000)],
    ));
  });
  tearDown(() async {
    engine.dispose();
    await store.close();
  });

  test('20 offline sales reach the server exactly once, even when a response is lost halfway', () async {
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'Kape', price: 1000, openingQty: 100), opId: 'op-open-product');
    for (var i = 1; i <= 20; i++) {
      await store.commitSale(sale('sale-$i', 1, [const PaymentDraft('cash', 1000)]), opId: 'op-sale-$i');
    }
    expect(await store.stockLeft(_v1), 80);

    server.loseNextResponse = true; // the server applies the batch, the phone never hears back
    await engine.syncNow();
    expect(server.sales, hasLength(20), reason: 'applied once even though the response was lost');
    expect((await store.watchOutboxCounts().first).pending, greaterThan(0), reason: 'phone still thinks they are unsent');

    await engine.syncNow(); // retry with the same op ids
    expect(server.sales, hasLength(20), reason: 'the retry created no duplicates');
    expect(server.stock, 80, reason: '100 opening - 20 sold, taken once');
    expect((await store.watchOutboxCounts().first).pending, 0);
    expect(await store.stockLeft(_v1), 80, reason: 'the server level is still held back: the screen keeps counting local effects');

    server.clock = server.clock.add(const Duration(seconds: 30));
    await engine.syncNow();
    expect(await store.stockLeft(_v1), 80, reason: 'same number once the server level has arrived');
    expect(await store.db.select(store.db.localMovements).get(), isEmpty, reason: 'and nothing is counted twice');
  });

  test('ops go in batches of at most 50, in order', () async {
    for (var i = 1; i <= 120; i++) {
      await store.commitSale(sale('s$i', 1, [const PaymentDraft('cash', 1000)]), opId: 'o$i');
    }
    await engine.syncNow();
    expect(server.batches, [50, 50, 20]);
    expect(server.sales, hasLength(120));
  });

  test('a refused op is parked for attention and does not block the ones after it', () async {
    await store.saveCustomer(id: _cus, name: 'Rosa', opId: 'oc');
    await store.commitSale(sale('s1', 1, [const PaymentDraft('cash', 1000)]), opId: 'o1');
    server.rejectKind = 'upsert_customer';
    await engine.syncNow();
    expect(server.sales, hasLength(1));
    final failed = await store.failedOps();
    expect(failed.single.kind, 'upsert_customer');
    expect(failed.single.lastError, 'customer_required');
    expect((await store.watchOutboxCounts().first).pending, 0);
  });

  test('a temporary server error stops the batch so later ops are not applied out of order', () async {
    await store.saveCustomer(id: _cus, name: 'Rosa', opId: 'oc');
    await store.commitSale(sale('s1', 1, [const PaymentDraft('cash', 1000)]), opId: 'o1');
    await store.recordUtangPayment(customerId: _cus, amount: 50, opId: 'o2');
    server.transientOnSale = true;
    await engine.syncNow();
    expect(server.customers, {_cus}, reason: 'the customer before the sale was applied');
    expect(server.sales, isEmpty);
    expect(server.ledger, 0, reason: 'the payment after the sale was not applied early');
    expect((await store.watchOutboxCounts().first).pending, 2);

    server.transientOnSale = false;
    await engine.syncNow();
    expect(server.sales, hasLength(1));
    expect((await store.watchOutboxCounts().first).pending, 0);
  });

  test('cancel + utang payment arrive in order and net out', () async {
    await store.saveCustomer(id: _cus, name: 'Rosa', opId: 'oc');
    await store.commitSale(sale('s1', 2, [const PaymentDraft('utang', 2000)], customer: _cus), opId: 'o1');
    await store.commitSale(sale('s2', 1, [const PaymentDraft('utang', 1000)], customer: _cus), opId: 'o2');
    await store.recordUtangPayment(customerId: _cus, amount: 500, opId: 'o3');
    await store.voidSale('s1', opId: 'o4');
    await engine.syncNow();
    expect(server.ledger, 500, reason: '1000 owed from s2 minus the 500 paid');
    expect(server.stock, -1);
    expect((await store.watchCustomers().first).single.balance, 500);
  });

  test('rejected sale that is discarded disappears from the device', () async {
    await store.commitSale(sale('s1', 1, [const PaymentDraft('cash', 1000)]), opId: 'o1');
    server.rejectKind = 'record_sale';
    await engine.syncNow();
    expect((await store.failedOps()).single.opId, 'o1');
    await store.discardFailed('o1');
    expect(await store.getSale('s1'), isNull);
    expect(await store.stockLeft(_v1), 0);
  });
}
