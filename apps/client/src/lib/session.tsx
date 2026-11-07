import { createContext, useContext, type ReactNode } from "react";
import { queryOptions, useSuspenseQuery, type QueryClient } from "@tanstack/react-query";
import { can, check, contextFromAccess, type AccessContext, type Decision, type PermissionKey } from "@pos/core";
import { getMyAccess, type MyAccess } from "./api.ts";
import { supabase } from "./supabase.ts";

export const accessQuery = queryOptions({
  queryKey: ["access"],
  queryFn: getMyAccess,
  staleTime: 60_000,
});

export async function hasSession(): Promise<boolean> {
  const { data } = await supabase.auth.getSession();
  return data.session !== null;
}

/** Returns the access payload, or null when signed out or the account is not usable. */
export async function loadAccess(qc: QueryClient): Promise<MyAccess | null> {
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
