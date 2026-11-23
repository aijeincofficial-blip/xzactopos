# Release Checklist

> [!IMPORTANT]
> Pre-deploy runbook for **XzactoPOS**. Execute steps in order for staging and production releases. Do **not** skip RLS, secret scans, or backup verification.

## 1. Pre-Deploy Local Verification Gate

Run all checks cleanly from the repository root before tagging a release:

```powershell
pnpm check
pnpm --filter @pos/client build
pnpm exec playwright test
pnpm exec supabase db advisors --local --type all --level warn
pnpm exec supabase db lint --local -s public
pnpm audit --prod
```

Verify the production client bundle (`apps/client/dist/`) contains no `service_role` keys or private secrets before publishing. See [00-summary.md](../qa/00-summary.md) for current QA sign-off status.

## 2. Database Migrations (60 Total, Ordered)

Apply all `supabase/migrations/` files in strict timestamp order to the target project (e.g., via `supabase db push` on a linked project):

1. `20261107000100_core_tenancy.sql`
2. `20261107000200_auth_hook_and_helpers.sql`
3. `20261107000300_rls_policies.sql`
4. `20261107000400_admin_rpcs.sql`
5. `20261107000500_user_registration.sql`
6. `20261108000100_solo_store.sql`
7. `20261108000200_catalog.sql`
8. `20261108000300_catalog_rpcs.sql`
9. `20261108000400_product_photos.sql`
10. `20261108000500_sales_ledger.sql`
11. `20261108000600_sale_rpcs.sql`
12. `20261108000700_stock_ops.sql`
13. `20261108000800_stock_counted.sql`
14. `20261108000900_sales_rollups.sql`
15. `20261108001000_utang_adjust_sales_pull.sql`
16. `20261108001100_expenses.sql`
17. `20261108001200_expense_supervisor_approval.sql`
18. `20261108001300_day_close.sql`
19. `20261108001400_service_ledger.sql`
20. `20261108001500_tingi_repack.sql`
21. `20261108001600_utang_due_dates.sql`
22. `20261108001700_expiry_dates.sql`
23. `20261108001800_opening_cash.sql`
24. `20261108001900_ewallet_float_payments.sql`
25. `20261108002000_store_scoping.sql`
26. `20261108002100_devices_sale_no.sql`
27. `20261108002200_transfers.sql`
28. `20261108002300_reports_analytics.sql`
29. `20261108002400_sales_controls.sql`
30. `20261108002500_offline_pins_and_approvals.sql`
31. `20261108002600_warehouse_bins.sql`
32. `20261108002700_free_tier_operations.sql`
33. `20261108002800_catalog_categories.sql`
34. `20261108002900_platform_admin.sql`
35. `20261109000100_multi_warehouse_hardening.sql`
36. `20261109000200_warehouse_receiving.sql`
37. `20261109000300_suppliers_purchase_orders.sql`
38. `20261109000400_goods_receipts.sql`
39. `20261109000500_warehouse_counts.sql`
40. `20261109000600_warehouse_views.sql`
41. `20261109000700_warehouse_sync.sql`
42. `20261109000800_grn_result_applied_at.sql`
43. `20261109000900_transfer_stock_guard.sql`
44. `20261109001000_negative_stock_report.sql`
45. `20261109001100_shifts.sql`
46. `20261109001200_shift_expected_now.sql`
47. `20261110000100_web_gaps_po_mode.sql`
48. `20261110000200_location_reorder_points.sql`
49. `20261110000300_card_payments.sql`
50. `20261110000400_offline_counts.sql`
51. `20261111000100_partial_returns.sql`
52. `20261111000200_pos_receive_from_warehouse.sql`
53. `20261112000100_offline_supervisor_pin_complete.sql`
54. `20261112000200_report_summary_location_filter.sql`
55. `20261112000300_access_receipt_branding.sql`
56. `20261113000100_qa01_functional_fixes.sql`
57. `20261114000100_qa02_security_fixes.sql`
58. `20261114000200_qa03_performance_fixes.sql`
59. `20261114000300_qa04_keepalive_and_lint_fix.sql`
60. `20261114000400_s07_return_tender_guard.sql`

### Target Supabase Platform Configuration

