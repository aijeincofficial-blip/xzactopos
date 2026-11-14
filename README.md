# XzactoPOS

Offline-first multi-tenant POS, Inventory, Utang Ledger, Purchasing, and Warehouse Bin Management platform built for retail stores and multi-branch operations.

## Architecture

- **Web App (`apps/client`, `@pos/client`)**: React + TypeScript + Vite PWA web portal & POS (`en` / `fil` i18n, IndexedDB offline outbox and catalog cache).
- **Mobile App (`apps/mobile`)**: Flutter app with local SQLite (`drift`, schema v18) offline POS, receiving, bin put-away/picking, counts, shifts, and background sync.
- **Shared Packages (`packages/core`, `packages/sync`)**: Cross-surface money integer math, role/module permission guards, offline PIN verification, and sync utilities.
- **Backend (`supabase/`)**: PostgreSQL `17`, Row-Level Security across all `public` tables, `custom_access_token_hook`, idempotent `SECURITY DEFINER` RPCs, pgTAP SQL test suite (`supabase/tests/`), private `product-photos` storage bucket, and Deno Edge Functions (`create_user`, `invite_user`).

## Prerequisites

- **Node.js** `>= 20` (tested on `v24.18.0`; CI runs Node `22`)
- **pnpm** `9.15.0`
- **Docker** + **Supabase CLI** (bundled in `devDependencies`, `^3.0.0`)
- **Flutter** (`3.41.9` stable) for mobile builds, analyzer, and widget/unit tests
- **Google Chrome** for Playwright end-to-end tests

## Quick Start (Local Development)

### 1. Install Dependencies

```powershell
pnpm install
```

### 2. Configure Client Environment Variables

Copy `.env.example` to `apps/client/.env.local` (never commit `.env` or `.env.local`) and point it to your local Supabase stack (`http://127.0.0.1:54321` + the `anon` key printed by `supabase status`):

```env
# Client-safe values only. NEVER put service_role in client code.
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_ANON_KEY=<local-anon-key>
```

### 3. Start Local Supabase Stack

```powershell
pnpm db:start
```

This applies all `59` migrations in `supabase/migrations/`, configures `public.custom_access_token_hook`, and exposes API (`:54321`), Postgres (`:54322`), Studio (`:54323`), and Mailpit (`:54324`).

*(To stop the stack later, run `pnpm db:stop`.)*

### 4. Seed Test Data

Seed two isolated multi-tenant QA stores (`qa-alpha-php` in `PHP`/`Asia/Manila` and `qa-beta-usd` in `USD`/`UTC` with `S01`, `S02`, bin-enabled `W01`, `owner`/`manager`/`supervisor`/`whclerk`/`cashier` roles, multi-variant products, supplier, and purchase order):

```powershell
node scripts/qa-seed.mjs
```

Additional seed / helper scripts:

- `node scripts/seed-full-mode.mjs` — seed full multi-store/warehouse demo state
- `pnpm smoke:users` (`node scripts/smoke-users.mjs`) — verify user creation/login smoke flow
- `node scripts/backup-db.mjs` — write a timestamped local SQL dump under `backups/`
- `node scripts/generate-design-tokens.mjs` — regenerate tokens from `docs/tokens.json`

### 5. Run Web & Mobile Apps

**Web (`@pos/client`)**:

```powershell
pnpm dev       # Vite dev server (http://localhost:5173)
pnpm build     # Production build -> apps/client/dist
```

**Mobile (`apps/mobile`)**:

```powershell
# Flutter Web (reads apps/client/.env.local)
./apps/mobile/run-web.ps1

# Android Emulator (passes --dart-define=SUPABASE_URL=http://10.0.2.2:54321)
./apps/mobile/run-android.ps1
```

## Environment Variables Reference

Never commit real secrets. Only variable names are listed below:

| Variable | Where Used | Purpose |
| --- | --- | --- |
| `VITE_SUPABASE_URL` | `apps/client` (`.env.local` / build env) | Supabase API URL for Web client |
| `VITE_SUPABASE_ANON_KEY` | `apps/client` (`.env.local` / build env) | Public anon key for Web client |
| `SUPABASE_URL` | Edge Functions, `.github/workflows/keep-alive.yml` & Flutter `--dart-define` | Supabase API URL |
| `SUPABASE_ANON_KEY` | Flutter `--dart-define` | Public anon key for Mobile client |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions (`create_user`, `invite_user`) & `.github/workflows/keep-alive.yml` (CI secret) | Server-only admin key (never ship to clients) |
| `ALLOWED_ORIGINS` | Edge Functions (`_shared/http.ts`) | Comma-separated CORS origin allowlist |
| `DB_URL` | `.github/workflows/backup.yml` (CI secret) | Postgres connection URI for `pg_dump` backups |
| `OPENAI_API_KEY`, `S3_*` | `supabase/config.toml` (optional local) | Optional Studio AI / experimental S3 storage config |

Release builds for Android read keystore credentials from `apps/mobile/android/key.properties` (falling back to debug signing when absent).

## Testing & Verification Suites

```powershell
# Full verification gate (lint -> typecheck -> test -> test:functions -> test:db -> check:mobile)
pnpm check

# Individual workspace checks
pnpm lint                       # ESLint across all packages
pnpm typecheck                  # TypeScript across all packages
pnpm test                       # Vitest unit suites (@pos/core, @pos/client, etc.)
pnpm test:functions             # Vitest Edge Function validation suite
pnpm test:db                    # pgTAP SQL suite (supabase/tests/)
pnpm check:mobile               # Service worker checks + flutter analyze + flutter test
pnpm exec playwright test       # Playwright E2E flows (builds & serves @pos/client on :5173)

# Database & security hygiene
pnpm exec supabase db advisors --local --type all --level warn
pnpm exec supabase db lint --local -s public
pnpm audit --prod
```

## Key Documentation

- [QA Final Wrap-Up Summary](docs/qa/00-summary.md) — audit scorecard, Critical/High test traceability, Medium/Low backlog, and release risks
- [Functional QA Report](docs/qa/01-functional.md) | [Security QA Report](docs/qa/02-security.md) | [Performance QA Report](docs/qa/03-performance.md)
- [Release Checklist](docs/runbooks/release-checklist.md) — ordered 59-migration checklist, env matrix, advisor posture, keep-alive setup, and rollback plan
- [Backup & Disaster Recovery Runbook](docs/runbooks/backup-and-restore.md)
- [Design Specification](docs/design.md) & [Handoff Notes](docs/handoff.md)
