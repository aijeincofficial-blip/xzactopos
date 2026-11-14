import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { hashPinPbkdf2 } from "@pos/core";
import { ApiError, clearSensitiveSessionStorage } from "./api.ts";

async function sha256B64(rawB64: string): Promise<string> {
  const bytes = Uint8Array.from(atob(rawB64), (c) => c.charCodeAt(0));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  let s = "";
  for (const b of new Uint8Array(digest)) s += String.fromCharCode(b);
  return btoa(s);
}

async function hmacSha256Hex(rawB64: string, message: string): Promise<string> {
  const keyBytes = Uint8Array.from(atob(rawB64), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig), (b) => b.toString(16).padStart(2, "0")).join("");
}
import {
  clearAllOfflinePinStorage,
  getCachedOfflinePins,
  isApproverPinUser,
  saveCachedOfflinePins,
  verifyOfflineSupervisorPin,
} from "./offline-pin-api.ts";
import { isNetworkFailure } from "./pos-outbox.ts";

class MemoryStorage implements Storage {
  private map = new Map<string, string>();
  get length(): number {
    return this.map.size;
  }
  clear(): void {
    this.map.clear();
  }
  getItem(key: string): string | null {
    return this.map.get(key) ?? null;
  }
  key(index: number): string | null {
    return Array.from(this.map.keys())[index] ?? null;
  }
  removeItem(key: string): void {
    this.map.delete(key);
  }
  setItem(key: string, value: string): void {
    this.map.set(key, value);
  }
}

const origLocal = globalThis.localStorage;
const origSession = globalThis.sessionStorage;

