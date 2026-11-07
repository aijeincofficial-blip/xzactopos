// Supabase clients for Edge Functions. The service role key exists only here (server side).
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing env ${name}`);
  return v;
}

export function serviceClient(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function bearer(req: Request): string | null {
  const h = req.headers.get("Authorization") ?? "";
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m ? m[1]!.trim() : null;
}

/** True when the request carries the service role key itself (platform operator scripts, CI). */
export function isServiceRoleRequest(req: Request): boolean {
  const token = bearer(req);
  return token !== null && token === Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
}

/** Verify the caller's access token with GoTrue and return their user id. */
export async function getCallerId(req: Request, svc: SupabaseClient): Promise<string | null> {
  const token = bearer(req);
  if (!token) return null;
  const { data, error } = await svc.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user.id;
}

export interface CallerProfile {
  tenant_id: string;
  role: string;
  active: boolean;
  tenants: { slug: string; status: string };
}

export async function getCallerProfile(svc: SupabaseClient, userId: string): Promise<CallerProfile | null> {
  const { data, error } = await svc
    .from("profiles")
    .select("tenant_id, role, active, tenants!inner(slug, status)")
    .eq("user_id", userId)
    .is("deleted_at", null)
    .maybeSingle();
  if (error) throw error;
  return data as CallerProfile | null;
}
