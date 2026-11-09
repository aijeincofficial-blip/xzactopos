import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;

// F-02: device identity, the server's sale number on the phone (op result and pull), provisional -> confirmed.

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _a = '0190a000-0000-7000-8000-0000000000e1';
const _b = '0190a000-0000-7000-8000-0000000000e2';
const _storeA = StoreRef(id: _a, name: 'Tindahan A');
const _storeB = StoreRef(id: _b, name: 'Tindahan B');
final _uuidV7 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

/// A small server like op_record_sale + register_device + sync_pull_sales: one number per (store, UTC day), taken in the
/// same step as the sale (a replay returns the stored result), local numbers unique per device (rows without a device:
/// per tenant), device ids registered per tenant.
class NumberServer implements SyncApi, DeviceApi {
  NumberServer({this.tenant = 't1'});
  final String tenant;
  static final devicesById = <String, String>{}; // device id -> tenant (shared, like the real primary key)

  final registrations = <Map<String, Object?>>[];
  final applied = <String, Map<String, dynamic>>{}; // op id -> result
  final sales = <String, Map<String, dynamic>>{}; // sale id -> server row
  final counters = <String, int>{}; // 'store|YYMMDD' -> last number
  static const codes = {_a: 'S01', _b: 'S02'};

  bool offline = false;
  bool registerOffline = false;
  String? refuseRegistration;
  bool omitSaleNoInResult = false;
  bool holdPull = false;

  @override
  Future<Map<String, dynamic>> registerDevice(String id, {String? name, String? platform}) async {
    if (offline || registerOffline) throw Exception('no signal');
    if (refuseRegistration != null) throw OpRejected(refuseRegistration!);
    final owner = devicesById.putIfAbsent(id, () => tenant);
    if (owner != tenant) throw const OpRejected('id_conflict');
    registrations.add({'id': id, 'name': name, 'platform': platform});
    return {'id': id, 'name': name, 'platform': platform};
  }

  Map<String, dynamic> _recordSale(Map<String, dynamic> p) {
    final dev = p['device_id'] as String?;
    final device = dev != null && devicesById[dev] == tenant ? dev : null;
    final localNo = p['local_no'] as String;
    if (sales.values.any((s) => s['device_id'] == device && s['local_no'] == localNo)) {
      throw const OpRejected('duplicate_local_no');
    }
    final loc = p['location_id'] as String;
    final sold = DateTime.parse(p['sold_at'] as String).toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    final day = '${two(sold.year % 100)}${two(sold.month)}${two(sold.day)}';
    final n = counters['$loc|$day'] = (counters['$loc|$day'] ?? 0) + 1;
    final saleNo = '${codes[loc]}-$day-${n.toString().padLeft(4, '0')}';
    sales[p['id'] as String] = {
      'id': p['id'], 'location_id': loc, 'local_no': localNo, 'sale_no': saleNo, 'device_id': device,
      'status': 'completed', 'subtotal': p['subtotal'], 'discount': p['discount'], 'tax': 0, 'total': p['total'],
      'customer_id': null, 'sold_at': p['sold_at'], 'voided_at': null, 'void_reason': null,
      'updated_at': '2026-11-08T05:00:00+00:00',
      'items': [
        for (final i in p['items'] as List)
          {...(i as Map).cast<String, dynamic>(), 'discount': 0, 'tracked': true},
      ],
      'payments': [for (final x in p['payments'] as List) (x as Map).cast<String, dynamic>()],
    };
    return {'sale_id': p['id'], 'local_no': localNo, 'sale_no': saleNo, 'device_id': device,
            'applied_at': '2026-11-08T05:00:00+00:00'};
  }

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    if (offline) throw Exception('no signal');
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      final id = op['op_id'] as String;
      if (applied.containsKey(id)) {
        out.add({'op_id': id, 'status': 'ok', 'result': {...applied[id]!, 'replay': true}});
        continue;
      }
      try {
        final p = (op['payload'] as Map).cast<String, dynamic>();
        final res = switch (op['kind']) {
          'record_sale' => _recordSale(p),
          'void_sale' => () {
              sales[p['sale_id']]!['status'] = 'voided';
              sales[p['sale_id']]!['voided_at'] = '2026-11-08T06:00:00+00:00';
              return {'sale_id': p['sale_id'], 'applied_at': '2026-11-08T06:00:00+00:00'};
            }(),
          _ => {'applied_at': '2026-11-08T05:00:00+00:00'},
        };
        applied[id] = res;
        final shown = omitSaleNoInResult ? (Map.of(res)..remove('sale_no')) : res;
        out.add({'op_id': id, 'status': 'ok', 'result': shown});
      } on OpRejected catch (e) {
        out.add({'op_id': id, 'status': 'rejected', 'hint': e.hint});
      }
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100}) async {
    if (offline) throw Exception('no signal');
    return {'rows': holdPull ? <dynamic>[] : sales.values.toList(), 'has_more': false, 'cursor': {'ts': 'x', 'k': 'y'}};
  }

  static Map<String, dynamic> _empty() => {'rows': <dynamic>[], 'has_more': false};
  @override
  Future<Map<String, dynamic>> pullExpenses(Map<String, dynamic>? cursor, {int limit = 100}) async => _empty();
  @override
  Future<Map<String, dynamic>> pullDayCloses(Map<String, dynamic>? cursor, {int limit = 100}) async => _empty();
  @override
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100}) async => _empty();
  @override
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100}) async => _empty();
  @override
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async =>
      {'server_time': '2026-11-08T05:00:00+00:00'};
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

