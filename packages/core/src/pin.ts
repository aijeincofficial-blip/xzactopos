/**
 * Offline PIN verification & HMAC-SHA256 approval proof signing
 * using Web Crypto PBKDF2-HMAC-SHA256.
 * Database profiles.pin_hash format:
 *   `pbkdf2_sha256$<iterations>$<salt base64>$<hash base64>`
 * Verifier format returned by pull_offline_pins:
 *   `pbkdf2_sha256$<iterations>$<salt base64>$v2:<sha256(dk) base64>`
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

function bytesToHex(bytes: Uint8Array): string {
  let hex = "";
  for (let i = 0; i < bytes.length; i++) {
    const val = bytes[i];
    if (val !== undefined) {
      hex += val.toString(16).padStart(2, "0");
    }
  }
  return hex;
}

async function derivePinKeyPbkdf2(
  pin: string,
  saltB64: string,
  iterations: number,
): Promise<Uint8Array> {
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

  return new Uint8Array(derivedBits);
}

async function sha256Base64(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes as unknown as BufferSource);
  return bytesToBase64(new Uint8Array(digest));
}

export async function hashPinPbkdf2(
  pin: string,
  saltB64: string,
  iterations: number = 20000,
): Promise<string> {
  const dk = await derivePinKeyPbkdf2(pin, saltB64, iterations);
  return `pbkdf2_sha256$${iterations}$${saltB64}$${bytesToBase64(dk)}`;
}

async function deriveAndVerifyPinKey(pin: string, pinHash: string): Promise<Uint8Array | null> {
  if (!pin || !pinHash) return null;
  const parts = pinHash.split("$");
  if (parts.length !== 4) return null;

  const scheme = parts[0];
  const iterStr = parts[1];
  const saltB64 = parts[2];
  const expected = parts[3];

  if (scheme !== "pbkdf2_sha256" || !iterStr || !saltB64 || !expected) {
    return null;
  }

  const iterations = parseInt(iterStr, 10);
  if (isNaN(iterations) || iterations <= 0) return null;

  try {
    const dk = await derivePinKeyPbkdf2(pin, saltB64, iterations);
    if (expected.startsWith("v2:")) {
      const verifier = `v2:${await sha256Base64(dk)}`;
      return verifier === expected ? dk : null;
    }
    return bytesToBase64(dk) === expected ? dk : null;
  } catch {
    return null;
  }
}

export async function verifyPinPbkdf2(pin: string, pinHash: string): Promise<boolean> {
  return (await deriveAndVerifyPinKey(pin, pinHash)) !== null;
}

export interface OfflineApprovalProofInput {
  pin: string;
  pinHash: string;
  tenantId: string;
  approverId: string;
  action: string;
  refId: string;
  approvedAt: string;
}

export async function signOfflineApprovalProof(
  input: OfflineApprovalProofInput,
): Promise<{ matched: boolean; proof?: string }> {
  const dk = await deriveAndVerifyPinKey(input.pin, input.pinHash);
  if (!dk) return { matched: false };

  const message = `${input.tenantId.toLowerCase()}|${input.approverId.toLowerCase()}|${input.action}|${input.refId.toLowerCase()}|${input.approvedAt}`;
  const hmacKey = await crypto.subtle.importKey(
    "raw",
    dk as unknown as BufferSource,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    hmacKey,
    new TextEncoder().encode(message),
  );
  return { matched: true, proof: bytesToHex(new Uint8Array(sig)) };
}
