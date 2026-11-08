import { verifyPinPbkdf2 } from "@pos/core";
import { supabase } from "./supabase.ts";

export interface OfflinePinUser {
  user_id: string;
  username: string;
  full_name: string | null;
  role: string;
  position: string | null;
  pin_hash: string;
}

export interface OfflineApprovalPayload {
  approver_id: string;
  action: string;
  ref_id: string;
  approved_at: string;
}

const STORAGE_PREFIX = "pos.offlinePins.";

export function getCachedOfflinePins(locationId?: string): OfflinePinUser[] {
  try {
    const key = `${STORAGE_PREFIX}${locationId ?? "global"}`;
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export function saveCachedOfflinePins(locationId: string | undefined, pins: OfflinePinUser[]): void {
  try {
    const key = `${STORAGE_PREFIX}${locationId ?? "global"}`;
    localStorage.setItem(key, JSON.stringify(pins));
  } catch {
    // ignore quota/storage issues
  }
}

export async function pullOfflinePins(locationId?: string): Promise<OfflinePinUser[]> {
  const { data, error } = await supabase.rpc("pull_offline_pins", {
    p_location_id: locationId || null,
  });

  if (error) throw error;
  const list = (data as OfflinePinUser[]) ?? [];
  saveCachedOfflinePins(locationId, list);
  return list;
}

/**
 * Attempts to verify an approver's PIN offline against locally cached pin hashes.
 */
export async function verifyOfflineSupervisorPin(
  approverId: string,
  pin: string,
  action: string,
  refId: string,
  locationId?: string,
): Promise<{ ok: boolean; offlineApproval?: OfflineApprovalPayload; hint?: string }> {
  const cached = getCachedOfflinePins(locationId);
  const user = cached.find((u) => u.user_id === approverId);
  if (!user) {
    return { ok: false, hint: "pin_wrong" };
  }

  const matches = await verifyPinPbkdf2(pin, user.pin_hash);
  if (!matches) {
    return { ok: false, hint: "pin_wrong" };
  }

  return {
    ok: true,
    offlineApproval: {
      approver_id: approverId,
      action,
      ref_id: refId,
      approved_at: new Date().toISOString(),
    },
  };
}
