# QA-02 — Security Audit

**Worktree:** `.claude/worktrees/ag-work` (branch `ag/work`)  
**Phase:** Remediated (`Critical` & `High`) — Baseline audit completed first (`S01`–`S14`), then `S01`–`S06` fixed across Postgres (`supabase/migrations/20261114000100_qa02_security_fixes.sql`), `@pos/core`, `@pos/client`, and Mobile Flutter (`apps/mobile`), and proven with pgTAP (`055_qa02_security_audit.test.sql` + tightened `028`/`030`/`031`/`032`/`051`/`054`), Vitest (`pin.test.ts`, `security-controls.test.ts`), and Flutter tests (`supervisor_pin_test.dart`). `Medium` (`S07`–`S13`) and `Low` (`S14`) remain `Open` for owner prioritization.

---

## Executive Summary & Audit Coverage

| Domain | Scope & Method | Pre-Fix Result |
|---|---|---|
| Tenant isolation & RLS | Inspected all `55` `public` schema tables, RLS flags, policies, and privilege grants (`pg_class`, `pg_policies`, `information_schema.table_privileges`) + existing `004_tenant_isolation_matrix.test.sql` | **55 / 55** tables have `rls_enabled = true`; zero tenant write policies using `true` (only permissive `true` policies are `currencies_read` `SELECT` for `authenticated` lookup and 3 `supabase_auth_admin` `SELECT` policies: `profiles_auth_admin_read`, `tenants_auth_admin_read`, `platform_admins_auth_admin_read`); zero direct `anon` grants (`anon_table_grants = 0`); zero client write privileges on append-only financial/inventory ledgers (`stock_movements`, `stock_levels`, `sales`, `sale_items`, `payments`, `sale_returns`, `sale_return_items`, `processed_ops`, `sale_counters`, `supervisor_approvals`, `audit_log`, `platform_admins`). Gap noted (`S13`) in existing `004` seed coverage for 5 bin/pick-list tables. |
| Postgres functions & `SECURITY DEFINER` | Inventoried all `192` `public` functions (`152` `SECURITY DEFINER`, `40` `SECURITY INVOKER`) | `0` functions missing `SET search_path TO ''`; `78` `SECURITY DEFINER` functions callable by `authenticated`; `0` callable by `anon`. Critical offline forgery (`S01`), cross-tenant metrics leak (`S03`), and role/location/active guard gaps (`S04`) identified. |
| Money & stock integrity | Audited `op_record_sale`, `op_return_sale_items`, `consume_supervisor_approval`, `sync_push`, and inventory RPCs | `sync_push` enforces JWT `tenant_id` and `auth.uid()` (`created_by`) and deduplicates by `(tenant_id, client_op_id)`. Critical price/discount bypass and `unit_cost` tampering found in `op_record_sale` (`S02`), plus unverified offline approval payload (`S01`). Refund method / currency snapshot gap logged (`S07`). |
| Secrets, `.env*`, git history & client bundle | Checked `.gitignore`, `.env*`, recent commits, and `pnpm --filter @pos/client build` (`apps/client/dist`) | Zero service-role keys, JWT secrets, or database URIs committed or bundled. Built `apps/client/dist` (`84` precache entries) contains only the public `role: "anon"` demo key and Supabase SDK client-side `sb_secret_` warning string. |
| Auth, sessions & shared-device logout | Audited `apps/client` (`api.ts`, `main.tsx`, `app-layout.tsx`, `offline-pin-api.ts`, `supervisor-pin-dialog.tsx`) and `apps/mobile` (`app.dart`, `drift_store.dart`, `pin_auth.dart`, `supervisor_pin_dialog.dart`) | Shared-tablet logout on both Web and Mobile retains prior cashier/store operational data & cached offline PINs (`S05`), and Web offline PIN verification lacks 5-strike/15m lockout and falls back offline on non-network errors (`S06`). |
| XSS, CSV export, headers & Storage | Searched `apps/client` & `apps/mobile` for unsafe HTML/eval sinks, CSV quoting, security headers, and `product-photos` storage bucket rules | Zero `dangerouslySetInnerHTML`, `innerHTML`, or `eval(`. Storage bucket `product-photos` enforces `public = false`, `file_size_limit = 204800`, `allowed_mime_types = {image/jpeg}`, and tenant-prefixed UUID folder ownership. CSV formula injection (`-`, `\t`, `\r`) and missing CSP/security headers logged (`S08`, `S09`). |
| Dependencies | Ran `pnpm audit --prod` | `No known vulnerabilities found`. |
| Supabase DB lint & Advisors | Ran `supabase db lint --local -s public` and Splinter Security Advisor | `db lint`: 1 error (`op_return_sale_items` temp table `_ret_lines`), 12 warnings (`pbkdf2_sha256`, `get_platform_metrics`, unused locals / implicit `text->uuid[]` casts). Splinter: `216` lints (`97 INFO unindexed_foreign_keys`, `38 INFO unused_index`, `3 INFO rls_enabled_no_policy` on intentional server-only tables `processed_ops`, `sale_counters`, `supervisor_approvals`, `78 WARN authenticated_security_definer_function_executable`) (`S12`). |

---

## Finding Severity Totals

