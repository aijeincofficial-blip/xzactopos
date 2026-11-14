import { uuidv7 } from "@pos/core";
import { fromRaw, rpc } from "./api.ts";
import {
  applyOptimisticStockDeltas,
  isNetworkFailure,
  loadPosCache,
  savePosCache,
} from "./pos-outbox.ts";
import { supabase } from "./supabase.ts";
import { pullCatalog, pushOp, type CatalogPull } from "./sell-api.ts";

export interface Category {
  id: string;
  name: string;
  parentId: string | null;
}

export interface ProductRow {
  productId: string;
  variantId: string;
  productName?: string;
  variantName?: string;
  isDefault?: boolean;
  variantCount?: number;
  name: string;
  sku: string;
  barcode: string | null;
  unit: string;
  /** Selling price in the base currency (minor units); null while no price is set. */
  price: number | null;
  cost: number;
  reorderPoint: number;
  defaultReorderPoint?: number;
  isReorderOverride?: boolean;
  taxRate: number;
  tracked: boolean;
  active: boolean;
  /** On hand at the chosen store (0 when the store has no stock row yet). */
  qty: number;
  categoryId: string | null;
  categoryName: string | null;
  breaksIntoVariantId: string | null;
  breaksIntoQty: number | null;
  expiresOn: string | null;
  photoPath?: string | null;
}

export interface ProductGroup {
  productId: string;
  productName: string;
  defaultRow: ProductRow;
  variants: ProductRow[];
}

/** Joins products, their variants, prices, stock levels, categories, expiry, and per-location reorder overrides. Archived products/variants are left out; inactive ones stay. */
export function toProductRows(
  pull: CatalogPull,
  currency: string,
  levels: ReadonlyMap<string, number>,
  expiries?: ReadonlyMap<string, string | null>,
  reorderOverrides?: ReadonlyMap<string, number>,
): ProductRow[] {
  const catMap = new Map((pull.categories?.rows ?? []).filter((c) => !c.deleted_at).map((c) => [c.id, c.name]));
  const products = new Map(pull.products.rows.filter((p) => !p.deleted_at).map((p) => [p.id, p]));
  const prices = new Map(pull.variant_prices.rows.filter((p) => p.currency === currency && !p.deleted_at).map((p) => [p.variant_id, p.price]));

  const variantCounts = new Map<string, number>();
  for (const v of pull.product_variants.rows) {
    if (v.deleted_at || !products.has(v.product_id)) continue;
    variantCounts.set(v.product_id, (variantCounts.get(v.product_id) ?? 0) + 1);
  }

  const out: ProductRow[] = [];
  for (const v of pull.product_variants.rows) {
    if (v.deleted_at) continue;
    const p = products.get(v.product_id);
    if (!p) continue;
    const variantCount = variantCounts.get(p.id) ?? 1;
    const variantName = (v.name ?? "Default").trim() || "Default";
    const showVariantLabel = variantCount > 1 || variantName !== "Default";
    const defaultReorder = Number(v.reorder_point);
    const overrideReorder = reorderOverrides?.get(v.id);
    out.push({
      productId: p.id,
      variantId: v.id,
      productName: p.name,
      variantName,
      isDefault: v.is_default,
      variantCount,
      name: showVariantLabel ? `${p.name} (${variantName})` : p.name,
      sku: v.sku,
      barcode: v.barcode,
      unit: p.unit,
      price: prices.get(v.id) ?? null,
      cost: v.cost,
      reorderPoint: overrideReorder ?? defaultReorder,
      defaultReorderPoint: defaultReorder,
      isReorderOverride: overrideReorder !== undefined,
      taxRate: Number(p.tax_rate),
      tracked: p.track_stock,
      active: p.active && v.active,
      qty: levels.get(v.id) ?? 0,
      categoryId: p.category_id ?? null,
      categoryName: p.category_id ? catMap.get(p.category_id) ?? null : null,
      breaksIntoVariantId: v.breaks_into_variant_id ?? null,
      breaksIntoQty: v.breaks_into_qty ? Number(v.breaks_into_qty) : null,
      expiresOn: expiries?.get(v.id) ?? null,
      ...(p.photo_path ? { photoPath: p.photo_path } : {}),
    });
  }
  return out.sort((a, b) => {
    const pCmp = (a.productName ?? a.name).localeCompare(b.productName ?? b.name);
    if (pCmp !== 0) return pCmp;
    const dCmp = Number(b.isDefault ?? false) - Number(a.isDefault ?? false);
    if (dCmp !== 0) return dCmp;
    return (a.variantName ?? a.name).localeCompare(b.variantName ?? b.name);
  });
}

