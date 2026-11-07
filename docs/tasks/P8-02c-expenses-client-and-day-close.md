# P8-02c Expenses on the device + day close (DONE)

Server: migration `supabase/migrations/20261108001300_day_close.sql`, pgTAP `supabase/tests/018_day_close.test.sql` (53) plus
`day_closes` rows in the `004` matrix. Flutter data layer: Drift schema v6, `SalesStore` methods, sync engine, `Backend` PIN calls,
tests `apps/mobile/test/expenses_test.dart` (17). **No screens**: P8-03 (Sonnet) builds them on this API.

## Server: day close
- `day_closes`: append-only (a guard refuses every edit and delete). Client UUIDv7 `id`, `tenant_id`, `location_id` (a store),
  `client_op_id`, `day` (date in the tenant timezone, like `daily_sales_summary.day`), `currency` (base), `expected_cash`,
  `counted_cash` (>= 0), `difference` (= counted - expected, stored, checked), `server_expected_cash`, `note`, `closed_by`,
  `approved_by`, `closed_at`, `created_at`, `updated_at`, `deleted_at`. Several closes per store and day are allowed (a re-count);
  the UI shows the newest `closed_at`.
- Read: superadmin and admins for their stores (same as expenses). No client writes.
- `server_expected_cash` is computed by the server when it applies the op, from its own rows for that store and day:
  cash payments of completed sales + utang payments (`customer_ledger` kind `payment`) - non-voided cash expenses.
  It never refuses a close: a mismatch with the phone's `expected_cash` is just visible.
  **Utang payments have no store on the server** (`customer_ledger` has no `location_id`), so they count tenant-wide:
  exact for the solo store, overstated per store with several stores until the ledger records a store.
- Who may close: owner, store manager (no extra step), store supervisor with a supervisor approval (`action = 'close_day'`,
  `ref_id` = the day close id). Cashiers and warehouse: `not_allowed`. `approve_supervisor_action` now accepts `close_day`.
- Audit: one `audit_log` row per close (`day.close`, entity `day_close`, meta `{ location_id, day, expected_cash, counted_cash,
  difference, server_expected_cash, op_id, approved_by? }`); replays write nothing.

### Op (through `sync_push`, idempotent by `op_id`)
`{ op_id, kind: "close_day", payload }`
```json
{
  "id": "<uuid v7, required>",
  "day": "2026-11-08",            // YYYY-MM-DD, not later than tomorrow in the tenant timezone
  "expected_cash": 120000,         // whole centavos, may be negative
  "counted_cash": 118000,          // whole centavos >= 0
  "closed_at": "2026-11-08T12:00:00Z", // optional, default now()
  "note": "kulang ng 20",          // optional, trimmed, max 200
  "currency": "PHP",               // optional; must be the base currency
  "location_id": "<store uuid>",   // optional when the user has exactly one store
  "approval_id": "<uuid>"          // only for a store supervisor
}
```
Result: `{ day_close_id, day, difference, server_expected_cash, approved_by, applied_at, replay }`.
Hints: `not_allowed`, `id_required`, `id_conflict`, `invalid_value` (day, currency, bad JSON), `amount_invalid`, `location_required`,
`location_denied`, `op_id_reused`, `module_disabled`, `approval_required`, `approval_invalid`, `approval_used`, `approval_expired`.

### Pull: `sync_pull_day_closes(p_cursor jsonb default null, p_limit int default 100)` (1..200)
Same rules as `sync_pull_expenses`: first pull = last 30 days by `closed_at`, then delta by `(updated_at, id)`, rows newer than
now - 5 s wait. Rows: `{ id, location_id, day, currency, expected_cash, counted_cash, difference, server_expected_cash, note,
closed_by, approved_by, closed_at, updated_at }`, plus `cursor`, `has_more`, `server_time`. Cashiers get none.

