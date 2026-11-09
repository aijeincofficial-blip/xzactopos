import { describe, expect, it } from "vitest";
import {
  createTransferSchema,
  createUserSchema,
  fieldErrors,
  inviteUserSchema,
  locationSchema,
  receiveTransferSchema,
  setPinSchema,
  setupLanguagesSchema,
  slugSchema,
  tenantSettingsSchema,
  upgradeSchema,
} from "./schemas.ts";
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

  it("validates tenant settings schema", () => {
    const valid = {
      name: "Tindahan Ni Rosa",
      timezone: "Asia/Manila",
      taxMode: "inclusive" as const,
      defaultLocale: "en" as const,
      locales: ["en", "fil"] as ("en" | "fil")[],
      offlineSessionDays: 7,
      receiptHeader: "Welcome to Rosa!",
      receiptFooter: "Salamat po!",
    };
    expect(tenantSettingsSchema.safeParse(valid).success).toBe(true);

    const badLocale = { ...valid, defaultLocale: "fil" as const, locales: ["en"] as ("en" | "fil")[] };
    expect(tenantSettingsSchema.safeParse(badLocale).success).toBe(false);

    const badDays = { ...valid, offlineSessionDays: 45 };
    expect(tenantSettingsSchema.safeParse(badDays).success).toBe(false);
  });

  it("validates invite user schema", () => {
    const valid = {
      email: "manager@example.com",
      username: "juan_mgr",
      fullName: "Juan Manager",
      role: "admin" as const,
      locationId: "loc-123",
      position: "manager" as const,
    };
    expect(inviteUserSchema.safeParse(valid).success).toBe(true);

    const badEmail = { ...valid, email: "invalid-email" };
    expect(inviteUserSchema.safeParse(badEmail).success).toBe(false);

    const missingPosition = { ...valid, position: "" as const };
    expect(inviteUserSchema.safeParse(missingPosition).success).toBe(false);

    const superadmin = {
      email: "owner2@example.com",
      username: "owner2",
      fullName: "",
      role: "superadmin" as const,
      locationId: "",
      position: "" as const,
    };
    expect(inviteUserSchema.safeParse(superadmin).success).toBe(true);
  });

  it("validates set/change PIN schema", () => {
    expect(setPinSchema.safeParse({ newPin: "1234", confirmPin: "1234" }).success).toBe(true);
    expect(setPinSchema.safeParse({ currentPin: "1234", newPin: "567890", confirmPin: "567890" }).success).toBe(true);

    // Mismatched confirmation
    expect(setPinSchema.safeParse({ newPin: "1234", confirmPin: "9999" }).success).toBe(false);

    // Too short / invalid digits
    expect(setPinSchema.safeParse({ newPin: "12", confirmPin: "12" }).success).toBe(false);
    expect(setPinSchema.safeParse({ newPin: "abcd", confirmPin: "abcd" }).success).toBe(false);
    expect(setPinSchema.safeParse({ newPin: "123456789", confirmPin: "123456789" }).success).toBe(false);
  });

  it("validates createTransferSchema and receiveTransferSchema", () => {
    const valid = {
      fromLocationId: "loc-1",
      toLocationId: "loc-2",
      notes: "Urgent store replenishment",
      items: [{ variantId: "var-1", qty: 10 }],
      shipNow: false,
    };
    expect(createTransferSchema.safeParse(valid).success).toBe(true);

    // Same from and to location
    const sameLoc = { ...valid, toLocationId: "loc-1" };
    const resSame = createTransferSchema.safeParse(sameLoc);
    expect(resSame.success).toBe(false);
    if (!resSame.success) {
      expect(fieldErrors(resSame.error)["toLocationId"]).toBe("validation.different_locations");
    }

    // Empty items
    const emptyItems = { ...valid, items: [] };
    const resEmpty = createTransferSchema.safeParse(emptyItems);
    expect(resEmpty.success).toBe(false);
    if (!resEmpty.success) {
      expect(fieldErrors(resEmpty.error)["items"]).toBe("validation.items_required");
    }

    // Invalid item qty <= 0
    const zeroQty = { ...valid, items: [{ variantId: "var-1", qty: 0 }] };
    expect(createTransferSchema.safeParse(zeroQty).success).toBe(false);

    // receiveTransferSchema
    expect(receiveTransferSchema.safeParse({ items: [{ variantId: "var-1", qtyReceived: 8 }] }).success).toBe(true);
    expect(receiveTransferSchema.safeParse({ items: [{ variantId: "var-1", qtyReceived: 0 }] }).success).toBe(true);
    expect(receiveTransferSchema.safeParse({ items: [{ variantId: "var-1", qtyReceived: -1 }] }).success).toBe(false);
    expect(receiveTransferSchema.safeParse({ items: [] }).success).toBe(false);
  });
});

describe("loginEmail", () => {
  it("builds the synthetic email for usernames and keeps real emails", () => {
    expect(loginEmail(" Ana ", "acme")).toBe("ana.acme@pos.invalid");
    expect(loginEmail("Owner@Example.com", "acme")).toBe("owner@example.com");
  });
});
