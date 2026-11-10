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
