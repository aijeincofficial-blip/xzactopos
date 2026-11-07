import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';

/// Server calls the engine needs. `Backend` implements it; tests fake it.
abstract class SyncApi {
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500});

  /// Stock levels, customers and the utang ledger (sync_pull_pos).
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500});

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

/// The server refused an op permanently (bad data, duplicate barcode, no permission). Retrying will not help.
class OpRejected implements Exception {
  const OpRejected(this.hint);
  final String hint;
  @override
  String toString() => 'OpRejected($hint)';
}

enum SyncPhase { idle, syncing, offline }

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
  });

  final LocalStore store;
  final SyncApi api;
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

  Future<void> _run() async {
    _timer?.cancel();
    status.value = SyncStatus(phase: SyncPhase.syncing, lastSyncedAt: status.value.lastSyncedAt);
    try {
      await _push();
      await _pull();
      _backoff = null;
      status.value = SyncStatus(phase: SyncPhase.idle, lastSyncedAt: DateTime.now());
      if (_started) _schedule(idleInterval);
    } catch (e) {
      final next = _backoff == null ? _minBackoff : _backoff! * 2;
      _backoff = next > _maxBackoff ? _maxBackoff : next;
      status.value = SyncStatus(phase: SyncPhase.offline, lastSyncedAt: status.value.lastSyncedAt);
      if (_started) _schedule(_backoff!);
    }
  }

  static const posKinds = {'record_sale', 'void_sale', 'upsert_customer', 'record_utang_payment', 'post_opening_stock', 'receive_stock', 'adjust_stock'};

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
          await store.posOpApplied(op.opId, (r['result'] as Map?)?['applied_at'] as String?);
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
        if (posKinds.contains(op.kind)) {
          // consecutive sale/stock/utang ops go together, in order
          var j = i;
          while (j < ops.length && posKinds.contains(ops[j].kind)) {
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
    for (var page = 0; page < _maxPagesPerRun; page++) {
      final res = await api.pullPos(await store.cursors(), limit: pageLimit);
      await store.applyPullPos(res);
      final more = res.values.any((v) => v is Map && v['has_more'] == true);
      if (!more) return;
    }
  }

  void dispose() {
    stop();
    status.dispose();
  }
}
