import { uuidv7 } from "@pos/core";
import { ApiError, fetchAllPages, fromRaw, rpc } from "./api.ts";
import { isOnline } from "./network.ts";
import { loadPosIdbCache, savePosIdbCache } from "./pos-idb-cache.ts";
import {
  enqueuePosOp,
  isNetworkFailure,
  loadPosCache,
  pendingOptimisticCustomers,
  savePosCache,
} from "./pos-outbox.ts";
import { supabase } from "./supabase.ts";
import { localReceiptNo, salePayload, type SaleDraft } from "./sale-math.ts";

// ---------------------------------------------------------------------------
// Catalog: what can be sold. Cold bootstrap via `sync_pull_catalog` RPC, then incremental delta sync backed by IndexedDB.
// ---------------------------------------------------------------------------

interface Page<T> {
  rows: T[];
  cursor: unknown;
  has_more: boolean;
}

type CategoryRow = { id: string; parent_id: string | null; name: string; updated_at?: string; deleted_at: string | null };
type ProductCatalogRow = {
  id: string;
  category_id?: string | null;
  name: string;
  unit: string;
  tax_rate: number;
  track_stock: boolean;
  active: boolean;
  photo_path?: string | null;
  updated_at?: string;
  deleted_at: string | null;
};
type VariantCatalogRow = {
  id: string;
  product_id: string;
  name?: string;
  sku: string;
  barcode: string | null;
  is_default: boolean;
  cost: number;
  reorder_point: number;
  active: boolean;
  breaks_into_variant_id?: string | null;
  breaks_into_qty?: number | null;
  updated_at?: string;
  deleted_at: string | null;
};
type PriceCatalogRow = {
  variant_id: string;
  currency: string;
  price: number;
  updated_at?: string;
  deleted_at: string | null;
};

export interface CatalogPull {
  categories?: Page<CategoryRow>;
  products: Page<ProductCatalogRow>;
  product_variants: Page<VariantCatalogRow>;
  variant_prices: Page<PriceCatalogRow>;
}

export interface Sellable {
  variantId: string;
  productId?: string;
  productName?: string;
  variantName?: string;
  isDefault?: boolean;
  name: string;
  sku: string;
  barcode: string | null;
  unit: string;
  price: number;
  cost: number;
  taxRate: number;
  tracked: boolean;
  categoryId?: string | null;
  reorderPoint?: number;
  photoPath?: string | null;
  searchText?: string;
}

export interface SellableProductGroup {
  productId: string;
  productName: string;
  primary: Sellable;
  variants: Sellable[];
}

/** Joins products, their active variants and the price in `currency`; hides inactive, deleted and unpriced items. */
export function toSellables(pull: CatalogPull, currency: string): Sellable[] {
  const products = new Map(pull.products.rows.filter((p) => p.active && !p.deleted_at).map((p) => [p.id, p]));
  const prices = new Map(pull.variant_prices.rows.filter((p) => p.currency === currency && !p.deleted_at).map((p) => [p.variant_id, p.price]));

  const byProduct = new Map<string, Array<{ v: CatalogPull["product_variants"]["rows"][number]; p: NonNullable<ReturnType<typeof products.get>>; price: number }>>();
  for (const v of pull.product_variants.rows) {
    if (!v.active || v.deleted_at) continue;
    const p = products.get(v.product_id);
    const price = prices.get(v.id);
    if (!p || price === undefined) continue;
    const arr = byProduct.get(p.id) ?? [];
    arr.push({ v, p, price });
    byProduct.set(p.id, arr);
  }

  const out: Sellable[] = [];
  for (const items of byProduct.values()) {
    const multi = items.length > 1;
    for (const { v, p, price } of items) {
      const variantName = (v.name ?? "Default").trim() || "Default";
      const showVariantLabel = multi || variantName !== "Default";
      const displayName = showVariantLabel ? `${p.name} (${variantName})` : p.name;
      out.push({
        variantId: v.id,
        productId: p.id,
        productName: p.name,
        variantName,
        isDefault: v.is_default,
        name: displayName,
        sku: v.sku,
        barcode: v.barcode,
        unit: p.unit,
        price,
        cost: v.cost,
        taxRate: Number(p.tax_rate),
        tracked: p.track_stock,
        ...(p.category_id !== undefined ? { categoryId: p.category_id } : {}),
        ...(v.reorder_point !== undefined ? { reorderPoint: Number(v.reorder_point) } : {}),
        ...(p.photo_path ? { photoPath: p.photo_path } : {}),
        searchText: `${displayName} ${p.name} ${variantName} ${v.sku} ${v.barcode ?? ""}`.toLowerCase(),
      });
    }
  }
  return out.sort((a, b) => {
    const pCmp = (a.productName ?? a.name).localeCompare(b.productName ?? b.name);
    if (pCmp !== 0) return pCmp;
    const dCmp = Number(b.isDefault ?? false) - Number(a.isDefault ?? false);
    if (dCmp !== 0) return dCmp;
    return (a.variantName ?? a.name).localeCompare(b.variantName ?? b.name);
  });
}

