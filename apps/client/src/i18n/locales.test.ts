import { describe, expect, it } from "vitest";
import { pickLocale, resolveLocale, resources } from "./index.ts";

function flatten(obj: unknown, prefix = ""): Array<[string, unknown]> {
  if (typeof obj !== "object" || obj === null) return [[prefix, obj]];
  return Object.entries(obj).flatMap(([k, v]) => flatten(v, prefix ? `${prefix}.${k}` : k));
}

describe("locale files", () => {
  for (const ns of Object.keys(resources.en) as Array<keyof typeof resources.en>) {
    it(`fil has exactly the same keys as en in "${ns}"`, () => {
      const en = flatten(resources.en[ns]).map(([k]) => k).sort();
      const fil = flatten(resources.fil[ns]).map(([k]) => k).sort();
      expect(fil).toEqual(en);
    });

    it(`no empty strings in "${ns}"`, () => {
      for (const loc of ["en", "fil"] as const) {
        for (const [k, v] of flatten(resources[loc][ns])) {
          expect(String(v).trim().length, `${loc}:${ns}.${k}`).toBeGreaterThan(0);
        }
      }
    });
  }

  it("resolves browser locales", () => {
    expect(resolveLocale("fil-PH")).toBe("fil");
    expect(resolveLocale("tl")).toBe("fil");
    expect(resolveLocale("en-US")).toBe("en");
    expect(resolveLocale("de")).toBe("en");
    expect(resolveLocale(undefined)).toBe("en");
  });

  it("picks the user's locale, then the tenant default, then English", () => {
    expect(pickLocale("fil", "en")).toBe("fil");
    expect(pickLocale(null, "fil")).toBe("fil");
    expect(pickLocale(undefined, undefined)).toBe("en");
    expect(pickLocale("de", "fil")).toBe("fil");
    expect(pickLocale("", "")).toBe("en");
  });
});
