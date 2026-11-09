import { describe, expect, it } from "vitest";
import {
  buildPoItems,
  buildReceiveItems,
  lineValue,
  poActions,
  poProgress,
  poStatusTone,
  remainingQty,
} from "./purchasing-math.ts";

const V1 = "11111111-1111-4111-8111-111111111111";
const V2 = "22222222-2222-4222-8222-222222222222";

describe("remainingQty", () => {
  it("is what is still expected, never below zero (over-delivery is not negative)", () => {
    expect(remainingQty({ qty_ordered: 100, qty_received: 40 })).toBe(60);
    expect(remainingQty({ qty_ordered: 10, qty_received: 15 })).toBe(0);
    expect(remainingQty({ qty_ordered: 2.5, qty_received: 0.5 })).toBe(2);
  });
});

describe("poProgress", () => {
  it("sums ordered, received and remaining across lines", () => {
    const p = poProgress([
      { qty_ordered: 100, qty_received: 60 },
      { qty_ordered: 20, qty_received: 20 },
    ]);
    expect(p).toEqual({ ordered: 120, received: 80, remaining: 40, percent: 67 });
  });
  it("does not let a surplus on one line make up for a gap on another", () => {
    const p = poProgress([
      { qty_ordered: 10, qty_received: 15 },
      { qty_ordered: 10, qty_received: 0 },
    ]);
    expect(p.remaining).toBe(10);
    expect(p.received).toBe(15);
    expect(p.percent).toBe(50);
  });
  it("is 0% for an empty order", () => {
    expect(poProgress([])).toEqual({ ordered: 0, received: 0, remaining: 0, percent: 0 });
  });
});

describe("lineValue", () => {
  it("multiplies quantity by cost exactly, half up (centavos)", () => {
    expect(lineValue(70, 1000)).toBe(70000);
    expect(lineValue(2.5, 1001)).toBe(2503); // 2502.5 rounds up
    expect(lineValue(0.001, 1500)).toBe(2); // 1.5 rounds up
    expect(lineValue(3, null)).toBeNull();
  });
});

describe("poStatusTone and poActions", () => {
  it("colours the status", () => {
    expect(poStatusTone("received")).toBe("good");
    expect(poStatusTone("partly_received")).toBe("warn");
    expect(poStatusTone("ordered")).toBe("neutral");
    expect(poStatusTone("cancelled")).toBe("neutral");
  });
  it("offers only what the server will accept", () => {
    expect(poActions("draft", false)).toEqual({ submit: true, cancel: true, receive: false, close: false });
    expect(poActions("ordered", false)).toEqual({ submit: false, cancel: true, receive: true, close: false });
    expect(poActions("partly_received", true)).toEqual({ submit: false, cancel: false, receive: true, close: true });
    expect(poActions("received", true)).toEqual({ submit: false, cancel: false, receive: false, close: false });
    expect(poActions("cancelled", false)).toEqual({ submit: false, cancel: false, receive: false, close: false });
  });
});

describe("buildPoItems", () => {
  it("turns typed lines into the RPC payload (cost in pesos becomes centavos)", () => {
    const r = buildPoItems(
      [
        { variantId: V1, qtyText: "100", costText: "12.50" },
        { variantId: V2, qtyText: "2.5", costText: "" },
      ],
      "PHP",
    );
    expect(r.ok).toBe(true);
    expect(r.items).toEqual([
      { variant_id: V1, qty: 100, unit_cost: 1250 },
      { variant_id: V2, qty: 2.5 },
    ]);
  });
  it("ignores completely blank rows but flags half-filled ones", () => {
    const r = buildPoItems(
      [
        { variantId: "", qtyText: "", costText: "" },
        { variantId: V1, qtyText: "", costText: "" },
        { variantId: "", qtyText: "5", costText: "" },
      ],
      "PHP",
    );
    expect(r.ok).toBe(false);
    expect(r.rowErrors).toEqual([null, "qty_invalid", "product_required"]);
  });
  it("rejects zero, negative, too precise and absurd quantities", () => {
    for (const q of ["0", "-1", "1.2345", "1000000000", "abc"]) {
      const r = buildPoItems([{ variantId: V1, qtyText: q, costText: "" }], "PHP");
      expect(r.rowErrors[0], q).toBe("qty_invalid");
    }
  });
  it("rejects a bad or negative cost, and a cost with too many decimals", () => {
    for (const c of ["abc", "-5", "1.234", "1,5"]) {
      const r = buildPoItems([{ variantId: V1, qtyText: "1", costText: c }], "PHP");
      expect(r.rowErrors[0], c).toBe("cost_invalid");
    }
  });
  it("flags the second use of the same product", () => {
    const r = buildPoItems(
      [
        { variantId: V1, qtyText: "1", costText: "" },
        { variantId: V1, qtyText: "2", costText: "" },
      ],
      "PHP",
    );
    expect(r.rowErrors).toEqual([null, "duplicate_item"]);
    expect(r.ok).toBe(false);
  });
  it("is not ok when nothing was entered", () => {
    const r = buildPoItems([{ variantId: "", qtyText: "", costText: "" }], "PHP");
    expect(r.ok).toBe(false);
    expect(r.items).toEqual([]);
    expect(r.empty).toBe(true);
  });
});

describe("buildReceiveItems", () => {
  const rows = [
    { variantId: V1, remaining: 60, qtyText: "", costText: "" },
    { variantId: V2, remaining: 20, qtyText: "", costText: "" },
  ];
  it("sends only the lines that actually arrived", () => {
    const r = buildReceiveItems(
      [
        { ...rows[0]!, qtyText: "40", costText: "10.50" },
        { ...rows[1]! },
      ],
      "PHP",
    );
    expect(r.ok).toBe(true);
    expect(r.items).toEqual([{ variant_id: V1, qty: 40, unit_cost: 1050 }]);
    expect(r.hasOver).toBe(false);
  });
  it("warns about over-delivery but still allows it", () => {
    const r = buildReceiveItems([{ ...rows[0]!, qtyText: "65" }, { ...rows[1]!, qtyText: "20" }], "PHP");
    expect(r.ok).toBe(true);
    expect(r.over).toEqual([true, false]);
    expect(r.hasOver).toBe(true);
  });
  it("is not ok when nothing arrived or a quantity is wrong", () => {
    expect(buildReceiveItems(rows, "PHP").ok).toBe(false);
    expect(buildReceiveItems(rows, "PHP").empty).toBe(true);
    const bad = buildReceiveItems([{ ...rows[0]!, qtyText: "0" }], "PHP");
    expect(bad.ok).toBe(false);
    expect(bad.rowErrors).toEqual(["qty_invalid"]);
  });
  it("leaves the cost out when the field is blank so the server uses the order's cost", () => {
    const r = buildReceiveItems([{ ...rows[0]!, qtyText: "5" }], "PHP");
    expect(r.items).toEqual([{ variant_id: V1, qty: 5 }]);
  });
});
