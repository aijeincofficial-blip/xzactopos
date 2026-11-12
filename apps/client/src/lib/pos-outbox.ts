import { useSyncExternalStore } from "react";
import { ApiError, rpc } from "./api.ts";
import { isOnline } from "./network.ts";

export const POS_OUTBOX_OP_KINDS = [
  "upsert_customer",
  "record_sale",
  "record_utang_payment",
  "record_expense",
  "record_service_txn",
  "open_shift",
] as const;

export type PosOutboxOpKind = (typeof POS_OUTBOX_OP_KINDS)[number];

function isPosOutboxOpKind(v: unknown): v is PosOutboxOpKind {
  return typeof v === "string" && (POS_OUTBOX_OP_KINDS as readonly string[]).includes(v);
}

export interface QueuedPosOp {
  opId: string;
  kind: PosOutboxOpKind;
  payload: Record<string, unknown>;
  locationId?: string;
  createdAt: string;
  state: "pending" | "failed";
  attempts: number;
  lastError?: string;
}

export interface SyncPushItemResult {
  op_id: string;
  status: "ok" | "rejected" | "error";
  hint?: string;
  code?: string;
}

const CACHE_PREFIX = "xzactopos:pos-cache";
const OUTBOX_PREFIX = "xzactopos:pos-outbox";
const MAX_BATCH = 25;

let currentTenantId = "default";
const listeners = new Set<() => void>();

function notifyListeners(): void {
  for (const fn of listeners) fn();
}

export function setPosOutboxTenant(tenantId: string | null | undefined): void {
  const next = tenantId?.trim() ? tenantId.trim() : "default";
  if (next !== currentTenantId) {
    currentTenantId = next;
    notifyListeners();
  }
}

export function getPosOutboxTenant(): string {
  return currentTenantId;
}

function defaultStorage(): Storage | null {
  try {
    return typeof localStorage !== "undefined" ? localStorage : null;
  } catch {
    return null;
  }
}

export function isNetworkFailure(err: unknown): boolean {
  if (!isOnline()) return true;
  if (err instanceof TypeError) return true;
  if (err instanceof ApiError) {
    if (err.key === "temporary") return true;
    if (
      err.key === "unknown" &&
      /failed to fetch|network|offline|load failed|timeout|connection|econnrefused|502|503|504/i.test(err.message)
    ) {
      return true;
    }
    return false;
  }
  if (err instanceof Error) {
    return /failed to fetch|network|offline|load failed|timeout|connection/i.test(err.message);
  }
  return false;
}

// ---------------------------------------------------------------------------
// Offline POS Snapshot Cache (Catalog, Categories, Customers, Stock Levels)
// ---------------------------------------------------------------------------

function cacheKey(slot: string): string {
  return `${CACHE_PREFIX}:${currentTenantId}:${slot}`;
}

export function savePosCache<T>(slot: string, value: T, storage: Storage | null = defaultStorage()): void {
  if (!storage) return;
  try {
    storage.setItem(cacheKey(slot), JSON.stringify({ savedAt: new Date().toISOString(), value }));
  } catch {
    // Ignore quota errors
  }
}

