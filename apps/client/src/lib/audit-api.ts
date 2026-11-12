import { fromRaw } from "./api.ts";
import { supabase } from "./supabase.ts";

export type AuditCategory = "sales" | "stock" | "shifts_cash" | "users_settings";

export interface AuditLogRow {
  id: string;
  user_id: string | null;
  location_id: string | null;
  action: string;
  entity: string;
  entity_id: string | null;
  meta: Record<string, unknown>;
  created_at: string;
}

export interface AuditActorProfile {
  user_id: string;
  username: string;
  full_name: string;
  role: string;
}

export interface AuditFilterInput {
  search: string;
  category: "all" | AuditCategory;
  actorId: string;
  locationId: string;
  onlySensitive: boolean;
  dateFrom: string;
  dateTo: string;
  timezone?: string;
}

const SENSITIVE_ACTIONS = new Set([
  "sale.void",
  "sale.return",
  "approval.grant",
  "pin.failed",
  "pin.clear",
  "role.change",
  "access.revoke",
  "user.deactivate",
  "expense.void",
  "service.void",
  "utang.adjust",
  "location.archive",
  "product.archive",
]);

/** Categorize an audit_log entry into one of 4 operational buckets. */
export function classifyAuditCategory(action: string, entity: string): AuditCategory {
  const a = action.toLowerCase();
  const e = entity.toLowerCase();

  if (
    a.startsWith("sale.") ||
    a.startsWith("utang.") ||
    a.startsWith("customer.") ||
    a.startsWith("approval.") ||
    e === "sale" ||
    e === "sale_return" ||
    e === "customer" ||
    e === "approval"
  ) {
    return "sales";
  }

  if (
    a.startsWith("stock.") ||
    a.startsWith("product.") ||
    a.startsWith("po.") ||
    a.startsWith("purchasing.") ||
    a.startsWith("transfer.") ||
    a.startsWith("count.") ||
    a.startsWith("bin.") ||
    a.startsWith("supplier.") ||
    [
      "product",
      "variant",
      "conversion",
      "purchase_order",
      "transfer",
      "stock_count",
      "bin",
      "supplier",
    ].includes(e)
  ) {
    return "stock";
  }

  if (
    a.startsWith("shift.") ||
    a.startsWith("day.") ||
    a.startsWith("expense.") ||
    a.startsWith("service.") ||
    ["shift", "day_close", "expense", "service_txn"].includes(e)
  ) {
    return "shifts_cash";
  }

  return "users_settings";
}

/** Whether an audit action represents a security-sensitive override, void, PIN event, or access change. */
export function isSecuritySensitiveAudit(action: string): boolean {
  const a = action.toLowerCase();
  return SENSITIVE_ACTIONS.has(a) || a.endsWith(".void") || a.endsWith(".archive") || a.startsWith("pin.");
}

/** Format a compact, single-line summary of the audit `meta` JSON object for table scanning. */
export function summarizeAuditMeta(meta: Record<string, unknown> | null | undefined): string {
  if (!meta || typeof meta !== "object") return "";
  const entries = Object.entries(meta).filter(([, v]) => v !== null && v !== undefined && v !== "");
  if (entries.length === 0) return "";
  return entries
    .slice(0, 3)
    .map(([k, v]) => {
      const text = typeof v === "object" ? JSON.stringify(v) : String(v);
      return `${k}: ${text}`;
    })
    .join(" · ");
}

function dayInTz(iso: string, timezone = "Asia/Manila"): string {
  try {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(new Date(iso));
    const y = parts.find((p) => p.type === "year")?.value;
    const m = parts.find((p) => p.type === "month")?.value;
    const d = parts.find((p) => p.type === "day")?.value;
    if (y && m && d) return `${y}-${m}-${d}`;
  } catch {
    // fallback to UTC date slice
  }
  return iso.slice(0, 10);
}

/** Pure filter helper for client-side search, category, actor, store, sensitivity, and date filtering. */
export function filterAuditLogs(
  rows: ReadonlyArray<AuditLogRow>,
  filters: AuditFilterInput,
  actorLabels: ReadonlyMap<string, string>,
  locationLabels: ReadonlyMap<string, string>,
): AuditLogRow[] {
  const q = filters.search.trim().toLowerCase();
  const tz = filters.timezone || "Asia/Manila";

  return rows.filter((row) => {
    if (filters.category !== "all" && classifyAuditCategory(row.action, row.entity) !== filters.category) {
      return false;
    }
    if (filters.onlySensitive && !isSecuritySensitiveAudit(row.action)) {
      return false;
    }
    if (filters.actorId !== "all") {
      if (filters.actorId === "system") {
        if (row.user_id !== null) return false;
      } else if (row.user_id !== filters.actorId) {
        return false;
      }
    }
    if (filters.locationId !== "all") {
      if (filters.locationId === "global") {
        if (row.location_id !== null) return false;
      } else if (row.location_id !== filters.locationId) {
        return false;
      }
    }
    if (filters.dateFrom || filters.dateTo) {
      const day = dayInTz(row.created_at, tz);
      if (filters.dateFrom && day < filters.dateFrom) return false;
      if (filters.dateTo && day > filters.dateTo) return false;
    }
    if (q) {
      const actor = (row.user_id ? actorLabels.get(row.user_id) ?? row.user_id : "system").toLowerCase();
      const loc = (row.location_id ? locationLabels.get(row.location_id) ?? row.location_id : "global").toLowerCase();
      const metaStr = JSON.stringify(row.meta ?? {}).toLowerCase();
      const hit =
        row.action.toLowerCase().includes(q) ||
        row.entity.toLowerCase().includes(q) ||
        (row.entity_id !== null && row.entity_id.toLowerCase().includes(q)) ||
        actor.includes(q) ||
        loc.includes(q) ||
        metaStr.includes(q);
      if (!hit) return false;
    }
    return true;
  });
}

export async function fetchAuditLogs(limit = 500): Promise<AuditLogRow[]> {
  const { data, error } = await supabase
    .from("audit_log")
    .select("id, user_id, location_id, action, entity, entity_id, meta, created_at")
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw fromRaw(error);
  return (data ?? []).map((r) => ({
    id: r.id as string,
    user_id: (r.user_id as string | null) ?? null,
    location_id: (r.location_id as string | null) ?? null,
    action: r.action as string,
    entity: r.entity as string,
    entity_id: (r.entity_id as string | null) ?? null,
    meta: (r.meta && typeof r.meta === "object" && !Array.isArray(r.meta)
      ? (r.meta as Record<string, unknown>)
      : {}),
    created_at: r.created_at as string,
  }));
}

export async function fetchAuditActors(): Promise<AuditActorProfile[]> {
  const { data, error } = await supabase
    .from("profiles")
    .select("user_id, username, full_name, role")
    .is("deleted_at", null)
    .order("full_name");
  if (error) return [];
  return (data ?? []) as AuditActorProfile[];
}
