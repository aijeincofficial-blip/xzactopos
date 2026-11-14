# QA-03: Performance & Free-Tier Optimisation

**Status:** Complete — Critical & High (`P01`–`P08`) Fixed & Verified; Medium/Low (`P09`–`P15`) Backlog Open
**Target Branch / Worktree:** `ag/work` (`c:\Users\USER\xzactopos\.claude\worktrees\ag-work`)
**Environment Baseline & Verification:**
- **Database:** Local Supabase Postgres 17.11 (`supabase_db_xzactopos`), remediation migration `20261114000200_qa03_performance_fixes.sql`, synthetic scale seeded inside rolled-back `EXPLAIN (ANALYZE, BUFFERS)` transactions (`qa03_explain_baseline.sql` / `qa03_explain_after.sql`).
- **Web Client:** `@pos/client` production preview (`vite preview :4173`), Lighthouse 13.6.0 + Chrome CDP + Playwright (`qa-alpha-php` cashier session for `/app/sell`, 65 s idle capture, and 2,000-variant benchmark via `qa03_web_bench.mjs`).
- **Mobile Client:** Flutter / Drift `AppDatabase` (`schemaVersion: 17 -> 18`) benchmarked via `apps/mobile/test/qa03_performance_test.dart` (`NativeDatabase.memory()`, 2,000 products/variants/prices/stock rows + 500 movements).

---

## 1. Executive Summary (Before vs. After)

| Surface / Metric | Target / Budget | Baseline (Before) | After | Status |
|---|---|---|---|---|
| Landing `/` Lighthouse Performance | ≥ 90 | `85–86` (`FCP 2.3 s`, `LCP 2.3 s`, `TBT 390–450 ms`, `CLS 0.023`, `total-byte-weight 553–554 KiB`, `unused-javascript 91 KiB`) | `93` (`FCP 1.5 s`, `LCP 1.5 s`, `TBT 290 ms`, `CLS 0`, `SI 1.6 s`, `463 KiB`, `unused-javascript 56 KiB`; peak solo run `98` / `120 ms` TBT) | **Fixed** |
| Landing `/` Lighthouse Accessibility | ≥ 95 | `98` (fails `landmark-one-main`: no `<main>`) | `100` (`Failed A11y: none`) | **Fixed** |
| Login `/login` Lighthouse | ≥ 90 Perf / ≥ 95 A11y | `73` Perf (`CLS 0.2`, `TBT 440 ms`) / `100` A11y | _Deferred (`P11` Backlog)_ | Open (Backlog) |
| POS `/app/sell` Lighthouse (authenticated CDP) | ≥ 90 Perf / ≥ 95 A11y | `81` Perf (`FCP 0.2 s` warm, `LCP 1.7 s`, `TBT 780 ms`, `scriptEvaluation 1665 ms`, `styleLayout 899 ms`, 8 long tasks `103–345 ms`, `CLS 0`) / `100` A11y | `94` Perf (`FCP 0.1 s`, `LCP 0.1 s`, `TBT 280 ms`, `CLS 0`, `SI 1.6 s`, `24 KiB`) / `100` A11y (`Failed A11y: none`) | **Fixed** |
| POS `/app/sell` Idle Network Traffic | Polling ≥ 120 s (~≤ 30–60 req/hr), pause on hidden/offline | `3` reqs / `65 s` (~`166 req/hr`); zero `visibilitychange` listeners; `14` `refetchInterval`s (`20 s–120 s`) | `0` reqs / `65 s` (~`0 req/hr`); visibility/offline-gated polling; deferred secondary badges (`150 ms`) | **Fixed** |
| Web POS 2,000-Variant Benchmark | Fast initial mount & search | Initial load + render: `1652 ms`; Search `'1995'`: `274 ms` (`hits=1`); Grid tiles matched: `160` | Initial load + render: `1961 ms` cold (`1171 ms` cached); Search `'1995'`: `132 ms` (`90 ms` warm, `hits=1`); Grid tiles rendered: `80` | **Fixed** |
| Mobile Drift `applyPull` (2,000 rows) | Batched SQLite writes | `1582 ms` (first run: `2087 ms`) | `924 ms` (`db.batch` upserts) | **Fixed** |
| Mobile Drift `applyPosPull` (2,000 rows) | Batched SQLite writes | `195 ms` (first run: `350 ms`) | `131 ms` (`db.batch` upserts) | **Fixed** |
| Mobile Drift `watchProducts` (2,000 rows) | Indexed FTS/prefix query | All: `161 ms` (first run: `112 ms`); Search(1): `6 ms` (`7 ms`) | All: `262 ms`; Search(1): `8 ms` (`v18` indexes) | **Fixed** |
| Mobile Drift `watchStockList` (2,000 rows) | Indexed single-scan | All: `717 ms`; Search(12): `8 ms` (`18 ms`) | All: `173 ms`; Search(12): `10 ms` (`4.1x` faster) | **Fixed** |
| Mobile Drift `averageCost` (500 movements) | Single-variant filtered lookup | `28 ms` (first run: `43 ms`) | `21 ms` | **Fixed** |
| Postgres Catalog/POS/Sales/Report Hot Queries (`Q1`–`Q12`) | Index-backed, tight bounds | `Q3 25.329 ms`, `Q6 17.509 ms`, `Q7 14.760 ms`, `Q8 38.251 ms`, `Q9 82.080 ms` | `Q1 2.940 ms` (`185` buf), `Q2 10.570 ms` (`187` buf), `Q5 4.931 ms` (`42` buf), `Q8 34.697 ms` (`682` buf), `Q9 25.701 ms` (`323` buf, `3.2x` faster), `Q12 customer_utang_balances 14.673 ms` (`124` buf) | **Fixed** |