- **Critical:** 2 (`S01`, `S02`) — **2 Fixed**, 0 Open
- **High:** 4 (`S03`, `S04`, `S05`, `S06`) — **4 Fixed**, 0 Open
- **Medium:** 7 (`S07`–`S13`) — *Open (owner backlog)*
- **Low:** 1 (`S14`) — *Open (owner backlog)*

---

## Findings Register

### Critical

#### `S01` · Critical · Offline Supervisor Approval Forgery (Unverified Path B & Non-Approver Hash Exposure)
- **Where:**
  - `supabase/migrations/20261112000100_offline_supervisor_pin_complete.sql:53-125` (`consume_supervisor_approval`)
  - `supabase/migrations/20261113000100_qa01_functional_fixes.sql:16-70` (`pull_offline_pins`)
  - `packages/core/src/pin.ts:56-100`, `apps/client/src/lib/offline-pin-api.ts:55-82`
  - `apps/mobile/lib/core/pin.dart:40-65`, `apps/mobile/lib/core/supervisor_pin_dialog.dart:195-200`, `apps/mobile/lib/screens/supervisor_pin.dart:140-145`
- **What:**
  1. `consume_supervisor_approval` (Path B, `p_offline_approval`) accepts any JSON object `{ "approver_id": "<supervisor-uuid>", "approved_at": "<recent-iso-timestamp>", "action"?: ..., "ref_id"?: ... }` and authorizes supervisor overrides (large cashier discounts, sale voids, expense records/voids, day close, service float txns/voids) **without verifying any PIN, secret, HMAC, or cryptographic signature**. It checks only that `approver_id` exists in `profiles` with a non-null `pin_hash`, passes `is_store_approver`, has fewer than 5 recent `pin.failed` rows, and has an `approved_at` timestamp within `[now() - 7 days, now() + 10 minutes]`.
  2. `pull_offline_pins` returns `{ user_id, username, full_name, role, position, pin_hash }` for **every active user with a PIN** at the location (including `cashier` and `warehouse` roles, not only store approvers) and exposes raw PBKDF2 derived key digests (`dk`) rather than one-way verifiers, while omitting `assert_module('pos')`.
- **How to reproduce:**
  1. Authenticate as a cashier in a tenant where `sales_controls` limits cashier discounts to 10%.
  2. Call `list_store_approvers(store_id)` (or inspect `pull_offline_pins(store_id)`) to obtain an active supervisor's `user_id`.
  3. Call `sync_push([{ op_id, kind: 'record_sale', payload: { ..., discount: 9000, offline_approval: { approver_id: '<supervisor_id>', approved_at: '<now ISO>', action: 'sale_discount', ref_id: '<sale_id>' } } }])` directly over REST without knowing or entering the supervisor's PIN.
  4. `consume_supervisor_approval` logs `approval.offline` and accepts the sale with `status = 'ok'`.
- **Fix:**
  1. Update `pull_offline_pins` to require `assert_module('pos')`, filter strictly to store approvers (`p.role = 'superadmin'` or `p.role = 'admin' and la.position in ('manager', 'supervisor')`), and replace raw `dk` in `pin_hash` with a derived SHA-256 verifier `pbkdf2_sha256$<iter>$<salt>$v2:<base64(sha256(dk))>` so clients can verify a supervisor's PIN offline without storing the signing key `dk` on disk (`localStorage`/Drift).
  2. Update `consume_supervisor_approval` Path B to require a 64-char hex `proof` field verified in Postgres via `extensions.hmac` keyed by `dk` (from `profiles.pin_hash`) over canonical message `lower(tenant_id) || '|' || lower(approver_id) || '|' || p_action || '|' || coalesce(lower(p_ref_id::text), '') || '|' || v_approved_at_raw`, plus enforce strict action/ref binding when `proof` is checked (rejecting missing/invalid proofs with `42501` hint `approval_invalid`).
  3. Update Web (`@pos/core`, `offline-pin-api.ts`, `supervisor-pin-dialog.tsx`) and Mobile (`pin.dart`, `pin_auth.dart`, `supervisor_pin_dialog.dart`, `supervisor_pin.dart`) to verify `v2:` verifiers locally and compute `proof = HMAC-SHA256(dk, canonical_msg)` using the supervisor's live entered PIN.
- **Status:** `Fixed` — `pull_offline_pins` and `consume_supervisor_approval` updated in `supabase/migrations/20261114000100_qa02_security_fixes.sql` (`v2:` SHA-256 verifiers, `pos` module guard, approver role/position filtering, `extensions.hmac` SHA-256 `proof` verification, single-use `proof_digest` replay logging); Web updated in `packages/core/src/pin.ts`, `apps/client/src/lib/offline-pin-api.ts`, `apps/client/src/components/supervisor-pin-dialog.tsx`, `apps/client/src/lib/sale-math.ts`, `apps/client/src/lib/sell-api.ts`; Mobile updated in `apps/mobile/lib/core/pin.dart`, `apps/mobile/lib/core/pin_auth.dart`, `apps/mobile/lib/core/supervisor_pin_dialog.dart`, `apps/mobile/lib/screens/supervisor_pin.dart`. Proven by `030_offline_pins_and_approvals.test.sql`, `051_offline_supervisor_pin_complete.test.sql`, `054_qa01_functional_fixes.test.sql`, `055_qa02_security_audit.test.sql` (`[32]`–`[41]`), `packages/core/src/pin.test.ts`, `apps/client/src/lib/security-controls.test.ts`, and `apps/mobile/test/supervisor_pin_test.dart`.

