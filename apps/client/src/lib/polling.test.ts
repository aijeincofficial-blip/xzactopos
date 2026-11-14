import { describe, expect, it } from "vitest";
import { MIN_POLL_INTERVAL_MS, resolvePollInterval } from "./polling.ts";

describe("visibility & offline-gated polling (P05)", () => {
  it("pauses polling completely when offline or tab is hidden", () => {
    expect(resolvePollInterval(false, true, 120_000)).toBe(false);
    expect(resolvePollInterval(true, false, 120_000)).toBe(false);
    expect(resolvePollInterval(false, false, 120_000)).toBe(false);
  });

  it("clamps active intervals to MIN_POLL_INTERVAL_MS (120 s) and preserves larger cadences", () => {
    expect(MIN_POLL_INTERVAL_MS).toBe(120_000);
    expect(resolvePollInterval(true, true, 30_000)).toBe(120_000);
    expect(resolvePollInterval(true, true)).toBe(120_000);
    expect(resolvePollInterval(true, true, 300_000)).toBe(300_000);
  });
});
