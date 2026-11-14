import { signOfflineApprovalProof } from "@pos/core";
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
  proof: string;
}

const STORAGE_PREFIX = "pos.offlinePins.";
const FAILURE_PREFIX = "pos.offlinePinFailures.";
const MAX_OFFLINE_PIN_ATTEMPTS = 5;
const LOCKOUT_WINDOW_MS = 15 * 60 * 1000;

export function isApproverPinUser(user: Pick<OfflinePinUser, "role" | "position">): boolean {
  return (
    user.role === "superadmin" ||
    (user.role === "admin" && (user.position === "supervisor" || user.position === "manager"))
  );
}

export function getCachedOfflinePins(locationId?: string): OfflinePinUser[] {
  try {
    const key = `${STORAGE_PREFIX}${locationId ?? "global"}`;
    const raw = localStorage.getItem(key);
    const parsed = raw ? (JSON.parse(raw) as OfflinePinUser[]) : [];
    return Array.isArray(parsed) ? parsed.filter(isApproverPinUser) : [];
  } catch {
    return [];
  }
}

export function saveCachedOfflinePins(locationId: string | undefined, pins: OfflinePinUser[]): void {
  try {
    const key = `${STORAGE_PREFIX}${locationId ?? "global"}`;
    localStorage.setItem(key, JSON.stringify(pins.filter(isApproverPinUser)));
  } catch {
    // ignore quota/storage issues
  }
}

function readFailuresMap(locationId?: string): Record<string, number[]> {
  try {
    const raw = localStorage.getItem(`${FAILURE_PREFIX}${locationId ?? "global"}`);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    if (!parsed || typeof parsed !== "object") return {};
    const now = Date.now();
    const cleaned: Record<string, number[]> = {};
    for (const [uid, times] of Object.entries(parsed)) {
      if (Array.isArray(times)) {
        const recent = times.filter((t): t is number => typeof t === "number" && now - t < LOCKOUT_WINDOW_MS);
        if (recent.length > 0) cleaned[uid] = recent;
      }
    }
    return cleaned;
  } catch {
    return {};
  }
}

function writeFailuresMap(locationId: string | undefined, map: Record<string, number[]>): void {
  try {
    const key = `${FAILURE_PREFIX}${locationId ?? "global"}`;
    if (Object.keys(map).length === 0) {
      localStorage.removeItem(key);
    } else {
      localStorage.setItem(key, JSON.stringify(map));
    }
  } catch {
    // ignore quota/storage issues
  }
}

export function clearAllOfflinePinStorage(): void {
  try {
    const toRemove: string[] = [];
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k && (k.startsWith(STORAGE_PREFIX) || k.startsWith(FAILURE_PREFIX))) {
        toRemove.push(k);
      }
    }
    for (const k of toRemove) localStorage.removeItem(k);
  } catch {
    // ignore storage issues
  }
}

export async function pullOfflinePins(locationId?: string): Promise<OfflinePinUser[]> {
  const { data, error } = await supabase.rpc("pull_offline_pins", {
    p_location_id: locationId || null,
  });

  if (error) throw error;
  const list = ((data as OfflinePinUser[]) ?? []).filter(isApproverPinUser);
  saveCachedOfflinePins(locationId, list);
  return list;
}

/**
 * Attempts to verify an approver's PIN offline against cached v2 PIN verifiers,
 * enforcing 5-attempt / 15-minute lockout and returning an HMAC-SHA256 proof.
 */
export async function verifyOfflineSupervisorPin(
  approverId: string,
  pin: string,
  action: string,
  refId: string,
  tenantId: string,
  locationId?: string,
): Promise<{ ok: boolean; offlineApproval?: OfflineApprovalPayload; hint?: string }> {
  const cached = getCachedOfflinePins(locationId);
  const user = cached.find((u) => u.user_id === approverId);
  if (!user) {
    return { ok: false, hint: "pin_wrong" };
  }

  const failures = readFailuresMap(locationId);
  const recent = failures[approverId] ?? [];
  if (recent.length >= MAX_OFFLINE_PIN_ATTEMPTS) {
    return { ok: false, hint: "pin_locked" };
  }

  if (!tenantId) {
    return { ok: false, hint: "approval_invalid" };
  }

  const approvedAt = new Date().toISOString();
  const signed = await signOfflineApprovalProof({
    pin,
    pinHash: user.pin_hash,
    tenantId,
    approverId,
    action,
    refId,
    approvedAt,
  });

  if (!signed.matched || !signed.proof) {
    const updated = [...recent, Date.now()];
    failures[approverId] = updated;
    writeFailuresMap(locationId, failures);
    return {
      ok: false,
      hint: updated.length >= MAX_OFFLINE_PIN_ATTEMPTS ? "pin_locked" : "pin_wrong",
    };
  }

  if (failures[approverId]) {
    delete failures[approverId];
    writeFailuresMap(locationId, failures);
  }

  return {
    ok: true,
    offlineApproval: {
      approver_id: approverId,
      action,
      ref_id: refId,
      approved_at: approvedAt,
      proof: signed.proof,
    },
  };
}
