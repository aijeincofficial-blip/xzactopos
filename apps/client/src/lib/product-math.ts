/** Small, pure rules for the Products and stock screen (parsing what the user types, and stock status). */

/** A quantity typed by the user: up to 3 decimals, below a billion. Zero is allowed only for a count. */
export function parseQty(text: string, opts: { allowZero?: boolean } = {}): number | null {
  const v = text.trim();
  if (!/^\d{1,9}(\.\d{1,3})?$/.test(v)) return null;
  const n = Number(v);
  if (n >= 1_000_000_000) return null;
  if (n === 0 && !opts.allowZero) return null;
  return n;
}

/** "12" or "12.5" (percent) to the stored rate (0.12, 0.125). Empty = no tax. Null when not a valid percentage. */
export function parseTaxPercent(text: string): number | null {
  const v = text.trim();
  if (v === "") return 0;
  if (!/^\d{1,2}(\.\d{1,2})?$/.test(v)) return null;
  return Math.round(Number(v) * 100) / 10_000;
}

/** The stored rate as the percent text shown in the form (0.125 becomes "12.5", 0 becomes ""). */
export function taxPercentText(rate: number): string {
  if (!rate) return "";
  return String(Math.round(rate * 10_000) / 100);
}

/** Quantity for display: no trailing zeros ("2", "1.5", "0.25"). */
export function formatQty(n: number): string {
  return String(Math.round(n * 1000) / 1000);
}

export type StockStatus = "untracked" | "out" | "low" | "ok";

/** out = nothing (or less) on the shelf; low = at or under the reorder point (when one is set). */
export function stockStatus(row: { tracked: boolean; qty: number; reorderPoint: number }): StockStatus {
  if (!row.tracked) return "untracked";
  if (row.qty <= 0) return "out";
  if (row.reorderPoint > 0 && row.qty <= row.reorderPoint) return "low";
  return "ok";
}