SaleDraft _sale(String id) => SaleDraft(
      id: id,
      soldAt: DateTime.utc(2026, 11, 8, 2),
      lines: [const SaleLine(variantId: _v1, name: 'Kape', qty: 1, unitPrice: 1000, unitCost: 500)],
      payments: [const PaymentDraft('cash', 1000)],
    );

Future<DriftStore> _open({List<StoreRef> stores = const [_storeA], String tenant = 't1', File? file}) async {
  final store = DriftStore(AppDatabase(file == null ? NativeDatabase.memory() : NativeDatabase(file)));
  await store.ensureTenant(tenant, baseCurrency: 'PHP', stores: stores, discardUnsent: true);
  await store.applyPull(pullPage(
    products: [serverProduct(_p1, 'Kape')],
    variants: [serverVariant(_v1, _p1)],
    prices: [serverPrice(_v1, 1000)],
  ));
  return store;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;

  setUp(() {
    NumberServer.devicesById.clear();
    dir = Directory.systemTemp.createTempSync('xzpos_f02_');
  });
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // a failed test may leave its database open; the temp folder is cleaned up by the OS
    }
  });

  test('the device id is made once, kept across restarts, and starts over only for another business', () async {
    final file = File('${dir.path}/app.sqlite');
    var store = await _open(file: file);
    final id = await store.deviceId();
    expect(id, matches(_uuidV7), reason: 'a UUIDv7 made on the device');
    expect(await store.deviceId(), id, reason: 'the same on every call');
    expect(await store.meta('device_id'), id, reason: 'kept in meta');
    await store.close();

    store = DriftStore(AppDatabase(NativeDatabase(file)));
    await store.ensureTenant('t1', baseCurrency: 'PHP', stores: const [_storeA]);
    expect(await store.deviceId(), id, reason: 'same id after a restart (same business: nothing cleared)');
    await store.ensureTenant('t2', baseCurrency: 'PHP', stores: const [_storeA], discardUnsent: true);
    final other = await store.deviceId();
    expect(other, isNot(id), reason: 'cleared for another business: a new device for that business');
    expect(other, matches(_uuidV7));
    await store.close();
  });

  test('the engine registers the device once per session, with its name and platform; best effort', () async {
    final store = await _open();
    final server = NumberServer();
    await store.setMeta(SyncEngine.deviceNameKey, 'Cashier phone');

    server.registerOffline = true;
    await store.commitSale(_sale('s1'), opId: 'o1');
    var engine = SyncEngine(store, server);
    await engine.syncNow();
    expect(server.registrations, isEmpty, reason: 'no signal for the registration...');
    expect(server.sales.keys, ['s1'], reason: '...never blocks selling and syncing');
    expect(engine.device, isNull);

    server.registerOffline = false;
    await engine.syncNow();
    await engine.syncNow();
    await engine.syncNow();
    expect(server.registrations, [
      {'id': await store.deviceId(), 'name': 'Cashier phone', 'platform': SyncEngine.devicePlatform},
    ], reason: 'registered on the next run, then not again in this session');
    expect(engine.device?['id'], await store.deviceId());
    engine.dispose();

    engine = SyncEngine(store, server); // the next sign-in
    await engine.syncNow();
    expect(server.registrations, hasLength(2), reason: 'once per session');
    expect(await engine.registerDevice(), isTrue);
    expect(server.registrations, hasLength(2), reason: 'a second call in the session does nothing');
    expect(await engine.registerDevice(force: true), isTrue);
    expect(server.registrations, hasLength(3), reason: 'unless forced (a renamed device)');
    engine.dispose();
    await store.close();
  });

  test('a refused registration is not retried in the session and sales still sync', () async {
    final store = await _open();
    final server = NumberServer()..refuseRegistration = 'device_limit';
    final engine = SyncEngine(store, server);
    await store.commitSale(_sale('s1'), opId: 'o1');
    await engine.syncNow();
    expect(await engine.registerDevice(), isFalse);
    expect(server.sales.keys, ['s1']);
    expect((await store.getSale('s1'))!.saleNo, 'S01-261108-0001', reason: 'numbered without a registered device');
    server.refuseRegistration = null;
    await engine.syncNow();
    expect(server.registrations, isEmpty, reason: 'settled for this session');
    engine.dispose();
    await store.close();
  });

  test('a sale carries the device id in its op and row; offline it keeps its local number until confirmed', () async {
    final store = await _open();
    final server = NumberServer()..offline = true;
    final engine = SyncEngine(store, server);
    final dev = await store.deviceId();
    final r = await store.commitSale(_sale('s1'), opId: 'o1');

    final op = (await store.nextOps()).single;
    expect(op.payload['device_id'], dev, reason: 'record_sale carries device_id');
    expect(op.payload['local_no'], r.localNo);
    expect((await store.db.select(store.db.sales).getSingle()).deviceId, dev);

    await engine.syncNow(); // no signal
    var d = (await store.getSale('s1'))!;
    expect((d.provisional, d.saleNo, d.displayNo, d.summary.pending), (true, null, r.localNo, true),
        reason: 'offline: the provisional local number is shown');

    server.offline = false;
    server.holdPull = true; // only the op result can tell the number this time
    await engine.syncNow();
    d = (await store.getSale('s1'))!;
    expect((d.provisional, d.saleNo, d.displayNo, d.summary.localNo, d.summary.pending),
        (false, 'S01-261108-0001', 'S01-261108-0001', r.localNo, false),
        reason: 'confirmed from the op result: the server number is shown, the local one is kept');
    expect((await store.watchSales().first).single.displayNo, 'S01-261108-0001', reason: 'lists show it too');
    engine.dispose();
    await store.close();
  });

  test('the number also arrives with the sales pull, and a pull without one never erases it', () async {
    final store = await _open();
    final server = NumberServer()..omitSaleNoInResult = true;
    final engine = SyncEngine(store, server);
    await store.commitSale(_sale('s1'), opId: 'o1');
    final seen = <String?>[];
    final sub = store.watchSale('s1').listen((d) => seen.add(d?.displayNo));

    await engine.syncNow();
    expect((await store.getSale('s1'))!.saleNo, 'S01-261108-0001', reason: 'from the pull (the result had none)');
    expect((await store.getSale('s1'))!.summary.localNo, isNot('S01-261108-0001'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.last, 'S01-261108-0001', reason: 'an open receipt follows (watchSale re-emits)');

    final row = Map<String, dynamic>.of(server.sales['s1']!)
      ..remove('sale_no')
      ..remove('device_id');
    await store.applyPullSales({'rows': [row], 'has_more': false});
    expect((await store.getSale('s1'))!.saleNo, 'S01-261108-0001', reason: 'an older server''s row does not erase it');
    await sub.cancel();
    engine.dispose();
    await store.close();
  });

  test('a sale with an unsent cancel still takes the server number from the pull', () async {
    final store = await _open();
    final server = NumberServer()
      ..omitSaleNoInResult = true
      ..holdPull = true;
    final engine = SyncEngine(store, server);
    await store.commitSale(_sale('s1'), opId: 'o1');
    await engine.syncNow();
    expect((await store.getSale('s1'))!.provisional, isTrue);
    await store.voidSale('s1', opId: 'o2'); // not sent yet
    await store.applyPullSales({'rows': [server.sales['s1']], 'has_more': false});
    final d = (await store.getSale('s1'))!;
    expect((d.summary.voided, d.saleNo), (true, 'S01-261108-0001'), reason: 'our cancel is kept, the number is taken');
    engine.dispose();
    await store.close();
  });

  test('two stores number on their own; the op names the store and the device', () async {
    final store = await _open(stores: const [_storeA, _storeB]);
    final server = NumberServer();
    final engine = SyncEngine(store, server);
    await store.commitSale(_sale('a1'), opId: 'oa1');
    await store.setActiveStore(_b);
    await store.commitSale(_sale('b1'), opId: 'ob1');
    await store.setActiveStore(_a);
    await store.commitSale(_sale('a2'), opId: 'oa2');
    final dev = await store.deviceId();
    expect([for (final o in await store.nextOps()) (o.payload['location_id'], o.payload['device_id'])],
        [(_a, dev), (_b, dev), (_a, dev)]);
    await engine.syncNow();
    expect({for (final s in await store.db.select(store.db.sales).get()) s.id: s.saleNo},
        {'a1': 'S01-261108-0001', 'b1': 'S02-261108-0001', 'a2': 'S01-261108-0002'});
    engine.dispose();
    await store.close();
  });

  test('two phones that drew the same device code both sync and get different server numbers (B1)', () async {
    final one = await _open();
    final two = await _open();
    await one.setMeta('device_code', 'NZD');
    await two.setMeta('device_code', 'NZD');
    final server = NumberServer();
    final r1 = await one.commitSale(_sale('s1'), opId: 'o1');
    final r2 = await two.commitSale(_sale('s2'), opId: 'o2');
    expect(r1.localNo, r2.localNo, reason: 'the same provisional number on both phones');
    expect(await one.deviceId(), isNot(await two.deviceId()));

    final e1 = SyncEngine(one, server);
    final e2 = SyncEngine(two, server);
    await e1.syncNow();
    await e2.syncNow();
    expect(await one.failedOps(), isEmpty);
    expect(await two.failedOps(), isEmpty, reason: 'not refused as a duplicate any more');
    expect((await one.getSale('s1'))!.displayNo, 'S01-261108-0001');
    expect((await two.getSale('s2'))!.displayNo, 'S01-261108-0002');
    await e1.syncNow(); // the first phone pulls the second one's sale
    expect({for (final s in await one.db.select(one.db.sales).get()) s.id: s.saleNo},
        {'s1': 'S01-261108-0001', 's2': 'S01-261108-0002'}, reason: 'each phone sees the other''s sale with its number');
    e1.dispose();
    e2.dispose();
    await one.close();
    await two.close();
  });

  test('upgrading a v13 database keeps every row and op, gives unsent sales the device id, re-pulls sales', () async {
    final file = File('${dir.path}/app.sqlite');
    final v13 = await _open(file: file);
    final r1 = await v13.commitSale(_sale('s1'), opId: 'o1');
    await v13.opDone('o1'); // sent before the upgrade
    final r2 = await v13.commitSale(_sale('s2'), opId: 'o2');
    await v13.db.customStatement("insert or replace into sync_cursors values ('sales', '{}'), ('stock_levels', '{}')");
    // back to the v13 layout: no sale number / device columns, no device id, ops without one
    final db = v13.db;
    await db.customStatement('alter table sales drop column sale_no');
    await db.customStatement('alter table sales drop column device_id');
    await db.customStatement("delete from meta where key = 'device_id'");
    await db.customStatement("update outbox set payload = json_remove(payload, '\$.device_id')");
    final before = [for (final o in await v13.nextOps()) (o.opId, o.kind, jsonEncode(o.payload))];
    await db.customStatement('PRAGMA user_version = 13');
    await v13.close();

    final v14 = DriftStore(AppDatabase(NativeDatabase(file)));
    await v14.ensureTenant('t1', baseCurrency: 'PHP', stores: const [_storeA]);
    expect((await v14.db.customSelect('PRAGMA user_version').getSingle()).data.values.single, 14);
    final dev = await v14.deviceId();
    expect(dev, matches(_uuidV7), reason: 'made by the upgrade');
    final after = await v14.nextOps();
    expect([for (final o in after) (o.opId, o.kind, jsonEncode(Map.of(o.payload)..remove('device_id')))], before,
        reason: 'the unsent op is kept, unchanged otherwise');
    expect(after.single.payload['device_id'], dev, reason: 'and now carries the device id');
    expect({for (final s in await v14.db.select(v14.db.sales).get()) s.id: (s.localNo, s.saleNo, s.deviceId)},
        {'s1': (r1.localNo, null, null), 's2': (r2.localNo, null, dev)},
        reason: 'every sale kept with its local number; only the unsent one is known to be this device''s');
    final cursors = (await v14.cursors()).keys.toSet();
    expect(cursors.contains('sales'), isFalse, reason: 'sales come again with their server numbers');
    expect(cursors, contains('stock_levels'));

    final server = NumberServer();
    final engine = SyncEngine(v14, server);
    await engine.syncNow();
    expect((await v14.getSale('s2'))!.displayNo, 'S01-261108-0001', reason: 'the upgraded unsent sale is numbered');
    expect(server.sales['s2']!['device_id'], dev);
    engine.dispose();
    await v14.close();
  });

  test('payload and schema stay JSON-friendly', () async {
    final store = await _open();
    await store.commitSale(_sale('s1'), opId: 'o1');
    final op = (await store.nextOps()).single;
    expect(jsonDecode(jsonEncode(op.payload))['device_id'], await store.deviceId());
    await store.close();
  });
}
