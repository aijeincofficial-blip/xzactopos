import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_store.dart';

/// Pure Dart PBKDF2-HMAC-SHA256 implementation matching PostgreSQL/Supabase profile PIN hashes:
/// `pbkdf2_sha256$<iterations>$<salt_b64>$<hash_b64>`
class PinCrypto {
  /// Computes PBKDF2-HMAC-SHA256 for a 32-byte (256-bit) key derivation.
  static Uint8List pbkdf2HmacSha256({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    int dkLen = 32,
  }) {
    final hmac = Hmac(sha256, password);

    // dkLen == 32 matches 1 block of SHA-256 (32 bytes)
    // Block 1: salt || 0x00 0x00 0x00 0x01
    final saltWithBlock = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..setRange(salt.length, salt.length + 4, [0, 0, 0, 1]);

    var u = Uint8List.fromList(hmac.convert(saltWithBlock).bytes);
    final result = Uint8List.fromList(u);

    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < 32; j++) {
        result[j] ^= u[j];
      }
    }

    if (dkLen == 32) return result;
    return Uint8List.sublistView(result, 0, dkLen);
  }

  /// Verifies a plain text PIN against a pbkdf2_sha256 hash string.
  static bool verifyPin(String pin, String pinHash) {
    if (pin.isEmpty || pinHash.isEmpty) return false;
    final parts = pinHash.split(r'$');
    if (parts.length != 4) return false;

    final scheme = parts[0];
    final iterStr = parts[1];
    final saltB64 = parts[2];
    final expectedHashB64 = parts[3];

    if (scheme != 'pbkdf2_sha256' || iterStr.isEmpty || saltB64.isEmpty || expectedHashB64.isEmpty) {
      return false;
    }

    final iterations = int.tryParse(iterStr);
    if (iterations == null || iterations <= 0) return false;

    try {
      final salt = base64Decode(saltB64);
      final expectedHash = base64Decode(expectedHashB64);
      final derived = pbkdf2HmacSha256(
        password: utf8.encode(pin),
        salt: salt,
        iterations: iterations,
        dkLen: expectedHash.length,
      );

      return constantTimeEquals(derived, expectedHash);
    } catch (_) {
      return false;
    }
  }

  /// Hashes a plain text PIN with the given salt and iteration count.
  static String hashPin(String pin, String saltB64, {int iterations = 20000}) {
    final salt = base64Decode(saltB64);
    final derived = pbkdf2HmacSha256(
      password: utf8.encode(pin),
      salt: salt,
      iterations: iterations,
      dkLen: 32,
    );
    return 'pbkdf2_sha256\$$iterations\$$saltB64\$${base64Encode(derived)}';
  }

  /// Constant-time comparison to prevent timing attacks.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Represents an offline supervisor / manager PIN record cached on the device.
class SupervisorPin {
  const SupervisorPin({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.pinHash,
    this.position,
  });

  final String userId;
  final String displayName;
  final String role;
  final String pinHash;
  final String? position;

  /// True only for roles/positions authorized to approve store supervisor actions
  /// (`superadmin`, or `admin` with store `manager`/`supervisor` position; never `cashier` or `warehouse`).
  bool get isStoreApprover {
    if (role == 'cashier' || role == 'warehouse') return false;
    if (role == 'superadmin' || role == 'manager' || role == 'supervisor') return true;
    if (role == 'admin') {
      return position == null || position == 'manager' || position == 'supervisor';
    }
    return false;
  }

