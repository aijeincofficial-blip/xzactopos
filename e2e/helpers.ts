import { readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { expect, type Page } from "@playwright/test";

export const QA_PASS = "QaPass123!";
export const ALPHA_SLUG = "qa-alpha-php";
export const EMAILS = {
  owner: "owner.qa-alpha-php@pos.invalid",
  manager: "manager.qa-alpha-php@pos.invalid",
  supervisor: "supervisor.qa-alpha-php@pos.invalid",
  whclerk: "whclerk.qa-alpha-php@pos.invalid",
  cashier: "cashier.qa-alpha-php@pos.invalid",
} as const;

export function getSupabaseConfig(): { url: string; anonKey: string } {
  const root = process.cwd();
  const candidates = [path.join(root, "apps", "client", ".env.local"), path.join(root, ".env")];
  let url = "http://127.0.0.1:54321";
  let anonKey = "";
  for (const file of candidates) {
    if (!existsSync(file)) continue;
    const text = readFileSync(file, "utf8");
    const u = text.match(/^VITE_SUPABASE_URL=(.+)$/m)?.[1]?.trim();
    const k =
      text.match(/^VITE_SUPABASE_ANON_KEY=(.+)$/m)?.[1]?.trim() ??
      text.match(/^SUPABASE_ANON_KEY=(.+)$/m)?.[1]?.trim();
    if (u) url = u;
    if (k && !anonKey) anonKey = k;
  }
  if (!anonKey) {
    throw new Error("Missing VITE_SUPABASE_ANON_KEY / SUPABASE_ANON_KEY in .env or apps/client/.env.local");
  }
  return { url, anonKey };
}

export async function apiAuth(email: string, password = QA_PASS): Promise<{ token: string; userId: string }> {
  const { url, anonKey } = getSupabaseConfig();
  const res = await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: anonKey, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const body = (await res.json()) as { access_token?: string; user?: { id: string }; error_description?: string };
  if (!res.ok || !body.access_token || !body.user?.id) {
    throw new Error(`Supabase auth failed for ${email}: ${JSON.stringify(body)}`);
  }
  return { token: body.access_token, userId: body.user.id };
}

export async function restGet<T = unknown>(token: string, queryPath: string): Promise<T> {
  const { url, anonKey } = getSupabaseConfig();
  const res = await fetch(`${url}/rest/v1/${queryPath}`, {
    headers: { apikey: anonKey, Authorization: `Bearer ${token}` },
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`REST GET ${queryPath} -> ${res.status}: ${text}`);
  }
  return text ? (JSON.parse(text) as T) : (undefined as T);
}

export async function rpcRaw(
  token: string,
  fn: string,
  args: Record<string, unknown> = {},
): Promise<{ status: number; ok: boolean; body: unknown }> {
  const { url, anonKey } = getSupabaseConfig();
  const res = await fetch(`${url}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args),
  });
  const text = await res.text();
  let body: unknown = text;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    // plain text fallback
  }
  return { status: res.status, ok: res.ok, body };
}

export async function rpc<T = unknown>(
  token: string,
  fn: string,
  args: Record<string, unknown> = {},
): Promise<T> {
  const r = await rpcRaw(token, fn, args);
  if (!r.ok) {
    throw new Error(`RPC ${fn} -> ${r.status}: ${JSON.stringify(r.body)}`);
  }
  return r.body as T;
}

export interface AlphaFixtures {
  tenantId: string;
  s01Id: string;
  s02Id: string;
  w01Id: string;
  latteRegId: string;
  latteRegSku: string;
  latteLargeId: string;
  latteLargeSku: string;
  kapeId: string;
  kapeSku: string;
  pandesalId: string;
  pandesalSku: string;
}

export async function resolveAlphaFixtures(ownerToken: string): Promise<AlphaFixtures> {
  const locs = await restGet<Array<{ id: string; code: string; type: string; tenant_id: string }>>(
    ownerToken,
    "locations?select=id,code,type,tenant_id",
  );
  const s01 = locs.find((l) => l.code === "S01");
  const s02 = locs.find((l) => l.code === "S02");
  const w01 = locs.find((l) => l.code === "W01");
  if (!s01 || !s02 || !w01) throw new Error(`Missing QA locations: ${JSON.stringify(locs)}`);

  const variants = await restGet<
    Array<{ id: string; sku: string; barcode: string | null; product_id: string; name: string | null }>
  >(ownerToken, "product_variants?select=id,sku,barcode,product_id,name");
  const bySku = new Map(variants.map((v) => [v.sku, v]));
  const latteReg = bySku.get("LATTE-R");
  const latteLarge = bySku.get("LATTE-L");
  const kape = variants.find((v) => v.barcode === "4809911000011");
  const pandesal = variants.find((v) => v.barcode === "4809911000028");
  if (!latteReg || !latteLarge || !kape || !pandesal) {
    throw new Error("Missing seeded qa-alpha-php variants; run `node scripts/qa-seed.mjs` first.");
  }
  return {
    tenantId: s01.tenant_id,
    s01Id: s01.id,
    s02Id: s02.id,
    w01Id: w01.id,
    latteRegId: latteReg.id,
    latteRegSku: latteReg.sku,
    latteLargeId: latteLarge.id,
    latteLargeSku: latteLarge.sku,
    kapeId: kape.id,
    kapeSku: kape.sku,
    pandesalId: pandesal.id,
    pandesalSku: pandesal.sku,
  };
}

export async function getStockQty(token: string, locationId: string, variantId: string): Promise<number> {
  const rows = await restGet<Array<{ qty_on_hand: number }>>(
    token,
    `stock_levels?location_id=eq.${locationId}&variant_id=eq.${variantId}&select=qty_on_hand`,
  );
  return Number(rows[0]?.qty_on_hand ?? 0);
}

export async function ensurePosEnabled(ownerToken: string): Promise<void> {
  await rpc(ownerToken, "set_modules", { p_pos: true, p_warehouse: true });
}

export async function signInEmail(page: Page, email: string, password = QA_PASS): Promise<void> {
  await page.goto("/login");
  await page.getByTestId("auth-tab-email").click();
  await page.getByTestId("home-email-input").fill(email);
  await page.getByTestId("home-password-input").fill(password);
  await page.getByTestId("home-email-submit").click();
  await expect(page).toHaveURL(/\/app(?:\/|$)/, { timeout: 15_000 });
}

export async function signInWarehousePortal(
  page: Page,
  slug: string,
  identifier: string,
  password = QA_PASS,
): Promise<void> {
  await page.goto("/warehouse");
  await page.getByTestId("wh-login-slug").fill(slug);
  await page.getByTestId("wh-login-identifier").fill(identifier);
  await page.getByTestId("wh-login-password").fill(password);
  await page.getByTestId("wh-login-submit").click();
  await expect(page).toHaveURL(/\/app(?:\/|$)/, { timeout: 15_000 });
}

export async function ensureServiceWorkerControlled(page: Page): Promise<void> {
  const hasController = await page.evaluate(async () => {
    if (!("serviceWorker" in navigator)) return false;
    await navigator.serviceWorker.ready;
    return Boolean(navigator.serviceWorker.controller);
  });
  if (!hasController) {
    await page.reload({ waitUntil: "networkidle" });
    await page.evaluate(async () => {
      if ("serviceWorker" in navigator) await navigator.serviceWorker.ready;
    });
  }
}