export function loadPosCache<T>(slot: string, storage: Storage | null = defaultStorage()): T | null {
  if (!storage) return null;
  try {
    const raw = storage.getItem(cacheKey(slot));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { value?: T } | null;
    return parsed && "value" in parsed ? (parsed.value ?? null) : null;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Idempotent Outbox Queue (`sync_push`)
// ---------------------------------------------------------------------------

function outboxKey(): string {
  return `${OUTBOX_PREFIX}:${currentTenantId}`;
}

function parseOutboxRaw(raw: string | null): QueuedPosOp[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    const out: QueuedPosOp[] = [];
    for (const item of parsed) {
      if (!item || typeof item !== "object") continue;
      const r = item as Record<string, unknown>;
      if (typeof r.opId !== "string" || !r.opId) continue;
      if (!isPosOutboxOpKind(r.kind)) continue;
      if (!r.payload || typeof r.payload !== "object") continue;
      out.push({
        opId: r.opId,
        kind: r.kind,
        payload: r.payload as Record<string, unknown>,
        ...(typeof r.locationId === "string" ? { locationId: r.locationId } : {}),
        createdAt: typeof r.createdAt === "string" ? r.createdAt : new Date().toISOString(),
        state: r.state === "failed" ? "failed" : "pending",
        attempts: typeof r.attempts === "number" ? r.attempts : 0,
        ...(typeof r.lastError === "string" ? { lastError: r.lastError } : {}),
      });
    }
    return out;
  } catch {
    return [];
  }
}

export function loadPosOutbox(storage: Storage | null = defaultStorage()): QueuedPosOp[] {
  if (!storage) return [];
  return parseOutboxRaw(storage.getItem(outboxKey()));
}

function savePosOutbox(ops: ReadonlyArray<QueuedPosOp>, storage: Storage | null = defaultStorage()): void {
  if (!storage) return;
  try {
    const key = outboxKey();
    if (ops.length === 0) {
      storage.removeItem(key);
    } else {
      storage.setItem(key, JSON.stringify(ops));
    }
  } catch {
    // Ignore storage write failures
  }
  notifyListeners();
}

export function enqueuePosOp(
  input: {
    opId: string;
    kind: PosOutboxOpKind;
    payload: Record<string, unknown>;
    locationId?: string;
  },
  storage: Storage | null = defaultStorage(),
): QueuedPosOp[] {
  const existing = loadPosOutbox(storage);
  const idx = existing.findIndex((o) => o.opId === input.opId);
  const entry: QueuedPosOp = {
    opId: input.opId,
    kind: input.kind,
    payload: input.payload,
    ...(input.locationId ? { locationId: input.locationId } : {}),
    createdAt: idx >= 0 ? existing[idx]!.createdAt : new Date().toISOString(),
    state: "pending",
    attempts: idx >= 0 ? existing[idx]!.attempts : 0,
  };
  const next = idx >= 0 ? existing.map((o, i) => (i === idx ? entry : o)) : [...existing, entry];
  savePosOutbox(next, storage);
  return next;
}

export function retryFailedPosOps(storage: Storage | null = defaultStorage()): QueuedPosOp[] {
  const existing = loadPosOutbox(storage);
  const next = existing.map((o) =>
    o.state === "failed" ? { ...o, state: "pending" as const, lastError: undefined } : o,
  );
  savePosOutbox(next, storage);
  return next;
}

export function discardPosOp(opId: string, storage: Storage | null = defaultStorage()): QueuedPosOp[] {
  const next = loadPosOutbox(storage).filter((o) => o.opId !== opId);
  savePosOutbox(next, storage);
  return next;
}

/** Extracts optimistic customers queued offline so cashiers can immediately select them for utang/sales. */
export function pendingOptimisticCustomers(
  ops: ReadonlyArray<QueuedPosOp> = loadPosOutbox(),
): Array<{ id: string; name: string; phone: string | null }> {
  const out: Array<{ id: string; name: string; phone: string | null }> = [];
  for (const op of ops) {
    if (op.kind !== "upsert_customer") continue;
    const id = typeof op.payload.id === "string" ? op.payload.id : null;
    const name = typeof op.payload.name === "string" ? op.payload.name : null;
    if (!id || !name) continue;
    out.push({
      id,
      name,
      phone: typeof op.payload.phone === "string" ? op.payload.phone : null,
    });
  }
  return out;
}

/** Subtracts quantities of tracked items in pending offline sales for `locationId` from the cached stock map. */
export function applyOptimisticStockDeltas(
  base: ReadonlyMap<string, number>,
  locationId: string,
  ops: ReadonlyArray<QueuedPosOp> = loadPosOutbox(),
): Map<string, number> {
  const merged = new Map(base);
  for (const op of ops) {
    if (op.kind !== "record_sale" || op.state !== "pending") continue;
    const saleLoc = op.locationId ?? (typeof op.payload.location_id === "string" ? op.payload.location_id : undefined);
    if (saleLoc !== locationId) continue;
    const lines = Array.isArray(op.payload.lines) ? op.payload.lines : [];
    for (const rawLine of lines) {
      if (!rawLine || typeof rawLine !== "object") continue;
      const line = rawLine as Record<string, unknown>;
      if (line.tracked === false) continue;
      const vid = typeof line.variant_id === "string" ? line.variant_id : null;
      const qty = typeof line.qty === "number" ? line.qty : Number(line.qty);
      if (!vid || !Number.isFinite(qty) || qty <= 0) continue;
      if (merged.has(vid)) {
        merged.set(vid, Number(((merged.get(vid) ?? 0) - qty).toFixed(3)));
      }
    }
  }
  return merged;
}

export interface OptimisticLedgerEntry {
  id: string;
  customer_id: string;
  kind: "charge" | "payment";
  amount: number;
  sale_id: string | null;
  note: string | null;
  occurred_at: string;
  method: "cash" | "ewallet";
  location_id: string | null;
  pending: true;
}

/** Extracts optimistic customer ledger entries (utang charges from offline sales + offline utang repayments). */
export function pendingOptimisticUtangLedger(
  ops: ReadonlyArray<QueuedPosOp> = loadPosOutbox(),
): OptimisticLedgerEntry[] {
  const out: OptimisticLedgerEntry[] = [];
  for (const op of ops) {
    if (op.state !== "pending" && op.state !== "failed") continue;
    if (op.kind === "record_utang_payment") {
      const customerId = typeof op.payload.customer_id === "string" ? op.payload.customer_id : null;
      const amt = Number(op.payload.amount);
      if (!customerId || !Number.isFinite(amt) || amt <= 0) continue;
      out.push({
        id: op.opId,
        customer_id: customerId,
        kind: "payment",
        amount: -amt,
        sale_id: null,
        note: typeof op.payload.note === "string" ? op.payload.note : null,
        occurred_at: typeof op.payload.occurred_at === "string" ? op.payload.occurred_at : op.createdAt,
        method: op.payload.method === "ewallet" ? "ewallet" : "cash",
        location_id: typeof op.payload.location_id === "string" ? op.payload.location_id : (op.locationId ?? null),
        pending: true,
      });
    } else if (op.kind === "record_sale") {
      const customerId = typeof op.payload.customer_id === "string" ? op.payload.customer_id : null;
      if (!customerId) continue;
      const payments = Array.isArray(op.payload.payments) ? op.payload.payments : [];
      let utangSum = 0;
      for (const rawPay of payments) {
        if (!rawPay || typeof rawPay !== "object") continue;
        const p = rawPay as Record<string, unknown>;
        if (p.method === "utang") {
          const a = Number(p.amount);
          if (Number.isFinite(a) && a > 0) utangSum += a;
        }
      }
      if (utangSum <= 0) continue;
      out.push({
        id: `${op.opId}:utang`,
        customer_id: customerId,
        kind: "charge",
        amount: utangSum,
        sale_id: typeof op.payload.id === "string" ? op.payload.id : null,
        note: typeof op.payload.local_no === "string" ? op.payload.local_no : null,
        occurred_at: typeof op.payload.sold_at === "string" ? op.payload.sold_at : op.createdAt,
        method: "cash",
        location_id: typeof op.payload.location_id === "string" ? op.payload.location_id : (op.locationId ?? null),
        pending: true,
      });
    }
  }
  return out;
}

export interface OptimisticExpenseItem {
  id: string;
  location_id: string;
  amount: number;
  currency: string;
  category: string;
  note: string | null;
  paid_from: "cash" | "ewallet";
  wallet: string | null;
  spent_at: string;
  voided_at: null;
  void_reason: null;
  created_by: null;
  pending: true;
}

/** Extracts optimistic expenses queued offline for `locationId`. */
export function pendingOptimisticExpenses(
  locationId: string,
  currency = "PHP",
  ops: ReadonlyArray<QueuedPosOp> = loadPosOutbox(),
): OptimisticExpenseItem[] {
  const out: OptimisticExpenseItem[] = [];
  for (const op of ops) {
    if (op.kind !== "record_expense") continue;
    const loc = typeof op.payload.location_id === "string" ? op.payload.location_id : op.locationId;
    if (loc !== locationId) continue;
    const id = typeof op.payload.id === "string" ? op.payload.id : op.opId;
    const amount = Number(op.payload.amount);
    if (!Number.isFinite(amount) || amount <= 0) continue;
    out.push({
      id,
      location_id: locationId,
      amount,
      currency,
      category: typeof op.payload.category === "string" ? op.payload.category : "other",
      note: typeof op.payload.note === "string" ? op.payload.note : null,
      paid_from: op.payload.paid_from === "ewallet" ? "ewallet" : "cash",
      wallet: typeof op.payload.wallet === "string" ? op.payload.wallet : null,
      spent_at: typeof op.payload.spent_at === "string" ? op.payload.spent_at : op.createdAt,
      voided_at: null,
      void_reason: null,
      created_by: null,
      pending: true,
    });
  }
  return out.sort((a, b) => b.spent_at.localeCompare(a.spent_at));
}

export interface OptimisticServiceTxnItem {
  id: string;
  location_id: string;
  kind: string;
  wallet: string;
  amount: number;
  fee: number;
  price: number | null;
  currency: string;
  ref: string | null;
  note: string | null;
  txn_at: string;
  voided_at: null;
  void_reason: null;
  created_by: null;
  pending: true;
}

/** Extracts optimistic load/e-wallet service entries queued offline for `locationId`. */
export function pendingOptimisticServiceTxns(
  locationId: string,
  currency = "PHP",
  ops: ReadonlyArray<QueuedPosOp> = loadPosOutbox(),
): OptimisticServiceTxnItem[] {
  const out: OptimisticServiceTxnItem[] = [];
  for (const op of ops) {
    if (op.kind !== "record_service_txn") continue;
    const loc = typeof op.payload.location_id === "string" ? op.payload.location_id : op.locationId;
    if (loc !== locationId) continue;
    const id = typeof op.payload.id === "string" ? op.payload.id : op.opId;
    const kind = typeof op.payload.kind === "string" ? op.payload.kind : "cash_in";
    const wallet = typeof op.payload.wallet === "string" ? op.payload.wallet : "gcash";
    const amount = Number(op.payload.amount);
    if (!Number.isFinite(amount) || amount === 0) continue;
    const price = op.payload.price !== undefined ? Number(op.payload.price) : null;
    const rawFee = op.payload.fee !== undefined ? Number(op.payload.fee) : 0;
    const fee = kind === "load" && price !== null ? Math.max(0, price - amount) : Math.max(0, rawFee);
    out.push({
      id,
      location_id: locationId,
      kind,
      wallet,
      amount,
      fee,
      price,
      currency,
      ref: typeof op.payload.ref === "string" ? op.payload.ref : null,
      note: typeof op.payload.note === "string" ? op.payload.note : null,
      txn_at: typeof op.payload.txn_at === "string" ? op.payload.txn_at : op.createdAt,
      voided_at: null,
      void_reason: null,
      created_by: null,
      pending: true,
    });
  }
  return out.sort((a, b) => b.txn_at.localeCompare(a.txn_at));
}

/** Extracts a concise summary (receipt #, customer name, or minor-unit amount) for Outbox Inspector display. */
export function describeQueuedPosOp(op: QueuedPosOp): {
  primaryRef: string | null;
  amountMinor: number | null;
} {
  const p = op.payload;
  switch (op.kind) {
    case "record_sale": {
      const localNo = typeof p.local_no === "string" ? p.local_no : null;
      const payments = Array.isArray(p.payments) ? p.payments : [];
      let sum = 0;
      for (const item of payments) {
        if (item && typeof item === "object") {
          const amt = Number((item as Record<string, unknown>).amount);
          if (Number.isFinite(amt) && amt > 0) sum += amt;
        }
      }
      return { primaryRef: localNo, amountMinor: sum > 0 ? sum : null };
    }
    case "upsert_customer":
      return {
        primaryRef: typeof p.name === "string" ? p.name : null,
        amountMinor: null,
      };
    case "record_utang_payment":
      return {
        primaryRef: typeof p.method === "string" ? p.method : null,
        amountMinor: Number.isFinite(Number(p.amount)) ? Number(p.amount) : null,
      };
    case "record_expense":
      return {
        primaryRef: typeof p.category === "string" ? p.category : null,
        amountMinor: Number.isFinite(Number(p.amount)) ? Number(p.amount) : null,
      };
    case "record_service_txn":
      return {
        primaryRef:
          typeof p.wallet === "string" ? p.wallet.toUpperCase() : null,
        amountMinor: Number.isFinite(Number(p.amount)) ? Number(p.amount) : null,
      };
    case "open_shift":
      return {
        primaryRef: null,
        amountMinor: Number.isFinite(Number(p.opening_cash)) ? Number(p.opening_cash) : 0,
      };
  }
}

let inFlightFlush: Promise<{ synced: number; remaining: number; failed: number }> | null = null;

async function defaultPushBatch(
  pOps: Array<{ op_id: string; kind: string; payload: Record<string, unknown> }>,
): Promise<SyncPushItemResult[]> {
  return rpc<SyncPushItemResult[]>("sync_push", { p_ops: pOps });
}

/** Flushes pending POS outbox ops in FIFO order using idempotent `sync_push` batches. */
export async function flushPosOutbox(options?: {
  pushBatch?: (
    ops: Array<{ op_id: string; kind: string; payload: Record<string, unknown> }>,
  ) => Promise<SyncPushItemResult[]>;
  storage?: Storage | null;
}): Promise<{ synced: number; remaining: number; failed: number }> {
  const storage = options?.storage === undefined ? defaultStorage() : options.storage;
  const pushBatch = options?.pushBatch ?? defaultPushBatch;

  if (!options?.pushBatch && inFlightFlush) {
    return inFlightFlush;
  }

  const run = async (): Promise<{ synced: number; remaining: number; failed: number }> => {
    let synced = 0;
    while (true) {
      const all = loadPosOutbox(storage);
      const pending = all.filter((o) => o.state === "pending");
      if (pending.length === 0) {
        return {
          synced,
          remaining: 0,
          failed: all.filter((o) => o.state === "failed").length,
        };
      }

      const batch = pending.slice(0, MAX_BATCH);
      let results: SyncPushItemResult[];
      try {
        results = await pushBatch(
          batch.map((o) => ({
            op_id: o.opId,
            kind: o.kind,
            payload: o.payload,
          })),
        );
      } catch {
        // Network/server unreachable: leave pending ops intact for next reconnect
        const bumped = all.map((o) =>
          batch.some((b) => b.opId === o.opId) ? { ...o, attempts: o.attempts + 1 } : o,
        );
        savePosOutbox(bumped, storage);
        return {
          synced,
          remaining: bumped.filter((o) => o.state === "pending").length,
          failed: bumped.filter((o) => o.state === "failed").length,
        };
      }

      const resultByOpId = new Map(results.map((r) => [r.op_id, r]));
      const next: QueuedPosOp[] = [];
      let sawTransientError = false;

      for (const item of all) {
        const res = resultByOpId.get(item.opId);
        if (!res) {
          next.push(item);
          continue;
        }
        if (res.status === "ok" || res.hint === "duplicate") {
          synced++;
          continue;
        }
        if (res.status === "rejected") {
          next.push({
            ...item,
            state: "failed",
            attempts: item.attempts + 1,
            lastError: res.hint ?? res.code ?? "rejected",
          });
          continue;
        }
        sawTransientError = true;
        next.push({
          ...item,
          attempts: item.attempts + 1,
          lastError: res.code ?? "temporary",
        });
      }

      savePosOutbox(next, storage);
      if (sawTransientError) {
        return {
          synced,
          remaining: next.filter((o) => o.state === "pending").length,
          failed: next.filter((o) => o.state === "failed").length,
        };
      }
    }
  };

  if (options?.pushBatch) {
    return run();
  }
  inFlightFlush = run().finally(() => {
    inFlightFlush = null;
  });
  return inFlightFlush;
}

// ---------------------------------------------------------------------------
// React External Store Subscription (referentially stable snapshot)
// ---------------------------------------------------------------------------

const EMPTY_OUTBOX: ReadonlyArray<QueuedPosOp> = [];
let snapshotMemo: { key: string; raw: string | null; items: ReadonlyArray<QueuedPosOp> } = {
  key: "",
  raw: null,
  items: EMPTY_OUTBOX,
};

function subscribeOutbox(cb: () => void): () => void {
  listeners.add(cb);
  const onStorage = (e: StorageEvent) => {
    if (!e.key || e.key.startsWith(OUTBOX_PREFIX)) cb();
  };
  if (typeof window !== "undefined") {
    window.addEventListener("storage", onStorage);
  }
  return () => {
    listeners.delete(cb);
    if (typeof window !== "undefined") {
      window.removeEventListener("storage", onStorage);
    }
  };
}

function getOutboxSnapshot(): ReadonlyArray<QueuedPosOp> {
  const s = defaultStorage();
  const key = outboxKey();
  const raw = s ? s.getItem(key) : null;
  if (snapshotMemo.key === key && snapshotMemo.raw === raw) {
    return snapshotMemo.items;
  }
  const parsed = raw ? parseOutboxRaw(raw) : EMPTY_OUTBOX;
  snapshotMemo = {
    key,
    raw,
    items: parsed.length === 0 ? EMPTY_OUTBOX : parsed,
  };
  return snapshotMemo.items;
}

export function usePosOutboxSnapshot(): ReadonlyArray<QueuedPosOp> {
  return useSyncExternalStore(subscribeOutbox, getOutboxSnapshot, () => EMPTY_OUTBOX);
}
