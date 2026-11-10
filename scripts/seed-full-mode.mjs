// Provisions a rich Full-mode demo tenant on the LOCAL Supabase stack for manual
// inspection and browser walkthrough across all Full-mode back-office screens.
//
// Usage: node scripts/seed-full-mode.mjs
// Output: Prints login credentials and pre-seeded locations, products, POs, and transfers.

import { execSync } from "node:child_process";
import { randomUUID as uuid } from "node:crypto";

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
  console.error(`Refusing to run: API_URL is not local (${API})`);
  process.exit(2);
}

const slug = `full-${Date.now().toString(36)}`;
const PASSWORD = "Demo-pass1234";

async function call(path, { token = ANON, body, method = "POST", allow = false } = {}) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { apikey: ANON, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  if (res.status >= 300 && !allow) {
    throw new Error(`${method} ${path} -> ${res.status}: ${text}`);
  }
  return { status: res.status, data };
}

const rpc = async (n, t, b = {}) => (await call(`/rest/v1/rpc/${n}`, { token: t, body: b })).data;
const get = async (path, t) => (await call(`/rest/v1/${path}`, { token: t, method: "GET" })).data;
const signIn = async (email) =>
  (await call("/auth/v1/token?grant_type=password", { body: { email, password: PASSWORD } })).data.access_token;

async function createAuthUser(email, username, fullName) {
  const res = await call("/auth/v1/admin/users", {
    method: "POST",
    token: SERVICE,
    body: {
      email,
      password: PASSWORD,
      email_confirm: true,
      user_metadata: { username, full_name: fullName },
    },
  });
  return res.data;
}

console.log("Seeding Full-mode demo tenant...");

// 1. Create owner auth user and provision tenant
const ownerEmail = `owner.${slug}@example.test`;
const ownerUser = await createAuthUser(ownerEmail, "owner", "Demo Owner");

const tenantId = await rpc("provision_tenant", SERVICE, {
  p_name: "Xzacto Mega Market",
  p_slug: slug,
  p_base_currency: "PHP",
  p_owner_user_id: ownerUser.id,
  p_owner_username: "owner",
  p_preset: "all",
  p_timezone: "Asia/Manila",
  p_owner_full_name: "Demo Owner",
});

const owner = await signIn(ownerEmail);

// Ensure full mode in tenant_settings
await rpc("set_tenant_mode", owner, { p_mode: "full" });

// 2. Locations: 2 stores and 2 warehouses
const S1 = uuid();
const S2 = uuid();
const W1 = uuid();
const W2 = uuid();

await rpc("upsert_location", owner, { p_id: S1, p_type: "store", p_code: "S01", p_name: "Central Store" });
await rpc("upsert_location", owner, { p_id: S2, p_type: "store", p_code: "S02", p_name: "Express Branch" });
await rpc("upsert_location", owner, { p_id: W1, p_type: "warehouse", p_code: "W01", p_name: "Main Distribution Hub" });
await rpc("upsert_location", owner, { p_id: W2, p_type: "warehouse", p_code: "W02", p_name: "North Storage Facility" });

// Enable bins on W01 (this creates RECEIVING, STAGING, and A-01-1)
await rpc("enable_warehouse_bins", owner, { p_warehouse_id: W1 });
const allBins = await get(`bins?warehouse_id=eq.${W1}`, owner);
const binA1 = allBins.find((b) => b.code === "A-01-1").id;
const binRcv = allBins.find((b) => b.code === "RECEIVING").id;

const binA2 = uuid();
const binB1 = uuid();
await rpc("upsert_warehouse_bin", owner, { p_warehouse_id: W1, p_id: binA2, p_code: "A-01-2", p_type: "shelf" });
await rpc("upsert_warehouse_bin", owner, { p_warehouse_id: W1, p_id: binB1, p_code: "B-01-1", p_type: "pallet" });

// 3. Suppliers
const sup1 = uuid();
const sup2 = uuid();
await rpc("upsert_supplier", owner, {
  p_id: sup1,
  p_name: "Universal Food Traders",
  p_contact_name: "Juan dela Cruz",
  p_phone: "09171234567",
  p_email: "juan@universal.ph",
});
await rpc("upsert_supplier", owner, {
  p_id: sup2,
  p_name: "Mega Beverage Supply Corp",
  p_contact_name: "Maria Santos",
  p_phone: "09187654321",
  p_email: "orders@megabev.ph",
});

// 4. Products
const rice = { pid: uuid(), vid: uuid() };
const oil = { pid: uuid(), vid: uuid() };
const noodlesPiece = { pid: uuid(), vid: uuid() };
const noodlesPack = { pid: uuid(), vid: uuid() };

await rpc("upsert_product", owner, {
  p_op_id: uuid(),
  p_product: {
    id: rice.pid,
    name: "Sinandomeng Rice 25kg",
    price: 155000,
    unit: "sack",
    variant: { id: rice.vid, sku: "RICE-25KG", cost: 130000, reorder_point: 10 },
    track_stock: true,
  },
});

await rpc("upsert_product", owner, {
  p_op_id: uuid(),
  p_product: {
    id: oil.pid,
    name: "Golden Cooking Oil 1L",
    price: 11000,
    unit: "btl",
    variant: { id: oil.vid, sku: "OIL-1L", cost: 8500, reorder_point: 24 },
    track_stock: true,
  },
});

await rpc("upsert_product", owner, {
  p_op_id: uuid(),
  p_product: {
    id: noodlesPiece.pid,
    name: "Lucky Me Instant Pancit Canton (Single)",
    price: 1800,
    unit: "pc",
    variant: { id: noodlesPiece.vid, sku: "CANTON-PC", cost: 1400, reorder_point: 50 },
    track_stock: true,
  },
});

