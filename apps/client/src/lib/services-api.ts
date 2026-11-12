import { uuidv7 } from "@pos/core";
import { fromRaw } from "./api.ts";
import { isOnline } from "./network.ts";
import type { OfflineApprovalPayload } from "./offline-pin-api.ts";
import {
  enqueuePosOp,
  isNetworkFailure,
  loadPosCache,
  pendingOptimisticServiceTxns,
  savePosCache,
} from "./pos-outbox.ts";
import { pushOp } from "./sell-api.ts";
import { supabase } from "./supabase.ts";

export type ServiceKind =
  | "cash_in"
  | "cash_out"
  | "load"
  | "float_topup"
  | "float_withdraw"
  | "float_adjust";

export type ServiceWallet = "gcash" | "maya" | "load" | "other";

export const CUSTOMER_SERVICE_KINDS = ["cash_in", "cash_out", "load"] as const;
export const FLOAT_SERVICE_KINDS = ["float_topup", "float_withdraw", "float_adjust"] as const;
export const EWALLET_OPTIONS: ServiceWallet[] = ["gcash", "maya", "other"];
export const ALL_SERVICE_WALLETS: ServiceWallet[] = ["gcash", "maya", "load", "other"];

export interface ServiceTxnRow {
  id: string;
  location_id: string;
  kind: ServiceKind;
  wallet: ServiceWallet;
  amount: number;
  fee: number;
  price: number | null;
  currency: string;
  ref: string | null;
  note: string | null;
  txn_at: string;
  voided_at: string | null;
  void_reason: string | null;
  created_by: string | null;
  pending?: boolean;
}

export interface WalletFloatRow {
  location_id: string;
  wallet: ServiceWallet;
  balance: number;
  txn_count: number;
  negative: boolean;
}

export type ServiceStatusFilter = "all" | "active" | "voided";

export interface ClientServiceFilter {
  search?: string;
  wallet?: ServiceWallet | "all";
  kind?: ServiceKind | "all";
  status?: ServiceStatusFilter;
  fromDate?: string;
  toDate?: string;
}

export interface ServiceTxnsSummary {
  activeCount: number;
  voidedCount: number;
  customerTxnCount: number;
  feeIncome: number;
  netCashEffect: number;
  netFloatEffect: number;
}

export function filterServiceTxns(
  rows: readonly ServiceTxnRow[],
  filter: ClientServiceFilter,
): ServiceTxnRow[] {
  const q = (filter.search ?? "").trim().toLowerCase();
  const wallet = filter.wallet && filter.wallet !== "all" ? filter.wallet : null;
  const kind = filter.kind && filter.kind !== "all" ? filter.kind : null;
  const status = filter.status ?? "all";
  const fromDate = filter.fromDate?.trim() || null;
  const toDate = filter.toDate?.trim() || null;

  return rows.filter((r) => {
    const isVoided = Boolean(r.voided_at);
    if (status === "active" && isVoided) return false;
    if (status === "voided" && !isVoided) return false;
    if (wallet && r.wallet !== wallet) return false;
    if (kind && r.kind !== kind) return false;

    const day = r.txn_at.slice(0, 10);
    if (fromDate && day < fromDate) return false;
    if (toDate && day > toDate) return false;

    if (q) {
      const major = (Math.abs(r.amount) / 100).toFixed(2);
      const haystack = [
        r.ref ?? "",
        r.note ?? "",
        r.kind.replace(/_/g, " "),
        r.wallet,
        r.void_reason ?? "",
        major,
      ]
        .join(" ")
        .toLowerCase();
      if (!haystack.includes(q)) return false;
    }

    return true;
  });
}

