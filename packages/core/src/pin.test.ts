import { describe, expect, it } from "vitest";
import { hashPinPbkdf2, verifyPinPbkdf2 } from "./pin.ts";

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
});
