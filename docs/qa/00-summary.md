# QA Final Wrap-Up Summary (`QA-04`)

**Date:** 2026-11-14 | **Branch:** `ag/work` (worktree `.claude/worktrees/ag-work`) | **Scope:** Full verification across QA-01 ([01-functional.md](01-functional.md)), QA-02 ([02-security.md](02-security.md)), QA-03 ([03-performance.md](03-performance.md)), and [design.md](../design.md) §13.

> [!IMPORTANT]
> **All 25 Critical & High findings (`F01`–`F11`, `S01`–`S06`, `P01`–`P08`) are `Fixed` and backed by automated tests.** Every verification gate (`pnpm check`, Web PWA build + secret scan, `7/7` Playwright E2E flows including offline reload, `supabase db advisors`, `supabase db lint` with **`0` errors**, and `pnpm audit --prod`) passed after the final edits. **Do not deploy** until the remaining policy/deploy items in §4 (GitHub keep-alive & DB backup secrets configured; Android release keystore configured locally; Firebase Hosting config & password minimum 8 ready in-repo; confirm `S11`/`S07` policy items plus deploy-time Auth/`ALLOWED_ORIGINS` & `xzacto.store` DNS cutover) are resolved.

---

## 1. Area Pass/Fail Scorecard

| Area | Source Report | Critical & High Status | Backlog Remaining | Overall Assessment |
| :--- | :--- | :--- | :--- | :--- |
| **QA-01 — Functional (Every Screen, Every Role)** | [01-functional.md](01-functional.md) | `11/11` **Fixed** (`F01`–`F11`) | `5` Medium (`M01`–`M05`), `2` Low (`L01`–`L02`), `M06` deduplicated into QA-02 | **PASS** (all Critical/High fixed; `7/7` E2E critical flows green) |
| **QA-02 — Security, RLS & Money Rules** | [02-security.md](02-security.md) | `6/6` **Fixed** (`S01`–`S06`) | `7` Medium (`S07`–`S13`), `1` Low (`S14`) | **PASS** (`55/55` RLS tables, `0` anon grants, `0` missing `search_path`, `0` WARN/ERROR advisors) |
| **QA-03 — Performance & Free-Tier Optimisation** | [03-performance.md](03-performance.md) | `8/8` **Fixed** (`P01`–`P08`) | `4` Medium (`P09`–`P12`), `3` Low (`P13`–`P15`) | **PASS** (`report_multi_store` `3.2x` faster, idle POS `0 req/65 s`, `/` `93`, `/app/sell` `94` Perf) |
| **`design.md` §13 Self-Check** | [design.md](../design.md) §13, [01-functional.md](01-functional.md) §3 | N/A (tracked as Medium drift) | Captured under `M01`, `M02`, `M03` | **CONDITIONAL PASS** (core UI kit, typography links, `en`/`fil` parity, `<SyncStatusPill>`, offline support pass; palette/manifest, `tabular-nums` on 12/28 routes, printable `.receipt`, currency symbol, and mobile `360px`/`768px` overflows tracked as backlog) |
| **Final Automated Gate (`QA-04`)** | See §1.1 below | All checks clean post-edit | None | **PASS** |

### 1.1 Final Verification Gate Results (Post-Edit Run)

