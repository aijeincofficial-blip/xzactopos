import { describe, expect, it } from "vitest";
import { toSellables } from "./sell-api.ts";

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
