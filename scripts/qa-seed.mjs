// Idempotent multi-tenant QA seed script against the LOCAL Supabase stack.
// Usage: node scripts/qa-seed.mjs
//
// Seeds 2 tenants (qa-alpha-php in PHP / Asia/Manila, qa-beta-usd in USD / UTC),
// each with 2 stores (S01, S02), 1 warehouse (W01) with bins enabled,
// 1 user per role (superadmin, admin-manager, admin-supervisor, warehouse, cashier),
// categories, suppliers, products (tracked & untracked), warehouse bin putaway,
// initial store stock, customers, and open purchase orders.
//
// Local stack only: refuses to run if API_URL is not localhost / 127.0.0.1.

import { execSync } from "node:child_process";
import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";

export const QA_PASSWORD = "QaPass123!";

export const QA_TENANT_SPECS = [
  {
    slug: "qa-alpha-php",
    name: "XZACTO QA Alpha",
    currency: "PHP",
    timezone: "Asia/Manila",
    pin: "1234",
    supplierName: "Alpha Luzon Distributors",
    customerName: "Maria Santos",
    products: [
      { key: "p1", name: "Kape Barako", unit: "pack", price: 12000, cost: 8000, barcode: "4809911000011", reorder: 10, s1Qty: 40, s2Qty: 15, whQty: 50, track: true },
      { key: "p2", name: "Pan de Sal Bag", unit: "bag", price: 3500, cost: 2000, barcode: "4809911000028", reorder: 12, s1Qty: 30, s2Qty: 20, whQty: 40, track: true },
      { key: "p3", name: "Bottled Water 500ml", unit: "btl", price: 2000, cost: 1100, barcode: "4809911000035", reorder: 24, s1Qty: 6, s2Qty: 10, whQty: 60, track: true },
      { key: "p4", name: "Gift Wrap Fee", unit: "svc", price: 1500, cost: 0, barcode: null, reorder: 0, s1Qty: 0, s2Qty: 0, whQty: 0, track: false },
      {
        key: "p5",
        name: "Iced Latte",
        unit: "cup",
        track: true,
        variants: [
          {
            vkey: "reg",
            name: "Regular",
            sku: "LATTE-R",
            barcode: "4809911000059",
            price: 12000,
            cost: 6000,
            reorder: 10,
            s1Qty: 20,
            s2Qty: 12,
            whQty: 40,
            isDefault: true,
          },
          {
            vkey: "lrg",
            name: "Large",
            sku: "LATTE-L",
            barcode: "4809911000066",
            price: 15000,
            cost: 7500,
            reorder: 10,
            s1Qty: 15,
            s2Qty: 10,
            whQty: 30,
            isDefault: false,
          },
        ],
      },
    ],
  },
  {
    slug: "qa-beta-usd",
    name: "XZACTO QA Beta",
    currency: "USD",
    timezone: "UTC",
    pin: "5678",
    supplierName: "Pacific Supply Co",
    customerName: "Jordan Rivera",
    products: [
      { key: "p1", name: "Espresso Roast", unit: "bag", price: 1450, cost: 900, barcode: "8909922000014", reorder: 8, s1Qty: 25, s2Qty: 12, whQty: 40, track: true },
      { key: "p2", name: "Sparkling Water", unit: "can", price: 250, cost: 120, barcode: "8909922000021", reorder: 15, s1Qty: 5, s2Qty: 18, whQty: 50, track: true },
      { key: "p3", name: "Tote Carry Bag", unit: "pc", price: 400, cost: 180, barcode: "8909922000038", reorder: 5, s1Qty: 20, s2Qty: 10, whQty: 30, track: true },
    ],
  },
];

export function detUuid(key) {
  const bytes = createHash("sha256").update(`qa-seed-v1:${key}`).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const h = bytes.toString("hex");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
}

