import { describe, expect, it, vi } from "vitest";
import { ApiError, clearAllCachedAccess, type MyAccess } from "./api.ts";
import {
  accessCacheKey,
  fetchAccessWithOfflineFallback,
  readCachedAccess,
  writeCachedAccess,
} from "./session.tsx";

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

function sampleAccess(userId = "user-1"): MyAccess {
  return {
    user_id: userId,
    username: "cashier",
    full_name: "Cashier One",
    role: "cashier",
    locale: "en",
    is_platform_admin: false,
    tenant: {
      id: "tenant-1",
      name: "QA Alpha",
      slug: "qa-alpha-php",
      status: "active",
      base_currency: "PHP",
      timezone: "Asia/Manila",
      setup_completed: true,
    },
    modules: { inventory: true, pos: true, warehouse: true },
    locations: [{ id: "store-1", type: "store", code: "S01", name: "Main", position: null }],
  };
}

describe("offline MyAccess persistence (F01)", () => {
  it("caches online access per user and falls back when a network error occurs", async () => {
    const storage = new MemoryStorage();
    const expected = sampleAccess("u-cashier");

    const live = await fetchAccessWithOfflineFallback({
      userId: "u-cashier",
      fetchAccess: async () => expected,
      storage,
    });
    expect(live).toEqual(expected);
    expect(readCachedAccess("u-cashier", storage)).toEqual(expected);
    expect(readCachedAccess("u-other", storage)).toBeNull();

    const offline = await fetchAccessWithOfflineFallback({
      userId: "u-cashier",
      fetchAccess: async () => {
        throw new ApiError("unknown", "TypeError: Failed to fetch");
      },
      storage,
    });
    expect(offline).toEqual(expected);
  });

  it("purges cached access and rethrows on explicit account refusal even when offline fallback exists", async () => {
    const storage = new MemoryStorage();
    writeCachedAccess(sampleAccess("u-revoked"), storage);

    await expect(
      fetchAccessWithOfflineFallback({
        userId: "u-revoked",
        fetchAccess: async () => {
          throw new ApiError("deactivated", "account deactivated");
        },
        storage,
      }),
    ).rejects.toThrow("account deactivated");

    expect(readCachedAccess("u-revoked", storage)).toBeNull();
  });

  it("clears all cached access keys on sign-out without touching unrelated keys", () => {
    const storage = new MemoryStorage();
    const access = sampleAccess("u-1");
    writeCachedAccess(access, storage);
    storage.setItem("pos.outbox.v1:u-1", "keep-me");
    expect(storage.getItem(accessCacheKey("u-1"))).not.toBeNull();

    clearAllCachedAccess(storage);
    expect(storage.getItem(accessCacheKey("u-1"))).toBeNull();
    expect(storage.getItem("pos.outbox.v1:u-1")).toBe("keep-me");
  });

  it("rethrows network error cleanly when no cached access exists for user", async () => {
    const storage = new MemoryStorage();
    const fetchAccess = vi.fn().mockRejectedValue(new TypeError("Failed to fetch"));
    await expect(
      fetchAccessWithOfflineFallback({ userId: "u-cold", fetchAccess, storage }),
    ).rejects.toThrow("Failed to fetch");
  });
});
