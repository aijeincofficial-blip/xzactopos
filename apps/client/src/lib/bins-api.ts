import { rpc } from "./api.ts";

export type ZoneType = "receiving" | "storage" | "picking" | "staging" | "quarantine" | "damaged";
export type BinType = "pallet" | "shelf" | "floor" | "bin";

export interface WarehouseZone {
  id: string;
  code: string;
  name: string;
  type: ZoneType;
}

export interface WarehouseBin {
  id: string;
  code: string;
  zone_id: string | null;
  zone_code: string | null;
  zone_name: string | null;
  zone_type: string | null;
  aisle: string | null;
  rack: string | null;
  shelf: string | null;
  position: string | null;
  type: BinType;
  max_qty: number | null;
  active: boolean;
  item_count: number;
  total_qty: number;
}

export interface BinStockItem {
  variant_id: string;
  sku: string;
  product_name: string;
  qty_on_hand: number;
  updated_at: string;
}

export interface BinStockInvariantRow {
  variant_id: string;
  sku: string;
  warehouse_qty: number;
  bins_qty: number;
  diff: number;
  is_valid: boolean;
}

export interface EnableWarehouseBinsResult {
  ok: boolean;
  warehouse_id: string;
  receiving_bin_id: string;
  staging_bin_id: string;
  migrated_count: number;
}

export async function enableWarehouseBins(warehouseId: string): Promise<EnableWarehouseBinsResult> {
  return await rpc<EnableWarehouseBinsResult>("enable_warehouse_bins", {
    p_warehouse_id: warehouseId,
  });
}

export async function checkBinStockInvariant(warehouseId: string): Promise<BinStockInvariantRow[]> {
  return await rpc<BinStockInvariantRow[]>("check_bin_stock_invariant", {
    p_warehouse_id: warehouseId,
  });
}

export async function listWarehouseBins(warehouseId: string, zoneId?: string): Promise<WarehouseBin[]> {
  return await rpc<WarehouseBin[]>("list_warehouse_bins", {
    p_warehouse_id: warehouseId,
    p_zone_id: zoneId || null,
  });
}

export async function listBinStock(binId: string): Promise<BinStockItem[]> {
  return await rpc<BinStockItem[]>("list_bin_stock", {
    p_bin_id: binId,
  });
}

export async function upsertWarehouseZone(
  warehouseId: string,
  code: string,
  name: string,
  type: ZoneType,
  id?: string,
): Promise<string> {
  return await rpc<string>("upsert_warehouse_zone", {
    p_warehouse_id: warehouseId,
    p_code: code,
    p_name: name,
    p_type: type,
    p_id: id || null,
  });
}

export async function upsertWarehouseBin(
  warehouseId: string,
  code: string,
  zoneId?: string,
  aisle?: string,
  rack?: string,
  shelf?: string,
  position?: string,
  type: BinType = "shelf",
  maxQty?: number,
  id?: string,
): Promise<string> {
  return await rpc<string>("upsert_warehouse_bin", {
    p_warehouse_id: warehouseId,
    p_code: code,
    p_zone_id: zoneId || null,
    p_aisle: aisle || null,
    p_rack: rack || null,
    p_shelf: shelf || null,
    p_position: position || null,
    p_type: type,
    p_max_qty: maxQty || null,
    p_id: id || null,
  });
}

export async function moveBinStock(
  warehouseId: string,
  fromBinId: string,
  toBinId: string,
  variantId: string,
  qty: number,
  reason?: string,
): Promise<void> {
  await rpc("move_bin_stock", {
    p_warehouse_id: warehouseId,
    p_from_bin_id: fromBinId,
    p_to_bin_id: toBinId,
    p_variant_id: variantId,
    p_qty: qty,
    p_reason: reason || null,
  });
}

export async function executePutaway(
  warehouseId: string,
  fromBinId: string,
  toBinId: string,
  variantId: string,
  qty: number,
): Promise<void> {
  await rpc("execute_putaway", {
    p_warehouse_id: warehouseId,
    p_from_bin_id: fromBinId,
    p_to_bin_id: toBinId,
    p_variant_id: variantId,
    p_qty: qty,
  });
}
