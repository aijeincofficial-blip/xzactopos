# Start here: the route we take (Solo to Web to Full)

Read order for any new session: this file, then `CLAUDE.md` (rules), then `docs/START-HERE-antigravity.md` (commands, gotchas, current numbers), then `docs/tasks/W-00-solo-web-and-upgrade.md` (the active plan), then `docs/tasks/F-00-overview-full-mode.md` (Full-mode background and card list).

## The route in one picture
1. **Solo on the phone (Flutter, `apps/mobile`): DONE and accepted.** Only fixes from now on, plus one "Upgrade to Full" entry (card W-05).
2. **Solo on the web (React, `apps/client`): NEXT, the foundation.** Cards W-01 to W-04: shell and Today, Sell, Stock and products, Utang/expenses/day close. Same backend and data as the phone.
3. **Upgrade to Full: card W-05.** A solo tenant upgrades **in place, same tenant, nothing copied** through a wizard in React web (`complete_setup`, `set_modules`, `upsert_location`). Both Solo apps (phone and web) show an "Upgrade to Full" entry.
4. **Full screens in React:** staff, stores, warehouse, bins, shifts, reports (the F cards, rewritten for React).
5. **Flutter for Full later:** role-based tabs, offline PIN, warehouse role screens. The old Flutter F-03 (settings) and F-04 (staff) cards are **parked** until Full works in React.

Solo and Full are one app and one backend, not two products. The mode (`tenant_modules`) and the role decide which screens show; the database enforces (RPCs check role, location and module).

## Decisions log (owner, 2026-11-08)
| Topic | Decision |
| --- | --- |
| Solo | Foundation. Stays as it is on the phone and also gets a web version. |
| Full | React-first. |
| Upgrade | In place, same tenant, no data copy. Started from React web; phone Solo shows an entry. |
| Scale | 3 to 10 stores, 5 to 30 staff (plan on Supabase Pro). |
| Shifts | Per-cashier shifts needed before staff go live (F-05). |
| Supervisor PIN | Must work fully offline (F-06 before staff go live). |
| Discounts | Cashier up to a small threshold; above it a supervisor PIN (F-07). |
| React admin (`apps/client`) | Kept. It grows into the web app for Solo and Full. |
| Warehouse | In the first Full release (F-08/F-09). |
| Web Solo offline | Assumed online-first in the first version (phone app is the offline one). Not yet confirmed by the owner. |

## Facts that are already verified (do not re-investigate)
- The solo owner has the `superadmin` role (`provision_solo_store`), so `set_modules`, `upsert_location` and `complete_setup` work for them as they are. Settings (name, timezone, tax mode, locales) are stored in `tenants` and `tenant_settings`; base currency is locked after setup.
- `apps/client` today: React 19, TanStack Router + Query, supabase-js, i18next (en + fil), zod, Tailwind; online only; routes `/app`, `/app/setup`, `/app/locations`, `/app/users`, `/app/modules`; no selling, stock, utang or reports screens.
- Worktree: always work in `C:\Users\USER\xzactopos\.claude\worktrees\phase3-sell-8261d3` (branch `claude/phase3-sell-8261d3`). The repo root folder is on an old branch.

## Known gaps to revisit later (owner agreed to defer)
- **Mode derivation (W-01):** `tenantMode()` in `apps/client/src/lib/mode.ts` derives Solo/Full from the access payload. An owner who added staff but nothing else still reads as Solo because the payload has no staff count. Fix later with a stored mode flag (migration + pgTAP + set by the W-05 upgrade) or by adding a staff count to `get_my_access`.
- **Web Solo is online-first** (see decisions log); offline on web is not planned.

## Status of work
- Done: Solo (phone), F-01 store scoping, F-02 server sale number + devices, plans W-00 and F-00 updated.
- Next: W-01.
- Not started by design: the Flutter F-03 settings screen (nothing was written).

## Owner-only items (do not do these without the owner)
- Merge the branch to `main` and push.
- Create the release keystore (never generate one).
- Pick a git remote so `.github/workflows/ci.yml` can run for the first time.

## Working rules for every card
1. Migration + pgTAP first (never edit an old migration; new tables need RLS and an isolation-matrix row per role).
2. Server RPCs before UI. Business logic in Postgres RPCs; select explicit columns; paginate.
3. UI strings only through i18n keys (en + fil); React: `src/locales/{en,fil}`; Flutter: ARB files.
4. `pnpm check`, plus `flutter analyze` and `flutter test` (one Flutter command at a time) when Flutter changed.
5. One commit per card with explicit paths (`git add <files>`, never `git add -A`); update `docs/handoff.md`.
6. Model split: careful model for RLS, sync, ledger and stock math; cheaper model for screens and tests.

## TODO for Claude: review the uncommitted Flutter edits before anything else
`apps/mobile/lib/core/theme.dart`, `screens/home_shell.dart` and `screens/receipt_screen.dart` have uncommitted changes that Antigravity did not make and did not commit. The owner asked **Claude to review them** and decide what to keep. What the diff contains:
- `theme.dart`: `onSecondary` changed from the dark `0xFF042F23` back to `Colors.white` (undoes the contrast fix; white on mint is about 2.5:1). Likely a regression.
- `home_shell.dart`: the `StoreChip` and its `store_picker.dart` import are removed from the More screen (removes the F-01 store picker entry point). Likely a regression.
- `receipt_screen.dart`: mostly reformatting to a wider line width; the diff may also hide real changes, so read it in full.

Review steps: read `git diff` for the three files; keep intended changes and commit them with explicit paths; restore the rest with `git checkout -- <file>` (only after confirming with the owner, because it discards the edits); then run `flutter analyze` and `flutter test`. Until Claude has done this, Antigravity does not commit, stash, revert or build on these files.

