# P3-08 Acceptance
Goal: prove the Phase 3 "Done when" and record it in `docs/handoff.md`.
- Automated: a Flutter test makes 20 sales (cash, utang, mixed) against a fake server, fails the push halfway, retries, and checks exactly 20 sales / correct totals / no duplicates / correct stock and balances.
- Server: a pgTAP or SQL script pushes the same 20 ops twice through `sync_push` and checks counts.
- Browser (release build via `tool/serve_web.py`, local Supabase, block requests to :54321 to go offline): 20 sales offline, reconnect, compare with the database.
  Also: scan a barcode on the Sell screen, utang then "nagbayad", cancel a sale, opening stock turns into an `opening` movement.
- Add `check:mobile` (analyze + test) to `pnpm check` if decision 16 is confirmed.
- Report table + known gaps in `docs/handoff.md`, status line updated, Next: Phase 4.
- Done when: `pnpm check`, `flutter analyze`, `flutter test` green. Use Sonnet.
