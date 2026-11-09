import { rpc } from "./api.ts";

// The three read-only warehouse views (F-13f). They run as the signed-in user, so row-level security decides which
// warehouses appear; nothing here filters by role.

export interface WarehouseStockRow {
  location_id: string;
  code: string;
  name: string;
  bins_enabled: boolean;
  qty_on_hand: number;
  avg_cost: number | null;
  stock_value: number | null;
  incoming_qty: number;
  on_order_qty: number;
}

export interface ReorderRow {
  location_id: string;
  location_code: string;
  variant_id: string;
  sku: string;
  product_name: string;
  qty_on_hand: number;
  reorder_point: number;
  incoming_qty: number;
  on_order_qty: number;
  covered: boolean;
  shortfall: number;
}

export interface TransitRow {
  transfer_id: string;
  transfer_no: string;
  from_location_id: string;
  /** Null when the caller cannot see that location. */
  from_code: string | null;
  to_location_id: string;
  to_code: string | null;
  shipped_at: string;
  hours_in_transit: number;
  lines: number;
  units: number;
}

export interface NegativeRow {
  location_id: string;
  location_code: string;
  location_type: "store" | "warehouse";
  variant_id: string;
  sku: string;
  product_name: string;
  /** Below zero. */
  qty_on_hand: number;
  avg_cost: number | null;
  /** Negative, in minor units; null when there is no average cost. */
  stock_value: number | null;
  last_movement_at: string | null;
}

export const PAGE_SIZE = 50;

const num = (v: unknown) => Number(v);
const numOrNull = (v: unknown) => (v === null || v === undefined ? null : Number(v));

export async function warehouseStockByVariant(variantId: string): Promise<WarehouseStockRow[]> {
  const rows = await rpc<Array<Record<string, unknown>>>("warehouse_stock_by_variant", { p_variant_id: variantId });
  return rows.map((r) => ({
    location_id: r.location_id as string,
    code: r.code as string,
    name: r.name as string,
    bins_enabled: Boolean(r.bins_enabled),
    qty_on_hand: num(r.qty_on_hand),
    avg_cost: numOrNull(r.avg_cost),
    stock_value: numOrNull(r.stock_value),
    incoming_qty: num(r.incoming_qty),
    on_order_qty: num(r.on_order_qty),
  }));
}

export async function warehouseReorderList(args: {
  warehouseId: string;
  afterLocation?: string;
  afterVariant?: string;
}): Promise<ReorderRow[]> {
  const rows = await rpc<Array<Record<string, unknown>>>("warehouse_reorder_list", {
    p_warehouse_id: args.warehouseId || null,
    p_limit: PAGE_SIZE,
    p_after_location: args.afterLocation ?? null,
    p_after_variant: args.afterVariant ?? null,
  });
  return rows.map((r) => ({
    location_id: r.location_id as string,
    location_code: r.location_code as string,
    variant_id: r.variant_id as string,
    sku: r.sku as string,
    product_name: r.product_name as string,
    qty_on_hand: num(r.qty_on_hand),
    reorder_point: num(r.reorder_point),
    incoming_qty: num(r.incoming_qty),
    on_order_qty: num(r.on_order_qty),
    covered: Boolean(r.covered),
    shortfall: num(r.shortfall),
  }));
}

export async function warehouseTransfersInTransit(args: {
  warehouseId: string;
  afterShippedAt?: string;
  afterId?: string;
}): Promise<TransitRow[]> {
  const rows = await rpc<Array<Record<string, unknown>>>("warehouse_transfers_in_transit", {
    p_warehouse_id: args.warehouseId || null,
    p_limit: PAGE_SIZE,
    p_after_shipped_at: args.afterShippedAt ?? null,
    p_after_id: args.afterId ?? null,
  });
  return rows.map((r) => ({
    transfer_id: r.transfer_id as string,
    transfer_no: r.transfer_no as string,
    from_location_id: r.from_location_id as string,
    from_code: (r.from_code as string | null) ?? null,
    to_location_id: r.to_location_id as string,
    to_code: (r.to_code as string | null) ?? null,
    shipped_at: r.shipped_at as string,
    hours_in_transit: num(r.hours_in_transit),
    lines: num(r.lines),
    units: num(r.units),
  }));
}

/** Places where stock is below zero (negative stock exceptions). Runs as the user, so only places they may see appear. */
export async function negativeStockList(args: { afterLocation?: string; afterVariant?: string }): Promise<NegativeRow[]> {
  const rows = await rpc<Array<Record<string, unknown>>>("negative_stock_list", {
    p_location_id: null,
    p_limit: PAGE_SIZE,
    p_after_location: args.afterLocation ?? null,
    p_after_variant: args.afterVariant ?? null,
  });
  return rows.map((r) => ({
    location_id: r.location_id as string,
    location_code: r.location_code as string,
    location_type: r.location_type as "store" | "warehouse",
    variant_id: r.variant_id as string,
    sku: r.sku as string,
    product_name: r.product_name as string,
    qty_on_hand: num(r.qty_on_hand),
    avg_cost: numOrNull(r.avg_cost),
    stock_value: numOrNull(r.stock_value),
    last_movement_at: (r.last_movement_at as string | null) ?? null,
  }));
}
