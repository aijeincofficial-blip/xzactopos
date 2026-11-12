import { describe, expect, it } from "vitest";
import {
  MAX_HELD_ORDERS,
  discardHeldOrder,
  loadHeldOrders,
  parkOrder,
  resumeHeldOrder,
  type StorageLike,
} from "./held-orders.ts";
import type { CartLine } from "./sale-math.ts";

function memStorage(): StorageLike {
  const map = new Map<string, string>();
  return {
    getItem: (k) => map.get(k) ?? null,
    setItem: (k, v) => {
      map.set(k, v);
    },
    removeItem: (k) => {
      map.delete(k);
    },
  };
}

const sampleLine = (id: string, name: string, price = 1800, qty = 2, discount = 0): CartLine => ({
  variantId: id,
  name,
  qty,
  unitPrice: price,
  catalogPrice: price,
  discount,
  unitCost: 1200,
  taxRate: 0.12,
  tracked: true,
});

describe("held-orders", () => {
  it("parks, scopes by store location, and preserves per-line discounts and overrides", () => {
    const store = memStorage();
    const { held, orders } = parkOrder(
      "loc-1",
      {
        label: "Blue cap customer",
        customerId: "cust-1",
        customerName: "Juan Dela Cruz",
        discountText: "5",
        lines: [{ ...sampleLine("v-1", "Pancit Canton", 1600, 3, 200), catalogPrice: 1800 }],
      },
      store,
    );

    expect(held).not.toBeNull();
    expect(orders).toHaveLength(1);
    expect(loadHeldOrders("loc-2", store)).toEqual([]);

    const reloaded = loadHeldOrders("loc-1", store);
    expect(reloaded).toHaveLength(1);
    expect(reloaded[0]?.label).toBe("Blue cap customer");
    expect(reloaded[0]?.customerName).toBe("Juan Dela Cruz");
    expect(reloaded[0]?.lines[0]?.unitPrice).toBe(1600);
    expect(reloaded[0]?.lines[0]?.catalogPrice).toBe(1800);
    expect(reloaded[0]?.lines[0]?.discount).toBe(200);
  });

  it("swaps an active non-empty cart onto hold when resuming another parked order", () => {
    const store = memStorage();
    const first = parkOrder(
      "loc-1",
      { id: "h-1", label: "First", lines: [sampleLine("v-1", "Rice")] },
      store,
    ).held!;

    const { resumed, swapped, orders } = resumeHeldOrder(
      "loc-1",
      first.id,
      { id: "h-swap", label: "Current active", lines: [sampleLine("v-2", "Cooking Oil", 11000, 1)] },
      store,
    );

    expect(resumed?.id).toBe("h-1");
    expect(swapped?.id).toBe("h-swap");
    expect(orders.map((o) => o.id)).toEqual(["h-swap"]);
  });

  it("discards held orders and enforces MAX_HELD_ORDERS cap", () => {
    const store = memStorage();
    for (let i = 0; i < MAX_HELD_ORDERS + 5; i++) {
      parkOrder("loc-1", { id: `h-${i}`, label: `#${i}`, lines: [sampleLine(`v-${i}`, `Item ${i}`)] }, store);
    }
    const capped = loadHeldOrders("loc-1", store);
    expect(capped).toHaveLength(MAX_HELD_ORDERS);
    expect(capped[0]?.id).toBe(`h-${MAX_HELD_ORDERS + 4}`);

    const afterDiscard = discardHeldOrder("loc-1", capped[0]!.id, store);
    expect(afterDiscard).toHaveLength(MAX_HELD_ORDERS - 1);
  });
});
