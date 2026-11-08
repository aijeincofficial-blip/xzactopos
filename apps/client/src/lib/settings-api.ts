import { fromRaw } from "./api.ts";
import { supabase } from "./supabase.ts";

export interface TenantSettingsData {
  tenant: {
    id: string;
    name: string;
    slug: string;
    base_currency: string;
    timezone: string;
    tax_mode: "inclusive" | "exclusive" | "none";
    plan: "free" | "pro";
    status: "active" | "suspended" | "archived";
  };
  settings: {
    default_locale: "en" | "fil";
    locales: ("en" | "fil")[];
    offline_session_days: number;
    receipt_header: string | null;
    receipt_footer: string | null;
  };
  limits: {
    max_locations: number;
    max_users: number;
    max_devices: number;
    max_products: number;
  };
  counts: {
    locations: number;
    users: number;
    devices: number;
    products: number;
  };
}

export async function fetchTenantSettings(): Promise<TenantSettingsData> {
  const [tRes, sRes, lRes, locCount, userCount, devCount, prodCount] = await Promise.all([
    supabase.from("tenants").select("id, name, slug, base_currency, timezone, tax_mode, plan, status").single(),
    supabase.from("tenant_settings").select("default_locale, locales, offline_session_days, receipt_header, receipt_footer").single(),
    supabase.from("tenant_limits").select("max_locations, max_users, max_devices, max_products").maybeSingle(),
    supabase.from("locations").select("id", { count: "exact", head: true }).is("deleted_at", null),
    supabase.from("profiles").select("user_id", { count: "exact", head: true }).is("deleted_at", null),
    supabase.from("devices").select("id", { count: "exact", head: true }).is("revoked_at", null),
    supabase.from("products").select("id", { count: "exact", head: true }).is("deleted_at", null),
  ]);

  if (tRes.error) throw fromRaw(tRes.error);
  if (sRes.error) throw fromRaw(sRes.error);

  return {
    tenant: tRes.data as TenantSettingsData["tenant"],
    settings: sRes.data as TenantSettingsData["settings"],
    limits: (lRes.data as TenantSettingsData["limits"] | null) ?? {
      max_locations: 25,
      max_users: 100,
      max_devices: 50,
      max_products: 10000,
    },
    counts: {
      locations: locCount.count ?? 0,
      users: userCount.count ?? 0,
      devices: devCount.count ?? 0,
      products: prodCount.count ?? 0,
    },
  };
}

export interface UpdateTenantSettingsInput {
  tenantId: string;
  name: string;
  timezone: string;
  tax_mode: "inclusive" | "exclusive" | "none";
  default_locale: "en" | "fil";
  locales: ("en" | "fil")[];
  offline_session_days: number;
  receipt_header?: string | null;
  receipt_footer?: string | null;
}

export async function updateTenantSettings(input: UpdateTenantSettingsInput): Promise<void> {
  const [tRes, sRes] = await Promise.all([
    supabase
      .from("tenants")
      .update({
        name: input.name.trim(),
        timezone: input.timezone.trim(),
        tax_mode: input.tax_mode,
      })
      .eq("id", input.tenantId),
    supabase
      .from("tenant_settings")
      .update({
        default_locale: input.default_locale,
        locales: input.locales,
        offline_session_days: input.offline_session_days,
        receipt_header: input.receipt_header?.trim() || null,
        receipt_footer: input.receipt_footer?.trim() || null,
      })
      .eq("tenant_id", input.tenantId),
  ]);

  if (tRes.error) throw fromRaw(tRes.error);
  if (sRes.error) throw fromRaw(sRes.error);
}