await rpc("upsert_product", owner, {
  p_op_id: uuid(),
  p_product: {
    id: noodlesPack.pid,
    name: "Lucky Me Instant Pancit Canton (Box of 24)",
    price: 39500,
    unit: "box",
    variant: {
      id: noodlesPack.vid,
      sku: "CANTON-BOX24",
      cost: 33600,
      reorder_point: 5,
      breaks_into_variant_id: noodlesPiece.vid,
      breaks_into_qty: 24,
    },
    track_stock: true,
  },
});

// Custom reorder point on W01 for rice
await rpc("set_location_reorder_point", owner, {
  p_location_id: W1,
  p_variant_id: rice.vid,
  p_reorder_point: 25,
});

// 5. Initial Receipts into Warehouses
await rpc("receive_without_po", owner, {
  p_id: uuid(),
  p_warehouse_id: W1,
  p_supplier_id: sup1,
  p_delivery_ref: "DR-2026-001",
  p_items: [
    { variant_id: rice.vid, qty: 50, unit_cost: 130000 },
    { variant_id: oil.vid, qty: 100, unit_cost: 8500 },
    { variant_id: noodlesPack.vid, qty: 20, unit_cost: 33600 },
  ],
});

// Put away stock in W01 from RECEIVING to A-01-1 and A-01-2
await rpc("execute_putaway", owner, {
  p_warehouse_id: W1,
  p_from_bin_id: binRcv,
  p_to_bin_id: binA1,
  p_variant_id: rice.vid,
  p_qty: 30,
});
await rpc("execute_putaway", owner, {
  p_warehouse_id: W1,
  p_from_bin_id: binRcv,
  p_to_bin_id: binA2,
  p_variant_id: oil.vid,
  p_qty: 60,
});

// Receive into W02
await rpc("receive_without_po", owner, {
  p_id: uuid(),
  p_warehouse_id: W2,
  p_supplier_id: sup1,
  p_delivery_ref: "DR-2026-002",
  p_items: [{ variant_id: rice.vid, qty: 20, unit_cost: 130000 }],
});

// Initial stock in Store 1 via sync_push adjust_stock
await rpc("sync_push", owner, {
  p_ops: [
    { id: uuid(), kind: "adjust_stock", entity_id: rice.vid, payload: { variant_id: rice.vid, counted: 15, reason: "counted", location_id: S1 } },
    { id: uuid(), kind: "adjust_stock", entity_id: oil.vid, payload: { variant_id: oil.vid, counted: 30, reason: "counted", location_id: S1 } },
  ],
});

// Negative stock exception in S02 (via offline sale)
const saleId = uuid();
await rpc("sync_push", owner, {
  p_ops: [
    {
      id: saleId,
      kind: "sale",
      entity_id: saleId,
      payload: {
        id: saleId,
        location_id: S2,
        sold_at: new Date().toISOString(),
        items: [{ variant_id: oil.vid, qty: 3, unit_price: 11000 }],
        payments: [{ method: "cash", amount: 33000, tendered: 33000 }],
      },
    },
  ],
});

// 6. Purchase Orders: Draft & Submitted
const poDraft = uuid();
await rpc("create_po", owner, {
  p_id: poDraft,
  p_warehouse_id: W1,
  p_supplier_id: sup2,
  p_notes: "Weekly restocking order",
  p_items: [{ variant_id: oil.vid, qty: 50, unit_cost: 8500 }],
});

const poOrdered = uuid();
await rpc("create_po", owner, {
  p_id: poOrdered,
  p_warehouse_id: W1,
  p_supplier_id: sup1,
  p_notes: "Bulk rice order for peak season",
  p_items: [{ variant_id: rice.vid, qty: 100, unit_cost: 128000 }],
});
await rpc("submit_po", owner, { p_po_id: poOrdered });

// 7. Users with specific roles
const cashierEmail = `cashier.${slug}@example.test`;
const cashierUser = await createAuthUser(cashierEmail, "cashier1", "Rosa Magtanggol");
await rpc("admin_register_user", SERVICE, {
  p_caller: ownerUser.id,
  p_user: cashierUser.id,
  p_username: "cashier1",
  p_full_name: "Rosa Magtanggol",
  p_role: "cashier",
  p_location: S1,
});

const whEmail = `clerk.${slug}@example.test`;
const whUser = await createAuthUser(whEmail, "whclerk", "Danilo Ramos");
await rpc("admin_register_user", SERVICE, {
  p_caller: ownerUser.id,
  p_user: whUser.id,
  p_username: "whclerk",
  p_full_name: "Danilo Ramos",
  p_role: "warehouse",
  p_location: W1,
});

console.log("\n========================================================");
console.log("Full-Mode Demo Tenant Ready!");
console.log("========================================================");
console.log(`Tenant Slug : ${slug}`);
console.log(`Web App URL : http://localhost:5173/`);
console.log(`Credentials (all use password: ${PASSWORD}):`);
console.log(`  Owner / Superadmin : ${ownerEmail}`);
console.log(`  Cashier (Store 1)  : ${cashierEmail}`);
console.log(`  Warehouse (W01)    : ${whEmail}`);
console.log("Locations:");
console.log("  - W01: Main Distribution Hub (Bins: A-01-1, A-01-2, B-01-1, RECEIVING)");
console.log("  - W02: North Storage Facility (No bins)");
console.log("  - S01: Central Store");
console.log("  - S02: Express Branch (includes negative stock line)");
console.log("========================================================\n");
