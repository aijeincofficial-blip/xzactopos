import type { Role } from "@pos/core";
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
  if (mode === "solo" || !access.modules.warehouse) {
    return ["pos"];
  }
  if (access.role === "warehouse") {
    return ["warehouse"];
  }
  if (access.role === "cashier") {
    return ["pos"];
  }
  const hasStore = access.locations.some((l) => l.type === "store");
  const hasWarehouse = access.locations.some((l) => l.type === "warehouse");
  if (access.role === "superadmin") {
    return ["pos", "warehouse"];
  }
  const out: PortalKind[] = [];
  if (hasStore || !hasWarehouse) out.push("pos");
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
  if (access.role === "warehouse") return "/app/warehouses";
  if (access.role === "cashier") return "/app/sell";
  const allowed = resolveAllowedPortals(access, mode);
  if (savedPortal === "warehouse" && allowed.includes("warehouse")) {
    return "/app/warehouses";
  }
  return "/app";
}
