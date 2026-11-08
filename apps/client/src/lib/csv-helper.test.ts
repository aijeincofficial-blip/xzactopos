import { describe, expect, it } from "vitest";
import { exportProductsCsv, parseAndValidateImport, parseCsv } from "./csv-helper.ts";
import type { ProductRow } from "./stock-api.ts";

describe("csv-helper", () => {
  it("exports product rows to CSV with proper quoting", () => {
    const rows: ProductRow[] = [
      {
        productId: "p1",
        variantId: "v1",
        name: 'Coke, 1.5L "Bottle"',
        sku: "COKE-15",
        barcode: "123456",
        unit: "btl",
        price: 7550, // 75.50
        cost: 6000,  // 60.00
        reorderPoint: 10,
        taxRate: 0.12,
        tracked: true,
        active: true,
        qty: 24,
        categoryId: "c1",
        categoryName: "Drinks, Cold",
        breaksIntoVariantId: null,
        breaksIntoQty: null,
        expiresOn: "2026-12-31",
      },
    ];

    const csv = exportProductsCsv(rows, "PHP");
    expect(csv).toContain('"Coke, 1.5L ""Bottle"""');
    expect(csv).toContain('"Drinks, Cold"');
    expect(csv).toContain("75.50");
    expect(csv).toContain("60.00");
    expect(csv).toContain("2026-12-31");
  });

  it("parses CSV grid handling commas inside quotes and escaped quotes", () => {
    const input = 'Name,Price\r\n"Item, with comma",25.00\r\n"Item with ""quote""",10.50';
    const grid = parseCsv(input);
    expect(grid).toEqual([
      ["Name", "Price"],
      ["Item, with comma", "25.00"],
      ['Item with "quote"', "10.50"],
    ]);
  });

  it("validates import rows and reports errors for invalid inputs", () => {
    const csv = [
      "Name,Price,Cost,OnHand,Tracked,ExpiresOn",
      "Valid Item,15.50,10.00,5,true,2027-01-01",
      ",10.00,5.00,0,true,", // Missing name
      "Bad Price,invalid,5.00,0,true,", // Bad price
    ].join("\n");

    const result = parseAndValidateImport(csv);
    expect(result.valid.length).toBe(1);
    expect(result.valid[0]!.name).toBe("Valid Item");
    expect(result.valid[0]!.price).toBe(1550);
    expect(result.valid[0]!.cost).toBe(1000);
    expect(result.valid[0]!.openingQty).toBe(5);
    expect(result.valid[0]!.expiresOn).toBe("2027-01-01");

    expect(result.errors.length).toBe(2);
    expect(result.errors[0]!).toContain("Line 3: Missing product name");
    expect(result.errors[1]!).toContain("Line 4: Invalid price");
  });
});
