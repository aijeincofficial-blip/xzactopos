import { describe, expect, it } from "vitest";
import { hashPinPbkdf2, signOfflineApprovalProof, verifyPinPbkdf2 } from "./pin.ts";

async function sha256B64(rawB64: string): Promise<string> {
  const bin = atob(rawB64);
  const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  let s = "";
  for (const b of new Uint8Array(digest)) s += String.fromCharCode(b);
  return btoa(s);
}

async function hmacSha256Hex(rawB64: string, message: string): Promise<string> {
  const bin = atob(rawB64);
  const keyBytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig), (b) => b.toString(16).padStart(2, "0")).join("");
}

describe("verifyPinPbkdf2", () => {
  it("rejects invalid hash formats", async () => {
    expect(await verifyPinPbkdf2("1234", "")).toBe(false);
    expect(await verifyPinPbkdf2("1234", "invalid_format")).toBe(false);
    expect(await verifyPinPbkdf2("1234", "bcrypt$10$abc$def")).toBe(false);
    expect(await verifyPinPbkdf2("1234", "pbkdf2_sha256$not_a_number$salt$hash")).toBe(false);
  });

  it("verifies matching PIN with 1,000 iterations", async () => {
    const saltB64 = "c2FsdHNhbHRzYWx0MTIz"; // 16 bytes base64
    const pin = "5678";
    const hashStr = await hashPinPbkdf2(pin, saltB64, 1000);

    expect(await verifyPinPbkdf2("5678", hashStr)).toBe(true);
    expect(await verifyPinPbkdf2("0000", hashStr)).toBe(false);
    expect(await verifyPinPbkdf2("5679", hashStr)).toBe(false);
  });

  it("verifies 20,000 iterations default database hash", async () => {
    const saltB64 = "YWJjZGVmZ2hpamtsbW5vcA==";
    const pin = "1111";
    const hashStr = await hashPinPbkdf2(pin, saltB64, 20000);

    expect(await verifyPinPbkdf2("1111", hashStr)).toBe(true);
    expect(await verifyPinPbkdf2("2222", hashStr)).toBe(false);
  });

  it("verifies v2 SHA-256 verifier strings and derives HMAC-SHA256 approval proofs", async () => {
    const saltB64 = btoa("0123456789abcdef");
    const rawHash = await hashPinPbkdf2("7712", saltB64, 1000);
    const parts = rawHash.split("$");
    const verifier = `${parts[0]}$${parts[1]}$${parts[2]}$v2:${await sha256B64(parts[3]!)}`;

    expect(await verifyPinPbkdf2("7712", verifier)).toBe(true);
    expect(await verifyPinPbkdf2("9999", verifier)).toBe(false);

    const input = {
      pin: "7712",
      pinHash: verifier,
      tenantId: "11111111-1111-4111-8111-111111111111",
      approverId: "22222222-2222-4222-8222-222222222222",
      action: "sale_discount",
      refId: "33333333-3333-4333-8333-333333333333",
      approvedAt: "2026-11-14T08:00:00.000Z",
    };

    const signed = await signOfflineApprovalProof(input);
    expect(signed.matched).toBe(true);
    expect(signed.proof).toMatch(/^[0-9a-f]{64}$/);
    const canonical = `${input.tenantId}|${input.approverId}|${input.action}|${input.refId}|${input.approvedAt}`;
    expect(signed.proof).toBe(await hmacSha256Hex(parts[3]!, canonical));

    const wrong = await signOfflineApprovalProof({ ...input, pin: "0000" });
    expect(wrong).toEqual({ matched: false });
  });
});