---

#### `S02` · Critical · Unvalidated Client `unit_price` & `unit_cost` in `op_record_sale` (Discount Bypass & COGS Manipulation)
- **Where:** `supabase/migrations/20261110000300_card_payments.sql:139-184, 232-245` (`op_record_sale`)
- **What:**
  1. `op_record_sale` computes `v_gross` purely from client-supplied `it ->> 'unit_price'` (`line 141, 157`) without consulting catalog `variant_prices.price`. A cashier can bypass `max_cashier_discount_percent` and `consume_supervisor_approval` (`line 179`) on a ₱100.00 catalog item by submitting `unit_price: 1` and `discount: 0`, selling ₱100.00 inventory for ₱0.01 with zero supervisor approval.
  2. `op_record_sale` accepts client-supplied `it ->> 'unit_cost'` (`line 239`: `v_cost := coalesce((it ->> 'unit_cost')::bigint, v_cost);`) with no non-negative validation or server cost enforcement, allowing a cashier client to submit `unit_cost: -999999` or override `stock_levels.avg_cost` / `product_variants.cost` in `sale_items` and `stock_movements`.
- **How to reproduce:**
  1. Authenticate as a cashier (`juan`) where catalog item `v:gatas` has `variant_prices.price = 10000` (₱100.00), `product_variants.cost = 5000`, and `max_cashier_discount_percent = 10`.
  2. Submit `sync_push` with `record_sale` containing `{ variant_id: v_gatas, qty: 1, unit_price: 100, unit_cost: -50000 }` and payment `amount: 100`, omitting `approval_id` and `offline_approval`.
  3. Server records the ₱100.00 product as a ₱1.00 sale without supervisor approval and writes `unit_cost = -50000` into `sale_items`.
- **Fix:**
  1. Look up the tenant's base currency catalog price `v_catalog_price` from `public.variant_prices` per line item. While still allowing open-amount / unpriced variants (`v_catalog_price is null or v_catalog_price = 0`) to accept cashier-entered `unit_price > 0`, treat any downward price override (`v_catalog_price > 0 and v_price < v_catalog_price`) as a price concession `(v_catalog_price - v_price) * v_qty` included in effective discount against `v_catalog_gross := greatest(v_catalog_price, v_price) * v_qty`, requiring supervisor approval (`consume_supervisor_approval`) whenever effective discount exceeds `max_cashier_discount_percent`.
  2. Enforce server-authoritative `v_cost := coalesce(nullif(v_avg_cost, 0), v_var_cost, 0)` (rejecting negative client `unit_cost` with `22023` and never allowing client `unit_cost` to override positive server cost).
- **Status:** `Fixed` — `op_record_sale` updated in `supabase/migrations/20261114000100_qa02_security_fixes.sql` (looks up tenant base-currency `variant_prices.price`, preserves open-amount items where catalog price is null/`0`, counts downward price overrides toward `max_cashier_discount_percent` / `consume_supervisor_approval`, rejects negative client `unit_cost`, and enforces server-side COGS from `stock_levels.avg_cost` / `product_variants.cost`). Proven by `055_qa02_security_audit.test.sql` (`[42]`–`[51]`).

---

### High

#### `S03` · High · Cross-Tenant Infrastructure & Table Size Leak in `get_storage_metrics()`
- **Where:** `supabase/migrations/20261108002700_free_tier_operations.sql:25-106` (`get_storage_metrics`), `supabase/tests/032_free_tier_operations.test.sql:111-158`
- **What:** `get_storage_metrics()` permits any tenant `admin` (including store supervisors/managers) or `superadmin` to query cluster-wide `pg_database_size(current_database())` and the top 15 `pg_stat_user_tables` (`reltuples` and `pg_total_relation_size` across **all tenants** in the shared database), leaking platform-wide tenant scale, growth, and infrastructure telemetry across tenant boundaries.
- **How to reproduce:**
  1. Authenticate as any tenant `admin` (`maria`) or non-platform-admin tenant `superadmin` (`owner`).
  2. Call `POST /rest/v1/rpc/get_storage_metrics`.
  3. Response contains global `total_bytes`, `percent_used`, and global row counts (`tables`) summing rows belonging to all other tenants.
