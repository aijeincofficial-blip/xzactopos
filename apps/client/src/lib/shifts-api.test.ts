import { beforeEach, describe, expect, it, vi } from "vitest";

const { pushOpMock, isOnlineMock, fromMock } = vi.hoisted(() => ({
  pushOpMock: vi.fn(),
  isOnlineMock: vi.fn(() => true),
  fromMock: vi.fn(),
}));

vi.mock("./sell-api.ts", () => ({
  pushOp: pushOpMock,
}));

vi.mock("./network.ts", () => ({
  isOnline: isOnlineMock,
}));

vi.mock("./supabase.ts", () => ({
  supabase: {
    from: fromMock,
    rpc: vi.fn(),
  },
}));

import { loadPosOutbox, setPosOutboxTenant } from "./pos-outbox.ts";
import { closeCashierShift, fetchMyOpenShift, openCashierShift } from "./shifts-api.ts";

class MemoryStorage implements Storage {
  private map = new Map<string, string>();
  get length(): number {
    return this.map.size;
  }
  clear(): void {
    this.map.clear();
  }
  getItem(key: string): string | null {
    return this.map.get(key) ?? null;
  }
  key(index: number): string | null {
    return Array.from(this.map.keys())[index] ?? null;
  }
  removeItem(key: string): void {
    this.map.delete(key);
  }
  setItem(key: string, value: string): void {
    this.map.set(key, value);
  }
}

describe("shifts-api", () => {
  beforeEach(() => {
    Object.defineProperty(globalThis, "localStorage", {
      value: new MemoryStorage(),
      configurable: true,
      writable: true,
    });
    setPosOutboxTenant("t-shifts");
    pushOpMock.mockReset();
    isOnlineMock.mockReset();
    isOnlineMock.mockReturnValue(true);
    fromMock.mockReset();
  });

  it("pushes open_shift online and builds close_shift payload", async () => {
    pushOpMock.mockResolvedValue({ shift_id: "s-1", difference: 0, server_expected_cash: 150000 });

    const opened = await openCashierShift({ locationId: "loc-1", openingCash: 100000 });
    expect(opened.queuedOffline).toBeUndefined();
    expect(pushOpMock).toHaveBeenCalledTimes(1);
    expect(pushOpMock.mock.calls[0]?.[0]).toBe("open_shift");
    expect(pushOpMock.mock.calls[0]?.[1]).toMatchObject({
      id: opened.shiftId,
      location_id: "loc-1",
      opening_cash: 100000,
    });

    await closeCashierShift({
      shiftId: opened.shiftId,
      expectedCash: 150000,
      countedCash: 149500,
      note: " ₱5 short ",
    });

    expect(pushOpMock.mock.calls[1]?.[0]).toBe("close_shift");
    expect(pushOpMock.mock.calls[1]?.[1]).toMatchObject({
      id: opened.shiftId,
      expected_cash: 150000,
      counted_cash: 149500,
      note: "₱5 short",
    });
  });

  it("queues open_shift offline and returns optimistic open shift when network fails", async () => {
    isOnlineMock.mockReturnValue(false);

    const opened = await openCashierShift({ locationId: "loc-2", openingCash: 250000 });
    expect(opened.queuedOffline).toBe(true);
    expect(loadPosOutbox()).toHaveLength(1);
    expect(loadPosOutbox()[0]?.kind).toBe("open_shift");

    fromMock.mockReturnValue({
      select: () => ({
        eq: () => ({
          is: () => ({
            order: () => ({
              limit: () => ({
                maybeSingle: () => Promise.reject(new TypeError("Failed to fetch")),
              }),
            }),
          }),
        }),
      }),
    });

    const active = await fetchMyOpenShift("cashier-1", "PHP");
    expect(active).not.toBeNull();
    expect(active?.id).toBe(opened.shiftId);
    expect(active?.opening_cash).toBe(250000);
    expect(active?.pending).toBe(true);
  });
});
