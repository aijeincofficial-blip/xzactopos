import { uuidv7 } from "@pos/core";
import { ApiError, rpc } from "./api.ts";
import { localReceiptNo, salePayload, type SaleDraft } from "./sale-math.ts";

// ---------------------------------------------------------------------------
// Catalog: what can be sold. One RPC (`sync_pull_catalog`, RLS-scoped), paged until every table is complete.
// ---------------------------------------------------------------------------

interface Page<T> {
  rows: T[];
  cursor: unknown;
  has_more: boolean;
}

interface CatalogPull {
  products: Page<{ id: string; name: string; unit: string; tax_rate: number; track_stock: boolean; active: boolean; deleted_at: string | null }>;
  product_variants: Page<{ id: string; product_id: string; sku: string; barcode: string | null; is_default: boolean; cost: number; active: boolean; deleted_at: string | null }>;
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

export async function fetchSellables(currency: string): Promise<Sellable[]> {
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
  return toSellables(acc, currency);
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

interface PushResult {
  op_id: string;
  status: "ok" | "rejected" | "error";
  hint?: string;
  code?: string;
  result?: { sale_id: string; local_no: string; sale_no: string | null };
}

export interface SoldReceipt {
  saleId: string;
  localNo: string;
  saleNo: string | null;
}

/** Sends the sale once. Throws ApiError(hint) when the server refuses it; the caller shows `errors:<hint>`. */
export async function submitSale(draft: SaleDraft, opId: string = uuidv7()): Promise<SoldReceipt> {
  const out = await rpc<PushResult[]>("sync_push", { p_ops: [{ op_id: opId, kind: "record_sale", payload: salePayload(draft) }] });
  const r = out[0];
  if (r?.status === "ok" && r.result) {
    return { saleId: r.result.sale_id, localNo: r.result.local_no, saleNo: r.result.sale_no };
  }
  if (r?.status === "error") throw new ApiError("temporary", `temporary server error ${r.code ?? ""}`);
  throw new ApiError(r?.hint ?? "rejected", `sale refused: ${r?.hint ?? "unknown"}`);
}
