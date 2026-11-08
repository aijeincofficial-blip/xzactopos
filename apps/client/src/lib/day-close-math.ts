/** Pure arithmetic and date boundary helpers for Day Close. */

export interface CashFlowSummary {
  openingCash: number;
  cashSales: number;
  cashUtangPayments: number;
  cashExpenses: number;
}

/** Expected cash in the drawer = opening cash + cash sales + cash utang payments - cash expenses. */
export function computeExpectedCash(flow: CashFlowSummary): number {
  return flow.openingCash + flow.cashSales + flow.cashUtangPayments - flow.cashExpenses;
}

/** Difference = counted cash - expected cash. Positive = Over, negative = Short. */
export function computeDifference(countedCash: number, expectedCash: number): number {
  return countedCash - expectedCash;
}

/** Given a YYYY-MM-DD string and an IANA timezone, returns UTC ISO string boundaries [from, to). */
export function dayUtcBounds(day: string, timezone: string): { from: string; to: string } {
  // Use noon UTC to avoid daylight savings edge cases when formatting
  // Parse year, month, day
  const [y, m, d] = day.split("-").map(Number);
  if (!y || !m || !d) {
    return { from: `${day}T00:00:00.000Z`, to: `${day}T23:59:59.999Z` };
  }

  // Construct start and end in target timezone
  // For standard timezone offsets, calculate start of day:
  // Using Intl to find the exact offset for the date in that timezone
  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    });

    // Approximate UTC guess
    const startGuess = new Date(Date.UTC(y, m - 1, d, 0, 0, 0));
    const parts = formatter.formatToParts(startGuess);
    const getPart = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? 0);
    const tzHour = getPart("hour") % 24;
    const tzDay = getPart("day");

    // Offset in hours between UTC and target timezone on that day
    let offsetHours = tzHour;
    if (tzDay > d) offsetHours += 24;
    else if (tzDay < d) offsetHours -= 24;

    const fromDate = new Date(Date.UTC(y, m - 1, d, -offsetHours, 0, 0));
    const toDate = new Date(Date.UTC(y, m - 1, d + 1, -offsetHours, 0, 0));
    return { from: fromDate.toISOString(), to: toDate.toISOString() };
  } catch {
    return { from: `${day}T00:00:00.000Z`, to: `${day}T23:59:59.999Z` };
  }
}
