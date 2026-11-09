# P8-02 Expenses: schema, RLS, ops, rollup, pgTAP (DONE)

Migration `supabase/migrations/20261108001100_expenses.sql`. Tests `supabase/tests/016_expenses.test.sql` (79) plus isolation-matrix rows in `004`.

## What exists
- `expenses`: append-only ledger row. Client UUIDv7 `id`, `tenant_id`, `location_id` (a store), `client_op_id` (unique per tenant),
  `amount` (bigint centavos, > 0), `currency` (always the tenant base currency), `category`, `note`, `paid_from`, `spent_at`,
  `created_by`, `created_at`, `updated_at`, `deleted_at` (never set; void instead), `voided_at`, `void_reason`.
  A trigger refuses every update and delete except one void (voided_at null -> set). No status column: voided = `voided_at is not null`.
- `daily_expense_summary`: per store, day (tenant timezone, from `spent_at`) and category: `amount`, `entry_count`, `cash`, `ewallet`.
  Kept by AFTER triggers on insert and on void; voided expenses are taken out. A category whose entries were all voided stays as a 0 row.
- Who may record or void (P8-02b, migration `20261108001200_expense_supervisor_approval.sql`, tests `017_expense_approvals.test.sql`):
  | Who | Needs |
  | --- | --- |
  | superadmin (solo owner) | nothing |
  | admin, **manager** of that store | nothing |
  | admin, **supervisor** of that store | a supervisor approval (`approval_id`), one per op |
  | cashier, warehouse | always `not_allowed` |
- Who may read `expenses` and the rollup: superadmin and admins, for their stores (same as the sales rollups). Cashiers read nothing.
- Columns `approved_by` (who approved the record) and `void_approved_by` (who approved the void); null when no approval was needed.
- Audit: every successful record / void writes one `audit_log` row (`expense.record` / `expense.void`, entity `expense`,
  meta `{ location_id, amount, category, paid_from, op_id, approved_by?, reason? }`). Replays and a second void of the same expense write nothing.
  Wrong PINs write `pin.failed` (entity `profile`, entity_id = approver). A granted approval writes `approval.grant`.
  An op refused for a missing or bad approval is **not** logged (sync_push rolls the op back; logging it would mean changing sync_push).
  Who reads the audit log is unchanged: owner all, managers their stores; supervisors and cashiers none.

## Supervisor credential (PIN -> approval)
1. `set_my_pin(p_new_pin text, p_current_pin text default null)` -> `{ ok: true }` or `{ ok: false, hint: pin_wrong | pin_locked }`.
   4 to 8 digits (raises `pin_invalid`); changing an existing PIN needs the current one (raises `pin_required`).
   Stored as `pbkdf2_sha256$20000$<salt b64>$<hash b64>` in `profiles.pin_hash` (never readable by clients).
   `clear_user_pin(p_user_id)`: owner only, for a forgotten PIN.
2. `approve_supervisor_action(p_action, p_ref_id, p_pin, p_location_id default null, p_approver_id default null)` (**needs signal**).
   - `p_action`: `record_expense` | `void_expense`; `p_ref_id`: the expense id (for a record, make the UUIDv7 first, then ask).
   - `p_approver_id`: null = the signed-in supervisor confirms with her own PIN; or the user id of a manager / the owner who types theirs.
   - Store: the expense's store for a void the server already has, else `p_location_id` (or the user's only store).
   - Returns `{ ok: true, approval_id, approved_by, expires_at }` or `{ ok: false, hint: pin_wrong | pin_locked | pin_not_set }`
     (returned, not raised, so wrong tries stay logged). Raises `not_allowed` (caller is not a supervisor of the store),
     `approver_invalid` (approver is not owner/supervisor/manager there, or inactive), `invalid_value`, `location_required`, `location_denied`.
   - 5 wrong PINs for one approver within 15 minutes lock that approver's PIN until the window passes.
3. Put `approval_id` in the op payload and push as usual. The approval is single use, bound to requester + store + action + expense id,
   valid 12 hours, and re-checked at sync (approver still active and still supervisor/manager there).

**Offline:** owner and managers record and void offline exactly as before. A supervisor needs signal at the moment of the PIN
(to get the approval); after that the op can sit in the outbox up to 12 hours with no signal. With no signal at all a supervisor
cannot record or void an expense (show "needs signal for the supervisor PIN"). True offline PIN checks need the offline PIN RPC (Full mode).

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
  "location_id": "<store uuid>",   // optional when the user has exactly one store (solo)
  "approval_id": "<uuid>"          // only for a store supervisor (see above)
}
```
Result: `{ expense_id, approved_by, applied_at, replay }`.

`{ op_id, kind: "void_expense", payload }`
```json
{ "expense_id": "<uuid>", "reason": "maling halaga", "approval_id": "<uuid>" }   // reason optional (max 200); approval_id for a supervisor
```
Result: `{ expense_id, already, approved_by, applied_at, replay }` (`already: true` when it was voided before; nothing changes).

Rejection hints (map to i18n): `not_allowed`, `amount_invalid`, `invalid_value` (category, paid_from, currency, bad JSON),
`id_required`, `id_conflict` (expense id already used by another op), `location_required`, `location_denied`,
`expense_not_found`, `op_id_reused`, `module_disabled`, and for supervisors `approval_required`, `approval_invalid`
(wrong store, expense, action, requester, tenant, or the approver lost the right), `approval_used`, `approval_expired`.

## Pull: `sync_pull_expenses(p_cursor jsonb default null, p_limit int default 100)` (1..200)
Same rules as `sync_pull_sales`: first pull (cursor null) = last 30 days by `spent_at`; afterwards delta by `(updated_at, id)`;
rows newer than now - 5 s wait for the next pull; a void comes again because `updated_at` moves.
```json
{
  "rows": [ { "id", "location_id", "amount", "currency", "category", "note", "paid_from", "spent_at",
              "created_by", "approved_by", "voided_at", "void_reason", "void_approved_by", "updated_at" } ],
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