/** Groups per-variant `ProductRow` entries into product cards while preserving sort order. */
export function groupProductRows(rows: ReadonlyArray<ProductRow>): ProductGroup[] {
  const byProduct = new Map<string, ProductRow[]>();
  for (const r of rows) {
    const list = byProduct.get(r.productId);
    if (list) list.push(r);
    else byProduct.set(r.productId, [r]);
  }
  const out: ProductGroup[] = [];
  for (const [productId, variants] of byProduct) {
    const defaultRow = variants.find((v) => v.isDefault) ?? variants[0]!;
    out.push({
      productId,
      productName: defaultRow.productName ?? defaultRow.name,
      defaultRow,
      variants,
    });
  }
  return out;
}

export async function fetchStockLevels(locationId: string): Promise<Map<string, number>> {
  const slot = `stock:${locationId}`;
  try {
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
    savePosCache(slot, Array.from(levels.entries()));
    return applyOptimisticStockDeltas(levels, locationId);
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<Array<[string, number]>>(slot);
      if (cached) return applyOptimisticStockDeltas(new Map(cached), locationId);
    }
    throw err;
  }
}

export async function fetchStockExpiries(locationId: string): Promise<Map<string, string | null>> {
  const slot = `expiries:${locationId}`;
  try {
    const expiries = new Map<string, string | null>();
    const { data, error } = await supabase
      .from("stock_expiry")
      .select("variant_id, expires_on")
      .eq("location_id", locationId);
    if (error) throw fromRaw(error);
    for (const r of data ?? []) {
      if (r.expires_on) expiries.set(r.variant_id, r.expires_on);
    }
    savePosCache(slot, Array.from(expiries.entries()));
    return expiries;
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<Array<[string, string | null]>>(slot);
      if (cached) return new Map(cached);
    }
    throw err;
  }
}

export async function fetchLocationReorderPoints(locationId: string): Promise<Map<string, number>> {
  const slot = `reorder-points:${locationId}`;
  try {
    const overrides = new Map<string, number>();
    const { data, error } = await supabase
      .from("location_reorder_points")
      .select("variant_id, reorder_point")
      .eq("location_id", locationId);
    if (error) throw fromRaw(error);
    for (const r of data ?? []) {
      overrides.set(r.variant_id, Number(r.reorder_point));
    }
    savePosCache(slot, Array.from(overrides.entries()));
    return overrides;
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<Array<[string, number]>>(slot);
      if (cached) return new Map(cached);
    }
    throw err;
  }
}

export async function fetchProductRows(currency: string, locationId: string): Promise<ProductRow[]> {
  const [pull, levels, expiries, reorderOverrides] = await Promise.all([
    pullCatalog(),
    fetchStockLevels(locationId),
    fetchStockExpiries(locationId).catch(() => new Map<string, string | null>()),
    fetchLocationReorderPoints(locationId).catch(() => new Map<string, number>()),
  ]);
  return toProductRows(pull, currency, levels, expiries, reorderOverrides);
}

export type StockMovementType =
  | "opening"
  | "sale"
  | "sale_void"
  | "sale_return"
  | "receipt"
  | "count_correction"
  | "damage"
  | "conversion_out"
  | "conversion_in"
  | "conversion_void"
  | "transfer_out"
  | "transfer_in"
  | "bin_move";

export type MovementFilterCategory = "sales" | "transfers" | "restock" | "adjustments";

export interface RawStockMovement {
  id: string;
  variant_id: string;
  qty_delta: number | string;
  type: string;
  ref_type: string | null;
  occurred_at: string;
}

export interface StockMovementRow {
  id: string;
  variantId: string;
  productName: string;
  sku: string;
  unit: string;
  qtyDelta: number;
  type: StockMovementType | string;
  category: MovementFilterCategory;
  occurredAt: string;
}

