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
  recordServiceTxn,
  serviceCashEffect,
  serviceFloatEffect,
  voidServiceTxn,
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
});
