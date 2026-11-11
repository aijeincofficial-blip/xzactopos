import { uuidv7 } from "@pos/core";
import { ApiError, fromRaw, rpc } from "./api.ts";
import { supabase } from "./supabase.ts";
import { localReceiptNo, salePayload, type SaleDraft } from "./sale-math.ts";

// ---------------------------------------------------------------------------
// Catalog: what can be sold. One RPC (`sync_pull_catalog`, RLS-scoped), paged until every table is complete.
// ---------------------------------------------------------------------------

interface Page<T> {
  rows: T[];
  cursor: unknown;
  has_more: boolean;
}

export interface CatalogPull {
  categories?: Page<{ id: string; parent_id: string | null; name: string; deleted_at: string | null }>;
  products: Page<{ id: string; category_id?: string | null; name: string; unit: string; tax_rate: number; track_stock: boolean; active: boolean; deleted_at: string | null }>;
  product_variants: Page<{ id: string; product_id: string; sku: string; barcode: string | null; is_default: boolean; cost: number; reorder_point: number; active: boolean; breaks_into_variant_id?: string | null; breaks_into_qty?: number | null; deleted_at: string | null }>;
  variant_prices: Page<{ variant_id: string; currency: string; price: number; deleted_at: string | null }>;
}

export interface Sellable {
  variantId: string;
  name: string;
  sku: string;
  barcode: string | null;
  unit: string;
  price: number;
  cost: number;
  taxRate: number;
  tracked: boolean;
}

/** Joins products, their default variant and the price in `currency`; hides inactive, deleted and unpriced items. */
export function toSellables(pull: CatalogPull, currency: string): Sellable[] {
  const products = new Map(pull.products.rows.filter((p) => p.active && !p.deleted_at).map((p) => [p.id, p]));
  const prices = new Map(pull.variant_prices.rows.filter((p) => p.currency === currency && !p.deleted_at).map((p) => [p.variant_id, p.price]));
  const out: Sellable[] = [];
  for (const v of pull.product_variants.rows) {
    if (!v.active || v.deleted_at || !v.is_default) continue; // Solo sells the default variant only
    const p = products.get(v.product_id);
    const price = prices.get(v.id);
    if (!p || price === undefined) continue;
    out.push({
      variantId: v.id,
      name: p.name,
      sku: v.sku,
      barcode: v.barcode,
      unit: p.unit,
      price,
      cost: v.cost,
      taxRate: Number(p.tax_rate),
      tracked: p.track_stock,
    });
  }
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

/** Every product, default variant and price the caller can see, paged until each table is complete. */
export async function pullCatalog(): Promise<CatalogPull> {
  const acc: CatalogPull = {
    products: { rows: [], cursor: null, has_more: true },
    product_variants: { rows: [], cursor: null, has_more: true },
    variant_prices: { rows: [], cursor: null, has_more: true },
  };
  const tables = ["products", "product_variants", "variant_prices"] as const;
  for (let guard = 0; guard < 200 && tables.some((t) => acc[t].has_more); guard++) {
    const cursors = Object.fromEntries(tables.filter((t) => acc[t].cursor).map((t) => [t, acc[t].cursor]));
    const page = await rpc<Record<(typeof tables)[number], Page<never>>>("sync_pull_catalog", { p_cursors: cursors, p_limit: 1000 });
    for (const t of tables) {
      if (!acc[t].has_more) continue;
      (acc[t].rows as unknown[]).push(...page[t].rows);
      acc[t].cursor = page[t].cursor;
      acc[t].has_more = page[t].has_more;
    }
  }
  return acc;
}

export async function fetchSellables(currency: string): Promise<Sellable[]> {
  return toSellables(await pullCatalog(), currency);
}

// ---------------------------------------------------------------------------
// This browser as a device (F-02): a stable id, a short code for the provisional receipt number.
// ---------------------------------------------------------------------------

const DEVICE_KEY = "pos.deviceId";
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
    await rpc("register_device", { p_id: webDevice().id, p_name: "Web browser", p_platform: "web" });
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
}

/** Sends the sale once (online only; the op id makes a retry safe). */
export async function submitSale(draft: SaleDraft, opId: string = uuidv7()): Promise<SoldReceipt> {
  const r = await pushOp<{ sale_id: string; local_no: string; sale_no: string | null }>("record_sale", salePayload(draft), opId);
  return { saleId: r.sale_id, localNo: r.local_no, saleNo: r.sale_no };
}

// ---------------------------------------------------------------------------
// Customers (utang) and past sales
// ---------------------------------------------------------------------------

export interface Customer {
  id: string;
  name: string;
  phone: string | null;
}

export async function fetchCustomers(): Promise<Customer[]> {
  const { data, error } = await supabase.from("customers").select("id, name, phone").is("deleted_at", null).order("name").limit(1000);
  if (error) throw fromRaw(error);
  return data;
}

/** Creates a customer (the id is made here, like the phone does) and returns it. */
export async function createCustomer(name: string, phone: string): Promise<Customer> {
  const id = uuidv7();
  await pushOp("upsert_customer", { id, name: name.trim(), ...(phone.trim() ? { phone: phone.trim() } : {}) });
  return { id, name: name.trim(), phone: phone.trim() || null };
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

export async function fetchRecentSales(locationId: string, limit = 50): Promise<SaleRow[]> {
  const { data, error } = await supabase.from("sales").select(SALE_COLS).eq("location_id", locationId).order("sold_at", { ascending: false }).limit(limit);
  if (error) throw fromRaw(error);
  return data as SaleRow[];
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

