# Start here (for Antigravity or any new session)

Written when the Claude usage limit was hit. Read this first, then `docs/handoff.md` (long; read the top Status list and the last sections), then `CLAUDE.md` (the rules).

## Where things stand
- Project: multi-tenant POS + inventory on Supabase (Postgres, RLS, RPCs, pgTAP) with a Flutter app in `apps/mobile` for a single-person sari-sari store ("solo mode"). The React admin in `apps/client` is untouched back-office.
- Branch with all the work: `claude/phase3-sell-8261d3` (git worktree `C:\Users\USER\xzactopos\.claude\worktrees\phase3-sell-8261d3`). It already contains `flutter-solo`. **Nothing is pushed.** `main` is untouched.
- Done and accepted: Phases 0 to 4, 6, 7 (solo). Cards are in `docs/tasks/`, acceptance reports at the end of `docs/handoff.md`.
- Green: `pnpm check` = lint, types, Vitest, pgTAP (1659 tests, 15 files), service worker checks, `flutter analyze`, `flutter test` (169).
- Local database was reset (`supabase db reset`); demo users are gone. Test account on the emulator: `p7.accept@example.com` (password was typed by hand, create a new account if needed).

## First commands
```bash
cd C:/Users/USER/xzactopos/.claude/worktrees/phase3-sell-8261d3
pnpm install            # if node_modules is missing
pnpm exec supabase status   # local stack must be running (Docker Desktop)
pnpm check              # should end with "check passed"
```
Run the web build: `flutter build web --release --no-web-resources-cdn --pwa-strategy=none --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<anon key from supabase status -o env>` in `apps/mobile`, then `python tool/serve_web.py build/web 5301`.
Android emulator (Pixel_4_API_33, already running as `emulator-5554`): build with `--dart-define=SUPABASE_URL=http://10.0.2.2:54321`, `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. See the "Android (emulator) setup" section of the handoff.

## Rules that matter (from CLAUDE.md)
Migrations and pgTAP before UI. Every new table: RLS + isolation-matrix rows (`supabase/tests/004_tenant_isolation_matrix.test.sql`). Never edit an existing migration; add a new one (the newest `sync_push` definition is in `20261108001000_utang_adjust_sales_pull.sql`; copy from the newest when you change it). Stock only changes through `stock_movements`. Money is integer centavos. UI strings only through ARB files (`lib/l10n`, English + Filipino, plurals must use `{count}`). Run `pnpm check` before declaring a task done, commit per card, update `docs/handoff.md`.

## What to do first: close the untested Phase 7 items (small)
1. **Offline web in a normal Chrome** (the Claude in-app browser blocks service workers). Build the web app (above), serve it, open `http://127.0.0.1:5301` in Chrome, reload TWICE online (the first visit only caches part of the app; `main.dart.js` is cached on the second load; use a normal reload, not Ctrl+Shift+R, which bypasses the worker), stop the python server, reload (verified by an automated headless-Chrome probe on 2026-11-07: passes after two online loads): the app should still open. Check DevTools > Application > Service Workers shows `sw.js` activated. If it fails, fix `apps/mobile/web/sw.js` and extend `apps/mobile/tool/sw_test.mjs`. (Node 24 has a built-in WebSocket if you want to script Chrome through its debug port.)
2. **Barcode decoding on a device.** The camera screen, permission prompt and live preview work on the emulator, but no real barcode has been decoded. Test with a real phone and a real barcode, or write a throwaway probe that calls `MobileScannerController().analyzeImage(path)` on a generated EAN-13 PNG on the emulator.
3. **Release APK signing:** needs a keystore that only the owner should create and keep. Not done, do not generate one without asking the owner.
4. Not testable here: a real Bluetooth/thermal printer.
(Share and Print were checked on the emulator: both open Android's own sheets with the 58 mm PDF.)

## Then the planned roadmap
Solo is finished. Next is the **Full-mode** list in `docs/gaps-review.md` section D (shifts and PIN unlock with the offline PIN RPC, server `sale_no`, multi-store pickers and user management in the Flutter app, warehouse and bins = Phases 5 and 5b, tenant settings screen, invite-by-email, full reports). The owner said they will decide the order after solo is done; a sensible start is what a growing store needs first (second store or staff: shifts, PIN unlock, server `sale_no`). Also still open: retire or keep the React admin; B1, B2, B3, B6 to B8, C1 to C4 in `docs/gaps-review.md`.

## Gotchas learned the hard way
- Flutter `setState(() => futureReturningCall())` throws; use a block body.
- Filipino plurals: every plural branch must use `{count}`, never a typed digit (a test guards it).
- `image` is pinned to `>=4.5.0 <4.8.0` because `pdf` needs `archive < 4.1`. Do not "upgrade" it without checking `flutter test`.
- In pgTAP, deferred triggers (rollups) need `set constraints all immediate`; to age rows past the 5 s pull hold-back use `set local session_replication_role = replica` around the UPDATE.
- Run `flutter test` before committing, not after (a new Home tile once broke 9 tests).
- Shell heredocs with quotes break the Bash tool on this machine; write scripts to a file first.
- Never run `supabase db reset` without asking: it wipes the local demo data.
- Android typing via `adb input text` is slow; type one character at a time and use Tab between fields.
- Web build must use `--pwa-strategy=none`: otherwise Flutter's bootstrap registers its own self-unregistering `flutter_service_worker.js` at the same scope and replaces our `sw.js` (symptom: no sw.js in DevTools).
- The Claude in-app browser blocks SharedWorker/service-worker fetches; the app falls back to in-page storage there (single tab).

## Where to look
`docs/plan.md` (architecture; sections 6, 7, 12), `docs/recalibration-solo-flutter.md` (why solo first), `docs/gaps-review.md` (triaged gaps), `docs/tasks/P*-00-overview-*.md` (decisions per phase), `apps/mobile/lib/data/` (Drift store and sync side), `apps/mobile/lib/sync/sync_engine.dart` (push/pull), `supabase/migrations/` (newest last).
