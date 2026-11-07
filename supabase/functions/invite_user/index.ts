// invite_user: invite someone with a real email address. They set their password from the email link.
//
// Two flows:
//   1. Superadmin invites a superadmin, admin or warehouse user into their tenant.
//      POST { email, username, role, full_name?, locale?, location_id?, position?, redirect_to? }
//   2. Platform operator (service role key, or a user in platform_admins) creates a new tenant and
//      invites its first superadmin in one call.
//      POST { email, username, full_name?, provision: { name, slug, base_currency, preset?, timezone? } }
//
// 201 { user_id, email, tenant_id? }
import { fail, fromDbError, json, preflight } from "../_shared/http.ts";
import { getCallerId, getCallerProfile, isServiceRoleRequest, serviceClient } from "../_shared/clients.ts";
import { parseInviteUser } from "../_shared/validate.ts";

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  const svc = serviceClient();
  const asService = isServiceRoleRequest(req);
  const callerId = asService ? null : await getCallerId(req, svc);
  if (!asService && !callerId) return fail(401, "unauthenticated", "sign in first");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail(400, "invalid_json", "body must be JSON");
  }
  const parsed = parseInviteUser(body);
  if (!parsed.ok) return fail(400, "invalid_argument", parsed.error, { field: parsed.field });
  const input = parsed.value;

  if (input.provision) {
    if (!asService) {
      const { data: op } = await svc.from("platform_admins").select("user_id").eq("user_id", callerId!).maybeSingle();
      if (!op) return fail(403, "forbidden", "platform operator only", { hint: "platform_only" });
    }
  } else {
    if (asService || !callerId) return fail(400, "invalid_argument", "service role may only provision tenants");
    const caller = await getCallerProfile(svc, callerId);
    if (!caller || !caller.active || caller.role !== "superadmin") {
      return fail(403, "forbidden", "superadmin only", { hint: "superadmin_only" });
    }
    if (caller.tenants.status !== "active") {
      return fail(403, "forbidden", `tenant is ${caller.tenants.status}`, { hint: `tenant_${caller.tenants.status}` });
    }
    if (input.role === "cashier") {
      return fail(400, "invalid_argument", "cashiers are created with create_user", { field: "role" });
    }
  }

  const { data: invited, error: inviteErr } = await svc.auth.admin.inviteUserByEmail(input.email, {
    data: { username: input.username, full_name: input.fullName },
    redirectTo: input.redirectTo ?? undefined,
  });
  if (inviteErr || !invited.user) {
    const exists = inviteErr?.message?.toLowerCase().includes("already") ?? false;
    if (exists) return fail(409, "conflict", "email already registered", { hint: "duplicate" });
    console.error("inviteUserByEmail failed", inviteErr);
    return fail(500, "internal", "could not send the invite");
  }
  const userId = invited.user.id;

  const rollback = async () => {
    const { error } = await svc.auth.admin.deleteUser(userId);
    if (error) console.error("rollback deleteUser failed", error);
  };

  if (input.provision) {
    const { data: tenantId, error } = await svc.rpc("provision_tenant", {
      p_name: input.provision.name,
      p_slug: input.provision.slug,
      p_base_currency: input.provision.baseCurrency,
      p_owner_user_id: userId,
      p_owner_username: input.username,
      p_preset: input.provision.preset,
      p_timezone: input.provision.timezone,
      p_owner_full_name: input.fullName,
    });
    if (error) {
      await rollback();
      return fromDbError(error);
    }
    return json(201, { user_id: userId, email: input.email, tenant_id: tenantId });
  }

  const { data: tenantId, error } = await svc.rpc("admin_register_user", {
    p_caller: callerId,
    p_user: userId,
    p_username: input.username,
    p_full_name: input.fullName,
    p_role: input.role,
    p_locale: input.locale,
    p_location: input.locationId,
    p_position: input.position,
  });
  if (error) {
    await rollback();
    return fromDbError(error);
  }
  return json(201, { user_id: userId, email: input.email, tenant_id: tenantId });
});
