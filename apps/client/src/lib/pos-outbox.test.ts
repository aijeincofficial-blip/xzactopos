import { afterEach, describe, expect, it } from "vitest";
import { ApiError } from "./api.ts";
import {
  applyOptimisticStockDeltas,
  describeQueuedPosOp,
  discardPosOp,
  enqueuePosOp,
  flushPosOutbox,
  isNetworkFailure,
  loadPosCache,
  loadPosOutbox,
  pendingOptimisticCustomers,
  pendingOptimisticExpenses,
  pendingOptimisticServiceTxns,
  pendingOptimisticUtangLedger,
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

  it("extracts optimistic utang ledger entries, store expenses, and service transactions", () => {
    const storage = new MemoryStorage();
    enqueuePosOp(
      {
        opId: "op-sale-utang",
        kind: "record_sale",
        locationId: "loc-1",
        payload: {
          id: "sale-u1",
          local_no: "WAB-261112-0009",
          customer_id: "cust-1",
          sold_at: "2026-11-12T02:00:00Z",
          location_id: "loc-1",
          payments: [
            { method: "cash", amount: 1000 },
            { method: "utang", amount: 4500 },
          ],
        },
      },
      storage,
    );
    enqueuePosOp(
      {
        opId: "op-pay-utang",
        kind: "record_utang_payment",
        locationId: "loc-1",
        payload: {
          customer_id: "cust-1",
          amount: 2000,
          method: "cash",
          note: "Bayad partial",
          location_id: "loc-1",
          occurred_at: "2026-11-12T03:00:00Z",
        },
      },
      storage,
    );
    enqueuePosOp(
      {
        opId: "op-exp-1",
        kind: "record_expense",
        locationId: "loc-1",
        payload: {
          id: "exp-1",
          location_id: "loc-1",
          amount: 35000,
          category: "utilities",
          paid_from: "cash",
          note: "Ice delivery",
          spent_at: "2026-11-12T04:00:00Z",
        },
      },
      storage,
    );
    enqueuePosOp(
      {
        opId: "op-svc-1",
        kind: "record_service_txn",
        locationId: "loc-1",
        payload: {
          id: "svc-1",
          location_id: "loc-1",
          kind: "load",
          wallet: "load",
          amount: 5000,
          price: 5300,
          ref: "09171234567",
          txn_at: "2026-11-12T05:00:00Z",
        },
      },
      storage,
    );

    const ops = loadPosOutbox(storage);
    const ledger = pendingOptimisticUtangLedger(ops);
    expect(ledger).toEqual([
      {
        id: "op-sale-utang:utang",
        customer_id: "cust-1",
        kind: "charge",
        amount: 4500,
        sale_id: "sale-u1",
        note: "WAB-261112-0009",
        occurred_at: "2026-11-12T02:00:00Z",
        method: "cash",
        location_id: "loc-1",
        pending: true,
      },
      {
        id: "op-pay-utang",
        customer_id: "cust-1",
        kind: "payment",
        amount: -2000,
        sale_id: null,
        note: "Bayad partial",
        occurred_at: "2026-11-12T03:00:00Z",
        method: "cash",
        location_id: "loc-1",
        pending: true,
      },
    ]);

    const exps = pendingOptimisticExpenses("loc-1", "PHP", ops);
    expect(exps).toHaveLength(1);
    expect(exps[0]).toMatchObject({
      id: "exp-1",
      amount: 35000,
      category: "utilities",
      paid_from: "cash",
      pending: true,
    });
    expect(pendingOptimisticExpenses("loc-2", "PHP", ops)).toEqual([]);

    const svcs = pendingOptimisticServiceTxns("loc-1", "PHP", ops);
    expect(svcs).toHaveLength(1);
    expect(svcs[0]).toMatchObject({
      id: "svc-1",
      kind: "load",
      wallet: "load",
      amount: 5000,
      price: 5300,
      fee: 300,
      pending: true,
    });

    expect(describeQueuedPosOp(ops[0]!)).toEqual({
      primaryRef: "WAB-261112-0009",
      amountMinor: 5500,
    });
    expect(describeQueuedPosOp(ops[1]!)).toEqual({
      primaryRef: "cash",
      amountMinor: 2000,
    });
    expect(describeQueuedPosOp(ops[3]!)).toEqual({
      primaryRef: "LOAD",
      amountMinor: 5000,
    });
  });
});