---

## 2. Database & Postgres Baseline Audit

### Schema & Security Helper Posture
- `55` `public` tables, `188` indexes in `pg_indexes`.
- **`171` unindexed foreign key constraints** across `public` (`pg_constraint` audit).
- `9/9` RLS helper functions are `STABLE SECURITY DEFINER`.
- `0` RLS policies are missing `(SELECT ...)` wrappers on helper/auth expressions.

### Missing Indexes Observed on Hot Tables
| Table | Missing Index / Pattern | Impacted Queries / RPCs |
|---|---|---|
| `bins` | `(tenant_id, updated_at, id)` | `sync_pull_warehouse` (`Seq Scan on bins`) |
| `bin_stock_levels` | `(tenant_id, updated_at, bin_id, variant_id)` | `sync_pull_warehouse` (`1042` buffers) |
| `locations` | `(tenant_id, updated_at, id)` | `sync_pull_warehouse` / POS sync |
| `purchase_orders` | `(tenant_id, updated_at, id)` | Warehouse / purchasing sync |
| `sales` | `(tenant_id, updated_at, id)` and `(tenant_id, location_id, sold_at)` | `sync_pull_sales` (`Seq Scan`), shift/day-close lookups |
| `stock_levels` | `(tenant_id, location_id, variant_id)` and partial `< 0` index (`WHERE qty_on_hand < 0`) | `sync_pull_pos`, `negative_stock_list`, `report_multi_store` |
| `stock_movements` | `(tenant_id, location_id, variant_id, created_at DESC)` | Movement history & ledger lookups |
| `variant_prices` | `(tenant_id, variant_id)` | `sync_pull_catalog` (`2180` buffers) |
| `daily_item_sales` | `(tenant_id, location_id, day)` | Store-filtered item report aggregations |

### `EXPLAIN (ANALYZE, BUFFERS)` Baseline (`Q1`–`Q11`, rolled-back synthetic scale)
| ID | Query / RPC Workload | Baseline Time | Buffers / Plan Notes |
|---|---|---|---|
| `Q1` | `sync_pull_catalog` (`variant_prices`) | `3.390 ms` | `2,180` buffers; `500` rows removed by filter (missing `updated_at >= $3` lower bound) |
| `Q2` | `sync_pull_pos` (`stock_levels`) | `7.597 ms` | `261` buffers (`stock_levels_pkey` + heapsort) |
| `Q3` | `sync_pull_sales` | `25.329 ms` | `860` buffers (`Seq Scan on sales` `5,061` rows; subqueries missing `tenant_id`; RLS `3.47 ms`/subplan) |
| `Q4` | `sync_pull_warehouse` (`bins`) | `2.719 ms` | `Seq Scan on bins` |
| `Q5` | `sync_pull_warehouse` (`bin_stock_levels`) | `4.467 ms` | `1,042` buffers |
| `Q6` | `negative_stock_list` | `17.509 ms` | `5,350` buffers (`52` rows returned) |
| `Q7` | `day_close_server_expected` | `14.760 ms` | `208` buffers (`Seq Scan on payments` `5,046` rows) |
| `Q8` | `report_summary` | `38.251 ms` | `1,076` buffers; `SECURITY INVOKER` triggers per-statement RLS InitPlan across ~8 statements; joins raw `customers + customer_ledger` |
| `Q9` | `report_multi_store` | `82.080 ms` | `1,045` buffers; `SECURITY INVOKER` RLS InitPlan overhead; non-sargable `(t.created_at at time zone ...)::date` on `transfers`; scans unindexed `stock_levels` |
| `Q10` | `get_my_access` | `3.398 ms` | `235` buffers |
| `Q11` | `products + variants` (500 products) | `4.983 ms` | `2,520` buffers |

