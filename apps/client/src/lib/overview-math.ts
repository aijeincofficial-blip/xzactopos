/** Pure rules for the warehouse overview: how to label a reorder line, add warehouses up, age a shipment, and page. */

const round3 = (n: number) => Math.round(n * 1000) / 1000;

export interface ReorderLine {
  location_id: string;
  variant_id: string;
  covered: boolean;
  shortfall: number;
}

export type ReorderStatus = "covered" | "order" | "at_point";

/**
 * covered  = on hand + incoming + on order is above the reorder point: something is already on its way.
 * order    = still short of the point even counting what is on its way.
 * at_point = exactly at the point with nothing coming (not short yet, not covered either).
 */
export function reorderStatus(line: Pick<ReorderLine, "covered" | "shortfall">): ReorderStatus {
  if (line.covered) return "covered";
  return line.shortfall > 0 ? "order" : "at_point";
}

export interface ReorderSummary {
  lines: number;
  covered: number;
  needOrder: number;
  atPoint: number;
  totalShortfall: number;
}

export function reorderSummary(lines: Array<Pick<ReorderLine, "covered" | "shortfall">>): ReorderSummary {
  let covered = 0;
  let needOrder = 0;
  let atPoint = 0;
  let totalShortfall = 0;
  for (const l of lines) {
    const s = reorderStatus(l);
    if (s === "covered") covered += 1;
    else if (s === "order") {
      needOrder += 1;
      totalShortfall += l.shortfall;
    } else atPoint += 1;
  }
  return { lines: lines.length, covered, needOrder, atPoint, totalShortfall: round3(totalShortfall) };
}

export interface StockLine {
  qty_on_hand: number;
  incoming_qty: number;
  on_order_qty: number;
  stock_value: number | null;
}

export interface StockTotals {
  qty: number;
  incoming: number;
  onOrder: number;
  /** Null when no warehouse has a cost for the product. A warehouse without a cost adds to the quantity but not to the value. */
  value: number | null;
}

export function stockTotals(rows: StockLine[]): StockTotals {
  let qty = 0;
  let incoming = 0;
  let onOrder = 0;
  let value: number | null = null;
  for (const r of rows) {
    qty += r.qty_on_hand;
    incoming += r.incoming_qty;
    onOrder += r.on_order_qty;
    if (r.stock_value !== null) value = (value ?? 0) + r.stock_value;
  }
  return { qty: round3(qty), incoming: round3(incoming), onOrder: round3(onOrder), value };
}

/** A shipment is overdue for attention after this many hours on the road. */
export const LATE_AFTER_HOURS = 72;

export function transitAge(hours: number): { days: number; hours: number } {
  const total = Math.round(Math.max(hours, 0));
  return { days: Math.floor(total / 24), hours: total % 24 };
}

export function transitIsLate(hours: number): boolean {
  return hours >= LATE_AFTER_HOURS;
}

/** Keyset cursor for the next page of the reorder list: only when this page was full. */
export function nextReorderCursor(rows: Array<{ location_id: string; variant_id: string }>, pageSize: number) {
  if (rows.length === 0 || rows.length < pageSize) return null;
  const last = rows[rows.length - 1]!;
  return { location: last.location_id, variant: last.variant_id };
}

/** Keyset cursor for the next page of shipments in transit: only when this page was full. */
export function nextTransitCursor(rows: Array<{ transfer_id: string; shipped_at: string }>, pageSize: number) {
  if (rows.length === 0 || rows.length < pageSize) return null;
  const last = rows[rows.length - 1]!;
  return { shippedAt: last.shipped_at, id: last.transfer_id };
}