/** Groups flat `Sellable` variants into per-product tiles for the Sell grid. */
export function groupSellableProducts(sellables: ReadonlyArray<Sellable>): SellableProductGroup[] {
  const byProduct = new Map<string, Sellable[]>();
  for (const s of sellables) {
    const pid = s.productId ?? s.variantId;
    const list = byProduct.get(pid);
    if (list) list.push(s);
    else byProduct.set(pid, [s]);
  }
  const groups: SellableProductGroup[] = [];
  for (const [productId, variants] of byProduct) {
    const primary = variants.find((v) => v.isDefault) ?? variants[0]!;
    groups.push({
      productId,
      productName: primary.productName ?? primary.name,
      primary,
      variants,
    });
  }
  return groups;
}

/**
 * Filters a catalog snapshot by category/search across ALL items before grouping & slicing to `maxGroups`,
 * so multi-variant products are never truncated mid-group at 2,000+ SKUs.
 */
export function filterAndGroupSellables(
  pool: ReadonlyArray<Sellable>,
  opts: { query?: string; categoryId?: string | null; maxGroups?: number } = {},
): SellableProductGroup[] {
  const maxGroups = opts.maxGroups ?? 80;
  const q = (opts.query ?? "").trim().toLowerCase();
  const cat = opts.categoryId ?? null;

  let filtered: ReadonlyArray<Sellable> = pool;
  if (cat) {
    filtered = filtered.filter((s) => s.categoryId === cat);
  }
  if (q) {
    filtered = filtered.filter((s) => {
      if (s.searchText) return s.searchText.includes(q);
      return (
        s.name.toLowerCase().includes(q) ||
        (s.productName?.toLowerCase().includes(q) ?? false) ||
        (s.variantName?.toLowerCase().includes(q) ?? false) ||
        s.sku.toLowerCase().includes(q) ||
        s.barcode?.toLowerCase() === q
      );
    });
  }
  return groupSellableProducts(filtered).slice(0, maxGroups);
}

const CATALOG_IDB_SLOT = "catalog:snapshot:v1";

interface CatalogSnapshot {
  lastSyncedAt: string;
  categories: Record<string, CategoryRow>;
  products: Record<string, ProductCatalogRow>;
  product_variants: Record<string, VariantCatalogRow>;
  variant_prices: Record<string, PriceCatalogRow>;
}

interface SyncPullCatalogResponse {
  server_time: string;
  categories: Page<CategoryRow>;
  products: Page<ProductCatalogRow>;
  product_variants: Page<VariantCatalogRow>;
  variant_prices: Page<PriceCatalogRow>;
}

let inflightCatalogPull: Promise<CatalogPull> | null = null;

function priceKey(row: { variant_id: string; currency: string }): string {
  return `${row.variant_id}|${row.currency}`;
}