- **Postgres**: `17`.
- **Auth Custom Access Token Hook**: Enable `pg-functions://postgres/public/custom_access_token_hook` in Auth Hooks before issuing user sessions (configured locally in `supabase/config.toml`).
- **Auth Redirect URLs**: Configure active production web `site_url` (`https://xzacto-403cc.web.app`) and `additional_redirect_urls` (`https://xzacto-403cc.web.app/**` and mobile deep link `xzactopos://auth-callback`; custom domain `https://xzacto.store/**` paused pending registrar recovery). Set hosted Auth **Minimum password length** to **`8`** (aligned with `supabase/config.toml`).
- **Storage Bucket**: Confirm `product-photos` exists with `public = false`, `file_size_limit = 204800` (200 KiB), and `allowed_mime_types = ['image/jpeg']`.

## 3. Environment Variables & Secrets per Environment

Never commit `.env`, `.env.local`, `android/key.properties`, or `service_role` keys. Store secrets only in target deployment managers / GitHub Secrets.

| Surface | Variable / File | Scope & Notes |
| --- | --- | --- |
| **Web Client** (`apps/client`) | `VITE_SUPABASE_URL` | Build-time Vite env (`supabase.ts`). Points to target Supabase API URL (`http://127.0.0.1:54321` locally). |
| **Web Client** (`apps/client`) | `VITE_SUPABASE_ANON_KEY` | Build-time Vite env (`supabase.ts`). Public anon key only — never use service role key. |
| **Edge Functions** (`create_user`, `invite_user`) | `SUPABASE_URL` | Server runtime (`_shared/clients.ts`). |
| **Edge Functions** (`create_user`, `invite_user`) | `SUPABASE_SERVICE_ROLE_KEY` | Server runtime secret (`_shared/clients.ts`). Must be set via `supabase secrets set`. |
| **Edge Functions** (`_shared/http.ts`) | `ALLOWED_ORIGINS` | Comma-separated production web origin allowlist for CORS (`https://xzacto-403cc.web.app`, adding `https://xzacto.store,https://www.xzacto.store` only once custom domain DNS cuts over). Required in production (`S10`). |
| **Mobile App** (`apps/mobile`) | `SUPABASE_URL` (`--dart-define`) | Build/run-time Dart define (`http://10.0.2.2:54321` on Android emulator). |
| **Mobile App** (`apps/mobile`) | `SUPABASE_ANON_KEY` (`--dart-define`) | Build/run-time Dart define. |
| **Mobile Android Release** | `apps/mobile/android/key.properties` | Upload/release keystore properties (gitignored; configured locally referencing `C:\Users\USER\keystores\xzactopos-release.jks`). |
| **GitHub Actions** (`.github/workflows/backup.yml`) | `DB_URL` | Repository secret: direct Postgres connection string (`pg_dump`). Workflow skips if unset. |
| **GitHub Actions** (`.github/workflows/keep-alive.yml`) | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Repository secrets used by authenticated keep-alive workflow (skips if unset). |
| **Local / Optional Supabase** (`supabase/config.toml`) | `OPENAI_API_KEY`, `S3_HOST`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` | Optional local Studio / S3 storage config; not needed unless using those features. |

## 4. Backups & Keep-Alive Verification

- **Take a pre-deploy backup before pushing migrations** (see [backup-and-restore.md](backup-and-restore.md)).
- **Scheduled Backup (`.github/workflows/backup.yml`)**: Runs weekly Sunday `02:00 UTC` and on manual `workflow_dispatch`. Executes `pg_dump "$DB_URL" --clean --if-exists --no-owner --no-privileges | gzip` and uploads the `.sql.gz` artifact for `30` days. Configure the `DB_URL` repository secret and test once with `workflow_dispatch`.
- **Local Backup Helper**: `scripts/backup-db.mjs` produces timestamped local dumps (see [backup-and-restore.md](backup-and-restore.md)).

> [!NOTE]
> **Keep-Alive Configuration (`.github/workflows/keep-alive.yml`)**:
> `keep-alive.yml` runs every 6 hours at off-peak minutes (`17 2,8,14,20 * * *` UTC) and executes `POST /rest/v1/rpc/health_ping`, read-only table queries (`tenants`, `locations`, `products` via PostgREST), `/auth/v1/settings`, and `/storage/v1/bucket` using `SUPABASE_SERVICE_ROLE_KEY` (allowed in migration `20261114000300_qa04_keepalive_and_lint_fix.sql`, while `anon` remains blocked and `authenticated` callers require `assert_active_user()`). Add `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` repository secrets in GitHub Actions and verify via `workflow_dispatch`.

## 5. Supabase Advisors & `db lint` Posture

Baseline verified locally after `20261114000400_s07_return_tender_guard.sql`:

- **`supabase db advisors --local --type all --level warn`**: `0` warnings and `0` errors (`No issues found`).
- **`supabase db advisors --local --type all --level info`** *(baseline at migration #59)*: `136` INFO items total:
  - `91` `unindexed_foreign_keys` (monitor after real traffic in staging/prod; see `P13`).
  - `42` `unused_index` (expected on freshly seeded local DB before production query traffic).
  - `3` `rls_enabled_no_policy` on internal tables `processed_ops`, `sale_counters`, and `supervisor_approvals` — **intentional** (locked down from direct client access; mutated only via `SECURITY DEFINER` RPCs).
- **Schema Security Invariants**: `0` tables without RLS (`tables_without_rls = 0`); `0` `SECURITY DEFINER` functions missing `SET search_path`.
- **`supabase db lint --local -s public`**: `0` errors across `public` schema (`op_return_sale_items` `_ret_lines` resolved in `20261114000300`, S07 guard added cleanly in `20261114000400`); `20` pre-existing warning-only functions remain (`S12`).
- **Hosted Check**: After running `supabase db push`, open **Supabase Dashboard -> Database -> Advisors** to confirm zero Warning/Error security regressions (`84` INFO/WARN expected: `1` built-in `rls_auto_enable` + `83` intentional `SECURITY DEFINER` RPCs).

## 6. Host Security Headers & Auth Settings

- Web hosting is configured for **Firebase Hosting** (`firebase.json` + `.firebaserc`, project `xzacto-403cc`, active URL `https://xzacto-403cc.web.app`) with `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy`, `Content-Security-Policy`, `Cache-Control: no-cache` on SPA routes/`sw.js` (rule order fixed in commit `2011252`), and SPA rewrites (`S09`).
- Repository password minimum is aligned at `8` characters (`supabase/config.toml`, Web `schemas.ts`, Mobile auth/password screens); confirm hosted Supabase Auth **Minimum password length = `8`** (`S10`).
- Confirm Edge Functions are deployed (`create_user`, `invite_user`) with `ALLOWED_ORIGINS="https://xzacto-403cc.web.app"` (until custom domain DNS is recovered and cut over). Note: hosted JWKS uses `ES256`; verify Edge gateway `verify_jwt` behavior or redeploy with `--no-verify-jwt` if gateway rejects valid tokens.

