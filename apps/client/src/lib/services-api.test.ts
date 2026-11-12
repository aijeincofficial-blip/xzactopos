import { beforeEach, describe, expect, it, vi } from "vitest";

const { pushOpMock } = vi.hoisted(() => ({
  pushOpMock: vi.fn(),
}));

vi.mock("./sell-api.ts", () => ({
  pushOp: pushOpMock,
}));

vi.mock("./supabase.ts", () => ({
  supabase: {
    from: vi.fn(),
  },
}));

import {
  computeOperatingExpenseBreakdown,
  filterServiceTxns,
  recordServiceTxn,
  serviceCashEffect,
  serviceFloatEffect,
  summarizeServiceTxns,
  voidServiceTxn,
  type ServiceTxnRow,
} from "./services-api.ts";

describe("services-api money invariants and payloads", () => {
  beforeEach(() => {
    pushOpMock.mockReset();
  });

  it("satisfies cashEffect + floatEffect = fee for every non-adjustment kind", () => {
    // Cash-in: ₱500 principal + ₱10 fee -> drawer +₱510, float -₱500, net +₱10
    expect(serviceCashEffect("cash_in", 50000, 1000)).toBe(51000);
    expect(serviceFloatEffect("cash_in", 50000)).toBe(-50000);
    expect(serviceCashEffect("cash_in", 50000, 1000) + serviceFloatEffect("cash_in", 50000)).toBe(1000);

    // Cash-out: ₱500 principal + ₱15 fee -> drawer -₱485, float +₱500, net +₱15
    expect(serviceCashEffect("cash_out", 50000, 1500)).toBe(-48500);
    expect(serviceFloatEffect("cash_out", 50000)).toBe(50000);
    expect(serviceCashEffect("cash_out", 50000, 1500) + serviceFloatEffect("cash_out", 50000)).toBe(1500);

    // Load: ₱50 wallet debit sold for ₱53 -> drawer +₱53, float -₱50, net +₱3
    expect(serviceCashEffect("load", 5000, 300, 5300)).toBe(5300);
    expect(serviceFloatEffect("load", 5000)).toBe(-5000);
    expect(serviceCashEffect("load", 5000, 300, 5300) + serviceFloatEffect("load", 5000)).toBe(300);

    // Float top-up & withdraw have zero net income
    expect(serviceCashEffect("float_topup", 100000) + serviceFloatEffect("float_topup", 100000)).toBe(0);
    expect(serviceCashEffect("float_withdraw", 40000) + serviceFloatEffect("float_withdraw", 40000)).toBe(0);

    // Float adjustment moves float only
    expect(serviceCashEffect("float_adjust", -2500)).toBe(0);
    expect(serviceFloatEffect("float_adjust", -2500)).toBe(-2500);
  });

  it("excludes stock_purchase from operating expenses to avoid double-counting COGS", () => {
    const res = computeOperatingExpenseBreakdown({
      total: 5500,
      by_category: [
        { category: "stock_purchase", amount: 4000 },
        { category: "utilities", amount: 1000 },
        { category: "transport", amount: 500 },
      ],
    });
    expect(res).toEqual({
      total: 5500,
      stockBought: 4000,
      operatingExpenses: 1500,
    });
  });

  it("builds record_service_txn and void_service_txn sync_push payloads with approvals", async () => {
    pushOpMock.mockResolvedValue({ status: "ok" });

    await recordServiceTxn({
      id: "txn-1",
      locationId: "loc-1",
      kind: "load",
      wallet: "load",
      amount: 5000,
      price: 5300,
      ref: " 09171234567 ",
      txnAt: "2026-11-12T01:00:00Z",
    });

    expect(pushOpMock).toHaveBeenCalledWith("record_service_txn", {
      id: "txn-1",
      location_id: "loc-1",
      kind: "load",
      wallet: "load",
      amount: 5000,
      price: 5300,
      ref: "09171234567",
      txn_at: "2026-11-12T01:00:00Z",
    });

    await voidServiceTxn({
      txnId: "txn-1",
      reason: "Wrong number",
      approvalId: "appr-99",
    });

    expect(pushOpMock).toHaveBeenCalledWith("void_service_txn", {
      txn_id: "txn-1",
      reason: "Wrong number",
      approval_id: "appr-99",
    });
  });

  it("filters and summarizes service entries in centavos while excluding voided entries", () => {
    const sample: ServiceTxnRow[] = [
      {
        id: "st-1",
        location_id: "loc-1",
        kind: "cash_in",
        wallet: "gcash",
        amount: 100000, // ₱1,000
        fee: 2000, // ₱20
        price: null,
        currency: "PHP",
        ref: "09171112222",
        note: "Regular suki",
        txn_at: "2026-11-10T09:00:00Z",
        voided_at: null,
        void_reason: null,
        created_by: "u1",
      },
      {
        id: "st-2",
        location_id: "loc-1",
        kind: "cash_out",
        wallet: "maya",
        amount: 50000, // ₱500 -> drawer -48500, float +50000
        fee: 1500, // ₱15
        price: null,
        currency: "PHP",
        ref: "MYA-8899",
        note: null,
        txn_at: "2026-11-11T10:30:00Z",
        voided_at: null,
        void_reason: null,
        created_by: "u1",
      },
      {
        id: "st-3",
        location_id: "loc-1",
        kind: "float_topup",
        wallet: "gcash",
        amount: 30000, // ₱300 -> drawer -30000, float +30000
        fee: 0,
        price: null,
        currency: "PHP",
        ref: null,
        note: "Bank replenish",
        txn_at: "2026-11-11T12:00:00Z",
        voided_at: null,
        void_reason: null,
        created_by: "u1",
      },
      {
        id: "st-4",
        location_id: "loc-1",
        kind: "load",
        wallet: "load",
        amount: 5000,
        fee: 300,
        price: 5300,
        currency: "PHP",
        ref: "09189990000",
        note: "Wrong number",
        txn_at: "2026-11-12T08:00:00Z",
        voided_at: "2026-11-12T08:05:00Z",
        void_reason: "Typo on number",
        created_by: "u1",
      },
    ];

    const summary = summarizeServiceTxns(sample);
    // Cash effects: +102000 - 48500 - 30000 = +23500; Float effects: -100000 + 50000 + 30000 = -20000; Net = +3500 (= feeIncome!)
    expect(summary).toEqual({
      activeCount: 3,
      voidedCount: 1,
      customerTxnCount: 2,
      feeIncome: 3500,
      netCashEffect: 23500,
      netFloatEffect: -20000,
    });
    expect(summary.netCashEffect + summary.netFloatEffect).toBe(summary.feeIncome);

    expect(filterServiceTxns(sample, { wallet: "gcash", status: "active" }).map((r) => r.id)).toEqual([
      "st-1",
      "st-3",
    ]);
    expect(filterServiceTxns(sample, { kind: "cash_out" }).map((r) => r.id)).toEqual(["st-2"]);
    expect(filterServiceTxns(sample, { status: "voided" }).map((r) => r.id)).toEqual(["st-4"]);
    expect(
      filterServiceTxns(sample, { fromDate: "2026-11-11", toDate: "2026-11-11" }).map((r) => r.id),
    ).toEqual(["st-2", "st-3"]);
    expect(filterServiceTxns(sample, { search: "MYA-8899" }).map((r) => r.id)).toEqual(["st-2"]);
  });
});
