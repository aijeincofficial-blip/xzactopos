import { uuidv7 } from "@pos/core";
import { fromRaw } from "./api.ts";
import { supabase } from "./supabase.ts";
import { pushOp } from "./sell-api.ts";
import type { Wallet } from "./sale-math.ts";

export type ExpenseCategory = "stock_purchase" | "utilities" | "transport" | "wages" | "rent" | "other";

export const EXPENSE_CATEGORIES: ExpenseCategory[] = [
  "stock_purchase",
  "utilities",
  "transport",
  "wages",
  "rent",
  "other",
];

export interface ExpenseRow {
  id: string;
  location_id: string;
  amount: number;
  currency: string;
  category: ExpenseCategory;
  note: string | null;
  paid_from: "cash" | "ewallet";
  wallet: Wallet | null;
  spent_at: string;
  voided_at: string | null;
  void_reason: string | null;
  created_by: string | null;
}

export async function fetchRecentExpenses(locationId: string): Promise<ExpenseRow[]> {
  const { data, error } = await supabase
    .from("expenses")
    .select("id, location_id, amount, currency, category, note, paid_from, wallet, spent_at, voided_at, void_reason, created_by")
    .eq("location_id", locationId)
    .order("spent_at", { ascending: false })
    .limit(50);

  if (error) throw fromRaw(error);
  return data as ExpenseRow[];
}

export interface RecordExpenseInput {
  amount: number;
  category: ExpenseCategory;
  paid_from: "cash" | "ewallet";
  wallet?: Wallet;
  note?: string;
  locationId: string;
  spentAt?: string;
}

export async function recordExpense(input: RecordExpenseInput): Promise<void> {
  const id = uuidv7();
  await pushOp("record_expense", {
    id,
    amount: input.amount,
    category: input.category,
    paid_from: input.paid_from,
    location_id: input.locationId,
    spent_at: input.spentAt ?? new Date().toISOString(),
    ...(input.wallet ? { wallet: input.wallet } : {}),
    ...(input.note?.trim() ? { note: input.note.trim() } : {}),
  });
}

export async function voidExpense(expenseId: string, reason?: string): Promise<void> {
  await pushOp("void_expense", {
    expense_id: expenseId,
    ...(reason?.trim() ? { reason: reason.trim() } : {}),
  });
}
