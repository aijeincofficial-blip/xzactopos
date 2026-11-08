import { describe, expect, it } from "vitest";
import { tenantMode } from "./mode.ts";
import { dayInTimezone } from "./today.ts";

const base = {
  role: "superadmin" as const,
  modules: { inventory: true, pos: true, warehouse: false },
  locations: [{ id: "s1", type: "store" as const, position: null, code: "MAIN", name: "Main" }],
};

describe("tenantMode", () => {
  it("is solo for an owner with one store and no warehouse", () => {
    expect(tenantMode(base)).toBe("solo");
  });
  it("is full once the warehouse module is on", () => {
    expect(tenantMode({ ...base, modules: { ...base.modules, warehouse: true } })).toBe("full");
  });
  it("is full with a second store", () => {
    const second = { id: "s2", type: "store" as const, position: null, code: "B", name: "B" };
    expect(tenantMode({ ...base, locations: [...base.locations, second] })).toBe("full");
  });
  it("is full for anyone who is not the owner", () => {
    expect(tenantMode({ ...base, role: "cashier" })).toBe("full");
    expect(tenantMode({ ...base, role: "admin" })).toBe("full");
  });
});

describe("dayInTimezone", () => {
  it("uses the business timezone, not UTC", () => {
    const t = new Date("2026-11-08T17:30:00Z"); // already 01:30 on the 9th in Manila
    expect(dayInTimezone("Asia/Manila", t)).toBe("2026-11-09");
    expect(dayInTimezone("UTC", t)).toBe("2026-11-08");
  });
  it("falls back to the UTC day for an unknown timezone", () => {
    expect(dayInTimezone("Not/AZone", new Date("2026-11-08T17:30:00Z"))).toBe("2026-11-08");
  });
});
