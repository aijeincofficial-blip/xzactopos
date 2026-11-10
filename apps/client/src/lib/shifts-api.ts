import { fromRaw } from "./api.ts";
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
