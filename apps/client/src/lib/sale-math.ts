/**
 * Sale arithmetic for the web Sell screen. It must give the same centavos as the phone app
 * (`apps/mobile/lib/data/sales_models.dart`, class SaleLine) and as `op_record_sale` on the server,
 * which rejects a sale whose line, subtotal or total does not match. Money is integer minor units; the
 * quantity may be fractional (rice by the kilo) and is handled in thousandths so no float noise appears.
 */

import { fromMajor } from "@pos/core";

/** Quantity in thousandths. */
export const milli = (qty: number): number => Math.round(qty * 1000);

/** qty x price, rounded half up. */
export function lineTotal(qty: number, unitPrice: number): number {
  return Math.floor((milli(qty) * unitPrice + 500) / 1000);
}

/** Tax contained in a tax-inclusive line total: total x rate / (1 + rate), in whole centavos (0.12 = 12%). */
export function lineTax(total: number, taxRate: number): number {
  const bp = Math.round(taxRate * 10000);
  if (bp <= 0) return 0;
  return Math.floor((total * bp + Math.floor((10000 + bp) / 2)) / (10000 + bp));
}

export interface CartLine {
  variantId: string;
  name: string;
  qty: number;
  unitPrice: number;
  unitCost: number;
  taxRate: number;
  tracked: boolean;
}

export function cartSubtotal(lines: readonly CartLine[]): number {
  return lines.reduce((a, l) => a + lineTotal(l.qty, l.unitPrice), 0);
}

export function cartTotal(lines: readonly CartLine[], discount: number): number {
  return cartSubtotal(lines) - discount;
}

/** Change to give back for a cash payment of `amount` when the customer handed over `tendered`. */
export function changeDue(tendered: number, amount: number): number {
  return Math.max(0, tendered - amount);
}

export type PayMethod = "cash" | "ewallet" | "utang" | "card";
export type Wallet = "gcash" | "maya" | "other";

export interface PaymentDraft {
  method: PayMethod;
  amount: number;
  tendered?: number;
  wallet?: Wallet;
  reference?: string;
}

export interface SaleDraft {
  id: string;
  localNo: string;
  soldAt: Date;
  locationId: string;
  deviceId?: string | undefined;
  customerId?: string | undefined;
  discount: number;
  approvalId?: string | undefined;
  offlineApproval?: {
    approver_id: string;
    action: string;
    ref_id: string;
    approved_at: string;
  } | undefined;
  lines: readonly CartLine[];
  payments: readonly PaymentDraft[];
}

/** Why a draft cannot be sent, as a stable key the UI maps to a message (same rules the server enforces). */
export type DraftProblem =
  | "empty"
  | "discount_invalid"
  | "payments_mismatch"
  | "tendered_too_low"
  | "customer_required"
  | "qty_invalid";

export function draftProblem(d: SaleDraft): DraftProblem | null {
  if (d.lines.length === 0) return "empty";
  if (d.lines.some((l) => !(l.qty > 0) || l.qty >= 1_000_000)) return "qty_invalid";
  const sub = cartSubtotal(d.lines);
  if (d.discount < 0 || d.discount > sub) return "discount_invalid";
  const paid = d.payments.reduce((a, p) => a + p.amount, 0);
  if (paid !== sub - d.discount) return "payments_mismatch";
  if (d.payments.some((p) => p.method === "cash" && p.tendered !== undefined && p.tendered < p.amount)) {
    return "tendered_too_low";
  }
  if (d.payments.some((p) => p.method === "utang") && !d.customerId) return "customer_required";
  return null;
}

/** The `record_sale` op payload for `sync_push` (same shape the phone enqueues). */
export function salePayload(d: SaleDraft): Record<string, unknown> {
  const sub = cartSubtotal(d.lines);
  return {
    id: d.id,
    local_no: d.localNo,
    location_id: d.locationId,
    ...(d.deviceId ? { device_id: d.deviceId } : {}),
    ...(d.approvalId ? { approval_id: d.approvalId } : {}),
    ...(d.offlineApproval ? { offline_approval: d.offlineApproval } : {}),
    sold_at: d.soldAt.toISOString(),
    subtotal: sub,
    discount: d.discount,
    total: sub - d.discount,
    ...(d.customerId ? { customer_id: d.customerId } : {}),
    items: d.lines.map((l) => {
      const total = lineTotal(l.qty, l.unitPrice);
      return {
        variant_id: l.variantId,
        name: l.name,
        qty: l.qty,
        unit_price: l.unitPrice,
        unit_cost: l.unitCost,
        tax: lineTax(total, l.taxRate),
        line_total: total,
      };
    }),
    payments: d.payments.map((p) => ({
      method: p.method,
      amount: p.amount,
      ...(p.method === "cash" ? { tendered: p.tendered ?? p.amount } : {}),
      ...(p.reference ? { reference: p.reference } : {}),
      ...(p.method === "ewallet" && p.wallet ? { wallet: p.wallet } : {}),
    })),
  };
}

export interface PaymentChoice {
  /** How the customer pays now; "utang" puts the whole sale on their account. */
  method: PayMethod;
  /** Amount paid now in minor units; null = the whole total. Anything left over goes on utang. */
  paidNow: number | null;
  /** Cash handed over (cash only); null or 0 = exact. */
  tendered: number | null;
  wallet?: Wallet;
  reference?: string;
}

/**
 * The payments list for a sale: the part paid now (cash or e-wallet), and whatever is left on utang.
 * Returns null when the chosen amount is more than the total or below zero. A zero total has no payments.
 */
export function buildPayments(total: number, c: PaymentChoice): PaymentDraft[] | null {
  if (total <= 0) return total === 0 ? [] : null;
  if (c.method === "utang") return [{ method: "utang", amount: total }];
  const paid = c.paidNow ?? total;
  if (paid < 0 || paid > total) return null;
  const out: PaymentDraft[] = [];
  if (paid > 0) {
    if (c.method === "cash") {
      out.push({ method: "cash", amount: paid, tendered: c.tendered && c.tendered > 0 ? c.tendered : paid });
    } else if (c.method === "card") {
      out.push({ method: "card", amount: paid, ...(c.reference ? { reference: c.reference } : {}) });
    } else {
      out.push({ method: "ewallet", amount: paid, ...(c.wallet ? { wallet: c.wallet } : {}), ...(c.reference ? { reference: c.reference } : {}) });
    }
  }
  if (paid < total) out.push({ method: "utang", amount: total - paid });
  return out;
}

/** Cash typed by the user ("125.50") to minor units; empty = 0; null when it is not a valid amount for the currency. */
export function parseAmount(value: string, currency: string): number | null {
  const v = value.trim();
  if (v === "") return 0;
  try {
    const m = fromMajor(v, currency);
    return m.amount >= 0 ? m.amount : null;
  } catch {
    return null;
  }
}

/** `<device code>-YYMMDD-NNNN`: the provisional receipt number (3 to 40 characters, unique per device). */
export function localReceiptNo(deviceCode: string, day: string, seq: number): string {
  return `${deviceCode}-${day.slice(2, 4)}${day.slice(5, 7)}${day.slice(8, 10)}-${String(seq).padStart(4, "0")}`;
}
