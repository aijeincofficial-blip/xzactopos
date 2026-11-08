import type { MyAccess } from "./api.ts";

/**
 * Solo = one owner and one store, nothing else switched on. Full = anything beyond that.
 * There is no stored mode yet: it is derived from what `get_my_access` returns, so a tenant becomes
 * "full" the moment the upgrade (card W-05) turns on the warehouse, adds a second store, or someone
 * other than the owner signs in. Keep every mode decision behind this one function so a stored flag can
 * replace the derivation later without touching screens.
 *
 * Known gap: an owner who has added staff but nothing else still derives as "solo", because the access
 * payload does not carry the staff count.
 */
export type TenantMode = "solo" | "full";

export function tenantMode(a: Pick<MyAccess, "role" | "modules" | "locations">): TenantMode {
  if (a.role !== "superadmin") return "full";
  if (a.modules.warehouse) return "full";
  const stores = a.locations.filter((l) => l.type === "store").length;
  return stores > 1 ? "full" : "solo";
}
