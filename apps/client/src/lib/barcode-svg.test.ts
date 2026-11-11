import { describe, expect, it } from "vitest";
import { encodeCode128, CODE128_PATTERNS } from "./barcode-svg.tsx";
import {
  buildPrintItems,
  formatBinBarcodeItem,
  type BarcodeProduct,
} from "../components/barcode-labels-dialog.tsx";

describe("encodeCode128", () => {
  it("has exactly 107 ISO patterns", () => {
    expect(CODE128_PATTERNS).toHaveLength(107);
    for (let i = 0; i < CODE128_PATTERNS.length; i++) {
      const pat = CODE128_PATTERNS[i]!;
      const sum = pat.split("").reduce((acc, c) => acc + Number(c), 0);
      if (i === 106) {
        expect(sum).toBe(13); // Stop symbol
      } else {
        expect(sum).toBe(11);
      }
    }
  });

  it("calculates correct checksum and module widths for sample SKU", () => {
    // Text: "P-100"
    // 'P' = 80-32 = 48 -> 1*48 = 48
    // '-' = 45-32 = 13 -> 2*13 = 26
    // '1' = 49-32 = 17 -> 3*17 = 51
    // '0' = 48-32 = 16 -> 4*16 = 64
    // '0' = 48-32 = 16 -> 5*16 = 80
    // Sum = 104 + 48 + 26 + 51 + 64 + 80 = 373
    // Checksum = 373 % 103 = 64
    const result = encodeCode128("P-100", 10);
    expect(result.rawText).toBe("P-100");
    expect(result.checksum).toBe(64);

    // Total modules: 10 (quiet) + 11 (start) + 5*11 (text) + 11 (checksum) + 13 (stop) + 10 (quiet) = 110
    expect(result.totalModules).toBe(110);
    expect(result.bars.length).toBeGreaterThan(0);

    // Ensure all bars have valid positive coordinates
    for (const bar of result.bars) {
      expect(bar.x).toBeGreaterThanOrEqual(10);
      expect(bar.x + bar.width).toBeLessThanOrEqual(100);
      expect(bar.width).toBeGreaterThanOrEqual(1);
      expect(bar.width).toBeLessThanOrEqual(4);
    }
  });

  it("handles empty or special character strings gracefully", () => {
    const emptyResult = encodeCode128("", 5);
    expect(emptyResult.rawText).toBe("");
    // Start (11) + Checksum 104%103=1 (11) + Stop (13) + 10 quiet = 45
    expect(emptyResult.totalModules).toBe(45);

    const filteredResult = encodeCode128("TEST\u20AC", 5); // euro sign filtered
    expect(filteredResult.rawText).toBe("TEST");
  });
});

describe("buildPrintItems", () => {
  const sampleProducts: BarcodeProduct[] = [
    { name: "Rice 1kg", sku: "SKU-RICE", barcode: "480000000001", price: 55 },
    { name: "Canned Tuna", sku: "SKU-TUNA", barcode: null, price: 38 },
  ];

  it("multiplies items by the specified copies count", () => {
    const items = buildPrintItems(sampleProducts, 3, "PHP", "en");
    // 2 products * 3 copies = 6 total print items
    expect(items).toHaveLength(6);
    expect(items.filter((i) => i.product.sku === "SKU-RICE")).toHaveLength(3);
    expect(items.filter((i) => i.product.sku === "SKU-TUNA")).toHaveLength(3);
  });

  it("uses barcode when present and falls back to sku when missing", () => {
    const items = buildPrintItems(sampleProducts, 1, "PHP", "en");
    expect(items[0]!.code).toBe("480000000001");
    expect(items[1]!.code).toBe("SKU-TUNA");
  });

  it("formats formatted price display with currency", () => {
    const items = buildPrintItems(sampleProducts, 1, "PHP", "en");
    expect(items[0]!.priceDisplay).toContain("55");
    expect(items[1]!.priceDisplay).toContain("38");
  });

  it("handles products with no price gracefully", () => {
    const noPriceProduct: BarcodeProduct[] = [{ name: "Box", sku: "BOX-1", price: null }];
    const items = buildPrintItems(noPriceProduct, 2, "PHP", "en");
    expect(items).toHaveLength(2);
    expect(items[0]!.priceDisplay).toBe("");
  });

  it("formats warehouse bin location stickers with Code 128 code and no retail price", () => {
    const binItem = formatBinBarcodeItem({
      code: "A-01-S2",
      zone_code: "PICK",
      aisle: "1",
      rack: "01",
      shelf: "2",
      position: "B",
      type: "shelf",
    });
    expect(binItem.sku).toBe("A-01-S2");
    expect(binItem.barcode).toBe("A-01-S2");
    expect(binItem.price).toBeNull();
    expect(binItem.name).toBe("PICK · A1-R01-S2-PB");

    const encoded = encodeCode128(binItem.barcode!, 10);
    expect(encoded.rawText).toBe("A-01-S2");
    expect(encoded.bars.length).toBeGreaterThan(10);

    const fallbackBin = formatBinBarcodeItem({
      code: "RECV-01",
      zone_code: "RECV",
      type: "floor",
    });
    expect(fallbackBin.name).toBe("RECV · FLOOR");
  });
});
