import type { Sellable } from "./sell-api.ts";

export const PINNED_STORAGE_KEY = "xzactopos:web-pinned-products";

export function getStoredPinned(): string[] | null {
  try {
    if (typeof localStorage === "undefined") return null;
    const raw = localStorage.getItem(PINNED_STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

export function saveStoredPinned(skus: string[]) {
  try {
    if (typeof localStorage === "undefined") return;
    localStorage.setItem(PINNED_STORAGE_KEY, JSON.stringify(skus));
  } catch {
    // ignore
  }
}

export function resolveFastKeyProducts(all: Sellable[], customPinned: string[] | null): Sellable[] {
  if (customPinned === null) {
    return all.slice(0, 6);
  }
  const map = new Map(all.map((p) => [p.sku, p]));
  return customPinned.map((sku) => map.get(sku)).filter((p): p is Sellable => Boolean(p));
}

export function isSkuPinned(sku: string, all: Sellable[], customPinned: string[] | null): boolean {
  if (customPinned === null) {
    const defaultSkus = all.slice(0, 6).map((s) => s.sku);
    return defaultSkus.includes(sku);
  }
  return customPinned.includes(sku);
}

export function togglePinnedSku(sku: string, all: Sellable[], customPinned: string[] | null): string[] {
  const currentSkus = customPinned ?? all.slice(0, 6).map((s) => s.sku);
  return currentSkus.includes(sku)
    ? currentSkus.filter((s) => s !== sku)
    : [...currentSkus, sku];
}
