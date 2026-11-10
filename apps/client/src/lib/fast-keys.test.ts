import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  PINNED_STORAGE_KEY,
  getStoredPinned,
  saveStoredPinned,
  resolveFastKeyProducts,
  isSkuPinned,
  togglePinnedSku,
} from "./fast-keys.ts";
import type { Sellable } from "./sell-api.ts";

const storageMap = new Map<string, string>();
const mockStorage = {
  getItem: (k: string) => storageMap.get(k) ?? null,
  setItem: (k: string, v: string) => { storageMap.set(k, String(v)); },
  removeItem: (k: string) => { storageMap.delete(k); },
  clear: () => { storageMap.clear(); },
};

const MOCK_SELLABLES: Sellable[] = [
  { variantId: "v1", name: "Rice 1kg", sku: "RICE-1", barcode: null, unit: "kg", price: 50, cost: 40, taxRate: 0, tracked: true },
  { variantId: "v2", name: "Cooking Oil 1L", sku: "OIL-1", barcode: null, unit: "L", price: 80, cost: 65, taxRate: 0, tracked: true },
  { variantId: "v3", name: "Brown Sugar 500g", sku: "SUGAR-B", barcode: null, unit: "pack", price: 35, cost: 28, taxRate: 0, tracked: true },
  { variantId: "v4", name: "White Sugar 500g", sku: "SUGAR-W", barcode: null, unit: "pack", price: 42, cost: 35, taxRate: 0, tracked: true },
  { variantId: "v5", name: "Iodized Salt 250g", sku: "SALT-250", barcode: null, unit: "pack", price: 15, cost: 10, taxRate: 0, tracked: true },
  { variantId: "v6", name: "Soy Sauce 350ml", sku: "SOY-350", barcode: null, unit: "bottle", price: 25, cost: 18, taxRate: 0, tracked: true },
  { variantId: "v7", name: "Vinegar 350ml", sku: "VIN-350", barcode: null, unit: "bottle", price: 22, cost: 16, taxRate: 0, tracked: true },
  { variantId: "v8", name: "Canned Sardines", sku: "SARD-155", barcode: null, unit: "can", price: 28, cost: 22, taxRate: 0, tracked: true },
];

describe("Fast-keys preset logic", () => {
  beforeEach(() => {
    storageMap.clear();
    vi.stubGlobal("localStorage", mockStorage);
  });

  it("defaults to top 6 catalog products when uninitialized (null)", () => {
    const fastKeys = resolveFastKeyProducts(MOCK_SELLABLES, null);
    expect(fastKeys).toHaveLength(6);
    expect(fastKeys.map((p) => p.sku)).toEqual([
      "RICE-1",
      "OIL-1",
      "SUGAR-B",
      "SUGAR-W",
      "SALT-250",
      "SOY-350",
    ]);
  });

  it("returns an empty list when user explicitly clears/unpins all items", () => {
    const fastKeys = resolveFastKeyProducts(MOCK_SELLABLES, []);
    expect(fastKeys).toEqual([]);
  });

  it("resolves pinned products in the exact user-specified order", () => {
    const fastKeys = resolveFastKeyProducts(MOCK_SELLABLES, ["SARD-155", "RICE-1"]);
    expect(fastKeys).toHaveLength(2);
    expect(fastKeys[0]!.sku).toBe("SARD-155");
    expect(fastKeys[1]!.sku).toBe("RICE-1");
  });

  it("filters out pinned SKUs that no longer exist in catalog", () => {
    const fastKeys = resolveFastKeyProducts(MOCK_SELLABLES, ["NON-EXISTENT", "OIL-1"]);
    expect(fastKeys).toHaveLength(1);
    expect(fastKeys[0]!.sku).toBe("OIL-1");
  });

  it("checks whether an SKU is pinned correctly in default and custom modes", () => {
    // Default mode: top 6 are pinned, 7th is not
    expect(isSkuPinned("RICE-1", MOCK_SELLABLES, null)).toBe(true);
    expect(isSkuPinned("VIN-350", MOCK_SELLABLES, null)).toBe(false);

    // Custom mode: only explicit SKUs are pinned
    expect(isSkuPinned("VIN-350", MOCK_SELLABLES, ["VIN-350"])).toBe(true);
    expect(isSkuPinned("RICE-1", MOCK_SELLABLES, ["VIN-350"])).toBe(false);
  });

  it("toggles pin status starting from default 6 when transitioning to custom", () => {
    // Unpinning RICE-1 from defaults keeps the other 5
    const unpinned = togglePinnedSku("RICE-1", MOCK_SELLABLES, null);
    expect(unpinned).toEqual(["OIL-1", "SUGAR-B", "SUGAR-W", "SALT-250", "SOY-350"]);

    // Pinning a 7th item (VIN-350) adds it to the defaults
    const added = togglePinnedSku("VIN-350", MOCK_SELLABLES, null);
    expect(added).toEqual([
      "RICE-1",
      "OIL-1",
      "SUGAR-B",
      "SUGAR-W",
      "SALT-250",
      "SOY-350",
      "VIN-350",
    ]);
  });

  it("toggles pin status on custom lists", () => {
    const initial = ["RICE-1", "OIL-1"];
    const added = togglePinnedSku("SUGAR-B", MOCK_SELLABLES, initial);
    expect(added).toEqual(["RICE-1", "OIL-1", "SUGAR-B"]);

    const removed = togglePinnedSku("RICE-1", MOCK_SELLABLES, added);
    expect(removed).toEqual(["OIL-1", "SUGAR-B"]);
  });

  it("stores and retrieves pinned SKUs from localStorage", () => {
    expect(getStoredPinned()).toBeNull();

    saveStoredPinned(["RICE-1", "VIN-350"]);
    expect(localStorage.getItem(PINNED_STORAGE_KEY)).toBe(JSON.stringify(["RICE-1", "VIN-350"]));
    expect(getStoredPinned()).toEqual(["RICE-1", "VIN-350"]);

    saveStoredPinned([]);
    expect(getStoredPinned()).toEqual([]);
  });
});
