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

/** Keyset cursor for the next page of the negative stock list: only when this page was full. */
export function nextNegativeCursor(rows: Array<{ location_id: string; variant_id: string }>, pageSize: number) {
  if (rows.length === 0 || rows.length < pageSize) return null;
  const last = rows[rows.length - 1]!;
  return { location: last.location_id, variant: last.variant_id };
}

export interface NegativeSummary {
  lines: number;
  places: number;
  /** Units missing, as a positive number. */
  units: number;
  /** Value of what is missing at average cost, as a positive number; lines without a cost are left out. */
  value: number;
}

export function negativeSummary(rows: Array<{ location_id: string; qty_on_hand: number; stock_value: number | null }>): NegativeSummary {
  let units = 0;
  let value = 0;
  for (const r of rows) {
    units += Math.abs(r.qty_on_hand);
    if (r.stock_value !== null) value += Math.abs(r.stock_value);
  }
  return { lines: rows.length, places: new Set(rows.map((r) => r.location_id)).size, units: round3(units), value };
}

export interface StoreReplenishmentRow {
  store_id: string;
  store_code: string;
  store_name: string;
  variant_id: string;
  sku: string;
  product_name: string;
  store_qty: number;
  reorder_point: number;
  shortfall: number;
  warehouse_total: number;
  best_warehouse_id: string | null;
  best_warehouse_code: string | null;
  best_warehouse_qty: number;
}

export function buildStoreReplenishmentRows(args: {
  stores: ReadonlyArray<{ id: string; code: string; name: string }>;
  warehouses: ReadonlyArray<{ id: string; code: string; name: string }>;
  variants: ReadonlyArray<{
    id: string;
    sku: string;
    product_name: string;
    default_reorder_point: number;
    track_stock: boolean;
  }>;
  stockLevels: ReadonlyArray<{ location_id: string; variant_id: string; qty_on_hand: number }>;
  reorderOverrides: ReadonlyArray<{ location_id: string; variant_id: string; reorder_point: number }>;
}): StoreReplenishmentRow[] {
  const levelMap = new Map<string, number>();
  for (const s of args.stockLevels) {
    levelMap.set(`${s.location_id}:${s.variant_id}`, s.qty_on_hand);
  }
  const overrideMap = new Map<string, number>();
  for (const o of args.reorderOverrides) {
    overrideMap.set(`${o.location_id}:${o.variant_id}`, o.reorder_point);
  }

  const out: StoreReplenishmentRow[] = [];
  for (const store of args.stores) {
    for (const v of args.variants) {
      if (!v.track_stock) continue;
      const key = `${store.id}:${v.id}`;
      const storeQty = levelMap.get(key) ?? 0;
      const point = overrideMap.get(key) ?? v.default_reorder_point;
      if (storeQty > 0 && (point <= 0 || storeQty > point)) continue;
      if (storeQty === 0 && point <= 0) continue;

      let whTotal = 0;
      let bestWhId: string | null = null;
      let bestWhCode: string | null = null;
      let bestWhQty = 0;
      for (const wh of args.warehouses) {
        const wQty = levelMap.get(`${wh.id}:${v.id}`) ?? 0;
        if (wQty > 0) {
          whTotal = round3(whTotal + wQty);
          if (wQty > bestWhQty) {
            bestWhQty = wQty;
            bestWhId = wh.id;
            bestWhCode = wh.code;
          }
        }
      }

      const target = point > 0 ? point : 1;
      const shortfall = round3(Math.max(1, target - storeQty));
      out.push({
        store_id: store.id,
        store_code: store.code,
        store_name: store.name,
        variant_id: v.id,
        sku: v.sku,
        product_name: v.product_name,
        store_qty: round3(storeQty),
        reorder_point: round3(point),
        shortfall,
        warehouse_total: whTotal,
        best_warehouse_id: bestWhId,
        best_warehouse_code: bestWhCode,
        best_warehouse_qty: round3(bestWhQty),
      });
    }
  }

  return out.sort((a, b) => {
    if (a.store_qty !== b.store_qty) return a.store_qty - b.store_qty;
    return b.shortfall - a.shortfall || a.product_name.localeCompare(b.product_name);
  });
}

/** Keyset cursor for the next page of shipments in transit: only when this page was full. */
export function nextTransitCursor(rows: Array<{ transfer_id: string; shipped_at: string }>, pageSize: number) {
  if (rows.length === 0 || rows.length < pageSize) return null;
  const last = rows[rows.length - 1]!;
  return { shippedAt: last.shipped_at, id: last.transfer_id };
}
