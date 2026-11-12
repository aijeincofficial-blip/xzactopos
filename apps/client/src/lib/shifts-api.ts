import { uuidv7 } from "@pos/core";
import { fromRaw } from "./api.ts";
import { isOnline } from "./network.ts";
import {
  enqueuePosOp,
  isNetworkFailure,
  loadPosCache,
  loadPosOutbox,
  savePosCache,
} from "./pos-outbox.ts";
import { supabase } from "./supabase.ts";
import { pushOp } from "./sell-api.ts";

export interface ShiftRow {
  id: string;
  tenant_id: string;
  location_id: string;
  cashier_id: string;
  open_op_id: string;
  close_op_id: string | null;
  currency: string;
  opening_cash: number;
  opened_at: string;
  closed_at: string | null;
  expected_cash: number | null;
  counted_cash: number | null;
  difference: number | null;
  server_expected_cash: number | null;
  note: string | null;
  closed_by: string | null;
  created_at: string;
  updated_at: string;
}

export async function fetchStoreShifts(locationId: string): Promise<ShiftRow[]> {
  const { data, error } = await supabase
    .from("shifts")
    .select("*")
    .eq("location_id", locationId)
    .order("opened_at", { ascending: false })
    .limit(50);

  if (error) throw fromRaw(error);
  return data as ShiftRow[];
}

function pendingOpenShiftForUser(
  userId: string,
  currency: string,
): (ShiftRow & { pending?: boolean }) | null {
  for (const op of loadPosOutbox()) {
    if (op.kind !== "open_shift") continue;
    const id = typeof op.payload.id === "string" ? op.payload.id : op.opId;
    const locId = typeof op.payload.location_id === "string" ? op.payload.location_id : (op.locationId ?? "");
    const openingCash = Number(op.payload.opening_cash) || 0;
    const openedAt = typeof op.payload.opened_at === "string" ? op.payload.opened_at : op.createdAt;
    return {
      id,
      tenant_id: "",
      location_id: locId,
      cashier_id: userId,
      open_op_id: op.opId,
      close_op_id: null,
      currency,
      opening_cash: openingCash,
      opened_at: openedAt,
      closed_at: null,
      expected_cash: null,
      counted_cash: null,
      difference: null,
      server_expected_cash: null,
      note: null,
      closed_by: null,
      created_at: openedAt,
      updated_at: openedAt,
      pending: true,
    };
  }
  return null;
}

export async function fetchMyOpenShift(
  userId: string,
  currency = "PHP",
): Promise<(ShiftRow & { pending?: boolean }) | null> {
  const slot = `open-shift:${userId}`;
  const optimistic = pendingOpenShiftForUser(userId, currency);
  try {
    const { data, error } = await supabase
      .from("shifts")
      .select("*")
      .eq("cashier_id", userId)
      .is("closed_at", null)
      .order("opened_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) throw fromRaw(error);
    const row = (data as ShiftRow | null) ?? null;
    savePosCache(slot, row);
    return row ?? optimistic;
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<ShiftRow | null>(slot);
      return cached ?? optimistic;
    }
    throw err;
  }
}

export async function openCashierShift(input: {
  locationId: string;
  openingCash: number;
}): Promise<{ shiftId: string; queuedOffline?: boolean }> {
  const id = uuidv7();
  const opId = uuidv7();
  const payload: Record<string, unknown> = {
    id,
    location_id: input.locationId,
    opening_cash: input.openingCash,
    opened_at: new Date().toISOString(),
  };

  if (!isOnline()) {
    enqueuePosOp({ opId, kind: "open_shift", payload, locationId: input.locationId });
    return { shiftId: id, queuedOffline: true };
  }
  try {
    await pushOp("open_shift", payload, opId);
    return { shiftId: id };
  } catch (err) {
    if (isNetworkFailure(err)) {
      enqueuePosOp({ opId, kind: "open_shift", payload, locationId: input.locationId });
      return { shiftId: id, queuedOffline: true };
    }
    throw err;
  }
}

export async function fetchShiftExpectedNow(shiftId: string): Promise<{
  shift_id: string;
  server_expected_cash: number;
  as_of: string;
}> {
  const { data, error } = await supabase.rpc("shift_expected_now", {
    p_shift_id: shiftId,
  });

  if (error) throw fromRaw(error);
  return data as { shift_id: string; server_expected_cash: number; as_of: string };
}

export interface CloseShiftInput {
  shiftId: string;
  expectedCash: number;
  countedCash: number;
  note?: string;
}

export async function closeCashierShift(input: CloseShiftInput): Promise<{
  shift_id: string;
  difference: number;
  server_expected_cash: number;
}> {
  return pushOp<{ shift_id: string; difference: number; server_expected_cash: number }>(
    "close_shift",
    {
      id: input.shiftId,
      expected_cash: input.expectedCash,
      counted_cash: input.countedCash,
      ...(input.note?.trim() ? { note: input.note.trim() } : {}),
      closed_at: new Date().toISOString(),
    },
  );
}
