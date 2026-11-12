import { uuidv7 } from "@pos/core";
import type { CartLine } from "./sale-math.ts";

export const MAX_HELD_ORDERS = 20;

export interface HeldOrder {
  id: string;
  label: string;
  customerId: string;
  customerName?: string;
  discountText: string;
  lines: CartLine[];
  createdAt: string;
}

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export interface ParkOrderInput {
  id?: string;
  label?: string;
  customerId?: string;
  customerName?: string;
  discountText?: string;
  lines: CartLine[];
  createdAt?: string;
}

function defaultStorage(): StorageLike | undefined {
  try {
    return typeof window !== "undefined" ? window.localStorage : undefined;
  } catch {
    return undefined;
  }
}

export function heldOrdersStorageKey(locationId: string): string {
  return `xzactopos:held-orders:${locationId}`;
}

function sanitizeLine(raw: unknown): CartLine | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  if (typeof r.variantId !== "string" || !r.variantId) return null;
  if (typeof r.name !== "string") return null;
  const qty = Number(r.qty);
  const unitPrice = Number(r.unitPrice);
  if (!Number.isFinite(qty) || qty <= 0 || !Number.isFinite(unitPrice) || unitPrice < 0) return null;
  const catalogPrice = r.catalogPrice !== undefined ? Number(r.catalogPrice) : undefined;
  const discount = r.discount !== undefined ? Math.max(0, Math.trunc(Number(r.discount) || 0)) : 0;
  const unitCost = Number.isFinite(Number(r.unitCost)) ? Math.trunc(Number(r.unitCost)) : 0;
  const taxRate = Number.isFinite(Number(r.taxRate)) ? Number(r.taxRate) : 0;
  return {
    variantId: r.variantId,
    name: r.name,
    qty,
    unitPrice: Math.trunc(unitPrice),
    ...(catalogPrice !== undefined && Number.isFinite(catalogPrice)
      ? { catalogPrice: Math.trunc(catalogPrice) }
      : {}),
    discount,
    unitCost,
    taxRate,
    tracked: r.tracked !== false,
  };
}

export function loadHeldOrders(locationId: string, storage: StorageLike | undefined = defaultStorage()): HeldOrder[] {
  if (!locationId || !storage) return [];
  try {
    const raw = storage.getItem(heldOrdersStorageKey(locationId));
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    const out: HeldOrder[] = [];
    for (const entry of parsed) {
      if (!entry || typeof entry !== "object") continue;
      const e = entry as Record<string, unknown>;
      if (typeof e.id !== "string" || !e.id || !Array.isArray(e.lines)) continue;
      const lines = e.lines.map(sanitizeLine).filter((x): x is CartLine => x !== null);
      if (lines.length === 0) continue;
      out.push({
        id: e.id,
        label: typeof e.label === "string" ? e.label : "",
        customerId: typeof e.customerId === "string" ? e.customerId : "",
        ...(typeof e.customerName === "string" && e.customerName ? { customerName: e.customerName } : {}),
        discountText: typeof e.discountText === "string" ? e.discountText : "",
        lines,
        createdAt: typeof e.createdAt === "string" && e.createdAt ? e.createdAt : new Date(0).toISOString(),
      });
    }
    return out.slice(0, MAX_HELD_ORDERS);
  } catch {
    return [];
  }
}

export function saveHeldOrders(
  locationId: string,
  orders: HeldOrder[],
  storage: StorageLike | undefined = defaultStorage(),
): void {
  if (!locationId || !storage) return;
  try {
    const key = heldOrdersStorageKey(locationId);
    if (orders.length === 0) {
      storage.removeItem(key);
    } else {
      storage.setItem(key, JSON.stringify(orders.slice(0, MAX_HELD_ORDERS)));
    }
  } catch {
    // Ignore quota / private-mode storage errors
  }
}

export function parkOrder(
  locationId: string,
  input: ParkOrderInput,
  storage: StorageLike | undefined = defaultStorage(),
): { held: HeldOrder | null; orders: HeldOrder[] } {
  const existing = loadHeldOrders(locationId, storage);
  const cleanLines = input.lines.map(sanitizeLine).filter((x): x is CartLine => x !== null);
  if (!locationId || cleanLines.length === 0) {
    return { held: null, orders: existing };
  }
  const held: HeldOrder = {
    id: input.id ?? uuidv7(),
    label: (input.label ?? "").trim().slice(0, 60),
    customerId: input.customerId ?? "",
    ...(input.customerName?.trim() ? { customerName: input.customerName.trim() } : {}),
    discountText: (input.discountText ?? "").trim(),
    lines: cleanLines,
    createdAt: input.createdAt ?? new Date().toISOString(),
  };
  const next = [held, ...existing.filter((x) => x.id !== held.id)].slice(0, MAX_HELD_ORDERS);
  saveHeldOrders(locationId, next, storage);
  return { held, orders: next };
}

export function resumeHeldOrder(
  locationId: string,
  heldId: string,
  currentCart?: ParkOrderInput,
  storage: StorageLike | undefined = defaultStorage(),
): { resumed: HeldOrder | null; swapped: HeldOrder | null; orders: HeldOrder[] } {
  const existing = loadHeldOrders(locationId, storage);
  const target = existing.find((x) => x.id === heldId) ?? null;
  if (!target) {
    return { resumed: null, swapped: null, orders: existing };
  }
  let remaining = existing.filter((x) => x.id !== heldId);
  let swapped: HeldOrder | null = null;
  const activeLines = (currentCart?.lines ?? []).map(sanitizeLine).filter((x): x is CartLine => x !== null);
  if (activeLines.length > 0 && currentCart) {
    swapped = {
      id: currentCart.id ?? uuidv7(),
      label: (currentCart.label ?? "").trim().slice(0, 60),
      customerId: currentCart.customerId ?? "",
      ...(currentCart.customerName?.trim() ? { customerName: currentCart.customerName.trim() } : {}),
      discountText: (currentCart.discountText ?? "").trim(),
      lines: activeLines,
      createdAt: currentCart.createdAt ?? new Date().toISOString(),
    };
    remaining = [swapped, ...remaining].slice(0, MAX_HELD_ORDERS);
  }
  saveHeldOrders(locationId, remaining, storage);
  return { resumed: target, swapped, orders: remaining };
}

export function discardHeldOrder(
  locationId: string,
  heldId: string,
  storage: StorageLike | undefined = defaultStorage(),
): HeldOrder[] {
  const next = loadHeldOrders(locationId, storage).filter((x) => x.id !== heldId);
  saveHeldOrders(locationId, next, storage);
  return next;
}
