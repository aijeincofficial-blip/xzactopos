/** Pure rules for the Purchasing screens: what to offer, what a typed line means, what the server will accept. */
import { fromMajor } from "@pos/core";
import { parseQty } from "./product-math.ts";

export type PoStatus = "draft" | "ordered" | "partly_received" | "received" | "cancelled";

/** What is still expected on a line. Over-delivery never makes it negative. */
export function remainingQty(line: { qty_ordered: number; qty_received: number }): number {
  return Math.max(Math.round((line.qty_ordered - line.qty_received) * 1000) / 1000, 0);
}

export interface PoProgress {
  ordered: number;
  received: number;
  /** Sum of what each line still expects (an over-delivered line counts 0, it does not cancel another line's gap). */
  remaining: number;
  percent: number;
}

export function poProgress(lines: Array<{ qty_ordered: number; qty_received: number }>): PoProgress {
  let ordered = 0;
  let received = 0;
  let remaining = 0;
  let done = 0;
  for (const l of lines) {
    ordered += l.qty_ordered;
    received += l.qty_received;
    remaining += remainingQty(l);
    done += Math.min(l.qty_received, l.qty_ordered);
  }
  const round3 = (n: number) => Math.round(n * 1000) / 1000;
  return {
    ordered: round3(ordered),
    received: round3(received),
    remaining: round3(remaining),
    percent: ordered > 0 ? Math.round((done / ordered) * 100) : 0,
  };
}

/** Quantity x cost in minor units, exact (3-decimal quantities), half up. Null when the cost is unknown. */
export function lineValue(qty: number, cost: number | null): number | null {
  if (cost === null) return null;
  const milli = BigInt(Math.round(qty * 1000));
  return Number((BigInt(cost) * milli * 2n + 1000n) / 2000n);
}

export function poStatusTone(status: PoStatus): "neutral" | "good" | "warn" {
  if (status === "received") return "good";
  if (status === "partly_received") return "warn";
  return "neutral";
}

/** The actions worth offering for a purchase order. The server is still the gate. */
export function poActions(status: PoStatus, hasReceipts: boolean) {
  return {
    submit: status === "draft",
    cancel: status === "draft" || (status === "ordered" && !hasReceipts),
    receive: status === "ordered" || status === "partly_received",
    close: status === "partly_received",
  };
}

export type LineError = "product_required" | "qty_invalid" | "cost_invalid" | "duplicate_item";

export interface LineResult<T> {
  ok: boolean;
  items: T[];
  rowErrors: Array<LineError | null>;
  /** Nothing usable was entered at all. */
  empty: boolean;
}

/** "" = no cost given (undefined). A typed cost in major units ("12.50") becomes minor units, or null when invalid. */
function parseCost(text: string, currency: string): number | undefined | null {
  const v = text.trim();
  if (v === "") return undefined;
  try {
    const m = fromMajor(v, currency);
    return m.amount >= 0 ? m.amount : null;
  } catch {
    return null;
  }
}

export interface PoLineDraft {
  variantId: string;
  qtyText: string;
  costText: string;
}

export interface PoItemPayload {
  variant_id: string;
  qty: number;
  unit_cost?: number;
}

/** Lines of a new purchase order. Completely blank rows are ignored; half-filled ones are errors. */
export function buildPoItems(drafts: PoLineDraft[], currency: string): LineResult<PoItemPayload> {
  const items: PoItemPayload[] = [];
  const rowErrors: Array<LineError | null> = [];
  const seen = new Set<string>();
  let anyContent = false;
  for (const d of drafts) {
    const blank = d.variantId === "" && d.qtyText.trim() === "" && d.costText.trim() === "";
    if (blank) {
      rowErrors.push(null);
      continue;
    }
    anyContent = true;
    if (d.variantId === "") {
      rowErrors.push("product_required");
      continue;
    }
    const qty = parseQty(d.qtyText);
    if (qty === null) {
      rowErrors.push("qty_invalid");
      continue;
    }
    const cost = parseCost(d.costText, currency);
    if (cost === null) {
      rowErrors.push("cost_invalid");
      continue;
    }
    if (seen.has(d.variantId)) {
      rowErrors.push("duplicate_item");
      continue;
    }
    seen.add(d.variantId);
    rowErrors.push(null);
    items.push(cost === undefined ? { variant_id: d.variantId, qty } : { variant_id: d.variantId, qty, unit_cost: cost });
  }
  const ok = anyContent && rowErrors.every((e) => e === null);
  return { ok, items: ok ? items : [], rowErrors, empty: !anyContent };
}

export interface ReceiveRow {
  variantId: string;
  remaining: number;
  qtyText: string;
  costText: string;
}

export interface ReceiveResult extends LineResult<PoItemPayload> {
  /** Per row: more than was still expected (allowed, but flagged by the server). */
  over: boolean[];
  hasOver: boolean;
}

/** One delivery against a PO: only rows with a quantity are sent; a blank cost lets the server use the order's cost. */
export function buildReceiveItems(rows: ReceiveRow[], currency: string): ReceiveResult {
  const items: PoItemPayload[] = [];
  const rowErrors: Array<LineError | null> = [];
  const over: boolean[] = [];
  let anyQty = false;
  for (const r of rows) {
    if (r.qtyText.trim() === "") {
      rowErrors.push(null);
      over.push(false);
      continue;
    }
    anyQty = true;
    const qty = parseQty(r.qtyText);
    if (qty === null) {
      rowErrors.push("qty_invalid");
      over.push(false);
      continue;
    }
    const cost = parseCost(r.costText, currency);
    if (cost === null) {
      rowErrors.push("cost_invalid");
      over.push(false);
      continue;
    }
    rowErrors.push(null);
    over.push(qty > r.remaining);
    items.push(cost === undefined ? { variant_id: r.variantId, qty } : { variant_id: r.variantId, qty, unit_cost: cost });
  }
  const ok = anyQty && rowErrors.every((e) => e === null);
  return { ok, items: ok ? items : [], rowErrors, empty: !anyQty, over, hasOver: over.some(Boolean) };
}
