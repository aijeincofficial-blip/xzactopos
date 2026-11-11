// create_user: add a user who signs in with tenant slug + username (synthetic email, no inbox needed).
//
// Who may call (re-checked authoritatively in admin_register_user):
//   superadmin: any role, any location
//   admin (manager): cashiers only, placed in a store they manage
//
// POST { username, password, role, full_name?, locale?, location_id?, position? }
// 201  { user_id, username, email }
import { fail, fromDbError, json, preflight } from "../_shared/http.ts";
import { getCallerId, getCallerProfile, serviceClient } from "../_shared/clients.ts";
import { parseCreateUser, syntheticEmail } from "../_shared/validate.ts";

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  const svc = serviceClient();
  const callerId = await getCallerId(req, svc);
  if (!callerId) return fail(401, "unauthenticated", "sign in first", {}, req);

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail(400, "invalid_json", "body must be JSON", {}, req);
  }
  const parsed = parseCreateUser(body);
  if (!parsed.ok) return fail(400, "invalid_argument", parsed.error, { field: parsed.field }, req);
  const input = parsed.value;

  const caller = await getCallerProfile(svc, callerId);
  if (!caller || !caller.active) return fail(403, "forbidden", "not an active user", { hint: "no_account" }, req);
  if (caller.tenants.status !== "active") {
    return fail(403, "forbidden", `tenant is ${caller.tenants.status}`, { hint: `tenant_${caller.tenants.status}` }, req);
  }
  // Fast refusal before touching auth.users; the SQL function is still the real gate.
  if (caller.role !== "superadmin" && !(caller.role === "admin" && input.role === "cashier")) {
    return fail(403, "forbidden", "not allowed to create this user", { hint: "create_denied" }, req);
  }

  const email = syntheticEmail(input.username, caller.tenants.slug);
  const { data: created, error: createErr } = await svc.auth.admin.createUser({
    email,
    password: input.password,
    email_confirm: true,
    user_metadata: { username: input.username, full_name: input.fullName },
    app_metadata: { tenant_id: caller.tenant_id },
  });
  if (createErr || !created.user) {
    const exists = createErr?.message?.toLowerCase().includes("already") ?? false;
    if (exists) return fail(409, "conflict", "username already taken", { hint: "duplicate" }, req);
    console.error("createUser failed", createErr);
    return fail(500, "internal", "could not create the account", {}, req);
  }

  const { error: rpcErr } = await svc.rpc("admin_register_user", {
    p_caller: callerId,
    p_user: created.user.id,
    p_username: input.username,
    p_full_name: input.fullName,
    p_role: input.role,
    p_locale: input.locale,
    p_location: input.locationId,
    p_position: input.position,
  });
  if (rpcErr) {
    // roll back the auth user so a refused request leaves nothing behind
    const { error: delErr } = await svc.auth.admin.deleteUser(created.user.id);
    if (delErr) console.error("rollback deleteUser failed", delErr);
    return fromDbError(rpcErr, req);
  }

  return json(201, { user_id: created.user.id, username: input.username, email }, req);
});
