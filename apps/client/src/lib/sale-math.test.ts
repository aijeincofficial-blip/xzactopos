import { describe, expect, it } from "vitest";
import {
  buildPayments,
  cartSubtotal,
  cartTotal,
  changeDue,
  draftProblem,
  lineTax,
  lineTotal,
  localReceiptNo,
  milli,
  parseAmount,
  salePayload,
  type CartLine,
  type SaleDraft,
} from "./sale-math.ts";

const line = (over: Partial<CartLine> = {}): CartLine => ({
  variantId: "v1",
  name: "Rice",
  qty: 1,
  unitPrice: 1000,
  unitCost: 600,
  taxRate: 0,
  tracked: true,
  ...over,
});

const draft = (over: Partial<SaleDraft> = {}): SaleDraft => ({
  id: "s1",
  localNo: "ABC-261108-0001",
  soldAt: new Date("2026-11-08T09:00:00Z"),
  locationId: "L1",
  discount: 0,
  lines: [line()],
  payments: [{ method: "cash", amount: 1000, tendered: 1000 }],
  ...over,
});

// A BigInt reference with no float anywhere: what the server computes with numeric/bigint.
function refLineTotal(qtyMilli: bigint, price: bigint): bigint {
  return (qtyMilli * price + 500n) / 1000n;
}
function refLineTax(total: bigint, bp: bigint): bigint {
  if (bp <= 0n) return 0n;
  return (total * bp + (10000n + bp) / 2n) / (10000n + bp);
}

