import { describe, expect, it } from "vitest";
import {
  buildStoreReplenishmentRows,
  nextReorderCursor,
  nextTransitCursor,
  reorderStatus,
  negativeSummary,
  nextNegativeCursor,
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

describe("negativeSummary", () => {
  it("counts lines and places and adds up what is missing", () => {
    const s = negativeSummary([
      { location_id: "S1", qty_on_hand: -3, stock_value: -3000 },
      { location_id: "S1", qty_on_hand: -0.5, stock_value: -250 },
      { location_id: "W1", qty_on_hand: -2.1, stock_value: null },
    ]);
    expect(s).toEqual({ lines: 3, places: 2, units: 5.6, value: 3250 });
  });
  it("is all zeros when nothing is below zero", () => {
    expect(negativeSummary([])).toEqual({ lines: 0, places: 0, units: 0, value: 0 });
  });
});

describe("nextNegativeCursor", () => {
  it("continues after the last row only when the page was full", () => {
    const rows = [
      { location_id: "a", variant_id: "1" },
      { location_id: "b", variant_id: "2" },
    ];
    expect(nextNegativeCursor(rows, 2)).toEqual({ location: "b", variant: "2" });
    expect(nextNegativeCursor(rows, 3)).toBeNull();
    expect(nextNegativeCursor([], 2)).toBeNull();
  });
});

describe("buildStoreReplenishmentRows", () => {
  it("flags low store stock against overrides and pairs with highest-stock warehouse", () => {
    const rows = buildStoreReplenishmentRows({
      stores: [{ id: "s1", code: "S01", name: "Main Store" }],
      warehouses: [
        { id: "w1", code: "WH1", name: "North Hub" },
        { id: "w2", code: "WH2", name: "South Hub" },
      ],
      variants: [
        { id: "v1", sku: "RICE-25", product_name: "Rice 25kg", default_reorder_point: 5, track_stock: true },
        { id: "v2", sku: "OIL-1L", product_name: "Oil 1L", default_reorder_point: 5, track_stock: true },
        { id: "v3", sku: "SVC-1", product_name: "Service Fee", default_reorder_point: 10, track_stock: false },
      ],
      stockLevels: [
        { location_id: "s1", variant_id: "v1", qty_on_hand: 3 },
        { location_id: "w1", variant_id: "v1", qty_on_hand: 12 },
        { location_id: "w2", variant_id: "v1", qty_on_hand: 40 },
        { location_id: "s1", variant_id: "v2", qty_on_hand: 8 },
      ],
      reorderOverrides: [{ location_id: "s1", variant_id: "v1", reorder_point: 10 }],
    });

    expect(rows).toHaveLength(1);
    expect(rows[0]).toEqual({
      store_id: "s1",
      store_code: "S01",
      store_name: "Main Store",
      variant_id: "v1",
      sku: "RICE-25",
      product_name: "Rice 25kg",
      store_qty: 3,
      reorder_point: 10,
      shortfall: 7,
      warehouse_total: 52,
      best_warehouse_id: "w2",
      best_warehouse_code: "WH2",
      best_warehouse_qty: 40,
    });
  });
});