function emptyCatalogSnapshot(lastSyncedAt: string): CatalogSnapshot {
  return {
    lastSyncedAt,
    categories: {},
    products: {},
    product_variants: {},
    variant_prices: {},
  };
}

function newerIsoTimestamp(current: string, candidate?: string | null): string {
  if (!candidate) return current;
  const candMs = Date.parse(candidate);
  if (Number.isNaN(candMs)) return current;
  const curMs = current ? Date.parse(current) : NaN;
  if (Number.isNaN(curMs) || candMs > curMs) {
    return new Date(candMs).toISOString();
  }
  return current;
}

function mergeRows<T extends { deleted_at: string | null; updated_at?: string }>(
  target: Record<string, T>,
  rows: ReadonlyArray<T>,
  keyOf: (row: T) => string,
  maxTs: { value: string },
): number {
  let changed = 0;
  for (const row of rows) {
    changed++;
    const key = keyOf(row);
    if (row.deleted_at) {
      delete target[key];
    } else {
      target[key] = row;
    }
    maxTs.value = newerIsoTimestamp(maxTs.value, row.updated_at);
  }
  return changed;
}

function mergeSnapshotRows(
  snap: CatalogSnapshot,
  delta: {
    categories: ReadonlyArray<CategoryRow>;
    products: ReadonlyArray<ProductCatalogRow>;
    product_variants: ReadonlyArray<VariantCatalogRow>;
    variant_prices: ReadonlyArray<PriceCatalogRow>;
  },
): { changed: number; maxUpdatedAt: string } {
  const maxTs = { value: snap.lastSyncedAt };
  const changed =
    mergeRows(snap.categories, delta.categories, (r) => r.id, maxTs) +
    mergeRows(snap.products, delta.products, (r) => r.id, maxTs) +
    mergeRows(snap.product_variants, delta.product_variants, (r) => r.id, maxTs) +
    mergeRows(snap.variant_prices, delta.variant_prices, priceKey, maxTs);
  return { changed, maxUpdatedAt: maxTs.value };
}

function snapshotToCatalogPull(snap: CatalogSnapshot): CatalogPull {
  return {
    categories: { rows: Object.values(snap.categories), cursor: null, has_more: false },
    products: { rows: Object.values(snap.products), cursor: null, has_more: false },
    product_variants: { rows: Object.values(snap.product_variants), cursor: null, has_more: false },
    variant_prices: { rows: Object.values(snap.variant_prices), cursor: null, has_more: false },
  };
}

async function fetchDeltaSince(sinceIso: string) {
  const [categories, products, product_variants, variant_prices] = await Promise.all([
    fetchAllPages<CategoryRow>((from, to) =>
      supabase
        .from("categories")
        .select("id, parent_id, name, updated_at, deleted_at")
        .gte("updated_at", sinceIso)
        .order("updated_at")
        .order("id")
        .range(from, to),
    ),
    fetchAllPages<ProductCatalogRow>((from, to) =>
      supabase
        .from("products")
        .select("id, category_id, name, unit, tax_rate, track_stock, active, photo_path, updated_at, deleted_at")
        .gte("updated_at", sinceIso)
        .order("updated_at")
        .order("id")
        .range(from, to),
    ),
    fetchAllPages<VariantCatalogRow>((from, to) =>
      supabase
        .from("product_variants")
        .select(
          "id, product_id, name, sku, barcode, is_default, cost, reorder_point, active, breaks_into_variant_id, breaks_into_qty, updated_at, deleted_at",
        )
        .gte("updated_at", sinceIso)
        .order("updated_at")
        .order("id")
        .range(from, to),
    ),
    fetchAllPages<PriceCatalogRow>((from, to) =>
      supabase
        .from("variant_prices")
        .select("variant_id, currency, price, updated_at, deleted_at")
        .gte("updated_at", sinceIso)
        .order("updated_at")
        .order("variant_id")
        .order("currency")
        .range(from, to),
    ),
  ]);
  return { categories, products, product_variants, variant_prices };
}

