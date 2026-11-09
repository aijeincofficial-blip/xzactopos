import { describe, expect, it } from "vitest";
import {
  buildCountItems,
  countActions,
  countStatusTone,
  mergeCountRows,
  rowKey,
  summarizeVariance,
  variance,
} from "./counts-math.ts";

const V1 = "11111111-1111-4111-8111-111111111111";
const V2 = "22222222-2222-4222-8222-222222222222";
const V3 = "33333333-3333-4333-8333-333333333333";
const B1 = "b1b1b1b1-b1b1-41b1-81b1-b1b1b1b1b1b1";
const B2 = "b2b2b2b2-b2b2-42b2-82b2-b2b2b2b2b2b2";

describe("rowKey", () => {
  it("identifies a spot by product and bin", () => {
    expect(rowKey(V1, null)).toBe(`${V1}:-`);
    expect(rowKey(V1, B1)).not.toBe(rowKey(V1, B2));
    expect(rowKey(V1, B1)).not.toBe(rowKey(V2, B1));
  });
});

describe("variance", () => {
  it("is counted minus the system quantity at count time", () => {
    expect(variance(97, 100)).toBe(-3);
    expect(variance(9, 7)).toBe(2);
    expect(variance(5, 5)).toBe(0);
    expect(variance(0.3, 0.1)).toBe(0.2); // no float noise
  });
});

describe("mergeCountRows", () => {
  const system = [
    { variantId: V1, binId: null, qty: 100 },
    { variantId: V2, binId: null, qty: 20 },
  ];
  it("shows what the system holds, with nothing counted yet", () => {
    const rows = mergeCountRows(system, [], [], null);
    expect(rows.map((r) => [r.variantId, r.systemNow, r.saved])).toEqual([
      [V1, 100, null],
      [V2, 20, null],
    ]);
  });
  it("attaches the saved line and keeps its snapshot separate from the live quantity", () => {
    const rows = mergeCountRows(system, [{ variantId: V1, binId: null, qtySystem: 90, qtyCounted: 97, autoZero: false }], [], null);
    const r = rows.find((x) => x.variantId === V1)!;
    expect(r.systemNow).toBe(100);
    expect(r.saved).toEqual({ variantId: V1, binId: null, qtySystem: 90, qtyCounted: 97, autoZero: false });
  });
  it("includes a counted product the system does not hold (found stock), with a live quantity of 0", () => {
    const rows = mergeCountRows(system, [{ variantId: V3, binId: null, qtySystem: 0, qtyCounted: 4, autoZero: false }], [], null);
    const r = rows.find((x) => x.variantId === V3)!;
    expect(r.systemNow).toBe(0);
    expect(r.saved?.qtyCounted).toBe(4);
  });
  it("adds rows the user chose to add, once, even if already present", () => {
    const rows = mergeCountRows(system, [], [{ variantId: V3, binId: null }, { variantId: V1, binId: null }, { variantId: V3, binId: null }], null);
    expect(rows.map((r) => r.variantId).sort()).toEqual([V1, V2, V3].sort());
  });
  it("keeps bins apart: the same product in two bins is two rows", () => {
    const rows = mergeCountRows(
      [
        { variantId: V1, binId: B1, qty: 30 },
        { variantId: V1, binId: B2, qty: 18 },
      ],
      [],
      [],
      null,
    );
    expect(rows).toHaveLength(2);
  });
  it("limits a one-bin count to that bin", () => {
    const rows = mergeCountRows(
      [
        { variantId: V1, binId: B1, qty: 30 },
        { variantId: V1, binId: B2, qty: 18 },
      ],
      [],
      [{ variantId: V2, binId: B2 }],
      B1,
    );
    expect(rows.map((r) => r.binId)).toEqual([B1]);
  });
});

describe("buildCountItems", () => {
  it("sends only the rows that were typed, 0 allowed (the shelf is empty)", () => {
    const r = buildCountItems(
      [
        { variantId: V1, binId: null, qtyText: "97" },
        { variantId: V2, binId: null, qtyText: "" },
        { variantId: V3, binId: null, qtyText: "0" },
      ],
      false,
    );
    expect(r.ok).toBe(true);
    expect(r.items).toEqual([
      { variant_id: V1, qty_counted: 97 },
      { variant_id: V3, qty_counted: 0 },
    ]);
  });
  it("sends the bin when the warehouse uses bins and refuses a row with no bin", () => {
    const ok = buildCountItems([{ variantId: V1, binId: B1, qtyText: "5" }], true);
    expect(ok.items).toEqual([{ variant_id: V1, qty_counted: 5, bin_id: B1 }]);
    const bad = buildCountItems([{ variantId: V1, binId: null, qtyText: "5" }], true);
    expect(bad.ok).toBe(false);
    expect(bad.rowErrors).toEqual(["bin_required"]);
  });
  it("rejects negative, too precise and non-numeric quantities", () => {
    for (const q of ["-1", "1.2345", "abc", "1000000000", "1,5"]) {
      const r = buildCountItems([{ variantId: V1, binId: null, qtyText: q }], false);
      expect(r.rowErrors[0], q).toBe("qty_invalid");
    }
  });
  it("accepts decimals for products sold by weight", () => {
    expect(buildCountItems([{ variantId: V1, binId: null, qtyText: "2.5" }], false).items[0]?.qty_counted).toBe(2.5);
  });
  it("is empty when nothing was typed", () => {
    const r = buildCountItems([{ variantId: V1, binId: null, qtyText: "  " }], false);
    expect(r.ok).toBe(false);
    expect(r.empty).toBe(true);
  });
});

describe("summarizeVariance", () => {
  it("counts the lines that will move stock and splits shortage from surplus", () => {
    const s = summarizeVariance([
      { qtySystem: 100, qtyCounted: 97 },
      { qtySystem: 7, qtyCounted: 9 },
      { qtySystem: 20, qtyCounted: 20 },
      { qtySystem: 10, qtyCounted: 4 },
    ]);
    expect(s).toEqual({ lines: 4, corrections: 3, shortage: -9, surplus: 2, net: -7 });
  });
  it("is all zeros for no lines", () => {
    expect(summarizeVariance([])).toEqual({ lines: 0, corrections: 0, shortage: 0, surplus: 0, net: 0 });
  });
});

describe("status helpers", () => {
  it("colours counts and offers only what is possible", () => {
    expect(countStatusTone("open")).toBe("warn");
    expect(countStatusTone("closed")).toBe("good");
    expect(countStatusTone("cancelled")).toBe("neutral");
    expect(countActions("open")).toEqual({ record: true, close: true, cancel: true });
    expect(countActions("closed")).toEqual({ record: false, close: false, cancel: false });
    expect(countActions("cancelled")).toEqual({ record: false, close: false, cancel: false });
  });
});
