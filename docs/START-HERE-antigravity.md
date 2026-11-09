> **ROUTE CHANGED 2026-11-08 (owner): read `docs/START-HERE-full-mode.md` first.** Solo on the phone is done; next is Solo on the web (React, cards W-01 to W-04 in `docs/tasks/W-00-solo-web-and-upgrade.md`), then an in-place "Upgrade to Full" (W-05), then Full in React. The old "Next: F-03 in Flutter" and the Flutter F-03/F-04 items below are **parked**. The numbers, rules and gotchas below are still correct.

# Start here (for Antigravity or any new session)

Rewritten 2026-11-08 when Claude's usage limit was close. Read this first, then `CLAUDE.md` (the rules), then `docs/tasks/F-00-overview-full-mode.md` (the plan). The older notes about Phases 0 to 7 are history; everything below is current.

## Where things stand
- Project: multi-tenant POS + inventory on Supabase (Postgres, RLS, RPCs, pgTAP) with a Flutter app in `apps/mobile` (offline-first, Drift local store, outbox sync). `apps/client` (React back-office) is untouched.
- **Solo mode is finished and accepted** (Phases 0 to 8 plus tabs, keypad, opening cash, e-wallet float, import/export). Report: `docs/tasks/P8-13-acceptance.md`.
- **Full mode has started.** Done: **F-01 store scoping** (server + phone + store picker, asks before switching with a sale in the cart) and **F-02 server sale number + devices** (`sale_no` per store per day, `devices` table, receipts/Today/CSV show it). Cards: `docs/tasks/F-01-store-scoping.md`, `F-02-server-sale-number-and-devices.md`.
- **Next: F-03** tenant settings + the switch to Full mode (see "What to do next").
- Branch with all the work: `claude/phase3-sell-8261d3`, git worktree `C:\Users\USER\xzactopos\.claude\worktrees\phase3-sell-8261d3`. **Nothing is pushed. `main` is 100+ commits behind and untouched.** Do not merge or push without the owner's OK.
- Green right now: `pnpm check` = lint, types, Vitest, pgTAP **2965 tests / 26 files**, `flutter analyze` clean, `flutter test` **346**. Latest migration: `20261108002100_devices_sale_no.sql`. Drift schema version: 14.

## First commands
```bash
cd C:/Users/USER/xzactopos/.claude/worktrees/phase3-sell-8261d3
pnpm install                  # only if node_modules is missing
pnpm exec supabase status     # the local stack must be running (Docker Desktop)
pnpm check                    # must end with "check passed" before you start and before every commit
```
Flutter only: `cd apps/mobile && flutter analyze && flutter test`. Run Flutter commands ONE AT A TIME (two at once crash on `sqlite3.dll`; if a run dies copying native assets, kill `flutter_tester` in Task Manager and rerun).

## Rules that matter (CLAUDE.md, plus what bit us)
- Migrations and pgTAP before UI. **Never edit an existing migration**: add a new one. The newest `sync_push` definition is in the newest migration that redefines it (check `supabase/migrations/` from the end); copy from the newest when you change it.
- Every new table: RLS + a row per role in `supabase/tests/004_tenant_isolation_matrix.test.sql` (the coverage check fails if you forget) + a test.
- Stock only changes through `stock_movements`. Money is integer centavos + currency. IDs are UUIDv7 made on the client. Timestamps UTC.
- UI strings only through the ARB files (`lib/l10n`, en + fil). Plurals must use `{count}` in every branch, no typed digits (a test guards it). English is the default language.
- Never run `supabase db reset` without asking the owner (it wipes the local test data). It was replayed cleanly once on 2026-11-08.
- Commit per card with explicit paths (`git add <files>`), never `git add -A`. Update `docs/handoff.md` at the end of a task.
- **Model split from CLAUDE.md:** the careful models (Opus-class) for RLS, sync engine, ledger and stock math; cheaper ones for screens and tests. For those cards: write the pgTAP test first, add a seeded property test for money/stock math, and mutation-check it (break the formula on purpose and see it fail).
- UI changes: keep the existing widget `Key`s, because ~350 tests find widgets by key. The bottom bar keys are `tab-today`, `tile-stock`, `tile-sell`, `tile-utang`, `tab-more`; Reports and the rest are tiles in More (`tile-reports`, `tile-products`, `more-expenses`, ...). Tests open on a phone-sized screen (`openHome` in `test/products_test.dart`).
- Screens behind the glass tab bar get the bar height as bottom padding (`MediaQuery.paddingOf(context).bottom`): add it to the last list item and to floating buttons, or they hide behind the bar.