export function classifyMovementCategory(type: string): MovementFilterCategory {
  if (type === "sale" || type === "sale_void" || type === "sale_return") return "sales";
  if (type === "transfer_in" || type === "transfer_out" || type === "bin_move") return "transfers";
  if (type === "opening" || type === "receipt") return "restock";
  return "adjustments";
}

export function toStockMovementRows(raw: ReadonlyArray<RawStockMovement>, pull: CatalogPull): StockMovementRow[] {
  const products = new Map(pull.products.rows.map((p) => [p.id, p]));
  const variants = new Map(pull.product_variants.rows.map((v) => [v.id, v]));
  return raw.map((m) => {
    const v = variants.get(m.variant_id);
    const p = v ? products.get(v.product_id) : undefined;
    return {
      id: m.id,
      variantId: m.variant_id,
      productName: p?.name ?? m.variant_id.slice(0, 8),
      sku: v?.sku ?? "—",
      unit: p?.unit ?? "pc",
      qtyDelta: Number(m.qty_delta),
      type: m.type,
      category: classifyMovementCategory(m.type),
      occurredAt: m.occurred_at,
    };
  });
}

export async function fetchStockMovements(locationId: string, limit = 150): Promise<StockMovementRow[]> {
  const [pull, movRes] = await Promise.all([
    pullCatalog(),
    supabase
      .from("stock_movements")
      .select("id, variant_id, qty_delta, type, ref_type, occurred_at")
      .eq("location_id", locationId)
      .order("occurred_at", { ascending: false })
      .limit(limit),
  ]);
  if (movRes.error) throw fromRaw(movRes.error);
  return toStockMovementRows((movRes.data ?? []) as RawStockMovement[], pull);
}

export async function fetchCategories(): Promise<Category[]> {
  try {
    const { data, error } = await supabase
      .from("categories")
      .select("id, name, parent_id")
      .is("deleted_at", null)
      .order("name");
    if (error) throw fromRaw(error);
    const rows = (data ?? []).map((c) => ({
      id: c.id,
      name: c.name,
      parentId: c.parent_id,
    }));
    savePosCache("categories", rows);
    return rows;
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<Category[]>("categories");
      if (cached) return cached;
    }
    throw err;
  }
}

export async function upsertCategory(input: { id?: string; name: string; parentId?: string | null }): Promise<Category> {
  const res = await rpc<{ id: string; name: string; parent_id: string | null }>("upsert_category", {
    p_op_id: uuidv7(),
    p_category: {
      ...(input.id ? { id: input.id } : {}),
      name: input.name.trim(),
      parent_id: input.parentId ?? null,
    },
  });
  return { id: res.id, name: res.name, parentId: res.parent_id };
}

export const archiveCategory = (categoryId: string) =>
  rpc("archive_category", { p_op_id: uuidv7(), p_category_id: categoryId });

export interface VariantInput {
  id?: string;
  name: string;
  sku: string;
  barcode: string;
  price: number;
  cost: number;
  reorderPoint: number;
  isDefault?: boolean;
  active?: boolean;
  openingQty?: number;
}

export interface ProductInput {
  name: string;
  price: number;
  cost: number;
  unit: string;
  taxRate: number;
  tracked: boolean;
  active: boolean;
  sku: string;
  barcode: string;
  reorderPoint: number;
  categoryId?: string | null;
  breaksIntoVariantId?: string | null;
  breaksIntoQty?: number | null;
  photoPath?: string | null;
  variants?: VariantInput[];
}

interface ResolvedVariant {
  id: string;
  name: string;
  sku: string;
  barcode: string;
  price: number;
  cost: number;
  reorderPoint: number;
  isDefault: boolean;
  active: boolean;
  openingQty: number;
}

