import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';

/// Server calls the engine needs. `Backend` implements it; tests fake it.
abstract class SyncApi {
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500});

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

  Future<void> _push() async {
    while (true) {
      final ops = await store.nextOps();
      if (ops.isEmpty) return;
      for (final op in ops) {
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
    }
  }

  Future<void> _pull() async {
    for (var page = 0; page < _maxPagesPerRun; page++) {
      final res = await api.pullCatalog(await store.cursors(), limit: pageLimit);
      await store.applyPull(res);
      final more = res.values.any((v) => v is Map && v['has_more'] == true);
      if (!more) return;
    }
  }

  void dispose() {
    stop();
    status.dispose();
  }
}
