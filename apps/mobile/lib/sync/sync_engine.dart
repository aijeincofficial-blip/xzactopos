import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/shift_models.dart';

/// Server calls the engine needs. `Backend` implements it; tests fake it.
abstract class SyncApi {
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500});

  /// Stock levels, customers, the utang ledger and expiry dates (sync_pull_pos).
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500});

  /// Recent sales with their lines and payments (sync_pull_sales). [cursor] is the last one received, or null.
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100});

  /// Expenses (sync_pull_expenses): first pull = last 30 days, then delta by cursor; rows newer than 5 s wait.
  /// Cashiers get no rows.
  Future<Map<String, dynamic>> pullExpenses(Map<String, dynamic>? cursor, {int limit = 100});

  /// Day closes (sync_pull_day_closes), same rules as [pullExpenses].
  Future<Map<String, dynamic>> pullDayCloses(Map<String, dynamic>? cursor, {int limit = 100});

  /// Load / e-wallet entries (sync_pull_service), same rules as [pullExpenses], plus `floats`: the current balance of
  /// every wallet of the caller's stores, read at `server_time`. Warehouse staff get nothing.
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100});

  /// Opened packs (sync_pull_conversions), same rules as [pullExpenses]. The stock levels come with [pullPos].
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100});

  /// Sends up to 50 sale/stock/utang ops in order (sync_push). Returns one result per op:
  /// `{op_id, status: ok|rejected|error, result?, hint?}`. A batch stops at the first `error`, so fewer results can come back.
  /// Throws on network or server trouble (transient).
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops);

  /// Throws [OpRejected] when the server refuses the op for good; any other error is treated as transient.
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload);
  Future<void> archiveProduct(String opId, String productId);

  /// Uploads (or overwrites) a product photo in Storage. Throws [OpRejected] when Storage refuses it for good.
  Future<void> uploadPhoto(String path, Uint8List jpeg);

  /// Downloads a product photo. Throws on any failure (the caller just tries again later).
  Future<Uint8List> downloadPhoto(String path);
}

/// Device registration (F-02). Kept apart from [SyncApi] so servers / fakes without it still work: the engine only
/// registers when its api also implements this. `SupabaseBackend` does.
abstract class DeviceApi {
  /// register_device: idempotent; returns the device row `{id, name, platform, user_id, first_seen_at, last_seen_at}`.
  /// Throws [OpRejected] for a refusal that retrying cannot fix (`id_conflict`, `device_limit`, `invalid_value`); any
  /// other error is transient.
  Future<Map<String, dynamic>> registerDevice(String id, {String? name, String? platform});
}

/// Warehouse data (F-13h). Kept apart from [SyncApi] like [DeviceApi]: only a phone used in a warehouse asks for it, and
/// servers / fakes without it still work. `SupabaseBackend` implements it.
abstract class WarehouseApi {
  /// sync_pull_warehouse: the caller's warehouses, bins, bin and warehouse stock, suppliers and open purchase orders, keyset
  /// paged by [cursors] (kept by name in the store). Returns `{server_time, <table>: {rows, cursor, has_more}}`; an empty map
  /// means there is nothing to apply (the tenant has switched the warehouse module off). Throws on network or server trouble.
  Future<Map<String, dynamic>> pullWarehouse(Map<String, dynamic> cursors, {int limit = 500});
}

/// Offline supervisor PIN material delivery (F-06). Kept apart from [SyncApi] like [DeviceApi] so minimal sync fakes
/// do not need to implement it, while `Backend` implements it automatically.
abstract class OfflinePinApi {
  Future<List<Map<String, dynamic>>> pullOfflinePins({String? locationId});
}

/// The server refused an op permanently (bad data, duplicate barcode, no permission). Retrying will not help.
class OpRejected implements Exception {
  const OpRejected(this.hint);
  final String hint;
  @override
  String toString() => 'OpRejected($hint)';
}

/// The session is no longer valid (expired or revoked). Nothing is lost: sign in again and the queue continues.
class AuthExpired implements Exception {
  const AuthExpired();
  @override
  String toString() => 'AuthExpired';
}

enum SyncPhase { idle, syncing, offline, needsSignIn }

@immutable
class SyncStatus {
  const SyncStatus({this.phase = SyncPhase.idle, this.lastSyncedAt});
  final SyncPhase phase;
  final DateTime? lastSyncedAt;
}