describe("QA-02 client security controls", () => {
  beforeEach(() => {
    Object.defineProperty(globalThis, "localStorage", {
      value: new MemoryStorage(),
      configurable: true,
    });
    Object.defineProperty(globalThis, "sessionStorage", {
      value: new MemoryStorage(),
      configurable: true,
    });
  });

  afterEach(() => {
    clearAllOfflinePinStorage();
    Object.defineProperty(globalThis, "localStorage", {
      value: origLocal,
      configurable: true,
    });
    Object.defineProperty(globalThis, "sessionStorage", {
      value: origSession,
      configurable: true,
    });
  });

  it("wipes tenant/user/offline-PIN/outbox storage on logout while preserving device & UI prefs", () => {
    localStorage.setItem("pos.access.v1:user-1", '{"tenant":"t1"}');
    localStorage.setItem("xzactopos:pos-cache:t1:s1", '{"items":[]}');
    localStorage.setItem("xzactopos:pos-outbox:t1", '[{"op_id":"1"}]');
    localStorage.setItem("xzactopos:held-orders:s1", '[{"id":"h1"}]');
    localStorage.setItem("pos.offlinePins.s1", '[{"user_id":"sup-1"}]');
    localStorage.setItem("pos.offlinePinFailures.s1", '{"sup-1":[1234]}');
    localStorage.setItem("xzactopos:web-pinned-products", '["SKU1"]');
    localStorage.setItem("pos.activeStoreId", "s1");
    localStorage.setItem("pos.activeWarehouseId", "w1");
    localStorage.setItem("pos.portal", "store");
    localStorage.setItem("pos.deviceId", "dev-keep");
    localStorage.setItem("pos.theme", "dark");
    localStorage.setItem("pos.locale", "fil");
    localStorage.setItem("pos.kioskMode", "1");

    sessionStorage.setItem("xzactopos:draft-po", '{"lines":[]}');
    sessionStorage.setItem("xzactopos:draft-transfer", '{"lines":[]}');
    sessionStorage.setItem("unrelated-key", "keep");

    clearSensitiveSessionStorage();

    expect(localStorage.getItem("pos.access.v1:user-1")).toBeNull();
    expect(localStorage.getItem("xzactopos:pos-cache:t1:s1")).toBeNull();
    expect(localStorage.getItem("xzactopos:pos-outbox:t1")).toBeNull();
    expect(localStorage.getItem("xzactopos:held-orders:s1")).toBeNull();
    expect(localStorage.getItem("pos.offlinePins.s1")).toBeNull();
    expect(localStorage.getItem("pos.offlinePinFailures.s1")).toBeNull();
    expect(localStorage.getItem("xzactopos:web-pinned-products")).toBeNull();
    expect(localStorage.getItem("pos.activeStoreId")).toBeNull();
    expect(localStorage.getItem("pos.activeWarehouseId")).toBeNull();
    expect(localStorage.getItem("pos.portal")).toBeNull();
    expect(sessionStorage.getItem("xzactopos:draft-po")).toBeNull();
    expect(sessionStorage.getItem("xzactopos:draft-transfer")).toBeNull();

    expect(localStorage.getItem("pos.deviceId")).toBe("dev-keep");
    expect(localStorage.getItem("pos.theme")).toBe("dark");
    expect(localStorage.getItem("pos.locale")).toBe("fil");
    expect(localStorage.getItem("pos.kioskMode")).toBe("1");
    expect(sessionStorage.getItem("unrelated-key")).toBe("keep");
  });

  it("filters offline PIN cache strictly to superadmin and manager/supervisor admins", () => {
    expect(isApproverPinUser({ role: "superadmin", position: null })).toBe(true);
    expect(isApproverPinUser({ role: "admin", position: "supervisor" })).toBe(true);
    expect(isApproverPinUser({ role: "admin", position: "manager" })).toBe(true);
    expect(isApproverPinUser({ role: "admin", position: null })).toBe(false);
    expect(isApproverPinUser({ role: "cashier", position: null })).toBe(false);
    expect(isApproverPinUser({ role: "warehouse", position: null })).toBe(false);

    saveCachedOfflinePins("loc-1", [
      { user_id: "u1", username: "owner", full_name: "Owner", role: "superadmin", position: null, pin_hash: "h" },
      { user_id: "u2", username: "sup", full_name: "Sup", role: "admin", position: "supervisor", pin_hash: "h" },
      { user_id: "u3", username: "cash", full_name: "Cashier", role: "cashier", position: null, pin_hash: "h" },
      { user_id: "u4", username: "adm", full_name: "PlainAdmin", role: "admin", position: null, pin_hash: "h" },
    ]);

    expect(getCachedOfflinePins("loc-1").map((u) => u.user_id)).toEqual(["u1", "u2"]);
  });

  it("generates valid HMAC proof from v2 verifier and enforces 5-attempt lockout", async () => {
    const saltB64 = btoa("abcdef0123456789");
    const rawHash = await hashPinPbkdf2("5678", saltB64, 1000);
    const parts = rawHash.split("$");
    const verifier = `${parts[0]}$${parts[1]}$${parts[2]}$v2:${await sha256B64(parts[3]!)}`;

    const approverId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
    const tenantId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
    const refId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";

    saveCachedOfflinePins("loc-2", [
      {
        user_id: approverId,
        username: "sara",
        full_name: "Sara Sup",
        role: "admin",
        position: "supervisor",
        pin_hash: verifier,
      },
    ]);

    const okRes = await verifyOfflineSupervisorPin(
      approverId,
      "5678",
      "sale_discount",
      refId,
      tenantId,
      "loc-2",
    );
    expect(okRes.ok).toBe(true);
    expect(okRes.offlineApproval?.proof).toMatch(/^[0-9a-f]{64}$/);
    const canonical = `${tenantId}|${approverId}|sale_discount|${refId}|${okRes.offlineApproval!.approved_at}`;
    const expectedHmac = await hmacSha256Hex(parts[3]!, canonical);
    expect(okRes.offlineApproval?.proof).toBe(expectedHmac);

    // 4 wrong attempts -> pin_wrong, 5th wrong attempt -> pin_locked
    for (let i = 0; i < 4; i++) {
      const r = await verifyOfflineSupervisorPin(approverId, "0000", "sale_discount", refId, tenantId, "loc-2");
      expect(r).toEqual({ ok: false, hint: "pin_wrong" });
    }
    const fifth = await verifyOfflineSupervisorPin(approverId, "0000", "sale_discount", refId, tenantId, "loc-2");
    expect(fifth).toEqual({ ok: false, hint: "pin_locked" });

    // Even the correct PIN is locked out on the 6th attempt
    const lockedOut = await verifyOfflineSupervisorPin(approverId, "5678", "sale_discount", refId, tenantId, "loc-2");
    expect(lockedOut).toEqual({ ok: false, hint: "pin_locked" });
  });

  it("distinguishes transport errors from server PIN/permission rejections for offline fallback", () => {
    expect(isNetworkFailure(new TypeError("Failed to fetch"))).toBe(true);
    expect(isNetworkFailure(new ApiError("pin_locked", "approver PIN is locked"))).toBe(false);
    expect(isNetworkFailure(new ApiError("pin_wrong", "wrong PIN"))).toBe(false);
    expect(isNetworkFailure(new ApiError("not_allowed", "forbidden"))).toBe(false);
  });
});