| Gate | Command | Observed Result |
| :--- | :--- | :--- |
| **Multi-Tenant Seed Idempotency** | `node scripts/qa-seed.mjs` (x2 consecutively) | Exit `0` both runs (`qa-alpha-php` `PHP` + `qa-beta-usd` `USD`) |
| **Lint & Typecheck** | `pnpm lint` & `pnpm typecheck` (`pnpm check`) | Exit `0` across `packages/core`, `packages/sync`, `apps/client` |
| **JS/TS Unit Tests** | `pnpm test` (`pnpm check`) | `@pos/core`: `4` files / `55` passed; `@pos/client`: `39` files / `260` passed; `@pos/sync`: `0` test files (`--passWithNoTests`, exit `0`) |
| **Edge Function Tests** | `pnpm test:functions` (`pnpm check`) | `1` file (`_shared/validate.test.ts`), `22` passed |
| **Postgres pgTAP Suite** | `pnpm test:db` (`pnpm check`) | `Files=56, Tests=4964 — Result: PASS` |
| **Mobile Checks & Tests** | `pnpm check:mobile` (`pnpm check`) | `8/8` service-worker checks passed; `flutter analyze`: `No issues found!`; `flutter test`: `+623: All tests passed!` |
| **Web Production Build & Secret Scan** | `pnpm --filter @pos/client build` + `dist/` regex scan | `✓ 2580 modules transformed`, `✓ built in 2.81s`, `PWA v2.0.0`, `precache 98 entries (2140.64 KiB)`; zero `service_role` or DB credential matches (only local `anon` JWT `role:"anon"` present) |
| **Playwright E2E Suite** | `pnpm exec playwright test` (`e2e/qa01-critical-flows.spec.ts`) | **`7/7 passed`** — Flows 1–7 all green (including offline reload Flow 2, partial returns Flow 3, and live poll Flow 6) |
| **Supabase Advisors (Local)** | `pnpm exec supabase db advisors --local --type all --level warn` / `info` | `0` WARN/ERROR (`No issues found`); `136` INFO (`91` `unindexed_foreign_keys`, `42` `unused_index`, `3` intentional `rls_enabled_no_policy` on internal tables `processed_ops`, `sale_counters`, `supervisor_approvals`) |
| **Supabase SQL Linter** | `pnpm exec supabase db lint --local -s public` | Exit `0`, `0` errors across `public` schema (`op_return_sale_items` `_ret_lines` resolved in `20261114000300`; `20` pre-existing warning functions remain) |
| **Dependency Audit** | `pnpm audit --prod` | Exit `0`: `No known vulnerabilities found` |

### 1.2 `design.md` §13 Self-Check Breakdown

- **Verified compliant**: Tight Night Market hierarchy & headline styles; shared UI kit (`apps/client/src/ui/`, tested in `ui.test.tsx`); Google Font links (`&display=optional`) and `theme-color="#0F1A16"` in `apps/client/index.html`; `en`/`fil` translation parity (`locales.test.ts` `12/12`, `arb_parity_test.dart`); `<SyncStatusPill>` & working offline outbox/cache on Web & Mobile.
- **Logged drift (`M01`–`M03` Open Backlog)**: `apps/client/vite.config.ts:25-26` PWA manifest retains `theme_color: "#3419d2"` / `background_color: "#fbfaf9"`; `apps/mobile/lib/app.dart:25` defaults `initialPalette` to `AppPalette.goldenIndigo`; `12` of `28` Web route files (`app-layout.tsx`, `counts.tsx`, `locations.tsx`, `modules.tsx`, `platform.tsx`, `public.tsx`, `purchasing.tsx`, `settings.tsx`, `setup.tsx`, `transfers.tsx`, `upgrade.tsx`, `users.tsx`) lack `tabular-nums`/`MoneyText`; printable slips (`receipt-slip.tsx`, `shift-slip.tsx`) lack `.receipt` zig-zag edge / `tabular-nums`; raw `₱` appears on non-PHP tenant `/app/settings` & denomination dialogs (`M01`); `/app/bins` overflows at `360px` (`+477px`) and `768px` (`+381px`) (`M02`).

---

## 2. Critical & High Findings Traceability (`25/25 Fixed`)

Every `Critical` and `High` item across QA-01, QA-02, and QA-03 is `Fixed` and backed by at least one automated test:

