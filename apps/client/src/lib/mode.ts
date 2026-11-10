import type { MyAccess } from "./api.ts";

/**
 * Solo = one owner and one store, nothing else switched on. Full = anything beyond that.
 * When the tenant carries a stored `mode` flag, that takes precedence.
 * Otherwise it is derived from what `get_my_access` returns.
 */
export type TenantMode = "solo" | "full";

export function tenantMode(
  a: Pick<MyAccess, "role" | "modules" | "locations"> & {
    tenant?: { mode?: TenantMode };
  },
): TenantMode {
  if (a.tenant?.mode) return a.tenant.mode;
  if (a.role !== "superadmin") return "full";
  if (a.modules.warehouse) return "full";
  const stores = a.locations.filter((l) => l.type === "store").length;
  return stores > 1 ? "full" : "solo";
}
