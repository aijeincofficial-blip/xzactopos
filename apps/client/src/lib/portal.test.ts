import { describe, expect, it } from "vitest";
import {
  canAccessPosRoute,
  canAccessReceiveStockRoute,
  canAccessReportsRoute,
  canCloseDayForRole,
  portalForPath,
  resolveAllowedPortals,
  resolveEffectivePortal,
  resolveRoleLandingPath,
} from "./portal.ts";

const fullModules = { inventory: true, pos: true, warehouse: true } as const;
const storeLoc = { id: "s1", code: "S01", name: "Main Store", type: "store" as const, position: null };
const whLoc = { id: "w1", code: "WH01", name: "Main Hub", type: "warehouse" as const, position: null };

describe("portal separation rules", () => {
  it("restricts warehouse staff strictly to the warehouse portal", () => {
    const whAccess = {
      role: "warehouse" as const,
      modules: fullModules,
      locations: [whLoc],
      tenant: { setup_completed: true },
    };
    expect(resolveAllowedPortals(whAccess, "full")).toEqual(["warehouse"]);
    expect(resolveEffectivePortal(whAccess, "full", "/app/products", "pos")).toBe("warehouse");
    expect(resolveRoleLandingPath(whAccess, "full", null)).toBe("/app/warehouses");
  });

  it("restricts POS cashiers strictly to the POS portal and lands on /app/sell", () => {
    const cashierAccess = {
      role: "cashier" as const,
      modules: fullModules,
      locations: [storeLoc],
      tenant: { setup_completed: true },
    };
    expect(resolveAllowedPortals(cashierAccess, "full")).toEqual(["pos"]);
    expect(resolveEffectivePortal(cashierAccess, "full", "/app/sell", "warehouse")).toBe("pos");
    expect(resolveRoleLandingPath(cashierAccess, "full", null)).toBe("/app/sell");
  });

  it("allows superadmin in full mode to switch between POS and Warehouse portals", () => {
    const ownerAccess = {
      role: "superadmin" as const,
      modules: fullModules,
      locations: [storeLoc, whLoc],
      tenant: { setup_completed: true },
    };
    expect(resolveAllowedPortals(ownerAccess, "full")).toEqual(["pos", "warehouse"]);
    expect(resolveEffectivePortal(ownerAccess, "full", "/app/warehouses", "pos")).toBe("warehouse");
    expect(resolveEffectivePortal(ownerAccess, "full", "/app/receive-stock", "warehouse")).toBe("pos");
    expect(resolveEffectivePortal(ownerAccess, "full", "/app/products", "warehouse")).toBe("warehouse");
    expect(resolveRoleLandingPath(ownerAccess, "full", "warehouse")).toBe("/app/warehouses");
    expect(resolveRoleLandingPath(ownerAccess, "full", "pos")).toBe("/app");
  });

  it("maps POS and Warehouse routes accurately", () => {
    expect(portalForPath("/app/sell")).toBe("pos");
    expect(portalForPath("/app/receive-stock")).toBe("pos");
    expect(portalForPath("/app/warehouses")).toBe("warehouse");
    expect(portalForPath("/app/bins")).toBe("warehouse");
    expect(portalForPath("/app/transfers")).toBe("warehouse");
    expect(portalForPath("/app/products")).toBe(null);
  });

  it("excludes the POS portal when the pos module is disabled (F05)", () => {
    const whOnlyOwner = {
      role: "superadmin" as const,
      modules: { inventory: true, pos: false, warehouse: true },
      locations: [],
      tenant: { setup_completed: true },
    };
    expect(resolveAllowedPortals(whOnlyOwner, "full")).toEqual(["warehouse"]);
    expect(resolveEffectivePortal(whOnlyOwner, "full", "/app/sell", "pos")).toBe("warehouse");
    expect(resolveRoleLandingPath(whOnlyOwner, "full", "pos")).toBe("/app");

    const disabledCashier = {
      role: "cashier" as const,
      modules: { inventory: true, pos: false, warehouse: true },
      locations: [{ id: "s1", type: "store" as const }],
      tenant: { setup_completed: true },
    };
    expect(resolveAllowedPortals(disabledCashier, "full")).toEqual([]);
    expect(resolveRoleLandingPath(disabledCashier, "full", null)).toBe("/app");
  });

  it("blocks cashiers from /app/expenses, /app/reports, and Close Day submit while allowing shifts (F06)", () => {
    const active = { status: "active" as const };
    const cashier = { role: "cashier" as const, tenant: active, modules: fullModules, locations: [{ id: "s1", type: "store" as const, position: null }] };
    const sup = { role: "admin" as const, tenant: active, modules: fullModules, locations: [{ id: "s1", type: "store" as const, position: "supervisor" as const }] };
    const mgr = { role: "admin" as const, tenant: active, modules: fullModules, locations: [{ id: "s1", type: "store" as const, position: "manager" as const }] };
    const wh = { role: "warehouse" as const, tenant: active, modules: fullModules, locations: [{ id: "w1", type: "warehouse" as const, position: null }] };

    expect(canAccessPosRoute(cashier, "shift.manage", { excludeCashier: true })).toBe(false);
    expect(canAccessPosRoute(cashier, "shift.manage")).toBe(true);
    expect(canAccessPosRoute(sup, "shift.manage", { excludeCashier: true })).toBe(true);

    expect(canAccessReportsRoute(cashier)).toBe(false);
    expect(canAccessReportsRoute(sup)).toBe(true);
    expect(canAccessReportsRoute(mgr)).toBe(true);
    expect(canAccessReportsRoute(wh)).toBe(true);

    expect(canCloseDayForRole("cashier")).toBe(false);
    expect(canCloseDayForRole("warehouse")).toBe(false);
    expect(canCloseDayForRole("admin")).toBe(true);
    expect(canCloseDayForRole("superadmin")).toBe(true);

    const noPosMgr = { ...mgr, modules: { inventory: true, pos: false, warehouse: true } };
    expect(canAccessReceiveStockRoute(noPosMgr)).toBe(true);
    expect(canAccessReceiveStockRoute(wh)).toBe(false);
  });
});
