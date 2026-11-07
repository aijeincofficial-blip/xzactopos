# Handoff

Updated at the end of every task. Read this first in a fresh session.

## Status
- Phase 0 (Foundation): done, committed (6d59c99).
- **Phase 1 (Tenancy, Auth, RBAC): in progress.** Cards in docs/tasks/P1-01..P1-08 (approved).
  - P1-01 core schema: done. Migration `20261107000100_core_tenancy.sql`, pgTAP `001_core_schema.test.sql` (38 tests).
  - P1-02 hook + helpers: done. Migration `20261107000200_auth_hook_and_helpers.sql`, pgTAP `002_auth_helpers.test.sql` (42 tests).
    Hook enabled in `supabase/config.toml`; verified end-to-end (real sign-in token carries tenant_id, user_role, tenant_status, user_active).
  - P1-03 RLS policies + guard: done. Migration `20261107000300_rls_policies.sql`, pgTAP `003_rls_guard_and_policies.test.sql` (33 tests).
  - P1-04 isolation matrix: done. pgTAP `004_tenant_isolation_matrix.test.sql` (508 tests): 2 tenants with colliding keys x
    5 users (superadmin, admin, cashier, warehouse, deactivated) x 10 tables x 5 metrics (own read, own update, foreign read,
    foreign update, delete blocked) against an explicit expectation table. Mutation-tested: a leaky locations policy fails it.
    **When adding a tenant table, add a row per role to `expected` and a probe entry**, or the coverage check fails.
  - Next: P1-05 admin RPCs + permission keys (Opus). RPC refusal tests for deactivated users and suspended tenants go there.
- **RLS shape:** reads follow the §5 matrix; direct client writes only for simple master data
  (tenant name/timezone/tax_mode, settings, currency rates, location name/address/active, own profile name/locale).
  Modules, roles, assignments, new locations, bins: RPC only (P1-05). Column-level grants enforce the editable columns.
- `profiles.pin_hash` is not client-readable (column grant). Offline PIN material needs a dedicated RPC later (Phase 3).
- Default privileges: new tables never grant anon or client DELETE/TRUNCATE; new functions are not executable by anon/public.
  New functions still need an explicit `grant execute ... to authenticated` when clients should call them.
- Guard test fails if any public table lacks RLS, `tenant_id` (allow-list: tenants, currencies, platform_admins),
  or a tenant-leading index; if anon has any grant; if a SECURITY DEFINER function lacks a pinned search_path.
- `audit_log.location_id` added so admins read audit entries for stores they manage.
- Policy gotcha: `x = any ((select fn()))` treats the array as a subquery; write `x = any ((select fn())::uuid[])`.
- **Auth decision:** JWT claims are UI hints. Helpers read role/active live from `profiles` and require the profile tenant to match
  the JWT `tenant_id` claim. Demotion/deactivation is immediate. Suspended tenants still resolve (read/export) but
  `assert_active_user()` refuses writes. Archived tenants and deactivated users resolve to nothing.
- Helpers for policies/RPCs: `auth_tenant_id()`, `auth_role()`, `is_superadmin()`, `is_active_user()`, `is_platform_admin()`,
  `has_location_access(loc, min_position)`, `auth_location_ids()`, `assert_active_user()`, `assert_module(m)`, `assert_location_access(loc, pos)`.
  Wrap in `(select ...)` inside policies.
- Changing `supabase/config.toml` (auth) needs `supabase stop && supabase start`; `db reset` alone is not enough.
- RLS is enabled on every table already, with no client policies yet (deny-all) until P1-03.
- `location_access` rules live in a trigger (role vs location type vs position). Changing a user's role must
  also clear or fix their assignments: handle in `set_user_role` RPC (P1-05).
- `tenant_modules` is one row per tenant with booleans; `check (inventory)` keeps the core always on.

## Phase 0 acceptance report (plan section 12)
| Criterion | Result |
| --- | --- |
| `pnpm dev` runs client against local Supabase | Verified in browser: shows "Connected", no console errors, en/fil switch works |
| Money formats correctly in 3 currencies and 2 locales | 22 tests pass (USD/JPY/KWD x en/fil, plus de-DE separators, parsing, rounding, convert, allocate) |
| i18next scaffolding | en + fil bundled; key-parity test passes (5 client tests) |
| CI green | **Not verified.** `.github/workflows/ci.yml` written but never run (no remote). The `supabase start -x ...` exclusion list is untested |
| `pnpm check` | Passes locally (lint, types, tests). pgTAP step is "NOT RUN" until migrations exist |

## Layout (matches plan section 11)
- `apps/client` Vite + React 19 + TS PWA. `packages/core` (`@pos/core`: money). `packages/sync` (`@pos/sync`: empty stub).
- Deferred from the plan stack to the phases that need them: Tailwind/shadcn, TanStack Query/Router, Dexie, Zod, Capacitor, Playwright.

## Decisions and gotchas
- TypeScript pinned to 6.x: typescript-eslint does not support TS 7 yet.
- Poll interval conflict: CLAUDE.md says 120 s idle with backoff; plan section 2 says 60 s. CLAUDE.md wins unless changed.
- `apps/client/.env.local` holds the local anon key (gitignored). Regenerate from `pnpm exec supabase status -o env`.
- Docker CLI is not on PATH in some shells: add `C:\Program Files\Docker\Docker\resources\bin`.
- `supabase_vector` container restarts on Windows (optional log collector; ignore or disable analytics).
- Money amounts are JS numbers (safe integers). Revisit if any amount can exceed 2^53 minor units.
- Local DB: postgresql://postgres:postgres@127.0.0.1:54322/postgres, Studio http://127.0.0.1:54323.
- Docker Desktop disk may still be on C:. VirtualBox VM was moved to D:.
