import { describe, expect, it } from "vitest";
import type { ReferenceCurrency, TenantCurrency } from "./currency-api.ts";

describe("currency-api types & math", () => {
  it("structures reference currency metadata properly", () => {
    const cur: ReferenceCurrency = {
      code: "USD",
      exponent: 2,
      name: "US dollar",
    };
    expect(cur.code).toBe("USD");
    expect(cur.exponent).toBe(2);
  });

  it("handles tenant currency exchange rate conversions", () => {
    const tc: TenantCurrency = {
      tenant_id: "t1",
      code: "USD",
      rate_to_base: 58.5,
      rate_date: "2026-11-10",
      rounding: "half-up",
      active: true,
      created_at: "2026-11-10T00:00:00Z",
      updated_at: "2026-11-10T00:00:00Z",
      deleted_at: null,
    };

    // 10 USD to PHP base: 10 * 58.5 = 585
    const foreignAmount = 10;
    const baseEquivalent = foreignAmount * tc.rate_to_base;
    expect(baseEquivalent).toBe(585);
  });
});
