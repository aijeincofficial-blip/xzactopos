import { fromRaw } from "./api.ts";
import { supabase } from "./supabase.ts";
import { pushOp } from "./sell-api.ts";
import { computeCustomerBalances, type CustomerBalanceInput } from "./utang-math.ts";

export interface LedgerEntry {
  id: string;
  kind: "charge" | "payment" | "adjust";
  amount: number;
  sale_id: string | null;
  note: string | null;
  occurred_at: string;
  method: "cash" | "ewallet";
  location_id: string | null;
}

export async function fetchCustomersWithBalances(): Promise<CustomerBalanceInput[]> {
  const [custRes, ledgerRes] = await Promise.all([
    supabase
      .from("customers")
      .select("id, name, phone, due_on")
      .is("deleted_at", null)
      .order("name")
      .limit(1000),
    supabase
      .from("customer_ledger")
      .select("customer_id, amount")
      .limit(50000),
  ]);

  if (custRes.error) throw fromRaw(custRes.error);
  if (ledgerRes.error) throw fromRaw(ledgerRes.error);

  return computeCustomerBalances(custRes.data, ledgerRes.data);
}

export async function fetchCustomerLedger(customerId: string): Promise<LedgerEntry[]> {
  const { data, error } = await supabase
    .from("customer_ledger")
    .select("id, kind, amount, sale_id, note, occurred_at, method, location_id")
    .eq("customer_id", customerId)
    .order("occurred_at", { ascending: false })
    .limit(100);

  if (error) throw fromRaw(error);
  return data as LedgerEntry[];
}

export interface UtangPaymentInput {
  customerId: string;
  amount: number;
  method: "cash" | "ewallet";
  note?: string;
  locationId: string;
}

export async function recordUtangPayment(input: UtangPaymentInput): Promise<void> {
  await pushOp("record_utang_payment", {
    customer_id: input.customerId,
    amount: input.amount,
    method: input.method,
    location_id: input.locationId,
    ...(input.note?.trim() ? { note: input.note.trim() } : {}),
    occurred_at: new Date().toISOString(),
  });
}

export async function setUtangDueDate(customerId: string, dueOn: string | null): Promise<void> {
  await pushOp("set_utang_due", {
    customer_id: customerId,
    due_on: dueOn,
  });
}
