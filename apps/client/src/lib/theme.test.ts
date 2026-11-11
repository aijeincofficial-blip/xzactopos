import { describe, expect, it } from "vitest";
import { contrastRatio, nextTheme, parseTheme, WCAG_TOKEN_PAIRS } from "./theme.ts";

describe("theme choice", () => {
  it("falls back to system for anything unknown", () => {
    expect(parseTheme(null)).toBe("system");
    expect(parseTheme("purple")).toBe("system");
    expect(parseTheme("dark")).toBe("dark");
    expect(parseTheme("light")).toBe("light");
  });
  it("cycles system, light, dark and round again", () => {
    expect(nextTheme("system")).toBe("light");
    expect(nextTheme("light")).toBe("dark");
    expect(nextTheme("dark")).toBe("system");
  });
});

describe("WCAG AA contrast audit (light & dark tokens)", () => {
  it.each(WCAG_TOKEN_PAIRS)("$label meets >= 4.5:1", ({ fg, bg }) => {
    expect(contrastRatio(fg, bg)).toBeGreaterThanOrEqual(4.5);
  });
});
