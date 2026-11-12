import { afterEach, describe, expect, it } from "vitest";
import { ApiError } from "./api.ts";
import {
  applyOptimisticStockDeltas,
  discardPosOp,
  enqueuePosOp,
  flushPosOutbox,
  isNetworkFailure,
  loadPosCache,
  loadPosOutbox,
  pendingOptimisticCustomers,
  retryFailedPosOps,
  savePosCache,
  setPosOutboxTenant,
} from "./pos-outbox.ts";

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

describe("pos-outbox", () => {
  afterEach(() => {
    setPosOutboxTenant("default");
  });

  it("distinguishes network/transient errors from business ApiErrors", () => {
    expect(isNetworkFailure(new TypeError("Failed to fetch"))).toBe(true);
    expect(isNetworkFailure(new ApiError("temporary", "temporary server error 503"))).toBe(true);
    expect(isNetworkFailure(new ApiError("unknown", "TypeError: Failed to fetch"))).toBe(true);
    expect(isNetworkFailure(new ApiError("approval_required", "needs supervisor"))).toBe(false);
    expect(isNetworkFailure(new ApiError("not_allowed", "forbidden"))).toBe(false);
  });

  it("isolates cache and outbox queues per tenant", () => {
    const storage = new MemoryStorage();
    setPosOutboxTenant("tenant-a");
    savePosCache("sellables:PHP", [{ sku: "A-1" }], storage);
    enqueuePosOp({ opId: "op-a", kind: "record_sale", payload: { id: "sale-a" }, locationId: "loc-1" }, storage);

    setPosOutboxTenant("tenant-b");
    expect(loadPosCache("sellables:PHP", storage)).toBeNull();
    expect(loadPosOutbox(storage)).toEqual([]);

    setPosOutboxTenant("tenant-a");
    expect(loadPosCache("sellables:PHP", storage)).toEqual([{ sku: "A-1" }]);
    expect(loadPosOutbox(storage)).toHaveLength(1);
  });

  it("deduplicates by opId and computes optimistic customer & stock overlays", () => {
    const storage = new MemoryStorage();
    enqueuePosOp(
      {
        opId: "op-cust-1",
        kind: "upsert_customer",
        payload: { id: "c-1", name: "Ate Nena", phone: "09171234567" },
      },
      storage,
    );
    enqueuePosOp(
      {
        opId: "op-sale-1",
        kind: "record_sale",
        locationId: "store-1",
        payload: {
          location_id: "store-1",
          lines: [
            { variant_id: "v-1", qty: 3, tracked: true },
            { variant_id: "v-untracked", qty: 5, tracked: false },
          ],
        },
      },
      storage,
    );
    // Re-enqueueing same opId updates in place without duplicating
    enqueuePosOp(
      {
        opId: "op-sale-1",
        kind: "record_sale",
        locationId: "store-1",
        payload: {
          location_id: "store-1",
          lines: [{ variant_id: "v-1", qty: 2, tracked: true }],
        },
      },
      storage,
    );

    const ops = loadPosOutbox(storage);
    expect(ops).toHaveLength(2);
    expect(pendingOptimisticCustomers(ops)).toEqual([
      { id: "c-1", name: "Ate Nena", phone: "09171234567" },
    ]);

    const baseStock = new Map([
      ["v-1", 10],
      ["v-untracked", 4],
    ]);
    expect(applyOptimisticStockDeltas(baseStock, "store-1", ops).get("v-1")).toBe(8);
    expect(applyOptimisticStockDeltas(baseStock, "store-2", ops).get("v-1")).toBe(10);
  });

  it("flushes FIFO batches, marks permanent rejections as failed without blocking valid sales, and supports retry/discard", async () => {
    const storage = new MemoryStorage();
    enqueuePosOp({ opId: "op-1", kind: "upsert_customer", payload: { id: "c1", name: "Juan" } }, storage);
    enqueuePosOp({ opId: "op-2", kind: "record_sale", payload: { id: "s1" } }, storage);
    enqueuePosOp({ opId: "op-3", kind: "record_sale", payload: { id: "s2" } }, storage);

    const summary = await flushPosOutbox({
      storage,
      pushBatch: async (batch) => {
        expect(batch.map((b) => b.op_id)).toEqual(["op-1", "op-2", "op-3"]);
        return [
          { op_id: "op-1", status: "ok" },
          { op_id: "op-2", status: "rejected", hint: "approval_expired" },
          { op_id: "op-3", status: "ok" },
        ];
      },
    });

    expect(summary).toEqual({ synced: 2, remaining: 0, failed: 1 });
    const left = loadPosOutbox(storage);
    expect(left).toHaveLength(1);
    expect(left[0]?.opId).toBe("op-2");
    expect(left[0]?.state).toBe("failed");
    expect(left[0]?.lastError).toBe("approval_expired");

    retryFailedPosOps(storage);
    expect(loadPosOutbox(storage)[0]?.state).toBe("pending");

    discardPosOp("op-2", storage);
    expect(loadPosOutbox(storage)).toEqual([]);
  });
});
