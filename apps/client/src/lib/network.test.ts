import { describe, expect, it } from "vitest";
import { isOnline } from "./network.ts";

describe("network status helper", () => {
  it("returns true in node environment by default", () => {
    expect(isOnline()).toBe(true);
  });

  it("reflects navigator.onLine when navigator.onLine is boolean", () => {
    const originalDescriptor = Object.getOwnPropertyDescriptor(navigator, "onLine");
    try {
      Object.defineProperty(navigator, "onLine", { value: false, configurable: true });
      expect(isOnline()).toBe(false);

      Object.defineProperty(navigator, "onLine", { value: true, configurable: true });
      expect(isOnline()).toBe(true);
    } finally {
      if (originalDescriptor) {
        Object.defineProperty(navigator, "onLine", originalDescriptor);
      } else {
        // @ts-expect-error cleanup
        delete navigator.onLine;
      }
    }
  });
});