## What to do next (in this order)
1. **Ask the owner for the open decisions** listed at the end of `docs/tasks/F-00-overview-full-mode.md` (real scale, shifts, offline supervisor PIN, discount policy, React admin, warehouse timing). Stores-first was decided; the rest are still open.
2. **F-00a housekeeping** (owner's OK needed for the merge): merge the solo+F-01/F-02 branch to `main`, get CI running on a remote (`.github/workflows/ci.yml` has never run), release APK signing needs a keystore the OWNER creates (never generate one).
3. **F-03 tenant settings + mode switch** (Sonnet-class, RPCs exist): Settings screen for name, timezone, tax mode, languages; an "Add staff / another store / warehouse" flow that toggles `tenant_modules` using `set_modules` and `upsert_location`; limits shown; a solo owner who does not use it sees no change.
4. **F-04 staff screens** (invite by email, create cashier via the `create_user` Edge Function, roles/positions, store assignment, set PIN; cashier and warehouse get fewer tabs), then F-05 shifts, F-06 offline PIN, F-07 sales controls, F-08/F-09 warehouse and bins, F-10 reports, F-11 operations. Details and models per card are in `F-00-overview-full-mode.md`.

## Known open items and gotchas
- Opening cash and the day close are per store; utang payments now carry store + method (only cash counts at the drawer).
- Reports (`report_summary`) still add up every store the caller can see; per-store reports are F-10.
- A supervisor needs signal once to get a PIN approval (no offline PIN RPC yet = F-06). Refused ops (missing approval) are not audit-logged.
- E-wallet sale payments and expenses name a wallet (GCash default, Maya, other) and move that wallet's float; load/cash-in/out are in the service ledger.
- Unexplained once: on the emulator a tap about 80 s after sign-in landed back on the first tab (same moment as a "Refresh session" log line). Not reproduced.
- Not verified on a device: supervisor PIN flow, tingi, expiry, pay-by dates, statement/CSV sharing, offline-then-reconnect, F-02 (sale numbers) and a second store on a phone with real data.
- Shell: heredocs with quotes break the Bash tool on this machine; write scripts to a file first. `adb input text` is slow; type one character at a time and use Tab between fields.
- Emulator (Pixel 4, `emulator-5554`): debug APKs can hit `INSTALL_FAILED_INSUFFICIENT_STORAGE`; if so build a release x64 APK:
  ```powershell
  cd apps/mobile
  flutter build apk --release --target-platform android-x64 `
    --dart-define=SUPABASE_URL=http://10.0.2.2:54321 `
    --dart-define=SUPABASE_ANON_KEY=<anon key from `pnpm exec supabase status -o env`>
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  ```
  A local test account is made with the auth admin API (service key from `supabase status`), then typed in by hand; the earlier test users were wiped by the reset.
- Local database poking: `docker exec supabase_db_xzactopos psql -U postgres -At -c "..."`.

## Where to look
`docs/plan.md` (architecture; sections 4 to 8, 12), `docs/tasks/F-00-overview-full-mode.md` (the plan), `docs/gaps-review.md`, `docs/handoff.md` (long; top status list and the last sections), `docs/design-references.md` and `docs/START-HERE-claude.md` (the UI direction and Antigravity's own notes), `apps/mobile/lib/data/` (Drift store, sync side), `apps/mobile/lib/sync/sync_engine.dart` (push/pull), `supabase/migrations/` (newest last), `supabase/tests/` (pgTAP).