function resolveVariants(i: ProductInput, fallbackVariantId: string): ResolvedVariant[] {
  if (i.variants && i.variants.length > 0) {
    const hasExplicitDefault = i.variants.some((v) => v.isDefault);
    return i.variants.map((v, idx) => ({
      id: v.id ?? uuidv7(),
      name: v.name.trim() || "Default",
      sku: v.sku.trim(),
      barcode: v.barcode.trim(),
      price: v.price,
      cost: v.cost,
      reorderPoint: v.reorderPoint,
      isDefault: hasExplicitDefault ? Boolean(v.isDefault) : idx === 0,
      active: v.active ?? i.active,
      openingQty: v.openingQty ?? 0,
    }));
  }
  return [
    {
      id: fallbackVariantId,
      name: "Default",
      sku: i.sku.trim(),
      barcode: i.barcode.trim(),
      price: i.price,
      cost: i.cost,
      reorderPoint: i.reorderPoint,
      isDefault: true,
      active: i.active,
      openingQty: 0,
    },
  ];
}

function productBody(
  i: ProductInput,
  productId: string,
  resolvedVariants: ResolvedVariant[],
): Record<string, unknown> {
  const usesArray = Boolean(i.variants && i.variants.length > 0);
  if (usesArray) {
    return {
      id: productId,
      name: i.name.trim(),
      unit: i.unit.trim() || "pc",
      tax_rate: i.taxRate,
      track_stock: i.tracked,
      active: i.active,
      ...(i.categoryId !== undefined ? { category_id: i.categoryId } : {}),
      ...(i.photoPath !== undefined ? { photo_path: i.photoPath } : {}),
      variants: resolvedVariants.map((v) => ({
        id: v.id,
        name: v.name,
        ...(v.sku ? { sku: v.sku } : {}),
        barcode: v.barcode || null,
        price: v.price,
        cost: v.cost,
        reorder_point: v.reorderPoint,
        is_default: v.isDefault,
        active: v.active,
      })),
    };
  }
  const single = resolvedVariants[0]!;
  return {
    id: productId,
    name: i.name.trim(),
    unit: i.unit.trim() || "pc",
    tax_rate: i.taxRate,
    track_stock: i.tracked,
    active: i.active,
    price: i.price,
    ...(i.categoryId !== undefined ? { category_id: i.categoryId } : {}),
    ...(i.photoPath !== undefined ? { photo_path: i.photoPath } : {}),
    variant: {
      id: single.id,
      name: single.name,
      ...(single.sku ? { sku: single.sku } : {}),
      barcode: single.barcode || null,
      cost: single.cost,
      reorder_point: single.reorderPoint,
      active: i.active,
    },
  };
}

/** Creates a product with one or more variants; `openingQty` / per-variant `openingQty` above zero are posted as opening stock. */
export async function createProduct(
  i: ProductInput,
  openingQty: number,
  locationId: string,
  explicitProductId?: string,
): Promise<{ productId: string; variantId: string }> {
  const productId = explicitProductId ?? uuidv7();
  const fallbackVariantId = uuidv7();
  const resolved = resolveVariants(i, fallbackVariantId);
  const defaultVariant = resolved.find((v) => v.isDefault) ?? resolved[0]!;
  await rpc("upsert_product", { p_op_id: uuidv7(), p_product: productBody(i, productId, resolved) });
  if (i.tracked) {
    if (i.variants && i.variants.length > 0) {
      for (const v of resolved) {
        if (v.openingQty > 0) {
          await pushOp("post_opening_stock", { variant_id: v.id, qty: v.openingQty, location_id: locationId });
        }
      }
    } else if (openingQty > 0) {
      await pushOp("post_opening_stock", { variant_id: defaultVariant.id, qty: openingQty, location_id: locationId });
    }
  }
  if (i.breaksIntoVariantId && i.breaksIntoQty && i.breaksIntoQty > 0) {
    await setTingiLink(defaultVariant.id, i.breaksIntoVariantId, i.breaksIntoQty);
  }
  return { productId, variantId: defaultVariant.id };
}

export async function updateProduct(
  row: Pick<ProductRow, "productId" | "variantId">,
  i: ProductInput,
  openingLocationId?: string,
): Promise<void> {
  const resolved = resolveVariants(i, row.variantId);
  const defaultVariant = resolved.find((v) => v.isDefault) ?? resolved[0]!;
  await rpc("upsert_product", { p_op_id: uuidv7(), p_product: productBody(i, row.productId, resolved) });
  if (i.tracked && openingLocationId && i.variants && i.variants.length > 0) {
    for (const v of resolved) {
      if (v.openingQty > 0) {
        await pushOp("post_opening_stock", { variant_id: v.id, qty: v.openingQty, location_id: openingLocationId });
      }
    }
  }
  if (i.breaksIntoVariantId !== undefined) {
    if (i.breaksIntoVariantId && i.breaksIntoQty && i.breaksIntoQty > 0) {
      await setTingiLink(defaultVariant.id, i.breaksIntoVariantId, i.breaksIntoQty);
    } else {
      await setTingiLink(defaultVariant.id, null, 0);
    }
  }
}

