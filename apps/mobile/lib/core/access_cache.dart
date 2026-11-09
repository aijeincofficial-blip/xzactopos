import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The user's access payload (`get_my_access`: role, business, modules, locations) kept on the phone, so the app can open with
/// no signal at all. It only decides what the screens show: every server call still checks the role, the location and the
/// module itself, so a stale copy can never do more than the server allows.
///
/// Rules: a copy belongs to ONE user and is never given to another; it is replaced by every answer from the server; it is
/// dropped when the server says the user has no business, and when the user signs out; and it is too old to use after
/// [maxAge] (a role taken away stays visible on the phone for at most that long while it never reaches the server).
abstract class AccessCache {
  /// How long a saved copy may be used without the server confirming it.
  static const maxAge = Duration(days: 7);

  Future<void> write(String userId, Map<String, dynamic> access);

  /// The saved copy for [userId], or null when there is none, it belongs to someone else, or it is too old.
  Future<Map<String, dynamic>?> read(String? userId);

  Future<void> clear();
}

/// Saved with the app's own preferences. Any failure to read or write is treated as "nothing saved": the cache must never be
/// the reason the app cannot start.
class PrefsAccessCache implements AccessCache {
  PrefsAccessCache({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  static const _key = 'access_cache_v1';

  @override
  Future<void> write(String userId, Map<String, dynamic> access) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode({'user_id': userId, 'saved_at': _now().toUtc().toIso8601String(), 'access': access}));
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>?> read(String? userId) async {
    if (userId == null) return null;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return null;
      return decodeAccessCache(raw, userId, _now());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key);
    } catch (_) {}
  }
}

/// Reads one saved copy: only for [userId], and only while it is no older than [AccessCache.maxAge]. A copy dated in the
/// future (the phone's clock was moved back) is not trusted either.
Map<String, dynamic>? decodeAccessCache(String raw, String userId, DateTime now) {
  try {
    final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
    if (j['user_id'] != userId) return null;
    final saved = DateTime.parse(j['saved_at'] as String);
    final age = now.toUtc().difference(saved);
    if (age > AccessCache.maxAge || age < const Duration(minutes: -5)) return null;
    return (j['access'] as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
}

/// For tests and anything that must not touch the device.
class MemoryAccessCache implements AccessCache {
  MemoryAccessCache({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  String? _raw;

  @override
  Future<void> write(String userId, Map<String, dynamic> access) async {
    _raw = jsonEncode({'user_id': userId, 'saved_at': _now().toUtc().toIso8601String(), 'access': access});
  }

  @override
  Future<Map<String, dynamic>?> read(String? userId) async => userId == null || _raw == null ? null : decodeAccessCache(_raw!, userId, _now());

  @override
  Future<void> clear() async => _raw = null;
}

/// The cache the app uses. Tests replace it (see `test/flutter_test_config.dart`).
AccessCache accessCache = PrefsAccessCache();
