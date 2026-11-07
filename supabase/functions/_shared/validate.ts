// Pure request validation shared by the create_user and invite_user Edge Functions.
// No Deno or npm imports, so the same file is unit-tested with Vitest (validate.test.ts).
// Patterns mirror the CHECK constraints in the core tenancy migration.

export const USERNAME_RE = /^[a-z0-9][a-z0-9._-]{1,38}[a-z0-9]$/;
export const SLUG_RE = /^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CURRENCY_RE = /^[A-Z]{3}$/;

export const ROLES = ["superadmin", "admin", "warehouse", "cashier"] as const;
export const POSITIONS = ["manager", "supervisor"] as const;
export const LOCALES = ["en", "fil"] as const;
export const PRESETS = ["inventory", "pos", "warehouse", "all"] as const;

export type Role = (typeof ROLES)[number];
export type Position = (typeof POSITIONS)[number];
export type Locale = (typeof LOCALES)[number];
export type Preset = (typeof PRESETS)[number];

export type Result<T> = { ok: true; value: T } | { ok: false; field: string; error: string };

export interface CreateUserInput {
  username: string;
  fullName: string;
  password: string;
  role: Role;
  locale: Locale | null;
  locationId: string | null;
  position: Position | null;
}

export interface ProvisionInput {
  name: string;
  slug: string;
  baseCurrency: string;
  preset: Preset;
  timezone: string;
}

export interface InviteUserInput {
  email: string;
  username: string;
  fullName: string;
  role: Role;
  locale: Locale | null;
  locationId: string | null;
  position: Position | null;
  redirectTo: string | null;
  /** Present only for the platform operator's "new tenant + owner" flow. */
  provision: ProvisionInput | null;
}

/** Cashiers have no real email. The tenant slug keeps usernames independent across tenants. */
export function syntheticEmail(username: string, slug: string): string {
  return `${username}.${slug}@pos.invalid`;
}

type Obj = Record<string, unknown>;

class Invalid extends Error {
  constructor(readonly field: string, message: string) {
    super(message);
  }
}

function str(o: Obj, key: string, opts: { required?: boolean; max?: number } = {}): string | null {
  const v = o[key];
  if (v === undefined || v === null || v === "") {
    if (opts.required) throw new Invalid(key, "required");
    return null;
  }
  if (typeof v !== "string") throw new Invalid(key, "must be a string");
  const s = v.trim();
  if (opts.max !== undefined && s.length > opts.max) throw new Invalid(key, `at most ${opts.max} characters`);
  return s;
}

function oneOf<T extends string>(o: Obj, key: string, allowed: readonly T[], required: boolean): T | null {
  const v = str(o, key, { required });
  if (v === null) return null;
  if (!(allowed as readonly string[]).includes(v)) throw new Invalid(key, `must be one of ${allowed.join(", ")}`);
  return v as T;
}

function username(o: Obj): string {
  const v = str(o, "username", { required: true })!.toLowerCase();
  if (!USERNAME_RE.test(v)) {
    throw new Invalid("username", "3-40 characters: a-z, 0-9, dot, dash, underscore; must start and end with a letter or digit");
  }
  return v;
}

function uuid(o: Obj, key: string): string | null {
  const v = str(o, key);
  if (v !== null && !UUID_RE.test(v)) throw new Invalid(key, "must be a UUID");
  return v;
}

function common(o: Obj) {
  const role = oneOf(o, "role", ROLES, true)!;
  const locationId = uuid(o, "location_id");
  const position = oneOf(o, "position", POSITIONS, false);
  if (position !== null && role !== "admin") throw new Invalid("position", "only admins hold a position");
  if (role === "admin" && locationId !== null && position === null) {
    throw new Invalid("position", "required when assigning an admin to a store");
  }
  if (position !== null && locationId === null) throw new Invalid("location_id", "required with a position");
  return {
    username: username(o),
    fullName: str(o, "full_name", { max: 120 }) ?? "",
    role,
    locale: oneOf(o, "locale", LOCALES, false),
    locationId,
    position,
  };
}

function run<T>(body: unknown, fn: (o: Obj) => T): Result<T> {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return { ok: false, field: "body", error: "expected a JSON object" };
  }
  try {
    return { ok: true, value: fn(body as Obj) };
  } catch (e) {
    if (e instanceof Invalid) return { ok: false, field: e.field, error: e.message };
    throw e;
  }
}

export function parseCreateUser(body: unknown): Result<CreateUserInput> {
  return run(body, (o) => {
    const password = o["password"];
    if (typeof password !== "string" || password.length < 8 || password.length > 72) {
      throw new Invalid("password", "8-72 characters");
    }
    return { ...common(o), password };
  });
}

export function parseInviteUser(body: unknown): Result<InviteUserInput> {
  return run(body, (o) => {
    const email = str(o, "email", { required: true, max: 254 })!.toLowerCase();
    if (!EMAIL_RE.test(email) || email.endsWith("@pos.invalid")) throw new Invalid("email", "must be a real email address");

    const redirectTo = str(o, "redirect_to", { max: 500 });
    if (redirectTo !== null && !/^https?:\/\//.test(redirectTo)) throw new Invalid("redirect_to", "must be an http(s) URL");

    let provision: ProvisionInput | null = null;
    const p = o["provision"];
    if (p !== undefined && p !== null) {
      if (typeof p !== "object" || Array.isArray(p)) throw new Invalid("provision", "expected an object");
      const po = p as Obj;
      const slug = str(po, "slug", { required: true })!.toLowerCase();
      if (!SLUG_RE.test(slug)) throw new Invalid("provision.slug", "3-40 characters: a-z, 0-9, dash");
      const baseCurrency = str(po, "base_currency", { required: true })!.toUpperCase();
      if (!CURRENCY_RE.test(baseCurrency)) throw new Invalid("provision.base_currency", "ISO 4217 code");
      provision = {
        name: str(po, "name", { required: true, max: 120 })!,
        slug,
        baseCurrency,
        preset: oneOf(po, "preset", PRESETS, false) ?? "inventory",
        timezone: str(po, "timezone", { max: 64 }) ?? "UTC",
      };
    }

    const c = common({ ...o, role: provision ? "superadmin" : o["role"] });
    if (provision && c.locationId !== null) throw new Invalid("location_id", "not used when provisioning");
    return { ...c, email, redirectTo, provision };
  });
}