## Device: store API (`lib/data/sales_models.dart`, implemented in `drift_sales.dart`)
```dart
Future<void> recordExpense({required String id, required int amount, required String category, String paidFrom = 'cash',
    String? note, DateTime? spentAt, String? approvalId, required String opId});
Future<void> voidExpense({required String expenseId, String? reason, String? approvalId, required String opId});
Stream<List<ExpenseView>> watchExpenses({required DateTime from, required DateTime to});
Stream<ExpenseTotals> watchTodayExpenses();
Future<int> expectedCash(DateTime day);
Stream<int> watchExpectedCash(DateTime day);
Future<void> closeDay({required String id, required DateTime day, required int countedCash, String? note,
    String? approvalId, required String opId});
Stream<DayCloseView?> watchLatestDayClose(DateTime day);
Future<void> requeueWithApproval({required String opId, required String approvalId});
// sync side
Future<void> applyPullExpenses(Map<String, dynamic> response);
Future<void> applyPullDayCloses(Map<String, dynamic> response);
```
- Money is integer centavos. `expenseCategories`, `expensePaidFrom`, `approvalHints`, `needsApproval(hint)`, `dayKey(DateTime)`
  live next to the views. Labels come from ARB keys (P8-03), never from these strings.
- `ExpenseView`: id, amount, category, paidFrom, note, spentAt, voidedAt / `voided`, voidReason, approvedBy, `pending`
  (an op is still in the outbox), `rejectedHint` (the server refused an op for it; waits for the user).
  `ExpenseTotals`: count, total, cash, ewallet (voided left out). `DayCloseView`: id, day, expectedCash, countedCash, difference
  (below 0 = short / kulang, above 0 = over / sobra), serverExpectedCash (null until pulled), note, closedAt, approvedBy,
  pending, rejectedHint.
- `expectedCash(day)` (local calendar day): cash payments of completed sales + utang payments (pulled and local) - cash
  expenses not voided. Includes unsent local ops; voided sales/expenses excluded; no opening float. `closeDay` stores the
  value of that moment. The local `sales` table has no store column, so a phone that pulled several stores' sales counts them all.
- Local effects: an expense / close is one row (like a sale). The pulled server copy replaces it (so nothing counts twice); a
  local void still on its way is kept until the server's voided copy comes. Utang payments use the existing
  `local_ledger` -> `server_ledger` hand-over.
- `discardFailed(opId)` now also takes back a refused `record_expense` (row removed), `void_expense` (void undone), `close_day`.

## Sync
- `record_expense`, `void_expense`, `close_day` go through `sync_push` in order with the other ops (same batching, retry and
  backoff). A `rejected` result parks the op as failed with the hint (shown via `failedOps()` / `rejectedHint`), never an endless
  retry; a transient `error` keeps it queued in order.
- After sales the engine pulls expenses and day closes (`SyncApi.pullExpenses`, `pullDayCloses`; cursors `expenses`, `day_closes`).

## Supervisor flow (what P8-03 must call)
Owner / manager: just call `recordExpense` / `voidExpense` / `closeDay` (works offline). A store supervisor:
1. Make the id first (`uuid.v7()`: the expense id, or the day close id; for a void it is the expense id).
2. `final r = await backend.approveSupervisorAction(action: 'record_expense' | 'void_expense' | 'close_day', refId: id, pin: pin,
   locationId: store, approverId: null /* or a manager's user id who types their PIN */)`. **Needs signal now**; it throws when
   offline: show "the supervisor PIN needs signal". `r.ok == false` -> show `r.hint` (`pin_wrong`, `pin_locked`, `pin_not_set`,
   `not_allowed`, `approver_invalid`, ...). Clear the PIN field right after.
3. Queue the op with `approvalId: r.approvalId`. It may wait in the outbox up to 12 h without signal.
4. If it comes back refused with `needsApproval(hint)` (e.g. `approval_expired`), ask for a new approval for the same id and call
   `requeueWithApproval(opId:, approvalId:)`, or `discardFailed(opId)`.
The PIN never goes into the outbox, Drift, logs or analytics; only the approval id travels (a test scans every local table).
`backend.setMyPin(newPin, currentPin: ...)` sets the user's own PIN (result hints `pin_wrong`, `pin_locked`, `pin_invalid`, `pin_required`).

## Tests
`expenses_test.dart`: local record/void/close, validation, expectedCash example and a seeded property test (random sales with
splits, voids, utang payments, cash/e-wallet expenses and voids on today and yesterday vs an independent sum), the same through
a sync (before, during and after the server copies arrive), queueing and replay after a lost reply, approval rejections,
requeue, discard, transient error order, paged pulls with the 5 s hold-back, v5 -> v6 upgrade keeping data, no PIN stored.