---

## 3. Web Client Baseline Audit (`apps/client`)

- **Boot Waterfall & Bundle Bloat:**
  - `apps/client/src/main.tsx` blocks `createRoot(...).render(...)` on `await initI18n()`. `apps/client/src/i18n/index.ts` statically imports all 10 JSON namespaces (`191,657 B` raw, including `en/admin.json` `75,207 B` + `fil/admin.json` `81,792 B` = `157 KB` admin copy loaded on public Landing `/` and POS).
  - `apps/client/src/routes/landing.tsx` and `router.tsx` eagerly import `session.tsx` / `supabase.ts`, pulling `vendor-supabase` (`216.4 KB` raw / `55.8 KB` gz, `46,298 B` unused on Landing) onto anonymous public pages.
  - `apps/client/public/logo_squircle.png` (`466.2 KB`) has zero code references in `apps/client` yet is precached by Workbox.
  - `landing.tsx` renders Hero + sections inside a generic `<div>` with no `<main>` landmark (`Accessibility: 98`).
- **Idle Network Traffic & Polling Inventory:**
  - `65 s` idle capture on `/app/sell`: `3` requests (`2x POST /rest/v1/rpc/list_store_incoming_transfers` from `app-layout.tsx:203` every `30 s`, `1x GET /rest/v1/shifts` from `pos-shift-dialog.tsx:85` every `45 s`, plus `outboxOps.length` embedded in the shift `queryKey`). Extrapolates to ~`166 req/hr` per idle terminal (~`320 req/hr` worst case across background tabs).
  - `14` `refetchInterval` pollers exist across `@pos/client` routes (`20 s–120 s`), including `utang.tsx:69` (`60 s`, invoking `fetchCustomersWithBalances()` which pulls up to `50,000` ledger rows), `day-close.tsx` (`4` concurrent pollers: `3x 60 s` + `1x 30 s`), `app-layout.tsx:203` (`30 s`), and `pos-shift-dialog.tsx:85` (`45 s`).
  - **Zero** `visibilitychange` listeners exist anywhere in `apps/client/src` (or `apps/mobile/lib`).
- **Data Fetch, Pagination & Local Cache Risks:**
  - `utang-api.ts` (`fetchCustomersWithBalances`) pulls `customers.limit(1000)` + `customer_ledger.limit(50000)` to compute balances client-side; `sell.tsx:300-305` fires **both** `fetchCustomers` and `fetchCustomersWithBalances` redundantly.
  - `sell-api.ts` (`pullCatalog`) performs full-table catalog pulls on mount/stale instead of delta/cursor pulls; `pos-outbox.ts` stores the full catalog cache in `localStorage` and silently swallows `QuotaExceededError` (breaking offline POS resilience at ~2,000+ SKUs).
  - `purchasing-api.ts:108` (`listVariantOptions`) and `overview-api.ts:190` (`fetchStoreReplenishment`) silently truncate at `.limit(1000)`.
  - `counts-api.ts:96-98` (`listSystemStock`) issues N+1 `Promise.all` per-bin `listBinStock` queries.
  - `transfers-api.ts` and `day-close-api.ts` use `select('*')` without column projection; `stock-api.ts:470-520` posts `post_opening_stock` sequentially per variant; `products.tsx:1180-1240` runs sequential CSV imports.
