import { describe, expect, it } from "vitest";
import { createUserSchema, fieldErrors, locationSchema, setupLanguagesSchema, slugSchema, upgradeSchema } from "./schemas.ts";
import { loginEmail } from "./api.ts";

const user = { username: "ana", fullName: "", password: "longenough", role: "cashier", locationId: "x", position: "" };

describe("schemas", () => {
  it("normalizes slugs and rejects bad ones", () => {
    expect(slugSchema.parse({ slug: " Acme-Shop " }).slug).toBe("acme-shop");
    expect(slugSchema.safeParse({ slug: "-bad" }).success).toBe(false);
    expect(slugSchema.safeParse({ slug: "a" }).success).toBe(false);
  });

  it("requires a store for cashiers and a position for admins with a store", () => {
    const c = createUserSchema.safeParse({ ...user, locationId: "" });
    expect(c.success).toBe(false);
    if (!c.success) expect(fieldErrors(c.error)["locationId"]).toBe("validation.location_required");

    const a = createUserSchema.safeParse({ ...user, role: "admin" });
    expect(a.success).toBe(false);
    if (!a.success) expect(fieldErrors(a.error)["position"]).toBe("validation.position_required");

    expect(createUserSchema.safeParse({ ...user, role: "admin", position: "manager" }).success).toBe(true);
    expect(createUserSchema.safeParse({ ...user, role: "admin", locationId: "" }).success).toBe(true);
  });

  it("enforces password length and username pattern", () => {
    expect(createUserSchema.safeParse({ ...user, password: "short" }).success).toBe(false);
    expect(createUserSchema.safeParse({ ...user, username: "A B" }).success).toBe(false);
  });

  it("default locale must be one of the enabled locales", () => {
    expect(setupLanguagesSchema.safeParse({ locales: ["en"], defaultLocale: "fil" }).success).toBe(false);
    expect(setupLanguagesSchema.safeParse({ locales: [], defaultLocale: "en" }).success).toBe(false);
    expect(setupLanguagesSchema.safeParse({ locales: ["en", "fil"], defaultLocale: "fil" }).success).toBe(true);
  });

  it("validates location codes", () => {
    const base = { type: "store" as const, name: "Main", address: "", binsEnabled: false };
    expect(locationSchema.safeParse({ ...base, code: "S01" }).success).toBe(true);
    expect(locationSchema.safeParse({ ...base, code: "has space" }).success).toBe(false);
  });

  it("validates upgrade schema with optional location", () => {
    expect(upgradeSchema.safeParse({ warehouse: true, addLocation: false }).success).toBe(true);
    expect(upgradeSchema.safeParse({ warehouse: false, addLocation: false }).success).toBe(true);

    const withLoc = {
      warehouse: true,
      addLocation: true,
      locationType: "warehouse" as const,
      locationCode: "WH01",
      locationName: "Central Warehouse",
      locationAddress: "Logistics Hub",
    };
    expect(upgradeSchema.safeParse(withLoc).success).toBe(true);

    const badCode = { ...withLoc, locationCode: "bad code with space" };
    const resBadCode = upgradeSchema.safeParse(badCode);
    expect(resBadCode.success).toBe(false);
    if (!resBadCode.success) {
      expect(fieldErrors(resBadCode.error)["locationCode"]).toBe("validation.location_code");
    }

    const missingName = { ...withLoc, locationName: "" };
    const resMissingName = upgradeSchema.safeParse(missingName);
    expect(resMissingName.success).toBe(false);
    if (!resMissingName.success) {
      expect(fieldErrors(resMissingName.error)["locationName"]).toBe("validation.required");
    }
  });
});

describe("loginEmail", () => {
  it("builds the synthetic email for usernames and keeps real emails", () => {
    expect(loginEmail(" Ana ", "acme")).toBe("ana.acme@pos.invalid");
    expect(loginEmail("Owner@Example.com", "acme")).toBe("owner@example.com");
  });
});
