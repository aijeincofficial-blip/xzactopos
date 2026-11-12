import { describe, expect, it, vi } from "vitest";

vi.mock("./supabase.ts", () => ({
  supabase: { from: vi.fn() },
}));

vi.mock("./sell-api.ts", () => ({
  pushOp: vi.fn(),
}));

import {
  filterExpenseRows,
  summarizeExpenseRows,
  type ExpenseRow,
} from "./expense-api.ts";

const SAMPLE_EXPENSES: ExpenseRow[] = [
  {
    id: "e1",
    location_id: "loc-1",
    amount: 150000, // ₱1,500.00
    currency: "PHP",
    category: "utilities",
    note: "Meralco electric bill",
    paid_from: "cash",
    wallet: null,
    spent_at: "2026-11-10T09:30:00Z",
    voided_at: null,
    void_reason: null,
    created_by: "u1",
  },
  {
    id: "e2",
    location_id: "loc-1",
    amount: 42000, // ₱420.00
    currency: "PHP",
    category: "stock_purchase",
    note: "Ice blocks via GCash",
    paid_from: "ewallet",
    wallet: "gcash",
    spent_at: "2026-11-11T14:15:00Z",
    voided_at: null,
    void_reason: null,
    created_by: "u1",
  },
  {
    id: "e3",
    location_id: "loc-1",
    amount: 25000, // ₱250.00 (voided)
    currency: "PHP",
    category: "transport",
    note: "Tricycle delivery",
    paid_from: "cash",
    wallet: null,
    spent_at: "2026-11-12T08:00:00Z",
    voided_at: "2026-11-12T08:30:00Z",
    void_reason: "Entered twice",
    created_by: "u2",
  },
];

describe("expense-api filter & KPI math", () => {
  it("summarizes active cash/ewallet outflows and excludes voided rows", () => {
    const summary = summarizeExpenseRows(SAMPLE_EXPENSES);
    expect(summary).toEqual({
      activeCount: 2,
      voidedCount: 1,
      totalActive: 192000,
      cashOutflow: 150000,
      ewalletOutflow: 42000,
      operatingSpend: 150000,
      stockPurchases: 42000,
    });
  });

  it("filters by date range, category, paid_from, status, and search text", () => {
    expect(filterExpenseRows(SAMPLE_EXPENSES, { status: "active" }).map((r) => r.id)).toEqual([
      "e1",
      "e2",
    ]);
    expect(filterExpenseRows(SAMPLE_EXPENSES, { status: "voided" }).map((r) => r.id)).toEqual([
      "e3",
    ]);
    expect(
      filterExpenseRows(SAMPLE_EXPENSES, { category: "stock_purchase" }).map((r) => r.id),
    ).toEqual(["e2"]);
    expect(filterExpenseRows(SAMPLE_EXPENSES, { paidFrom: "ewallet" }).map((r) => r.id)).toEqual([
      "e2",
    ]);
    expect(
      filterExpenseRows(SAMPLE_EXPENSES, {
        fromDate: "2026-11-11",
        toDate: "2026-11-11",
      }).map((r) => r.id),
    ).toEqual(["e2"]);
    expect(filterExpenseRows(SAMPLE_EXPENSES, { search: "meralco" }).map((r) => r.id)).toEqual([
      "e1",
    ]);
    expect(filterExpenseRows(SAMPLE_EXPENSES, { search: "gcash" }).map((r) => r.id)).toEqual([
      "e2",
    ]);
    expect(filterExpenseRows(SAMPLE_EXPENSES, { search: "entered twice" }).map((r) => r.id)).toEqual(
      ["e3"],
    );
  });
});
