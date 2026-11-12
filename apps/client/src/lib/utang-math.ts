/** Pure helper functions for utang calculations and overdue detection. */

export interface CustomerBalanceInput {
  customerId: string;
  name: string;
  phone: string | null;
  dueOn: string | null;
  balance: number;
}

/** Check if an utang balance is overdue: balance > 0 and dueOn is before today in the store's timezone. */
export function isOverdue(balance: number, dueOn: string | null, today: string): boolean {
  if (balance <= 0 || !dueOn) return false;
  return dueOn < today;
}

/** Calculate signed adjustment amount from magnitude and direction (less = negative, more = positive). */
export function calculateAdjustment(magnitude: number, direction: "less" | "more"): number {
  if (magnitude <= 0) return 0;
  return direction === "less" ? -Math.abs(magnitude) : Math.abs(magnitude);
}

/** Calculate customer balances given customer records and ledger entries. */
export function computeCustomerBalances(
  customers: ReadonlyArray<{ id: string; name: string; phone: string | null; due_on: string | null }>,
  ledgerEntries: ReadonlyArray<{ customer_id: string; amount: number }>,
): CustomerBalanceInput[] {
  const map = new Map<string, number>();
  for (const entry of ledgerEntries) {
    map.set(entry.customer_id, (map.get(entry.customer_id) ?? 0) + entry.amount);
  }

  return customers
    .map((c) => {
      const balance = map.get(c.id) ?? 0;
      return {
        customerId: c.id,
        name: c.name,
        phone: c.phone,
        dueOn: c.due_on,
        balance,
      };
    })
    .sort((a, b) => {
      // Sort by balance descending, then by name
      if (b.balance !== a.balance) return b.balance - a.balance;
      return a.name.localeCompare(b.name);
    });
}

export interface CustomerCreditStatus {
  hasBalance: boolean;
  overdue: boolean;
  currentBalance: number;
  projectedBalance: number;
  dueOn: string | null;
}

/** Filter and sort customers alphabetically for fast POS counter lookup by name or phone. */
export function filterCustomersForPos(
  customers: ReadonlyArray<CustomerBalanceInput>,
  query: string,
): CustomerBalanceInput[] {
  const q = query.trim().toLowerCase();
  const filtered = q
    ? customers.filter(
        (c) =>
          c.name.toLowerCase().includes(q) ||
          (c.phone !== null && c.phone.toLowerCase().includes(q)),
      )
    : [...customers];
  return filtered.sort((a, b) => a.name.localeCompare(b.name));
}

/** Evaluate whether a selected POS customer already owes Utang or is past their promised due date. */
export function evaluateCustomerCreditStatus(
  customer: Pick<CustomerBalanceInput, "balance" | "dueOn"> | null | undefined,
  today: string,
  additionalUtangMinor = 0,
): CustomerCreditStatus {
  const currentBalance = customer ? Math.max(0, customer.balance) : 0;
  const dueOn = customer?.dueOn ?? null;
  const add = Math.max(0, additionalUtangMinor);
  return {
    hasBalance: currentBalance > 0,
    overdue: isOverdue(currentBalance, dueOn, today),
    currentBalance,
    projectedBalance: currentBalance + add,
    dueOn,
  };
}
