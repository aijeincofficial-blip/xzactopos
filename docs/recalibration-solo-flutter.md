# Recalibration: solo sari-sari store + Flutter client

Status: proposed, written after Phase 1 acceptance (P1-08). Phase 1 is done and is NOT reopened.
Branch: `flutter-solo`. Everything below is additive.

## Why
Target user is a single tindera running one small sari-sari store alone, often on patchy signal.
Phase 1 serves chains (roles, positions, wizard, business-code login). Solo use needs one screen to start selling.

## Do-not-damage rules
- Do not edit `supabase/` migrations, `packages/core`, or `apps/client`. New DB work = new migration files only.
- `pnpm check` (693 pgTAP tests) must stay green before any merge to `main`.
- Flutter code lives only in `apps/mobile/`.

## Decisions
- Backend stays Supabase (RLS, RPCs, `stock_movements` ledger). Not Firestore.
- Mobile client is Flutter (`supabase_flutter`). Test on web with `flutter run -d chrome` (hot reload), then Android/iOS from the same code.
- DECIDED: both clients. Flutter (`apps/mobile`) is the one app for tinderas AND the full plan; React `apps/client` stays as back-office admin web. Revisit retiring React at Phase 3.
- One Flutter app, two modes: Solo mode (default, tiny home screen) and Full mode (more users/stores/warehouse via `tenant_modules` toggles). Same backend and data; no migration when a store grows. Role decides screens. Heavy modules are deferred-loaded and not synced when off.
- Ported to Dart: `can()` permissions, money utils, i18n (en + fil), local store + outbox (Drift). Keep Dart tests mirroring the TS ones.
- Offline first, Filipino default, images in Supabase Storage (never in DB).

## Solo Mode
- One owner, one store. Sign up, name the store, sell. No wizard, no business code, no positions.
- Auto-created: tenant, one location, superadmin role, PHP currency, `fil` locale.
- Hidden until enabled in Settings: more users, more stores, warehouse and bins.
- Core screens: Sell (barcode + quick-item buttons), Products (photo), Stock (low-stock warning), Utang (credit list), Daily total.

## Revised roadmap
| Phase | Change |
| --- | --- |
| 0, 1 | Done and accepted. Untouched. |
| S | New. Solo provisioning RPC + Flutter scaffold (cards S-01, S-02). |
| 2 | Catalog + local store, done in Flutter/Drift. Variants stay in the schema; UI shows a single default variant unless the tindera adds more. |
| 3 | POS core in Flutter: cart, cash payment, utang, receipt, outbox, `sync_push`. Opus for sync + stock math. |
| 4 | Inventory: stock in, adjust, low-stock. Warehouse (5, 5b) stays hidden/optional. |
| 6 | Reports reduced to daily/weekly sales, top items, utang balance. |
| 7 | Mobile packaging (APK) replaces the Capacitor plan. |

## Carried-over gaps to schedule
Offline PIN RPC (Phase 3), password reset UI, session-expiry handling, CI never run (no remote).
