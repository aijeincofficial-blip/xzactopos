import { describe, expect, it } from "vitest";
import { filterAndGroupSellables, filterSaleRows, groupSellableProducts, toSellables, type SaleRow } from "./sell-api.ts";

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

  it("includes active priced default and non-default variants and hides inactive, deleted, and unpriced items", () => {
    const out = toSellables(
      {
        products: page([product("a"), product("off", { active: false }), product("gone", { deleted_at: "2026-01-01" }), product("np")]),
        product_variants: page([
          variant("va", "a", { name: "Regular", sku: "A-REG" }),
          variant("voff", "off"),
          variant("vgone", "gone"),
          variant("vnp", "np"),
          variant("vx", "a", { name: "Large", sku: "A-LRG", is_default: false }),
          variant("vdel", "a", { deleted_at: "2026-01-01" }),
        ]),
        variant_prices: page([price("va", 100), price("voff", 100), price("vgone", 100), price("vx", 150), price("vdel", 100)]),
      } as never,
      "PHP",
    );
    expect(out.map((s) => s.variantId)).toEqual(["va", "vx"]);
    expect(out.map((s) => s.name)).toEqual(["P-a (Regular)", "P-a (Large)"]);
    const grouped = groupSellableProducts(out);
    expect(grouped).toHaveLength(1);
    expect(grouped[0]?.primary.variantId).toBe("va");
    expect(grouped[0]?.variants.map((v) => v.variantId)).toEqual(["va", "vx"]);
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

describe("filterAndGroupSellables", () => {
  it("groups multi-variant products before slicing and searches across a 2000-variant catalog", () => {
    const products = Array.from({ length: 1000 }, (_, i) => product(`p${i}`, { name: `Item ${String(i).padStart(4, "0")}`, category_id: i % 2 === 0 ? "cat-even" : "cat-odd" }));
    const variants = products.flatMap((p, i) => [
      variant(`v${i}a`, p.id, { name: "Small", sku: `SKU-${i}-A`, is_default: true }),
      variant(`v${i}b`, p.id, { name: "Large", sku: `SKU-${i}-B`, is_default: false }),
    ]);
    const prices = variants.map((v) => price(v.id, 1000));

    const sellables = toSellables(
      { products: page(products), product_variants: page(variants), variant_prices: page(prices) } as never,
      "PHP",
    );
    expect(sellables).toHaveLength(2000);
    expect(sellables[0]?.searchText).toContain("item 0000");

    const topGroups = filterAndGroupSellables(sellables, { maxGroups: 80 });
    expect(topGroups).toHaveLength(80);
    // Every group keeps both of its variants rather than getting split at a variant slice boundary
    expect(topGroups.every((g) => g.variants.length === 2)).toBe(true);

    const lateHit = filterAndGroupSellables(sellables, { query: "SKU-999-B", maxGroups: 80 });
    expect(lateHit).toHaveLength(1);
    expect(lateHit[0]?.productId).toBe("p999");

    const catFiltered = filterAndGroupSellables(sellables, { categoryId: "cat-odd", maxGroups: 80 });
    expect(catFiltered).toHaveLength(80);
    expect(catFiltered.every((g) => g.primary.categoryId === "cat-odd")).toBe(true);
  });
});
