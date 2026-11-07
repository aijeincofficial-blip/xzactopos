import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../data/local_store.dart';
import 'sync_engine.dart';

/// Gets product photos for display: from the device first, otherwise downloads them one or two at a time
/// as rows come on screen (never the whole list at once) and keeps them on the device.
class PhotoLoader {
  PhotoLoader(this.store, this.api, {this.maxParallel = 2});

  final LocalStore store;
  final SyncApi api;
  final int maxParallel;

  final _inFlight = <String, Future<Uint8List?>>{};
  final _queue = Queue<void Function()>();
  int _running = 0;

  /// Null when the photo is not on the device and cannot be downloaded right now (offline).
  Future<Uint8List?> load(String productId, String path) {
    // block body on purpose: `=> _inFlight.remove(path)` would return this very future and whenComplete would wait on itself
    return _inFlight[path] ??= _load(productId, path).whenComplete(() {
      _inFlight.remove(path);
    });
  }

  Future<Uint8List?> _load(String productId, String path) async {
    final cached = await store.cachedPhoto(productId, path);
    if (cached != null) return cached;
    final bytes = await _limited(() => api.downloadPhoto(path)).then<Uint8List?>((b) => b, onError: (_) => null);
    if (bytes != null) await store.cachePhoto(productId, path, bytes);
    return bytes;
  }

  Future<T> _limited<T>(Future<T> Function() job) {
    final done = Completer<T>();
    void run() {
      _running++;
      job().then(done.complete, onError: done.completeError).whenComplete(() {
        _running--;
        if (_queue.isNotEmpty) _queue.removeFirst()();
      });
    }

    if (_running < maxParallel) {
      run();
    } else {
      _queue.add(run);
    }
    return done.future;
  }
}
