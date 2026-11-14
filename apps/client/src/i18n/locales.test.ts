import { describe, expect, it } from "vitest";
import enAdmin from "../locales/en/admin.json";
import enAuth from "../locales/en/auth.json";
import enCommon from "../locales/en/common.json";
import enErrors from "../locales/en/errors.json";
import enShell from "../locales/en/shell.json";
import filAdmin from "../locales/fil/admin.json";
import filAuth from "../locales/fil/auth.json";
import filCommon from "../locales/fil/common.json";
import filErrors from "../locales/fil/errors.json";
import filShell from "../locales/fil/shell.json";
import { pickLocale, resolveLocale } from "./index.ts";

const allResources = {
  en: { common: enCommon, auth: enAuth, shell: enShell, admin: enAdmin, errors: enErrors },
  fil: { common: filCommon, auth: filAuth, shell: filShell, admin: filAdmin, errors: filErrors },
} as const;

function flatten(obj: unknown, prefix = ""): Array<[string, unknown]> {
  if (typeof obj !== "object" || obj === null) return [[prefix, obj]];
  return Object.entries(obj).flatMap(([k, v]) => flatten(v, prefix ? `${prefix}.${k}` : k));
}

describe("locale files", () => {
  for (const ns of Object.keys(allResources.en) as Array<keyof typeof allResources.en>) {
    it(`fil has exactly the same keys as en in "${ns}"`, () => {
      const en = flatten(allResources.en[ns]).map(([k]) => k).sort();
      const fil = flatten(allResources.fil[ns]).map(([k]) => k).sort();
      expect(fil).toEqual(en);
    });

    it(`no empty strings in "${ns}"`, () => {
      for (const loc of ["en", "fil"] as const) {
        for (const [k, v] of flatten(allResources[loc][ns])) {
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
