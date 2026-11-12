import { uuidv7 } from "@pos/core";
import { fromRaw } from "./api.ts";
import type { OfflineApprovalPayload } from "./offline-pin-api.ts";
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
}

export interface WalletFloatRow {
  location_id: string;
  wallet: ServiceWallet;
  balance: number;
  txn_count: number;
  negative: boolean;
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

export async function fetchStoreWalletFloats(locationId: string): Promise<WalletFloatRow[]> {
  const { data, error } = await supabase
    .from("wallet_float")
    .select("location_id, wallet, balance, txn_count, negative")
    .eq("location_id", locationId);

  if (error) throw fromRaw(error);
  const order: ServiceWallet[] = ["gcash", "maya", "load", "other"];
  return ((data ?? []) as WalletFloatRow[]).sort(
    (a, b) => order.indexOf(a.wallet) - order.indexOf(b.wallet),
  );
}

export async function fetchRecentServiceTxns(locationId: string): Promise<ServiceTxnRow[]> {
  const { data, error } = await supabase
    .from("service_txns")
    .select("id, location_id, kind, wallet, amount, fee, price, currency, ref, note, txn_at, voided_at, void_reason, created_by")
    .eq("location_id", locationId)
    .order("txn_at", { ascending: false })
    .limit(50);

  if (error) throw fromRaw(error);
  return (data ?? []) as ServiceTxnRow[];
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

export async function recordServiceTxn(input: RecordServiceTxnInput): Promise<string> {
  const id = input.id ?? uuidv7();
  await pushOp("record_service_txn", {
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
  });
  return id;
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