| ID | Severity | Summary | Primary Fix Location(s) | Backing Automated Test(s) | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `F01` | Critical | Offline reload while signed in wiped session | `apps/client/src/lib/session.tsx`, `router.tsx` | `apps/client/src/lib/session.test.ts`; `e2e/qa01-critical-flows.spec.ts` (`Flow 2`) | **Fixed** |
| `F02` | High | Offline optimistic stock did not decrement on queued sales | `apps/client/src/lib/pos-outbox.ts`, `sale-math.ts` | `apps/client/src/lib/pos-outbox.test.ts` | **Fixed** |
| `F03` | High | Multi-variant catalog creation, sync, and POS variant picker missing | `20261113000100_qa01_functional_fixes.sql`; Web `products.tsx`, `sell.tsx`, `stock-api.ts`, `sell-api.ts`; Mobile `drift_store.dart`, `product_form_screen.dart`, `sell_screen.dart` | `supabase/tests/054_qa01_functional_fixes.test.sql`; `apps/client/src/lib/stock-api.test.ts`; `apps/mobile/test/variants_test.dart`; `e2e/qa01-critical-flows.spec.ts` (`Flow 1`, `Flow 6`) | **Fixed** |
| `F04` | High | `pull_offline_pins(null)` called nonexistent `resolve_caller_store` | `20261113000100_qa01_functional_fixes.sql` | `supabase/tests/054_qa01_functional_fixes.test.sql` | **Fixed** |
| `F05` | High | Disabling `pos` module left Web nav/routes and POS pull RPCs exposed | `20261113000100_qa01_functional_fixes.sql`; `apps/client/src/lib/portal.ts`, `router.tsx`, `app-layout.tsx` | `supabase/tests/054_qa01_functional_fixes.test.sql`; `apps/client/src/lib/portal.test.ts`; `apps/mobile/test/role_permissions_test.dart`; `e2e/qa01-critical-flows.spec.ts` (`Flow 7`) | **Fixed** |
| `F06` | High | Cashiers could open `/app/expenses`, `/app/reports`, and Close Day submit | `apps/client/src/lib/portal.ts`, `router.tsx`, `routes/app-layout.tsx`, `routes/day-close.tsx` | `apps/client/src/lib/portal.test.ts` (`F06` cashier route/Close Day guard unit test) | **Fixed** |
| `F07` | High | Mobile ignored `modules.pos`, granted supervisor write/upgrade UI to wrong roles | `apps/mobile/lib/app.dart`, `store_session.dart`, shells/screens | `apps/mobile/test/role_permissions_test.dart`, `apps/mobile/test/cash_drop_test.dart` | **Fixed** |
| `F08` | High | Warehouse bin & transfer RPCs lacked location/module/role guards | `20261113000100_qa01_functional_fixes.sql` | `supabase/tests/054_qa01_functional_fixes.test.sql`, `055_qa02_security_audit.test.sql` | **Fixed** |
| `F09` | High | Web Day Close drawer expected cash omitted service ledger cash effect | `apps/client/src/routes/day-close.tsx`, `lib/day-close-math.ts` | `apps/client/src/lib/day-close-math.test.ts` | **Fixed** |
| `F10` | High | Non-superadmin users saw empty transfer destinations due to strict `locations_read` | `20261113000100_qa01_functional_fixes.sql` (`list_transfer_destinations`); `transfers.tsx`; Mobile `backend.dart` | `supabase/tests/054_qa01_functional_fixes.test.sql`; `e2e/qa01-critical-flows.spec.ts` (`Flow 4`) | **Fixed** |
| `F11` | High | Web catalog updates invisible for 5 s via `sync_pull_catalog` watermark holdback | `apps/client/src/lib/sell-api.ts` | `apps/client/src/lib/sell-api.test.ts`; `e2e/qa01-critical-flows.spec.ts` (`Flow 6`) | **Fixed** |
| `S01` | Critical | Offline supervisor approval trusted client JSON without HMAC verifier & leaked hashes | `20261114000100_qa02_security_fixes.sql`; `packages/core/src/pin.ts`; Web `offline-pin-api.ts`, `supervisor-pin-dialog.tsx`; Mobile `pin.dart`, `pin_auth.dart`, `supervisor_pin*.dart` | `supabase/tests/055_qa02_security_audit.test.sql` (`[32]-[41]`), `030`, `051`, `054`; `packages/core/src/pin.test.ts`; `apps/client/src/lib/security-controls.test.ts`; `apps/mobile/test/supervisor_pin_test.dart` | **Fixed** |
| `S02` | Critical | `op_record_sale` trusted client `unit_price` / `unit_cost` without discount cap enforcement | `20261114000100_qa02_security_fixes.sql` (`op_record_sale`) | `supabase/tests/055_qa02_security_audit.test.sql` (`[42]-[51]`) | **Fixed** |
| `S03` | High | `get_storage_metrics()` exposed cluster DB metrics to non-platform tenant admins | `20261114000100_qa02_security_fixes.sql`; `maintenance-api.ts`, `settings.tsx`, `platform.tsx` | `supabase/tests/032_free_tier_operations.test.sql`, `055_qa02_security_audit.test.sql` (`[14]-[17]`) | **Fixed** |
| `S04` | High | Missing RPC role/module/active checks (`snapshot_daily_stock`, `report_multi_store`, `health_ping`, sync pulls, `devices` RLS) | `20261114000100_qa02_security_fixes.sql` | `supabase/tests/055_qa02_security_audit.test.sql` (`[11]-[31]`), `028`, `031`, `054` | **Fixed** |
| `S05` | High | Shared-device sign-out left prior user storage/PIN verifiers accessible | Web `api.ts`, `main.tsx`, `app-layout.tsx`; Mobile `local_store.dart`, `drift_store.dart`, `store_session.dart`, `app.dart` | `apps/client/src/lib/security-controls.test.ts`; `apps/mobile/test/supervisor_pin_test.dart` | **Fixed** |
| `S06` | High | Web offline PIN fallback allowed non-network errors, unprivileged PINs, and unlimited attempts | `apps/client/src/lib/offline-pin-api.ts`, `supervisor-pin-dialog.tsx` | `apps/client/src/lib/security-controls.test.ts` (`4/4`) | **Fixed** |
| `P01` | Critical | Full-table catalog pulls, 50k client ledger sum, and `QuotaExceededError` snapshot drops | `20261114000200_qa03_performance_fixes.sql` (`customer_utang_balances`); `sell-api.ts`, `pos-idb-cache.ts`, `utang-api.ts`, `session.tsx` | `supabase/tests/056_qa03_performance.test.sql`; `apps/client/src/lib/sell-api.test.ts` | **Fixed** |
| `P02` | Critical | Blocking `initI18n()`, eager `vendor-supabase` on Landing, `<main>` a11y, oversized precache | `main.tsx`, `i18n/index.ts`, `router.tsx`, `landing.tsx`, `index.html`, `vite.config.ts` | `apps/client/src/routes/landing.test.tsx`; `apps/client/src/i18n/locales.test.ts`; `@pos/client` Vite build | **Fixed** |
| `P03` | Critical | Web POS `/app/sell` high TBT, slow 2k search, stale effects, unbounded formatters | `routes/sell.tsx`, `lib/sell-api.ts`, `packages/core/src/money.ts` | `packages/core/src/money.test.ts`; `e2e/qa01-critical-flows.spec.ts` (`Flow 1`, `Flow 2`, `Flow 6`) | **Fixed** |
| `P04` | High | Missing cursor predicates/indexes across hot tables & `SECURITY INVOKER` report RLS overhead | `20261114000200_qa03_performance_fixes.sql` | `supabase/tests/056_qa03_performance.test.sql` (`16/16`) | **Fixed** |
| `P05` | High | Unthrottled Web idle polling (`3 req/65 s`) without visibility/offline pause | `apps/client/src/lib/polling.ts`, `session.tsx`, `app-layout.tsx`, `pos-shift-dialog.tsx`, `sell.tsx`, `utang.tsx`, `day-close.tsx` | `apps/client/src/lib/polling.test.ts` (`resolvePollInterval` floor & hidden/offline pause) | **Fixed** |
| `P06` | High | Silent `.limit(1000)` catalog truncation & N+1 `listBinStock` counts queries | `apps/client/src/lib/api.ts` (`fetchAllPages`), `purchasing-api.ts`, `overview-api.ts`, `counts-api.ts` | `apps/client/src/lib/api.test.ts` (`fetchAllPages` pagination, `maxRows`, `ApiError`) | **Fixed** |
| `P07` | High | Mobile missing SQLite indexes (`v17`), non-batched pulls, full-table `averageCost` scans | `apps/mobile/lib/data/db.dart` (`v18`), `drift_store.dart`, `drift_sales.dart` | `apps/mobile/test/qa03_performance_test.dart` | **Fixed** |
| `P08` | High | Mobile network-blocking cold start, N+1 pin pulls, eager `ListView`, `select('*')` transfers | `apps/mobile/lib/app.dart`, `store_session.dart`, `sync_engine.dart`, `backend.dart`, `warehouse_shell.dart`, `customer_picker.dart` | `apps/mobile/test/qa03_performance_test.dart` | **Fixed** |