async function coldPullCatalogSnapshot(): Promise<CatalogSnapshot> {
  const snap = emptyCatalogSnapshot("");
  const cursors: Record<string, unknown> = {};
  let serverTime = "";

  for (let page = 0; page < 500; page++) {
    const res = await rpc<SyncPullCatalogResponse>("sync_pull_catalog", {
      p_cursors: cursors,
      p_limit: 1000,
    });
    serverTime = res.server_time;
    mergeSnapshotRows(snap, {
      categories: res.categories.rows,
      products: res.products.rows,
      product_variants: res.product_variants.rows,
      variant_prices: res.variant_prices.rows,
    });
    if (res.categories.cursor) cursors.categories = res.categories.cursor;
    if (res.products.cursor) cursors.products = res.products.cursor;
    if (res.product_variants.cursor) cursors.product_variants = res.product_variants.cursor;
    if (res.variant_prices.cursor) cursors.variant_prices = res.variant_prices.cursor;
    if (
      !res.categories.has_more &&
      !res.products.has_more &&
      !res.product_variants.has_more &&
      !res.variant_prices.has_more
    ) {
      break;
    }
  }

  // Catch any writes inside `sync_pull_catalog`'s 5s MVCC holdback window so new/edited items show immediately.
  const baseMs = Date.parse(serverTime);
  const cutoffIso = Number.isNaN(baseMs)
    ? new Date(Date.now() - 10_000).toISOString()
    : new Date(baseMs - 6000).toISOString();
  snap.lastSyncedAt = Number.isNaN(baseMs) ? new Date().toISOString() : new Date(baseMs).toISOString();
  const recent = await fetchDeltaSince(cutoffIso);
  const { maxUpdatedAt } = mergeSnapshotRows(snap, recent);
  snap.lastSyncedAt = newerIsoTimestamp(snap.lastSyncedAt, maxUpdatedAt);
  await savePosIdbCache(CATALOG_IDB_SLOT, snap);
  return snap;
}

/**
 * Current catalog for web views (RLS-scoped), backed by IndexedDB + incremental delta sync.
 */
export function pullCatalog(): Promise<CatalogPull> {
  if (inflightCatalogPull) return inflightCatalogPull;
  inflightCatalogPull = (async () => {
    const existing = await loadPosIdbCache<CatalogSnapshot>(CATALOG_IDB_SLOT);
    const parsedSince = existing ? Date.parse(existing.lastSyncedAt) : NaN;
    if (!existing || Number.isNaN(parsedSince)) {
      const fresh = await coldPullCatalogSnapshot();
      return snapshotToCatalogPull(fresh);
    }

    try {
      const overlapIso = new Date(parsedSince - 6000).toISOString();
      const delta = await fetchDeltaSince(overlapIso);
      const { changed, maxUpdatedAt } = mergeSnapshotRows(existing, delta);
      if (changed > 0) {
        existing.lastSyncedAt = newerIsoTimestamp(existing.lastSyncedAt, maxUpdatedAt);
        await savePosIdbCache(CATALOG_IDB_SLOT, existing);
      }
      return snapshotToCatalogPull(existing);
    } catch (err) {
      if (isNetworkFailure(err)) {
        return snapshotToCatalogPull(existing);
      }
      throw err;
    }
  })().finally(() => {
    inflightCatalogPull = null;
  });
  return inflightCatalogPull;
}

export async function fetchSellables(currency: string): Promise<Sellable[]> {
  return toSellables(await pullCatalog(), currency);
}

// ---------------------------------------------------------------------------
// This browser as a device (F-02): a stable id, a short code for the provisional receipt number.
// ---------------------------------------------------------------------------

const DEVICE_KEY = "pos.deviceId";
const DEVICE_NAME_KEY = "pos.deviceName";
const CODE_KEY = "pos.deviceCode";
const SEQ_KEY = "pos.receiptSeq";
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function store(): Storage | null {
  try {
    return localStorage;
  } catch {
    return null;
  }
}