export const archiveProduct = (productId: string) => rpc("archive_product", { p_op_id: uuidv7(), p_product_id: productId });

/** Stock in: adds `qty`, optionally with the unit cost paid and expiry date. */
export const receiveStock = (
  variantId: string,
  qty: number,
  unitCost: number | null,
  locationId: string,
  expiresOn?: string | null,
) =>
  pushOp("receive_stock", {
    variant_id: variantId,
    qty,
    location_id: locationId,
    ...(unitCost !== null ? { unit_cost: unitCost } : {}),
    ...(expiresOn?.trim() ? { expires_on: expiresOn.trim() } : {}),
  });

/** A count: sets the on-hand to what was counted; the server records the difference as a movement. */
export const countStock = (variantId: string, counted: number, reason: "counted" | "damage" | "other", locationId: string) =>
  pushOp<{ delta: number }>("adjust_stock", { variant_id: variantId, counted, reason, location_id: locationId });

/** Tingi / repack pack-to-piece conversions */
export const setTingiLink = (variantId: string, pieceVariantId: string | null, piecesPerPack: number) =>
  pushOp("set_tingi_link", {
    variant_id: variantId,
    piece_variant_id: pieceVariantId,
    pieces_per_pack: piecesPerPack,
  });

export const openPack = (packVariantId: string, packs: number, locationId: string, note?: string) =>
  pushOp("open_pack", {
    id: uuidv7(),
    pack_variant_id: packVariantId,
    packs,
    location_id: locationId,
    ...(note?.trim() ? { note: note.trim() } : {}),
  });

export const voidOpenPack = (conversionId: string, reason?: string) =>
  pushOp("void_open_pack", {
    conversion_id: conversionId,
    ...(reason?.trim() ? { reason: reason.trim() } : {}),
  });

export interface ConversionRow {
  id: string;
  location_id: string;
  pack_variant_id: string;
  piece_variant_id: string;
  packs: number;
  ratio: number;
  pieces: number;
  pack_cost: number | null;
  piece_cost: number | null;
  note: string | null;
  converted_at: string;
  voided_at: string | null;
  void_reason: string | null;
}

export async function fetchRecentConversions(locationId: string): Promise<ConversionRow[]> {
  const { data, error } = await supabase
    .from("conversions")
    .select("*")
    .eq("location_id", locationId)
    .order("converted_at", { ascending: false })
    .limit(20);
  if (error) throw fromRaw(error);
  return (data ?? []).map((r) => ({
    id: r.id,
    location_id: r.location_id,
    pack_variant_id: r.pack_variant_id,
    piece_variant_id: r.piece_variant_id,
    packs: Number(r.packs),
    ratio: Number(r.ratio),
    pieces: Number(r.pieces),
    pack_cost: r.pack_cost != null ? Number(r.pack_cost) : null,
    piece_cost: r.piece_cost != null ? Number(r.piece_cost) : null,
    note: r.note,
    converted_at: r.converted_at,
    voided_at: r.voided_at,
    void_reason: r.void_reason,
  }));
}

/** Expiry tracking */
export const setExpiry = (variantId: string, expiresOn: string | null, locationId: string) =>
  pushOp("set_expiry", {
    variant_id: variantId,
    expires_on: expiresOn ? expiresOn.trim() : null,
    location_id: locationId,
  });

export function getExpiryStatus(expiresOn: string | null): "none" | "expired" | "expiring_soon" | "fresh" {
  if (!expiresOn) return "none";
  const today = new Date().toISOString().slice(0, 10);
  if (expiresOn < today) return "expired";
  const in7Days = new Date(Date.now() + 7 * 86400 * 1000).toISOString().slice(0, 10);
  if (expiresOn <= in7Days) return "expiring_soon";
  return "fresh";
}
