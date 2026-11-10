import { describe, expect, it } from "vitest";
import { PHP_DENOMINATIONS, calculateDenominationTotal } from "./denomination-math.ts";

describe("denomination-math", () => {
  it("calculates zero when all counts are empty or zero", () => {
    expect(calculateDenominationTotal(PHP_DENOMINATIONS, {})).toBe(0);
    expect(calculateDenominationTotal(PHP_DENOMINATIONS, { bill_1000: 0, coin_5: 0 })).toBe(0);
  });

  it("calculates exact sum for banknotes and coins", () => {
    const counts = {
      bill_1000: 3, // 3000
      bill_500: 2,  // 1000
      bill_100: 5,  // 500
      coin_20: 4,   // 80
      coin_5: 3,    // 15
      coin_025: 2,  // 0.50
    };
    expect(calculateDenominationTotal(PHP_DENOMINATIONS, counts)).toBe(4595.5);
  });
});
