/**
 * Offline PIN verification using Web Crypto PBKDF2-HMAC-SHA256.
 * Hash format matching database profiles.pin_hash:
 * `pbkdf2_sha256$<iterations>$<salt base64>$<hash base64>`
 */

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    const val = bytes[i];
    if (val !== undefined) {
      binary += String.fromCharCode(val);
    }
  }
  return btoa(binary);
}

export async function hashPinPbkdf2(
  pin: string,
  saltB64: string,
  iterations: number = 20000,
): Promise<string> {
  const salt = base64ToBytes(saltB64);
  const enc = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    enc.encode(pin),
    { name: "PBKDF2" },
    false,
    ["deriveBits"],
  );

  const derivedBits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      salt: salt as unknown as BufferSource,
      iterations,
      hash: "SHA-256",
    },
    keyMaterial,
    256,
  );

  return `pbkdf2_sha256$${iterations}$${saltB64}$${bytesToBase64(new Uint8Array(derivedBits))}`;
}

export async function verifyPinPbkdf2(pin: string, pinHash: string): Promise<boolean> {
  if (!pin || !pinHash) return false;
  const parts = pinHash.split("$");
  if (parts.length !== 4) return false;

  const scheme = parts[0];
  const iterStr = parts[1];
  const saltB64 = parts[2];
  const expectedHashBase64 = parts[3];

  if (scheme !== "pbkdf2_sha256" || !iterStr || !saltB64 || !expectedHashBase64) {
    return false;
  }

  const iterations = parseInt(iterStr, 10);
  if (isNaN(iterations) || iterations <= 0) return false;

  try {
    const salt = base64ToBytes(saltB64);
    const enc = new TextEncoder();
    const keyMaterial = await crypto.subtle.importKey(
      "raw",
      enc.encode(pin),
      { name: "PBKDF2" },
      false,
      ["deriveBits"],
    );

    const derivedBits = await crypto.subtle.deriveBits(
      {
        name: "PBKDF2",
        salt: salt as unknown as BufferSource,
        iterations,
        hash: "SHA-256",
      },
      keyMaterial,
      256,
    );

    const derivedBase64 = bytesToBase64(new Uint8Array(derivedBits));
    return derivedBase64 === expectedHashBase64;
  } catch {
    return false;
  }
}
