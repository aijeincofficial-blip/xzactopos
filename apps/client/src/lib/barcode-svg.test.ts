import { describe, expect, it } from "vitest";
import { encodeCode128, CODE128_PATTERNS } from "./barcode-svg.tsx";

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
