import { FunctionsHttpError } from "@supabase/supabase-js";
import type { MyAccessPayload, Position, Role } from "@pos/core";
import { supabase } from "./supabase.ts";

/** Error with a stable key the UI maps to an i18n message (`errors:<key>`). */
export class ApiError extends Error {
  constructor(
    readonly key: string,
    message: string,
    readonly field?: string,
  ) {
    super(message);
  }
}

interface RawError {
  code?: string | undefined;
  message: string;
  hint?: string | null | undefined;
}

/** Postgres/PostgREST errors carry our business `hint`; otherwise fall back to the SQLSTATE class. */
export function fromRaw(e: RawError): ApiError {
  if (e.hint) return new ApiError(e.hint, e.message);
  switch (e.code) {
    case "42501":
      return new ApiError("forbidden", e.message);
    case "23505":
      return new ApiError("duplicate", e.message);
    case "22023":
    case "23514":
      return new ApiError("invalid_argument", e.message);
    default:
      return new ApiError("unknown", e.message);
  }
}

export async function rpc<T = unknown>(name: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw fromRaw(error);
  return data as T;
}

export interface MyAccess extends MyAccessPayload {
  user_id: string;
  username: string;
  full_name: string;
  locale: "en" | "fil";
  is_platform_admin?: boolean;
  tenant: MyAccessPayload["tenant"] & {
    id: string;
    name: string;
    slug: string;
    base_currency: string;
    timezone: string;
    setup_completed: boolean;
    mode?: "solo" | "full";
  };
  locations: Array<MyAccessPayload["locations"][number] & { code: string; name: string }>;
}

export const getMyAccess = () => rpc<MyAccess>("get_my_access");
export const setTenantMode = (mode: "solo" | "full") => rpc<void>("set_tenant_mode", { p_mode: mode });

/** Cashiers sign in as <username>.<slug>@pos.invalid; invited users use their real email. */
export function loginEmail(identifier: string, slug: string): string {
  const id = identifier.trim().toLowerCase();
  return id.includes("@") ? id : `${id}.${slug}@pos.invalid`;
}

export async function signIn(slug: string, identifier: string, password: string) {
  const { error } = await supabase.auth.signInWithPassword({ email: loginEmail(identifier, slug), password });
  if (error) throw new ApiError("invalid_credentials", error.message);
}

/** Direct email sign-in for Solo store owners or Full-mode owners/managers without typing a tenant slug first. */
export async function signInWithEmail(email: string, password: string) {
  const { error } = await supabase.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
  if (error) throw new ApiError("invalid_credentials", error.message);
}

/** Self-serve Solo account creation. Returns hasSession=false when email confirmation is required by Auth config. */
export async function signUpSolo(email: string, password: string): Promise<{ hasSession: boolean }> {
  const { data, error } = await supabase.auth.signUp({ email: email.trim().toLowerCase(), password });
  if (error) {
    const exists = error.message.toLowerCase().includes("already");
    throw new ApiError(exists ? "duplicate" : "unknown", error.message);
  }
  return { hasSession: data.session !== null };
}

/** Creates the one-store Solo tenant for the signed-in user and refreshes JWT claims so tenant_id is active. */
export async function provisionSoloStore(params: {
  tenantId: string;
  locationId: string;
  storeName: string;
  locale: "en" | "fil";
}): Promise<string> {
  const id = await rpc<string>("provision_solo_store", {
    p_tenant_id: params.tenantId,
    p_location_id: params.locationId,
    p_store_name: params.storeName.trim(),
    p_locale: params.locale,
  });
  await supabase.auth.refreshSession();
  return id;
}

/** Sends a password recovery link. Caller shows an anti-enumeration confirmation regardless of existence. */
export async function sendPasswordReset(email: string, redirectTo?: string): Promise<void> {
  await supabase.auth.resetPasswordForEmail(email.trim().toLowerCase(), redirectTo ? { redirectTo } : undefined);
}

/** Sets a new password for the active session (including right after opening a password recovery link). */
export async function updatePassword(newPassword: string): Promise<void> {
  const { error } = await supabase.auth.updateUser({ password: newPassword });
  if (error) throw new ApiError("unknown", error.message);
}