---

## 3. Prioritised Medium & Low Backlog (Deduplicated)

> [!NOTE]
> QA-01 pre-note `M06` is deduplicated out of the table below: items 1–3 were resolved in `S01`, `S03`, and `S04`, and item 4 (`/app/upgrade` route guard) is tracked under **`S11`**. All `22` remaining open items across QA-01..QA-03 are prioritized below.

### Priority 1 — Pre-Launch / Launch-Week Hardening

| ID | Severity | Source | Area & Issue | Where |
| :--- | :--- | :--- | :--- | :--- |
| `S09` | Medium | QA-02 | Firebase Hosting config (`firebase.json`, `.firebaserc` for `xzacto-403cc`) added with CSP, HSTS, `nosniff`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, `no-cache` shell/SW rules; pending deploy & `xzacto.store` DNS cutover | `firebase.json`, `.firebaserc`, `apps/client/index.html` |
| `S10` | Medium | QA-02 | Password minimum `8` aligned in `supabase/config.toml`, Web, & Mobile; still configure hosted Auth min length `8`, Edge `ALLOWED_ORIGINS` (`https://xzacto.store`), & `invite_user` `redirect_to` strictness | `supabase/config.toml:183`, `apps/client/src/lib/schemas.ts`, `supabase/functions/_shared/http.ts`, `invite_user/index.ts` |
| `S11` | Medium | QA-02 | `/app/upgrade` lacks solo-mode/`superadmin` `beforeLoad` route guard (`M06` #4); review `product-photos` read policy on suspended tenants | `apps/client/src/router.tsx:229`, `20261108000400_product_photos.sql` |
| `S08` | Medium | QA-02 | Incomplete CSV formula injection escaping across Web reports & Mobile (`export.dart` omits leading `-`, `\t`, `\r`) | `apps/client/src/lib/csv-helper.ts:29`, `apps/mobile/lib/core/export.dart:12` |
| `S07` | Medium | QA-02 | `op_return_sale_items` accepts refund tender (`cash`, `ewallet`, `card`) without checking original tender (`utang` sales); `sales` lacks per-sale currency/FX snapshot columns | `supabase/migrations/20261111000100_partial_returns.sql:188-194`, `sales` schema |

### Priority 2 — UX, Formatting & Multi-Currency Polish

| ID | Severity | Source | Area & Issue | Where |
| :--- | :--- | :--- | :--- | :--- |
| `M01` | Medium | QA-01 | Hardcoded `₱` symbol on non-PHP tenants (`qa-beta-usd` on `/app/settings`), plus PHP-only denomination sheets & `Math.round(n * 100)` | `apps/client/src/locales/{en,fil}/admin.json:831`, `customer-statement-dialog.tsx`, `denomination-counter-dialog.tsx`, `denomination_sheet.dart`, `app_{en,fil}.arb`, `product_form_screen.dart` |
| `M05` | Medium | QA-01 | CSV exports divide minor units by `100` instead of currency exponent; Mobile `warehouse_count.dart` throws `CountOffline` offline instead of showing cached offline banner | `apps/client/src/lib/reports-api.ts:181-263`, `apps/mobile/lib/data/drift_warehouse.dart:520-652` |
| `M02` | Medium | QA-01 | Web horizontal overflow at `360px`/`768px` (`/app/bins` `+477px`/`+381px`, `/app` `+26px`, `/app/settings` `+26px`, `/app/reports` `+12px`, `/app/transfers` `+4px`) & clipped nav pills | `apps/client/src/routes/bins.tsx`, `settings.tsx`, `app-layout.tsx`, `reports.tsx`, `transfers.tsx` |
| `M03` | Medium | QA-01 | Remaining `design.md` §13 drifts: `vite.config.ts` `theme_color: "#3419d2"`, Mobile `app.dart` default `goldenIndigo`, `12/28` routes missing `tabular-nums`, `.receipt` zig-zag missing on slips, custom sync pill in `sell.tsx`, raw symbols/Tailwind classes | `apps/client/vite.config.ts:25-26`, `routes/*.tsx`, `components/*.tsx`, `apps/mobile/lib/app.dart:25`, `warehouse_shell.dart` |
| `P11` | Medium | QA-03 | `/login` Lighthouse `Performance: 73` (`CLS: 0.2`, `TBT: 440 ms`) during initial auth/redirect stabilization | `apps/client/src/routes/login.tsx`, `router.tsx` |
| `M04` | Medium | QA-01 | Dev-mode React 19 Suspense warning on `/app/*` navigation | `apps/client/src/lib/session.tsx` / router lazy boundaries |

### Priority 3 — Scale Optimisation, Deep Hardening & Code Hygiene

| ID | Severity | Source | Area & Issue | Where |
| :--- | :--- | :--- | :--- | :--- |
| `P09` | Medium | QA-03 | Sequential CSV bulk import loop & per-variant `post_opening_stock` writes | `apps/client/src/routes/products.tsx:1180-1240`, `lib/stock-api.ts:470-520` |
| `P10` | Medium | QA-03 | `transfers-api.ts` & `day-close-api.ts` `select('*')` over-fetching; 4 concurrent pollers in `day-close.tsx` | `apps/client/src/lib/transfers-api.ts`, `day-close-api.ts`, `routes/day-close.tsx` |
| `P12` | Medium | QA-03 | Mobile `PhotoLoader` queries SQLite blobs without an in-memory LRU cache layer | `apps/mobile/lib/sync/photo_loader.dart` |
| `S12` | Medium | QA-02 | `supabase db lint` `0` errors (`_ret_lines` resolved in `20261114000300`), `20` pre-existing warning functions remain; review read-only `SECURITY DEFINER` RPCs vs `SECURITY INVOKER` | `public` schema functions |
| `S13` | Medium | QA-02 | `004_tenant_isolation_matrix.test.sql` has `own_rows = 0` on 5 warehouse bin/pick tables (all 55 tables are independently covered in `055_qa02_security_audit.test.sql`) | `supabase/tests/004_tenant_isolation_matrix.test.sql:200-525` |
| `S14` | Low | QA-02 | Increase offline PIN PBKDF2 default iterations (`20,000 -> 100,000+` after low-end tablet benchmark) and migrate Mobile verifier cache to `flutter_secure_storage` | `20261108001200_expense_supervisor_approval.sql:92`, `offline-pin-api.ts`, `pin_auth.dart` |
| `P13` | Low | QA-03 | Remaining non-hot foreign keys without explicit indexes (`91` flagged in current local `db advisors`) | `public` schema |
| `P14` | Low | QA-03 | `report_summary` / `report_multi_store` still join live `customers + customer_ledger` & `stock_levels` rather than snapshot summary columns | Postgres report RPCs |
| `P15` | Low | QA-03 | `sell.tsx` caps visible grid at 80 cards rather than virtualized unbounded scrolling | `apps/client/src/routes/sell.tsx` |
| `L01` | Low | QA-01 | Inline English fallback strings in `t(key, "...")` calls (`bins.tsx` 114, `sales.tsx` 12, `transfers.tsx` 9, `purchasing.tsx` 5, `counts.tsx` 2, `overview.tsx` 2, `reports.tsx` 2) | `apps/client/src/routes/*.tsx` |
| `L02` | Low | QA-01 | `/app/setup` redirects via `/app` to `/app/warehouses` after completion if stale `pos.portal = "warehouse"` remains in `localStorage` | `apps/client/src/router.tsx`, `lib/portal.ts` |

---

## 4. Risks & Owner Actions Required Before Deploy

1. **GitHub Actions Secrets & Keep-Alive Verification (`.github/workflows/keep-alive.yml` & `backup.yml`):**
   Migration `20261114000300_qa04_keepalive_and_lint_fix.sql` and `.github/workflows/keep-alive.yml` (`d032efb`, supporting both `sb_secret_` and legacy JWT keys) are pushed to `origin/main` (`aijeincofficial-blip/xzactopos`). `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `DB_URL` are configured and `backup.yml` passed green on GitHub; run `keep-alive.yml` once after pushing the `59` migrations to `skdwxenbvhzpfxtwgepa`.
2. **Android Release Signing (`apps/mobile/android/app/build.gradle.kts`):**
   Keystore `C:\Users\USER\keystores\xzactopos-release.jks` (`upload`) and gitignored `apps/mobile/android/key.properties` are provisioned locally and verified via APK v2 release signing. **Owner action:** Back up the `.jks` file and `key.properties` credentials securely outside this PC.
3. **Firebase Hosting, Auth & CORS Cutover (`S09`, `S10`):**
   Root `firebase.json` + `.firebaserc` (`xzacto-403cc` / `https://skdwxenbvhzpfxtwgepa.supabase.co`) and `minimum_password_length = 8` (across `supabase/config.toml`, Web, and Mobile) are configured in-repo. **Deploy-time actions:** Configure Supabase Auth (`Site URL: https://xzacto.store`, Redirect URLs `https://xzacto.store/**`, `https://www.xzacto.store/**`, `xzactopos://auth-callback`, Minimum password length `8`), set Edge `ALLOWED_ORIGINS="https://xzacto.store,https://www.xzacto.store"`, deploy to `xzacto-403cc`, and cut over `xzacto.store` DNS from AWS CloudFront to Firebase Hosting.
5. **Suspended-Tenant Image Read Policy (`S11`):**
   `product_photos_member_read` allows `suspended` tenants to read/export existing photos (matching data export posture) while blocking uploads (`can_upload_product_photo()`). **Decision needed:** Confirm whether product images should stay readable during suspension or also be blocked.
6. **Refund Tender Rules vs Multi-Currency Roadmap (`S07`):**
   `op_return_sale_items` currently permits cash/e-wallet/card refund methods without checking the original tender mix (e.g., cash refund on an unpaid `utang` sale), and `sales` stores amounts in `base_currency` without FX snapshots. **Decision needed:** Prioritize refund-to-credit rules before expanding `utang` / multi-currency features.

---

## 5. Release Checklist Summary

See the full pre-deploy procedure in [docs/runbooks/release-checklist.md](../runbooks/release-checklist.md) and recovery steps in [docs/runbooks/backup-and-restore.md](../runbooks/backup-and-restore.md):

- **Migrations:** All `59` migrations (`20261107000100_core_tenancy.sql` .. `20261114000300_qa04_keepalive_and_lint_fix.sql`) listed in strict timestamp order, plus Postgres `17`, `custom_access_token_hook`, auth redirect URLs, and private `product-photos` storage bucket (`200 KiB`, `image/jpeg`).
- **Environment & Secrets Matrix:** Build-time Web vars (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`), Edge Function runtime vars (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ALLOWED_ORIGINS`), Flutter `--dart-define` vars + `android/key.properties`, and CI secrets (`DB_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`).
- **Backups & Advisors:** Weekly GitHub Action backup (`backup.yml`) + manual `scripts/backup-db.mjs`; baseline `db advisors --level warn` is `0` issues (`136` INFO total) and `db lint -s public` is `0` errors.
- **Rollback Plan:** Additive forward migrations or `pg_dump` restore from pre-deploy backup (`backup-and-restore.md`), Edge Function revision redeploy, static web artifact revert, and forward-only handling for Mobile SQLite (`schemaVersion = 18`).
