// F-13i: two-warehouse scenario against the LOCAL Supabase stack, checked after every step.
// Usage: node scripts/acceptance/f13i-two-warehouses.mjs "$(pwd)"   (needs `supabase start`; leaves a throwaway tenant `f13i-...` behind)
//   PO -> receipt at W1 (bins) -> put-away -> W1 -> W2 transfer (pick, ship, receive) -> W2 -> store -> counts at both.
// Checks after each step: stock_levels per place, bin invariant (sum of bins = warehouse), and the ledger (sum of movements = stock level).
import { execSync } from "node:child_process";
import { randomUUID as uuid } from "node:crypto";

const cwd = process.argv[2];
const env = Object.fromEntries(
  execSync("pnpm exec supabase status -o env", { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] })
    .split(/\r?\n/).map((l) => /^([A-Z_]+)="?(.*?)"?$/.exec(l)).filter(Boolean).map((m) => [m[1], m[2]]),
);
const API = env.API_URL, ANON = env.ANON_KEY, SERVICE = env.SERVICE_ROLE_KEY;
if (!/^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(API)) throw new Error("not local");
const slug = `f13i-${Date.now().toString(36)}`;
const PASSWORD = "F13i-test-pass1";

async function call(path, { token = ANON, body, method = "POST", allow = false } = {}) {
  const res = await fetch(`${API}${path}`, {
    method, headers: { apikey: ANON, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  if (res.status >= 300 && !allow) throw new Error(`${method} ${path} -> ${res.status} ${text}`);
  return { status: res.status, data };
}
const fn = async (n, t, b) => (await call(`/functions/v1/${n}`, { token: t, body: b })).data;
const rpc = async (n, t, b = {}) => (await call(`/rest/v1/rpc/${n}`, { token: t, body: b })).data;
const rpcTry = (n, t, b = {}) => call(`/rest/v1/rpc/${n}`, { token: t, body: b, allow: true });
const get = async (path, t) => (await call(`/rest/v1/${path}`, { token: t, method: "GET" })).data;
const signIn = async (email) => (await call("/auth/v1/token?grant_type=password", { body: { email, password: PASSWORD } })).data.access_token;

let fails = 0, checks = 0;
const log = [];
function expect(label, actual, wanted) {
  checks++;
  const ok = JSON.stringify(actual) === JSON.stringify(wanted);
  if (!ok) fails++;
  log.push(`${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : `  got ${JSON.stringify(actual)} wanted ${JSON.stringify(wanted)}`}`);
}

// ---- setup
const ownerEmail = `owner.${slug}@example.test`;
const prov = await fn("invite_user", SERVICE, {
  email: ownerEmail, username: "owner", full_name: "Owner",
  provision: { name: "F13i Co", slug, base_currency: "PHP", preset: "all", timezone: "Asia/Manila" },
});
await call(`/auth/v1/admin/users/${prov.user_id}`, { method: "PUT", token: SERVICE, body: { password: PASSWORD, email_confirm: true } });
const owner = await signIn(ownerEmail);
const W1 = uuid(), W2 = uuid(), S1 = uuid();
await rpc("upsert_location", owner, { p_id: W1, p_type: "warehouse", p_code: "W1", p_name: "Main warehouse" });
await rpc("upsert_location", owner, { p_id: W2, p_type: "warehouse", p_code: "W2", p_name: "Overflow warehouse" });
await rpc("upsert_location", owner, { p_id: S1, p_type: "store", p_code: "S1", p_name: "Store 1" });
const A = { pid: uuid(), vid: uuid() }, B = { pid: uuid(), vid: uuid() };
for (const [p, name, sku] of [[A, "Rice 25kg", "RICE"], [B, "Cooking oil 1L", "OIL"]]) {
  await rpc("upsert_product", owner, { p_op_id: uuid(), p_product: { id: p.pid, name, price: 1500, unit: "pc", variant: { id: p.vid, sku, cost: 1000 }, track_stock: true } });
}
const sup = uuid();
await rpc("upsert_supplier", owner, { p_id: sup, p_name: "Mega Rice Trading" });
const c1 = await fn("create_user", owner, { username: "clerk1", password: PASSWORD, role: "warehouse", location_id: W1 });
const c2 = await fn("create_user", owner, { username: "clerk2", password: PASSWORD, role: "warehouse", location_id: W2 });
const clerk1 = await signIn(c1.email ?? `clerk1.${slug}@pos.invalid`);
const clerk2 = await signIn(c2.email ?? `clerk2.${slug}@pos.invalid`);
const bins = await rpc("enable_warehouse_bins", owner, { p_warehouse_id: W1 });
const binA = uuid(), binB = uuid();
await rpc("upsert_warehouse_bin", owner, { p_warehouse_id: W1, p_code: "A-01", p_id: binA, p_type: "shelf" });
await rpc("upsert_warehouse_bin", owner, { p_warehouse_id: W1, p_code: "B-02", p_id: binB, p_type: "shelf" });
const allBins = await get(`bins?select=id,code&warehouse_id=eq.${W1}`, owner);
const binRcv = allBins.find((b) => b.code === "RECEIVING").id;

// ---- checks
async function stockOf(place) {
  const rows = await get(`stock_levels?select=variant_id,qty_on_hand&location_id=eq.${place}`, owner);
  const m = {}; for (const r of rows) m[r.variant_id === A.vid ? "A" : "B"] = Number(r.qty_on_hand);
  return { A: m.A ?? 0, B: m.B ?? 0 };
}
async function binsOf() {
  const rows = await get(`bin_stock_levels?select=bin_id,variant_id,qty_on_hand`, owner);
  const code = { [binRcv]: "RCV", [binA]: "A-01", [binB]: "B-02" };
  const out = {};
  for (const r of rows) if (Number(r.qty_on_hand) !== 0) out[`${code[r.bin_id] ?? r.bin_id}:${r.variant_id === A.vid ? "A" : "B"}`] = Number(r.qty_on_hand);
  return out;
}
async function ledgerOk(label) {
  const mv = await get(`stock_movements?select=location_id,variant_id,qty_delta&limit=5000`, owner);
  const sums = {};
  for (const r of mv) sums[`${r.location_id}|${r.variant_id}`] = (sums[`${r.location_id}|${r.variant_id}`] ?? 0) + Number(r.qty_delta);
  const lv = await get(`stock_levels?select=location_id,variant_id,qty_on_hand&limit=5000`, owner);
  const bad = lv.filter((r) => Math.abs((sums[`${r.location_id}|${r.variant_id}`] ?? 0) - Number(r.qty_on_hand)) > 1e-6).length;
  expect(`${label}: every stock level equals the sum of its movements`, bad, 0);
}
async function invariant(label) {
  const rows = await rpc("check_bin_stock_invariant", owner, { p_warehouse_id: W1 });
  expect(`${label}: bins of W1 add up to W1`, rows.filter((r) => !r.is_valid).length, 0);
}
async function step(label, w1, w2, s1, binsWanted) {
  expect(`${label}: W1`, await stockOf(W1), w1);
  expect(`${label}: W2`, await stockOf(W2), w2);
  expect(`${label}: S1`, await stockOf(S1), s1);
  if (binsWanted) expect(`${label}: W1 by bin`, await binsOf(), binsWanted);
  await invariant(label);
  await ledgerOk(label);
}

// 1. purchase order at W1: A 100, B 50; clerk1 receives A 100, B 30, then B 20
const po = uuid();
await rpc("create_po", owner, { p_id: po, p_warehouse_id: W1, p_supplier_id: sup, p_items: [{ variant_id: A.vid, qty: 100, unit_cost: 1000 }, { variant_id: B.vid, qty: 50, unit_cost: 5000 }] });
await rpc("submit_po", owner, { p_po_id: po });
await rpc("receive_po", clerk1, { p_id: uuid(), p_po_id: po, p_items: [{ variant_id: A.vid, qty: 100 }, { variant_id: B.vid, qty: 30 }] });
expect("PO status after a part delivery", (await get(`purchase_orders?select=status&id=eq.${po}`, owner))[0].status, "partly_received");
await step("1 part receipt at W1", { A: 100, B: 30 }, { A: 0, B: 0 }, { A: 0, B: 0 }, { "RCV:A": 100, "RCV:B": 30 });
await rpc("receive_po", clerk1, { p_id: uuid(), p_po_id: po, p_items: [{ variant_id: B.vid, qty: 20 }] });
expect("PO status when everything arrived", (await get(`purchase_orders?select=status&id=eq.${po}`, owner))[0].status, "received");
await step("2 rest of the order", { A: 100, B: 50 }, { A: 0, B: 0 }, { A: 0, B: 0 }, { "RCV:A": 100, "RCV:B": 50 });
const over = await rpcTry("receive_po", clerk1, { p_id: uuid(), p_po_id: po, p_items: [{ variant_id: A.vid, qty: 1 }] });
expect("receiving on a finished order is refused", over.status >= 400, true);

// 3. put-away: A 60 to A-01, B 50 to B-02
await rpc("execute_putaway", clerk1, { p_warehouse_id: W1, p_from_bin_id: binRcv, p_to_bin_id: binA, p_variant_id: A.vid, p_qty: 60 });
await rpc("execute_putaway", clerk1, { p_warehouse_id: W1, p_from_bin_id: binRcv, p_to_bin_id: binB, p_variant_id: B.vid, p_qty: 50 });
await step("3 put-away", { A: 100, B: 50 }, { A: 0, B: 0 }, { A: 0, B: 0 }, { "RCV:A": 40, "A-01:A": 60, "B-02:B": 50 });

// 4. W1 -> W2: A 30, B 10 (bins: pick list first)
const t1 = await rpc("create_transfer", owner, { p_from_location_id: W1, p_to_location_id: W2, p_items: [{ variant_id: A.vid, qty: 30 }, { variant_id: B.vid, qty: 10 }] });
const noPick = await rpcTry("ship_transfer", clerk1, { p_transfer_id: t1 });
expect("shipping from a warehouse with bins needs the pick first (pick_required)", noPick.data?.hint, "pick_required");
const pl = await rpc("generate_pick_list", clerk1, { p_transfer_id: t1 });
const items = await get(`pick_list_items?select=id,variant_id,bin_id,qty_requested&pick_list_id=eq.${pl}`, clerk1);
for (const it of items) await rpc("confirm_pick_item", clerk1, { p_pick_list_id: pl, p_item_id: it.id, p_qty_picked: it.qty_requested });
await rpc("ship_transfer", clerk1, { p_transfer_id: t1 });
await step("4a W1 to W2 shipped (in transit)", { A: 70, B: 40 }, { A: 0, B: 0 }, { A: 0, B: 0 });
await rpc("receive_transfer", clerk2, { p_transfer_id: t1, p_items: [{ variant_id: A.vid, qty_received: 30 }, { variant_id: B.vid, qty_received: 10 }] });
await step("4b W2 received", { A: 70, B: 40 }, { A: 30, B: 10 }, { A: 0, B: 0 });

// 5. W2 -> store S1: A 10 (W2 has no bins, so no pick)
const t2 = await rpc("create_transfer", clerk2, { p_from_location_id: W2, p_to_location_id: S1, p_items: [{ variant_id: A.vid, qty: 10 }] });
await rpc("ship_transfer", clerk2, { p_transfer_id: t2 });
await rpc("receive_transfer", owner, { p_transfer_id: t2, p_items: [{ variant_id: A.vid, qty_received: 10 }] });
await step("5 W2 to store", { A: 70, B: 40 }, { A: 20, B: 10 }, { A: 10, B: 0 });

// 6. counts: W1 bin A-01 (system 30 after the pick) counted 28; W2 whole warehouse counted A 19, B 10
const bin1 = await binsOf();
expect("W1 bin A-01 holds what is left after the pick", bin1["A-01:A"], 30);
const cnt1 = uuid();
await rpc("start_count", clerk1, { p_id: cnt1, p_warehouse_id: W1, p_bin_id: binA });
await rpc("record_count", clerk1, { p_count_id: cnt1, p_items: [{ variant_id: A.vid, qty_counted: 28, bin_id: binA }] });
await step("6a count open (stock not moved yet)", { A: 70, B: 40 }, { A: 20, B: 10 }, { A: 10, B: 0 });
await rpc("close_count", clerk1, { p_count_id: cnt1 });
await step("6b W1 count closed", { A: 68, B: 40 }, { A: 20, B: 10 }, { A: 10, B: 0 }, { "RCV:A": 40, "A-01:A": 28, "B-02:B": 40 });
const cnt2 = uuid();
await rpc("start_count", clerk2, { p_id: cnt2, p_warehouse_id: W2 });
await rpc("record_count", clerk2, { p_count_id: cnt2, p_items: [{ variant_id: A.vid, qty_counted: 19 }, { variant_id: B.vid, qty_counted: 10 }] });
// a delivery lands in W2 while the count is open: the correction must not wipe it
const t3 = await rpc("create_transfer", owner, { p_from_location_id: W1, p_to_location_id: W2, p_items: [{ variant_id: B.vid, qty: 5 }] });
const pl3 = await rpc("generate_pick_list", clerk1, { p_transfer_id: t3 });
for (const it of await get(`pick_list_items?select=id,qty_requested&pick_list_id=eq.${pl3}`, clerk1)) await rpc("confirm_pick_item", clerk1, { p_pick_list_id: pl3, p_item_id: it.id, p_qty_picked: it.qty_requested });
await rpc("ship_transfer", clerk1, { p_transfer_id: t3 });
await rpc("receive_transfer", clerk2, { p_transfer_id: t3, p_items: [{ variant_id: B.vid, qty_received: 5 }] });
await rpc("close_count", clerk2, { p_count_id: cnt2 });
await step("6c W2 count closed with a delivery during it", { A: 68, B: 35 }, { A: 19, B: 15 }, { A: 10, B: 0 }, { "RCV:A": 40, "A-01:A": 28, "B-02:B": 35 });

// 7. who may do what
const x1 = await rpcTry("start_count", clerk2, { p_id: uuid(), p_warehouse_id: W1 });
expect("clerk of W2 cannot count W1", x1.data?.hint, "location_denied");
const x2 = await rpcTry("create_transfer", clerk2, { p_from_location_id: W1, p_to_location_id: W2, p_items: [{ variant_id: A.vid, qty: 1 }] });
expect("clerk of W2 cannot send stock out of W1", x2.status >= 400, true);
const x3 = await rpcTry("receive_po", clerk2, { p_id: uuid(), p_po_id: po, p_items: [{ variant_id: A.vid, qty: 1 }] });
expect("clerk of W2 cannot receive an order of W1", x3.status >= 400, true);
const seen2 = await get("stock_counts?select=id,warehouse_id", clerk2);
expect("clerk of W2 sees only counts of W2", [...new Set(seen2.map((r) => r.warehouse_id))], [W2]);
const big = await rpcTry("create_transfer", owner, { p_from_location_id: W2, p_to_location_id: S1, p_items: [{ variant_id: A.vid, qty: 500 }], p_ship_now: true });
expect("shipping more than W2 holds is refused", big.status >= 400, true);
await step("7 after the refused attempts, nothing moved", { A: 68, B: 35 }, { A: 19, B: 15 }, { A: 10, B: 0 });

console.log(log.join("\n"));
console.log(`\n${checks - fails} of ${checks} checks passed`);
console.log(JSON.stringify({ slug, password: PASSWORD, W1, W2, S1, clerks: [c1.email, c2.email], A: A.vid, B: B.vid }));
process.exit(fails ? 1 : 0);
