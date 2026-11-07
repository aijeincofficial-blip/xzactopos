# Handoff

Updated at the end of every task. Read this first in a fresh session.

## Status
- **Phase 0 (Foundation): built, awaiting review.** Task cards: docs/tasks/P0-01..P0-05.
- Not committed yet. Next: Phase 1 (Tenancy, Auth, RBAC). Use Opus for RLS work.

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
