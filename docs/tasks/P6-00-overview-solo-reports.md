# Phase 6 (solo): Reports from rollups

Plan section 12 Phase 6, cut down for a solo store: daily and weekly sales, top items, utang owed. Reports read rollup tables, never raw sales (CLAUDE.md free-tier rule).

## Goal
The tindera opens "Ulat" and sees how much she sold in the last 7 or 30 days, a bar per day, what sold most, how it was paid, an estimated profit, and who owes her how much.
**Done when:** the rollups equal the raw sales on a seeded dataset (pgTAP); cancelling a sale takes it out of the rollups; the report RPC reads only rollup tables (plus the utang ledger); the screen works offline from its last result; `pnpm check` is green.

## Decisions (defaults; change before P6-01 if you disagree)
1. **Rollups:** `daily_sales_summary` (per store and day: gross, discount, net, tax, cost of goods, transactions, cash / e-wallet / utang) and `daily_item_sales` (per store, day and variant: qty, revenue, cost).
   Days are in the tenant's timezone. Maintained by deferred constraint triggers on `sales` (insert, and status change to voided), so items and payments already exist when they run, and a rejected op leaves nothing.
2. **Who reads:** superadmin and admins for their stores. Cashiers and warehouse see no reports.
3. **Profit is an estimate** (net minus the cost snapshot on each line); shown only when costs exist.
4. **Reports need the server.** The result of the last fetch is kept on the phone and shown offline with "as of". Sales not yet sent are not included, and the screen says how many are waiting.
5. **Utang** in the report is read live from the ledger (small table), not a rollup.
6. **Deferred:** CSV export, month/year pickers, per-hour charts, the 14 warehouse reports (Phase 5), `stock_snapshots_daily`, a usage meter (Phase 8).

## Cards
| Card | Work | Model |
| --- | --- | --- |
| P6-01 rollups and report RPC | migration, triggers, backfill, `report_summary`, pgTAP, isolation matrix rows | Opus |
| P6-02 Reports screen | Home tile, 7/30 day switch, bars, payments split, top items, utang, offline cache, fil + en | Sonnet |
| P6-03 acceptance | browser check, handoff report | Sonnet |
