# QA-01 — Functional Pass: Every Screen, Every Role

- **Pass Date**: 2026-11-14 (branch `ag/work`, worktree `.claude/worktrees/ag-work`)
- **Scope**: Complete screen × role × viewport (`360 / 768 / 1280`) × locale (`en / fil`) functional pass across Web (`apps/client`), Mobile (`apps/mobile`), and Supabase Postgres RPCs / Edge Functions (`supabase/`), plus `docs/design.md` §13 drift review and all 7 critical end-to-end user flows.
- **Workflow**: Find first, fix second. All baseline findings (`F01`–`F09`, `M01`–`M06`, `L01`–`L02`) were recorded prior to fixes, and two additional `High` defects (`F10`, `F11`) uncovered during Playwright E2E Flows 4 & 6 were fixed alongside `F01`–`F09`. Only `Critical` and `High` items (`F01`–`F11`) are fixed in QA-01; all `Medium` and `Low` items remain `Open` for triage.

---

## 1. Idempotent Multi-Tenant QA Seed (`scripts/qa-seed.mjs`)

Re-runnable seed script verified idempotent across two consecutive runs (`node scripts/qa-seed.mjs`, exit `0`). Creates two active `full`-mode tenants with all modules (`inventory = true`, `pos = true`, `warehouse = true`) and Edge Runtime verified healthy (`create_user` / `invite_user` returning `200 OK`):

| Tenant Slug | Name | Currency | Timezone | Locations | Seeded Users (`QaPass123!`) | Approvals PIN |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `qa-alpha-php` | XZACTO QA Alpha | `PHP` | `Asia/Manila` | `S01` (Main store), `S02` (Annex store), `W01` (Warehouse, `bins_enabled = true` via `enable_warehouse_bins`, default `RECEIVING`/`STAGING`/storage zones & bins + `A1-R1-S1`) | `owner` (`superadmin`), `manager` (`admin` @ `S01`,`S02` manager), `supervisor` (`admin` @ `S01` supervisor), `whclerk` (`warehouse` @ `W01`), `cashier` (`cashier` @ `S01`) | `1234` |
| `qa-beta-usd` | XZACTO QA Beta USD | `USD` | `UTC` | `S01` (Main store), `S02` (Annex store), `W01` (Warehouse, `bins_enabled = true` via `enable_warehouse_bins`, default `RECEIVING`/`STAGING`/storage zones & bins + `A1-R1-S1`) | `owner`, `manager`, `supervisor`, `whclerk`, `cashier` | `5678` |

Also seeds deterministic catalog products (including multi-variant `Iced Latte` with `Regular`/`Large`), store `stock_levels`, warehouse `stock_levels` + bin stock (`check_bin_stock_invariant` verified `0` invalid rows across `5` rows on `qa-alpha-php` and `3` rows on `qa-beta-usd`), active supplier, draft/open PO, and sample customer.

---

## 2. Complete Inventory: Screen · Roles · Modules · RPCs Used

### 2.1 Web Routes (`apps/client/src/router.tsx` & `apps/client/src/routes/app-layout.tsx`)

#### Public Routes
| Route | Screen | Who Can Access | Modules Required | RPCs / Tables / Edge Calls |
| :--- | :--- | :--- | :--- | :--- |
| `/` | `LandingPage` | Unauthenticated / Any | None | None |
| `/login` | `HomePage` | Unauthenticated (redirects to `/app` if signed in) | None | `signInWithPassword`, `provision_solo_store`, `resetPasswordForEmail` |
| `/signup` | `SoloSignUpPage` | Unauthenticated (redirects to `/app` if signed in) | None | `auth.signUp`, `rpc('provision_solo_store')` |
| `/reset-password` | `ResetPasswordPage` | Recovery session / Any | None | `auth.updateUser` |
| `/warehouse` | `WarehousePortalLoginPage` | Unauthenticated (redirects via portal if signed in) | None | `signIn`, `rpc('get_my_access')` |
| `/t/$slug` | `LoginPage` | Unauthenticated (redirects to `/app` if signed in) | None | `signIn`, `rpc('get_my_access')` |
| `/dev/ui` | `DevUiPage` | Dev only (`import.meta.env.DEV`) | None | None |

