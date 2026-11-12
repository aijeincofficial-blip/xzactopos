import { describe, expect, it } from "vitest";
import {
  computeCustomerBalances,
  isOverdue,
  calculateAdjustment,
  filterCustomersForPos,
  evaluateCustomerCreditStatus,
} from "./utang-math.ts";

describe("utang-math", () => {
  it("calculates adjustment amount correctly based on direction", () => {
    expect(calculateAdjustment(500, "less")).toBe(-500);
    expect(calculateAdjustment(500, "more")).toBe(500);
    expect(calculateAdjustment(0, "less")).toBe(0);
    expect(calculateAdjustment(0, "more")).toBe(0);
    expect(calculateAdjustment(-10, "less")).toBe(0);
    expect(calculateAdjustment(-10, "more")).toBe(0);
  });
  it("determines whether an account is overdue correctly", () => {
    expect(isOverdue(100, "2026-11-07", "2026-11-08")).toBe(true);
    expect(isOverdue(100, "2026-11-08", "2026-11-08")).toBe(false);
    expect(isOverdue(100, "2026-11-09", "2026-11-08")).toBe(false);
    expect(isOverdue(0, "2026-11-07", "2026-11-08")).toBe(false);
    expect(isOverdue(-50, "2026-11-07", "2026-11-08")).toBe(false);
    expect(isOverdue(100, null, "2026-11-08")).toBe(false);
  });

  it("computes and sorts customer balances correctly", () => {
    const customers = [
      { id: "c1", name: "Bob", phone: "123", due_on: "2026-11-01" },
      { id: "c2", name: "Alice", phone: null, due_on: null },
      { id: "c3", name: "Charlie", phone: null, due_on: null },
    ];
    const ledger = [
      { customer_id: "c1", amount: 500 },
      { customer_id: "c1", amount: -200 },
      { customer_id: "c2", amount: 1000 },
    ];
    const res = computeCustomerBalances(customers, ledger);
    expect(res).toEqual([
      { customerId: "c2", name: "Alice", phone: null, dueOn: null, balance: 1000 },
      { customerId: "c1", name: "Bob", phone: "123", dueOn: "2026-11-01", balance: 300 },
      { customerId: "c3", name: "Charlie", phone: null, dueOn: null, balance: 0 },
    ]);
  });

  it("filters POS customers by name or phone and sorts alphabetically", () => {
    const list = [
      { customerId: "c1", name: "Mang Tomas", phone: "09171234567", dueOn: null, balance: 2500 },
      { customerId: "c2", name: "Aling Nena", phone: "09189998888", dueOn: "2026-11-01", balance: 5000 },
      { customerId: "c3", name: "Jun Reyes", phone: null, dueOn: null, balance: 0 },
    ];
    expect(filterCustomersForPos(list, "").map((c) => c.name)).toEqual([
      "Aling Nena",
      "Jun Reyes",
      "Mang Tomas",
    ]);
    expect(filterCustomersForPos(list, "nena").map((c) => c.customerId)).toEqual(["c2"]);
    expect(filterCustomersForPos(list, "1234").map((c) => c.customerId)).toEqual(["c1"]);
  });

  it("evaluates overdue and projected Utang credit status accurately", () => {
    expect(
      evaluateCustomerCreditStatus({ balance: 15000, dueOn: "2026-11-05" }, "2026-11-12", 5000),
    ).toEqual({
      hasBalance: true,
      overdue: true,
      currentBalance: 15000,
      projectedBalance: 20000,
      dueOn: "2026-11-05",
    });

    expect(
      evaluateCustomerCreditStatus({ balance: 8000, dueOn: "2026-11-20" }, "2026-11-12", 0),
    ).toEqual({
      hasBalance: true,
      overdue: false,
      currentBalance: 8000,
      projectedBalance: 8000,
      dueOn: "2026-11-20",
    });

    expect(evaluateCustomerCreditStatus(null, "2026-11-12", 3000)).toEqual({
      hasBalance: false,
      overdue: false,
      currentBalance: 0,
      projectedBalance: 3000,
      dueOn: null,
    });
  });
});
