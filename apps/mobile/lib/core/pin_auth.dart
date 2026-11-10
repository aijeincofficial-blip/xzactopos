import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });

  final String userId;
  final String displayName;
  final String role;
  final String pinHash;

  factory SupervisorPin.fromJson(Map<String, dynamic> json) {
    return SupervisorPin(
      userId: json['user_id'] as String? ?? json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['name'] as String? ?? 'Supervisor',
      role: json['role'] as String? ?? 'supervisor',
      pinHash: json['pin_hash'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'role': role,
        'pin_hash': pinHash,
      };
}

/// Stores and retrieves supervisor PIN hashes for offline branch authentication.
class SupervisorPinStorage {
  static const _prefix = 'pos.offline_pins.';

  static Future<void> savePins(String locationId, List<SupervisorPin> pins) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = pins.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('$_prefix$locationId', jsonList);
  }

  static Future<List<SupervisorPin>> loadPins(String locationId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_prefix$locationId') ?? [];
    return list.map((raw) {
      try {
        return SupervisorPin.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<SupervisorPin>().toList();
  }

  static Future<SupervisorPin?> verifyOfflinePin({
    required String locationId,
    required String pin,
  }) async {
    final pins = await loadPins(locationId);
    for (final candidate in pins) {
      if (PinCrypto.verifyPin(pin, candidate.pinHash)) {
        return candidate;
      }
    }
    return null;
  }
}
