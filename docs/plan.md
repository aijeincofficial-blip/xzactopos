# Multi-Tenant POS + Warehouse Platform: Architecture & Execution Plan

Offline-first POS, Inventory and Warehouse system for web and mobile, built on the Supabase free tier. Written so it can be executed phase by phase in Claude Code.

## 1. Summary and Key Decisions

| Topic | Decision |
| --- | --- |
| Tenancy | Shared database, shared schema, `tenant_id` on every row, enforced by Postgres RLS |
| Modules | Per-tenant toggles: **POS**, **Inventory**, **Warehouse** (Inventory is the always-on core; POS and Warehouse are add-ons that each require it) |
| Locations | One `locations` table with `type = store \| warehouse`. Stock is tracked per location, and per bin inside warehouses that enable bins |
| Roles | 4 roles: `superadmin`, `admin`, `warehouse`, `cashier`. Admins get a per-store **position** (manager or supervisor) |
| Client | One React + TypeScript codebase: PWA for web, wrapped with Capacitor for Android/iOS |
| Offline | Local IndexedDB store + outbox queue, idempotent batch push, delta pull |
| Backend logic | Postgres RPC functions first. Edge Functions only where the service role key is required |
| Realtime | Off by default for POS terminals. Polling and on-focus pull instead. Optional for warehouse dashboards |
| Inventory | Append-only stock movement ledger. Stock levels are derived by trigger |

### Assumptions (please confirm)

1. **Superadmin = the business owner of a tenant**, not the platform operator. The platform operator (you) manages tenants through the Supabase dashboard or SQL in v1. A platform-admin UI is a later phase.
2. A cashier is assigned to one store (schema allows many). A warehouse user is assigned to one or more warehouses. An admin can be assigned to many stores with a different position in each.
3. Payments are recorded, not processed (cash, card via external terminal, e-wallet reference). No payment gateway in v1.
4. Local tax and fiscal receipt rules (for example, Philippine BIR requirements) are out of scope and must be checked before real-world use.

### Honest note on the free tier

The Supabase free plan is fine for building, demos and a small pilot, but it is not meant for always-on production. As of the current published limits: 500 MB database, 1 GB file storage, 5 GB egress, 2 active projects, 200 concurrent realtime connections, 2M realtime messages per month, 500K edge function invocations, 50K auth MAU. **Projects pause after 7 days of inactivity**, and there are **no automatic backups**. This design stays inside those limits and has mitigations (section 2), but a paying tenant should move to Pro. Nothing in the architecture changes when you upgrade.

## 2. Free-Tier Budget and Guardrails

| Resource | Free limit | Design response |
| --- | --- | --- |
| Database 500 MB | Hard cap, writes fail when full | Narrow columns, UUID + int types, minimal indexes, daily rollups, archive old data (see below) |
| Egress 5 GB / month | Overage or throttle | Delta sync by `updated_at`, only needed columns, catalog cached locally, reports return aggregates not rows, no product images by default (optional 20 KB WebP thumbnails) |
| Realtime 200 connections / 2M msgs | Shared across all tenants | No realtime on cashier devices. Poll every 60 s when online, plus pull on app focus and after each push |
| Edge Functions 500K / month | Invocations | Business logic lives in Postgres RPC (not counted as edge invocations). Edge Functions only for user creation and invites |
| Storage 1 GB | Files | Receipts are generated on the client. Storage only for optional thumbnails and exported reports |
| Auth 50K MAU | Plenty | Cashiers use synthetic emails so no real email is needed |
| Pause after 7 idle days | Project goes offline | Scheduled keep-alive ping (GitHub Actions cron every 3 days hitting a lightweight RPC), plus an uptime monitor |
| No backups | Data loss risk | Weekly `pg_dump` via GitHub Actions to a private repo artifact or external storage. Document restore steps |
| 2 projects |  | Project 1 = production, Project 2 = staging. Local dev with Supabase CLI |

### Storage budget (rough planning numbers)

One typical sale (header + 3 items + 1 payment + 3 stock movements) is about 1.2 KB of data, roughly 2.5 KB with indexes. That gives about 150K to 200K sales in 500 MB, shared by all tenants. For example, 5 stores at 100 sales/day is 500/day, so roughly 12 months before pressure.

Mitigations built into the plan:

- `daily_sales_summary` and `stock_snapshots_daily` tables (pg\_cron) so reports never scan raw rows.
- Archive job: sales older than N months (default 13) are exported to compressed CSV, then deleted. Summaries stay.
- A `usage_metrics` view and a superadmin warning banner at 70% and 90% of the DB size budget.
- Rule: never store base64 images, big JSON blobs or verbose audit payloads in the database.

### Pilot sizing: 1 tenant, 10 stores, 10 warehouses

Sales per day was not given, so three scenarios are checked against the 150K to 200K sales capacity estimated above. This is an upper bound: warehouse movements, bin moves and put-away tasks share the same 500 MB.

| Sales per store per day | Total sales per day | Days until about 150K to 200K sales |
| --- | --- | --- |
| 50 | 500 | 300 to 400 |
| 100 | 1,000 | 150 to 200 |
| 200 | 2,000 | 75 to 100 |