- **Fix:** Restrict global DB-wide metrics (`total_bytes`, `limit_bytes`, `limit_mb`, `percent_used`, `status`, `tables`) inside `get_storage_metrics()` to `service_role` / `is_platform_admin()` (`assert_platform_admin()`), restrict tenant caller access strictly to `superadmin` (blocking store `admin`/supervisor/manager, `warehouse`, and `cashier`), and return only tenant-scoped `tenant_stats` (with empty `tables: []` and null global database metrics) when called by a tenant `superadmin`, or provide a dedicated `get_tenant_storage_stats()` RPC for tenant settings (`apps/client/src/routes/settings.tsx` / `maintenance-api.ts`) while keeping full `get_storage_metrics()` strictly platform-admin-only (`get_platform_metrics()`). Update `032_free_tier_operations.test.sql` to assert platform-admin metrics vs tenant `superadmin` isolation and `admin`/cashier refusal without dropping any test case.
- **Status:** `Fixed` — `get_storage_metrics()` updated in `supabase/migrations/20261114000100_qa02_security_fixes.sql` (`scope = 'global'` global DB metrics and `tables` breakdown restricted strictly to `platform_admins` / `service_role`; tenant `superadmin` receives `scope = 'tenant'` `tenant_stats` with null global metrics and empty `tables`; store `admin`, `warehouse`, and `cashier` denied); Web callers updated in `apps/client/src/lib/maintenance-api.ts`, `apps/client/src/routes/settings.tsx`, and `apps/client/src/routes/platform.tsx`. Proven by `032_free_tier_operations.test.sql` (`25/25`) and `055_qa02_security_audit.test.sql` (`[14]`–`[17]`).

---

#### `S04` · High · Missing Role, Position, Module, and `is_active_user()` Guards Across RPCs & `devices` RLS
- **Where:**
  - `supabase/migrations/20261108002300_reports_analytics.sql:33-75` (`snapshot_daily_stock`)
  - `supabase/migrations/20261110000300_card_payments.sql:414-455` (`report_multi_store`)
  - `supabase/migrations/20261108002700_free_tier_operations.sql:4-22` (`health_ping`)
  - `supabase/migrations/20261113000100_qa01_functional_fixes.sql:450-1695, 1743-1810, 2234-2270` (warehouse bin/pick/transfer RPCs, `sync_pull_catalog`, `list_transfer_destinations`)
  - `supabase/migrations/20261108001500_tingi_repack.sql:588-610` (`sync_pull_conversions`)
  - `supabase/migrations/20261109000700_warehouse_sync.sql:56-82` (`sync_pull_warehouse`)
  - `supabase/migrations/20261108002100_devices_sale_no.sql:103-110` (`devices` insert/update RLS)
- **What:**
  1. `snapshot_daily_stock(date)` calls `assert_active_user()` and `assert_module('inventory')` with **zero role check**, allowing any `cashier` to snapshot and compute tenant-wide COGS/stock valuation daily rows.
  2. `report_multi_store(date, date, uuid)` checks only location access and **omits role exclusion of `cashier`** (`permissions.ts` restricts store/cost reports from cashiers; `report_multi_store` exposes `cogs`, `profit`, and `stock_levels.avg_cost`-derived valuation).
  3. Warehouse bin & transfer management RPCs (`enable_warehouse_bins`, `upsert_warehouse_zone`, `upsert_warehouse_bin`, `list_warehouse_bins`, `list_bin_stock`, `check_bin_stock_invariant`, `move_bin_stock`, `execute_putaway`, `generate_pick_list`, `confirm_pick_item`, `list_receiving_stock`, `get_pick_list_for_transfer`, `create_transfer`, `ship_transfer`, `cancel_transfer`, `list_transfer_destinations`) only check `v_role = 'cashier'`, permitting an `admin` with only `position = 'supervisor'` (never granted `transfer.manage` or warehouse permissions per `packages/core/src/permissions.ts:116-123` / `docs/plan.md`) to create/ship/cancel transfers and manage warehouse bins (and note: `receive_transfer` intentionally allows store cashiers at their own destination store `to_location_id` per `050_pos_receive_from_warehouse.test.sql`).
  4. `health_ping()` omits `assert_active_user()` and leaks `current_database()`.
  5. `sync_pull_catalog` & `sync_pull_conversions` lack `assert_module('inventory')`, and `sync_pull_catalog`, `sync_pull_conversions`, `sync_pull_warehouse` check only `v_tenant is not null` without active-user checks (`auth_tenant_id()` intentionally resolves for `suspended` read/export, so module guards are the critical missing check here).
  6. `devices_insert_own` and `devices_update` RLS policies (`20261108002100:103-110`) omit `(select public.is_active_user())`, allowing a suspended-tenant user to insert or rename terminal `devices` rows.
- **How to reproduce:**
  1. Authenticate as `cashier` (`juan`) and execute `select public.snapshot_daily_stock(current_date)` -> succeeds instead of raising `42501`.
  2. Authenticate as `admin` (`sara`, position `supervisor`) assigned to store `S01` and call `create_transfer(S01, S02, ...)` or `ship_transfer` -> succeeds even though `permissions.ts` (`transfer.manage`) sets `supervisor: false`.
  3. Authenticate as a suspended-tenant user and `insert into public.devices ...` -> succeeds despite tenant suspension.
