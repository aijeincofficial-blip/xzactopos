// End-to-end smoke test for Phase 1 user flows against the LOCAL Supabase stack.
// Usage: pnpm smoke:users   (requires `supabase start`)
//
// Provisions a throwaway tenant through invite_user, creates users through create_user, signs in as
// them, checks permissions, then deletes everything it created. Local stack only: it reads the
// local service role key from `supabase status` and refuses to run against anything else.
import { execSync } from "node:child_process";
import { randomUUID } from "node:crypto";

const env = Object.fromEntries(
  execSync("pnpm exec supabase status -o env", { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] })
    .split(/\r?\n/)
    .map((l) => /^([A-Z_]+)="?(.*?)"?$/.exec(l))
    .filter(Boolean)
    .map((m) => [m[1], m[2]]),
);
const API = env.API_URL;
const ANON = env.ANON_KEY;
const SERVICE = env.SERVICE_ROLE_KEY;
if (!API || !/^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(API)) {
  console.error(`refusing to run: API_URL is not local (${API})`);
  process.exit(2);
}

const slug = `smoke-${Date.now().toString(36)}`;
const PASSWORD = "Smoke-test-pass1";
let failures = 0;

function check(ok, label, detail) {
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${ok || detail === undefined ? "" : `  -> ${JSON.stringify(detail)}`}`);
  if (!ok) failures++;
}

async function call(path, { token = ANON, body, method = "POST", headers = {} } = {}) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { apikey: ANON, Authorization: `Bearer ${token}`, "Content-Type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: res.status, data };
}

const fn = (name, token, body) => call(`/functions/v1/${name}`, { token, body });
const rpc = (name, token, body = {}) => call(`/rest/v1/rpc/${name}`, { token, body });

async function signIn(email) {
  const r = await call("/auth/v1/token?grant_type=password", { body: { email, password: PASSWORD } });
  if (r.status !== 200) throw new Error(`sign-in failed for ${email}: ${JSON.stringify(r.data)}`);
  return r.data.access_token;
}

const claims = (token) => JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString());

async function cleanup() {
  await call(`/rest/v1/tenants?slug=eq.${slug}`, { method: "DELETE", token: SERVICE });
  const users = await call("/auth/v1/admin/users?per_page=1000", { method: "GET", token: SERVICE });
  for (const u of users.data?.users ?? []) {
    if (u.email?.includes(slug)) await call(`/auth/v1/admin/users/${u.id}`, { method: "DELETE", token: SERVICE });
  }
}

try {
  // 1. Platform operator provisions a tenant and invites its owner
  const ownerEmail = `owner.${slug}@example.test`;
  const prov = await fn("invite_user", SERVICE, {
    email: ownerEmail,
    username: "owner",
    full_name: "Owner",
    provision: { name: "Smoke Shop", slug, base_currency: "PHP", preset: "pos", timezone: "Asia/Manila" },
  });
  check(prov.status === 201 && prov.data.tenant_id, "service role provisions a tenant and invites the owner", prov);

  // accept the invite (set a password) the way the email link would
  await call(`/auth/v1/admin/users/${prov.data.user_id}`, {
    method: "PUT", token: SERVICE, body: { password: PASSWORD, email_confirm: true },
  });
  const owner = await signIn(ownerEmail);
  check(claims(owner).tenant_id === prov.data.tenant_id && claims(owner).user_role === "superadmin",
    "owner token carries tenant_id and superadmin role", claims(owner));

  // 2. Owner creates two stores (client-generated ids)
  const s1 = randomUUID();
  const s2 = randomUUID();
  const loc1 = await rpc("upsert_location", owner, { p_id: s1, p_type: "store", p_code: "S01", p_name: "Store 1" });
  const loc2 = await rpc("upsert_location", owner, { p_id: s2, p_type: "store", p_code: "S02", p_name: "Store 2" });
  check(loc1.status === 200 && loc2.status === 200, "owner creates two stores", [loc1, loc2]);

  // 3. Acceptance: superadmin creates a cashier and assigns a store
  const cashier = await fn("create_user", owner, {
    username: "maria", password: PASSWORD, role: "cashier", full_name: "Maria", location_id: s1,
  });
  check(cashier.status === 201 && cashier.data.email === `maria.${slug}@pos.invalid`,
    "superadmin creates cashier maria in S01 (synthetic email)", cashier);

  const maria = await signIn(`maria.${slug}@pos.invalid`);
  const mariaAccess = await rpc("get_my_access", maria);
  check(claims(maria).user_role === "cashier" && mariaAccess.data?.locations?.map((l) => l.code).join() === "S01",
    "cashier signs in with slug + username and sees only S01", mariaAccess.data);

  // 4. Acceptance: admin with different positions in two stores
  const admin = await fn("create_user", owner, {
    username: "lito", password: PASSWORD, role: "admin", location_id: s1, position: "manager",
  });
  const assign = await rpc("assign_location", owner, { p_user: admin.data?.user_id, p_location: s2, p_position: "supervisor" });
  check(admin.status === 201 && assign.status === 204, "owner creates admin lito: manager S01, supervisor S02", [admin, assign]);

  const lito = await signIn(`lito.${slug}@pos.invalid`);
  const litoAccess = await rpc("get_my_access", lito);
  const positions = Object.fromEntries((litoAccess.data?.locations ?? []).map((l) => [l.code, l.position]));
  check(positions.S01 === "manager" && positions.S02 === "supervisor", "admin sees per-store positions", positions);

  const pia = await fn("create_user", lito, { username: "pia", password: PASSWORD, role: "cashier", location_id: s1 });
  check(pia.status === 201, "manager creates a cashier in the store they manage", pia);

  const denied = await fn("create_user", lito, { username: "lea", password: PASSWORD, role: "cashier", location_id: s2 });
  check(denied.status === 403 && denied.data?.error?.hint === "create_denied",
    "supervisor store: cashier creation refused", denied);

  const users = await call("/auth/v1/admin/users?per_page=1000", { method: "GET", token: SERVICE });
  check(!users.data.users.some((u) => u.email === `lea.${slug}@pos.invalid`),
    "refused request left no auth user behind (rolled back)");

  const noAdmin = await fn("create_user", lito, { username: "boss", password: PASSWORD, role: "admin" });
  check(noAdmin.status === 403, "manager cannot create admins", noAdmin);

  const noInvite = await fn("invite_user", lito, { email: `x.${slug}@example.test`, username: "xavier", role: "warehouse" });
  check(noInvite.status === 403, "admin cannot invite users", noInvite);

  // 5. Superadmin invites a warehouse user by email
  const inv = await fn("invite_user", owner, { email: `wh.${slug}@example.test`, username: "pedro", role: "warehouse" });
  check(inv.status === 201, "superadmin invites a warehouse user by email", inv);

  const dup = await fn("create_user", owner, { username: "maria", password: PASSWORD, role: "cashier" });
  check(dup.status === 409, "duplicate username is a 409", dup);

  const anon = await fn("create_user", ANON, { username: "anon1", password: PASSWORD, role: "cashier" });
  check(anon.status === 401, "anonymous callers are refused", anon);
} catch (e) {
  failures++;
  console.error("FAIL  smoke test crashed:", e);
} finally {
  await cleanup();
  const left = await call(`/rest/v1/tenants?slug=eq.${slug}&select=id`, { method: "GET", token: SERVICE });
  check(Array.isArray(left.data) && left.data.length === 0, "cleanup removed the smoke tenant");
}

console.log(failures === 0 ? "\nsmoke:users passed" : `\nsmoke:users FAILED (${failures})`);
process.exit(failures === 0 ? 0 : 1);
