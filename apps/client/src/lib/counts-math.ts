/** Pure rules for the stock-count screen: which rows to show, what a typed quantity means, what closing will change. */
import { parseQty } from "./product-math.ts";

export type CountStatus = "open" | "closed" | "cancelled";

/** A spot is a product, in a bin when the warehouse uses bins. */
export function rowKey(variantId: string, binId: string | null): string {
  return `${variantId}:${binId ?? "-"}`;
}

const round3 = (n: number) => Math.round(n * 1000) / 1000;

/** What closing applies for a line: counted minus the system quantity at the moment it was counted. */
export function variance(counted: number, systemAtCount: number): number {
  return round3(counted - systemAtCount);
}

export interface SystemRow {
  variantId: string;
  binId: string | null;
  qty: number;
}

export interface SavedLine {
  variantId: string;
  binId: string | null;
  /** The system quantity when this line was counted (the baseline the correction is measured from). */
  qtySystem: number;
  qtyCounted: number;
  autoZero: boolean;
}

export interface CountRow {
  key: string;
  variantId: string;
  binId: string | null;
  /** What the system holds right now (0 for a product it does not hold). */
  systemNow: number;
  saved: SavedLine | null;
}

/**
 * The rows of an open count: every spot the system holds stock in, every line already saved (including found stock the
 * system did not hold), and spots the user added. A one-bin count only has that bin.
 */
export function mergeCountRows(
  system: SystemRow[],
  saved: SavedLine[],
  added: Array<{ variantId: string; binId: string | null }>,
  scopeBinId: string | null,
): CountRow[] {
  const rows = new Map<string, CountRow>();
  const inScope = (binId: string | null) => scopeBinId === null || binId === scopeBinId;
  const touch = (variantId: string, binId: string | null): CountRow | null => {
    if (!inScope(binId)) return null;
    const key = rowKey(variantId, binId);
    let r = rows.get(key);
    if (!r) {
      r = { key, variantId, binId, systemNow: 0, saved: null };
      rows.set(key, r);
    }
    return r;
  };
  for (const s of system) {
    const r = touch(s.variantId, s.binId);
    if (r) r.systemNow = s.qty;
  }
  for (const l of saved) {
    const r = touch(l.variantId, l.binId);
    if (r) r.saved = l;
  }
  for (const a of added) touch(a.variantId, a.binId);
  return [...rows.values()];
}

export type CountLineError = "qty_invalid" | "bin_required";

export interface CountItemPayload {
  variant_id: string;
  qty_counted: number;
  bin_id?: string;
}

export interface CountItemsResult {
  ok: boolean;
  items: CountItemPayload[];
  rowErrors: Array<CountLineError | null>;
  empty: boolean;
}

/** Rows the user typed a quantity into. Blank rows are left alone; 0 is a real count (the shelf is empty). */
export function buildCountItems(
  rows: Array<{ variantId: string; binId: string | null; qtyText: string }>,
  binsEnabled: boolean,
): CountItemsResult {
  const items: CountItemPayload[] = [];
  const rowErrors: Array<CountLineError | null> = [];
  let any = false;
  for (const r of rows) {
    if (r.qtyText.trim() === "") {
      rowErrors.push(null);
      continue;
    }
    any = true;
    const qty = parseQty(r.qtyText, { allowZero: true });
    if (qty === null) {
      rowErrors.push("qty_invalid");
      continue;
    }
    if (binsEnabled && r.binId === null) {
      rowErrors.push("bin_required");
      continue;
    }
    rowErrors.push(null);
    items.push(binsEnabled && r.binId !== null ? { variant_id: r.variantId, qty_counted: qty, bin_id: r.binId } : { variant_id: r.variantId, qty_counted: qty });
  }
  const ok = any && rowErrors.every((e) => e === null);
  return { ok, items: ok ? items : [], rowErrors, empty: !any };
}

export interface VarianceSummary {
  lines: number;
  /** Lines whose counted quantity differs from the system quantity: these become movements. */
  corrections: number;
  shortage: number;
  surplus: number;
  net: number;
}

export function summarizeVariance(lines: Array<{ qtySystem: number; qtyCounted: number }>): VarianceSummary {
  let corrections = 0;
  let shortage = 0;
  let surplus = 0;
  for (const l of lines) {
    const v = variance(l.qtyCounted, l.qtySystem);
    if (v === 0) continue;
    corrections += 1;
    if (v < 0) shortage += v;
    else surplus += v;
  }
  return { lines: lines.length, corrections, shortage: round3(shortage), surplus: round3(surplus), net: round3(shortage + surplus) };
}

export function countStatusTone(status: CountStatus): "neutral" | "good" | "warn" {
  return status === "open" ? "warn" : status === "closed" ? "good" : "neutral";
}

export function countActions(status: CountStatus) {
  const open = status === "open";
  return { record: open, close: open, cancel: open };
}