## 7. Rollback Plan

1. **Database Rollback**:
   - Prefer **additive forward-fix migrations** over destructive down-migrations in production.
   - If a release corrupts schema or data and cannot be patched forward cleanly, enable maintenance mode (halt writes), restore the pre-deploy `pg_dump` backup per [backup-and-restore.md](backup-and-restore.md) (or Supabase PITR / daily snapshot), and verify `supabase_migrations.schema_migrations` matches the restored schema before reopening traffic.
2. **Edge Functions Rollback**:
   - Check out the previous release commit and redeploy `create_user` and `invite_user` via `supabase functions deploy`.
3. **Web Client Rollback**:
   - Promote/redeploy the previous immutable `apps/client/dist` build on the static host and purge CDN/service-worker caches.
4. **Mobile Client Rollback**:
   - Halt staged Play Store / enterprise distribution immediately. Note that local SQLite upgrades on existing devices (`apps/mobile/lib/core/db.dart`, currently `schemaVersion = 18`) are forward-only: do **not** ship a binary with a lower `schemaVersion` to users who already upgraded; ship a hotfix bump instead.

## 8. Post-Deploy Smoke Checks

- Sign in as owner and verify JWT `custom_access_token_hook` claims (`tenant_id`, `role`, `location_ids`).
- Test Edge Function `create_user` / `invite_user` from the production web origin (verify CORS + role enforcement).
- Run a canary offline POS sale on Web and Mobile, reconnect, and verify idempotent sync and Day Close math.
- Trigger `.github/workflows/backup.yml` via `workflow_dispatch` and inspect artifact integrity.
