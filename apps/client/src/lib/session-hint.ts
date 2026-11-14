/**
 * Zero-dependency check for a persisted Supabase auth token in localStorage.
 * Prevents public routes (`/`, `/login`, `/signup`) from loading `@supabase/supabase-js`
 * until the user actually has a stored session or signs in.
 */
export function hasStoredSessionHint(): boolean {
  try {
    if (typeof localStorage === "undefined") return false;
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (!k || !k.startsWith("sb-") || !k.endsWith("-auth-token")) continue;
      const raw = localStorage.getItem(k);
      if (!raw) continue;
      const parsed = JSON.parse(raw) as { access_token?: unknown } | null;
      if (parsed && typeof parsed.access_token === "string" && parsed.access_token.length > 0) {
        return true;
      }
    }
    return false;
  } catch {
    return false;
  }
}
