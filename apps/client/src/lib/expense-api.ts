import { uuidv7 } from "@pos/core";
import { fromRaw } from "./api.ts";
import { isOnline } from "./network.ts";
import {
  enqueuePosOp,
  isNetworkFailure,
  loadPosCache,
  pendingOptimisticExpenses,
  savePosCache,
} from "./pos-outbox.ts";
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
  pending?: boolean;
}

export type ExpenseStatusFilter = "all" | "active" | "voided";
export type ExpensePaidFromFilter = "all" | "cash" | "ewallet";

export interface ClientExpenseFilter {
  search?: string;
  category?: ExpenseCategory | "all";
  paidFrom?: ExpensePaidFromFilter;
  status?: ExpenseStatusFilter;
  fromDate?: string;
  toDate?: string;
}

export interface ExpenseSummary {
  activeCount: number;
  voidedCount: number;
  totalActive: number;
  cashOutflow: number;
  ewalletOutflow: number;
  operatingSpend: number;
  stockPurchases: number;
}

export function filterExpenseRows(
  rows: readonly ExpenseRow[],
  filter: ClientExpenseFilter,
): ExpenseRow[] {
  const q = (filter.search ?? "").trim().toLowerCase();
  const cat = filter.category && filter.category !== "all" ? filter.category : null;
  const paidFrom = filter.paidFrom && filter.paidFrom !== "all" ? filter.paidFrom : null;
  const status = filter.status ?? "all";
  const fromDate = filter.fromDate?.trim() || null;
  const toDate = filter.toDate?.trim() || null;

  return rows.filter((r) => {
    const isVoided = Boolean(r.voided_at);
    if (status === "active" && isVoided) return false;
    if (status === "voided" && !isVoided) return false;
    if (cat && r.category !== cat) return false;
    if (paidFrom && r.paid_from !== paidFrom) return false;

    const day = r.spent_at.slice(0, 10);
    if (fromDate && day < fromDate) return false;
    if (toDate && day > toDate) return false;

    if (q) {
      const major = (r.amount / 100).toFixed(2);
      const haystack = [
        r.note ?? "",
        r.category.replace(/_/g, " "),
        r.paid_from,
        r.wallet ?? "",
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

export function summarizeExpenseRows(rows: readonly ExpenseRow[]): ExpenseSummary {
  let activeCount = 0;
  let voidedCount = 0;
  let totalActive = 0;
  let cashOutflow = 0;
  let ewalletOutflow = 0;
  let operatingSpend = 0;
  let stockPurchases = 0;

  for (const r of rows) {
    if (r.voided_at) {
      voidedCount += 1;
      continue;
    }
    activeCount += 1;
    totalActive += r.amount;
    if (r.paid_from === "cash") {
      cashOutflow += r.amount;
    } else {
      ewalletOutflow += r.amount;
    }
    if (r.category === "stock_purchase") {
      stockPurchases += r.amount;
    } else {
      operatingSpend += r.amount;
    }
  }

  return {
    activeCount,
    voidedCount,
    totalActive,
    cashOutflow,
    ewalletOutflow,
    operatingSpend,
    stockPurchases,
  };
}

function mergeExpenses(base: ExpenseRow[], locationId: string, currency = "PHP"): ExpenseRow[] {
  const byId = new Map(base.map((e) => [e.id, e]));
  for (const opt of pendingOptimisticExpenses(locationId, currency)) {
    if (!byId.has(opt.id)) {
      byId.set(opt.id, {
        ...opt,
        category: opt.category as ExpenseCategory,
        wallet: (opt.wallet as Wallet | null) ?? null,
      });
    }
  }
  return Array.from(byId.values()).sort((a, b) => b.spent_at.localeCompare(a.spent_at));
}

export async function fetchRecentExpenses(locationId: string, currency = "PHP"): Promise<ExpenseRow[]> {
  const slot = `expenses:${locationId}`;
  try {
    const { data, error } = await supabase
      .from("expenses")
      .select("id, location_id, amount, currency, category, note, paid_from, wallet, spent_at, voided_at, void_reason, created_by")
      .eq("location_id", locationId)
      .order("spent_at", { ascending: false })
      .limit(200);

    if (error) throw fromRaw(error);
    const rows = data as ExpenseRow[];
    savePosCache(slot, rows);
    return mergeExpenses(rows, locationId, currency);
  } catch (err) {
    if (isNetworkFailure(err)) {
      const cached = loadPosCache<ExpenseRow[]>(slot) ?? [];
      return mergeExpenses(cached, locationId, currency);
    }
    throw err;
  }
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

export async function recordExpense(
  input: RecordExpenseInput,
): Promise<{ id: string; queuedOffline?: boolean }> {
  const id = uuidv7();
  const opId = uuidv7();
  const payload: Record<string, unknown> = {
    id,
    amount: input.amount,
    category: input.category,
    paid_from: input.paid_from,
    location_id: input.locationId,
    spent_at: input.spentAt ?? new Date().toISOString(),
    ...(input.wallet ? { wallet: input.wallet } : {}),
    ...(input.note?.trim() ? { note: input.note.trim() } : {}),
  };

  if (!isOnline()) {
    enqueuePosOp({ opId, kind: "record_expense", payload, locationId: input.locationId });
    return { id, queuedOffline: true };
  }
  try {
    await pushOp("record_expense", payload, opId);
    return { id };
  } catch (err) {
    if (isNetworkFailure(err)) {
      enqueuePosOp({ opId, kind: "record_expense", payload, locationId: input.locationId });
      return { id, queuedOffline: true };
    }
    throw err;
  }
}

export async function voidExpense(expenseId: string, reason?: string): Promise<void> {
  await pushOp("void_expense", {
    expense_id: expenseId,
    ...(reason?.trim() ? { reason: reason.trim() } : {}),
  });
}
