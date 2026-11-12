import { describe, expect, it } from "vitest";
import {
  classifyAuditCategory,
  filterAuditLogs,
  isSecuritySensitiveAudit,
  summarizeAuditMeta,
  type AuditLogRow,
} from "./audit-api.ts";

const sampleRows: AuditLogRow[] = [
  {
    id: "a1",
    user_id: "u-owner",
    location_id: "loc-s01",
    action: "sale.void",
    entity: "sale",
    entity_id: "0190a000-0000-7000-8000-000000000001",
    meta: { reason: "Duplicate scan", total: 15000 },
    created_at: "2026-11-12T06:00:00Z", // 2026-11-12 14:00 Manila
  },
  {
    id: "a2",
    user_id: "u-mgr",
    location_id: "loc-s01",
    action: "stock.receive",
    entity: "variant",
    entity_id: "0190a000-0000-7000-8000-000000000002",
    meta: { qty: 24, unit_cost: 1200 },
    created_at: "2026-11-11T04:00:00Z",
  },
  {
    id: "a3",
    user_id: "u-cashier",
    location_id: "loc-s02",
    action: "day.close",
    entity: "day_close",
    entity_id: "0190a000-0000-7000-8000-000000000003",
    meta: { counted_cash: 250000, difference: 0 },
    created_at: "2026-11-10T13:30:00Z",
  },
  {
    id: "a4",
    user_id: "u-owner",
    location_id: null,
    action: "pin.failed",
    entity: "profile",
    entity_id: "u-mgr",
    meta: { action: "discount_override" },
    created_at: "2026-11-12T07:15:00Z",
  },
];

describe("audit-api pure helpers", () => {
  it("classifies audit actions into operational categories", () => {
    expect(classifyAuditCategory("sale.create", "sale")).toBe("sales");
    expect(classifyAuditCategory("utang.payment", "customer")).toBe("sales");
    expect(classifyAuditCategory("approval.grant", "approval")).toBe("sales");
    expect(classifyAuditCategory("stock.count", "variant")).toBe("stock");
    expect(classifyAuditCategory("transfer.ship", "transfer")).toBe("stock");
    expect(classifyAuditCategory("day.close", "day_close")).toBe("shifts_cash");
    expect(classifyAuditCategory("expense.record", "expense")).toBe("shifts_cash");
    expect(classifyAuditCategory("role.change", "profile")).toBe("users_settings");
    expect(classifyAuditCategory("modules.set", "tenant")).toBe("users_settings");
  });

  it("flags security-sensitive overrides, voids, PIN events, and role changes", () => {
    expect(isSecuritySensitiveAudit("sale.void")).toBe(true);
    expect(isSecuritySensitiveAudit("pin.failed")).toBe(true);
    expect(isSecuritySensitiveAudit("approval.grant")).toBe(true);
    expect(isSecuritySensitiveAudit("role.change")).toBe(true);
    expect(isSecuritySensitiveAudit("sale.create")).toBe(false);
    expect(isSecuritySensitiveAudit("stock.receive")).toBe(false);
  });

  it("summarizes audit metadata cleanly", () => {
    expect(summarizeAuditMeta({ reason: "Damaged", qty: -2, ignored: null })).toBe(
      "reason: Damaged · qty: -2",
    );
    expect(summarizeAuditMeta({})).toBe("");
  });

  it("filters audit rows by category, sensitivity, actor, location, date range, and search", () => {
    const actors = new Map([
      ["u-owner", "Aling Nena (@owner)"],
      ["u-mgr", "Maria Santos (@maria)"],
      ["u-cashier", "Jun Reyes (@jun)"],
    ]);
    const locs = new Map([
      ["loc-s01", "Poblacion Main (S01)"],
      ["loc-s02", "Market Branch (S02)"],
    ]);

    const baseFilter = {
      search: "",
      category: "all" as const,
      actorId: "all",
      locationId: "all",
      onlySensitive: false,
      dateFrom: "",
      dateTo: "",
      timezone: "Asia/Manila",
    };

    expect(filterAuditLogs(sampleRows, { ...baseFilter, onlySensitive: true }, actors, locs).map((r) => r.id)).toEqual([
      "a1",
      "a4",
    ]);

    expect(filterAuditLogs(sampleRows, { ...baseFilter, category: "stock" }, actors, locs).map((r) => r.id)).toEqual([
      "a2",
    ]);

    expect(filterAuditLogs(sampleRows, { ...baseFilter, locationId: "global" }, actors, locs).map((r) => r.id)).toEqual([
      "a4",
    ]);

    expect(filterAuditLogs(sampleRows, { ...baseFilter, search: "duplicate scan" }, actors, locs).map((r) => r.id)).toEqual([
      "a1",
    ]);

    expect(filterAuditLogs(sampleRows, { ...baseFilter, search: "maria" }, actors, locs).map((r) => r.id)).toEqual([
      "a2",
    ]);

    expect(
      filterAuditLogs(
        sampleRows,
        { ...baseFilter, dateFrom: "2026-11-12", dateTo: "2026-11-12" },
        actors,
        locs,
      ).map((r) => r.id),
    ).toEqual(["a1", "a4"]);
  });
});