export function getStoredWebDeviceName(): string | null {
  const raw = store()?.getItem(DEVICE_NAME_KEY)?.trim();
  return raw ? raw : null;
}

export function setStoredWebDeviceName(name: string | null): void {
  const s = store();
  if (!s) return;
  const trimmed = name?.trim() ?? "";
  if (trimmed) {
    s.setItem(DEVICE_NAME_KEY, trimmed);
  } else {
    s.removeItem(DEVICE_NAME_KEY);
  }
}

export function webDevice(): { id: string; code: string } {
  const s = store();
  let id = s?.getItem(DEVICE_KEY) ?? null;
  let code = s?.getItem(CODE_KEY) ?? null;
  if (!id) {
    id = uuidv7();
    s?.setItem(DEVICE_KEY, id);
  }
  if (!code) {
    const r = crypto.getRandomValues(new Uint8Array(3));
    code = "W" + Array.from(r, (b) => CODE_CHARS[b % CODE_CHARS.length]).join("").slice(0, 2);
    s?.setItem(CODE_KEY, code);
  }
  return { id, code };
}

/** Best effort: the server also registers an unknown device on the first sale, so a failure is harmless. */
export async function registerWebDevice(): Promise<void> {
  try {
    await rpc("register_device", {
      p_id: webDevice().id,
      p_name: getStoredWebDeviceName(),
      p_platform: "web",
    });
  } catch {
    /* the sale registers it on the spot */
  }
}

/** Next provisional receipt number for `day` (YYYY-MM-DD in the business timezone); the counter restarts each day. */
export function nextLocalNo(day: string): string {
  const s = store();
  const key = `${SEQ_KEY}.${day}`;
  const n = (Number(s?.getItem(key)) || 0) + 1;
  s?.setItem(key, String(n));
  return localReceiptNo(webDevice().code, day, n);
}

// ---------------------------------------------------------------------------
// Sending a sale: `sync_push` with one `record_sale` op. Online only; the op id makes a retry safe.
// ---------------------------------------------------------------------------

/** Sends one op through `sync_push`. Throws ApiError(hint) when the server refuses it; the caller shows `errors:<hint>`. */
export async function pushOp<R = Record<string, unknown>>(kind: string, payload: Record<string, unknown>, opId: string = uuidv7()): Promise<R> {
  const out = await rpc<Array<{ op_id: string; status: "ok" | "rejected" | "error"; hint?: string; code?: string; result?: R }>>("sync_push", {
    p_ops: [{ op_id: opId, kind, payload }],
  });
  const r = out[0];
  if (r?.status === "ok" && r.result) return r.result;
  if (r?.status === "error") throw new ApiError("temporary", `temporary server error ${r.code ?? ""}`);
  throw new ApiError(r?.hint ?? "rejected", `${kind} refused: ${r?.hint ?? "unknown"}`);
}

export interface SoldReceipt {
  saleId: string;
  localNo: string;
  saleNo: string | null;
  queuedOffline?: boolean;
}