export function summarizeServiceTxns(rows: readonly ServiceTxnRow[]): ServiceTxnsSummary {
  let activeCount = 0;
  let voidedCount = 0;
  let customerTxnCount = 0;
  let feeIncome = 0;
  let netCashEffect = 0;
  let netFloatEffect = 0;

  for (const r of rows) {
    if (r.voided_at) {
      voidedCount += 1;
      continue;
    }
    activeCount += 1;
    if (r.kind === "cash_in" || r.kind === "cash_out" || r.kind === "load") {
      customerTxnCount += 1;
    }
    feeIncome += r.fee;
    netCashEffect += serviceCashEffect(r.kind, r.amount, r.fee, r.price);
    netFloatEffect += serviceFloatEffect(r.kind, r.amount);
  }

  return {
    activeCount,
    voidedCount,
    customerTxnCount,
    feeIncome,
    netCashEffect,
    netFloatEffect,
  };
}

/**
 * Pure drawer cash effect in centavos, matching `public.service_cash_effect` in Postgres.
 */
export function serviceCashEffect(
  kind: ServiceKind,
  amount: number,
  fee = 0,
  price?: number | null,
): number {
  switch (kind) {
    case "cash_in":
      return amount + fee;
    case "cash_out":
      return fee - amount;
    case "load":
      return price ?? amount + fee;
    case "float_topup":
      return -amount;
    case "float_withdraw":
      return amount;
    case "float_adjust":
      return 0;
  }
}

/**
 * Pure wallet float effect in centavos, matching `public.service_float_effect` in Postgres.
 */
export function serviceFloatEffect(kind: ServiceKind, amount: number): number {
  switch (kind) {
    case "cash_in":
    case "load":
    case "float_withdraw":
      return -amount;
    case "cash_out":
    case "float_topup":
    case "float_adjust":
      return amount;
  }
}

/**
 * Computes operating expenses excluding `stock_purchase` (which is already reflected in COGS when sold).
 */
export function computeOperatingExpenseBreakdown(expenses: {
  total: number;
  by_category: ReadonlyArray<{ category: string; amount: number }>;
}): { total: number; stockBought: number; operatingExpenses: number } {
  const total = expenses.total ?? 0;
  let stockBought = 0;
  for (const c of expenses.by_category ?? []) {
    if (c.category === "stock_purchase") {
      stockBought += c.amount;
    }
  }
  return {
    total,
    stockBought,
    operatingExpenses: Math.max(0, total - stockBought),
  };
}

function mergeWalletFloats(base: WalletFloatRow[], locationId: string): WalletFloatRow[] {
  const order: ServiceWallet[] = ["gcash", "maya", "load", "other"];
  const byWallet = new Map<ServiceWallet, WalletFloatRow>(
    base.map((row) => [row.wallet, { ...row }]),
  );
  for (const opt of pendingOptimisticServiceTxns(locationId)) {
    const wallet = opt.wallet as ServiceWallet;
    const kind = opt.kind as ServiceKind;
    const delta = serviceFloatEffect(kind, opt.amount);
    const existing = byWallet.get(wallet);
    if (existing) {
      const nextBalance = existing.balance + delta;
      byWallet.set(wallet, {
        ...existing,
        balance: nextBalance,
        txn_count: existing.txn_count + 1,
        negative: nextBalance < 0,
      });
    } else {
      byWallet.set(wallet, {
        location_id: locationId,
        wallet,
        balance: delta,
        txn_count: 1,
        negative: delta < 0,
      });
    }
  }
  return Array.from(byWallet.values()).sort(
    (a, b) => order.indexOf(a.wallet) - order.indexOf(b.wallet),
  );
}

function mergeServiceTxns(
  base: ServiceTxnRow[],
  locationId: string,
  currency = "PHP",
): ServiceTxnRow[] {
  const byId = new Map(base.map((t) => [t.id, t]));
  for (const opt of pendingOptimisticServiceTxns(locationId, currency)) {
    if (!byId.has(opt.id)) {
      byId.set(opt.id, {
        ...opt,
        kind: opt.kind as ServiceKind,
        wallet: opt.wallet as ServiceWallet,
      });
    }
  }
  return Array.from(byId.values()).sort((a, b) => b.txn_at.localeCompare(a.txn_at));
}

