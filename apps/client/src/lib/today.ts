import { rpc } from "./api.ts";

/** The part of `report_summary` the Today screen reads. Amounts are integer minor units (centavos). */
export interface DaySummary {
  totals: { net: number; gross: number; discount: number; txns: number; cash: number; ewallet: number; utang: number };
  expenses: { total: number; cash: number };
  utang: { owed: number };
  top_items: Array<{ variant_id: string; name: string; qty: number; revenue: number }>;
  services: { fee_total: number; float: Array<{ wallet: string; balance: number }> };
}

/** The calendar day (YYYY-MM-DD) right now in the business's timezone, not the browser's. */
export function dayInTimezone(timezone: string, now: Date = new Date()): string {
  try {
    return new Intl.DateTimeFormat("en-CA", { timeZone: timezone, year: "numeric", month: "2-digit", day: "2-digit" }).format(now);
  } catch {
    return now.toISOString().slice(0, 10);
  }
}

export const getDaySummary = (day: string) => rpc<DaySummary>("report_summary", { p_from: day, p_to: day });
