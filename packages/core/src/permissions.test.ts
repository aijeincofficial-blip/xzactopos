import { describe, expect, it } from "vitest";
import {
  PERMISSION_KEYS,
  can,
  check,
  contextFromAccess,
  type AccessContext,
  type PermissionKey,
} from "./permissions.ts";

const ALL_MODULES = { inventory: true, pos: true, warehouse: true } as const;

const S1 = "store-1";
const S2 = "store-2";
const W1 = "warehouse-1";

const superadmin: AccessContext = {
  role: "superadmin",
  active: true,
  tenantActive: true,
  modules: ALL_MODULES,
  locations: {
    [S1]: { type: "store", position: null },
    [S2]: { type: "store", position: null },
    [W1]: { type: "warehouse", position: null },
  },
};

// Manager in Store 1, supervisor in Store 2: the Phase 1 acceptance case.
const maria: AccessContext = {
  role: "admin",
  active: true,
  tenantActive: true,
  modules: ALL_MODULES,
  locations: {
    [S1]: { type: "store", position: "manager" },
    [S2]: { type: "store", position: "supervisor" },
  },
};

const juan: AccessContext = {
  role: "cashier",
  active: true,
  tenantActive: true,
  modules: ALL_MODULES,
  locations: { [S1]: { type: "store", position: null } },
};

const pedro: AccessContext = {
  role: "warehouse",
  active: true,
  tenantActive: true,
  modules: ALL_MODULES,
  locations: { [W1]: { type: "warehouse", position: null } },
};

describe("admin with different positions per store", () => {
  const cases: Array<[PermissionKey, string, ReturnType<typeof check>]> = [
    ["catalog.manage", S1, { allowed: true }],
    ["catalog.manage", S2, { allowed: false, reason: "role" }],
    ["discount.override", S1, { allowed: true }],
    ["discount.override", S2, { allowed: true, condition: "with_pin" }],
    ["sale.void", S2, { allowed: true }],
    ["users.manage", S1, { allowed: true, condition: "cashiers_only" }],
    ["users.manage", S2, { allowed: false, reason: "role" }],
    ["stock.adjust_store", S1, { allowed: true }],
    ["stock.adjust_store", S2, { allowed: false, reason: "role" }],
    ["transfer.manage", S1, { allowed: true, condition: "receive_only" }],
    ["reports.store", S2, { allowed: true }],
    ["audit.read", S1, { allowed: true }],
    ["audit.read", S2, { allowed: false, reason: "role" }],
    ["tenant.settings", S1, { allowed: false, reason: "role" }],
    ["purchasing.manage", S1, { allowed: false, reason: "role" }],
  ];
  it.each(cases)("%s at %s", (key, loc, expected) => {
    expect(check(maria, key, loc)).toEqual(expected);
  });

  it("without a location answers for the best of the admin's stores", () => {
    expect(check(maria, "catalog.manage")).toEqual({ allowed: true });
    expect(check(maria, "discount.override")).toEqual({ allowed: true }); // manager in S1 beats PIN in S2
    expect(check(maria, "users.manage")).toEqual({ allowed: true, condition: "cashiers_only" });
  });

  it("refuses locations the user is not assigned to", () => {
    expect(check(maria, "sale.create", W1)).toEqual({ allowed: false, reason: "location" });
    expect(check(maria, "sale.create", "unknown")).toEqual({ allowed: false, reason: "location" });
  });
});

describe("cashier and warehouse", () => {
  it("cashier sells and has limited voids, shifts and reports", () => {
    expect(check(juan, "sale.create", S1)).toEqual({ allowed: true });
    expect(check(juan, "sale.void", S1)).toEqual({ allowed: true, condition: "own_only" });
    expect(check(juan, "shift.manage", S1)).toEqual({ allowed: true, condition: "own_only" });
    expect(check(juan, "reports.store", S1)).toEqual({ allowed: true, condition: "own_shift_summary" });
    expect(can(juan, "discount.override", S1)).toBe(false);
    expect(can(juan, "catalog.manage")).toBe(false);
    expect(can(juan, "users.manage")).toBe(false);
  });

  it("warehouse user runs warehouse work and edits cost and SKU only", () => {
    expect(check(pedro, "catalog.manage", W1)).toEqual({ allowed: true, condition: "cost_and_sku_only" });
    for (const key of ["purchasing.manage", "transfer.manage", "stock.count", "stock.adjust_warehouse", "reports.warehouse"] as const) {
      expect(can(pedro, key, W1), key).toBe(true);
    }
    expect(can(pedro, "sale.create")).toBe(false);
    expect(can(pedro, "stock.adjust_store")).toBe(false);
  });
});

describe("superadmin", () => {
  it("is allowed every permission when all modules are on", () => {
    for (const key of PERMISSION_KEYS) {
      expect(check(superadmin, key), key).toEqual({ allowed: true });
    }
  });

  it("still needs the location to exist in the tenant", () => {
    expect(check(superadmin, "sale.create", "other-tenant-store")).toEqual({ allowed: false, reason: "location" });
  });
});

describe("gates before roles", () => {
  it("deactivated users can do nothing", () => {
    const off = { ...superadmin, active: false };
    for (const key of PERMISSION_KEYS) {
      expect(check(off, key), key).toEqual({ allowed: false, reason: "inactive" });
    }
  });

  it("suspended tenants keep reads and lose writes", () => {
    const suspended = { ...superadmin, tenantActive: false };
    expect(check(suspended, "reports.store")).toEqual({ allowed: true });
    expect(check(suspended, "audit.read")).toEqual({ allowed: true });
    expect(check(suspended, "sale.create")).toEqual({ allowed: false, reason: "tenant_suspended" });
    expect(check(suspended, "tenant.settings")).toEqual({ allowed: false, reason: "tenant_suspended" });
  });

  it("disabled modules hide their permissions", () => {
    const inventoryOnly = { ...maria, modules: { inventory: true, pos: false, warehouse: false } };
    expect(check(inventoryOnly, "sale.create", S1)).toEqual({ allowed: false, reason: "module_disabled" });
    expect(check(inventoryOnly, "transfer.manage", S1)).toEqual({ allowed: false, reason: "module_disabled" });
    expect(check(inventoryOnly, "catalog.manage", S1)).toEqual({ allowed: true });
  });
});

describe("contextFromAccess", () => {
  it("maps the get_my_access payload", () => {
    const ctx = contextFromAccess({
      role: "admin",
      tenant: { status: "suspended" },
      modules: { inventory: true, pos: true, warehouse: false },
      locations: [
        { id: S1, type: "store", position: "manager" },
        { id: S2, type: "store", position: "supervisor" },
      ],
    });
    expect(ctx.tenantActive).toBe(false);
    expect(ctx.locations[S2]).toEqual({ type: "store", position: "supervisor" });
    expect(check(ctx, "reports.store", S2)).toEqual({ allowed: true });
    expect(check(ctx, "sale.create", S1)).toEqual({ allowed: false, reason: "tenant_suspended" });
  });
});
