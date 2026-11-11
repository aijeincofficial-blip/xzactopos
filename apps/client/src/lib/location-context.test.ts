import { describe, expect, it } from "vitest";
import { resolveActiveStore, resolveActiveWarehouse, type ActiveLocation } from "./location-context.tsx";

describe("resolveActiveStore & resolveActiveWarehouse", () => {
  const stores: ActiveLocation[] = [
    { id: "store-1", type: "store", code: "S01", name: "Main Store" },
    { id: "store-2", type: "store", code: "S02", name: "Branch Two" },
  ];
  const warehouses: ActiveLocation[] = [
    { id: "wh-1", type: "warehouse", code: "WH01", name: "Central Hub" },
    { id: "wh-2", type: "warehouse", code: "WH02", name: "North Hub" },
  ];

  it("returns null if no stores exist", () => {
    expect(resolveActiveStore(null, [])).toBe(null);
    expect(resolveActiveStore("store-1", [])).toBe(null);
  });

  it("returns first store when no saved ID is provided", () => {
    expect(resolveActiveStore(null, stores)).toEqual(stores[0]);
  });

  it("returns matching store when valid ID is saved", () => {
    expect(resolveActiveStore("store-2", stores)).toEqual(stores[1]);
  });

  it("falls back to first store when saved ID is invalid", () => {
    expect(resolveActiveStore("non-existent-id", stores)).toEqual(stores[0]);
  });

  it("resolves active warehouse with fallback", () => {
    expect(resolveActiveWarehouse(null, [])).toBe(null);
    expect(resolveActiveWarehouse(null, warehouses)).toEqual(warehouses[0]);
    expect(resolveActiveWarehouse("wh-2", warehouses)).toEqual(warehouses[1]);
    expect(resolveActiveWarehouse("missing", warehouses)).toEqual(warehouses[0]);
  });
});
