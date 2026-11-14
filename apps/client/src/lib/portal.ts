import { can, contextFromAccess, type MyAccessPayload, type PermissionKey, type Role } from "@pos/core";
import type { TenantMode } from "./mode.ts";

export type PortalKind = "pos" | "warehouse";

export interface PortalAccessInput {
  readonly role: Role;
  readonly modules: {
    readonly inventory: boolean;
    readonly pos: boolean;
    readonly warehouse: boolean;
  };
  readonly locations: ReadonlyArray<{
    readonly id: string;
    readonly type: "store" | "warehouse";
  }>;
}

export interface PortalLandingAccessInput extends PortalAccessInput {
  readonly tenant: {
    readonly setup_completed: boolean;
  };
}

const PORTAL_STORAGE_KEY = "pos.portal";

const WAREHOUSE_ROUTE_PREFIXES = [
  "/app/warehouses",
  "/app/purchasing",
  "/app/bins",
  "/app/counts",
  "/app/transfers",
] as const;

const POS_ROUTE_PREFIXES = [
  "/app/sell",
  "/app/receive-stock",
  "/app/sales",
  "/app/utang",
  "/app/services",
  "/app/expenses",
  "/app/day-close",
] as const;

export function readStoredPortal(): PortalKind | null {
  try {
    const v = localStorage.getItem(PORTAL_STORAGE_KEY);
    return v === "pos" || v === "warehouse" ? v : null;
  } catch {
    return null;
  }
}

export function saveStoredPortal(portal: PortalKind): void {
  try {
    localStorage.setItem(PORTAL_STORAGE_KEY, portal);
  } catch {
    // ignore storage errors
  }
}

export function portalForPath(pathname: string): PortalKind | null {
  if (WAREHOUSE_ROUTE_PREFIXES.some((p) => pathname === p || pathname.startsWith(`${p}/`))) {
    return "warehouse";
  }
  if (POS_ROUTE_PREFIXES.some((p) => pathname === p || pathname.startsWith(`${p}/`))) {
    return "pos";
  }
  return null;
}

export function resolveAllowedPortals(access: PortalAccessInput, mode: TenantMode): PortalKind[] {
  if (mode === "solo") {
    return access.modules.pos ? ["pos"] : [];
  }
  if (!access.modules.warehouse) {
    if (access.role === "warehouse") return [];
    return access.modules.pos ? ["pos"] : [];
  }
  if (access.role === "warehouse") {
    return ["warehouse"];
  }
  if (access.role === "cashier") {
    return access.modules.pos ? ["pos"] : [];
  }
  const hasStore = access.locations.some((l) => l.type === "store");
  const hasWarehouse = access.locations.some((l) => l.type === "warehouse");
  if (access.role === "superadmin") {
    return access.modules.pos ? ["pos", "warehouse"] : ["warehouse"];
  }
  const out: PortalKind[] = [];
  if (access.modules.pos && (hasStore || !hasWarehouse)) out.push("pos");
  if (hasWarehouse) out.push("warehouse");
  return out;
}

export function resolveEffectivePortal(
  access: PortalAccessInput,
  mode: TenantMode,
  pathname: string,
  savedPortal: PortalKind | null,
): PortalKind {
  const allowed = resolveAllowedPortals(access, mode);
  if (allowed.length === 0) {
    return access.role === "warehouse" ? "warehouse" : "pos";
  }
  if (allowed.length === 1) return allowed[0]!;

  const fromPath = portalForPath(pathname);
  if (fromPath && allowed.includes(fromPath)) return fromPath;

  if (savedPortal && allowed.includes(savedPortal)) return savedPortal;
  return allowed[0]!;
}

export function resolveRoleLandingPath(
  access: PortalLandingAccessInput,
  mode: TenantMode,
  savedPortal: PortalKind | null,
): "/app" | "/app/sell" | "/app/warehouses" {
  if (!access.tenant.setup_completed) return "/app";
  if (mode === "solo") return "/app";
  if (access.role === "warehouse") return access.modules.warehouse ? "/app/warehouses" : "/app";
  if (access.role === "cashier") return access.modules.pos ? "/app/sell" : "/app";
  const allowed = resolveAllowedPortals(access, mode);
  if (savedPortal === "warehouse" && allowed.includes("warehouse")) {
    return "/app/warehouses";
  }
  return "/app";
}

/** Shared Web route & capability guard helpers (also enforced by Postgres RLS & RPCs). */
export function canAccessPosRoute(
  access: MyAccessPayload,
  perm: PermissionKey,
  opts?: { excludeCashier?: boolean },
): boolean {
  if (!access.modules.pos) return false;
  if (opts?.excludeCashier && access.role === "cashier") return false;
  return can(contextFromAccess(access), perm);
}

export function canAccessReceiveStockRoute(access: MyAccessPayload): boolean {
  if (!access.modules.warehouse || access.role === "warehouse") return false;
  const ctx = contextFromAccess(access);
  return can(ctx, "sale.create") || can(ctx, "stock.adjust_store") || can(ctx, "transfer.manage");
}

export function canAccessReportsRoute(access: MyAccessPayload): boolean {
  if (access.role === "cashier") return false;
  const ctx = contextFromAccess(access);
  const storeOk = access.modules.pos && can(ctx, "reports.store");
  const whOk = access.modules.warehouse && can(ctx, "reports.warehouse");
  return storeOk || whOk;
}

export function canCloseDayForRole(role: Role): boolean {
  return role === "superadmin" || role === "admin";
}
