import { supabase } from "./supabase.ts";
import { fetchAllPages, fromRaw, rpc } from "./api.ts";
import { listWarehouseBins } from "./bins-api.ts";
import type { VariantOption } from "./purchasing-api.ts";
import type { CountItemPayload, CountStatus, SystemRow } from "./counts-math.ts";

export interface CountWarehouse {
  id: string;
  code: string;
  name: string;
  bins_enabled: boolean;
}

export interface CountBin {
  id: string;
  code: string;
}

export interface CountLineRow {
  id: string;
  variant_id: string;
  bin_id: string | null;
  qty_system: number;
  qty_counted: number;
  qty_variance: number | null;
  auto_zero: boolean;
  variant: VariantOption | null;
  bin: CountBin | null;
}

export interface StockCount {
  id: string;
  count_no: string;
  warehouse_id: string;
  bin_id: string | null;
  status: CountStatus;
  notes: string | null;
  started_at: string;
  closed_at: string | null;
  cancelled_at: string | null;
  cancel_reason: string | null;
  warehouse: { id: string; code: string; name: string } | null;
  bin: CountBin | null;
  stock_count_items: CountLineRow[];
}

export interface CloseCountResult {
  count_id: string;
  status: "closed";
  lines: number;
  corrections: number;
  net_variance: number;
  zeroed: number;
  replay?: boolean;
}

const VARIANT = "variant:product_variants(id, sku, product:products(name, unit))";

/** Warehouses the signed-in user can see (row-level security), with whether they use bins. */
export async function listCountWarehouses(): Promise<CountWarehouse[]> {
  const { data, error } = await supabase
    .from("locations")
    .select("id, code, name, bins_enabled")
    .eq("type", "warehouse")
    .is("deleted_at", null)
    .eq("active", true)
    .order("code");
  if (error) throw fromRaw(error);
  return (data ?? []) as CountWarehouse[];
}

export async function listCounts(warehouseId: string): Promise<StockCount[]> {
  const { data, error } = await supabase
    .from("stock_counts")
    .select(
      `id, count_no, warehouse_id, bin_id, status, notes, started_at, closed_at, cancelled_at, cancel_reason,
       warehouse:locations!stock_counts_warehouse_fk(id, code, name),
       bin:bins!stock_counts_bin_fk(id, code),
       stock_count_items(id, variant_id, bin_id, qty_system, qty_counted, qty_variance, auto_zero, ${VARIANT},
         bin:bins!stock_count_items_bin_fk(id, code))`,
    )
    .eq("warehouse_id", warehouseId)
    .order("started_at", { ascending: false })
    .limit(50);
  if (error) throw fromRaw(error);
  return (data ?? []) as unknown as StockCount[];
}

export async function listCountBins(warehouseId: string): Promise<CountBin[]> {
  const bins = await listWarehouseBins(warehouseId);
  return bins.filter((b) => b.active).map((b) => ({ id: b.id, code: b.code }));
}

/** What the system holds in the warehouse right now: per bin when bins are on, else per product. Zero rows are left out. */
export async function listSystemStock(warehouse: CountWarehouse): Promise<SystemRow[]> {
  if (warehouse.bins_enabled) {
    const bins = await listWarehouseBins(warehouse.id);
    if (bins.length === 0) return [];
    const binIds = bins.map((b) => b.id);
    const rows = await fetchAllPages<{ bin_id: string; variant_id: string; qty_on_hand: number }>((from, to) =>
      supabase
        .from("bin_stock_levels")
        .select("bin_id, variant_id, qty_on_hand")
        .in("bin_id", binIds)
        .neq("qty_on_hand", 0)
        .order("bin_id")
        .order("variant_id")
        .range(from, to),
    );
    return rows.map((s) => ({
      variantId: s.variant_id,
      binId: s.bin_id,
      qty: Number(s.qty_on_hand),
    }));
  }
  const rows = await fetchAllPages<{ variant_id: string; qty_on_hand: number }>((from, to) =>
    supabase
      .from("stock_levels")
      .select("variant_id, qty_on_hand")
      .eq("location_id", warehouse.id)
      .neq("qty_on_hand", 0)
      .order("variant_id")
      .range(from, to),
  );
  return rows.map((r) => ({ variantId: r.variant_id, binId: null, qty: Number(r.qty_on_hand) }));
}

export async function startCount(args: { id: string; warehouseId: string; binId: string | null; notes: string }): Promise<string> {
  return await rpc<string>("start_count", {
    p_id: args.id,
    p_warehouse_id: args.warehouseId,
    p_bin_id: args.binId,
    p_notes: args.notes.trim() === "" ? null : args.notes.trim(),
  });
}

export async function recordCount(countId: string, items: CountItemPayload[]): Promise<{ count_id: string; recorded: number }> {
  return await rpc("record_count", { p_count_id: countId, p_items: items });
}

export async function closeCount(countId: string, zeroUncounted: boolean): Promise<CloseCountResult> {
  return await rpc<CloseCountResult>("close_count", { p_count_id: countId, p_zero_uncounted: zeroUncounted });
}

export async function cancelCount(countId: string, reason: string): Promise<string> {
  return await rpc<string>("cancel_count", { p_count_id: countId, p_reason: reason.trim() === "" ? null : reason.trim() });
}
