import { describe, expect, it } from "vitest";
import { parseCreateUser, parseInviteUser, syntheticEmail } from "./validate.ts";

describe("syntheticEmail", () => {
  it("namespaces usernames by tenant slug", () => {
    expect(syntheticEmail("maria", "sari-sari")).toBe("maria.sari-sari@pos.invalid");
  });
});

describe("parseCreateUser", () => {
  const base = { username: "Maria", password: "s3cret-pass", role: "cashier" };

  it("accepts a cashier and normalizes the username", () => {
    const r = parseCreateUser({ ...base, full_name: "  Maria Santos ", location_id: "0190f3a2-7b7e-7cc1-9f00-000000000001" });
    expect(r).toEqual({
      ok: true,
      value: {
        username: "maria",
        fullName: "Maria Santos",
        password: "s3cret-pass",
        role: "cashier",
        locale: null,
        locationId: "0190f3a2-7b7e-7cc1-9f00-000000000001",
        position: null,
      },
    });
  });

  it.each([
    [{ ...base, username: "a" }, "username"],
    [{ ...base, username: "has space" }, "username"],
    [{ ...base, username: "-dash" }, "username"],
    [{ ...base, password: "short" }, "password"],
    [{ ...base, password: 12345678 }, "password"],
    [{ ...base, role: "owner" }, "role"],
    [{ ...base, locale: "de" }, "locale"],
    [{ ...base, location_id: "not-a-uuid" }, "location_id"],
    [{ ...base, position: "manager", location_id: "0190f3a2-7b7e-7cc1-9f00-000000000001" }, "position"],
    [{ ...base, role: "admin", location_id: "0190f3a2-7b7e-7cc1-9f00-000000000001" }, "position"],
    [{ ...base, role: "admin", position: "manager" }, "location_id"],
  ])("rejects %j at %s", (body, field) => {
    const r = parseCreateUser(body);
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.field).toBe(field);
  });

  it("rejects non-object bodies", () => {
    expect(parseCreateUser(null)).toMatchObject({ ok: false, field: "body" });
    expect(parseCreateUser([base])).toMatchObject({ ok: false, field: "body" });
  });

  it("accepts an admin with a store and a position", () => {
    const r = parseCreateUser({
      ...base,
      role: "admin",
      position: "supervisor",
      location_id: "0190f3a2-7b7e-7cc1-9f00-000000000001",
    });
    expect(r.ok && r.value.position).toBe("supervisor");
  });
});

describe("parseInviteUser", () => {
  it("accepts a regular invite", () => {
    const r = parseInviteUser({ email: " Boss@Example.com ", username: "boss", role: "warehouse" });
    expect(r).toMatchObject({ ok: true, value: { email: "boss@example.com", role: "warehouse", provision: null } });
  });

  it("refuses synthetic and malformed emails", () => {
    expect(parseInviteUser({ email: "x.shop@pos.invalid", username: "xx", role: "admin" })).toMatchObject({ ok: false, field: "email" });
    expect(parseInviteUser({ email: "nope", username: "xx", role: "admin" })).toMatchObject({ ok: false, field: "email" });
  });

  it("forces superadmin and defaults when provisioning", () => {
    const r = parseInviteUser({
      email: "owner@shop.ph",
      username: "owner",
      role: "cashier",
      provision: { name: "Shop", slug: "Shop-PH", base_currency: "php" },
    });
    expect(r).toMatchObject({
      ok: true,
      value: {
        role: "superadmin",
        provision: { slug: "shop-ph", baseCurrency: "PHP", preset: "inventory", timezone: "UTC" },
      },
    });
  });

  it("validates provisioning fields", () => {
    const bad = (provision: unknown) => parseInviteUser({ email: "o@shop.ph", username: "owner", provision });
    expect(bad({ name: "Shop", slug: "x", base_currency: "PHP" })).toMatchObject({ ok: false, field: "provision.slug" });
    expect(bad({ name: "Shop", slug: "shop", base_currency: "PESO" })).toMatchObject({ ok: false, field: "provision.base_currency" });
    expect(bad({ name: "Shop", slug: "shop", base_currency: "PHP", preset: "everything" })).toMatchObject({ ok: false, field: "preset" });
  });

  it("rejects non-http redirect targets", () => {
    expect(parseInviteUser({ email: "a@b.co", username: "abc", role: "admin", redirect_to: "javascript:alert(1)" }))
      .toMatchObject({ ok: false, field: "redirect_to" });
  });
});
