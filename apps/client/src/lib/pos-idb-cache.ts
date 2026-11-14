import { getPosOutboxTenant } from "./pos-outbox.ts";

const DB_NAME = "xzactopos-pos-cache";
const DB_VERSION = 1;
const STORE_NAME = "kv";
const FAST_KEY_PREFIX = "xzactopos:pos-cache:fast:";
const FAST_JSON_LIMIT = 250_000;
const IDB_SENTINEL = "__idb__";

interface StoredEntry<T> {
  savedAt: string;
  value: T;
}

function safeLocalStorage(): Storage | null {
  try {
    return typeof localStorage !== "undefined" ? localStorage : null;
  } catch {
    return null;
  }
}

function fastKey(scoped: string): string {
  return `${FAST_KEY_PREFIX}${scoped}`;
}

const memoryCache = new Map<string, unknown>();
const pendingWrites = new Map<string, { value: unknown; timer: ReturnType<typeof setTimeout> }>();
const IDB_WRITE_DEBOUNCE_MS = 3000;
let dbPromise: Promise<IDBDatabase | null> | null = null;
let flushListenerAttached = false;

function writeEntryToIdb(key: string, value: unknown): void {
  void openCacheDb().then((db) => {
    if (!db) return;
    try {
      const tx = db.transaction(STORE_NAME, "readwrite");
      const payload: StoredEntry<unknown> = { savedAt: new Date().toISOString(), value };
      tx.objectStore(STORE_NAME).put(payload, key);
    } catch {
      // Ignore background IDB quota/close errors; memoryCache still holds latest snapshot.
    }
  });
}

function flushAllPendingWrites(): void {
  if (pendingWrites.size === 0) return;
  const entries = [...pendingWrites.entries()];
  for (const [key, pending] of entries) {
    clearTimeout(pending.timer);
    pendingWrites.delete(key);
    writeEntryToIdb(key, pending.value);
  }
}

function ensureFlushListener(): void {
  if (flushListenerAttached || typeof window === "undefined") return;
  flushListenerAttached = true;
  window.addEventListener("pagehide", flushAllPendingWrites);
}

function scopedKey(slot: string): string {
  return `${getPosOutboxTenant()}:${slot}`;
}

function openCacheDb(): Promise<IDBDatabase | null> {
  if (typeof indexedDB === "undefined") return Promise.resolve(null);
  if (dbPromise) return dbPromise;
  dbPromise = new Promise<IDBDatabase | null>((resolve) => {
    try {
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME);
        }
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => {
        dbPromise = null;
        resolve(null);
      };
    } catch {
      dbPromise = null;
      resolve(null);
    }
  });
  return dbPromise;
}

export async function loadPosIdbCache<T>(slot: string): Promise<T | null> {
  const key = scopedKey(slot);
  if (memoryCache.has(key)) {
    return memoryCache.get(key) as T;
  }
  const storage = safeLocalStorage();
  if (storage) {
    try {
      const raw = storage.getItem(fastKey(key));
      if (!raw) return null;
      if (raw !== IDB_SENTINEL) {
        const parsed = JSON.parse(raw) as StoredEntry<T>;
        if (!parsed || typeof parsed !== "object" || !("value" in parsed)) return null;
        memoryCache.set(key, parsed.value);
        return parsed.value;
      }
    } catch {
      // Fall through to IDB when fast localStorage lookup fails.
    }
  }
  const db = await openCacheDb();
  if (!db) return null;
  return await new Promise<T | null>((resolve) => {
    try {
      const tx = db.transaction(STORE_NAME, "readonly");
      const req = tx.objectStore(STORE_NAME).get(key);
      req.onsuccess = () => {
        const entry = req.result as StoredEntry<T> | undefined;
        if (!entry || typeof entry !== "object" || !("value" in entry)) {
          resolve(null);
          return;
        }
        memoryCache.set(key, entry.value);
        resolve(entry.value);
      };
      req.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

export async function savePosIdbCache<T>(slot: string, value: T): Promise<void> {
  const key = scopedKey(slot);
  memoryCache.set(key, value);
  const existing = pendingWrites.get(key);
  if (existing) {
    clearTimeout(existing.timer);
    pendingWrites.delete(key);
  }
  const storage = safeLocalStorage();
  if (storage) {
    try {
      const serialized = JSON.stringify({ savedAt: new Date().toISOString(), value });
      if (serialized.length <= FAST_JSON_LIMIT) {
        storage.setItem(fastKey(key), serialized);
        return;
      }
      storage.setItem(fastKey(key), IDB_SENTINEL);
    } catch {
      try {
        storage.setItem(fastKey(key), IDB_SENTINEL);
      } catch {
        // Ignore storage write failure; fall back to deferred IDB persistence.
      }
    }
  }
  ensureFlushListener();
  const timer = setTimeout(() => {
    const entry = pendingWrites.get(key);
    if (!entry) return;
    pendingWrites.delete(key);
    writeEntryToIdb(key, entry.value);
  }, IDB_WRITE_DEBOUNCE_MS);
  pendingWrites.set(key, { value, timer });
}

export async function clearAllPosIdbCache(): Promise<void> {
  for (const pending of pendingWrites.values()) {
    clearTimeout(pending.timer);
  }
  pendingWrites.clear();
  memoryCache.clear();
  const storage = safeLocalStorage();
  if (storage) {
    try {
      for (let i = storage.length - 1; i >= 0; i--) {
        const k = storage.key(i);
        if (k?.startsWith(FAST_KEY_PREFIX)) storage.removeItem(k);
      }
    } catch {
      // ignore
    }
  }
  const db = await openCacheDb();
  if (!db) return;
  await new Promise<void>((resolve) => {
    try {
      const tx = db.transaction(STORE_NAME, "readwrite");
      tx.objectStore(STORE_NAME).clear();
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
      tx.onabort = () => resolve();
    } catch {
      resolve();
    }
  });
}