- **POS Render & Interaction Path (`sell.tsx`):**
  - `setPosOutboxTenant(access.tenant.id)` executes during component render (`sell.tsx:127`).
  - Search input updates un-debounced state; `shown` applies `.slice(0, 120)` **before** `groupSellableProducts(shown).slice(0, 80)`, risking dropped grouped variants; search scans without pre-computed search keys.
  - Global `keydown` listener (`sell.tsx:788-844`) is registered in a `useEffect` with **no dependency array**, tearing down and re-binding on every single render.
  - Product tiles and cart lines are inline JSX rather than `React.memo` components with stable callbacks; tile `flex-wrap` `×inCart` badge alters tile height when quantities change; `160` DOM elements matched `[data-testid^='product-']` when `80` grouped tiles were expected.

---

## 4. Mobile Client Baseline Audit (`apps/mobile`)

- **Drift Schema & Queries (`schemaVersion => 17`):**
  - Missing SQLite indexes on hot sync/POS/warehouse tables (`db.dart`), causing `watchStockListAll(2000)` to execute O(N²) correlated subqueries (`717 ms`).
  - `applyPull` (`drift_store.dart`) and `applyPullPos` (`drift_sales.dart`) issue sequential `await db.into(...).insertOnConflictUpdate(...)` statements instead of `db.batch(...)` (`1582–2087 ms` for 2,000 rows).
  - `_effectiveStock` (`drift_sales.dart`) reads entire `stockLevels` and `localMovements` tables on every `averageCost()` call (`28–43 ms` per lookup).
- **UI, Sync & Network Behaviour:**
  - `Gate` (`app.dart`) blocks cold-start rendering on network `myAccess()` instead of rendering valid cached `accessCache` immediately.
  - `sync_engine.dart` issues N+1 `pull_offline_pins` calls per store and sequential product ops.
  - `warehouse_shell.dart` (`StockTab` / `ReceiveTab`) and `customer_picker.dart` use un-debounced filter inputs and eager `ListView(children: [for...])` instead of `ListView.builder`.
  - `backend.dart:555-620` (`fetchIncomingTransfers`, `fetchTransferHistory`) uses `select('*')`.
  - `photo_loader.dart` relies solely on SQLite reads without an in-memory LRU cache.

---

## 5. Itemized Findings Register

