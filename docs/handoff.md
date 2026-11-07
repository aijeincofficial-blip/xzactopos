# Handoff

Updated at the end of every task. Read this first in a fresh session.

## Status
- Phase 0 (Foundation): done, committed (6d59c99).
- **Phase 1 (Tenancy, Auth, RBAC): in progress.** Cards in docs/tasks/P1-01..P1-08 (approved).
  - P1-01 core schema: done. Migration `20261107000100_core_tenancy.sql`, pgTAP `001_core_schema.test.sql` (38 tests).
  - Next: P1-02 access token hook + RLS helpers (Opus).
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
