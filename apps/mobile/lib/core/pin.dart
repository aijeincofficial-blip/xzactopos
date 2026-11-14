import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

Uint8List _base64ToBytes(String b64) => base64.decode(b64);
String _bytesToBase64(List<int> bytes) => base64.encode(bytes);

/// Derives a 32-byte (256-bit) key using PBKDF2-HMAC-SHA256 (RFC 2898 / RFC 8018).
Uint8List pbkdf2HmacSha256(String pin, List<int> salt, int iterations) {
  final passwordBytes = utf8.encode(pin);
  final hmac = Hmac(sha256, passwordBytes);

  // U_1 = PRF(Password, Salt || INT_32_BE(1))
  final u1Input = Uint8List(salt.length + 4)
    ..setRange(0, salt.length, salt)
    ..[salt.length + 3] = 1; // 0x00, 0x00, 0x00, 0x01

  var u = Uint8List.fromList(hmac.convert(u1Input).bytes);
  final result = Uint8List.fromList(u);

  for (var i = 1; i < iterations; i++) {
    u = Uint8List.fromList(hmac.convert(u).bytes);
    for (var j = 0; j < 32; j++) {
      result[j] ^= u[j];
    }
  }

  return result;
}

/// Generates a PBKDF2-HMAC-SHA256 hash string matching profiles.pin_hash format:
/// `pbkdf2_sha256$<iterations>$<salt base64>$<hash base64>`
String hashPinPbkdf2(String pin, String saltB64, [int iterations = 20000]) {
  final salt = _base64ToBytes(saltB64);
  final derived = pbkdf2HmacSha256(pin, salt, iterations);
  return 'pbkdf2_sha256\$$iterations\$$saltB64\$${_bytesToBase64(derived)}';
}

/// Derives and verifies the 32-byte key from a stored `pin_hash` or a `v2:` verifier.
/// Returns null if the PIN does not match or the format is invalid.
Uint8List? derivePinKeyAndVerify(String pin, String pinHash) {
  if (pin.isEmpty || pinHash.isEmpty) return null;
  final parts = pinHash.split('\$');
  if (parts.length != 4) return null;

  final scheme = parts[0];
  final iterStr = parts[1];
  final saltB64 = parts[2];
  final expected = parts[3];

  if (scheme != 'pbkdf2_sha256' || iterStr.isEmpty || saltB64.isEmpty || expected.isEmpty) {
    return null;
  }

  final iterations = int.tryParse(iterStr);
  if (iterations == null || iterations <= 0) return null;

  try {
    final salt = _base64ToBytes(saltB64);
    final derived = pbkdf2HmacSha256(pin, salt, iterations);
    if (expected.startsWith('v2:')) {
      final expectedDigest = _base64ToBytes(expected.substring(3));
      final actualDigest = sha256.convert(derived).bytes;
      return _constantTimeEquals(actualDigest, expectedDigest) ? derived : null;
    }
    final expectedBytes = _base64ToBytes(expected);
    return _constantTimeEquals(derived, expectedBytes) ? derived : null;
  } catch (_) {
    return null;
  }
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Verifies a PIN against a PBKDF2-HMAC-SHA256 hash or `v2:` verifier string.
bool verifyPinPbkdf2(String pin, String pinHash) =>
    derivePinKeyAndVerify(pin, pinHash) != null;

/// Derives an offline supervisor approval HMAC-SHA256 proof matching Postgres `consume_supervisor_approval`.
String? signOfflineApprovalProof({
  required String pin,
  required String pinHash,
  required String tenantId,
  required String approverId,
  required String action,
  required String refId,
  required String approvedAt,
}) {
  final dk = derivePinKeyAndVerify(pin, pinHash);
  if (dk == null) return null;
  final msg =
      '${tenantId.toLowerCase()}|${approverId.toLowerCase()}|$action|${refId.toLowerCase()}|$approvedAt';
  final digest = Hmac(sha256, dk).convert(utf8.encode(msg));
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
