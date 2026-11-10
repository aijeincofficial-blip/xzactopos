export interface Denomination {
  id: string;
  value: number; // in currency units e.g. 1000, 500, 0.25
  label: string; // e.g. "1,000", "500", "0.25"
  type: "bill" | "coin";
}

export const PHP_DENOMINATIONS: readonly Denomination[] = [
  { id: "bill_1000", value: 1000, label: "1,000", type: "bill" },
  { id: "bill_500", value: 500, label: "500", type: "bill" },
  { id: "bill_200", value: 200, label: "200", type: "bill" },
  { id: "bill_100", value: 100, label: "100", type: "bill" },
  { id: "bill_50", value: 50, label: "50", type: "bill" },
  { id: "bill_20", value: 20, label: "20", type: "bill" },
  { id: "coin_20", value: 20, label: "20", type: "coin" },
  { id: "coin_10", value: 10, label: "10", type: "coin" },
  { id: "coin_5", value: 5, label: "5", type: "coin" },
  { id: "coin_1", value: 1, label: "1", type: "coin" },
  { id: "coin_025", value: 0.25, label: "0.25", type: "coin" },
];

export type DenominationCounts = Record<string, number>;

export function calculateDenominationTotal(
  denominations: readonly Denomination[],
  counts: DenominationCounts
): number {
  return denominations.reduce((acc, d) => {
    const qty = counts[d.id] ?? 0;
    if (qty > 0) {
      // Use round to avoid floating point precision quirks
      return Math.round((acc + d.value * qty) * 100) / 100;
    }
    return acc;
  }, 0);
}