#### Authenticated `/app/*` Routes
| Route | Screen | Route Guard (`router.tsx`) | Nav / Portal Scope | Modules Required | RPCs / Tables / Outbox Ops / Edge Calls |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/app` | `HomeRoute` (`TodayPage` solo / `DashboardPage` full) | Active user (`get_my_access`); cashier -> `/app/sell`, wh -> `/app/warehouses` | Shared | `inventory` | `TodayPage`: `rpc('report_summary')`. `DashboardPage`: access context only |
| `/app/forbidden` | `ForbiddenPage` | Active user | Hidden | None | None |
| `/app/setup` | `SetupPage` | `tenant.settings` (`superadmin` until complete; then redirects) | Setup flow | None | `rpc('complete_setup')`, `.from('currencies')` |
| `/app/sell` | `SellPage` | `sale.create` (`superadmin`, `admin`, `cashier`) | `pos` | `pos` *(UI missing guard in `portal.ts` when `wh=false`)* | `.from('tenant_settings','customers','categories','stock_levels','stock_expiry','location_reorder_points','customer_ledger')`, `rpc('sync_pull_catalog')`, `rpc('register_device')`, `rpc('sync_push')` (`record_sale`, `upsert_customer`, `open_shift`, `close_shift`), `rpc('approve_supervisor_action')`, `rpc('pull_offline_pins')` |
| `/app/receive-stock` | `ReceiveStockPage` | `sale.create` *(mismatch: RPC only needs `inventory`)* | `pos` *(hidden if `!modules.warehouse`, `fullOnly`)* | `inventory` + `warehouse` | `rpc('list_store_incoming_transfers')`, `rpc('receive_transfer')` |
| `/app/sales` | `SalesPage` | `sale.create` | `pos` | `pos` | `.from('tenant_settings','sales','customers','payments','sale_returns','sale_items','sale_return_items')`, `rpc('sync_push')` (`void_sale`, `return_sale_items`), `rpc('approve_supervisor_action')`, `rpc('pull_offline_pins')` |
| `/app/utang` | `UtangPage` | `sale.create` | `pos` | `pos` | `.from('customers','customer_ledger')`, `rpc('sync_push')` (`upsert_customer`, `record_utang_payment`, `set_utang_due`, `adjust_utang`) |
| `/app/services` | `ServicesPage` | `sale.create` | `pos` | `pos` | `.from('wallet_float','service_txns')`, `rpc('sync_push')` (`record_service_txn`, `void_service_txn`), `rpc('approve_supervisor_action')`, `rpc('pull_offline_pins')` |
| `/app/expenses` | `ExpensesPage` | `shift.manage` *(bug: allows `cashier`)* | `pos` | `pos` | `.from('expenses')`, `rpc('sync_push')` (`record_expense`, `void_expense`) |
| `/app/day-close` | `DayClosePage` | `shift.manage` *(bug: allows `cashier` to close day)* | `pos` | `pos` | `rpc('report_summary')`, `rpc('shift_expected_now')`, `.from('profiles','day_closes','customer_ledger','shifts')`, `rpc('sync_push')` (`close_day`, `close_shift`) |
| `/app/warehouses` | `OverviewPage` | `reports.warehouse` (`superadmin`, `warehouse`) | `warehouse`, `fullOnly` | `warehouse` | `rpc('warehouse_stock_by_variant')`, `rpc('warehouse_reorder_list')`, `rpc('set_location_reorder_point')`, `rpc('warehouse_transfers_in_transit')`, `rpc('negative_stock_list')`, `.from('product_variants','stock_levels','location_reorder_points','locations')` |
| `/app/transfers` | `TransfersPage` | `transfer.manage` OR `stock.adjust_store` (`superadmin`, `admin-manager`, `warehouse`) | `warehouse`, `fullOnly` | `warehouse` | `rpc('sync_pull_catalog')`, `.from('locations','transfers')`, `rpc('create_transfer','ship_transfer','receive_transfer','cancel_transfer','generate_pick_list','get_pick_list_for_transfer','confirm_pick_item')` |
| `/app/bins` | `BinsPage` | `transfer.manage` OR `stock.adjust_store` OR `locations.manage` | `warehouse`, `fullOnly` | `warehouse` | `.from('locations','warehouse_zones')`, `rpc('enable_warehouse_bins','check_bin_stock_invariant','list_warehouse_bins','list_bin_stock','upsert_warehouse_zone','upsert_warehouse_bin','move_bin_stock','execute_putaway','list_receiving_stock')` |
| `/app/purchasing` | `PurchasingPage` | `purchasing.manage` (`superadmin`, `warehouse`) | `warehouse`, `fullOnly` | `warehouse` | `.from('suppliers','product_variants','purchase_orders','goods_receipts')`, `rpc('upsert_supplier','archive_supplier','create_po','update_po','submit_po','cancel_po','close_po','receive_po','receive_without_po')` |
| `/app/counts` | `CountsPage` | `stock.adjust_warehouse` (`superadmin`, `warehouse`) | `warehouse`, `fullOnly` | `warehouse` | `.from('locations','stock_counts','product_variants','stock_levels')`, `rpc('list_warehouse_bins','list_bin_stock','start_count','record_count','close_count','cancel_count')` |
| `/app/inventory` | `InventoryPage` | Any of `sale.create`, `catalog.manage`, `stock.adjust_*`, `reports.warehouse`, `transfer.manage` | `both` | `inventory` | `rpc('sync_pull_catalog')`, `.from('stock_levels','stock_expiry','location_reorder_points','categories','stock_movements')`, `rpc('set_location_reorder_point')`, `rpc('sync_push')` (`receive_stock`, `adjust_stock`, `open_pack`, `set_expiry`) |
| `/app/products` | `ProductsPage` | `catalog.manage` (`superadmin`, `admin-manager`, `warehouse`) | `both` | `inventory` | `rpc('sync_pull_catalog')`, `.from('stock_levels','stock_expiry','location_reorder_points','categories','conversions')`, `rpc('upsert_category','archive_category','upsert_product','archive_product')`, `storage.from('product-photos')`, `rpc('sync_push')` (`post_opening_stock`, `receive_stock`, `adjust_stock`, `open_pack`, `void_open_pack`, `set_expiry`) |
| `/app/reports` | `ReportsPage` | `reports.store` OR `reports.warehouse` *(bug: allows `cashier`)* | `both`, `fullOnly` | `pos` or `warehouse` | `.from('locations')`, `rpc('report_multi_store')`, `rpc('snapshot_daily_stock')` |
| `/app/audit` | `AuditPage` | `audit.read` (`superadmin`, `admin-manager`) | `both` | `inventory` | `.from('audit_log','profiles')` |
| `/app/locations` | `LocationsPage` | `locations.manage` (`superadmin`) | `both`, `fullOnly` | `warehouse` (for warehouse types) | `.from('locations')`, `rpc('upsert_location','archive_location')` |
| `/app/users` | `UsersPage` | `users.manage` (`superadmin`, `admin`) | `both`, `fullOnly` | None | `Edge: create_user, invite_user`, `rpc('set_user_role','assign_location','revoke_location','set_user_active','clear_user_pin','set_my_pin')`, `.from('profiles','locations','location_access','tenant_limits')` |
| `/app/modules` | `ModulesPage` | `tenant.modules` (`superadmin`) | `both`, `fullOnly` | None | `rpc('set_modules')` |
| `/app/upgrade` | `UpgradePage` | `tenant.modules` *(lacks solo check in `beforeLoad`)* | `pos`, `soloOnly` | None | `rpc('set_modules','upsert_location')` |
| `/app/settings` | `SettingsPage` | `tenant.settings` (`superadmin`, `admin`) | `both` | None | `.from('tenants','tenant_settings','tenant_limits','locations','profiles','devices','products','currencies','tenant_currencies')`, `rpc('register_device','get_storage_metrics','archive_processed_ops','health_ping')` |
| `/app/platform` | `PlatformPage` | `is_platform_admin` | Platform admin only | None | `rpc('get_platform_metrics','list_platform_tenants','set_platform_tenant_status','set_platform_tenant_plan','provision_tenant')` |

### 2.2 Mobile Screens (`apps/mobile/lib/`)

| Screen (`apps/mobile/lib/screens/`) | Shell / Entry | Current Role Gate (Observed) | Required Roles / Modules (Backend) | RPCs / Outbox / Storage Used |
| :--- | :--- | :--- | :--- | :--- |
| `AuthScreen` (`auth_screen.dart`) | Signed out | Unauthenticated | None | `signIn`, `signUp`, `sendPasswordReset` |
| `StoreNameScreen` (`store_name_screen.dart`) | Signed in, no tenant | Active auth user | None | `rpc('provision_solo_store')` |
| `SetPasswordScreen` (`password_screens.dart`) | Password recovery | Recovery session | None | `auth.updateUser` |
| `HomeShell` (`home_shell.dart`) | `role != 'warehouse'` | *(Bug: ignores `modules.pos`)* | `modules.pos = true` | SyncEngine: `register_device`, `sync_push`, `sync_pull_*`, `pull_offline_pins` |
| `TodayScreen` (`today_screen.dart`) | `HomeShell` tab | Store roles; Expenses/DayClose gated by `canManageStock` | `pos` | Reads Drift; links to `ServicesScreen`, `ExpensesScreen`, `DayCloseScreen`, `ReceiptScreen` |
| `StockScreen` (`stock_screen.dart`) | `HomeShell` tab | All store roles (`canManageStock` gates action sheet, **not** Restock icon) | `inventory`; write ops require manager/superadmin | Reads Drift; links to `RestockScreen`, `TransferCreateScreen`; enqueues `receive_stock`, `adjust_stock`, `set_expiry`, `open_pack`, `void_open_pack` |
| `SellScreen` (`sell_screen.dart`) | `HomeShell` tab | All store roles *(Bug: opens `ProductFormScreen` ungated)* | `pos` | Reads Drift; links to `PayScreen`, `ShiftScreen`, `TodayScreen`, `ProductFormScreen` |
| `PayScreen` (`pay_screen.dart`) | Pushed from Sell | All store roles | `pos` (`sale.create`) | `rpc('pull_offline_pins')`, `rpc('approve_supervisor_action')`, outbox `record_sale` |
| `ReceiptScreen` (`receipt_screen.dart`) | Pushed from Today/Sales | Void/Return flow via PIN dialog | `pos` | `rpc('approve_supervisor_action')`, `rpc('pull_offline_pins')`, outbox `void_sale`, `return_sale_items` |
| `UtangScreen` (`utang_screen.dart`) | `HomeShell` tab | All store roles (`adjust_utang` gated by `canManageStock`) | `pos` (`adjust_utang` requires manager/superadmin) | Outbox `upsert_customer`, `record_utang_payment`, `set_utang_due`, `adjust_utang` |
| `MoreScreen` -> `ProductsScreen` / `ProductFormScreen` | `HomeShell` More tab | **None** *(Bug: accessible & editable by cashier and supervisor)* | `catalog.manage` (`superadmin` / `admin-manager`) | `rpc('upsert_product')`, `rpc('archive_product')`, `storage.from('product-photos')`, outbox `post_opening_stock`, `set_tingi_link` |
| `MoreScreen` -> `RestockScreen` | `HomeShell` / Stock icon | Submit gated by `canManageStock` (`admin-supervisor` allowed despite SQL denial) | `superadmin` / `admin-manager` | Outbox `receive_stock` |
| `MoreScreen` -> `ReportsScreen` | `HomeShell` More tab | `canManageStock` *(allows supervisor, excludes cashier shift view)* | Store reports | `rpc('report_summary')` |
| `MoreScreen` -> `ExpensesScreen` | `HomeShell` More tab | `canManageStock` | `pos` (`superadmin` / `admin`) | Outbox `record_expense`, `void_expense` |
| `MoreScreen` -> `ShiftScreen` | `HomeShell` More tab | All store roles *(Bug: Cash Drop button visible to cashier -> `record_expense` fails)* | `pos` (Shift = seller; Cash Drop = admin+) | `rpc('shift_expected_now')`, outbox `open_shift`, `close_shift`, `record_expense` |
| `MoreScreen` -> `StaffScreen` | `HomeShell` More tab | `isAdminOrSuperadmin` *(Bug: includes supervisor)* | `superadmin` / `admin-manager` | `.from('profiles','location_access','locations')`, `Edge: create_user`, `rpc('set_user_active','clear_user_pin')` |
| `MoreScreen` -> `ServicesScreen` | `HomeShell` More tab | All store roles; float/void gated by `canManageStock` | `pos` (`float/void` = manager/superadmin) | Outbox `record_service_txn`, `void_service_txn` |
| `MoreScreen` -> `DayCloseScreen` | `HomeShell` More tab | `canManageStock` | `pos` (`superadmin` / `admin`) | Outbox `close_day` |
| `MoreScreen` -> `TransfersScreen` / `TransferCreateScreen` / `TransferReceiveScreen` | `HomeShell` More tab | `canManageStock` (`admin-supervisor` fails create) | `inventory` (`warehouse` for warehouse transfers) | `.from('transfers','locations')`, `rpc('create_transfer','receive_transfer')` |
| `MoreScreen` -> `DataScreen` | `HomeShell` More tab | `canManageStock` *(supervisor hits SQL error)* | `superadmin` / `admin-manager` | CSV export + outbox `upsert_product`, `post_opening_stock` |
| `MoreScreen` -> `SettingsScreen` | `HomeShell` More & Warehouse More | All roles *(Bug: `Upgrade to Full` shown to `admin` despite superadmin-only RPC)* | User settings (`set_modules` = `superadmin`) | `rpc('set_modules','set_my_pin')` |
| `WarehouseShell` -> `ReceiveTab` (`WalkInScreen`, `ReceiveOrderScreen`) | `role == 'warehouse'` | `warehouse` role only | `warehouse` | `sync_pull_warehouse`, outbox `receive_po`, `receive_without_po` |
| `WarehouseShell` -> `CountTab` | `WarehouseShell` | `warehouse` role only | `warehouse` | Outbox `start_count`, `record_count`, `close_count`, `cancel_count` |
| `WarehouseShell` -> `StockTab` | `WarehouseShell` | `warehouse` role only | `warehouse` | Reads Drift + bin stock lookup |
| `WarehouseShell` -> `PutawayScreen`, `PickListScreen`, `TransfersScreen` | `WarehouseShell` More | `warehouse` role only | `warehouse` | `rpc('list_receiving_stock','list_warehouse_bins','execute_putaway','get_pick_list_for_transfer','generate_pick_list','confirm_pick_item')`, `.from('transfers')` |

### 2.3 Postgres Functions & Edge Functions Summary

Total unique `public.*` functions inventoried across `supabase/migrations/`: **192 functions** (`op_*` outbox handlers via `sync_push`, `sync_pull_*` delta sync RPCs, direct UI RPCs, trigger/RLS helpers). Edge Functions (`supabase/functions/`): `create_user` and `invite_user`.
- `sync_pull_warehouse` checks `assert_module('warehouse')`.
- **Gap**: POS pull RPCs (`sync_pull_pos`, `sync_pull_sales`, `sync_pull_expenses`, `sync_pull_day_closes`, `sync_pull_service`, `sync_pull_shifts`) do NOT check `assert_module('pos')`.
- **Gap**: `pull_offline_pins(null)` references nonexistent `public.resolve_caller_store(uuid)`.
- **Gap**: Several warehouse bin/pick-list/transfer RPCs omit `assert_module('warehouse')`, `assert_location_access(...)`, or role checks (detailed in Findings below).

---

## 3. Live Sweep Results (Web UI Matrix + Viewports + `en/fil` + `design.md` §13)

Automated Chromium Playwright sweep ran against `qa-alpha-php` (all 5 roles × 25 `/app/*` routes × `1280px` `en`, `360px` `fil`, `768px` `en` + 6 public routes × 2 locales × 3 viewports) and `qa-beta-usd` (`USD` currency leakage check across 12 routes):

- **Role Access Matrix (Observed Live URL Behavior on `qa-alpha-php`)**:
  - **Public**: `/`, `/login`, `/signup`, `/warehouse`, `/reset-password`, `/t/qa-alpha-php` — `0` horizontal overflows (`ox = 0`), `0` raw i18n keys, `0` error banners across `en` & `fil` at `360`, `768`, `1280` px.
  - **`owner` (`superadmin`)**: Full access to all `/app/*` routes (except `/app/setup` redirects cleanly once completed).
  - **`manager` (`admin`, store manager)**: Allowed on `/app`, `/app/sell`, `/app/receive-stock`, `/app/sales`, `/app/inventory`, `/app/products`, `/app/utang`, `/app/services`, `/app/expenses`, `/app/day-close`, `/app/transfers`, `/app/bins`, `/app/reports`, `/app/audit`, `/app/users`, `/app/settings`, `/app/forbidden`; redirected off `/app/warehouses`, `/app/purchasing`, `/app/counts`, `/app/locations`, `/app/modules`, `/app/upgrade`, `/app/platform`.
  - **`supervisor` (`admin`, store supervisor)**: Redirected off `/app/products`, `/app/transfers`, `/app/bins`, `/app/audit`, `/app/warehouses`, `/app/purchasing`, `/app/counts`, `/app/locations`, `/app/modules`; allowed on `/app`, `/app/sell`, `/app/receive-stock`, `/app/sales`, `/app/inventory`, `/app/utang`, `/app/services`, `/app/expenses`, `/app/day-close`, `/app/reports`, `/app/users`, `/app/settings`.
  - **`whclerk` (`warehouse`)**: Allowed on `/app/warehouses`, `/app/inventory`, `/app/products`, `/app/transfers`, `/app/bins`, `/app/purchasing`, `/app/counts`, `/app/reports`; redirected to `/app/warehouses` on all POS & admin config routes.
  - **`cashier`**: Redirected to `/app/sell` on warehouse, admin config, `products`, `audit`; **HOWEVER** currently allowed on `/app/expenses`, `/app/day-close`, and `/app/reports` without write/access restrictions (see **F06**).
- **Responsive Overflow (`overflowX > 0`)**:
  - `/app/bins`: **`+477px` at `360px` (`fil`)**, **`+381px` at `768px` (`en`)**
  - `/app` (Dashboard): `+26px` at `768px` (`en`)
  - `/app/settings`: `+26px` at `360px` (`fil`)
  - `/app/reports`: `+12px` at `360px` (`fil`)
  - `/app/transfers`: `+4px` at `360px` (`fil`)
- **USD Currency Leakage (`qa-beta-usd`)**:
  - `/app/settings` rendered `₱` (`Max Cashier Void Amount (₱)`) on the USD tenant (`M01`).
- **Console / Runtime Diagnostics**:
  - Dev-mode console warning/error on navigation: `Error: This library called use() to suspend in a previous render but did not call use() when it finished` (`M04`).

---

## 4. Critical User Flows Verification (`qa-wrapup.md` QA-01)

All 7 critical flows now pass end-to-end in `e2e/qa01-critical-flows.spec.ts` against the production Vite PWA preview build (`vite preview`):

| Flow | Scenario | Baseline Status | Post-Fix Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| Flow 1 | Multi-variant item sale (cash / card / QR -> receipt -> stock decrements) | **Blocked / Failing** (`F03`) | **Passing** | Cash, Card, and QR split/direct checkouts verified for Regular/Large variants with DB stock deduction. |
| Flow 2 | Offline sale (offline -> sell 3 orders -> reload app -> online -> all 3 sync once -> stock correct) | **Blocked / Failing** (`F01`, `F02`) | **Passing** | Survives full browser `page.reload()` while offline via PWA SW + cached `MyAccess`; flushes 3 unique sales once on reconnect. |
| Flow 3 | Void & partial return / refund | Unverified in E2E | **Passing** | Partial return + full void append positive `stock_movements` without altering prior rows; stock restored. |
| Flow 4 | Warehouse receive -> transfer -> store receive (bins invariant) | Unverified in E2E (`F08`) | **Passing** *(uncovered & fixed `F10`)* | Walk-in receive at `W01` -> draft transfer (`list_transfer_destinations`) -> pick list to staging -> ship -> store receive on `/app/receive-stock`; `check_bin_stock_invariant` `0` invalid. |
| Flow 5 | Stock count / adjust append-only | Unverified in E2E | **Passing** | Inventory adjustment writes new `count_correction` movement without modifying existing movement rows. |
| Flow 6 | Admin create product & edit price -> cashier sees update after poll | **Blocked / Failing** (`F03`) | **Passing** *(uncovered & fixed `F11`)* | Admin creates multi-variant product + updates price with immediate refresh; cashier sees product & updated price after `30s` `staleTime` poll. |
| Flow 7 | Module off (`pos` disabled -> POS nav hidden AND POS RPCs refuse) | **Blocked / Failing** (`F05`, `F07`) | **Passing** | Disabling `pos` hides Sell nav / blocks `/app/sell` route and refuses `sync_pull_pos` + `sync_push`; `pos` re-enabled in cleanup. |

---

## 5. Findings Register

### Critical & High (Fixed in QA-01)

| ID | Severity | Area | What | Where (`file:line`) | How to Reproduce | Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **F01** | **Critical** | Web Auth / Offline | Offline reload while signed in wipes session and redirects to `/login`. `loadAccess` checks `hasSession()`, calls `get_my_access` RPC, catches network failure and returns `null`; `router.tsx` calls `signOut()` and redirects to `/login`. | `apps/client/src/lib/session.tsx:19-26`, `apps/client/src/router.tsx:124-128` | Sign in on Web, go offline (`context.setOffline(true)`), reload `/app/sell`. | Persist `MyAccess` per `user_id` in `localStorage`, fall back to cached `MyAccess` on offline/network errors (only sign out on explicit server rejection/no account), clear cache on sign-out; verified PWA SW offline reload (`Flow 2`). | **Fixed** |
| **F02** | **High** | Web POS / Stock | Offline optimistic stock never decrements on queued sales. `applyOptimisticStockDeltas` reads `op.payload.lines` (`line.tracked !== false`), whereas `salePayload()` writes `op.payload.items` without `tracked`. | `apps/client/src/lib/pos-outbox.ts:233-258`, `apps/client/src/lib/sale-math.ts:148-184` | Go offline on `/app/sell`, record a sale, observe displayed stock count before reconnecting. | Updated `applyOptimisticStockDeltas` and `salePayload` to read `items` (preserving backward compat with `lines`) and respect tracked variants via passed map/payload flag. | **Fixed** |
| **F03** | **High** | DB / Web / Mobile Catalog & POS | Multi-variant products cannot be created, edited, synced with labels/prices, or picked on POS. `product_variants` lacks `name`, `upsert_product` rejects non-default variants (`variant_mismatch`), `sync_pull_catalog` omits variant label/price, Web & Mobile catalog filter out `!v.is_default`, and POS has no variant picker sheet (`design.md` §7). | `supabase/migrations/20261108000200_catalog.sql`, `20261108000300_catalog_rpcs.sql:126-278,360`; `apps/client/src/lib/sell-api.ts:56-65`, `stock-api.ts:55-61`, `routes/products.tsx:64`, `routes/sell.tsx`; `apps/mobile/lib/data/drift_store.dart:59`, `product_form_screen.dart`, `sell_screen.dart` | Try creating a product with 2 variants (`Regular` / `Large`) on Web/Mobile and selling either variant. | Added `20261113000100_qa01_functional_fixes.sql` (`product_variants.name`, multi-variant `upsert_product` & `sync_pull_catalog`), Web/Mobile multi-variant UI & variant picker (`DriftStore`, `ProductFormScreen`, `SellScreen`), and seeded `Iced Latte` (`Regular`/`Large`) in `qa-seed.mjs`. | **Fixed** |
| **F04** | **High** | Postgres RPC | `pull_offline_pins(null)` calls nonexistent `public.resolve_caller_store(uuid)`, failing at runtime whenever `p_location_id` is omitted (e.g., `superadmin` pull). | `supabase/migrations/20261108002500_offline_pins_and_approvals.sql:25`; `apps/client/src/lib/offline-pin-api.ts:42` | Call `rpc('pull_offline_pins', { p_location_id: null })` as active user. | Replaced `public.resolve_caller_store(v_loc)` with `public.resolve_store(v_loc)` in `20261113000100_qa01_functional_fixes.sql` + pgTAP tests in `054_qa01_functional_fixes.test.sql`. | **Fixed** |
| **F05** | **High** | Module Enforcement (Web & DB) | Disabling `pos` module (`set_modules(false, true)`) leaves `portal.ts` returning `["pos"]` when `warehouse=false`, blocks `/app/receive-stock` behind `sale.create` even when `warehouse=true` (`receive_transfer` only needs `inventory`), omits `modules.warehouse` guard in `router.tsx` for `/app/receive-stock`, and allows `sync_pull_pos`, `sync_pull_sales`, `sync_pull_expenses`, `sync_pull_day_closes`, `sync_pull_service`, `sync_pull_shifts` to execute without `module_disabled`. | `apps/client/src/lib/portal.ts:72-81`; `apps/client/src/router.tsx:179`; `apps/client/src/routes/app-layout.tsx:275`; `supabase/migrations/20261108001300..20261109001100` (`sync_pull_*`) | Set `modules.pos = false, warehouse = true`, inspect Web nav/redirects & call `sync_pull_pos` / `sync_pull_sales` / `sync_pull_shifts`. | Fixed `resolveAllowedPortals` & POS nav/route visibility when `!access.modules.pos`; aligned `/app/receive-stock` guard; added `assert_module('pos')` to POS `sync_pull_*` RPCs (`20261113000100` + `054` pgTAP + `Flow 7`). | **Fixed** |
| **F06** | **High** | Web RBAC | `cashier` can load `/app/expenses`, `/app/day-close` Close Day form, and `/app/reports`, triggering `not_allowed` refusals on `op_record_expense` / `op_close_day`. (`/app/expenses` and Close Day require admin/superadmin in SQL.) | `apps/client/src/router.tsx:197-198,206`; `apps/client/src/routes/expenses.tsx:213`; `apps/client/src/routes/day-close.tsx:332`; `apps/client/src/routes/app-layout.tsx:75-76,104` | Sign in as `cashier`, visit `/app/expenses` -> submit expense, or `/app/day-close` -> submit close day. | Enforced role/permission split so `cashier` cannot access `/app/expenses`, multi-store `/app/reports`, or Close Day submission on `/app/day-close` (keeping cashier shift view accessible). | **Fixed** |
| **F07** | **High** | Mobile Module & RBAC | Mobile ignores `access['modules']['pos']`, grants `canManageStock = true` / `isAdminOrSuperadmin = true` to `admin-supervisor` (whose writes `catalog_write_mode()` rejects!), exposes `+ Add Product` / editable form / `RestockScreen` / `Cash Drop` (`record_expense`) to `cashier`, and exposes `Upgrade to Full Mode` (`set_modules`) to `admin`. | `apps/mobile/lib/app.dart:268`; `apps/mobile/lib/sync/store_session.dart:28,106-109,218-223`; `home_shell.dart:150-264`; `products_screen.dart:106,160`; `product_form_screen.dart:480`; `sell_screen.dart:166,621`; `shift_screen.dart:335-340`; `settings_screen.dart:338-384` | Sign in on Mobile as `cashier`, `supervisor`, or `manager`, or with `pos = false`. | Enforced `modules['pos']` in `App` + `SyncEngine`; split `manager` vs `supervisor` permissions in `StoreSession`; gated catalog/restock/cash-drop/upgrade controls; added `role_permissions_test.dart` & split `cash_drop_test.dart`. | **Fixed** |
| **F08** | **High** | Postgres Warehouse & Bin RPCs | Warehouse bin/pick-list RPCs (`check_bin_stock_invariant`, `list_warehouse_bins`, `list_bin_stock`, `get_pick_list_for_transfer`) omit `assert_location_access` / `assert_active_user` / role/module checks; `confirm_pick_item` (`p_qty_picked = 0`) lacks role check; warehouse bin/transfer RPCs omit `assert_module('warehouse')`. | `supabase/migrations/20261108002600_warehouse_bins.sql:340,469,523,582,663,728,767,866,999`; `20261108002200_transfers.sql:196,316,494`; `20261110000100_web_gaps_po_mode.sql:277` | Call `check_bin_stock_invariant(other_wh)` or `list_warehouse_bins(other_wh)` as a user restricted to another location, or with `warehouse = false`. | Added `assert_active_user()`, `assert_module('warehouse')`, `assert_location_access(...)`, and non-cashier role guards in `20261113000100_qa01_functional_fixes.sql` + `054_qa01_functional_fixes.test.sql`. | **Fixed** |
| **F09** | **High** | Web Day Close Math | `DayClosePage` drawer expected cash calculation excludes net service ledger cash (`cash_in`, `cash_out`, `load`, float top-up/withdraw), disagreeing with server `day_close_server_expected`. | `apps/client/src/routes/day-close.tsx:126-139`; `supabase/migrations/20261108001400_service_ledger.sql:680` | Record a GCash cash-in service txn, then check expected cash on `/app/day-close` vs server expected. | Included service cash effect from day summary / service txns in `DayClosePage` expected cash breakdown & `computeExpectedCash`. | **Fixed** |
| **F10** | **High** | Web & Mobile / Postgres Transfers | Non-superadmin users (e.g., `whclerk` at `W01`) see an empty **Destination Location** dropdown on `/app/transfers` (and Mobile `TransferCreateScreen`) because `listLocations()` / `fetchTransferDestinations()` query `public.locations` directly, whose `locations_read` RLS hides stores/warehouses not in `auth_location_ids()`, and transfer rows/manifests show raw destination UUIDs. | `supabase/migrations/20261107000300_rls_policies.sql:166`; `apps/client/src/routes/transfers.tsx:128,626`; `apps/mobile/lib/backend.dart:612-622` | Sign in as `whclerk`, open `/app/transfers` -> `New Transfer`, open Destination dropdown. | Kept `locations_read` RLS strict and added `public.list_transfer_destinations()` `SECURITY DEFINER` RPC (`20261113000100_qa01_functional_fixes.sql`, rejecting `cashier`, requiring `inventory` + active user, filtering warehouses when `!modules.warehouse`, pgTAP-tested in `054`), plus Web `listTransferDestinations` + `resolveLocation` (`transfers-api.ts`, `transfers.tsx`) and Mobile `fetchTransferDestinations` (`backend.dart`). | **Fixed** |
| **F11** | **High** | Web POS / Catalog Sync | Creating a multi-variant product or editing prices on `/app/products` does not appear after `Save` (`invalidateQueries(["products"])`) for 5 seconds because Web's `pullCatalog()` called `sync_pull_catalog`, which enforces `updated_at <= now() - interval '5 seconds'` for offline delta-sync watermarks. | `apps/client/src/lib/sell-api.ts:141-159`; `supabase/migrations/20261108001500_tingi_repack.sql:657` | Create a new product or update price on `/app/products`; inspect product list immediately after `pf-save` closes. | Updated `pullCatalog()` in `apps/client/src/lib/sell-api.ts` to read current `categories`, `products`, `product_variants`, and `variant_prices` via RLS-scoped PostgREST pagination (zero 5 s holdback), preserving `sync_pull_catalog` untouched for Mobile delta sync (`Flow 6`). | **Fixed** |

### Medium & Low (Logged for Triage — Not Fixed in QA-01)

| ID | Severity | Area | What | Where (`file:line`) | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **M01** | **Medium** | Currency / i18n | Hardcoded `₱` symbol shown on non-PHP tenants (`qa-beta-usd` confirmed live on `/app/settings`), plus denomination sheets hardcode PHP bills/coins and `Math.round(n * 100)`. | `apps/client/src/locales/{en,fil}/admin.json:831`; `apps/client/src/components/customer-statement-dialog.tsx:148`; `apps/client/src/components/denomination-counter-dialog.tsx:30,104,141`; `apps/mobile/lib/screens/denomination_sheet.dart:21`; `apps/mobile/lib/l10n/app_{en,fil}.arb:1381`; `apps/mobile/lib/screens/product_form_screen.dart:257` | **Open** |
| **M02** | **Medium** | Web Responsive / Layout | Horizontal overflow (`overflowX`) at `360px`/`768px` on `/app/bins` (`+477px`/`+381px`), `/app/settings` (`+26px`), `/app` (`+26px` tablet), `/app/reports` (`+12px`), `/app/transfers` (`+4px`); nav pills clip text (`Receive Stock`, `Utang (pay later)`, `Warehouse Overview`, `Dispatch to POS`, `Bins & Put-Away`) due to `whitespace-nowrap`/narrow containers. | `apps/client/src/routes/bins.tsx`, `settings.tsx`, `app-layout.tsx`, `reports.tsx`, `transfers.tsx` | **Open** |
| **M03** | **Medium** | `design.md` §13 Drift | PWA `theme_color: "#3419d2"` instead of `#0F1A16`; `★` / `✳` / `⇄` glyphs; `slate-*`/`amber-800` Tailwind classes instead of Night Market tokens; literal non-i18n UI strings (`platform.tsx`, `bins.tsx`, `settings.tsx`, `sell.tsx:1035`, `app-layout.tsx:457,599`); printable slips (`receipt-slip.tsx:54`, `shift-slip.tsx:128,244`) lack `.receipt` zig-zag edge/`tabular-nums`; 13/28 routes lack `tabular-nums`; `sell.tsx:996-1026` uses custom sync pill instead of `<SyncStatusPill>`; Mobile `app.dart:24` defaults to `goldenIndigo` and `warehouse_shell.dart:58-98` uses generic Material `NavigationBar`. | `apps/client/vite.config.ts:24`, `apps/client/src/routes/*.tsx`, `apps/client/src/components/*.tsx`, `apps/mobile/lib/app.dart:24`, `apps/mobile/lib/screens/warehouse_shell.dart:58-98` | **Open** |
| **M04** | **Medium** | Web Runtime Warning | Console logs React 19 Suspense warning (`This library called use() to suspend in a previous render...`) across `/app/*` navigations. | `apps/client/src/lib/session.tsx` / router lazy boundaries | **Open** |
| **M05** | **Medium** | Currency Exponents & Offline UX | CSV export helpers divide minor units by `100` instead of `currency.exponent`; Mobile `warehouse_count.dart` throws `CountOffline` when offline instead of showing cached offline banner. | `apps/client/src/lib/reports-api.ts:181-263`; `apps/mobile/lib/data/drift_warehouse.dart:520-652` | **Open** |
| **M06** | **Medium** | QA-02 Security Pre-Notes | (1) `consume_supervisor_approval` offline Path B trusts client JSON without server cryptographic PIN verification; (2) `get_storage_metrics` exposes DB-wide sizes to tenant admins; (3) `snapshot_daily_stock` lacks role check (cashier allowed); (4) `/app/upgrade` lacks solo-mode `beforeLoad` redirect. | `supabase/migrations/20261112000100:6`, `20261108002700:25`, `20261108002300:33`, `apps/client/src/router.tsx:199` | **Open** |
| **L01** | **Low** | Web i18n Cleanup | Inline English fallback literals in `t(key, "...")` across `bins.tsx` (114), `sales.tsx` (12), `transfers.tsx` (9), `purchasing.tsx` (5), `counts.tsx` (2), `overview.tsx` (2), `reports.tsx` (2). | Respective `apps/client/src/routes/*.tsx` | **Open** |
| **L02** | **Low** | Navigation Polish | Visiting `/app/setup` after setup completion redirects via `/app` to `/app/warehouses` if `pos.portal` in `localStorage` was previously set to `"warehouse"`. | `apps/client/src/router.tsx:132`, `apps/client/src/lib/portal.ts:109` | **Open** |

---

## 6. Post-Fix Verification Ledger

All checks below ran cleanly after the final code & migration edit (`2026-11-14`, branch `ag/work`, worktree `.claude/worktrees/ag-work`):

| Check | Command | Scope & Exact Observed Result |
| :--- | :--- | :--- |
| QA Seed & Bin Invariants | `node scripts/qa-seed.mjs` (x2) + `check_bin_stock_invariant` | Idempotent exit `0` both runs; `qa-alpha-php` `W01`: `5` rows (`0` invalid); `qa-beta-usd` `W01`: `3` rows (`0` invalid). |
| Lint | `pnpm lint` (`pnpm check`) | Exit `0` across `packages/sync`, `packages/core`, `apps/client`. |
| Typecheck | `pnpm typecheck` (`pnpm check`) | Exit `0` across `packages/sync`, `packages/core`, `apps/client`. |
| Unit Tests (`core` + `client`) | `pnpm test` (`pnpm check`) | `packages/core`: `4` files, `54` passed; `apps/client`: `36` files, `250` passed; `packages/sync`: `0` test files (`--passWithNoTests`). |
| Edge Function Tests | `pnpm test:functions` (`pnpm check`) | `1` file, `22` passed. |
| Postgres pgTAP | `pnpm test:db` (`pnpm check`) | `Files=54, Tests=4889`, `All tests successful`, `Result: PASS` (`054_qa01_functional_fixes.test.sql`: `40` assertions). |
| Mobile Analyzer & Tests + SW | `pnpm check:mobile` (`pnpm check`) | `service worker checks passed`; `flutter analyze`: `No issues found!`; `flutter test`: `617` passed (`0` failures). |
| Web Production PWA Build | `pnpm --filter @pos/client build` | Built in `2.89s`; VitePWA `generateSW` precached `84` entries (`2578.16 KiB`). |
| Playwright Critical E2E | `pnpm exec playwright test` (`e2e/qa01-critical-flows.spec.ts`) | **`7 passed (2.8m)`** against `vite preview`: Flows 1–7 all green (`0` failures, `0` skips). |
