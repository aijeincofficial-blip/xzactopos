/**
 * Sale arithmetic for the web Sell screen. It must give the same centavos as the phone app
 * (`apps/mobile/lib/data/sales_models.dart`, class SaleLine) and as `op_record_sale` on the server,
 * which rejects a sale whose line, subtotal or total does not match. Money is integer minor units; the
 * quantity may be fractional (rice by the kilo) and is handled in thousandths so no float noise appears.
 */

import { fromMajor } from "@pos/core";

/** Quantity in thousandths. */
export const milli = (qty: number): number => Math.round(qty * 1000);

/** Gross line total before per-line discount: qty x price, rounded half up. */
export function lineGrossTotal(qty: number, unitPrice: number): number {
  return Math.floor((milli(qty) * unitPrice + 500) / 1000);
}

/** Net line total: (qty x price, rounded half up) - discount, clamped at 0. */
export function lineTotal(qty: number, unitPrice: number, discount = 0): number {
  return Math.max(0, lineGrossTotal(qty, unitPrice) - discount);
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
  catalogPrice?: number;
  discount?: number;
  unitCost: number;
  taxRate: number;
  tracked: boolean;
}

export function cartGrossSubtotal(lines: readonly CartLine[]): number {
  return lines.reduce((a, l) => a + lineGrossTotal(l.qty, l.unitPrice), 0);
}

export function cartLineDiscounts(lines: readonly CartLine[]): number {
  return lines.reduce((a, l) => a + (l.discount ?? 0), 0);
}

export function cartSubtotal(lines: readonly CartLine[]): number {
  return lines.reduce((a, l) => a + lineTotal(l.qty, l.unitPrice, l.discount ?? 0), 0);
}

export function cartTotalDiscount(lines: readonly CartLine[], cartDiscount: number): number {
  return cartDiscount + cartLineDiscounts(lines);
}

export function cartTotal(lines: readonly CartLine[], discount: number): number {
  return cartSubtotal(lines) - discount;
}

/**
 * Returns true when a cashier's line-level or cart-level discounts (or downward price overrides)
 * require supervisor PIN approval (`action: "sale_discount"`).
 */
export function cartNeedsDiscountApproval(params: {
  role: string | null;
  lines: readonly CartLine[];
  cartDiscount: number;
  maxDiscountPercent: number;
}): boolean {
  const { role, lines, cartDiscount, maxDiscountPercent } = params;
  if (role !== "cashier" || lines.length === 0) return false;
  if (lines.some((l) => l.catalogPrice !== undefined && l.unitPrice < l.catalogPrice)) {
    return true;
  }
  const gross = cartGrossSubtotal(lines);
  const totalDisc = cartTotalDiscount(lines, cartDiscount);
  return gross > 0 && totalDisc * 100 > gross * maxDiscountPercent;
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
  | "qty_invalid"
  | "amount_invalid";

export function draftProblem(d: SaleDraft): DraftProblem | null {
  if (d.lines.length === 0) return "empty";
  if (d.lines.some((l) => !(l.qty > 0) || l.qty >= 1_000_000)) return "qty_invalid";
  if (d.lines.some((l) => !Number.isInteger(l.unitPrice) || l.unitPrice < 0)) return "amount_invalid";
  for (const l of d.lines) {
    const disc = l.discount ?? 0;
    const gross = lineGrossTotal(l.qty, l.unitPrice);
    if (!Number.isInteger(disc) || disc < 0 || disc > gross) return "discount_invalid";
  }
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
      const disc = l.discount ?? 0;
      const total = lineTotal(l.qty, l.unitPrice, disc);
      return {
        variant_id: l.variantId,
        name: l.name,
        qty: l.qty,
        unit_price: l.unitPrice,
        unit_cost: l.unitCost,
        ...(disc > 0 ? { discount: disc } : {}),
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

export interface ReturnMathItem {
  variantId: string;
  soldQty: number;
  alreadyReturnedQty: number;
  lineTotal: number;
  returnQty: number;
}

/**
 * Computes the exact pro-rata refund in minor units for a partial or full remaining return,
 * matching `op_return_sale_items` on the server (including cart-level discount share and
 * zero-centavo drift when all remaining units on the receipt are returned).
 */
export function computePartialReturnRefund(params: {
  saleSubtotal: number;
  saleDiscount: number;
  saleTotal: number;
  alreadyRefundedTotal: number;
  items: readonly ReturnMathItem[];
}): number {
  const { saleSubtotal, saleDiscount, saleTotal, alreadyRefundedTotal, items } = params;
  let totalSoldUnits = 0;
  let totalPrevUnits = 0;
  let totalReqUnits = 0;
  let refundSum = 0;

  for (const it of items) {
    totalSoldUnits += milli(it.soldQty);
    totalPrevUnits += milli(it.alreadyReturnedQty);
    const req = Math.max(0, Math.min(it.returnQty, it.soldQty - it.alreadyReturnedQty));
    if (req <= 0 || it.soldQty <= 0) continue;
    totalReqUnits += milli(req);

    let lineSub: number;
    if (milli(it.alreadyReturnedQty) + milli(req) === milli(it.soldQty)) {
      const prevSub = Math.round(it.lineTotal * (it.alreadyReturnedQty / it.soldQty));
      lineSub = Math.max(0, it.lineTotal - prevSub);
    } else {
      lineSub = Math.round(it.lineTotal * (req / it.soldQty));
    }

    const lineDisc =
      saleSubtotal > 0 && saleDiscount > 0
        ? Math.min(lineSub, Math.round((saleDiscount * lineSub) / saleSubtotal))
        : 0;
    refundSum += Math.max(0, lineSub - lineDisc);
  }

  if (totalReqUnits === 0) return 0;
  if (totalPrevUnits + totalReqUnits === totalSoldUnits) {
    return Math.max(0, saleTotal - alreadyRefundedTotal);
  }
  return refundSum;
}