/** Sends the sale immediately when online, or queues an idempotent `record_sale` op when offline/unreachable. */
export async function submitSale(draft: SaleDraft, opId: string = uuidv7()): Promise<SoldReceipt> {
  const payload = salePayload(draft);
  if (!isOnline()) {
    enqueuePosOp({ opId, kind: "record_sale", payload, locationId: draft.locationId });
    return { saleId: draft.id, localNo: draft.localNo, saleNo: null, queuedOffline: true };
  }
  try {
    const r = await pushOp<{ sale_id: string; local_no: string; sale_no: string | null }>("record_sale", payload, opId);
    return { saleId: r.sale_id, localNo: r.local_no, saleNo: r.sale_no };
  } catch (err) {
    if (isNetworkFailure(err)) {
      enqueuePosOp({ opId, kind: "record_sale", payload, locationId: draft.locationId });
      return { saleId: draft.id, localNo: draft.localNo, saleNo: null, queuedOffline: true };
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Customers (utang) and past sales
// ---------------------------------------------------------------------------

export interface Customer {
  id: string;
  name: string;
  phone: string | null;
}

function mergeOptimisticCustomers(base: Customer[]): Customer[] {
  const byId = new Map(base.map((c) => [c.id, c]));
  for (const pending of pendingOptimisticCustomers()) {
    if (!byId.has(pending.id)) byId.set(pending.id, pending);
  }
  return Array.from(byId.values()).sort((a, b) => a.name.localeCompare(b.name));
}

export async function fetchCustomers(): Promise<Customer[]> {
  try {
    const { data, error } = await supabase.from("customers").select("id, name, phone").is("deleted_at", null).order("name").limit(1000);
    if (error) throw fromRaw(error);
    savePosCache("customers", data);
    return mergeOptimisticCustomers(data);
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<Customer[]>("customers");
      if (cached) return mergeOptimisticCustomers(cached);
      const pending = pendingOptimisticCustomers();
      if (pending.length > 0) return mergeOptimisticCustomers([]);
    }
    throw err;
  }
}

/** Creates a customer (the id is made here, like the phone does) and queues offline if needed. */
export async function createCustomer(name: string, phone: string): Promise<Customer> {
  const id = uuidv7();
  const opId = uuidv7();
  const trimmedName = name.trim();
  const trimmedPhone = phone.trim();
  const payload: Record<string, unknown> = {
    id,
    name: trimmedName,
    ...(trimmedPhone ? { phone: trimmedPhone } : {}),
  };
  if (!isOnline()) {
    enqueuePosOp({ opId, kind: "upsert_customer", payload });
    return { id, name: trimmedName, phone: trimmedPhone || null };
  }
  try {
    await pushOp("upsert_customer", payload, opId);
    return { id, name: trimmedName, phone: trimmedPhone || null };
  } catch (err) {
    if (isNetworkFailure(err)) {
      enqueuePosOp({ opId, kind: "upsert_customer", payload });
      return { id, name: trimmedName, phone: trimmedPhone || null };
    }
    throw err;
  }
}

export interface SaleRow {
  id: string;
  sale_no: string | null;
  local_no: string;
  status: "completed" | "voided";
  subtotal: number;
  discount: number;
  total: number;
  sold_at: string;
  customer_id: string | null;
  location_id: string;
  customer_name?: string | null;
  payment_methods?: string[];
  refunded_total?: number;
}

export interface SalesListFilter {
  from?: string;
  to?: string;
  status?: "all" | "completed" | "voided";
  limit?: number;
}

export interface ClientSalesFilter {
  search?: string;
  from?: string;
  to?: string;
  status?: "all" | "completed" | "voided";
  method?: "all" | "cash" | "ewallet" | "card" | "utang";
  timezone?: string;
}

/** Pure client-side receipt filter across receipt no., provisional local no., customer, tender method, status, and business-timezone date. */
export function filterSaleRows(rows: readonly SaleRow[], filter: ClientSalesFilter): SaleRow[] {
  const q = (filter.search ?? "").trim().toLowerCase();
  const status = filter.status ?? "all";
  const method = filter.method ?? "all";
  const from = filter.from ?? "";
  const to = filter.to ?? "";
  const dayFmt =
    from || to
      ? new Intl.DateTimeFormat("en-CA", { timeZone: filter.timezone || "UTC" })
      : null;

  return rows.filter((s) => {
    if (status !== "all" && s.status !== status) return false;
    if (dayFmt) {
      const localDay = dayFmt.format(new Date(s.sold_at));
      if (from && localDay < from) return false;
      if (to && localDay > to) return false;
    }
    if (method !== "all" && !(s.payment_methods ?? []).includes(method)) {
      return false;
    }
    if (q) {
      const receipt = (s.sale_no ?? s.local_no).toLowerCase();
      const localNo = s.local_no.toLowerCase();
      const cust = (s.customer_name ?? "").toLowerCase();
      if (!receipt.includes(q) && !localNo.includes(q) && !cust.includes(q)) {
        return false;
      }
    }
    return true;
  });
}

export interface SaleReturnRecord {
  id: string;
  refund_method: "cash" | "utang" | "ewallet" | "card";
  refund_total: number;
  reason: string | null;
  returned_at: string;
}

export interface SaleDetail {
  sale: SaleRow;
  customerName: string | null;
  items: Array<{
    id: string;
    variant_id: string;
    product_name: string;
    qty: number;
    returned_qty: number;
    unit_price: number;
    line_total: number;
  }>;
  payments: Array<{ method: string; amount: number; tendered: number | null; wallet: string | null; reference?: string | null }>;
  returns: SaleReturnRecord[];
}

const SALE_COLS = "id, sale_no, local_no, status, subtotal, discount, total, sold_at, customer_id, location_id";

export async function fetchRecentSales(
  locationId: string,
  limitOrFilter: number | SalesListFilter = 200,
): Promise<SaleRow[]> {
  const opts: SalesListFilter =
    typeof limitOrFilter === "number" ? { limit: limitOrFilter } : limitOrFilter;
  const limit = opts.limit ?? 200;
  const isDefaultQuery = !opts.from && !opts.to && (!opts.status || opts.status === "all");
  const cacheKey = `sales:${locationId}`;

  try {
    let query = supabase
      .from("sales")
      .select(SALE_COLS)
      .eq("location_id", locationId)
      .order("sold_at", { ascending: false })
      .limit(limit);

    if (opts.status && opts.status !== "all") {
      query = query.eq("status", opts.status);
    }
    if (opts.from) {
      const fromBuffer = new Date(Date.parse(`${opts.from}T00:00:00Z`) - 86_400_000).toISOString();
      query = query.gte("sold_at", fromBuffer);
    }
    if (opts.to) {
      const toBuffer = new Date(Date.parse(`${opts.to}T23:59:59Z`) + 86_400_000).toISOString();
      query = query.lte("sold_at", toBuffer);
    }

    const { data, error } = await query;
    if (error) throw fromRaw(error);
    const sales = (data ?? []) as SaleRow[];
    if (sales.length === 0) {
      if (isDefaultQuery) savePosCache(cacheKey, []);
      return [];
    }

    const saleIds = sales.map((s) => s.id);
    const customerIds = Array.from(
      new Set(sales.map((s) => s.customer_id).filter((id): id is string => Boolean(id))),
    );

    const [customersRes, paymentsRes, returnsRes] = await Promise.all([
      customerIds.length > 0
        ? supabase.from("customers").select("id, name").in("id", customerIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }>, error: null }),
      supabase.from("payments").select("sale_id, method").in("sale_id", saleIds),
      supabase.from("sale_returns").select("sale_id, refund_total").in("sale_id", saleIds),
    ]);

    const customerMap = new Map<string, string>();
    for (const c of (customersRes.data ?? []) as Array<{ id: string; name: string }>) {
      customerMap.set(c.id, c.name);
    }

    const methodsBySale = new Map<string, Set<string>>();
    for (const p of (paymentsRes.data ?? []) as Array<{ sale_id: string; method: string }>) {
      let set = methodsBySale.get(p.sale_id);
      if (!set) {
        set = new Set<string>();
        methodsBySale.set(p.sale_id, set);
      }
      set.add(p.method);
    }

    const refundBySale = new Map<string, number>();
    for (const r of (returnsRes.data ?? []) as Array<{ sale_id: string; refund_total: number }>) {
      refundBySale.set(r.sale_id, (refundBySale.get(r.sale_id) ?? 0) + Number(r.refund_total));
    }

    const enriched: SaleRow[] = sales.map((s) => ({
      ...s,
      customer_name: s.customer_id ? (customerMap.get(s.customer_id) ?? null) : null,
      payment_methods: Array.from(methodsBySale.get(s.id) ?? []),
      refunded_total: refundBySale.get(s.id) ?? 0,
    }));

    if (isDefaultQuery) savePosCache(cacheKey, enriched);
    return enriched;
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<SaleRow[]>(cacheKey);
      if (cached) {
        return opts.status && opts.status !== "all"
          ? cached.filter((s) => s.status === opts.status)
          : cached;
      }
    }
    throw err;
  }
}