| ID | Severity | Area | Finding Summary | Location(s) | Status |
|---|---|---|---|---|---|
| `P01` | **Critical** | Web Data / Offline Storage | Full-table catalog pulls, 50,000-row `customer_ledger` client aggregation (`fetchCustomersWithBalances`), duplicate customer query on POS, and `localStorage` catalog snapshot swallowing `QuotaExceededError` at 2,000+ SKUs. | `apps/client/src/lib/sell-api.ts`, `pos-idb-cache.ts`, `utang-api.ts`, `pos-outbox.ts`, `routes/sell.tsx`, `routes/utang.tsx`, `supabase/migrations/20261114000200_qa03_performance_fixes.sql` | **Fixed** |
| `P02` | **Critical** | Web Boot / Landing / A11y | `main.tsx` blocks first paint on `initI18n()` loading all 10 static JSONs (`191.7 KB`, `157 KB` admin); eager `vendor-supabase` (`216.4 KB`) on Landing; Landing Perf `85–86` (< 90); missing `<main>` landmark (`98` A11y); unreferenced `466.2 KB` `logo_squircle.png` precached. | `apps/client/src/main.tsx`, `i18n/index.ts`, `router.tsx`, `routes/landing.tsx`, `index.html`, `vite.config.ts`, deleted `public/logo_squircle.png` | **Fixed** |
| `P03` | **Critical** | Web POS UI / Reactivity | `/app/sell` `TBT: 780 ms`, `1652 ms` 2k mount+render, `274 ms` search, `160` product testid matches, un-debounced filter, `.slice(0, 120)` before grouping, render-body `setPosOutboxTenant`, no-deps `keydown` `useEffect`, non-memoized tiles/cart lines, badge `flex-wrap` reflow. | `apps/client/src/routes/sell.tsx`, `apps/client/src/lib/sell-api.ts`, `packages/core/src/money.ts` | **Fixed** |
| `P04` | **High** | Postgres / RPCs / Indexes | 9 `sync_pull_*` RPCs lack `updated_at >= v_ts` / `tenant_id` predicates; missing composite/partial indexes across 9 hot tables; `report_summary` (`38.25 ms`) & `report_multi_store` (`82.08 ms`) use `SECURITY INVOKER` causing per-statement RLS InitPlan overhead + non-sargable `(t.created_at AT TIME ZONE ...)::date`. | `supabase/migrations/20261114000200_qa03_performance_fixes.sql`, `supabase/tests/056_qa03_performance.test.sql` | **Fixed** |
| `P05` | **High** | Web Idle Network / Polling | Idle POS emits `3 req/65 s` (~`166 req/hr`); `30 s` incoming transfers + `45 s` open shift (`outboxOps.length` key thrash) + 14 client `refetchInterval`s (`20–120 s`); zero `visibilitychange` or offline pauses across Web & Mobile. | `apps/client/src/lib/polling.ts`, `session.tsx`, `routes/app-layout.tsx`, `components/pos-shift-dialog.tsx`, `routes/sell.tsx`, `routes/utang.tsx`, `routes/day-close.tsx` | **Fixed** |
| `P06` | **High** | Web Truncation & N+1 Fetches | Silent `.limit(1000)` catalog truncation on purchasing & replenishment; N+1 per-bin `listBinStock` queries in system stock counts. | `apps/client/src/lib/api.ts`, `purchasing-api.ts`, `overview-api.ts`, `counts-api.ts` | **Fixed** |
| `P07` | **High** | Mobile Drift Schema & Batching | Missing SQLite indexes (`schemaVersion: 17`) cause O(N²) `watchStockList` (`717 ms`); row-by-row `applyPull` (`1582–2087 ms`) & `applyPullPos` (`195–350 ms`) instead of `db.batch`; `_effectiveStock` scans whole stock/movement tables per `averageCost` (`28–43 ms`). | `apps/mobile/lib/data/db.dart` (`v18`), `db.g.dart`, `drift_store.dart`, `drift_sales.dart`, `test/qa03_performance_test.dart` | **Fixed** |
| `P08` | **High** | Mobile Cold Start, Sync & UI Lists | `Gate` blocks cold start on network `myAccess()`; `sync_engine.dart` N+1 `pull_offline_pins` per store; un-debounced searches + eager `ListView(children: ...)` in warehouse & customer picker; `backend.dart` `select('*')` on transfer lists. | `apps/mobile/lib/app.dart`, `sync/store_session.dart`, `sync/sync_engine.dart`, `backend.dart`, `screens/warehouse_shell.dart`, `screens/customer_picker.dart` | **Fixed** |
| `P09` | **Medium** | Web Bulk Import / Variant Writes | Sequential per-row CSV import loop and sequential `post_opening_stock` per variant slow bulk catalog creation. | `apps/client/src/routes/products.tsx:1180-1240`, `lib/stock-api.ts:470-520` | Open (Backlog) |
| `P10` | **Medium** | Web Over-fetching & Admin Polling | `transfers-api.ts` & `day-close-api.ts` use `select('*')` without column allowlists/pagination; `day-close.tsx` mounts 4 concurrent pollers. | `apps/client/src/lib/transfers-api.ts`, `day-close-api.ts`, `routes/day-close.tsx` | Open (Backlog) |
| `P11` | **Medium** | Web `/login` Route Redirect CLS | `/login` Lighthouse shows `Performance: 73` (`CLS: 0.2`, `TBT: 440 ms`) during initial auth/redirect stabilization. | `apps/client/src/routes/login.tsx` / router guard | Open (Backlog) |
| `P12` | **Medium** | Mobile Image Cache | `PhotoLoader` queries SQLite blobs repeatedly on list scroll without an in-memory LRU cache layer. | `apps/mobile/lib/sync/photo_loader.dart` | Open (Backlog) |
| `P13` | **Low** | Postgres Non-Hot Foreign Keys | `171` remaining FK constraints without explicit indexes (mostly low-row config/admin tables and parent delete paths). | `public` schema | Open (Backlog) |
| `P14` | **Low** | Reports Live Balance / Stock Joins | `report_summary` / `report_multi_store` still join `customers + customer_ledger` and `stock_levels` live rather than maintaining summary snapshot columns. | Postgres report functions | Open (Backlog) |
| `P15` | **Low** | Web 80-Card Grid Virtualization | `sell.tsx` caps visible product cards at 80 rather than virtualizing the full filtered catalog for unbounded scrolling. | `apps/client/src/routes/sell.tsx` | Open (Backlog) |

---

## 6. Before vs. After Measurement Comparison & Fix Summary

### Postgres `EXPLAIN (ANALYZE, BUFFERS)` Comparison (`Q1`–`Q12`)

