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

interface CustomerBalanceRpcRow {
  customer_id: string;
  name: string;
  phone: string | null;
  due_on: string | null;
  balance: number;
}

export function mergeUtangBalances(base: ReadonlyArray<CustomerBalanceRpcRow>): CustomerBalanceInput[] {
  const snapshot: CachedUtangSnapshot = {
    customers: base.map((r) => ({
      id: r.customer_id,
      name: r.name,
      phone: r.phone,
      due_on: r.due_on,
    })),
    ledger: base
      .filter((r) => Number(r.balance) !== 0)
      .map((r) => ({
        customer_id: r.customer_id,
        amount: Number(r.balance),
      })),
  };
  return mergeUtangSnapshot(snapshot);
}

export async function fetchCustomersWithBalances(): Promise<CustomerBalanceInput[]> {
  const slot = "utang:balances:v2";
  try {
    const pageSize = 1000;
    const rows: CustomerBalanceRpcRow[] = [];
    for (let offset = 0; offset < 50_000; offset += pageSize) {
      const { data, error } = await supabase.rpc("customer_utang_balances", {
        p_limit: pageSize,
        p_offset: offset,
      });
      if (error) throw fromRaw(error);
      const batch = (data ?? []) as CustomerBalanceRpcRow[];
      rows.push(...batch);
      if (batch.length < pageSize) break;
    }

    savePosCache(slot, rows);
    return mergeUtangBalances(rows);
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<CustomerBalanceRpcRow[]>(slot);
      if (cached) return mergeUtangBalances(cached);
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