/// Push the outbox, then pull catalog changes. No Realtime (CLAUDE.md): runs on start, shortly after a local
/// change, and every 120 s when idle. Failures back off from 15 s up to 15 min.
class SyncEngine {
  SyncEngine(
    this.store,
    this.api, {
    this.idleInterval = const Duration(seconds: 120),
    this.pokeDelay = const Duration(seconds: 2),
    this.pageLimit = 500,
    this.pullsStore = true,
    this.pullsWarehouse = false,
  });

  final LocalStore store;
  final SyncApi api;

  /// Pull the store's data (stock levels, utang, sales, expenses, day closes, load / e-wallet, opened packs). A warehouse
  /// clerk has no store: false skips those requests (and keeps warehouse stock out of the store tables).
  final bool pullsStore;

  /// Pull the warehouse data ([WarehouseApi]). Only for people who work in a warehouse; a store phone never asks.
  final bool pullsWarehouse;
  final Duration idleInterval;
  final Duration pokeDelay;
  final int pageLimit;

  static const _minBackoff = Duration(seconds: 15);
  static const _maxBackoff = Duration(minutes: 15);
  static const _maxPagesPerRun = 20;

  final status = ValueNotifier(const SyncStatus());
  Timer? _timer;
  Duration? _backoff;
  Future<void>? _running;
  bool _again = false;
  bool _started = false;

  void start() {
    _started = true;
    _schedule(Duration.zero);
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Call after a local write: syncs soon, without waiting for the idle poll.
  void poke() {
    if (!_started) return;
    // A run in progress ends by scheduling the idle poll, which would replace a short timer set now and delay
    // this change by up to [idleInterval]. Ask that run to go again instead.
    if (_running != null) {
      _again = true;
      return;
    }
    _schedule(pokeDelay);
  }

  void _schedule(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, () => syncNow());
  }

