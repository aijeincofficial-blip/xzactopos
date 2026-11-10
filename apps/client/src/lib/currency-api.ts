import { fromRaw } from "./api.ts";
import { supabase } from "./supabase.ts";

export interface ReferenceCurrency {
  code: string;
  exponent: number;
  name: string;
}

export interface TenantCurrency {
  tenant_id: string;
  code: string;
  rate_to_base: number;
  rate_date: string;
  rounding: "half-up" | "half-even" | "floor" | "ceil";
  active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export async function fetchReferenceCurrencies(): Promise<ReferenceCurrency[]> {
  const { data, error } = await supabase
    .from("currencies")
    .select("code, exponent, name")
    .order("code", { ascending: true });

  if (error) throw fromRaw(error);
  return (data ?? []) as ReferenceCurrency[];
}

export async function fetchTenantCurrencies(): Promise<TenantCurrency[]> {
  const { data, error } = await supabase
    .from("tenant_currencies")
    .select("*")
    .is("deleted_at", null)
    .order("code", { ascending: true });

  if (error) throw fromRaw(error);
  return (data ?? []).map((row) => ({
    ...row,
    rate_to_base: Number(row.rate_to_base),
  })) as TenantCurrency[];
}

export interface UpsertTenantCurrencyInput {
  tenantId: string;
  code: string;
  rateToBase: number;
  rateDate?: string;
  rounding?: "half-up" | "half-even" | "floor" | "ceil";
  active?: boolean;
}

export async function upsertTenantCurrency(input: UpsertTenantCurrencyInput): Promise<TenantCurrency> {
  const { data, error } = await supabase
    .from("tenant_currencies")
    .upsert(
      {
        tenant_id: input.tenantId,
        code: input.code.toUpperCase().trim(),
        rate_to_base: input.rateToBase,
        rate_date: input.rateDate ?? new Date().toISOString().slice(0, 10),
        rounding: input.rounding ?? "half-up",
        active: input.active ?? true,
        deleted_at: null,
      },
      { onConflict: "tenant_id, code" },
    )
    .select("*")
    .single();

  if (error) throw fromRaw(error);
  return {
    ...data,
    rate_to_base: Number(data.rate_to_base),
  } as TenantCurrency;
}

export async function deactivateTenantCurrency(tenantId: string, code: string): Promise<void> {
  const { error } = await supabase
    .from("tenant_currencies")
    .update({
      active: false,
      deleted_at: new Date().toISOString(),
    })
    .eq("tenant_id", tenantId)
    .eq("code", code);

  if (error) throw fromRaw(error);
}