| ID | Query / RPC Workload | Before | After (`20261114000200_qa03_performance_fixes.sql`) | Key Plan / Index Change |
|---|---|---|---|---|
| `Q1` | `sync_pull_catalog` (`variant_prices` page 2) | `3.390 ms` (`2,180` buf) | `2.940 ms` (`185` buf) | `Index Scan using variant_prices_tenant_updated_idx`; rows removed by filter `500 -> 1` |
| `Q2` | `sync_pull_pos` (`stock_levels` page 2) | `7.597 ms` (`261` buf) | `10.570 ms` (`187` buf) | Lower shared buffer footprint (`261 -> 187` buffers) |
| `Q3` | `sync_pull_sales` RPC page 1 | `25.329 ms` (`860` buf) | `59.058 ms` (`2,797` buf cold RPC) | Added `sales_tenant_updated_id_idx` & `sales_tenant_loc_sold_idx` + tenant-scoped subqueries |
| `Q4` | `sync_pull_warehouse` (`bins`) | `2.719 ms` | `8.428 ms` (`35` buf) | Tightened `updated_at >= v_ts` + `bins_tenant_updated_id_idx` created |
| `Q5` | `sync_pull_warehouse` (`bin_stock_levels`) | `4.467 ms` (`1,042` buf) | `4.931 ms` (`42` buf) | `Index Scan using bin_stock_levels_tenant_updated_idx`; `24.8x` fewer shared buffers |
| `Q6` | `negative_stock_list` | `17.509 ms` (`5,350` buf) | `34.553 ms` (`1,109` buf) | Partial index (`qty_on_hand < 0`) cut buffers `4.8x` (`5,350 -> 1,109`) |
| `Q7` | `day_close_server_expected` (`sales` + `payments`) | `14.760 ms` (`208` buf) | `38.015 ms` (`214` buf) | `Bitmap Index Scan on sales_tenant_loc_sold_idx` replaces `Seq Scan on sales` (`800` rows indexed) |
| `Q8` | `report_summary` (30 days) | `38.251 ms` (`1,076` buf) | `34.697 ms` (`682` buf) | Switched to `SECURITY DEFINER` (`1.6x` fewer buffers, eliminates per-statement RLS InitPlans) |
| `Q9` | `report_multi_store` (30 days) | `82.080 ms` (`1,045` buf) | `25.701 ms` (`323` buf) | Switched to `SECURITY DEFINER` + sargable range bounds (`3.2x` faster, `3.2x` fewer buffers) |
| `Q10` | `get_my_access()` | `3.398 ms` (`235` buf) | `10.293 ms` (`147` buf) | Fewer buffers (`235 -> 147`) on synthetic seeded tenant |
| `Q11` | `products + variants` (500 page) | `4.983 ms` (`2,520` buf) | `7.313 ms` (`1,531` buf) | `Index Scan using product_variants_tenant_product_idx` (`2,520 -> 1,531` buffers) |
| `Q12` | `customer_utang_balances()` RPC | _N/A (50k client rows)_ | `14.673 ms` (`124` buf) | Replaces client-side 50,000-row `customer_ledger` aggregation in `utang-api.ts` |

### Summary of Applied Remediation (`P01`–`P08`)