  factory SupervisorPin.fromJson(Map<String, dynamic> json) {
    final fullName = (json['full_name'] as String?)?.trim();
    final display = (json['display_name'] as String?)?.trim();
    final username = (json['username'] as String?)?.trim();
    final name = (json['name'] as String?)?.trim();
    return SupervisorPin(
      userId: json['user_id'] as String? ?? json['id'] as String? ?? '',
      displayName: (fullName != null && fullName.isNotEmpty)
          ? fullName
          : (display != null && display.isNotEmpty)
              ? display
              : (username != null && username.isNotEmpty)
                  ? username
                  : (name != null && name.isNotEmpty)
                      ? name
                      : 'Supervisor',
      role: json['role'] as String? ?? 'supervisor',
      position: json['position'] as String?,
      pinHash: json['pin_hash'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'role': role,
        if (position != null) 'position': position,
        'pin_hash': pinHash,
      };
}

enum OfflinePinVerifyStatus { matched, wrongPin, locked, noPins }

class OfflinePinVerifyOutcome {
  const OfflinePinVerifyOutcome._(this.status, [this.approver]);

  const OfflinePinVerifyOutcome.matched(SupervisorPin approver)
      : this._(OfflinePinVerifyStatus.matched, approver);
  const OfflinePinVerifyOutcome.wrongPin()
      : this._(OfflinePinVerifyStatus.wrongPin);
  const OfflinePinVerifyOutcome.locked()
      : this._(OfflinePinVerifyStatus.locked);
  const OfflinePinVerifyOutcome.noPins()
      : this._(OfflinePinVerifyStatus.noPins);

  final OfflinePinVerifyStatus status;
  final SupervisorPin? approver;
}

/// Stores and retrieves supervisor PIN hashes for offline branch authentication,
/// enforcing a local 5-strike / 15-minute lockout matching server `approve_supervisor_action`.
class SupervisorPinStorage {
  static const _prefix = 'pos.offline_pins.';
  static const _failurePrefix = 'pos.offline_pin_failures.';
  static const int maxFailedAttempts = 5;
  static const Duration lockoutWindow = Duration(minutes: 15);

  // Fallback for pure-Dart unit tests where SharedPreferences platform channel is unavailable.
  static final Map<String, List<int>> _memoryFailures = {};

  static void resetInMemoryFailures() => _memoryFailures.clear();

  static Future<void> savePins(String locationId, List<SupervisorPin> pins) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = pins.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('$_prefix$locationId', jsonList);
  }

  static Future<List<SupervisorPin>> loadPins(String locationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('$_prefix$locationId') ?? [];
      return list.map((raw) {
        try {
          return SupervisorPin.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      }).whereType<SupervisorPin>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<int>> _loadRecentFailures(
    String locationId,
    DateTime now, {
    LocalStore? store,
  }) async {
    final cutoff = now.toUtc().subtract(lockoutWindow).millisecondsSinceEpoch;
    if (store != null) {
      final raw = await store.meta('$_failurePrefix$locationId');
      final decoded = raw == null || raw.isEmpty
          ? const <int>[]
          : (jsonDecode(raw) as List).whereType<int>().toList();
      final recent = decoded.where((ms) => ms > cutoff).toList();
      if (recent.length != decoded.length) {
        await store.setMeta('$_failurePrefix$locationId', jsonEncode(recent));
      }
      return recent;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('$_failurePrefix$locationId') ?? const [];
      final recent = raw
          .map(int.tryParse)
          .whereType<int>()
          .where((ms) => ms > cutoff)
          .toList();
      if (recent.length != raw.length) {
        await prefs.setStringList(
          '$_failurePrefix$locationId',
          recent.map((ms) => ms.toString()).toList(),
        );
      }
      return recent;
    } catch (_) {
      final list = (_memoryFailures[locationId] ?? const [])
          .where((ms) => ms > cutoff)
          .toList();
      _memoryFailures[locationId] = list;
      return list;
    }
  }

  static Future<bool> isLockedOut(
    String locationId, {
    DateTime? now,
    LocalStore? store,
  }) async {
    final recent = await _loadRecentFailures(locationId, now ?? DateTime.now(), store: store);
    return recent.length >= maxFailedAttempts;
  }

  static Future<int> recordFailure(
    String locationId, {
    DateTime? now,
    LocalStore? store,
  }) async {
    final ts = (now ?? DateTime.now()).toUtc();
    final recent = await _loadRecentFailures(locationId, ts, store: store);
    recent.add(ts.millisecondsSinceEpoch);
    if (store != null) {
      await store.setMeta('$_failurePrefix$locationId', jsonEncode(recent));
      return recent.length;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        '$_failurePrefix$locationId',
        recent.map((ms) => ms.toString()).toList(),
      );
    } catch (_) {
      _memoryFailures[locationId] = recent;
    }
    return recent.length;
  }

  static Future<void> clearFailures(String locationId, {LocalStore? store}) async {
    _memoryFailures.remove(locationId);
    if (store != null) {
      await store.setMeta('$_failurePrefix$locationId', null);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_failurePrefix$locationId');
    } catch (_) {}
  }

  /// Verifies [pin] against cached store approvers from Drift ([store] / [extraRawPins]) or [SharedPreferences]
  /// (when [store] is null), rejecting non-approver staff (`cashier`/`warehouse`) and enforcing 5-strike lockout.
  static Future<OfflinePinVerifyOutcome> verifyOfflinePinDetailed({
    required String locationId,
    required String pin,
    LocalStore? store,
    List<Map<String, dynamic>> extraRawPins = const [],
    String? approverId,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    if (await isLockedOut(locationId, now: ts, store: store)) {
      return const OfflinePinVerifyOutcome.locked();
    }

    final mergedById = <String, SupervisorPin>{};
    if (store != null) {
      for (final raw in await store.getOfflinePins(locationId: locationId)) {
        final parsed = SupervisorPin.fromJson(raw);
        if (parsed.userId.isNotEmpty && parsed.pinHash.isNotEmpty) {
          mergedById[parsed.userId] = parsed;
        }
      }
    }
    for (final raw in extraRawPins) {
      final parsed = SupervisorPin.fromJson(raw);
      if (parsed.userId.isNotEmpty && parsed.pinHash.isNotEmpty) {
        mergedById[parsed.userId] = parsed;
      }
    }
    if (store == null) {
      for (final p in await loadPins(locationId)) {
        if (p.userId.isNotEmpty && p.pinHash.isNotEmpty) {
          mergedById.putIfAbsent(p.userId, () => p);
        }
      }
    }

    final approvers = mergedById.values.where((c) {
      if (!c.isStoreApprover) return false;
      if (approverId != null && c.userId != approverId) return false;
      return true;
    }).toList();

    if (mergedById.isEmpty || approvers.isEmpty) {
      if (mergedById.isEmpty) {
        return const OfflinePinVerifyOutcome.noPins();
      }
      final count = await recordFailure(locationId, now: ts, store: store);
      return count >= maxFailedAttempts
          ? const OfflinePinVerifyOutcome.locked()
          : const OfflinePinVerifyOutcome.wrongPin();
    }

    for (final candidate in approvers) {
      if (PinCrypto.verifyPin(pin, candidate.pinHash)) {
        await clearFailures(locationId, store: store);
        return OfflinePinVerifyOutcome.matched(candidate);
      }
    }

    final count = await recordFailure(locationId, now: ts, store: store);
    return count >= maxFailedAttempts
        ? const OfflinePinVerifyOutcome.locked()
        : const OfflinePinVerifyOutcome.wrongPin();
  }

  static Future<SupervisorPin?> verifyOfflinePin({
    required String locationId,
    required String pin,
    List<Map<String, dynamic>> extraRawPins = const [],
    String? approverId,
    DateTime? now,
  }) async {
    final outcome = await verifyOfflinePinDetailed(
      locationId: locationId,
      pin: pin,
      extraRawPins: extraRawPins,
      approverId: approverId,
      now: now,
    );
    return outcome.approver;
  }
}
