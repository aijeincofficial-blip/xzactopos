import { fromRaw } from "./api.ts";
import { setStoredWebDeviceName, webDevice } from "./sell-api.ts";
import { supabase } from "./supabase.ts";

export interface DeviceRow {
  id: string;
  tenant_id: string;
  user_id: string | null;
  name: string | null;
  platform: string | null;
  first_seen_at: string;
  last_seen_at: string;
  deleted_at: string | null;
  owner_name?: string | null;
  owner_username?: string | null;
}

export interface DeviceFleetSummary {
  activeCount: number;
  retiredCount: number;
  maxDevices: number;
  percentUsed: number;
  nearLimit: boolean;
  atLimit: boolean;
}

/** Short 8-char suffix for displaying terminal UUIDs cleanly on cards and receipts. */
export function shortDeviceId(id: string): string {
  const clean = id.replace(/-/g, "").trim().toUpperCase();
  if (clean.length <= 8) return clean;
  return clean.slice(-8);
}

/** Trims and validates a custom terminal name (1..60 chars, or null when cleared). */
export function normalizeDeviceName(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.length > 60) {
    throw new Error("invalid_value");
  }
  return trimmed;
}

/** Summarizes active vs retired terminals against `tenant_limits.max_devices`. */
export function summarizeDevices(
  rows: readonly DeviceRow[],
  maxDevices: number,
): DeviceFleetSummary {
  const safeMax = Math.max(1, maxDevices);
  let activeCount = 0;
  let retiredCount = 0;
  for (const row of rows) {
    if (row.deleted_at) {
      retiredCount += 1;
    } else {
      activeCount += 1;
    }
  }
  const percentUsed = Math.min(100, Math.round((activeCount / safeMax) * 100));
  return {
    activeCount,
    retiredCount,
    maxDevices: safeMax,
    percentUsed,
    nearLimit: percentUsed >= 80,
    atLimit: activeCount >= safeMax,
  };
}

export interface DeviceFilterInput {
  search?: string;
  showRetired?: boolean;
  currentDeviceId?: string;
}

/** Filters and orders registered terminals (current browser first among active rows, then most recently seen). */
export function filterDevices(
  rows: readonly DeviceRow[],
  input: DeviceFilterInput = {},
): DeviceRow[] {
  const q = (input.search ?? "").trim().toLowerCase();
  const showRetired = Boolean(input.showRetired);
  const currentId = input.currentDeviceId ?? "";

  const filtered = rows.filter((d) => {
    if (!showRetired && d.deleted_at) return false;
    if (!q) return true;
    const haystacks = [
      d.name ?? "",
      d.id,
      shortDeviceId(d.id),
      d.platform ?? "",
      d.owner_name ?? "",
      d.owner_username ?? "",
    ];
    return haystacks.some((h) => h.toLowerCase().includes(q));
  });

  return [...filtered].sort((a, b) => {
    const aRetired = Boolean(a.deleted_at);
    const bRetired = Boolean(b.deleted_at);
    if (aRetired !== bRetired) return aRetired ? 1 : -1;
    if (!aRetired && currentId) {
      const aCurrent = a.id === currentId;
      const bCurrent = b.id === currentId;
      if (aCurrent !== bCurrent) return aCurrent ? -1 : 1;
    }
    return b.last_seen_at.localeCompare(a.last_seen_at);
  });
}

export async function fetchTenantDevices(): Promise<DeviceRow[]> {
  const { data, error } = await supabase
    .from("devices")
    .select("id, tenant_id, user_id, name, platform, first_seen_at, last_seen_at, deleted_at")
    .order("last_seen_at", { ascending: false });

  if (error) throw fromRaw(error);
  const devices = (data ?? []) as DeviceRow[];

  const userIds = Array.from(
    new Set(devices.map((d) => d.user_id).filter((id): id is string => Boolean(id))),
  );
  if (userIds.length === 0) return devices;

  const { data: profiles } = await supabase
    .from("profiles")
    .select("user_id, full_name, username")
    .in("user_id", userIds);

  const byUser = new Map<string, { full_name: string | null; username: string | null }>();
  for (const p of (profiles ?? []) as Array<{
    user_id: string;
    full_name: string | null;
    username: string | null;
  }>) {
    byUser.set(p.user_id, p);
  }

  return devices.map((d) => {
    const owner = d.user_id ? byUser.get(d.user_id) : undefined;
    return {
      ...d,
      owner_name: owner?.full_name ?? null,
      owner_username: owner?.username ?? null,
    };
  });
}

export async function renameDevice(deviceId: string, rawName: string): Promise<string | null> {
  const name = normalizeDeviceName(rawName);
  const { error } = await supabase
    .from("devices")
    .update({ name })
    .eq("id", deviceId);
  if (error) throw fromRaw(error);

  if (deviceId === webDevice().id) {
    setStoredWebDeviceName(name);
  }
  return name;
}

export async function setDeviceRetired(deviceId: string, retired: boolean): Promise<void> {
  const { error } = await supabase
    .from("devices")
    .update({ deleted_at: retired ? new Date().toISOString() : null })
    .eq("id", deviceId);
  if (error) throw fromRaw(error);
}
