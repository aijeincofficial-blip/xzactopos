import { rpc } from "./api.ts";
import type { StorageMetrics } from "./maintenance-api.ts";

export interface PlatformTenant {
  id: string;
  name: string;
  slug: string;
  status: "active" | "suspended" | "archived";
  plan: "free" | "pro";
  base_currency: string;
  timezone: string;
  created_at: string;
  setup_completed: boolean;
  max_locations: number;
  max_users: number;
  max_devices: number;
  max_products: number;
  user_count: number;
  store_count: number;
  warehouse_count: number;
  sales_count: number;
  gross_sales: number;
}

export interface PlatformMetrics {
  total_tenants: number;
  active_tenants: number;
  suspended_tenants: number;
  pro_tenants: number;
  total_users: number;
  total_sales_count: number;
  total_gross_sales: number;
  storage: StorageMetrics;
}

export const fetchPlatformMetrics = () =>
  rpc<PlatformMetrics>("get_platform_metrics");

export const fetchPlatformTenants = (search?: string, status?: string) =>
  rpc<PlatformTenant[]>("list_platform_tenants", {
    p_search: search?.trim() || null,
    p_status: status?.trim() || null,
  });

export const setPlatformTenantStatus = (tenantId: string, status: string, reason?: string) =>
  rpc<{ tenant_id: string; status: string; old_status: string }>("set_platform_tenant_status", {
    p_tenant_id: tenantId,
    p_status: status,
    p_reason: reason?.trim() || null,
  });

export const setPlatformTenantPlan = (
  tenantId: string,
  plan: string,
  limits?: { max_locations?: number; max_users?: number; max_devices?: number; max_products?: number },
) =>
  rpc<{ tenant_id: string; plan: string; old_plan: string }>("set_platform_tenant_plan", {
    p_tenant_id: tenantId,
    p_plan: plan,
    p_limits: limits ?? null,
  });

export const provisionPlatformTenant = (input: {
  name: string;
  slug: string;
  baseCurrency: string;
  ownerUserId: string;
  ownerUsername: string;
  preset?: string;
  timezone?: string;
  ownerFullName?: string;
}) =>
  rpc<string>("provision_tenant", {
    p_name: input.name.trim(),
    p_slug: input.slug.trim(),
    p_base_currency: input.baseCurrency.trim().toUpperCase(),
    p_owner_user_id: input.ownerUserId,
    p_owner_username: input.ownerUsername.trim(),
    p_preset: input.preset ?? "all",
    p_timezone: input.timezone ?? "Asia/Manila",
    p_owner_full_name: input.ownerFullName?.trim() ?? "",
  });
