import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/backend.dart' show isPermanent;
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;

class FakeApi implements SyncApi {
  final calls = <String>[];
  final pages = <Map<String, dynamic>>[];
  final pulledWith = <Map<String, dynamic>>[];
  Object? failNextPush;
  final rejectOps = <String, String>{};

  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async {
    pulledWith.add(cursors);
    return pages.isEmpty ? pullPage() : pages.removeAt(0);
  }

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
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async => {};
  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async =>
      [for (final o in ops) {'op_id': o['op_id'], 'status': 'ok', 'result': <String, dynamic>{}}];

  Future<void> _push(String what, String opId) async {
    calls.add('$what:$opId');
    if (failNextPush != null) {
      final e = failNextPush!;
      failNextPush = null;
      throw e;
    }
    if (rejectOps.containsKey(opId)) throw OpRejected(rejectOps[opId]!);
  }

  @override
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload) {
    upserts[opId] = payload;
    return _push('upsert', opId);
  }

  @override
  Future<void> archiveProduct(String opId, String productId) => _push('archive', opId);

  final uploads = <String, Uint8List>{};
  final upserts = <String, Map<String, dynamic>>{};
  Object? failNextUpload;
  final photos = <String, Uint8List>{};
  final downloads = <String>[];
  int downloading = 0;
  int maxDownloading = 0;
  bool offline = false;

  @override
  Future<void> uploadPhoto(String path, Uint8List jpeg) async {
    calls.add('upload:$path');
    if (failNextUpload != null) {
      final e = failNextUpload!;
      failNextUpload = null;
      throw e;
    }
    uploads[path] = jpeg;
  }

  @override
  Future<Uint8List> downloadPhoto(String path) async {
    downloads.add(path);
    downloading++;
    if (downloading > maxDownloading) maxDownloading = downloading;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    downloading--;
    if (offline || !photos.containsKey(path)) throw Exception('offline');
    return photos[path]!;
  }
}

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;
  late FakeApi api;
  late SyncEngine engine;

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('t', baseCurrency: 'PHP');
    api = FakeApi();
    engine = SyncEngine(store, api);
  });
  tearDown(() async {
    engine.dispose();
    await store.close();
  });

  test('pushes in order, then pulls', () async {
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'Kape', price: 1), opId: 'o1');
    await store.archiveProduct(_p1, opId: 'o2');
    await engine.syncNow();
    expect(api.calls, ['upsert:o1', 'archive:o2']);
    expect(await store.nextOps(), isEmpty);
    expect(api.pulledWith, hasLength(1));
    expect(engine.status.value.phase, SyncPhase.idle);
    expect(engine.status.value.lastSyncedAt, isNotNull);
  });

  test('a network error keeps the op and retries it later with the same op id', () async {
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'Kape', price: 1), opId: 'o1');
    await store.saveProduct(const ProductDraft(id: _p2, variantId: _v2, name: 'Asukal', price: 1), opId: 'o2');
    api.failNextPush = Exception('SocketException: no route to host');

    await engine.syncNow();
    expect(engine.status.value.phase, SyncPhase.offline);
    expect(api.calls, ['upsert:o1'], reason: 'stops at the first transient failure to keep order');
    expect(api.pulledWith, isEmpty);
    final ops = await store.nextOps();
    expect(ops.map((o) => o.opId), ['o1', 'o2']);
    expect(ops.first.attempts, 1);

    await engine.syncNow();
    expect(api.calls, ['upsert:o1', 'upsert:o1', 'upsert:o2']);
    expect(await store.nextOps(), isEmpty);
    expect(engine.status.value.phase, SyncPhase.idle);
  });

  test('a rejected op is parked as failed and the rest still go', () async {
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'Dup', price: 1), opId: 'o1');
    await store.saveProduct(const ProductDraft(id: _p2, variantId: _v2, name: 'Ok', price: 1), opId: 'o2');
    api.rejectOps['o1'] = 'duplicate_barcode';

    await engine.syncNow();
    expect(api.calls, ['upsert:o1', 'upsert:o2']);
    expect((await store.failedOps()).single.lastError, 'duplicate_barcode');
    expect(engine.status.value.phase, SyncPhase.idle);
  });

  test('pull follows has_more and sends the stored cursors', () async {
    api.pages
      ..add(pullPage(
          products: [serverProduct(_p1, 'Kape')], variants: [serverVariant(_v1, _p1)], prices: [serverPrice(_v1, 1)],
          more: true))
      ..add(pullPage(products: [serverProduct(_p2, 'Asukal')], variants: [serverVariant(_v2, _p2)]));
    await engine.syncNow();
    expect(api.pulledWith, hasLength(2));
    expect(api.pulledWith.first, isEmpty);
    expect(api.pulledWith.last['products'], isNotNull);
    expect(await store.productCount(), 2);
  });

  test('a sync requested while one runs is not lost', () async {
    await Future.wait([engine.syncNow(), engine.syncNow()]);
    await Future<void>.delayed(Duration.zero);
    await engine.syncNow();
    expect(api.pulledWith.length, greaterThanOrEqualTo(2));
  });

  test('a change saved while a sync is pulling is sent right after it, not at the next idle poll', () async {
    // the push loop re-reads the outbox, so the only gap is a save during the pull phase
    final gate = Completer<void>();
    final slow = _SlowPullApi(gate);
    final e = SyncEngine(store, slow, idleInterval: const Duration(hours: 1), pokeDelay: const Duration(milliseconds: 300));
    e.start();
    await Future<void>.delayed(const Duration(milliseconds: 20)); // first run is now blocked in its pull

    await store.saveProduct(const ProductDraft(id: _p2, variantId: _v2, name: 'Asukal', price: 1), opId: 'o2');
    e.poke();
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(slow.calls, ['upsert:o2']);
    expect(await store.nextOps(), isEmpty);
    e.dispose();
  });

  test('which server refusals are final', () {
    expect(isPermanent('23505', 'duplicate_barcode'), isTrue);
    expect(isPermanent('22023', 'name_required'), isTrue);
    expect(isPermanent('P0001', 'product_archived'), isTrue);
    expect(isPermanent('42501', 'not_allowed'), isTrue);
    expect(isPermanent('42501', 'no_account'), isFalse, reason: 'stale token: retry after refresh');
    expect(isPermanent('PGRST301', null), isFalse);
    expect(isPermanent(null, null), isFalse);
  });
}

/// Holds the first pull until [gate] completes, like a slow network.
class _SlowPullApi extends FakeApi {
  _SlowPullApi(this.gate);
  final Completer<void> gate;
  var _pulls = 0;

  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async {
    if (_pulls++ == 0) await gate.future;
    return super.pullCatalog(cursors, limit: limit);
  }
}