- **Fix:**
  1. Restrict `snapshot_daily_stock` and `report_multi_store` to exclude `cashier` (`42501`, `not_allowed`), and restrict warehouse bin/pick-list RPCs to `superadmin`, `warehouse` with `has_location_access(v_wh, null)`, or `admin` with `has_location_access(v_wh, 'manager')`, while restricting `create_transfer`, `ship_transfer`, `cancel_transfer`, and `list_transfer_destinations` to `superadmin`, `warehouse` with source access, or `admin` with `has_location_access(v_from, 'manager')` (preserving destination-store cashier `receive_transfer` per `050_pos_receive_from_warehouse.test.sql`, while guarding warehouse-destination receives).
  2. Require `assert_active_user()` in `health_ping()` and remove `'database', current_database()` from its payload.
  3. Add `assert_module('inventory')` to `sync_pull_catalog` and `sync_pull_conversions` (note: keep `pos` module fallback if POS cashiers sync catalog? Check: `054` tests catalog pull with `inventory`/`pos`; allow `inventory or pos` module enabled cleanly while refusing disabled-module tenants) and recreate `devices_insert_own` / `devices_update` with `(select public.is_active_user())`.
- **Status:** `Fixed` — Updated in `supabase/migrations/20261114000100_qa02_security_fixes.sql` (`snapshot_daily_stock` and `report_multi_store` exclude `cashier`; `health_ping()` requires `assert_active_user()` and omits `current_database()`; `sync_pull_catalog` requires active `tenant_modules` (`deleted_at is null and (inventory or pos or warehouse)`) and `sync_pull_conversions` enforces active module access; warehouse bin/pick-list/transfer management RPCs restrict actions to `superadmin`, warehouse role, or `admin` with `'manager'` position while keeping destination store `receive_transfer`; `devices_insert_own` and `devices_update` RLS policies enforce `(select public.is_active_user())`). Proven by `028_multi_store_reports.test.sql`, `031_warehouse_bins.test.sql`, `054_qa01_functional_fixes.test.sql`, and `055_qa02_security_audit.test.sql` (`[11]`–`[31]`).

---

#### `S05` · High · Incomplete Local Data Clearing on Logout (Shared Tablet Data Exposure, Web & Mobile)
- **Where:**
  - `apps/client/src/lib/api.ts:128-147` (`signOut`), `apps/client/src/main.tsx:22` (`onAuthStateChange`), `apps/client/src/routes/app-layout.tsx:271-280` (`leave`)
  - `apps/client/src/lib/pos-outbox.ts:38-39`, `held-orders.ts:41`, `offline-pin-api.ts:20`, `fast-keys.ts:3`, `location-context.tsx:47-48`, `portal.ts:25`
  - `apps/mobile/lib/app.dart:156-166` (`Gate`), `apps/mobile/lib/data/drift_store.dart:27-48` (`ensureTenant`), `apps/mobile/lib/core/pin_auth.dart:176-184`
- **What:**
  1. **Web:** `signOut()` only calls `clearAllCachedAccess()` (`pos.access.v1:*`), and `main.tsx`'s `onAuthStateChange` listener ignores `SIGNED_OUT`. `xzactopos:pos-cache:*`, `xzactopos:pos-outbox:*`, `xzactopos:held-orders:*`, `pos.offlinePins.*`, `xzactopos:web-pinned-products`, `pos.activeStoreId`, `pos.activeWarehouseId`, and `pos.portal` remain in `localStorage` after logout and can be read by the next cashier signing in on the same shared browser/tablet (even across tenants!).
  2. **Mobile:** `Gate` (`app.dart:158-160`) clears only `accessCache.clear()` on sign-out. `DriftStore.ensureTenant` (`drift_store.dart:32-34`) only wipes Drift SQLite tables when `tenant_id` **changes**, meaning a second user logging into the **same tenant** on a shared tablet inherits all prior cashier sales, held carts, customers, shifts, queued outbox payloads, and `meta` `offline_pins_*` rows, plus `SharedPreferences` `pos.offline_pins.*` / failure counters remain populated.
- **How to reproduce:**
  1. Sign in on Web or Mobile as Manager/Cashier A at Store S01 (caching catalog, customers, sales, held orders, and `pos.offlinePins.*`).
  2. Click Sign Out.
  3. Inspect `localStorage` in Web DevTools or sign in on Mobile as Cashier B of the same tenant -> prior user's cached orders, PINs, outbox items, and store state remain present.
- **Fix:**
  1. **Web:** Add `clearSessionStorageOnSignOut()` clearing `pos.access.v1:*`, `xzactopos:pos-cache:*`, `xzactopos:pos-outbox:*`, `xzactopos:held-orders:*`, `pos.offlinePins.*`, `pos.offlinePinFailures.*`, `xzactopos:web-pinned-products`, `pos.activeStoreId`, `pos.activeWarehouseId`, `pos.portal`, and `sessionStorage` draft keys (`xzactopos:draft-po`, `xzactopos:draft-transfer`), invoked from `signOut()`, `leave()`, and `onAuthStateChange('SIGNED_OUT')` (with React Query `qc.clear()`). Keep benign device identity (`pos.deviceId`, `pos.deviceCode`, `pos.deviceName`, `pos.theme`, `pos.locale`, `pos.kioskMode`) intact so registered hardware terminal code isn't orphaned.
  2. **Mobile:** Add `LocalStore.clearSessionData()` / `DriftStore.clearSessionData()` (clearing all Drift SQLite tables via `db.allTables` + `SupervisorPinStorage.clearAll()`, resetting in-memory failure counters, and `accessCache.clear()`) and invoke it on sign-out in `Gate` (`app.dart`), as well as forcing clear whenever the signed-in `userId` changes in `DriftStore.ensureTenant` (while safely blocking or warning before explicit sign-out ONLY if unsent outbox exists in UI, or wiping clean on completed sign-out). Wait: ensure UI `Sign out` guard doesn't silently lose unsent ops while guaranteed sign-out leaves zero residual PII/PIN/sales caches!