export async function fetchStoreWalletFloats(locationId: string): Promise<WalletFloatRow[]> {
  const slot = `wallet-floats:${locationId}`;
  try {
    const { data, error } = await supabase
      .from("wallet_float")
      .select("location_id, wallet, balance, txn_count, negative")
      .eq("location_id", locationId);

    if (error) throw fromRaw(error);
    const rows = (data ?? []) as WalletFloatRow[];
    savePosCache(slot, rows);
    return mergeWalletFloats(rows, locationId);
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<WalletFloatRow[]>(slot) ?? [];
      return mergeWalletFloats(cached, locationId);
    }
    throw err;
  }
}

export async function fetchRecentServiceTxns(
  locationId: string,
  currency = "PHP",
): Promise<ServiceTxnRow[]> {
  const slot = `service-txns:${locationId}`;
  try {
    const { data, error } = await supabase
      .from("service_txns")
      .select("id, location_id, kind, wallet, amount, fee, price, currency, ref, note, txn_at, voided_at, void_reason, created_by")
      .eq("location_id", locationId)
      .order("txn_at", { ascending: false })
      .limit(200);

    if (error) throw fromRaw(error);
    const rows = (data ?? []) as ServiceTxnRow[];
    savePosCache(slot, rows);
    return mergeServiceTxns(rows, locationId, currency);
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<ServiceTxnRow[]>(slot) ?? [];
      return mergeServiceTxns(cached, locationId, currency);
    }
    throw err;
  }
}

export interface RecordServiceTxnInput {
  id?: string;
  locationId: string;
  kind: ServiceKind;
  wallet: ServiceWallet;
  amount: number;
  fee?: number;
  price?: number;
  ref?: string;
  note?: string;
  txnAt?: string;
  approvalId?: string;
  offlineApproval?: OfflineApprovalPayload;
}

export async function submitServiceTxn(
  input: RecordServiceTxnInput,
): Promise<{ id: string; queuedOffline?: boolean }> {
  const id = input.id ?? uuidv7();
  const payload: Record<string, unknown> = {
    id,
    location_id: input.locationId,
    kind: input.kind,
    wallet: input.wallet,
    amount: input.amount,
    txn_at: input.txnAt ?? new Date().toISOString(),
    ...(input.kind === "load" && input.price !== undefined ? { price: input.price } : {}),
    ...(input.kind !== "load" && input.fee !== undefined && input.fee > 0 ? { fee: input.fee } : {}),
    ...(input.ref?.trim() ? { ref: input.ref.trim() } : {}),
    ...(input.note?.trim() ? { note: input.note.trim() } : {}),
    ...(input.approvalId ? { approval_id: input.approvalId } : {}),
    ...(input.offlineApproval ? { offline_approval: input.offlineApproval } : {}),
  };

  if (!isOnline()) {
    enqueuePosOp({ opId: uuidv7(), kind: "record_service_txn", payload, locationId: input.locationId });
    return { id, queuedOffline: true };
  }
  try {
    await pushOp("record_service_txn", payload);
    return { id };
  } catch (err) {
    if (isNetworkFailure(err)) {
      enqueuePosOp({ opId: uuidv7(), kind: "record_service_txn", payload, locationId: input.locationId });
      return { id, queuedOffline: true };
    }
    throw err;
  }
}

export async function recordServiceTxn(input: RecordServiceTxnInput): Promise<string> {
  const res = await submitServiceTxn(input);
  return res.id;
}

export async function voidServiceTxn(input: {
  txnId: string;
  reason?: string;
  approvalId?: string;
  offlineApproval?: OfflineApprovalPayload;
}): Promise<void> {
  await pushOp("void_service_txn", {
    txn_id: input.txnId,
    ...(input.reason?.trim() ? { reason: input.reason.trim() } : {}),
    ...(input.approvalId ? { approval_id: input.approvalId } : {}),
    ...(input.offlineApproval ? { offline_approval: input.offlineApproval } : {}),
  });
}
