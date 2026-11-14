import { createContext, useContext, type ReactNode } from "react";
import { queryOptions, useSuspenseQuery, type QueryClient } from "@tanstack/react-query";
import { can, check, contextFromAccess, type AccessContext, type Decision, type PermissionKey } from "@pos/core";
import type { MyAccess } from "./api.ts";
import { ACCESS_CACHE_PREFIX, ApiError, isNetworkFailure } from "./errors.ts";
import { hasStoredSessionHint } from "./session-hint.ts";

function defaultStorage(): Storage | null {
  try {
    return typeof localStorage !== "undefined" ? localStorage : null;
  } catch {
    return null;
  }
}

export function accessCacheKey(userId: string): string {
  return `${ACCESS_CACHE_PREFIX}${userId}`;
}

export function readCachedAccess(
  userId: string,
  storage: Storage | null = defaultStorage(),
): MyAccess | null {
  if (!storage || !userId) return null;
  try {
    const raw = storage.getItem(accessCacheKey(userId));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object") return null;
    const rec = parsed as Partial<MyAccess>;
    if (rec.user_id !== userId || !rec.tenant || !rec.modules || !Array.isArray(rec.locations)) {
      return null;
    }
    return rec as MyAccess;
  } catch {
    return null;
  }
}

export function writeCachedAccess(
  access: MyAccess,
  storage: Storage | null = defaultStorage(),
): void {
  if (!storage || !access.user_id) return;
  try {
    storage.setItem(accessCacheKey(access.user_id), JSON.stringify(access));
  } catch {
    // ignore storage quota errors
  }
}

export function clearCachedAccess(
  userId: string,
  storage: Storage | null = defaultStorage(),
): void {
  if (!storage || !userId) return;
  try {
    storage.removeItem(accessCacheKey(userId));
  } catch {
    // ignore storage failures
  }
}

/**
 * Fetches fresh access permissions from the server and persists them for offline reloads.
 * Falls back to the cached `MyAccess` ONLY on network/offline errors; explicit server
 * refusals (deactivated / no_account / forbidden) purge the cache and rethrow.
 */
export async function fetchAccessWithOfflineFallback(opts: {
  userId?: string | null;
  fetchAccess: () => Promise<MyAccess>;
  storage?: Storage | null;
}): Promise<MyAccess> {
  const storage = opts.storage === undefined ? defaultStorage() : opts.storage;
  try {
    const access = await opts.fetchAccess();
    writeCachedAccess(access, storage);
    return access;
  } catch (err) {
    if (isNetworkFailure(err)) {
      if (opts.userId) {
        const cached = readCachedAccess(opts.userId, storage);
        if (cached) return cached;
      }
      throw err;
    }
    if (
      opts.userId &&
      err instanceof ApiError &&
      (err.key === "no_account" || err.key === "deactivated" || err.key === "forbidden")
    ) {
      clearCachedAccess(opts.userId, storage);
    }
    throw err;
  }
}

export const accessQuery = queryOptions({
  queryKey: ["access"],
  networkMode: "offlineFirst",
  queryFn: async () => {
    const [{ supabase }, { getMyAccess }] = await Promise.all([
      import("./supabase.ts"),
      import("./api.ts"),
    ]);
    const { data } = await supabase.auth.getSession();
    return fetchAccessWithOfflineFallback({
      userId: data.session?.user?.id ?? null,
      fetchAccess: getMyAccess,
    });
  },
  staleTime: 60_000,
});

export async function hasSession(): Promise<boolean> {
  if (!hasStoredSessionHint()) return false;
  const { supabase } = await import("./supabase.ts");
  const { data } = await supabase.auth.getSession();
  return data.session !== null;
}

/** Returns the access payload, or null when signed out or the account is not usable. */
export async function loadAccess(qc: QueryClient): Promise<MyAccess | null> {
  if (!hasStoredSessionHint()) return null;
  const cached = qc.getQueryData(accessQuery.queryKey);
  if (cached) {
    const state = qc.getQueryState(accessQuery.queryKey);
    const stale = !state || Date.now() - state.dataUpdatedAt > 60_000;
    if (stale) {
      // Stale-while-revalidate on sibling navigation so >60s sessions never block clicks under /app/*.
      void qc.fetchQuery(accessQuery).catch(() => {});
    }
    return cached;
  }
  if (!(await hasSession())) return null;
  try {
    return await qc.fetchQuery(accessQuery);
  } catch {
    return null;
  }
}

export interface Session {
  access: MyAccess;
  ctx: AccessContext;
  can: (key: PermissionKey, locationId?: string) => boolean;
  check: (key: PermissionKey, locationId?: string) => Decision;
}

const SessionContext = createContext<Session | null>(null);

export function SessionProvider({ children }: { children: ReactNode }) {
  const { data } = useSuspenseQuery(accessQuery);
  const ctx = contextFromAccess(data);
  const value: Session = {
    access: data,
    ctx,
    can: (key, loc) => can(ctx, key, loc),
    check: (key, loc) => check(ctx, key, loc),
  };
  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession(): Session {
  const s = useContext(SessionContext);
  if (!s) throw new Error("useSession outside SessionProvider");
  return s;
}

const SLUG_KEY = "pos.lastSlug";

export function rememberSlug(slug: string) {
  try {
    localStorage.setItem(SLUG_KEY, slug);
  } catch {
    /* storage can be blocked; the slug is only a convenience */
  }
}

export function lastSlug(): string | null {
  try {
    return localStorage.getItem(SLUG_KEY);
  } catch {
    return null;
  }
}
