import { describe, expect, it } from "vitest";
import { resolveActiveStore, type ActiveLocation } from "./location-context.tsx";

describe("resolveActiveStore", () => {
  const stores: ActiveLocation[] = [
    { id: "store-1", type: "store", code: "S01", name: "Main Store" },
    { id: "store-2", type: "store", code: "S02", name: "Branch Two" },
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
});