// small seeded generator so a failure is reproducible
function rng(seed: number) {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

describe("line math (same centavos as the phone)", () => {
  it("rounds a fractional quantity half up", () => {
    expect(lineTotal(1.5, 1999)).toBe(2999); // 2998.5 rounds up
    expect(lineTotal(0.333, 1000)).toBe(333);
    expect(lineTotal(2, 1250)).toBe(2500);
  });
  it("finds the tax contained in a tax-inclusive price", () => {
    expect(lineTax(112, 0.12)).toBe(12);
    expect(lineTax(1000, 0.12)).toBe(107); // 107.14
    expect(lineTax(1000, 0)).toBe(0);
  });
  it("handles quantities in thousandths without float noise", () => {
    expect(milli(0.1 + 0.2)).toBe(300);
    expect(milli(1.005)).toBe(1005);
  });

  it("matches a BigInt reference for 5000 seeded random lines", () => {
    const r = rng(20261108);
    for (let i = 0; i < 5000; i++) {
      const q = Math.floor(r() * 50_000) / 1000 + 0.001; // 0.001 .. 50
      const price = Math.floor(r() * 5_000_00); // up to 5,000.00
      const rate = [0, 0.05, 0.12, 0.0725][Math.floor(r() * 4)] ?? 0;
      const t = lineTotal(q, price);
      expect(BigInt(t), `qty ${q} price ${price}`).toBe(refLineTotal(BigInt(milli(q)), BigInt(price)));
      expect(BigInt(lineTax(t, rate)), `total ${t} rate ${rate}`).toBe(refLineTax(BigInt(t), BigInt(Math.round(rate * 10000))));
      expect(lineTax(t, rate)).toBeLessThanOrEqual(t);
    }
  });
});

describe("cart totals and checks", () => {
  it("adds lines, takes the discount off, and gives change", () => {
    const lines = [line({ qty: 2, unitPrice: 1250 }), line({ variantId: "v2", qty: 1.5, unitPrice: 1999 })];
    expect(cartSubtotal(lines)).toBe(2500 + 2999);
    expect(cartTotal(lines, 499)).toBe(5000);
    expect(changeDue(5000, 4500)).toBe(500);
    expect(changeDue(4000, 4500)).toBe(0);
  });

  it("accepts a normal cash sale", () => {
    expect(draftProblem(draft())).toBeNull();
  });
  it("refuses what the server would refuse", () => {
    expect(draftProblem(draft({ lines: [] }))).toBe("empty");
    expect(draftProblem(draft({ discount: 1001 }))).toBe("discount_invalid");
    expect(draftProblem(draft({ discount: -1 }))).toBe("discount_invalid");
    expect(draftProblem(draft({ payments: [{ method: "cash", amount: 900, tendered: 900 }] }))).toBe("payments_mismatch");
    expect(draftProblem(draft({ payments: [{ method: "cash", amount: 1000, tendered: 500 }] }))).toBe("tendered_too_low");
    expect(draftProblem(draft({ payments: [{ method: "utang", amount: 1000 }] }))).toBe("customer_required");
    expect(draftProblem(draft({ lines: [line({ qty: 0 })] }))).toBe("qty_invalid");
  });
  it("lets utang through when a customer is chosen, and a split sale cover the total", () => {
    const split = draft({
      customerId: "c1",
      payments: [
        { method: "cash", amount: 600, tendered: 1000 },
        { method: "utang", amount: 400 },
      ],
    });
    expect(draftProblem(split)).toBeNull();
  });
});

describe("buildPayments", () => {
  it("pays the whole total by the chosen method", () => {
    expect(buildPayments(1000, { method: "cash", paidNow: null, tendered: null })).toEqual([{ method: "cash", amount: 1000, tendered: 1000 }]);
    expect(buildPayments(1000, { method: "cash", paidNow: null, tendered: 1500 })).toEqual([{ method: "cash", amount: 1000, tendered: 1500 }]);
    expect(buildPayments(1000, { method: "ewallet", paidNow: null, tendered: null, wallet: "maya", reference: "R" })).toEqual([
      { method: "ewallet", amount: 1000, wallet: "maya", reference: "R" },
    ]);
    expect(buildPayments(1000, { method: "card", paidNow: null, tendered: null, reference: "AUTH-123" })).toEqual([
      { method: "card", amount: 1000, reference: "AUTH-123" },
    ]);
  });
  it("puts the whole sale on utang, or only what is left unpaid", () => {
    expect(buildPayments(1000, { method: "utang", paidNow: null, tendered: null })).toEqual([{ method: "utang", amount: 1000 }]);
    expect(buildPayments(1000, { method: "cash", paidNow: 600, tendered: 1000 })).toEqual([
      { method: "cash", amount: 600, tendered: 1000 },
      { method: "utang", amount: 400 },
    ]);
    expect(buildPayments(1000, { method: "cash", paidNow: 0, tendered: null })).toEqual([{ method: "utang", amount: 1000 }]);
  });
  it("refuses an amount above the total or below zero, and handles a zero total", () => {
    expect(buildPayments(1000, { method: "cash", paidNow: 1001, tendered: null })).toBeNull();
    expect(buildPayments(1000, { method: "cash", paidNow: -1, tendered: null })).toBeNull();
    expect(buildPayments(0, { method: "cash", paidNow: null, tendered: null })).toEqual([]);
    expect(buildPayments(-5, { method: "cash", paidNow: null, tendered: null })).toBeNull();
  });
  it("always adds up to the total for 2000 seeded random choices", () => {
    const r = rng(99);
    for (let i = 0; i < 2000; i++) {
      const total = Math.floor(r() * 500_000) + 1;
      const paidNow = r() < 0.3 ? null : Math.floor(r() * (total + 1));
      const method = (["cash", "ewallet", "card", "utang"] as const)[Math.floor(r() * 4)] ?? "cash";
      const pays = buildPayments(total, { method, paidNow, tendered: null });
      expect(pays).not.toBeNull();
      expect((pays ?? []).reduce((a, p) => a + p.amount, 0), `${method} ${total} ${paidNow}`).toBe(total);
      expect((pays ?? []).every((p) => p.amount > 0)).toBe(true);
    }
  });
});

describe("record_sale payload", () => {
  it("is internally consistent for 500 seeded random sales (what op_record_sale verifies)", () => {
    const r = rng(7);
    for (let i = 0; i < 500; i++) {
      const lines = Array.from({ length: 1 + Math.floor(r() * 6) }, (_, j) =>
        line({ variantId: `v${j}`, qty: Math.floor(r() * 9000) / 1000 + 0.001, unitPrice: Math.floor(r() * 99_900), taxRate: r() < 0.5 ? 0 : 0.12 }),
      );
      const sub = cartSubtotal(lines);
      const discount = Math.floor(r() * (sub + 1));
      const total = sub - discount;
      const d = draft({ lines, discount, payments: [{ method: "cash", amount: total, tendered: total + 50 }] });
      expect(draftProblem(d)).toBeNull();
      const p = salePayload(d) as {
        subtotal: number;
        total: number;
        items: Array<{ line_total: number; tax: number }>;
        payments: Array<{ amount: number }>;
      };
      expect(p.items.reduce((a, it) => a + it.line_total, 0)).toBe(p.subtotal);
      expect(p.total).toBe(p.subtotal - discount);
      expect(p.payments.reduce((a, x) => a + x.amount, 0)).toBe(p.total);
      for (const it of p.items) expect(it.tax).toBeLessThanOrEqual(it.line_total);
    }
  });

  it("carries the optional fields only when present, like the phone", () => {
    const p = salePayload(draft({ deviceId: "dev-1", customerId: "c1" }));
    expect(p).toMatchObject({ device_id: "dev-1", customer_id: "c1", location_id: "L1", local_no: "ABC-261108-0001" });
    const bare = salePayload(draft());
    expect("device_id" in bare).toBe(false);
    expect("customer_id" in bare).toBe(false);
    const wallet = salePayload(draft({ payments: [{ method: "ewallet", amount: 1000, wallet: "gcash", reference: "R1" }] })) as {
      payments: Array<Record<string, unknown>>;
    };
    expect(wallet.payments[0]).toEqual({ method: "ewallet", amount: 1000, reference: "R1", wallet: "gcash" });
  });

  it("builds the provisional receipt number", () => {
    expect(localReceiptNo("ABC", "2026-11-08", 7)).toBe("ABC-261108-0007");
    expect(localReceiptNo("ABC", "2026-11-08", 12345)).toBe("ABC-261108-12345");
  });

  it("reads typed amounts exactly, with no float rounding", () => {
    expect(parseAmount("125.50", "PHP")).toBe(12550);
    expect(parseAmount("0.1", "PHP")).toBe(10);
    expect(parseAmount("19.99", "PHP")).toBe(1999);
    expect(parseAmount("", "PHP")).toBe(0);
    expect(parseAmount("1.234", "PHP")).toBeNull(); // more decimals than the currency has
    expect(parseAmount("-5", "PHP")).toBeNull();
    expect(parseAmount("abc", "PHP")).toBeNull();
    expect(parseAmount("500", "JPY")).toBe(500);
  });
});
