import { uuidv7 } from "@pos/core";
import { fromRaw } from "./api.ts";
import { supabase } from "./supabase.ts";
import { pushOp } from "./sell-api.ts";
import { dayUtcBounds } from "./day-close-math.ts";
import { serviceCashEffect, type ServiceKind } from "./services-api.ts";

export interface DayCloseRow {
  id: string;
  location_id: string;
  day: string;
  currency: string;
  opening_cash: number;
  expected_cash: number;
  counted_cash: number;
  difference: number;
  server_expected_cash: number;
  note: string | null;
  closed_at: string;
  closed_by: string | null;
  approved_by: string | null;
}

export async function fetchDayCloses(locationId: string): Promise<DayCloseRow[]> {
  const { data, error } = await supabase
    .from("day_closes")
    .select("*")
    .eq("location_id", locationId)
    .order("day", { ascending: false })
    .limit(30);

  if (error) throw fromRaw(error);
  return data as DayCloseRow[];
}

export async function fetchTodayCashUtang(locationId: string, day: string, timezone: string): Promise<number> {
  const { from, to } = dayUtcBounds(day, timezone);
  const { data, error } = await supabase
    .from("customer_ledger")
    .select("amount")
    .eq("location_id", locationId)
    .eq("kind", "payment")
    .eq("method", "cash")
    .gte("occurred_at", from)
    .lt("occurred_at", to);

  if (error) throw fromRaw(error);
  // payment amounts in ledger are negative, so negate to get positive cash inflow
  return (data ?? []).reduce((acc, row) => acc + -row.amount, 0);
}

/** Net drawer cash effect (in centavos) from active service transactions & wallet float cash transfers today. */
export async function fetchTodayCashServices(locationId: string, day: string, timezone: string): Promise<number> {
  const { from, to } = dayUtcBounds(day, timezone);
  const { data, error } = await supabase
    .from("service_txns")
    .select("kind, amount, fee, price")
    .eq("location_id", locationId)
    .is("voided_at", null)
    .gte("txn_at", from)
    .lt("txn_at", to);

  if (error) throw fromRaw(error);
  return (data ?? []).reduce(
    (acc, row) => acc + serviceCashEffect(row.kind as ServiceKind, row.amount, row.fee ?? 0, row.price),
    0,
  );
}

export interface CloseDayInput {
  day: string;
  openingCash: number;
  expectedCash: number;
  countedCash: number;
  locationId: string;
  note?: string;
}

export async function closeDay(input: CloseDayInput): Promise<{ id: string; difference: number }> {
  const id = uuidv7();
  const res = await pushOp<{ day_close_id: string; difference: number }>("close_day", {
    id,
    day: input.day,
    opening_cash: input.openingCash,
    expected_cash: input.expectedCash,
    counted_cash: input.countedCash,
    location_id: input.locationId,
    ...(input.note?.trim() ? { note: input.note.trim() } : {}),
    closed_at: new Date().toISOString(),
  });

  return { id: res.day_close_id, difference: res.difference };
}
