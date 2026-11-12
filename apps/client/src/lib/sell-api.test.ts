import { describe, expect, it } from "vitest";
import { filterSaleRows, toSellables, type SaleRow } from "./sell-api.ts";

const product = (id: string, over: Record<string, unknown> = {}) => ({
  id,
  name: `P-${id}`,
  unit: "pc",
  tax_rate: 0,
  track_stock: true,
  active: true,
  deleted_at: null,
  ...over,
});
const variant = (id: string, productId: string, over: Record<string, unknown> = {}) => ({
  id,
  product_id: productId,
  sku: `SKU-${id}`,
  barcode: null,
  is_default: true,
  cost: 500,
  active: true,
  deleted_at: null,
  ...over,
});
const price = (variantId: string, p: number, over: Record<string, unknown> = {}) => ({ variant_id: variantId, currency: "PHP", price: p, deleted_at: null, ...over });
const page = <T,>(rows: T[]) => ({ rows, cursor: null, has_more: false });

describe("toSellables", () => {
  it("joins product, default variant and base-currency price, sorted by name", () => {
    const out = toSellables(
      {
        products: page([product("b"), product("a", { tax_rate: "0.12" })]),
        product_variants: page([variant("vb", "b"), variant("va", "a")]),
        variant_prices: page([price("vb", 1500), price("va", 2000), price("va", 9, { currency: "USD" })]),
      } as never,
      "PHP",
    );
    expect(out.map((s) => [s.name, s.price, s.taxRate])).toEqual([
      ["P-a", 2000, 0.12],
      ["P-b", 1500, 0],
    ]);
  });

  it("hides inactive, deleted, unpriced and non-default items", () => {
    const out = toSellables(
      {
        products: page([product("a"), product("off", { active: false }), product("gone", { deleted_at: "2026-01-01" }), product("np")]),
        product_variants: page([
          variant("va", "a"),
          variant("voff", "off"),
          variant("vgone", "gone"),
          variant("vnp", "np"),
          variant("vx", "a", { is_default: false }),
          variant("vdel", "a", { deleted_at: "2026-01-01" }),
        ]),
        variant_prices: page([price("va", 100), price("voff", 100), price("vgone", 100), price("vx", 100), price("vdel", 100)]),
      } as never,
      "PHP",
    );
    expect(out.map((s) => s.variantId)).toEqual(["va"]);
  });
});

describe("filterSaleRows", () => {
  const sampleSales: SaleRow[] = [
    {
      id: "s1",
      sale_no: "S01-261112-0001",
      local_no: "WAB-261112-0001",
      status: "completed",
      subtotal: 5000,
      discount: 0,
      total: 5000,
      sold_at: "2026-11-11T17:30:00Z", // 2026-11-12 01:30 in Asia/Manila
      customer_id: "c1",
      location_id: "loc1",
      customer_name: "Aling Rosa",
      payment_methods: ["cash", "utang"],
      refunded_total: 0,
    },
    {
      id: "s2",
      sale_no: "S01-261111-0099",
      local_no: "WAB-261111-0099",
      status: "voided",
      subtotal: 2500,
      discount: 0,
      total: 2500,
      sold_at: "2026-11-11T05:00:00Z", // 2026-11-11 13:00 in Asia/Manila
      customer_id: null,
      location_id: "loc1",
      customer_name: null,
      payment_methods: ["ewallet"],
      refunded_total: 0,
    },
  ];

  it("filters by receipt number, provisional local number, or customer name", () => {
    expect(filterSaleRows(sampleSales, { search: "0001" }).map((s) => s.id)).toEqual(["s1"]);
    expect(filterSaleRows(sampleSales, { search: "wab-261111" }).map((s) => s.id)).toEqual(["s2"]);
    expect(filterSaleRows(sampleSales, { search: "rosa" }).map((s) => s.id)).toEqual(["s1"]);
  });

  it("filters by status, payment method (including split tenders), and business-timezone date", () => {
    expect(filterSaleRows(sampleSales, { status: "voided" }).map((s) => s.id)).toEqual(["s2"]);
    expect(filterSaleRows(sampleSales, { method: "utang" }).map((s) => s.id)).toEqual(["s1"]);
    expect(filterSaleRows(sampleSales, { method: "card" })).toEqual([]);
    expect(
      filterSaleRows(sampleSales, {
        from: "2026-11-12",
        to: "2026-11-12",
        timezone: "Asia/Manila",
      }).map((s) => s.id),
    ).toEqual(["s1"]);
  });
});