- **Free plan for build, not for trading.** Ten live stores on the free plan face the 7-day auto-pause and no backups. Use free for development, staging and a 1 to 2 store trial. For real trading, plan on Pro (8 GB database, daily backups, no pausing, per Supabase's published pricing as of November 2026). The architecture is unchanged.
- **Polling cost with 10 stores.** About 30 devices polling every 60 s over a 12-hour day is roughly 21,600 requests. At about 1 KB for an empty delta, that is around 0.65 GB a month, already 13% of the 5 GB egress allowance. Use a 120 s idle poll with backoff when nothing changes, and push immediately only when the outbox has items.
- **Archive early.** Turn on the sales archive job and daily rollups in Phase 6, not Phase 8, if volume is near the 100-per-store scenario.

## 3. System Architecture

```
+---------------------------+      +---------------------------+
|  WEB (PWA, installable)   |      |  MOBILE (Capacitor shell) |
|  React + TS + Vite        |      |  same React codebase      |
|  Service Worker (Workbox) |      |  Android / iOS            |
+-------------+-------------+      +-------------+-------------+
              |                                  |
              +----------------+-----------------+
                               |
                  +------------v-------------+
                  |  Shared packages         |
                  |  core (zod, permissions) |
                  |  sync (outbox, pull)     |
                  |  storage adapter (Dexie) |
                  +------------+-------------+
                               |  HTTPS (batched, gzip)
                               |
+------------------------------v------------------------------+
|                       SUPABASE (free)                        |
|  Auth (JWT + custom claims hook)                             |
|  PostgREST  ->  RPC: sync_push, sync_pull, report_*          |
|  Postgres + RLS (tenant_id + location scope)                 |
|  pg_cron: rollups, snapshots, archive, keep-alive            |
|  Edge Functions: create_user, invite_user (service role)     |
|  Storage: thumbnails, exported reports (optional)            |
|  Realtime: optional, warehouse dashboards only               |
+--------------------------------------------------------------+
```

### Client storage

- Use **Dexie (IndexedDB)** on both web and Capacitor, behind a `LocalStore` interface so a SQLite adapter can replace it later without touching app code.
- Call `navigator.storage.persist()` on startup. Show a sync-status badge (online, pending N, last synced time). Warn if pending operations are older than 24 hours, because mobile WebViews can evict storage under pressure.
- Why one codebase: one team (or one Claude Code session) maintains one UI, one sync engine and one test suite. Native-only features (Bluetooth printer, barcode camera) are Capacitor plugins.

## 4. Multi-Tenancy and Module Toggles

### Tenant onboarding flow

```
[Platform operator creates tenant row]  (provision_tenant)
        |
        v
[First superadmin invited by email]  -->  [Superadmin sets password]
        |
        v
[Setup wizard: business name, base currency, extra currencies,
 tax, timezone, languages]
        |
        v
[Choose modules]  Inventory is the core and is always on
   |-- Inventory only          : stock tracking, no sales
   |-- Inventory + POS         : shops, one or many stores
   |-- Inventory + Warehouse   : distribution, no cashiers
   |-- All three               : retail + distribution
   (ticking POS or Warehouse auto-ticks Inventory and locks it)
        |
        v
[Create locations (stores / warehouses)]
        |
        v
[Create users + assign roles + assign locations]
        |
        v
[Import products and variants (CSV) -> opening stock]
```

### Module rules

| Tenant buys | Behavior |
| --- | --- |
| Inventory only | Products and variants, per-location stock, receiving, adjustments, counts, stock reports. No sales screens |
| Inventory + POS | Sales, shifts, payments. Every sale writes a stock movement and lowers store stock. Products with `track_stock = false` (services, loose items) skip deduction, so simple shops can ignore stock |
| Inventory + Warehouse | Warehouse locations, suppliers, purchase orders, receiving, two-step transfers, discrepancies, full warehouse reports |
| All three | Warehouse ships to stores, stores sell, stock is deducted at every step, with consolidated reporting |

Inventory is the core module and is always on. POS and Warehouse are add-ons that each require it, so a tenant cannot buy POS or Warehouse without Inventory. `tenant_modules` stores the flags and a check constraint (`pos or warehouse implies inventory`) enforces it. The setup wizard auto-ticks and locks Inventory when POS or Warehouse is chosen. Each add-on owns its screens, RPCs and RLS policies, so a missing module never leaves dead UI or open endpoints.

Enforcement happens in three places so toggles cannot be bypassed: UI route guards, RPC functions (`assert_module(tenant, 'warehouse')`), and RLS policies on module-specific tables.

Turning a module off hides it and blocks writes but never deletes data. Turning POS or Warehouse on later reuses the existing products and stock, so no data migration is needed.

## 5. RBAC Design

### Roles

| Role | Scope | Purpose |
| --- | --- | --- |
| `superadmin` | Whole tenant | Owner. Manages settings, modules, locations, users, role and location assignment, all reports, audit log. At least one must always exist per tenant |
| `admin` | Assigned stores, with a position per store | Runs stores. Position decides how much power they have in that store |
| `warehouse` | Assigned warehouses | Receiving, put-away, picking, transfers out, stock adjustments and counts, warehouse reports |
| `cashier` | Assigned store | Sells, takes payments, opens and closes own shift |

### Admin positions (per store assignment)

| Position | Meaning |
| --- | --- |
| `manager` | Full store operations: price and product edits, discount overrides, void/refund approval, stock adjustments, shift close, store reports, cashier management within the store |
| `supervisor` | Floor control: approve voids and refunds, run shifts, view store reports. Cannot change prices, products or settings |

An admin who is manager in Store A and supervisor in Store B is a normal case: permissions are evaluated per store.

### Permission matrix (permission keys live in `packages/core/permissions.ts`)

| Capability | Superadmin | Admin (manager) | Admin (supervisor) | Warehouse | Cashier |
| --- | --- | --- | --- | --- | --- |
| Tenant settings, modules | Yes |  |  |  |  |
| Create users, assign roles and locations | Yes | Cashiers in own stores |  |  |  |
| Create/edit locations | Yes |  |  |  |  |
| Product and price management | Yes | Yes |  | Cost and SKU only |  |
| Make a sale, take payment | Yes | Yes | Yes |  | Yes |
| Discount above threshold | Yes | Yes | With PIN |  |  |
| Void / refund | Yes | Yes | Yes |  | Own sale, same shift, below limit |
| Open/close shift | Yes | Yes | Yes |  | Own shift |
| Stock adjustment (store) | Yes | Yes |  |  |  |
| Purchase orders, receiving | Yes |  |  | Yes |  |
| Transfers (create / ship / receive) | Yes | Receive at own store |  | Yes |  |
| Stock count | Yes | Own store |  | Yes |  |
| Store reports | Yes | Assigned stores | Assigned stores |  | Own shift summary |
| Warehouse reports | Yes |  |  | Assigned warehouses |  |
| Audit log | Yes | Own stores |  |  |  |

### Implementation

- `auth.users` gets a custom access token hook that adds `tenant_id` and `role` to the JWT. Store/warehouse scope is **not** put in the JWT (it can be large and goes stale). It is looked up through a `STABLE SECURITY DEFINER` function `has_location_access(location_id, min_position)` wrapped as `(select ...)` in policies for planner caching.
- UI hides what the user cannot do. The database is the real gate: every RPC checks role, location and module.
- Role or assignment changes take effect at the next token refresh (default 1 hour) for JWT claims and immediately for location lookups. Deactivated users are blocked at the RPC level on every call.
- Manager override flow offline: supervisor or manager enters a PIN on the cashier device. The override is recorded with `approved_by` and validated on sync.

## 6. Data Model

All tables have `tenant_id uuid not null`, `created_at`, `updated_at` (server-set by trigger), and `deleted_at` (soft delete, required for delta sync). IDs are UUIDv7 generated on the client so offline records never collide.

### Core

```
tenants(id, name, slug, currency, timezone, tax_mode, plan, status)
tenant_modules(tenant_id, module, enabled)            -- pos | inventory | warehouse
profiles(user_id, tenant_id, full_name, role, pin_hash, active)
locations(id, tenant_id, type[store|warehouse], code, name, address, active)
location_access(user_id, location_id, position[manager|supervisor|null])
devices(id, tenant_id, location_id, name, last_seen_at)
audit_log(id, tenant_id, user_id, action, entity, entity_id, meta_small, at)
```

### Catalog

```
categories(id, tenant_id, name, parent_id)
products(id, tenant_id, name, category_id, unit, tax_rate, track_stock bool, active)
product_options(id, product_id, name, position)           -- e.g. Size, Color
product_option_values(id, option_id, value, position)     -- e.g. S, M, L / Red
product_variants(id, tenant_id, product_id, sku, barcode, option_value_ids uuid[],
                 cost, reorder_point, active)             -- every product has 1+ variants
variant_prices(variant_id, currency, price)               -- base currency row required
product_translations(product_id, locale, name, description)
suppliers(id, tenant_id, name, contact)
customers(id, tenant_id, name, phone, locale)             -- optional, phase 6
```

### Sales (POS module)

```
shifts(id, tenant_id, location_id, device_id, cashier_id, opened_at, closed_at,
       opening_cash, closing_cash, expected_cash)
sales(id, tenant_id, location_id, shift_id, cashier_id, device_id,
      local_no, sale_no, status[completed|voided|refunded], subtotal, discount,
      tax, total, sold_at, synced_at, client_op_id)
sale_items(id, sale_id, variant_id, qty, unit_price, discount, tax, line_total, unit_cost)
payments(id, sale_id, method, amount, reference)
```

### Inventory and Warehouse

```
stock_movements(id, tenant_id, location_id, variant_id, qty_delta, type,
                ref_type, ref_id, unit_cost, occurred_at, created_by)
   -- type: receipt | sale | sale_return | transfer_out | transfer_in |
   --       adjustment | count_correction | damage | supplier_return | opening
stock_levels(tenant_id, location_id, variant_id, qty_on_hand, avg_cost, updated_at)
   -- maintained by trigger on stock_movements, never written by clients
purchase_orders(id, tenant_id, warehouse_id, supplier_id, status, expected_at)
po_items(id, po_id, variant_id, qty_ordered, qty_received, unit_cost)
goods_receipts(id, tenant_id, location_id, po_id, received_by, received_at)
goods_receipt_items(id, grn_id, variant_id, qty, unit_cost)
transfers(id, tenant_id, from_location, to_location, status[draft|shipped|received|cancelled],
          shipped_at, received_at)
transfer_items(id, transfer_id, variant_id, qty_shipped, qty_received)
stock_counts(id, tenant_id, location_id, status, started_at, closed_at)
stock_count_items(id, count_id, variant_id, qty_system, qty_counted)
```

### Reporting and sync support

```
daily_sales_summary(tenant_id, location_id, day, gross, discount, tax, net, txn_count)
stock_snapshots_daily(tenant_id, location_id, variant_id, day, qty, value)
processed_ops(client_op_id pk, tenant_id, device_id, processed_at, result)
sync_cursors(device_id, table_name, last_pulled_at)    -- optional, can live on client
```

### Inventory rules

- Stock is **never** edited directly. Every change is an append-only movement. `stock_levels` is derived.
- Offline sales can push stock below zero. The server accepts it (the sale already happened), flags the product in a `negative_stock` exception report, and a warehouse or admin user reconciles it.
- Transfers are two-step (ship, then receive). While shipped, stock is "in transit": it has left the source and has not arrived. A receive with a different quantity creates a discrepancy record.
- Weighted average cost is updated on receipt. `sale_items.unit_cost` snapshots cost at sale time so margin reports stay correct.

### Warehouse structure: zones, bins and shelves

Bins are opt-in per warehouse (`locations.bins_enabled`). A warehouse without bins stays location-level, so small tenants avoid the extra rows.

```
warehouse_zones(id, tenant_id, warehouse_id, code, name,
                type[receiving|storage|picking|staging|quarantine|damaged])
bins(id, tenant_id, warehouse_id, zone_id, code, aisle, rack, shelf, position,
     type[pallet|shelf|floor], max_qty, active)       -- bins.code is the barcode label
bin_stock_levels(tenant_id, bin_id, variant_id, qty_on_hand)   -- derived by trigger
stock_movements + bin_id (nullable)                   -- the ledger gains a bin
putaway_rules(tenant_id, warehouse_id, variant_id | category_id,
              preferred_zone_id, preferred_bin_id)
putaway_tasks(id, tenant_id, warehouse_id, grn_id, variant_id, qty,
              from_bin_id, to_bin_id, status, assigned_to)
pick_lists(id, tenant_id, warehouse_id, transfer_id, status, assigned_to)
pick_list_items(id, pick_list_id, variant_id, bin_id, qty_requested, qty_picked, short_reason)
```

- **Invariant:** for a bins-enabled warehouse, the sum of `bin_stock_levels` per variant equals `stock_levels` for that warehouse. A trigger and a nightly check enforce it.
- **Receiving:** every receipt lands in the warehouse's default RECEIVING bin first.
- **Bin moves:** put-away and picking move stock between bins with a pair of `bin_move` movements. They net to zero at warehouse level, so `stock_levels` is untouched.
- **Shipping:** a transfer from a bins-enabled warehouse needs a completed pick list. Picked items move to a STAGING bin, and the ship step writes `transfer_out` from STAGING.
- **Scanning offline:** tasks are created online and cached on the device. Scan confirmations (bin, item, qty) queue in the outbox. Two pickers draining the same bin can push it negative, which appears in the negative stock exception report, same as stores.
- **Labels:** bin labels (QR or Code 128) are generated on the client as PDF, with nothing stored.
- **Counts:** cycle counts can be done per bin.
- **Budget:** bin moves roughly double movement rows for received stock. Enable bins only on warehouses that need them.

### Product variants

- The sellable and stockable unit is the **variant**. A simple product has exactly one default variant, so no code path branches on "has variants".
- Up to 3 option sets per product in v1 (for example Size, Color, Material). A matrix generator creates the variants. Each variant has its own SKU, barcode, cost and reorder point.
- Every transactional table references `variant_id`. Reports roll variants up to products.
- Scanning looks up the variant by barcode in a local Dexie index, so it works offline.
- Storage impact: stock rows multiply by variants. 2,000 products with 4 variants each across 6 locations is about 48,000 `stock_levels` rows, a few MB to roughly 10 MB with indexes. Archive inactive variants rather than deleting them.

### Currency

| Rule | Detail |
| --- | --- |
| Base currency | Each tenant has one base currency. Stock cost, valuation and consolidated reports are always in base |
| Enabled currencies | `tenant_currencies(code, rate_to_base, rate_date, rounding)`. Rates are set manually by admins (no external rate API, which saves egress and works offline) |
| Money format | Integer minor units plus a currency code. The exponent comes from a `currencies` table (JPY 0, USD 2, KWD 3) |
| Sales | `sales.currency` and `sales.fx_rate` snapshot the rate used. Totals are stored in sale currency and in base (`total_base`) |
| Payments | Each payment has `currency`, `amount` and `amount_base`, so a customer can pay in one currency and receive change in another |
| Reports | Shown in base, with an optional display currency using the stored rate at transaction time, never today's rate |
| Offline | Rates are cached on the device. A sale keeps the rate it was made with |

### Language

- UI text uses i18next with keys per feature (not sentences). English first, plus Tagalog (locale code fil) in v1. More languages are added as JSON files.
- Locale files are bundled with the app so they work offline.
- Tenant default locale plus a per-user locale. Dates, numbers and currency use `Intl` formatting.
- User-entered content (product and category names) uses `*_translations` tables with fallback to the tenant default. Clients download only the tenant's active locales to save egress.
- Receipts print in the tenant's receipt language, or the customer's if set.
- CSS uses logical properties from day one, so right-to-left languages are cheap to add later.

## 7. Offline-First Sync Design

### Principles

1. **Transactions are append-only and conflict-free.** Sales, movements and receipts are created once with a client-generated ID. They never conflict.
2. **Master data is last-write-wins by server `updated_at`.** Catalog, prices and users are only edited online by privileged roles.
3. **Every push is idempotent** via `client_op_id` in `processed_ops`. Retrying is always safe.
4. **The server is the authority** for official numbers (`sale_no`), stock levels and permissions.

### Sync engine flow

```
          APP ACTION (e.g., complete sale)
                     |
                     v
   +------------------------------------------+
   | 1. Write to local tables (sale, items)   |
   | 2. Write op to OUTBOX (status=pending)   |
   | 3. Print/show receipt with local_no      |
   +--------------------+---------------------+
                        |
         (online? timer 15s / focus / manual)
                        v
   +------------------------------------------+
   | PUSH: send up to 50 ops -> rpc sync_push |
   +--------------------+---------------------+
                        v
        +-------------- server --------------+
        | for each op, in order:             |
        |  - skip if client_op_id processed  |
        |  - check JWT, role, location, module|
        |  - apply (insert sale, movements)  |
        |  - assign sale_no                  |
        |  - record in processed_ops         |
        +-------------------+----------------+
                            v
   +------------------------------------------+
   | Response: per-op result                  |
   |  ok -> mark outbox done, store sale_no   |
   |  rejected(permanent) -> mark failed,     |
   |     surface in "Sync issues" screen      |
   |  error(transient) -> retry w/ backoff    |
   +--------------------+---------------------+
                        v
   +------------------------------------------+
   | PULL: rpc sync_pull(cursors) per table   |
   |  rows with updated_at > cursor, scoped   |
   |  to tenant + user's locations, paginated |
   |  includes tombstones (deleted_at)        |
   +------------------------------------------+
```

### Offline POS sale flow

```
Cashier logs in (online once; PIN unlock afterwards)
   |
   v
Open shift (opening cash)  -- stored locally, pushed when online
   |
   v
Scan/search product  -->  local catalog (IndexedDB)
   |
   v
Cart -> discounts (permission checked locally from cached role)
   |
   v
Payment (cash / card ref / e-wallet ref)
   |
   v
Commit local transaction: sale + items + payments + stock_movements(local) + outbox op
   |
   v
Receipt (local_no = DEVICECODE-YYYYMMDD-0001)
   |
   +--> online?  yes -> push immediately
   |             no  -> queued, badge shows pending count
   v
Close shift: counted cash vs expected -> variance saved
```

### Offline authentication

- First login needs the network. The device then caches the profile, role, assigned locations, a PBKDF2-hashed PIN, and the Supabase refresh token in secure storage (Capacitor secure storage on mobile, WebCrypto-wrapped on web).
- Offline unlock uses the PIN. An offline session expires after a configurable window (default 7 days) and then requires network login.
- Revoked users are blocked on the next sync (the server rejects their ops with a permission error, which appears in Sync Issues).

### Handling known edge cases

| Case | Handling |
| --- | --- |
| Price changed while a device was offline | Sale keeps the price it was made at. Server stores it as is and flags a price mismatch if it differs from the current price by more than a threshold |
| Product deleted while offline | Soft-deleted rows still sync. Sale is accepted, product flagged inactive |
| Clock skew on device | `occurred_at` from the device is stored, but ordering and cursors use server time. Large skew (over 24 h) is flagged |
| Two devices sell the last item | Both accepted, stock goes negative, exception report raised |
| Same op sent twice | `processed_ops` returns the stored result |
| Long offline period (over 30 days) | Full resync via snapshot pull in pages before allowing new sales |

## 8. Warehouse Flows

### Purchase order and receiving

```
[Warehouse/Superadmin creates PO]  (draft -> sent)
            |
            v
   Goods arrive at warehouse
            |
            v
[Create goods receipt against PO]
   - scan items, enter qty, cost
   - partial receipt allowed (PO stays open)
            |
            v
[Server: insert movements (type=receipt), update avg cost,
         update po_items.qty_received, close PO if complete]
            |
            v
   Variance (ordered vs received) feeds the Receiving report
```

### Warehouse to store transfer

```
Store Admin or Warehouse creates transfer request (draft)
            |
            v
Warehouse picks items --> [SHIP]
   movements: transfer_out (source)   | status=shipped (in transit)
            |
            v
Store receives --> [RECEIVE] enters counted qty
   movements: transfer_in (destination)
            |
   qty differs? --yes--> discrepancy record + notification on dashboard
            |no
            v
        status=received
```

Ship and receive can both be done offline (queued). Receive must reference an existing shipped transfer, so it syncs after the ship op.

### Stock count

```
Start count (snapshot qty_system) -> count by scan -> review variances
   -> approver (warehouse lead / manager) confirms
   -> movements (type=count_correction) -> status=closed
```

### Put-away and picking (bins-enabled warehouses)

```
PUT-AWAY
Goods receipt posted -> stock lands in RECEIVING bin
        |
        v
System creates put-away tasks
(suggested bin from putaway_rules, else nearest bin with space)
        |
        v
Worker scans item + RECEIVING bin, then scans destination bin
(accept suggestion, or override with a reason)
        |
        v
bin_move out of RECEIVING / into storage bin
(warehouse total unchanged)  ->  task done

PICKING
Transfer request approved (store order)
        |
        v
Pick list generated: bins allocated, lines sorted by
aisle -> rack -> shelf walking route
        |
        v
Picker scans bin, scans item, enters qty
(short pick allowed with a reason)
        |
        v
Pick list complete -> items moved to STAGING bin
        |
        v
Ship: transfer_out from STAGING, transfer status = shipped
```

## 9. Warehouse Reports (detailed)

All reports run as server-side RPCs or views returning aggregates, with date range, location and category filters, pagination, and CSV export. Heavy ones read from `stock_snapshots_daily` and `daily_sales_summary`.

| # | Report | Content |
| --- | --- | --- |
| 1 | Stock on hand and valuation | Qty, avg cost, value by warehouse, category, product |
| 2 | Stock card (ledger) | Every movement for a product with running balance |
| 3 | Low stock and reorder | Below reorder point, suggested quantity, days of cover |
| 4 | Receiving report | GRNs by supplier and date, ordered vs received, cost variance |
| 5 | Purchase order status | Open, partial, overdue POs, supplier lead time |
| 6 | Transfer report | Shipped, in transit, received, aging of in-transit, discrepancies |
| 7 | Adjustments and shrinkage | Adjustments and damage by reason, user and value |
| 8 | Cycle count variance | System vs counted, value of variance, repeat offenders |
| 9 | Slow-moving and dead stock | No movement in N days, stock value tied up |
| 10 | Inventory turnover and ABC | Turnover ratio, ABC classification by value and velocity |
| 11 | Negative stock exceptions | Products driven negative by offline sales, awaiting reconciliation |
| 12 | Supplier performance | Fill rate, on-time rate, cost trend |
| 13 | Store replenishment | Store stock vs warehouse stock, suggested transfers |
| 14 | Daily activity log | In/out per day, by user |

Bin-level reports, available when a warehouse has bins enabled:

- **15. Bin stock and utilization:** qty and fill percent per bin, empty and overfull bins, by zone.
- **16. Put-away aging:** received stock still sitting in RECEIVING, by age and worker.
- **17. Pick performance:** lines picked per hour, short picks and reasons, pick accuracy by worker.
- **18. Bin movement history:** every bin move for a variant or bin with the user and time.

Optional later: lot and expiry tracking (needs a `lot_id` on movements and levels).

## 10. Security and RLS Strategy

- RLS enabled on **every** table with no exceptions. A CI test fails the build if any table in `public` lacks RLS.
- Base policy: `tenant_id = (auth.jwt() ->> 'tenant_id')::uuid`.
- Location-scoped tables add `has_location_access(location_id)`. Superadmin passes for all tenant locations.
- Clients cannot write `stock_levels`, `processed_ops`, `audit_log` or summaries. They have no insert policy at all.
- Writes from the apps go through RPCs (`SECURITY DEFINER`, fixed `search_path`, explicit checks inside). Direct table writes are allowed only for simple master-data edits by authorized roles.
- The service role key lives only in Edge Functions and CI secrets. Never in the client bundle.
- Index every policy column (`tenant_id`, `location_id`) and use `(select auth.jwt())` patterns for performance.
- pgTAP tests prove tenant isolation: tenant A can never read or write tenant B, per role, per table.
- Audit log records role changes, voids, refunds, price changes, adjustments, and overrides (small payloads only).

## 11. Repository and Conventions

```
pos-platform/
  CLAUDE.md                     # rules for Claude Code (section 13)
  docs/                         # this plan, ADRs, runbooks
  apps/
    client/                     # Vite + React + TS PWA, Capacitor config
      src/features/{pos,inventory,warehouse,admin,reports,auth}
      src/db/                   # Dexie schema, LocalStore adapter
  packages/
    core/                       # zod schemas, permission keys, money utils
    sync/                       # outbox, push, pull, backoff, tests
  supabase/
    migrations/                 # numbered SQL
    functions/                  # create_user, invite_user
    tests/                      # pgTAP RLS and RPC tests
    seed.sql
  .github/workflows/            # ci, keepalive, backup
```

**Stack:** React, TypeScript, Vite, vite-plugin-pwa, TanStack Query and Router, Dexie, Zod, Tailwind with shadcn/ui, Capacitor, Vitest, Playwright, Supabase CLI, pgTAP.

**Conventions:** money stored as integer minor units (never floats), UUIDv7 for IDs, all timestamps in UTC, migrations are forward-only and numbered, generated DB types committed, every feature ships with tests.

## 12. Implementation Roadmap

Each phase ends with acceptance criteria. Do not start the next phase until the current one passes.

### Phase 0: Foundation

- Monorepo, Supabase CLI local stack, CI (lint, typecheck, test, pgTAP), env handling, `CLAUDE.md`, i18next scaffolding (English first), money utilities (integer minor units, per-currency exponent).
- **Done when:** `pnpm dev` runs the client against local Supabase, CI is green, and a test formats money correctly in 3 currencies and 2 locales.

### Phase 1: Tenancy, Auth, RBAC

- Tables: tenants, tenant\_modules, profiles, locations, location\_access. Custom access token hook. RLS helpers.
- Edge Functions: `create_user` (synthetic email for cashiers), `invite_user`.
- Admin UI: users, roles, location assignment, module toggles, setup wizard.
- **Done when:** pgTAP proves cross-tenant isolation for every role; superadmin can create a cashier and assign a store; admin with two stores and different positions sees correct permissions in each.

### Phase 2: Catalog and Local Store

- Categories, products with variants (option sets, SKU and barcode per variant, matrix generator), per-currency prices, product translations, CSV import. Dexie schema, `LocalStore` interface, `sync_pull` for master data, sync status badge.
- **Done when:** a device loads the catalog, goes offline, and still searches and scans variants by barcode.

### Phase 3: POS Core (offline)

- Shifts, cart, discounts, payments, receipt, local numbering, outbox, `sync_push` for sales, idempotency, Sync Issues screen, PIN unlock.
- **Done when:** Playwright test makes 20 sales offline, reconnects, and the server has exactly 20 sales with correct totals and no duplicates, including after a forced mid-push failure and retry.

### Phase 4: Inventory

- Movement ledger, trigger-maintained levels, sale deduction, adjustments, store stock screen, negative stock handling, avg cost.
- **Done when:** stock equals the sum of movements in a property test; POS-only tenants record no movements.

### Phase 5: Warehouse

- Warehouse locations, suppliers, POs, goods receipts, transfers (ship/receive/discrepancy), stock counts, warehouse role UI.
- **Done when:** end-to-end PO to receipt to transfer to store receipt works, partially offline, with correct stock at every step.

### Phase 5b: Warehouse bins, put-away and picking

- Zones, bins and bin label PDFs (QR or Code 128), `bins_enabled` per warehouse, default RECEIVING and STAGING bins, `bin_stock_levels` with the sum-equals-warehouse invariant, put-away tasks and rules, pick lists with walking-route ordering, bin-level counts, bin reports 15 to 18, offline scan flows.
- **Done when:** pgTAP proves bin stock sums to warehouse stock after receipts, put-aways, picks and ships, and an end-to-end test runs receipt, put-away, pick, ship and store receive with correct stock at every step.

### Phase 6: Reports and Rollups

- `daily_sales_summary`, `stock_snapshots_daily`, all 14 warehouse reports, store reports, CSV export, usage meter.
- **Done when:** reports match raw-data checks on a seeded dataset, and each report responds within 2 seconds on 100K movements.

### Phase 7: Mobile and Hardware

- Phone camera scanning: BarcodeDetector on the web where available, a Capacitor ML Kit barcode plugin on mobile, with a continuous-scan mode.
- Portable scanners: support HID keyboard mode first (the scanner types the code and Enter, detected as a fast keystroke burst), which works on web and mobile with no plugin. Add BLE or SPP support through a Capacitor plugin only if your scanner models need it.
- Receipt printing: Bluetooth ESC/POS thermal printers (58 or 80 mm) through a Capacitor plugin, with browser print or PDF as a fallback. Web Bluetooth is not available on iOS Safari, so iOS printing needs the native app. Printer models are not chosen yet, so receipts go through a printer-agnostic ReceiptPrinter interface: browser print or PDF first, ESC/POS adapters added once models are known.
- Android and iOS builds, storage-persistence checks.

### Phase 8: Free-Tier Operations

- Keep-alive workflow, weekly backup workflow, archive job, storage and egress monitoring, restore runbook, load test against free limits.

### Phase 9 (later): Platform admin UI, customers and loyalty, lot/expiry, multi-currency, upgrade runbook to Pro.

## 13. Claude Code Execution Guide

### Suggested CLAUDE.md contents

```
# Project rules
- Read docs/plan.md before starting a phase. Work one phase at a time.
- Never write directly to stock_levels. Stock changes = stock_movements only.
- Money is integer minor units. IDs are UUIDv7 generated on the client.
- Every new table: tenant_id, timestamps, deleted_at, RLS policies, pgTAP test.
- Business logic goes in Postgres RPC, not Edge Functions, unless service role is required.
- Never add Realtime subscriptions to POS screens.
- Keep payloads small: select explicit columns, paginate, delta-sync.
- Never put the service role key in client code.
- Run `pnpm check` (lint, types, tests, pgTAP) before declaring a task done.
- Commit per task, update docs/handoff.md, then /clear before the next unrelated task.
```

### How to drive each phase

1. Ask Claude Code to **plan first** for the phase (files to create, migrations, tests) and review it.
2. Build **migrations and pgTAP tests before UI**.
3. Implement in small tasks, one commit each. Run `pnpm check` after each.
4. At phase end, ask for a written acceptance report against the criteria above.

### Example kickoff prompt (Phase 1)

> Read docs/plan.md sections 4, 5, 6 and 10. Implement Phase 1. First output a task list with the migrations, RLS helpers, pgTAP tests and Edge Functions you will write. After I approve, implement migrations and tests first, then the Edge Functions, then the admin UI.

## 14. Risks and Open Questions

| Risk | Mitigation |
| --- | --- |
| Free project pauses or hits 500 MB | Keep-alive, usage meter, archive job, clear upgrade path to Pro |
| No automated backups on free | Weekly pg\_dump workflow and tested restore runbook |
| IndexedDB eviction on mobile | Persist request, frequent sync, pending-age warning, SQLite adapter planned behind `LocalStore` |
| Shared free quotas across tenants | Treat free tier as pilot capacity. Add per-tenant usage tracking early |
| Negative stock from offline sales | Accepted by design, reported, reconciled |
| Receipt and tax compliance | Out of scope until local rules are confirmed |

**Decisions so far, and what is still open:**

1. **Modules (decided):** Inventory is the core. POS and Warehouse each require it. See section 4.
2. **Variants (decided):** yes in v1. The variant is the stockable unit. See section 6.
3. **Currency and language (decided):** multi-currency from v1. Languages: English and Tagalog. See section 6.
4. **Scanners (decided):** phone camera plus portable scanners. HID keyboard mode first. See Phase 7.
5. **Pilot scale (decided, partly):** 1 tenant, 10 stores, 10 warehouses. Sales per day is unknown, so section 2 sizes three scenarios. Plan on Pro for real trading.
6. **Warehouse depth (decided):** zones, bins and shelves, put-away and pick lists, opt-in per warehouse. See section 6, section 8 and Phase 5b.
7. **Printers (open, not blocking):** models unknown. Receipts use a printer-agnostic interface with browser print or PDF first.
8. **Superadmin (assumed, proceeding):** tenant owner, with a separate platform operator in `platform_admins` (section 15). Say so if you want a platform-operator screen in v1.
9. **Sales per day (open):** the expected sales per store per day will refine the free-tier and Pro sizing.

## 15. Multi-Tenant Readiness (Tenant N, not just Tenant 1)

The schema is already tenant-scoped; these rules stop the first customer from becoming a hard-coded special case, so tenant 2 is a configuration job, not a rewrite.

| Area | Rule | How it is proven |
| --- | --- | --- |
| Uniqueness | Every business key is unique per tenant: `unique (tenant_id, sku)`, `(tenant_id, barcode)`, `(tenant_id, location.code)`. Never global | Seed two tenants with the same SKUs and usernames |
| Login | Tenant slug at login or in the URL (`/t/<slug>`). Cashier synthetic emails include the slug (`maria.<slug>@pos.invalid`) so usernames can repeat across tenants | Playwright login test on both tenants |
| Config in data | Currency, tax mode, timezone, receipt header/footer, numbering format, offline-session window live in `tenant_settings`. No tenant names or rates in code | Grep rule in CI for hard-coded tenant values |
| Entitlements | `tenant_modules` (POS, Inventory, Warehouse) plus `tenant_limits` (max locations, users, devices, products). Every RPC calls `assert_module` and `assert_limit` | pgTAP: module off means RPC refused |
| Numbering | `sale_no` and PO numbers come from a counter per (tenant, location), never a global sequence. Offline `local_no` carries the device code | Two tenants selling in parallel produce independent sequences |
| Platform operator | Separate `platform_admins` table, not a tenant role. `provision_tenant(name, slug, owner_email, preset)` creates tenant, modules, settings and the first superadmin invite in one transaction, callable only with the service role | Provisioning test creates a working tenant from one call |
| Tenant status | `active`, `suspended`, `archived`. Suspended tenants are refused at login and at `sync_push` with a clear message, but can still export | pgTAP and client test |
| Shared free quota | `tenant_usage_daily` counts rows written, sales, sync calls and DB size estimate per tenant. Soft caps and a max batch size on `sync_push` stop one tenant from starving the others | Load test with one noisy tenant |
| Device data | Local database name includes `tenant_id` and `user_id`. A device is bound to one tenant. Logout or tenant switch wipes or isolates local data | Client test: switch tenant, no leaked rows |
| Offboarding | `export_tenant(tenant_id)` produces CSVs. Deleting a tenant cascades by `tenant_id` | Export, delete, verify zero rows |
| CI guard | Build fails if any `public` table lacks `tenant_id`, RLS, or a tenant-prefixed unique index where needed | Migration lint script |

### Pricing and scale presets map to entitlements

Presets (Micro, Retail, Distributor, Custom) only pre-tick `tenant_modules` and `tenant_limits`. A tenant can later switch module sets without a data migration, because stock and sales data are separate from the module flags.

## 16. Usage-Limit-Optimized Execution (Claude Pro, 5-hour and weekly)

The goal is the most shipped, tested code per unit of usage, not more usage: Pro has a rolling 5-hour session limit and a weekly limit, shared by claude.ai chats and Claude Code, and Anthropic does not publish either as a prompt count ([source](https://hashnode.com/blog/claude-code-usage-limits), as of November 6, 2026). So this plan cuts wasted context, sizes work into task cards, and measures the real cost with `/usage` before committing to a schedule.

### 16.1 Habits that stretch the limit

| Habit | Why it saves usage | In this project |
| --- | --- | --- |
| One task card per session slice | No re-exploring the repo. Files, tests and "do not touch" are given up front | Cards live in `docs/tasks/`, template below |
| Split the spec into small files | Claude loads only the section it needs, not the whole plan | `docs/spec/01-tenancy.md`, `02-rbac.md`, `03-data-model.md`, `04-sync.md`, `05-warehouse.md`, `06-reports.md` |
| Keep `CLAUDE.md` under 200 lines | It is read every session. Long workflows go into skills, which load only when used | Rules from section 13 only |
| `/clear` between unrelated cards, `/compact` mid-card | Stale history is re-billed on every message | Run /clear before every unrelated task. State lives in the card and docs/handoff.md |
| Sonnet by default, Opus for hard parts only | Opus costs more of the pool. Switching models does not help once the session or weekly limit is hit | Opus: RLS policies, sync engine, money and stock math. Sonnet: UI, CRUD, tests, docs |
| Plan mode, then build | A short approved plan avoids rewrites | Plan first on every L-size card |
| Generate, don't hand-write | A script that emits repetitive code costs tokens once, then runs free | Generators: types from DB, zod from types, CRUD screens from a table config, seed data, RLS test stubs |
| Tests as the oracle | Short pass/fail output replaces long manual review | Dot reporters; hooks that trim noisy logs |
| No agent teams or parallel subagents | Anthropic says agent teams use about 7x the tokens of one session | Sequential cards only |
| Back-to-back cards | The prompt cache expires when idle, so the first message after a break costs more | Start a window only when you can run 2 to 3 cards |
| Keep chat out of the pool | claude.ai chats draw from the same limit | Do planning in the doc, not long side chats |

### 16.2 Using the two clocks

- **5-hour window** (rolling, starts at your first message): open it with the highest-value card, run cards back-to-back, and stop at about 85% (the "used 85%" warning). Finish the card, commit, write a 5-line handoff in `docs/handoff.md`.
- **Weekly limit** (fixed reset time shown in `/usage`, independent of the 5-hour reset): spend Opus-heavy design and RLS early in the week, leave tests, docs and UI polish for the end.
- **Calibrate first.** After the first 3 cards, record the session % and weekly % each used in `docs/usage-log.md`. Cap any card at roughly one third of a session, split it if it will not fit.
- **If still blocked:** wait for the reset (auto-continue is available through `/rate-limit-options` on recent Claude Code versions), buy usage credits, or move up a plan. Move routine cards (settings pages, simple CRUD) to other tools only if needed.

### 16.3 Task card template

```markdown
# T-014 Cashier offline sale commit
Size: M   Model: Sonnet   Depends on: T-011, T-012
Spec: docs/spec/04-sync.md (section: Offline POS sale flow)
Files to create/edit: packages/sync/outbox.ts, apps/client/src/features/pos/commitSale.ts
Do not touch: supabase/migrations/*, packages/core/permissions.ts
Acceptance (must pass): pnpm test sync/outbox; Playwright pos-offline-20-sales
Done = commit made, docs/handoff.md updated, usage % logged
```

### 16.4 Card plan by phase

| Phase | Cards (approx.) | Opus cards | Generated by script |
| --- | --- | --- | --- |
| 0 Foundation | 4 | 0 | Repo scaffold, CI |
| 1 Tenancy, Auth, RBAC | 8 | 3 (RLS, JWT hook, provisioning) | Type generation, RLS test stubs |
| 2 Catalog + local store | 5 | 1 (sync pull) | CRUD screens, CSV import |
| 3 POS core offline | 9 | 3 (outbox, push idempotency, conflicts) | Zod schemas |
| 4 Inventory | 6 | 2 (ledger trigger, avg cost) | Stock test cases |
| 5 Warehouse | 8 | 2 (transfers, counts) | CRUD screens |
| 6 Reports | 8 | 1 (rollups) | Report pages from a report config |
| 7 Mobile + hardware | 4 | 0 | None |
| 8 Free-tier operations | 4 | 0 | Workflows |

Start with Phase 0 and Phase 1 in the first week: they are small, they prove tenant isolation early, and they give you real usage numbers to plan the rest.

Phase 5b (bins, put-away, picking) adds about 7 cards, 2 of them on Opus (bin ledger invariants and pick allocation). Generate its CRUD screens from the table config like the other phases.

> Recalibrated after Phase 1: solo-store focus and Flutter client. See docs/recalibration-solo-flutter.md (overrides Phase 2+ client choices).
