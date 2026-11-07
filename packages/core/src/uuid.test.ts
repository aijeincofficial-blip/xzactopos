import { describe, expect, it } from "vitest";
import { uuidv7 } from "./uuid.ts";

describe("uuidv7", () => {
  it("has version 7 and RFC variant", () => {
    const id = uuidv7();
    expect(id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  });

  it("encodes the timestamp in the first 48 bits", () => {
    const ts = 0x0190_1234_5678;
    const id = uuidv7(ts, () => new Uint8Array(16));
    expect(id.replace(/-/g, "").slice(0, 12)).toBe("019012345678");
  });

  it("sorts by time", () => {
    expect(uuidv7(1_000) < uuidv7(2_000)).toBe(true);
  });

  it("is unique across calls", () => {
    expect(new Set(Array.from({ length: 500 }, () => uuidv7())).size).toBe(500);
  });
});
