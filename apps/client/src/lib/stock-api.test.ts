import { describe, expect, it } from "vitest";
import { classifyMovementCategory, getExpiryStatus, toProductRows, toStockMovementRows } from "./stock-api.ts";

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

  it("applies per-location reorder point overrides while preserving catalog default", () => {
    const rows = toProductRows(
      {
        products: page([prod("p1"), prod("p2")]),
        product_variants: page([
          vari("v1", "p1", { reorder_point: "5.000" }),
          vari("v2", "p2", { reorder_point: "10.000" }),
        ]),
        variant_prices: page([]),
      } as never,
      "PHP",
      new Map([["v1", 8], ["v2", 8]]),
      undefined,
      new Map([["v1", 15]]),
    );

    expect(rows[0]!.reorderPoint).toBe(15);
    expect(rows[0]!.defaultReorderPoint).toBe(5);
    expect(rows[0]!.isReorderOverride).toBe(true);

    expect(rows[1]!.reorderPoint).toBe(10);
    expect(rows[1]!.defaultReorderPoint).toBe(10);
    expect(rows[1]!.isReorderOverride).toBe(false);
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

describe("stock movement ledger helpers", () => {
  it("classifies every movement type into its filter category", () => {
    expect(classifyMovementCategory("sale")).toBe("sales");
    expect(classifyMovementCategory("sale_return")).toBe("sales");
    expect(classifyMovementCategory("sale_void")).toBe("sales");
    expect(classifyMovementCategory("transfer_in")).toBe("transfers");
    expect(classifyMovementCategory("transfer_out")).toBe("transfers");
    expect(classifyMovementCategory("bin_move")).toBe("transfers");
    expect(classifyMovementCategory("opening")).toBe("restock");
    expect(classifyMovementCategory("receipt")).toBe("restock");
    expect(classifyMovementCategory("count_correction")).toBe("adjustments");
    expect(classifyMovementCategory("damage")).toBe("adjustments");
    expect(classifyMovementCategory("conversion_in")).toBe("adjustments");
  });

  it("joins catalog product names and SKUs onto raw movement rows", () => {
    const pull = {
      products: page([prod("p1", { name: "Nescafe 3-in-1", unit: "sachet" })]),
      product_variants: page([vari("v1", "p1", { sku: "NES-01" })]),
      variant_prices: page([]),
    } as never;

    const rows = toStockMovementRows(
      [
        {
          id: "m1",
          variant_id: "v1",
          qty_delta: "24.000",
          type: "transfer_in",
          ref_type: "transfer",
          occurred_at: "2026-11-11T04:00:00Z",
        },
        {
          id: "m2",
          variant_id: "unknown-variant-id",
          qty_delta: "-2",
          type: "sale",
          ref_type: "sale",
          occurred_at: "2026-11-11T04:05:00Z",
        },
      ],
      pull,
    );

    expect(rows).toEqual([
      {
        id: "m1",
        variantId: "v1",
        productName: "Nescafe 3-in-1",
        sku: "NES-01",
        unit: "sachet",
        qtyDelta: 24,
        type: "transfer_in",
        category: "transfers",
        occurredAt: "2026-11-11T04:00:00Z",
      },
      {
        id: "m2",
        variantId: "unknown-variant-id",
        productName: "unknown-",
        sku: "—",
        unit: "pc",
        qtyDelta: -2,
        type: "sale",
        category: "sales",
        occurredAt: "2026-11-11T04:05:00Z",
      },
    ]);
  });
});
