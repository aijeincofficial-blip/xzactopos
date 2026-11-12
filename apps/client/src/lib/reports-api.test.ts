import { beforeEach, describe, expect, it, vi } from "vitest";

const { rpcMock } = vi.hoisted(() => ({
  rpcMock: vi.fn(),
}));

vi.mock("./supabase.ts", () => ({
  supabase: {
    rpc: rpcMock,
  },
}));

import {
  buildDailySalesCsv,
  buildTopProductsCsv,
  fetchMultiStoreReport,
  filterAccessibleReportLocations,
  type ReportMultiStoreResult,
} from "./reports-api.ts";

const sampleReport = (locationId: string | null = null): ReportMultiStoreResult => ({
  from: "2026-11-01",
  to: "2026-11-08",
  location_id: locationId,
  totals: {
    net: 24000,
    gross: 25000,
    discount: 1000,
    tax: 0,
    cogs: 15000,
    txns: 3,
    cash: 19500,
    ewallet: 0,
    card: 0,
    utang: 4500,
    profit: 9000,
    margin_percent: 37.5,
  },
  days: [
    {
      day: "2026-11-08",
      net: 24000,
      gross: 25000,
      discount: 1000,
      tax: 0,
      cogs: 15000,
      txns: 3,
      cash: 19500,
      ewallet: 0,
      card: 0,
      utang: 4500,
      profit: 9000,
    },
  ],
  top_items: [
    {
      variant_id: "v-1",
      name: "Barako Coffee",
      sku: "COFFEE-01",
      qty: 5,
      revenue: 24000,
      cogs: 15000,
      profit: 9000,
    },
  ],
  stores: [],
  stock_valuation: { total_value: 100000, total_units: 10, items_count: 1 },
  transfers: { total_transfers: 0, shipped_count: 0, received_count: 0, discrepancy_count: 0 },
  expenses: { total: 0, cash: 0, ewallet: 0, count: 0, by_category: [], days: [] },
  services: { count: 0, fee_total: 0, by_kind: [], float: [] },
  utang: { owed: 4500, customers: [{ id: "c-1", name: "Aling Nena", balance: 4500 }] },
  server_time: "2026-11-08T10:00:00Z",
});

describe("reports-api branch filtering", () => {
  beforeEach(() => {
    rpcMock.mockReset();
  });

  it("passes p_location_id = null when aggregating all locations", async () => {
    const expected = sampleReport(null);
    rpcMock.mockResolvedValueOnce({ data: expected, error: null });

    const res = await fetchMultiStoreReport({ from: "2026-11-01", to: "2026-11-08", locationId: null });
    expect(rpcMock).toHaveBeenCalledWith("report_multi_store", {
      p_from: "2026-11-01",
      p_to: "2026-11-08",
      p_location_id: null,
    });
    expect(res.totals.net).toBe(24000);
  });

  it("passes branch UUID as p_location_id when filtering a single store", async () => {
    const branchId = "20000000-0000-0000-0000-000000000011";
    const expected = sampleReport(branchId);
    rpcMock.mockResolvedValueOnce({ data: expected, error: null });

    const res = await fetchMultiStoreReport({
      from: "2026-11-01",
      to: "2026-11-08",
      locationId: branchId,
    });
    expect(rpcMock).toHaveBeenCalledWith("report_multi_store", {
      p_from: "2026-11-01",
      p_to: "2026-11-08",
      p_location_id: branchId,
    });
    expect(res.location_id).toBe(branchId);
  });

  it("scopes location dropdown options to active assigned stores unless superadmin", () => {
    const locs = [
      { id: "s1", code: "S01", name: "Downtown", active: true },
      { id: "s2", code: "S02", name: "Uptown", active: true },
      { id: "s3", code: "S03", name: "Closed Branch", active: false },
    ];

    expect(
      filterAccessibleReportLocations(locs, {
        role: "superadmin",
        locations: [{ id: "s1" }],
      }).map((l) => l.id),
    ).toEqual(["s1", "s2"]);

    expect(
      filterAccessibleReportLocations(locs, {
        role: "admin",
        locations: [{ id: "s2" }],
      }).map((l) => l.id),
    ).toEqual(["s2"]);
  });

  it("includes branch label and slug in CSV exports when filtered to a store", () => {
    const rep = sampleReport("s1");
    const allCsv = buildDailySalesCsv(rep, "Tindahan Co");
    expect(allCsv.filename).toBe("sales_daily_2026-11-01_to_2026-11-08.csv");
    expect(allCsv.content).not.toContain("# Location:");

    const branchCsv = buildDailySalesCsv(rep, "Tindahan Co", "S01 · Downtown");
    expect(branchCsv.filename).toBe("sales_daily_s01_downtown_2026-11-01_to_2026-11-08.csv");
    expect(branchCsv.content).toContain("# Location: S01 · Downtown");
    expect(branchCsv.content).toContain("2026-11-08,250.00,10.00,240.00,150.00,90.00,3,195.00,0.00,0.00,45.00");

    const topCsv = buildTopProductsCsv(rep, "Tindahan Co", "S01 · Downtown");
    expect(topCsv.filename).toBe("top_products_s01_downtown_2026-11-01_to_2026-11-08.csv");
    expect(topCsv.content).toContain("Barako Coffee,COFFEE-01,5,240.00,150.00,90.00");
  });
});
