# Gaps review across phases 0 to 6 (solo)

Collected from the handoff after Phase 6. Each gap has an owner phase and a suggested call: **Fix now** (small, blocks a real tindera), **Phase 7** (APK, camera, printing, offline load), **Full mode** (needs the chain features), **Accept** (fine for the pilot, revisit with real users).
Decide per item; nothing here has been changed yet.

## A. Blocks a real tindera on a phone (suggest: fix before the pilot)
| # | Gap | Origin | Call |
| --- | --- | --- | --- |
| A1 | **Phone never tested.** Android toolchain was incomplete; APK, camera capture, camera barcode scan, thumb layout and keyboard-over-cart untested. Another session owns the Android setup | P2 | Phase 7 (first thing) |
| A2 | **Offline first load of the web app.** The web build needs a signal to start (no service worker; canvaskit from the CDN unless built with `--no-web-resources-cdn`). On the APK this does not apply | P2 | Phase 7 (web only) |
| A3 | **Session expiry mid-use.** An expired token during a sale push shows a generic failure and retries; the tindera is never told to sign in again | P1/P3 | Fix now (small: detect auth errors in the sync engine, show "sign in again", keep the outbox) |
| A4 | **No password reset / change** in the Flutter app or the admin | P1 | Fix now (Supabase has it built in; needs two screens) |
| A5 | **Pending ops are lost when a different business signs in on the same device** (`ensureTenant` wipes local data, including unsent sales) | P2 | Fix now (refuse the switch while ops are pending, or ask) |
| A6 | **Receipts and local sales are lost on reinstall;** "Today" only knows this device's sales | P3 | Fix now or Phase 7 (pull the last 30 days of sales on first sign-in) |
| A7 | **Stock UX wording** for never-counted products | P3 | Done in Phase 4 |

## B. Data and sync quality (suggest: schedule soon)
| # | Gap | Origin | Call |
| --- | --- | --- | --- |
| B1 | **Receipt number clash across devices:** the 3-character device code is random; a clash shows as a rejected op | P3 | Full mode (server `sale_no`), accept for one device |
| B2 | **Old product photo versions never deleted** from Storage (about 100 KB each; free tier) | P2 | Phase 8 cleanup job |
| B3 | **A sale without a store id only works when the user has exactly one store** | P3/P4 | Full mode (store picker) |
| B4 | **Receipt "not sent" icon is not live** (refreshes when reopened) | P3 | Fix now (stream the sale) |
| B5 | **Utang adjust** (write-off, correction) has no op; the ledger kind exists | P3 | Fix now if the user wants it (one op + one dialog) |
| B6 | **Counting a never-counted product as 0 writes nothing** (stays "not counted") | P4 | Accept |
| B7 | **Average cost is not shown on any screen;** only copied onto sales. Margin is an estimate | P4/P6 | Accept; show on the product screen later |
| B8 | **Reports are online only** (last result cached) and exclude unsent sales (stated on screen) | P6 | Accept |
| B9 | **Clean `supabase db reset` never run** since S-01; migrations applied with `migration up`. 14 migrations should be replayed from scratch once | P2 | Fix now (needs your OK: wipes demo data) |

## C. Process and tooling
| # | Gap | Origin | Call |
| --- | --- | --- | --- |
| C1 | **CI never run** (no remote). `.github/workflows/ci.yml` and the `supabase start -x ...` list are untested; Flutter is not in CI yet (it is in `pnpm check`) | P0 | Fix when a remote exists |
| C2 | **No browser automation tests** (Playwright deferred); screens verified by hand plus widget tests | P1+ | Accept; consider an integration test for the 20-sale flow in a real browser |
| C3 | **Web in the Claude in-app browser** uses in-page storage (SharedWorker blocked); single tab only | P2 | Accept (testing quirk) |
| C4 | `flutter test` skips with a notice when Flutter is missing on PATH | P3 | Accept |

## D. Full-mode work (planned, not built)
Shifts and cash-drawer counts; PIN unlock and the offline PIN RPC (`profiles.pin_hash`); server `sale_no` and a devices table; per-line discounts and permissions; card payments; multi-store pickers and user/store management inside the Flutter app (today in the React admin); warehouse, transfers, bins (Phases 5 and 5b); tenant settings screen (name, timezone, tax mode, languages); invite-by-email screen; user list search/pagination (capped at 500); full reports and `stock_snapshots_daily`; platform operator tooling (Phase 9); customers beyond utang (loyalty, Phase 9). The decision to retire the React admin is also open.

## Suggested order
1. Fix now: A3, A4, A5, B4, B9 (and B5 if wanted): about one small phase of work, all low risk.
2. Phase 7: A1, A2, A6 (APK first, then the rest).
3. Then decide the Full-mode order (D), starting with what a growing store needs first (second store or staff).