export async function fetchSaleDetail(saleId: string): Promise<SaleDetail> {
  const [s, i, p, r, ri] = await Promise.all([
    supabase.from("sales").select(SALE_COLS).eq("id", saleId).single(),
    supabase.from("sale_items").select("id, variant_id, product_name, qty, unit_price, line_total").eq("sale_id", saleId).order("product_name"),
    supabase.from("payments").select("method, amount, tendered, wallet, reference").eq("sale_id", saleId).order("amount", { ascending: false }),
    supabase.from("sale_returns").select("id, refund_method, refund_total, reason, returned_at").eq("sale_id", saleId).order("returned_at", { ascending: false }),
    supabase.from("sale_return_items").select("sale_item_id, qty").eq("sale_id", saleId),
  ]);
  if (s.error) throw fromRaw(s.error);
  if (i.error) throw fromRaw(i.error);
  if (p.error) throw fromRaw(p.error);
  const sale = s.data as SaleRow;
  let customerName: string | null = null;
  if (sale.customer_id) {
    const c = await supabase.from("customers").select("name").eq("id", sale.customer_id).maybeSingle();
    customerName = c.data?.name ?? null;
  }
  const returnedByItem = new Map<string, number>();
  for (const row of (ri.data ?? []) as Array<{ sale_item_id: string; qty: number }>) {
    returnedByItem.set(row.sale_item_id, (returnedByItem.get(row.sale_item_id) ?? 0) + Number(row.qty));
  }
  const rawItems = (i.data ?? []) as Array<{
    id: string;
    variant_id: string;
    product_name: string;
    qty: number;
    unit_price: number;
    line_total: number;
  }>;
  return {
    sale,
    customerName,
    items: rawItems.map((item) => ({
      ...item,
      qty: Number(item.qty),
      returned_qty: returnedByItem.get(item.id) ?? 0,
    })),
    payments: p.data as SaleDetail["payments"],
    returns: (r.data ?? []) as SaleReturnRecord[],
  };
}