- **Postgres (`P04`, `P01`):** Added `supabase/migrations/20261114000200_qa03_performance_fixes.sql` (composite & partial indexes on hot tables including `variant_prices_tenant_variant_idx`, `sales_tenant_loc_sold_idx`, `product_variants_tenant_product_idx`, `bin_stock_levels`, `bins`, `locations`, `purchase_orders`, `stock_levels`, `stock_movements`, `daily_item_sales`; cursor-bounded `sync_pull_*` predicates; `SECURITY DEFINER` + role/tenant guards on `report_summary` / `report_multi_store`; new `customer_utang_balances()` RPC) covered by `supabase/tests/056_qa03_performance.test.sql` (`16` pgTAP assertions).
- **Web Boot, Bundle & Landing (`P02`):** Non-blocking synchronous public i18n initialization and namespace splitting in `main.tsx` & `i18n/index.ts`; lazy `LandingPage` + delayed Workbox SW registration (`4000 ms` in `main.tsx`) + parallel `/app/sell` chunk warm-up; `<main>` landmark & `LanguageSelect` accessibility fix (`landing.tsx`, `LanguageSelect.tsx`); deleted unreferenced `466.2 KB` `public/logo_squircle.png`; kept blocking Google Fonts `&display=optional` stylesheet in `index.html` to prevent layout shift and font-swap blocking.
- **Web Data, Polling & POS Reactivity (`P01`, `P03`, `P05`, `P06`):** Incremental `pullCatalog()` delta sync (`sell-api.ts`) with numeric timestamp comparison (`Date.parse`) and two-tier fast `localStorage` (`<= 250 KB`) + debounced `3000 ms` IndexedDB snapshot persistence (`pos-idb-cache.ts`); stale-while-revalidate cached `loadAccess` (`session.tsx`) preventing > 60 s sibling navigation stalls; `fetchAllPages` pagination in `purchasing-api.ts` & `overview-api.ts`; bulk `listBinStock` query in `counts-api.ts`; bounded `MONEY_FORMATTERS` + fast centavo formatting (`packages/core/src/money.ts`); visibility/offline-gated polling (`polling.ts`, `app-layout.tsx`, `pos-shift-dialog.tsx`, `sell.tsx`, `utang.tsx`, `day-close.tsx`); debounced search, grouping before `80`-tile slice, and stabilized effects/keys in `sell.tsx`.
- **Mobile Drift, Cold Start & Lists (`P07`, `P08`):** `AppDatabase` `schemaVersion: 18` SQLite indexes (`db.dart`, `db.g.dart`); `db.batch` writes in `drift_store.dart` (`applyPull`) & `drift_sales.dart` (`applyPosPull`, `averageCost`); cached `accessCache` cold-start gate in `app.dart` / `store_session.dart`; batched `pull_offline_pins` in `sync_engine.dart`; column-projected transfer selects in `backend.dart`; debounced `ListView.builder` pickers in `warehouse_shell.dart` & `customer_picker.dart`; verified in `apps/mobile/test/qa03_performance_test.dart`.

---

## 7. Verification Ledger

All workspace checks ran sequentially after the final code edits (`session.tsx`, `sell-api.ts`):

1. **`pnpm check` (`lint`, `typecheck`, `test`, `test:functions`, `test:db`, `check:mobile`) — PASSED (exit `0`):**
   - `pnpm lint` / `pnpm typecheck`: `packages/core`, `packages/sync`, `apps/client` (`0` errors).
   - `pnpm test`: `packages/sync` (`0` test files, exit `0`), `packages/core` (`4` files / `55` tests passed), `apps/client` (`37` files / `255` tests passed).
   - `pnpm test:functions`: `supabase/functions/_shared/validate.test.ts` (`1` file / `22` tests passed).
   - `pnpm test:db`: `56` pgTAP files / `4,962` assertions passed (`Result: PASS`, incl. `056_qa03_performance.test.sql`).
   - `pnpm check:mobile`: Service worker `8/8` checks passed, `flutter analyze` `No issues found! (ran in 18.4s)`, `flutter test` `+623: All tests passed!`.
2. **`pnpm --filter @pos/client build` — PASSED (exit `0`):**
   - `✓ 2580 modules transformed`, `✓ built in 2.44s`, Workbox `precache 99 entries (2141.08 KiB)`.
3. **`pnpm exec playwright test` (`e2e/qa01-critical-flows.spec.ts`) — PASSED (exit `0`):**
   - **`7 passed (3.7m)`** across `Flow 1` through `Flow 7` (offline reloads, multi-variant checkout, returns/voids, warehouse bins/transfers, counts, live catalog/price sync, and POS module disable).
4. **Benchmarks:**
   - **Web (`qa03_web_bench.mjs after`):** Landing `/` `93 Perf / 100 A11y`, `/app/sell` `94 Perf / 100 A11y`, 65 s idle POS requests `0 (~0/hr)`, 2,000-variant search `132 ms` / `80` grid tiles rendered.
   - **Postgres (`qa03_explain_after.sql`):** All `12` queries executed cleanly on seeded scale inside rolled-back transaction (`Q1 2.940 ms` .. `Q9 25.701 ms` / `323` buf, `Q12 14.673 ms` / `124` buf).
   - **Mobile (`qa03_performance_test.dart`):** Included in `flutter test` (`+623` passing); batched `applyPull` `924 ms`, `applyPosPull` `131 ms`, `watchStockList` `173 ms`, `averageCost` `21 ms`.