- **Status:** `Fixed` — Web updated in `apps/client/src/lib/api.ts`, `apps/client/src/main.tsx`, and `apps/client/src/routes/app-layout.tsx` (`clearSensitiveSessionStorage()` invoked on `signOut()`, `leave()`, and `SIGNED_OUT`); Mobile updated in `apps/mobile/lib/data/local_store.dart`, `apps/mobile/lib/data/drift_store.dart`, `apps/mobile/lib/core/store_session.dart`, `apps/mobile/lib/app.dart`, and `apps/mobile/lib/core/pin_auth.dart` (`clearSessionData()`, `SupervisorPinStorage.clearAll()`, and `ensureTenant` `userId`-change wipe). Proven by `apps/client/src/lib/security-controls.test.ts` (`4/4`) and `apps/mobile/test/supervisor_pin_test.dart` (full `619/619` `flutter test`).

---

#### `S06` · High · Web Offline PIN Missing Rate Limit / Role Filter & Unconditional Offline Fallback
- **Where:** `apps/client/src/lib/offline-pin-api.ts:55-82`, `apps/client/src/components/supervisor-pin-dialog.tsx:95-115`
- **What:**
  1. `verifyOfflineSupervisorPin` (`offline-pin-api.ts:55-82`) has **no brute-force lockout** (unlike Postgres `pin_attempt` and Mobile `SupervisorPinStorage`'s 5-strike / 15-minute lockout) and does not filter cached users to approvers (`superadmin` or `admin` with `supervisor`/`manager` position).
  2. `SupervisorPinDialog` (`supervisor-pin-dialog.tsx:103-112`) catches **any** exception from online `approveSupervisorAction` and unconditionally falls back to `verifyOfflineSupervisorPin`, instead of checking `isNetworkFailure(err)` (so server `401`/`403`/`42501` policy rejections can silently fall back to offline mode).
- **How to reproduce:**
  1. Open `SupervisorPinDialog` on Web while disconnected (or trigger a server `42501` exception during `approveSupervisorAction`).
  2. Observe `SupervisorPinDialog` accepts offline verification even on server policy errors, and allows unlimited brute-force PIN attempts without locking out after 5 wrong tries.
- **Fix:**
  1. Restrict offline fallback in `SupervisorPinDialog` strictly to `if (!isNetworkFailure(err))` (`apps/client/src/components/supervisor-pin-dialog.tsx`), surfacing server policy errors immediately.
  2. Enforce approver role/position validation (`superadmin` or `admin` with `manager`/`supervisor`) and 5-attempt / 15-minute local lockout (`pos.offlinePinFailures.<locationId>`) in `offline-pin-api.ts`.
- **Status:** `Fixed` — Updated `apps/client/src/components/supervisor-pin-dialog.tsx` (`isNetworkFailure(err)` gating before falling back to offline verification) and `apps/client/src/lib/offline-pin-api.ts` (approver role/position validation and 5-attempt / 15-minute lockout tracked under `pos.offlinePinFailures.<locationId>`). Proven by `apps/client/src/lib/security-controls.test.ts` (`4/4`).

---

### Medium (Open Backlog)

#### `S07` · Medium · Partial Return Refund Method & Multi-Currency Sale Snapshot Gaps
- **Where:** `supabase/migrations/20261111000100_partial_returns.sql:188-194`, `sales` schema
- **What:**
  1. `op_return_sale_items` accepts `p_refund_method in ('cash', 'ewallet', 'card')` without verifying the original sale's tender mix (e.g., cash refund on an unpaid `utang` balance).
  2. `sales` table stores amounts only in `tenants.base_currency` without snapshotting `currency`/`fx_rate` columns per sale (`docs/plan.md` §6 backlog).
- **How to reproduce:** Issue a credit (`utang`) sale, call `op_return_sale_items` with `refund_method = 'cash'` -> returns cash on an unpaid credit sale.
- **Fix:** Validate `refund_method` against `payments` settled on the sale (or settle `utang` credit balance first) and add sale currency/FX snapshot columns if multi-currency checkout is enabled.
- **Status:** `Open`

#### `S08` · Medium · Incomplete CSV Formula Injection Escaping
- **Where:** `apps/client/src/lib/csv-helper.ts:29`, `apps/mobile/lib/core/export.dart:12`
- **What:** Web (`csv-helper.ts`) does not escape formula prefixes on all exported cells consistently across reports, and Mobile (`export.dart`) checks `= + @` (`startsWith`) but omits leading `-`, `\t`, and `\r`, allowing spreadsheet formula injection in exported product names, customer notes, or SKU values opened in Excel/Sheets.
- **How to reproduce:** Create a customer or product named `-2+3*cmd|' /C calc'!A0` or `=1+1` and export CSV on Mobile/Web; Excel interprets `-2+...` as a formula.
- **Fix:** Prefix any cell whose first character is `=`, `+`, `-`, `@`, `\t`, or `\r` with a leading single quote (`'`) before CSV quoting in both `csv-helper.ts` and `export.dart`.
- **Status:** `Open`

#### `S09` · Medium · Missing HTTP Security Headers & Content-Security-Policy (CSP)
- **Where:** `apps/client/index.html` and repository root hosting configuration
- **What:** No hosting headers file (`vercel.json`, `netlify.toml`, `_headers`, `firebase.json`, `nginx.conf`) and no CSP `<meta>` tag exist in `apps/client/index.html`, leaving clickjacking (`X-Frame-Options` / `frame-ancestors`), `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy`, and `Content-Security-Policy` unconfigured in-repo.
- **How to reproduce:** Build `apps/client/dist` or inspect repo root — no response-header config or CSP policy is declared.
- **Fix:** Add platform hosting header rules (e.g., `vercel.json` / `netlify.toml` / `_headers`) setting `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy`, `frame-ancestors 'none'`, and a tight CSP allowing `self`, Supabase HTTPS/WSS origins, and Google Fonts (if used).
- **Status:** `Open`

#### `S10` · Medium · Auth Minimum Password Length & Edge CORS / `redirect_to` Hardening
- **Where:** `supabase/config.toml:183-184`, `supabase/functions/_shared/http.ts`, `supabase/functions/invite_user/index.ts`
- **What:**
  1. `supabase/config.toml:183` sets `minimum_password_length = 6` and `password_requirements = ""`, whereas Edge `create_user` requires 8–72 characters.
  2. Edge `_shared/http.ts` falls back to `Access-Control-Allow-Origin: *` when `ALLOWED_ORIGINS` is unset in production.
  3. `invite_user` accepts arbitrary `https?://` `redirect_to` strings relying solely on GoTrue's `additional_redirect_urls` allowlist check.
- **How to reproduce:** Inspect `supabase/config.toml:183` (`minimum_password_length = 6`) and deploy Edge Functions without setting `ALLOWED_ORIGINS` env var.
- **Fix:** Set `minimum_password_length = 8` in `supabase/config.toml`, enforce fail-closed origin allowlist when running in production in `_shared/http.ts`, and validate `invite_user` `redirect_to` against `ALLOWED_ORIGINS`.
- **Status:** `Open`

#### `S11` · Medium · Unimplemented Solo-Mode Route Guard & Suspended Read Note (`/app/upgrade`)
- **Where:** `apps/client/src/router.tsx:229`, `supabase/migrations/20261108000400_product_photos.sql:51-53`
- **What:**
  1. `/app/upgrade` lacks a role/mode route guard (`M06` carried from QA-01).
  2. Note for owner awareness: `product_photos_member_read` checks `is_own_product_photo_path(name)` via `auth_tenant_id()`, which intentionally permits `suspended` tenants to read/export (`20261107000200:83`) while blocking writes via `can_upload_product_photo()`. Verify whether signed-out / suspended product image downloads should also be blocked on suspension.
- **How to reproduce:** Navigate directly to `/app/upgrade` as an unprivileged/already-pro role or fetch a cached object path as a suspended tenant member.
- **Fix:** Guard `/app/upgrade` route to `superadmin` (`router.tsx`) and confirm product photo retention/read policy on tenant suspension.
- **Status:** `Open`

#### `S12` · Medium · Supabase `db lint` & Splinter Security Advisor Hardening Backlog
- **Where:** Postgres database (`public` schema functions & tables)
- **What:**
  - `supabase db lint --local -s public` reports `1` error (`op_return_sale_items` line 194 temp table `_ret_lines` static resolution) and `12` warnings (`pbkdf2_sha256` volatility `IMMUTABLE` vs `STABLE` + shadowed/unused `i`; `get_platform_metrics` `STABLE` calling volatile paths; unused variables in `upsert_category`, `op_record_count`, `op_close_count`, `op_cancel_count`, `upsert_supplier`; implicit `text->uuid[]`/`text[]` casts in `create_po`, `update_po`, `receive_po`, `receive_without_po`, `record_count`).
  - Splinter Security Advisor reports `78 WARN authenticated_security_definer_function_executable`, `3 INFO rls_enabled_no_policy` (intentional server-only tables `processed_ops`, `sale_counters`, `supervisor_approvals`), `97 INFO unindexed_foreign_keys`, and `38 INFO unused_index`.
- **How to reproduce:** Run `supabase db lint --local -s public` and execute Splinter queries against local Postgres.
- **Fix:** Refactor `_ret_lines` in `op_return_sale_items` to a PL/pgSQL array/jsonb variable so `db lint` passes cleanly with 0 errors, review read-only `SECURITY DEFINER` RPCs that can be `SECURITY INVOKER` safely, and add covering indexes on hot FK columns.
- **Status:** `Open` *(Post-QA-02 `supabase db lint --local -s public` exits `0` with `0` new errors: `1` pre-existing `public.op_return_sale_items` line `194` `_ret_lines` error + `20` pre-existing/harmless warning objects.)*

#### `S13` · Medium · Incomplete `004_tenant_isolation_matrix` Coverage for Bin/Pick Tables & Cross-Tenant `INSERT`
- **Where:** `supabase/tests/004_tenant_isolation_matrix.test.sql:200-525`
- **What:** `004_tenant_isolation_matrix.test.sql` leaves `own_rows = 0` on 5 warehouse bin/pick-list tables (`warehouse_zones`, `bins`, `bin_stock_levels`, `pick_lists`, `pick_list_items`) and tests cross-tenant `INSERT` probes on only 1 table (`products`) rather than all 55 client-accessible/restricted tables. *(Note: QA-02 proof test `055_qa02_security_audit.test.sql` covers all 55 tables across `SELECT`, `INSERT`, `UPDATE`, `DELETE` and `anon` independently.)*
- **How to reproduce:** Review `004_tenant_isolation_matrix.test.sql` seed inserts (`lines 200-400`).
- **Fix:** Seed representative rows across the 5 bin/pick-list tables and verify full 55-table CRUD matrix in automated pgTAP tests (`055_qa02_security_audit.test.sql`).
- **Status:** `Open` *(Cross-tenant 55-table CRUD & `anon` matrix verified independently in `055_qa02_security_audit.test.sql`; seeding the 5 bin/pick tables in `004_tenant_isolation_matrix.test.sql` remains backlog.)*

---

### Low (Open Backlog)

#### `S14` · Low · Offline PIN Hash Iteration Count & Storage Encryption Hardening
- **Where:** `supabase/migrations/20261108001200_expense_supervisor_approval.sql:92` (`pbkdf2_sha256` default `20000` iterations), `apps/client/src/lib/offline-pin-api.ts`, `apps/mobile/lib/core/pin_auth.dart`
- **What:** Offline PIN hashes use `20,000` PBKDF2-HMAC-SHA256 iterations and are stored in unencrypted `SharedPreferences` / Drift SQLite / `localStorage` rather than `FlutterSecureStorage` / OS keystore. If a device's local storage is physically extracted (`S05`/`S01` mitigate remote/post-logout access and `v2:` verifier extraction from forging HMACs cleanly), a short 4-digit PIN still has only `10^4` search space offline.
- **How to reproduce:** Extract cached PIN entries from device storage and run an offline 4-digit dictionary search at `20,000` iterations.
- **Fix:** Increase `set_my_pin` default PBKDF2 iterations (e.g. `100,000+`, benchmarked on target low-end Android tablets), encourage 6-digit PINs for supervisors/managers, and store offline verifiers in encrypted mobile keystore storage (`flutter_secure_storage`) where available.
- **Status:** `Open`

---

## Verification Ledger

All checks below ran after final code, migration, and test edits:

| Check | Command | Observed Result |
|---|---|---|
| Workspace lint & typecheck | `pnpm lint` & `pnpm typecheck` | Exit `0` (`3/3` workspace packages clean) |
| Web & Core unit tests | `pnpm test` | `@pos/core`: `4` files, `55/55` tests (incl. `pin.test.ts` `4/4`); `@pos/client`: `37` files, `254/254` tests (incl. `security-controls.test.ts` `4/4`) |
| Edge function unit tests | `pnpm test:functions` | `_shared/validate.test.ts`: `22/22` tests passed (exit `0`) |
| Database pgTAP suite | `pnpm test:db` | `Files=55, Tests=4946, 160 wallclock secs — Result: PASS` (incl. `055_qa02_security_audit.test.sql` `51/51`, `032_free_tier_operations.test.sql` `25/25`, plus updated `028`, `030`, `031`, `051`, `054`) |
| Mobile analyze, SW & Flutter tests | `pnpm check:mobile` | Exit `0`: `8/8` service-worker checks passed; `flutter analyze`: `No issues found! (57.9s)`; `flutter test`: `+619: All tests passed!` |
| Production Web build & secret scan | `pnpm --filter @pos/client build` + `dist/` secret/JWT scan | `✓ built in 15.44s`, `PWA v2.0.0`, `precache 84 entries (2581.79 KiB)`. Zero `service_role` tokens (`session-DpfRJM-9.js` holds only `{"iss":"supabase-demo","role":"anon","exp":1983812996}`; `vendor-supabase-D0x-GxyM.js` matched only Supabase SDK's `sb_secret_` check string) |
| Production dependency audit | `pnpm audit --prod` | `No known vulnerabilities found` |
| Supabase SQL linter | `pnpm exec supabase db lint --local -s public` | Exit `0`, `0` new errors (`1` pre-existing `public.op_return_sale_items` line `194` `_ret_lines` error + `20` pre-existing/harmless warning objects) |
| Postgres security posture queries | `docker exec supabase_db_xzactopos psql` | `public_tables = 55`, `rls_tables = 55`, `anon_table_grants = 0`, `anon_fn_exec = 0`, `secdef_missing_search_path = 0`, `secdef_total = 152` (out of `192` `public` functions), `secdef_auth_exec = 78`; only permissive `true` policies are `currencies_read` (`SELECT`, `authenticated`) and `profiles_auth_admin_read`, `tenants_auth_admin_read`, `platform_admins_auth_admin_read` (`SELECT`, `supabase_auth_admin` only); `storage.buckets` `product-photos` has `public = f`, `file_size_limit = 204800`, `allowed_mime_types = {image/jpeg}` |
