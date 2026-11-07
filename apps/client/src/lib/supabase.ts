import { createClient } from "@supabase/supabase-js";

// Anon key only. The service role key must never appear in client code.
const url: string | undefined = import.meta.env.VITE_SUPABASE_URL;
const anonKey: string | undefined = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const isSupabaseConfigured = Boolean(url && anonKey);

export const supabase = createClient(url ?? "http://127.0.0.1:54321", anonKey ?? "missing", {
  auth: { persistSession: true, autoRefreshToken: true },
  realtime: { params: { eventsPerSecond: 0 } }, // no Realtime on POS screens (see CLAUDE.md)
});

export type ConnectionState = "unconfigured" | "connected" | "unreachable";

/** One cheap GET against the auth health endpoint. No polling here; callers decide when to retry. */
export async function checkConnection(signal?: AbortSignal): Promise<ConnectionState> {
  if (!url || !anonKey) return "unconfigured";
  try {
    const res = await fetch(`${url}/auth/v1/health`, { headers: { apikey: anonKey }, signal });
    return res.ok ? "connected" : "unreachable";
  } catch {
    return "unreachable";
  }
}
