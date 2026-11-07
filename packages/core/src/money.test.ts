import { describe, expect, it } from "vitest";
import {
  add, allocate, convert, formatMoney, fromMajor, money, multiply, negate, roundToInt, sub, toMajorNumber,
} from "./money.ts";

const NBSP = String.fromCharCode(160);
const fmt = (m: ReturnType<typeof money>, locale: string) =>
  formatMoney(m, locale).split(NBSP).join(" ");

describe("formatMoney: 3 currencies x 2 locales", () => {
  const cases: Array<[string, number, string, string]> = [
    // currency, minor, locale, expected
    ["USD", 123456, "en", "$1,234.56"],
    ["USD", 123456, "fil", "$1,234.56"],
    ["JPY", 123456, "en", "¥123,456"],
    ["JPY", 123456, "fil", "¥123,456"],
    ["KWD", 123456, "en", "KWD 123.456"],
    ["KWD", 123456, "fil", "KWD 123.456"],
    ["PHP", 123456, "fil", "₱1,234.56"],
  ];
  it.each(cases)("%s %i in %s -> %s", (cur, minor, loc, expected) => {
    expect(fmt(money(minor, cur), loc)).toBe(expected);
  });

  it("uses the exponent table: JPY 0, USD 2, KWD 3 decimals", () => {
    expect(fmt(money(5, "JPY"), "en")).toBe("¥5");
    expect(fmt(money(5, "USD"), "en")).toBe("$0.05");
    expect(fmt(money(5, "KWD"), "en")).toBe("KWD 0.005");
  });

  it("follows locale separators (de-DE)", () => {
    expect(fmt(money(123456, "USD"), "de-DE")).toBe("1.234,56 $");
  });
});

describe("construction and parsing", () => {
  it("rejects non-integer minor units", () => {
    expect(() => money(1.5, "USD")).toThrow(RangeError);
    expect(() => money(NaN, "USD")).toThrow(RangeError);
    expect(() => money(100, "usd")).toThrow(RangeError);
  });
  it("parses decimal strings exactly (no float drift)", () => {
    expect(fromMajor("1.005", "KWD")).toEqual(money(1005, "KWD"));
    expect(fromMajor("0.10", "USD")).toEqual(money(10, "USD"));
    expect(fromMajor("-12.3", "USD")).toEqual(money(-1230, "USD"));
    expect(fromMajor("500", "JPY")).toEqual(money(500, "JPY"));
  });
  it("rejects too many decimals and bad input", () => {
    expect(() => fromMajor("1.005", "USD")).toThrow(RangeError);
    expect(() => fromMajor("1.5", "JPY")).toThrow(RangeError);
    expect(() => fromMajor("abc", "USD")).toThrow(SyntaxError);
    expect(() => fromMajor("1.00", "XXX")).toThrow(RangeError);
  });
  it("toMajorNumber is for display only", () => {
    expect(toMajorNumber(money(123456, "KWD"))).toBe(123.456);
  });
});

describe("arithmetic", () => {
  it("adds and subtracts in the same currency", () => {
    expect(add(money(10, "USD"), money(5, "USD"))).toEqual(money(15, "USD"));
    expect(sub(money(10, "USD"), money(15, "USD"))).toEqual(money(-5, "USD"));
    expect(negate(money(0, "USD")).amount).toBe(0);
  });
  it("refuses cross-currency arithmetic", () => {
    expect(() => add(money(1, "USD"), money(1, "PHP"))).toThrow(TypeError);
  });
  it("multiplies with half-up rounding", () => {
    expect(multiply(money(1999, "USD"), 3)).toEqual(money(5997, "USD"));
    expect(multiply(money(1050, "USD"), 0.12)).toEqual(money(126, "USD"));
    expect(multiply(money(5, "USD"), 0.5)).toEqual(money(3, "USD")); // 2.5 -> 3
    expect(multiply(money(-5, "USD"), 0.5)).toEqual(money(-3, "USD")); // away from zero
  });
  it("supports other rounding modes", () => {
    expect(roundToInt(2.5, "half-even")).toBe(2);
    expect(roundToInt(3.5, "half-even")).toBe(4);
    expect(roundToInt(2.1, "ceil")).toBe(3);
    expect(roundToInt(2.9, "floor")).toBe(2);
  });
  it("allocates without losing minor units", () => {
    const parts = allocate(money(100, "USD"), 3);
    expect(parts.map((p) => p.amount)).toEqual([34, 33, 33]);
    expect(parts.reduce((s, p) => s + p.amount, 0)).toBe(100);
    expect(allocate(money(-100, "USD"), 3).map((p) => p.amount)).toEqual([-34, -33, -33]);
  });
});

describe("convert across exponents", () => {
  it("USD -> JPY (2 -> 0 decimals)", () => {
    // $10.00 at 150 JPY/USD = 1500 yen
    expect(convert(money(1000, "USD"), "JPY", 150)).toEqual(money(1500, "JPY"));
  });
  it("JPY -> KWD (0 -> 3 decimals)", () => {
    // 1000 yen at 0.002 KWD/JPY = 2.000 KWD
    expect(convert(money(1000, "JPY"), "KWD", 0.002)).toEqual(money(2000, "KWD"));
  });
  it("PHP -> USD rounds to cents", () => {
    // 1,000.00 PHP at 0.0173 = 17.30 USD
    expect(convert(money(100000, "PHP"), "USD", 0.0173)).toEqual(money(1730, "USD"));
  });
  it("rejects bad rates", () => {
    expect(() => convert(money(1, "USD"), "PHP", 0)).toThrow(RangeError);
  });
});
