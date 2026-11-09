import { describe, expect, it } from "vitest";
import { getExpiryStatus, toProductRows } from "./stock-api.ts";

const cat = (id: string, name: string, over: Record<string, unknown> = {}) => ({ id, name, parent_id: null, updated_at: "2026-01-01", deleted_at: null, ...over });
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

  it("correctly attaches category, tingi repack links, and expiry dates", () => {
    const rows = toProductRows(
      {
        categories: page([cat("c1", "Beverages"), cat("c_gone", "Old", { deleted_at: "2026-01-01" })]),
        products: page([
          prod("p1", { category_id: "c1" }),
          prod("p2", { category_id: "c_gone" }),
        ]),
        product_variants: page([
          vari("v1", "p1", { breaks_into_variant_id: "v2", breaks_into_qty: 20 }),
          vari("v2", "p2"),
        ]),
        variant_prices: page([]),
      } as never,
      "PHP",
      new Map([["v1", 10], ["v2", 50]]),
      new Map([["v1", "2027-01-01"]]),
    );

    expect(rows[0]!.categoryName).toBe("Beverages");
    expect(rows[0]!.breaksIntoVariantId).toBe("v2");
    expect(rows[0]!.breaksIntoQty).toBe(20);
    expect(rows[0]!.expiresOn).toBe("2027-01-01");

    expect(rows[1]!.categoryName).toBe(null); // deleted category
    expect(rows[1]!.breaksIntoVariantId).toBe(null);
    expect(rows[1]!.expiresOn).toBe(null);
  });
});

describe("getExpiryStatus", () => {
  it("computes status correctly for null, past, near, and future dates", () => {
    expect(getExpiryStatus(null)).toBe("none");
    expect(getExpiryStatus("2020-01-01")).toBe("expired");
    // Date far in the future
    expect(getExpiryStatus("2099-12-31")).toBe("fresh");
    // Date tomorrow
    const tomorrow = new Date(Date.now() + 86400 * 1000).toISOString().slice(0, 10);
    expect(getExpiryStatus(tomorrow)).toBe("expiring_soon");
  });
});
