# P8-02 Expenses: schema, RLS, ops, rollup, pgTAP (DONE)

Migration `supabase/migrations/20261108001100_expenses.sql`. Tests `supabase/tests/016_expenses.test.sql` (79) plus isolation-matrix rows in `004`.

## What exists
- `expenses`: append-only ledger row. Client UUIDv7 `id`, `tenant_id`, `location_id` (a store), `client_op_id` (unique per tenant),
  `amount` (bigint centavos, > 0), `currency` (always the tenant base currency), `category`, `note`, `paid_from`, `spent_at`,
  `created_by`, `created_at`, `updated_at`, `deleted_at` (never set; void instead), `voided_at`, `void_reason`.
  A trigger refuses every update and delete except one void (voided_at null -> set). No status column: voided = `voided_at is not null`.
- `daily_expense_summary`: per store, day (tenant timezone, from `spent_at`) and category: `amount`, `entry_count`, `cash`, `ewallet`.
  Kept by AFTER triggers on insert and on void; voided expenses are taken out. A category whose entries were all voided stays as a 0 row.
- Who may record or void: the owner (superadmin) or an admin who is **manager of that store**. Cashiers and warehouse: `not_allowed`.
- Who may read `expenses` and the rollup: superadmin and admins, for their stores (same as the sales rollups). Cashiers read nothing.

## Ops (through `sync_push`, idempotent by `op_id`)
`{ op_id, kind: "record_expense", payload }`
```json
{
  "id": "<uuid v7, required>",
  "amount": 15000,                 // whole centavos > 0 (number or digit string; no decimals)
  "category": "utilities",         // stock_purchase | utilities | transport | wages | rent | other
  "paid_from": "cash",             // cash | ewallet   (optional, default cash)
  "note": "Meralco",               // optional, trimmed, max 200
  "spent_at": "2026-11-08T02:00:00Z", // optional, default server now()
  "currency": "PHP",               // optional; must equal the tenant base currency
  "location_id": "<store uuid>"    // optional when the user has exactly one store (solo)
}
```
Result: `{ expense_id, applied_at, replay }`.

`{ op_id, kind: "void_expense", payload }`
```json
{ "expense_id": "<uuid>", "reason": "maling halaga" }   // reason optional, max 200
```
Result: `{ expense_id, already, applied_at, replay }` (`already: true` when it was voided before; nothing changes).

Rejection hints (map to i18n): `not_allowed`, `amount_invalid`, `invalid_value` (category, paid_from, currency, bad JSON),
`id_required`, `id_conflict` (expense id already used by another op), `location_required`, `location_denied`,
`expense_not_found`, `op_id_reused`, `module_disabled`.

## Pull: `sync_pull_expenses(p_cursor jsonb default null, p_limit int default 100)` (1..200)
Same rules as `sync_pull_sales`: first pull (cursor null) = last 30 days by `spent_at`; afterwards delta by `(updated_at, id)`;
rows newer than now - 5 s wait for the next pull; a void comes again because `updated_at` moves.
```json
{
  "rows": [ { "id", "location_id", "amount", "currency", "category", "note", "paid_from", "spent_at",
              "created_by", "voided_at", "void_reason", "updated_at" } ],
  "cursor": { "ts": "<updated_at>", "k": "<id>" },
  "has_more": false,
  "server_time": "..."
}
```

## Report: `report_summary(from, to)` now also returns
```json
"expenses": { "total", "cash", "ewallet", "count",
              "by_category": [ { "category", "amount", "count" } ],   // largest first, all-voided categories left out
              "days": [ { "day", "amount" } ] }
```
Read from `daily_expense_summary` only. Net profit for P8-04 = `totals.net - totals.cogs - expenses.total`.
