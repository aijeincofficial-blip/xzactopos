// HTTP helpers for Edge Functions: JSON responses, CORS, and Postgres error mapping.

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Error body the client maps to an i18n message by `code` (and `hint` for business rules). */
export function fail(status: number, code: string, message: string, extra: Record<string, unknown> = {}): Response {
  return json(status, { error: { code, message, ...extra } });
}

interface DbError {
  code?: string;
  message: string;
  hint?: string | null;
}

/** Map a Postgres / PostgREST error raised by an RPC to an HTTP response. */
export function fromDbError(err: DbError): Response {
  const hint = err.hint ?? undefined;
  switch (err.code) {
    case "42501":
      return fail(403, "forbidden", err.message, { hint });
    case "22023":
      return fail(400, "invalid_argument", err.message, { hint });
    case "23505":
      return fail(409, "conflict", "already exists", { hint: hint ?? "duplicate" });
    case "23514":
    case "P0001":
      return fail(422, "rule_violation", err.message, { hint });
    default:
      console.error("unexpected database error", err);
      return fail(500, "internal", "unexpected error");
  }
}

export function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "use POST");
  return null;
}
