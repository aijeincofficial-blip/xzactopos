import { uuidv7 } from "@pos/core";
import { fromRaw } from "./api.ts";
import { isOnline } from "./network.ts";
import {
  enqueuePosOp,
  isNetworkFailure,
  loadPosCache,
  pendingOptimisticCustomers,
  pendingOptimisticUtangLedger,
  savePosCache,
} from "./pos-outbox.ts";
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
  pending?: boolean;
}

interface CachedUtangSnapshot {
  customers: Array<{ id: string; name: string; phone: string | null; due_on: string | null }>;
  ledger: Array<{ customer_id: string; amount: number }>;
}

function mergeUtangSnapshot(base: CachedUtangSnapshot): CustomerBalanceInput[] {
  const byId = new Map(base.customers.map((c) => [c.id, c]));
  for (const pendingCust of pendingOptimisticCustomers()) {
    if (!byId.has(pendingCust.id)) {
      byId.set(pendingCust.id, {
        id: pendingCust.id,
        name: pendingCust.name,
        phone: pendingCust.phone,
        due_on: null,
      });
    }
  }
  const mergedLedger = [
    ...base.ledger,
    ...pendingOptimisticUtangLedger().map((e) => ({
      customer_id: e.customer_id,
      amount: e.amount,
    })),
  ];
  return computeCustomerBalances(Array.from(byId.values()), mergedLedger);
}

export async function fetchCustomersWithBalances(): Promise<CustomerBalanceInput[]> {
  const slot = "utang:balances";
  try {
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

    const snapshot: CachedUtangSnapshot = {
      customers: custRes.data,
      ledger: ledgerRes.data,
    };
    savePosCache(slot, snapshot);
    return mergeUtangSnapshot(snapshot);
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<CachedUtangSnapshot>(slot);
      if (cached) return mergeUtangSnapshot(cached);
    }
    throw err;
  }
}

export async function fetchCustomerLedger(customerId: string): Promise<LedgerEntry[]> {
  const slot = `utang:ledger:${customerId}`;
  const optimistic = pendingOptimisticUtangLedger()
    .filter((e) => e.customer_id === customerId)
    .map(
      (e): LedgerEntry => ({
        id: e.id,
        kind: e.kind,
        amount: e.amount,
        sale_id: e.sale_id,
        note: e.note,
        occurred_at: e.occurred_at,
        method: e.method,
        location_id: e.location_id,
        pending: true,
      }),
    );

  try {
    const { data, error } = await supabase
      .from("customer_ledger")
      .select("id, kind, amount, sale_id, note, occurred_at, method, location_id")
      .eq("customer_id", customerId)
      .order("occurred_at", { ascending: false })
      .limit(100);

    if (error) throw fromRaw(error);
    const rows = data as LedgerEntry[];
    savePosCache(slot, rows);
    return [...optimistic, ...rows].sort((a, b) => b.occurred_at.localeCompare(a.occurred_at));
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<LedgerEntry[]>(slot) ?? [];
      return [...optimistic, ...cached].sort((a, b) => b.occurred_at.localeCompare(a.occurred_at));
    }
    throw err;
  }
}

export interface UtangPaymentInput {
  customerId: string;
  amount: number;
  method: "cash" | "ewallet";
  note?: string;
  locationId: string;
}

export async function recordUtangPayment(
  input: UtangPaymentInput,
): Promise<{ queuedOffline?: boolean }> {
  const opId = uuidv7();
  const payload: Record<string, unknown> = {
    customer_id: input.customerId,
    amount: input.amount,
    method: input.method,
    location_id: input.locationId,
    ...(input.note?.trim() ? { note: input.note.trim() } : {}),
    occurred_at: new Date().toISOString(),
  };

  if (!isOnline()) {
    enqueuePosOp({ opId, kind: "record_utang_payment", payload, locationId: input.locationId });
    return { queuedOffline: true };
  }
  try {
    await pushOp("record_utang_payment", payload, opId);
    return {};
  } catch (err) {
    if (isNetworkFailure(err)) {
      enqueuePosOp({ opId, kind: "record_utang_payment", payload, locationId: input.locationId });
      return { queuedOffline: true };
    }
    throw err;
  }
}

export async function setUtangDueDate(customerId: string, dueOn: string | null): Promise<void> {
  await pushOp("set_utang_due", {
    customer_id: customerId,
    due_on: dueOn,
  });
}

export interface AdjustUtangInput {
  customerId: string;
  amount: number;
  note?: string;
  locationId?: string;
}

export async function adjustUtang(input: AdjustUtangInput): Promise<void> {
  await pushOp("adjust_utang", {
    customer_id: input.customerId,
    amount: input.amount,
    ...(input.note?.trim() ? { note: input.note.trim() } : {}),
    ...(input.locationId ? { location_id: input.locationId } : {}),
    occurred_at: new Date().toISOString(),
  });
}
