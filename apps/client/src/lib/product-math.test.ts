import { describe, expect, it } from "vitest";
import { formatQty, parseQty, parseTaxPercent, stockStatus, taxPercentText } from "./product-math.ts";

describe("parseQty", () => {
  it("reads quantities with up to 3 decimals", () => {
    expect(parseQty("5")).toBe(5);
    expect(parseQty("1.5")).toBe(1.5);
    expect(parseQty(" 0.125 ")).toBe(0.125);
  });
  it("refuses zero (unless a count), negatives, too many decimals, junk and huge numbers", () => {
    expect(parseQty("0")).toBeNull();
    expect(parseQty("0", { allowZero: true })).toBe(0);
    expect(parseQty("-1")).toBeNull();
    expect(parseQty("1.2345")).toBeNull();
    expect(parseQty("1,5")).toBeNull();
    expect(parseQty("abc")).toBeNull();
    expect(parseQty("")).toBeNull();
    expect(parseQty("1000000000")).toBeNull();
  });
});

describe("tax percent", () => {
  it("turns a percent into the stored rate exactly", () => {
    expect(parseTaxPercent("")).toBe(0);
    expect(parseTaxPercent("12")).toBe(0.12);
    expect(parseTaxPercent("12.5")).toBe(0.125);
    expect(parseTaxPercent("7.25")).toBe(0.0725);
    expect(parseTaxPercent("0")).toBe(0);
  });
  it("refuses what the database would (rate must stay under 100%)", () => {
    expect(parseTaxPercent("100")).toBeNull();
    expect(parseTaxPercent("-1")).toBeNull();
    expect(parseTaxPercent("1.234")).toBeNull();
    expect(parseTaxPercent("x")).toBeNull();
  });
  it("round-trips between the form text and the stored rate", () => {
    for (const text of ["", "5", "12", "12.5", "7.25", "99.99"]) {
      expect(taxPercentText(parseTaxPercent(text) ?? -1)).toBe(text);
    }
  });
});

describe("stockStatus and formatQty", () => {
  it("flags out, low and ok, and ignores untracked products", () => {
    expect(stockStatus({ tracked: false, qty: -3, reorderPoint: 5 })).toBe("untracked");
    expect(stockStatus({ tracked: true, qty: 0, reorderPoint: 5 })).toBe("out");
    expect(stockStatus({ tracked: true, qty: -2, reorderPoint: 0 })).toBe("out");
    expect(stockStatus({ tracked: true, qty: 5, reorderPoint: 5 })).toBe("low");
    expect(stockStatus({ tracked: true, qty: 6, reorderPoint: 5 })).toBe("ok");
    expect(stockStatus({ tracked: true, qty: 1, reorderPoint: 0 })).toBe("ok");
  });
  it("prints quantities without trailing zeros", () => {
    expect(formatQty(2)).toBe("2");
    expect(formatQty(1.5)).toBe("1.5");
    expect(formatQty(0.1 + 0.2)).toBe("0.3");
    expect(formatQty(-1.5)).toBe("-1.5");
  });
});
