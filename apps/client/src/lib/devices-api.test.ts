import { describe, expect, it } from "vitest";
import {
  filterDevices,
  normalizeDeviceName,
  shortDeviceId,
  summarizeDevices,
  type DeviceRow,
} from "./devices-api.ts";

const sampleDevices: DeviceRow[] = [
  {
    id: "019a0000-0000-7000-8000-00000000aa11",
    tenant_id: "t1",
    user_id: "u1",
    name: "Counter 1 Tablet",
    platform: "android",
    first_seen_at: "2026-11-10T08:00:00Z",
    last_seen_at: "2026-11-12T10:30:00Z",
    deleted_at: null,
    owner_name: "Rosa Magtanggol",
    owner_username: "rosa",
  },
  {
    id: "019a0000-0000-7000-8000-00000000bb22",
    tenant_id: "t1",
    user_id: "u2",
    name: "Back-Office Chrome",
    platform: "web",
    first_seen_at: "2026-11-09T08:00:00Z",
    last_seen_at: "2026-11-12T09:00:00Z",
    deleted_at: null,
    owner_name: "Demo Owner",
    owner_username: "owner",
  },
  {
    id: "019a0000-0000-7000-8000-00000000cc33",
    tenant_id: "t1",
    user_id: "u1",
    name: "Lost Moto G",
    platform: "android",
    first_seen_at: "2026-11-01T08:00:00Z",
    last_seen_at: "2026-11-05T12:00:00Z",
    deleted_at: "2026-11-06T09:00:00Z",
    owner_name: "Rosa Magtanggol",
    owner_username: "rosa",
  },
];

describe("devices-api helpers", () => {
  it("shortens UUID device IDs to uppercase 8-character suffixes", () => {
    expect(shortDeviceId("019a0000-0000-7000-8000-00000000aa11")).toBe("0000AA11");
    expect(shortDeviceId("abc-123")).toBe("ABC123");
  });

  it("normalizes and validates custom terminal names", () => {
    expect(normalizeDeviceName("  Register #2  ")).toBe("Register #2");
    expect(normalizeDeviceName("   ")).toBeNull();
    expect(() => normalizeDeviceName("x".repeat(61))).toThrow("invalid_value");
  });

  it("summarizes active and retired counts against max_devices", () => {
    expect(summarizeDevices(sampleDevices, 5)).toEqual({
      activeCount: 2,
      retiredCount: 1,
      maxDevices: 5,
      percentUsed: 40,
      nearLimit: false,
      atLimit: false,
    });

    expect(summarizeDevices(sampleDevices.slice(0, 2), 2)).toEqual({
      activeCount: 2,
      retiredCount: 0,
      maxDevices: 2,
      percentUsed: 100,
      nearLimit: true,
      atLimit: true,
    });
  });

  it("hides retired devices by default, pins current browser first, and searches across name/owner/id", () => {
    const activeDefault = filterDevices(sampleDevices, {
      currentDeviceId: "019a0000-0000-7000-8000-00000000bb22",
    });
    expect(activeDefault.map((d) => d.name)).toEqual([
      "Back-Office Chrome",
      "Counter 1 Tablet",
    ]);

    const withRetired = filterDevices(sampleDevices, { showRetired: true });
    expect(withRetired.map((d) => d.name)).toEqual([
      "Counter 1 Tablet",
      "Back-Office Chrome",
      "Lost Moto G",
    ]);

    expect(
      filterDevices(sampleDevices, { showRetired: true, search: "cc33" }).map((d) => d.name),
    ).toEqual(["Lost Moto G"]);

    expect(
      filterDevices(sampleDevices, { search: "magtanggol" }).map((d) => d.name),
    ).toEqual(["Counter 1 Tablet"]);
  });
});
