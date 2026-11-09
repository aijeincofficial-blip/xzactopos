import { describe, expect, it } from "vitest";
import {
  nextReorderCursor,
  nextTransitCursor,
  reorderStatus,
  reorderSummary,
  stockTotals,
  transitAge,
  transitIsLate,
} from "./overview-math.ts";

const reorder = (over: Record<string, unknown> = {}) => ({
  location_id: "L1",
  location_code: "W1",
  variant_id: "V1",
  sku: "RICE",
  product_name: "Rice",
  qty_on_hand: 10,
  reorder_point: 20,
  incoming_qty: 0,
  on_order_qty: 0,
  covered: false,
  shortfall: 10,
  ...over,
});

describe("reorderStatus", () => {
  it("is covered when stock already on its way lifts the line above the point", () => {
    expect(reorderStatus(reorder({ covered: true, shortfall: 0, incoming_qty: 15 }))).toBe("covered");
  });
  it("is order when something is still missing after what is on its way", () => {
    expect(reorderStatus(reorder({ covered: false, shortfall: 5 }))).toBe("order");
  });
  it("is at_point when exactly at the reorder point with nothing coming", () => {
    expect(reorderStatus(reorder({ qty_on_hand: 20, covered: false, shortfall: 0 }))).toBe("at_point");
  });
});

describe("reorderSummary", () => {
  it("counts the lines that still need an order", () => {
    const s = reorderSummary([
      reorder({ covered: true, shortfall: 0 }),
      reorder({ covered: false, shortfall: 7 }),
      reorder({ covered: false, shortfall: 0 }),
      reorder({ covered: false, shortfall: 3 }),
    ]);
    expect(s).toEqual({ lines: 4, covered: 1, needOrder: 2, atPoint: 1, totalShortfall: 10 });
  });
  it("is all zeros when empty", () => {
    expect(reorderSummary([])).toEqual({ lines: 0, covered: 0, needOrder: 0, atPoint: 0, totalShortfall: 0 });
  });
});

describe("stockTotals", () => {
  it("adds the warehouses up, with no float noise", () => {
    const t = stockTotals([
      { qty_on_hand: 60.1, incoming_qty: 30, on_order_qty: 0, stock_value: 60000 },
      { qty_on_hand: 55.2, incoming_qty: 0, on_order_qty: 25, stock_value: 55000 },
    ]);
    expect(t).toEqual({ qty: 115.3, incoming: 30, onOrder: 25, value: 115000 });
  });
  it("skips a warehouse with no cost but keeps its quantity", () => {
    const t = stockTotals([
      { qty_on_hand: 5, incoming_qty: 0, on_order_qty: 0, stock_value: null },
      { qty_on_hand: 10, incoming_qty: 0, on_order_qty: 0, stock_value: 1000 },
    ]);
    expect(t.qty).toBe(15);
    expect(t.value).toBe(1000);
  });
  it("has no value at all when no warehouse has a cost", () => {
    expect(stockTotals([{ qty_on_hand: 5, incoming_qty: 0, on_order_qty: 0, stock_value: null }]).value).toBeNull();
    expect(stockTotals([]).value).toBeNull();
  });
});

describe("transitAge", () => {
  it("splits hours into days and hours", () => {
    expect(transitAge(0)).toEqual({ days: 0, hours: 0 });
    expect(transitAge(5.4)).toEqual({ days: 0, hours: 5 });
    expect(transitAge(24)).toEqual({ days: 1, hours: 0 });
    expect(transitAge(76.6)).toEqual({ days: 3, hours: 5 });
  });
  it("carries a rounded-up 24 hours into a day", () => {
    expect(transitAge(47.6)).toEqual({ days: 2, hours: 0 });
  });
  it("treats a shipment as late after 72 hours", () => {
    expect(transitIsLate(71.9)).toBe(false);
    expect(transitIsLate(72)).toBe(true);
    expect(transitIsLate(200)).toBe(true);
  });
});

describe("paging cursors", () => {
  it("continues after the last reorder row of a full page, and stops after a short one", () => {
    const rows = [reorder({ location_id: "A", variant_id: "1" }), reorder({ location_id: "A", variant_id: "2" })];
    expect(nextReorderCursor(rows, 2)).toEqual({ location: "A", variant: "2" });
    expect(nextReorderCursor(rows, 3)).toBeNull();
    expect(nextReorderCursor([], 2)).toBeNull();
  });
  it("continues after the last shipment of a full page, and stops after a short one", () => {
    const rows = [
      { transfer_id: "T1", shipped_at: "2026-11-09T02:00:00Z" },
      { transfer_id: "T2", shipped_at: "2026-11-09T01:00:00Z" },
    ];
    expect(nextTransitCursor(rows, 2)).toEqual({ shippedAt: "2026-11-09T01:00:00Z", id: "T2" });
    expect(nextTransitCursor(rows, 5)).toBeNull();
  });
});
