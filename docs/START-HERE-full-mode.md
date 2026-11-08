# Start here: Full mode

Read `CLAUDE.md` (rules) first, then `docs/tasks/F-00-overview-full-mode.md` (plan). `docs/START-HERE-antigravity.md` has the current state, commands and gotchas; this file is the short Full-mode map.

## Status
- Solo mode: finished and accepted (`docs/tasks/P8-13-acceptance.md`).
- Full mode done: F-01 store scoping, F-02 server sale number + devices.
- Next: F-03 tenant settings + mode switch, then F-04 staff, F-05 shifts, F-06 offline PIN, F-07 sales controls, F-08/F-09 warehouse and bins, F-10 reports, F-11 operations.
- Work lives on branch `claude/phase3-sell-8261d3` (worktree `.claude/worktrees/phase3-sell-8261d3`). Nothing is pushed; `main` is untouched.

## Direction (owner, 2026-11-08)
Full mode is React-first (`apps/client`). Solo on the phone (Flutter) stays as is, and **Solo also gets a web version in React**; both Solo apps show an "Upgrade to Full" entry. A solo tenant upgrades in place (same tenant, no copy) through an "Upgrade to Full" wizard in React. Flutter settings/staff cards (old F-03/F-04) are parked until Full works in React; Flutter is only prepared for the change. Details: "Direction change" in `docs/tasks/F-00-overview-full-mode.md`.

## Owner-only items (do not do these without the owner)
- Merge the branch to `main` and push.
- Create the release keystore (never generate one).
- Pick a git remote so `.github/workflows/ci.yml` can run for the first time.
- Open decisions at the end of the F-00 overview: real scale, shifts, offline supervisor PIN, discount policy, React admin, warehouse timing.

## How a Full-mode card runs
1. Migration + pgTAP first (never edit an old migration; new tables need RLS and an isolation-matrix row per role).
2. Flutter data layer (Drift, outbox), then UI. Keep widget `Key`s; strings through ARB (en + fil).
3. `pnpm check`, `flutter analyze`, `flutter test` (one Flutter command at a time) before the commit.
4. Commit per card with explicit paths; update `docs/handoff.md`.

## Rule of thumb
The role decides which screens a user sees; the database enforces. A solo owner who never opens the Full-mode flow must see no change.
