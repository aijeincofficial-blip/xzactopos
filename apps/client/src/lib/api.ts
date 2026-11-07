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
  tenant: MyAccessPayload["tenant"] & {
    id: string;
    name: string;
    slug: string;
    base_currency: string;
    timezone: string;
    setup_completed: boolean;
  };
  locations: Array<MyAccessPayload["locations"][number] & { code: string; name: string }>;
}

export const getMyAccess = () => rpc<MyAccess>("get_my_access");

/** Cashiers sign in as <username>.<slug>@pos.invalid; invited users use their real email. */
export function loginEmail(identifier: string, slug: string): string {
  const id = identifier.trim().toLowerCase();
  return id.includes("@") ? id : `${id}.${slug}@pos.invalid`;
}

export async function signIn(slug: string, identifier: string, password: string) {
  const { error } = await supabase.auth.signInWithPassword({ email: loginEmail(identifier, slug), password });
  if (error) throw new ApiError("invalid_credentials", error.message);
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