/** Cancels a sale: stock goes back and any utang charge is reversed. The server checks the caller may do it. */
export const voidSale = (
  saleId: string,
  reason: string,
  approvalId?: string,
  offlineApproval?: {
    approver_id: string;
    action: string;
    ref_id: string;
    approved_at: string;
    proof: string;
  },
) =>
  pushOp("void_sale", {
    sale_id: saleId,
    ...(reason.trim() ? { reason: reason.trim() } : {}),
    ...(approvalId ? { approval_id: approvalId } : {}),
    ...(offlineApproval ? { offline_approval: offlineApproval } : {}),
  });

/** Returns specific items from a completed receipt back into stock with pro-rata refund. */
export const returnSaleItems = (params: {
  saleId: string;
  refundMethod: "cash" | "utang" | "ewallet" | "card";
  items: Array<{ variant_id: string; qty: number }>;
  reason?: string;
  approvalId?: string;
  offlineApproval?: {
    approver_id: string;
    action: string;
    ref_id: string;
    approved_at: string;
    proof: string;
  };
}) =>
  pushOp<{
    return_id: string;
    sale_id: string;
    refund_total: number;
    refund_method: string;
    applied_at: string;
  }>("return_sale_items", {
    sale_id: params.saleId,
    refund_method: params.refundMethod,
    items: params.items,
    ...(params.reason?.trim() ? { reason: params.reason.trim() } : {}),
    ...(params.approvalId ? { approval_id: params.approvalId } : {}),
    ...(params.offlineApproval ? { offline_approval: params.offlineApproval } : {}),
  });