export function getLocalSupabaseEnv() {
  const raw = execSync("pnpm exec supabase status -o env", {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  const env = Object.fromEntries(
    raw
      .split(/\r?\n/)
      .map((l) => /^([A-Z_]+)="?(.*?)"?$/.exec(l))
      .filter(Boolean)
      .map((m) => [m[1], m[2]]),
  );
  if (!env.API_URL || !/^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(env.API_URL)) {
    throw new Error(`Refusing to run qa-seed against non-local API_URL: ${env.API_URL}`);
  }
  return env;
}

function makeClient(env) {
  async function api(path, { token = env.ANON_KEY, method = "GET", body, headers = {} } = {}) {
    const res = await fetch(`${env.API_URL}${path}`, {
      method,
      headers: {
        apikey: env.ANON_KEY,
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        ...headers,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = text;
    }
    return { ok: res.ok, status: res.status, data };
  }

  async function rpc(name, token, args = {}) {
    const res = await api(`/rest/v1/rpc/${name}`, { token, method: "POST", body: args });
    if (!res.ok) {
      throw new Error(`RPC ${name} (${res.status}): ${JSON.stringify(res.data)}`);
    }
    return res.data;
  }

  async function restGet(path) {
    const res = await api(`/rest/v1/${path}`, { token: env.SERVICE_ROLE_KEY, method: "GET" });
    if (!res.ok) throw new Error(`REST GET ${path} (${res.status}): ${JSON.stringify(res.data)}`);
    return res.data;
  }

  async function signIn(email, password = QA_PASSWORD) {
    const res = await api("/auth/v1/token?grant_type=password", {
      token: env.ANON_KEY,
      method: "POST",
      body: { email, password },
    });
    if (!res.ok) throw new Error(`Sign-in failed for ${email}: ${JSON.stringify(res.data)}`);
    return res.data.access_token;
  }

  async function listAuthUsers() {
    const all = [];
    for (let page = 1; page <= 20; page++) {
      const res = await api(`/auth/v1/admin/users?page=${page}&per_page=100`, {
        token: env.SERVICE_ROLE_KEY,
        method: "GET",
      });
      if (!res.ok) throw new Error(`List auth users failed: ${JSON.stringify(res.data)}`);
      const batch = res.data?.users ?? [];
      all.push(...batch);
      if (batch.length < 100) break;
    }
    return all;
  }

  async function ensureAuthUser({ email, fullName, username, tenantId }) {
    const existing = (await listAuthUsers()).find((u) => u.email?.toLowerCase() === email.toLowerCase());
    if (existing) {
      const upd = await api(`/auth/v1/admin/users/${existing.id}`, {
        token: env.SERVICE_ROLE_KEY,
        method: "PUT",
        body: {
          password: QA_PASSWORD,
          email_confirm: true,
          user_metadata: { username, full_name: fullName },
          ...(tenantId ? { app_metadata: { tenant_id: tenantId } } : {}),
        },
      });
      if (!upd.ok) throw new Error(`Update auth user ${email} failed: ${JSON.stringify(upd.data)}`);
      return { userId: existing.id, created: false };
    }
    const created = await api("/auth/v1/admin/users", {
      token: env.SERVICE_ROLE_KEY,
      method: "POST",
      body: {
        email,
        password: QA_PASSWORD,
        email_confirm: true,
        user_metadata: { username, full_name: fullName },
        ...(tenantId ? { app_metadata: { tenant_id: tenantId } } : {}),
      },
    });
    if (!created.ok) throw new Error(`Create auth user ${email} failed: ${JSON.stringify(created.data)}`);
    return { userId: created.data.id, created: true };
  }

  return { api, rpc, restGet, signIn, ensureAuthUser };
}

async function ensurePin(c, email, pin) {
  const jwt = await c.signIn(email);
  try {
    await c.rpc("set_my_pin", jwt, { p_new_pin: pin });
  } catch (err) {
    // Already has a PIN -> ignore if current_pin required
    if (!String(err.message).includes("invalid_pin") && !String(err.message).includes("pin")) {
      throw err;
    }
  }
}

async function seedTenant(c, env, spec) {
  const slug = spec.slug;
  const ownerEmail = `owner.${slug}@pos.invalid`;

  // 1. Provision tenant & owner if absent
  let [tenant] = await c.restGet(`tenants?slug=eq.${slug}&select=id,slug,name,base_currency,timezone,setup_completed_at`);
  let ownerUserId;
  if (!tenant) {
    const ownerAuth = await c.ensureAuthUser({ email: ownerEmail, fullName: "QA Owner", username: "owner" });
    ownerUserId = ownerAuth.userId;
    await c.rpc("provision_tenant", env.SERVICE_ROLE_KEY, {
      p_name: spec.name,
      p_slug: slug,
      p_base_currency: spec.currency,
      p_owner_user_id: ownerUserId,
      p_owner_username: "owner",
      p_preset: "all",
      p_timezone: spec.timezone,
      p_owner_full_name: "QA Owner",
    });
    [tenant] = await c.restGet(`tenants?slug=eq.${slug}&select=id,slug,name,base_currency,timezone,setup_completed_at`);
  } else {
    const [ownerProf] = await c.restGet(`profiles?tenant_id=eq.${tenant.id}&username=eq.owner&select=user_id`);
    ownerUserId = ownerProf?.user_id;
    await c.ensureAuthUser({ email: ownerEmail, fullName: "QA Owner", username: "owner", tenantId: tenant.id });
  }

  const tenantId = tenant.id;
  const ownerJwt = await c.signIn(ownerEmail);

  // Ensure Full mode + both modules active + setup completed
  await c.rpc("set_tenant_mode", ownerJwt, { p_mode: "full" });
  await c.rpc("set_modules", ownerJwt, { p_pos: true, p_warehouse: true });
  if (!tenant.setup_completed_at) {
    await c.rpc("complete_setup", ownerJwt, {
      p_name: spec.name,
      p_base_currency: spec.currency,
      p_timezone: spec.timezone,
      p_tax_mode: "inclusive",
      p_default_locale: "en",
      p_locales: ["en", "fil"],
      p_pos: true,
      p_warehouse: true,
    });
  }

  // 2. Locations (2 stores + 1 warehouse with bins enabled)
  const s1Id = detUuid(`${slug}:loc:S01`);
  const s2Id = detUuid(`${slug}:loc:S02`);
  const w1Id = detUuid(`${slug}:loc:W01`);
  const existingLocs = await c.restGet(`locations?tenant_id=eq.${tenantId}&select=id,code,type,bins_enabled`);
  const locByCode = new Map(existingLocs.map((l) => [l.code, l]));

  const loc1Id = locByCode.get("S01")?.id ?? s1Id;
  const loc2Id = locByCode.get("S02")?.id ?? s2Id;
  const whId = locByCode.get("W01")?.id ?? w1Id;

  if (!locByCode.has("S01")) {
    await c.rpc("upsert_location", ownerJwt, { p_id: loc1Id, p_type: "store", p_code: "S01", p_name: `${spec.name} Main` });
  }
  if (!locByCode.has("S02")) {
    await c.rpc("upsert_location", ownerJwt, { p_id: loc2Id, p_type: "store", p_code: "S02", p_name: `${spec.name} Annex` });
  }
  if (!locByCode.has("W01")) {
    await c.rpc("upsert_location", ownerJwt, { p_id: whId, p_type: "warehouse", p_code: "W01", p_name: `${spec.name} Warehouse`, p_bins_enabled: false });
  }
  const [whRow] = await c.restGet(`locations?id=eq.${whId}&select=bins_enabled`);
  const preBins = await c.restGet(`bins?tenant_id=eq.${tenantId}&warehouse_id=eq.${whId}&select=id,code`);
  if (!whRow?.bins_enabled || !preBins.some((b) => b.code === "RECEIVING")) {
    await c.rpc("enable_warehouse_bins", ownerJwt, { p_warehouse_id: whId });
  }

  // Ensure zones & bins
  const zones = await c.restGet(`warehouse_zones?tenant_id=eq.${tenantId}&warehouse_id=eq.${whId}&select=id,code`);
  const zoneByCode = new Map(zones.map((z) => [z.code, z.id]));
  if (!zoneByCode.has("STORAGE")) {
    const zId = detUuid(`${slug}:zone:STORAGE`);
    await c.rpc("upsert_warehouse_zone", ownerJwt, { p_warehouse_id: whId, p_code: "STORAGE", p_name: "Main Storage", p_type: "storage", p_id: zId });
    zoneByCode.set("STORAGE", zId);
  }
  const bins = await c.restGet(`bins?tenant_id=eq.${tenantId}&warehouse_id=eq.${whId}&select=id,code,zone_id`);
  const binByCode = new Map(bins.map((b) => [b.code, b.id]));
  if (!binByCode.has("A1-R1-S1")) {
    const bId = detUuid(`${slug}:bin:A1-R1-S1`);
    await c.rpc("upsert_warehouse_bin", ownerJwt, {
      p_warehouse_id: whId,
      p_code: "A1-R1-S1",
      p_zone_id: zoneByCode.get("STORAGE"),
      p_aisle: "A1",
      p_rack: "R1",
      p_shelf: "S1",
      p_position: "P1",
      p_type: "shelf",
      p_max_qty: 500,
      p_id: bId,
    });
    binByCode.set("A1-R1-S1", bId);
  }
  const shelfBinId = binByCode.get("A1-R1-S1");
  const rcvZoneId = zoneByCode.get("RCV") ?? zoneByCode.get("RECEIVING");
  const rcvBinId =
    binByCode.get("RECEIVING") ??
    binByCode.get("RCV-01") ??
    bins.find((b) => b.zone_id && b.zone_id === rcvZoneId)?.id;

  // 3. Users (1 per role: owner/superadmin, manager/admin-manager, supervisor/admin-supervisor, whclerk/warehouse, cashier/cashier)
  const userSpecs = [
    { username: "manager", fullName: "QA Manager", role: "admin", locationId: loc1Id, position: "manager", extraLoc: loc2Id },
    { username: "supervisor", fullName: "QA Supervisor", role: "admin", locationId: loc1Id, position: "supervisor" },
    { username: "whclerk", fullName: "QA Warehouse", role: "warehouse", locationId: whId, position: null },
    { username: "cashier", fullName: "QA Cashier", role: "cashier", locationId: loc1Id, position: null },
  ];

  const profiles = await c.restGet(`profiles?tenant_id=eq.${tenantId}&select=user_id,username,role`);
  const profByUsername = new Map(profiles.map((p) => [p.username, p]));
  const accessRows = await c.restGet(`location_access?tenant_id=eq.${tenantId}&deleted_at=is.null&select=user_id,location_id,position`);

  const usersSummary = {
    owner: { username: "owner", email: ownerEmail, password: QA_PASSWORD, role: "superadmin", pin: spec.pin, userId: ownerUserId },
  };

  for (const u of userSpecs) {
    const email = `${u.username}.${slug}@pos.invalid`;
    const auth = await c.ensureAuthUser({ email, fullName: u.fullName, username: u.username, tenantId });
    if (!profByUsername.has(u.username)) {
      await c.rpc("admin_register_user", env.SERVICE_ROLE_KEY, {
        p_caller: ownerUserId,
        p_user: auth.userId,
        p_username: u.username,
        p_full_name: u.fullName,
        p_role: u.role,
        p_locale: "en",
        p_location: u.locationId,
        p_position: u.position,
      });
    } else if (!accessRows.some((a) => a.user_id === auth.userId && a.location_id === u.locationId)) {
      await c.rpc("assign_location", ownerJwt, { p_user: auth.userId, p_location: u.locationId, p_position: u.position });
    }
    if (u.extraLoc && !accessRows.some((a) => a.user_id === auth.userId && a.location_id === u.extraLoc)) {
      await c.rpc("assign_location", ownerJwt, { p_user: auth.userId, p_location: u.extraLoc, p_position: u.position });
    }
    if (u.role === "admin") {
      await ensurePin(c, email, spec.pin);
    }
    usersSummary[u.username] = {
      username: u.username,
      email,
      password: QA_PASSWORD,
      role: u.position ? `${u.role}-${u.position}` : u.role,
      ...(u.role === "admin" ? { pin: spec.pin } : {}),
      userId: auth.userId,
    };
  }
  await ensurePin(c, ownerEmail, spec.pin);

  // 4. Category, Supplier, Products
  const catId = detUuid(`${slug}:cat:beverages`);
  const cats = await c.restGet(`categories?tenant_id=eq.${tenantId}&deleted_at=is.null&select=id,name`);
  if (!cats.some((cat) => cat.id === catId || cat.name === "General")) {
    await c.rpc("upsert_category", ownerJwt, { p_op_id: detUuid(`${slug}:op:cat`), p_category: { id: catId, name: "General" } });
  }
  const actualCatId = cats[0]?.id ?? catId;

  const supId = detUuid(`${slug}:supplier:main`);
  const existingSuppliers = await c.restGet(`suppliers?tenant_id=eq.${tenantId}&deleted_at=is.null&select=id,name`);
  const supplierId = existingSuppliers[0]?.id ?? supId;
  if (existingSuppliers.length === 0) {
    await c.rpc("upsert_supplier", ownerJwt, { p_id: supplierId, p_name: spec.supplierName, p_contact_name: "Ops Desk" });
  }

  const productIds = {};
  const variantSpecs = [];
  for (const prod of spec.products) {
    const pId = detUuid(`${slug}:prod:${prod.key}`);
    if (Array.isArray(prod.variants) && prod.variants.length > 0) {
      const resolvedVars = prod.variants.map((v) => ({
        ...v,
        id: detUuid(`${slug}:var:${prod.key}:${v.vkey}`),
      }));
      const existingVars = await c.restGet(`product_variants?product_id=eq.${pId}&select=id`);
      const existingIds = new Set(existingVars.map((r) => r.id));
      if (resolvedVars.some((v) => !existingIds.has(v.id))) {
        const def = resolvedVars.find((v) => v.isDefault) ?? resolvedVars[0];
        await c.rpc("upsert_product", ownerJwt, {
          p_op_id: detUuid(`${slug}:op:prod:${prod.key}`),
          p_product: {
            id: pId,
            name: prod.name,
            category_id: actualCatId,
            unit: prod.unit,
            price: def.price,
            track_stock: prod.track,
            variants: resolvedVars.map((v) => ({
              id: v.id,
              name: v.name,
              sku: v.sku,
              price: v.price,
              cost: v.cost,
              reorder_point: v.reorder,
              is_default: Boolean(v.isDefault),
              active: true,
              ...(v.barcode ? { barcode: v.barcode } : {}),
            })),
          },
        });
      }
      const def = resolvedVars.find((v) => v.isDefault) ?? resolvedVars[0];
      productIds[prod.key] = {
        productId: pId,
        variantId: def.id,
        name: prod.name,
        variants: Object.fromEntries(resolvedVars.map((v) => [v.vkey, { variantId: v.id, name: v.name, sku: v.sku, price: v.price }])),
      };
      for (const v of resolvedVars) {
        variantSpecs.push({ key: `${prod.key}:${v.vkey}`, variantId: v.id, prod, v });
      }
    } else {
      const vId = detUuid(`${slug}:var:${prod.key}`);
      const [existingVar] = await c.restGet(`product_variants?id=eq.${vId}&select=id`);
      if (!existingVar) {
        await c.rpc("upsert_product", ownerJwt, {
          p_op_id: detUuid(`${slug}:op:prod:${prod.key}`),
          p_product: {
            id: pId,
            name: prod.name,
            category_id: actualCatId,
            unit: prod.unit,
            price: prod.price,
            track_stock: prod.track,
            variant: {
              id: vId,
              cost: prod.cost,
              reorder_point: prod.reorder,
              ...(prod.barcode ? { barcode: prod.barcode } : {}),
            },
          },
        });
      }
      productIds[prod.key] = { productId: pId, variantId: vId, name: prod.name };
      variantSpecs.push({ key: prod.key, variantId: vId, prod, v: prod });
    }
  }

  // 5. Initial stock in S01 & S02 + W01 bin putaway (only if location stock is empty)
  const existingStock = await c.restGet(`stock_levels?tenant_id=eq.${tenantId}&select=location_id,variant_id,qty_on_hand`);
  const hasStockAt = (locId, vid) => existingStock.some((s) => s.location_id === locId && s.variant_id === vid);

  const openingOps = [];
  const whItems = [];
  for (const entry of variantSpecs) {
    if (!entry.prod.track) continue;
    const vid = entry.variantId;
    const vSpec = entry.v;
    if (vSpec.s1Qty > 0 && !hasStockAt(loc1Id, vid)) {
      openingOps.push({
        op_id: detUuid(`${slug}:op:open:S01:${entry.key}`),
        kind: "post_opening_stock",
        payload: { location_id: loc1Id, variant_id: vid, qty: vSpec.s1Qty, unit_cost: vSpec.cost },
      });
    }
    if (vSpec.s2Qty > 0 && !hasStockAt(loc2Id, vid)) {
      openingOps.push({
        op_id: detUuid(`${slug}:op:open:S02:${entry.key}`),
        kind: "post_opening_stock",
        payload: { location_id: loc2Id, variant_id: vid, qty: vSpec.s2Qty, unit_cost: vSpec.cost },
      });
    }
    if (vSpec.whQty > 0 && !hasStockAt(whId, vid)) {
      whItems.push({ variant_id: vid, qty: vSpec.whQty, unit_cost: vSpec.cost, whQty: vSpec.whQty });
    }
  }

  // Customer
  const custId = detUuid(`${slug}:cust:main`);
  const existingCusts = await c.restGet(`customers?tenant_id=eq.${tenantId}&select=id`);
  if (!existingCusts.some((cRow) => cRow.id === custId)) {
    openingOps.push({
      op_id: detUuid(`${slug}:op:cust:main`),
      kind: "upsert_customer",
      payload: { id: custId, name: spec.customerName, phone: "09171234567" },
    });
  }

  if (openingOps.length > 0) {
    await c.rpc("sync_push", ownerJwt, { p_ops: openingOps });
  }

  if (whItems.length > 0) {
    const grnId = detUuid(`${slug}:grn:init:${whItems.map((i) => i.variant_id).sort().join(",")}`);
    await c.rpc("receive_without_po", ownerJwt, {
      p_id: grnId,
      p_warehouse_id: whId,
      p_supplier_id: supplierId,
      p_items: whItems.map(({ variant_id, qty, unit_cost }) => ({ variant_id, qty, unit_cost })),
      p_notes: "QA seed opening warehouse delivery",
      p_delivery_ref: `QA-INIT-${slug.toUpperCase()}`,
    });
    if (rcvBinId && shelfBinId) {
      for (const item of whItems) {
        await c.rpc("execute_putaway", ownerJwt, {
          p_warehouse_id: whId,
          p_from_bin_id: rcvBinId,
          p_to_bin_id: shelfBinId,
          p_variant_id: item.variant_id,
          p_qty: item.qty,
        });
      }
    }
  }

  // Open PO
  const pos = await c.restGet(`purchase_orders?tenant_id=eq.${tenantId}&select=id`);
  const poId = detUuid(`${slug}:po:init`);
  if (pos.length === 0) {
    const firstProd = spec.products[0];
    await c.rpc("create_po", ownerJwt, {
      p_id: poId,
      p_warehouse_id: whId,
      p_supplier_id: supplierId,
      p_notes: "QA seeded replenishment PO",
      p_items: [{ variant_id: productIds[firstProd.key].variantId, qty: 20, unit_cost: firstProd.cost }],
    });
    await c.rpc("submit_po", ownerJwt, { p_po_id: poId });
  }

  return {
    tenantId,
    slug,
    name: spec.name,
    currency: spec.currency,
    timezone: spec.timezone,
    locations: { S01: loc1Id, S02: loc2Id, W01: whId },
    bins: { RECEIVING: rcvBinId, SHELF: shelfBinId },
    users: usersSummary,
    products: productIds,
    customerId: custId,
    supplierId,
  };
}

export async function seedAllQaTenants() {
  const env = getLocalSupabaseEnv();
  const c = makeClient(env);
  const out = {};
  for (const spec of QA_TENANT_SPECS) {
    out[spec.slug] = await seedTenant(c, env, spec);
  }
  return out;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = await seedAllQaTenants();
  console.log(JSON.stringify(result, null, 2));
}
