import { describe, expect, it } from "vitest";
import { toProductRows } from "./stock-api.ts";

const prod = (id: string, over: Record<string, unknown> = {}) => ({ id, name: `P-${id}`, unit: "pc", tax_rate: "0.1200", track_stock: true, active: true, deleted_at: null, ...over });
const vari = (id: string, productId: string, over: Record<string, unknown> = {}) => ({ id, product_id: productId, sku: `S-${id}`, barcode: null, is_default: true, cost: 500, reorder_point: "5.000", active: true, deleted_at: null, ...over });
const price = (variantId: string, p: number, over: Record<string, unknown> = {}) => ({ variant_id: variantId, currency: "PHP", price: p, deleted_at: null, ...over });
const page = <T,>(rows: T[]) => ({ rows, cursor: null, has_more: false });

describe("toProductRows", () => {
  it("joins price and the store's stock level, keeps unpriced and inactive products, sorted by name", () => {
    const rows = toProductRows(
      {
        products: page([prod("b"), prod("a", { active: false }), prod("np")]),
        product_variants: page([vari("vb", "b"), vari("va", "a"), vari("vnp", "np")]),
        variant_prices: page([price("vb", 1500), price("va", 2000), price("vb", 9, { currency: "USD" })]),
      } as never,
      "PHP",
      new Map([["vb", 7.5]]),
    );
    expect(rows.map((r) => [r.name, r.price, r.qty, r.active, r.reorderPoint, r.taxRate])).toEqual([
      ["P-a", 2000, 0, false, 5, 0.12],
      ["P-b", 1500, 7.5, true, 5, 0.12],
      ["P-np", null, 0, true, 5, 0.12],
    ]);
  });

  it("leaves out archived products, deleted and non-default variants", () => {
    const rows = toProductRows(
      {
        products: page([prod("a"), prod("gone", { deleted_at: "2026-01-01" })]),
        product_variants: page([vari("va", "a"), vari("vg", "gone"), vari("vx", "a", { is_default: false }), vari("vd", "a", { deleted_at: "2026-01-01" })]),
        variant_prices: page([]),
      } as never,
      "PHP",
      new Map(),
    );
    expect(rows.map((r) => r.variantId)).toEqual(["va"]);
  });
});