/** Own profile locale: allowed by the column grant (full_name, locale) and the own-row policy. */
export async function saveMyLocale(userId: string, locale: "en" | "fil") {
  const { error } = await supabase.from("profiles").update({ locale }).eq("user_id", userId);
  if (error) throw fromRaw(error);
}

export const signOut = () => supabase.auth.signOut();

export interface CreateUserBody {
  username: string;
  password: string;
  role: Role;
  full_name?: string;
  locale?: "en" | "fil";
  location_id?: string;
  position?: Position;
}

export async function createUser(body: CreateUserBody) {
  const { data, error } = await supabase.functions.invoke<{ user_id: string }>("create_user", { body });
  if (error) {
    if (error instanceof FunctionsHttpError) {
      const parsed = (await error.context.json().catch(() => null)) as {
        error?: { code?: string; message?: string; hint?: string; field?: string };
      } | null;
      const e = parsed?.error;
      if (e) {
        throw new ApiError(e.hint ?? (e.code === "invalid_argument" ? "invalid_argument" : (e.code ?? "unknown")), e.message ?? "", e.field);
      }
    }
    throw new ApiError("unknown", error.message);
  }
  return data!;
}

export interface InviteUserBody {
  email: string;
  username: string;
  role: Role;
  full_name?: string;
  locale?: "en" | "fil";
  location_id?: string;
  position?: Position;
}

export async function inviteUser(body: InviteUserBody) {
  const { data, error } = await supabase.functions.invoke<{ user_id: string }>("invite_user", { body });
  if (error) {
    if (error instanceof FunctionsHttpError) {
      const parsed = (await error.context.json().catch(() => null)) as {
        error?: { code?: string; message?: string; hint?: string; field?: string };
      } | null;
      const e = parsed?.error;
      if (e) {
        throw new ApiError(e.hint ?? (e.code === "invalid_argument" ? "invalid_argument" : (e.code ?? "unknown")), e.message ?? "", e.field);
      }
    }
    throw new ApiError("unknown", error.message);
  }
  return data!;
}

export async function clearUserPin(userId: string): Promise<void> {
  await rpc("clear_user_pin", { p_user_id: userId });
}

export async function setMyPin(newPin: string, currentPin?: string): Promise<{ ok: boolean; hint?: string }> {
  const res = await rpc<{ ok: boolean; hint?: string }>("set_my_pin", {
    p_new_pin: newPin,
    p_current_pin: currentPin || null,
  });
  if (res && typeof res === "object" && !res.ok) {
    throw new ApiError(res.hint ?? "pin_wrong", res.hint ?? "pin_wrong");
  }
  return res;
}

export interface UserRow {
  user_id: string;
  username: string;
  full_name: string;
  role: Role;
  active: boolean;
  locale: string | null;
}
export interface LocationRow {
  id: string;
  type: "store" | "warehouse";
  code: string;
  name: string;
  address: string | null;
  bins_enabled: boolean;
  active: boolean;
}
export interface AccessRow {
  user_id: string;
  location_id: string;
  position: Position | null;
}
export interface CurrencyRow {
  code: string;
  name: string;
}

async function select<T>(q: PromiseLike<{ data: T[] | null; error: RawError | null }>): Promise<T[]> {
  const { data, error } = await q;
  if (error) throw fromRaw(error);
  return data ?? [];
}

export const listUsers = () =>
  select<UserRow>(
    supabase
      .from("profiles")
      .select("user_id, username, full_name, role, active, locale")
      .is("deleted_at", null)
      .order("username")
      .limit(500),
  );

export const listLocations = () =>
  select<LocationRow>(
    supabase
      .from("locations")
      .select("id, type, code, name, address, bins_enabled, active")
      .is("deleted_at", null)
      .order("code")
      .limit(500),
  );

export const listAccess = () =>
  select<AccessRow>(
    supabase.from("location_access").select("user_id, location_id, position").is("deleted_at", null).limit(2000),
  );

export const listCurrencies = () =>
  select<CurrencyRow>(supabase.from("currencies").select("code, name").order("code").limit(300));

export interface LimitsRow {
  max_locations: number;
  max_users: number;
  max_devices: number;
  max_products: number;
}

export async function getTenantLimits(): Promise<LimitsRow | null> {
  const { data, error } = await supabase.from("tenant_limits").select("max_locations, max_users, max_devices, max_products").maybeSingle();
  if (error) throw fromRaw(error);
  return data;
}
