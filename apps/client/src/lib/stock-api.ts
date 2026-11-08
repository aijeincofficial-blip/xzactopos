import { uuidv7 } from "@pos/core";
import { fromRaw, rpc } from "./api.ts";
import { supabase } from "./supabase.ts";
import { pullCatalog, pushOp, type CatalogPull } from "./sell-api.ts";

export interface ProductRow {
  productId: string;
  variantId: string;
  name: string;
  sku: string;
  barcode: string | null;
  unit: string;
  /** Selling price in the base currency (minor units); null while no price is set. */
  price: number | null;
  cost: number;
  reorderPoint: number;
  taxRate: number;
  tracked: boolean;
  active: boolean;
  /** On hand at the chosen store (0 when the store has no stock row yet). */
  qty: number;
}

/** Joins products, default variant, price and the store's stock level. Archived products are left out; inactive ones stay. */
export function toProductRows(pull: CatalogPull, currency: string, levels: ReadonlyMap<string, number>): ProductRow[] {
  const products = new Map(pull.products.rows.filter((p) => !p.deleted_at).map((p) => [p.id, p]));
  const prices = new Map(pull.variant_prices.rows.filter((p) => p.currency === currency && !p.deleted_at).map((p) => [p.variant_id, p.price]));
  const out: ProductRow[] = [];
  for (const v of pull.product_variants.rows) {
    if (v.deleted_at || !v.is_default) continue;
    const p = products.get(v.product_id);
    if (!p) continue;
    out.push({
      productId: p.id,
      variantId: v.id,
      name: p.name,
      sku: v.sku,
      barcode: v.barcode,
      unit: p.unit,
      price: prices.get(v.id) ?? null,
      cost: v.cost,
      reorderPoint: Number(v.reorder_point),
      taxRate: Number(p.tax_rate),
      tracked: p.track_stock,
      active: p.active && v.active,
      qty: levels.get(v.id) ?? 0,
    });
  }
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

export async function fetchStockLevels(locationId: string): Promise<Map<string, number>> {
  const levels = new Map<string, number>();
  // paged by the primary key so a large catalog is never cut at the API's row limit
  for (let from = 0; ; from += 1000) {
    const { data, error } = await supabase
      .from("stock_levels")
      .select("variant_id, qty_on_hand")
      .eq("location_id", locationId)
      .order("variant_id")
      .range(from, from + 999);
    if (error) throw fromRaw(error);
    for (const r of data) levels.set(r.variant_id, Number(r.qty_on_hand));
    if (data.length < 1000) break;
  }
  return levels;
}

export async function fetchProductRows(currency: string, locationId: string): Promise<ProductRow[]> {
  const [pull, levels] = await Promise.all([pullCatalog(), fetchStockLevels(locationId)]);
  return toProductRows(pull, currency, levels);
}

export interface ProductInput {
  name: string;
  /** Selling price, minor units. */
  price: number;
  cost: number;
  unit: string;
  taxRate: number;
  tracked: boolean;
  active: boolean;
  sku: string;
  barcode: string;
  reorderPoint: number;
}

function productBody(i: ProductInput, ids: { productId: string; variantId: string }): Record<string, unknown> {
  return {
    id: ids.productId,
    name: i.name.trim(),
    unit: i.unit.trim() || "pc",
    tax_rate: i.taxRate,
    track_stock: i.tracked,
    active: i.active,
    price: i.price,
    variant: {
      id: ids.variantId,
      ...(i.sku.trim() ? { sku: i.sku.trim() } : {}),
      barcode: i.barcode.trim() || null,
      cost: i.cost,
      reorder_point: i.reorderPoint,
      active: i.active,
    },
  };
}

/** Creates a product with its one default variant; `openingQty` (when above zero) is posted as opening stock. */
export async function createProduct(i: ProductInput, openingQty: number, locationId: string): Promise<{ variantId: string }> {
  const ids = { productId: uuidv7(), variantId: uuidv7() };
  await rpc("upsert_product", { p_op_id: uuidv7(), p_product: productBody(i, ids) });
  if (openingQty > 0 && i.tracked) {
    await pushOp("post_opening_stock", { variant_id: ids.variantId, qty: openingQty, location_id: locationId });
  }
  return { variantId: ids.variantId };
}

export const updateProduct = (row: Pick<ProductRow, "productId" | "variantId">, i: ProductInput) =>
  rpc("upsert_product", { p_op_id: uuidv7(), p_product: productBody(i, row) });

export const archiveProduct = (productId: string) => rpc("archive_product", { p_op_id: uuidv7(), p_product_id: productId });

/** Stock in: adds `qty`, optionally with the unit cost paid (the average cost follows). */
export const receiveStock = (variantId: string, qty: number, unitCost: number | null, locationId: string) =>
  pushOp("receive_stock", { variant_id: variantId, qty, location_id: locationId, ...(unitCost !== null ? { unit_cost: unitCost } : {}) });

/** A count: sets the on-hand to what was counted; the server records the difference as a movement. */
export const countStock = (variantId: string, counted: number, reason: "counted" | "damage" | "other", locationId: string) =>
  pushOp<{ delta: number }>("adjust_stock", { variant_id: variantId, counted, reason, location_id: locationId });
