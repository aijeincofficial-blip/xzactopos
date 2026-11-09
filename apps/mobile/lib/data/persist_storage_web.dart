import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Asks the browser not to evict this site's data (IndexedDB holds the unsent sales) under storage pressure.
/// Returns whether the browser agreed. Never throws.
Future<bool> requestPersistentStorage() async {
  try {
    final persisted = await web.window.navigator.storage.persisted().toDart;
    if (persisted.toDart) return true;
    return (await web.window.navigator.storage.persist().toDart).toDart;
  } catch (_) {
    return false;
  }
}