  /// One full run. Concurrent calls share the run in progress and trigger one more afterwards.
  Future<void> syncNow() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final run = _run().whenComplete(() {
      _running = null;
      if (_again) {
        _again = false;
        syncNow();
      }
    });
    _running = run;
    return run;
  }

  /// Meta key of the optional device name sent with the registration (set by a Settings screen; null = none).
  static const deviceNameKey = 'device_name';

  /// The server answered the registration in this session (ok, or refused for good). Null = not yet / failed for now.
  Map<String, dynamic>? get device => _device;
  Map<String, dynamic>? _device;
  bool _deviceSettled = false;

  /// Registers this device with the server (F-02), at most once per engine (= per sign-in session) unless [force] (e.g.
  /// after the device name changed). Best effort: never throws; offline or a server error = tried again on the next run.
  /// A permanent refusal (`id_conflict`, `device_limit`) is not retried this session: selling and syncing go on, the
  /// server just stores those sales without a device. Returns true when the server accepted it.
  Future<bool> registerDevice({bool force = false}) async {
    final api = this.api;
    if (api is! DeviceApi) return false;
    if (_deviceSettled && !force) return _device != null;
    try {
      final id = await store.deviceId();
      final name = await store.meta(deviceNameKey);
      _device = await (api as DeviceApi).registerDevice(id, name: name, platform: devicePlatform);
      _deviceSettled = true;
      return true;
    } on OpRejected catch (e) {
      debugPrint('SyncEngine: device registration refused (${e.hint})');
      _deviceSettled = true;
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Short platform name sent with the registration.
  static String get devicePlatform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  Future<void> _run() async {
    _timer?.cancel();
    status.value = SyncStatus(phase: SyncPhase.syncing, lastSyncedAt: status.value.lastSyncedAt);
    try {
      await registerDevice();
      await _push();
      await _pull();
      _backoff = null;
      status.value = SyncStatus(phase: SyncPhase.idle, lastSyncedAt: DateTime.now());
      if (_started) _schedule(idleInterval);
    } catch (e) {
      final next = _backoff == null ? _minBackoff : _backoff! * 2;
      _backoff = next > _maxBackoff ? _maxBackoff : next;
      status.value = SyncStatus(
          phase: e is AuthExpired ? SyncPhase.needsSignIn : SyncPhase.offline, lastSyncedAt: status.value.lastSyncedAt);
      if (_started) _schedule(_backoff!);
    }
  }

  /// Ops that go through sync_push. A `rejected` result parks the op as failed with the server's hint (shown to the
  /// user, never retried on its own), including the supervisor approval hints (`approval_required`,
  /// `approval_invalid`, `approval_expired`, `approval_used`); network trouble and transient server errors retry later.
  static const posKinds = {
    'record_sale', 'void_sale', 'return_sale_items', 'upsert_customer', 'record_utang_payment',
    'post_opening_stock', 'receive_stock', 'adjust_stock', 'adjust_utang', 'record_expense',
    'void_expense', 'close_day', 'record_service_txn', 'void_service_txn', 'set_tingi_link',
    'open_pack', 'void_open_pack', 'set_utang_due', 'set_expiry',
  };

  /// Warehouse receipts and counts (F-13h H7) ride the same batches.
  static const warehouseKinds = {
    'receive_po',
    'receive_without_po',
    'start_count',
    'record_count',
    'close_count',
    'cancel_count',
  };

  /// Cashier shifts (F-05m): opening and closing go through sync_push like any other op.
  static const shiftKinds = {'open_shift', 'close_shift'};

  static bool _viaSyncPush(String kind) => posKinds.contains(kind) || warehouseKinds.contains(kind) || shiftKinds.contains(kind);

  /// One batch through sync_push. Results are applied in order; a transient `error` stops the batch.
  /// Returns how many ops were settled (applied or refused).
  Future<int> _pushPos(List<OutboxOp> batch) async {
    final List<Map<String, dynamic>> results;
    try {
      results = await api.syncPush([
        for (final op in batch) {'op_id': op.opId, 'kind': op.kind, 'payload': op.payload}
      ]);
    } catch (e) {
      await store.opRetryLater(batch.first.opId, e.toString());
      rethrow;
    }
    final byId = {for (final r in results) r['op_id'] as String: r};
    var settled = 0;
    for (final op in batch) {
      final r = byId[op.opId];
      if (r == null) return settled; // the server stopped before this op: it stays queued
      switch (r['status']) {
        case 'ok':
          final result = (r['result'] as Map?)?.cast<String, dynamic>();
          if (warehouseKinds.contains(op.kind)) {
            await store.warehouseOpApplied(op.opId, result?['applied_at'] as String?, result: result);
          } else if (shiftKinds.contains(op.kind)) {
            await store.shiftOpApplied(op.opId, result?['applied_at'] as String?, result: result);
          } else {
            await store.posOpApplied(op.opId, result?['applied_at'] as String?, result: result);
          }
          await store.opDone(op.opId);
          settled++;
        case 'rejected':
          await store.opFailed(op.opId, (r['hint'] as String?) ?? 'rejected');
          settled++;
        default:
          await store.opRetryLater(op.opId, 'server_error_${r['code']}');
          throw StateError('server could not apply ${op.kind} yet');
      }
    }
    return settled;
  }

  Future<void> _push() async {
    while (true) {
      final ops = await store.nextOps();
      if (ops.isEmpty) return;
      var i = 0;
      var settled = 0;
      while (i < ops.length) {
        final op = ops[i];
        if (_viaSyncPush(op.kind)) {
          // consecutive sale/stock/utang/warehouse-receipt ops go together, in order
          var j = i;
          while (j < ops.length && _viaSyncPush(ops[j].kind)) {
            j++;
          }
          settled += await _pushPos(ops.sublist(i, j));
          i = j;
          continue;
        }
        i++;
        settled++;
        try {
          switch (op.kind) {
            case 'upsert_product':
              await api.upsertProduct(op.opId, op.payload);
            case 'archive_product':
              await api.archiveProduct(op.opId, op.payload['product_id'] as String);
            case 'upload_photo':
              // file first, then point the product at it; the upsert reuses this op id, so a retry is a no-op
              final bytes = await store.pendingPhoto(op.opId);
              if (bytes == null) throw const OpRejected('photo_missing');
              final path = op.payload['path'] as String;
              await api.uploadPhoto(path, bytes);
              await api.upsertProduct(op.opId, {
                'id': op.payload['product_id'],
                'photo_path': path,
                'variant': {'id': op.payload['variant_id']},
              });
              await store.photoUploaded(op.opId);
            default:
              throw OpRejected('unknown_op_${op.kind}');
          }
          await store.opDone(op.opId);
        } on OpRejected catch (e) {
          await store.opFailed(op.opId, e.hint);
        } catch (e) {
          // transient: keep order, stop pushing, retry later (same op id, so the server dedupes)
          await store.opRetryLater(op.opId, e.toString());
          rethrow;
        }
      }
      // nothing settled and no error: looping again would only repeat the same call
      if (settled == 0) return;
    }
  }

  Future<void> _pull() async {
    for (var page = 0; page < _maxPagesPerRun; page++) {
      final res = await api.pullCatalog(await store.cursors(), limit: pageLimit);
      await store.applyPull(res);
      final more = res.values.any((v) => v is Map && v['has_more'] == true);
      if (!more) break;
    }
    if (pullsStore) await _pullStore();
    // warehouse staff: after the push, so what was just sent is already in the server's copy
    final wh = api;
    if (pullsWarehouse && wh is WarehouseApi) await _pullWarehouse(wh as WarehouseApi);
  }

  /// A page at a time until the pull is complete: the store settles receipts only on a complete pull. A pull that
  /// runs out of pages simply continues next run.
  Future<void> _pullWarehouse(WarehouseApi wh) async {
    for (var page = 0; page < _maxPagesPerRun; page++) {
      final res = await wh.pullWarehouse(await store.warehouseCursors(), limit: pageLimit);
      await store.applyPullWarehouse(res);
      final more = res.values.any((v) => v is Map && v['has_more'] == true);
      if (!more) break;
    }
  }

  Future<void> _pullStore() async {
    for (var page = 0; page < _maxPagesPerRun; page++) {
      final res = await api.pullPos(await store.cursors(), limit: pageLimit);
      await store.applyPullPos(res);
      final more = res.values.any((v) => v is Map && v['has_more'] == true);
      if (!more) break;
    }
    // sales made on other devices (or before a reinstall): receipts and Today
    for (var page = 0; page < _maxPagesPerRun; page++) {
      final cursor = (await store.cursors())['sales'];
      final res = await api.pullSales(cursor is Map ? cursor.cast<String, dynamic>() : null, limit: 100);
      await store.applyPullSales(res);
      if (res['has_more'] != true) break;
    }
    // expenses and day closes (Today, the cash count); the server holds back rows newer than 5 s
    for (var page = 0; page < _maxPagesPerRun; page++) {
      final cursor = (await store.cursors())['expenses'];
      final res = await api.pullExpenses(cursor is Map ? cursor.cast<String, dynamic>() : null, limit: 100);
      await store.applyPullExpenses(res);
      if (res['has_more'] != true) break;
    }
    for (var page = 0; page < _maxPagesPerRun; page++) {
      final cursor = (await store.cursors())['day_closes'];
      final res = await api.pullDayCloses(cursor is Map ? cursor.cast<String, dynamic>() : null, limit: 100);
      await store.applyPullDayCloses(res);
      if (res['has_more'] != true) break;
    }
    // cashier shifts: the open one and the last 30 days (after the push, so what was just sent is already in the server's copy)
    final sh = api;
    if (sh is ShiftApi) {
      for (var page = 0; page < _maxPagesPerRun; page++) {
        final res = await (sh as ShiftApi).pullShifts(await store.shiftCursor(), limit: 100);
        await store.applyPullShifts(res);
        if (res['has_more'] != true) break;
      }
    }
    // load / e-wallet entries and the float balances (after the push, so the balances include what was just sent)
    for (var page = 0; page < _maxPagesPerRun; page++) {
      final cursor = (await store.cursors())['service_txns'];
      final res = await api.pullService(cursor is Map ? cursor.cast<String, dynamic>() : null, limit: 100);
      await store.applyPullService(res);
      if (res['has_more'] != true) break;
    }
    // opened packs (tingi), for the history; their stock effects already came with the pos pull
    for (var page = 0; page < _maxPagesPerRun; page++) {
      final cursor = (await store.cursors())['conversions'];
      final res = await api.pullConversions(cursor is Map ? cursor.cast<String, dynamic>() : null, limit: 100);
      await store.applyPullConversions(res);
      if (res['has_more'] != true) break;
    }
    // offline supervisor PIN hashes (F-06): refresh for every accessible store so overrides work before first online dialog
    final pinApi = api;
    if (pinApi is OfflinePinApi) {
      await _pullOfflinePins(pinApi as OfflinePinApi);
    }
  }

  Future<void> _pullOfflinePins(OfflinePinApi pinApi) async {
    final locIds = <String>{};
    final active = await store.activeStoreNow();
    if (active != null && active.isNotEmpty) locIds.add(active);
    try {
      for (final s in await store.myStores()) {
        if (s.id.isNotEmpty) locIds.add(s.id);
      }
    } catch (_) {}
    for (final locId in locIds) {
      try {
        final pins = await pinApi.pullOfflinePins(locationId: locId);
        if (pins.isNotEmpty) {
          await store.saveOfflinePins(locId, pins);
        }
      } catch (_) {
        // Best-effort per branch; never fail POS sync if offline PIN pull fails.
      }
    }
  }

  void dispose() {
    stop();
    status.dispose();
  }
}
