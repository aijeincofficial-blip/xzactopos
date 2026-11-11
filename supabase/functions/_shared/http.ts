// HTTP helpers for Edge Functions: JSON responses, CORS origin allowlist, and Postgres error mapping.

interface GlobalEnv {
  Deno?: { env?: { get(key: string): string | undefined } };
  process?: { env?: Record<string, string | undefined> };
}

function readEnv(key: string): string | undefined {
  const g = globalThis as unknown as GlobalEnv;
  return g.Deno?.env?.get(key) ?? g.process?.env?.[key];
}

/** Parse comma-separated ALLOWED_ORIGINS. Empty or '*' means unrestricted (local dev / native clients). */
export function parseAllowedOrigins(raw = readEnv("ALLOWED_ORIGINS")): string[] | null {
  if (!raw) return null;
  const list = raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  if (list.length === 0 || list.includes("*")) return null;
  return list;
}

export function isOriginAllowed(req: Request, rawAllowed?: string): boolean {
  const allowed = parseAllowedOrigins(rawAllowed);
  if (!allowed) return true;
  const origin = req.headers.get("Origin");
  // Native mobile / server-to-server requests omit Origin; browser requests carry Origin.
  if (!origin) return true;
  return allowed.includes(origin);
}

export function corsHeadersFor(req?: Request, rawAllowed?: string): Record<string, string> {
  const base: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  const allowed = parseAllowedOrigins(rawAllowed);
  if (!allowed) {
    return { ...base, "Access-Control-Allow-Origin": "*" };
  }
  const origin = req?.headers.get("Origin") ?? null;
  const matched = origin && allowed.includes(origin) ? origin : allowed[0]!;
  return { ...base, "Access-Control-Allow-Origin": matched, Vary: "Origin" };
}

export const corsHeaders: Record<string, string> = corsHeadersFor();

export function json(status: number, body: unknown, req?: Request): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeadersFor(req), "Content-Type": "application/json" },
  });
}

/** Error body the client maps to an i18n message by `code` (and `hint` for business rules). */
export function fail(
  status: number,
  code: string,
  message: string,
  extra: Record<string, unknown> = {},
  req?: Request,
): Response {
  return json(status, { error: { code, message, ...extra } }, req);
}

interface DbError {
  code?: string;
  message: string;
  hint?: string | null;
}

/** Map a Postgres / PostgREST error raised by an RPC to an HTTP response. */
export function fromDbError(err: DbError, req?: Request): Response {
  const hint = err.hint ?? undefined;
  switch (err.code) {
    case "42501":
      return fail(403, "forbidden", err.message, { hint }, req);
    case "22023":
      return fail(400, "invalid_argument", err.message, { hint }, req);
    case "23505":
      return fail(409, "conflict", "already exists", { hint: hint ?? "duplicate" }, req);
    case "23514":
    case "P0001":
      return fail(422, "rule_violation", err.message, { hint }, req);
    default:
      console.error("unexpected database error", err);
      return fail(500, "internal", "unexpected error", {}, req);
  }
}

export function preflight(req: Request, rawAllowed?: string): Response | null {
  if (!isOriginAllowed(req, rawAllowed)) {
    return new Response(JSON.stringify({ error: { code: "forbidden", message: "origin not allowed" } }), {
      status: 403,
      headers: { ...corsHeadersFor(req, rawAllowed), "Content-Type": "application/json" },
    });
  }
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeadersFor(req, rawAllowed) });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "use POST", {}, req);
  return null;
}
