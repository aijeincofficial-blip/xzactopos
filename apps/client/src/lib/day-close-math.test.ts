import { describe, expect, it } from "vitest";
import { computeDifference, computeExpectedCash, dayUtcBounds } from "./day-close-math.ts";

describe("day-close-math", () => {
  it("computes expected cash properly", () => {
    expect(
      computeExpectedCash({
        openingCash: 1000,
        cashSales: 5000,
        cashUtangPayments: 800,
        cashExpenses: 1200,
      }),
    ).toBe(5600);
  });

  it("computes difference (over/short) properly", () => {
    expect(computeDifference(5600, 5600)).toBe(0);
    expect(computeDifference(6000, 5600)).toBe(400); // Over
    expect(computeDifference(5000, 5600)).toBe(-600); // Short
  });

  it("computes dayUtcBounds for Asia/Manila (UTC+8)", () => {
    const { from, to } = dayUtcBounds("2026-11-08", "Asia/Manila");
    // 2026-11-08 00:00:00 +08:00 is 2026-11-07 16:00:00Z
    expect(from).toBe("2026-11-07T16:00:00.000Z");
    expect(to).toBe("2026-11-08T16:00:00.000Z");
  });

  it("computes expected cash including net service drawer effects (F09)", () => {
    expect(
      computeExpectedCash({
        openingCash: 100000,
        cashSales: 250000,
        cashUtangPayments: 50000,
        cashServices: 302000, // e.g. +3020 PHP from cash-in / load minus cash-out
        cashExpenses: 40000,
      }),
    ).toBe(662000);

    expect(
      computeExpectedCash({
        openingCash: 100000,
        cashSales: 100000,
        cashUtangPayments: 0,
        cashServices: -45000, // net cash-out / float top-up reduces drawer cash
        cashExpenses: 10000,
      }),
    ).toBe(145000);
  });

  it("computes dayUtcBounds for UTC", () => {
    const { from, to } = dayUtcBounds("2026-11-08", "UTC");
    expect(from).toBe("2026-11-08T00:00:00.000Z");
    expect(to).toBe("2026-11-09T00:00:00.000Z");
  });
});
