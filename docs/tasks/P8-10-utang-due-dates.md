# P8-10 Utang due dates, overdue list, statement text (DONE: server + data layer)

Server: migration `supabase/migrations/20261108001600_utang_due_dates.sql`, pgTAP `supabase/tests/021_utang_due_dates.test.sql` (38).
No new table (a column on `customers`), so no isolation-matrix rows.
Flutter data layer: Drift schema v9, `SalesStore` methods, sync engine, `lib/core/utang_statement.dart`, tests
`apps/mobile/test/utang_due_test.dart` (13). **No screens**: the UI card (Sonnet) builds them on this API.

## Model
- `customers.due_on date` (nullable): the date the customer promised to pay. One per customer, not per charge (decision 6:
  "due date per customer"). A partial payment is already a payment; nothing else changes in the ledger.
- **Overdue is derived, never stored**: `balance > 0 and due_on < today` (device local date). A date due **today is not overdue**;
  yesterday is (1 day). Paying in full does not clear the date (she is simply not overdue any more); the next promise replaces it.

## Server
### Who (the UI hides; the server enforces) - same as `upsert_customer` / `record_utang_payment` (`assert_seller`)
| Who | set_utang_due |
| --- | --- |
| owner (superadmin), admins (manager or supervisor), cashiers | yes |
| warehouse staff (they do not see utang) | `not_allowed` |
| a tenant without the POS module | `module_disabled` |

A due date is a promise noted at the counter and moves no money, so it does not get the owner-only rule of `adjust_utang`.

### Op (through `sync_push`, idempotent by `op_id`)
`{ op_id, kind: "set_utang_due", payload }`
```json
{ "customer_id": "<uuid>", "due_on": "2026-11-15" }      // or "due_on": null to clear; the key must be present
```
Result `{ customer_id, due_on, changed, applied_at, replay }`. Sending the same date again: `changed: false`, nothing written.
Rules: `due_on` is a JSON string `YYYY-MM-DD` that is a real date (no time part, no slashes, no number) or `null`; at most
2 calendar years before or after the server's today. Hints: `invalid_value` (missing key, bad form, not a real date, too far),
`unknown_customer` (also another tenant's customer), `not_allowed`, `module_disabled`, `op_id_reused`.
Audit (only when the date changed; replays write nothing): `utang.set_due`, entity `customer`, meta `{ due_on, previous, op_id }`.

### Pull: `sync_pull_pos` (re-created, additive)
`customers` rows gain `due_on` (`"YYYY-MM-DD"` or null):
```json
"customers": { "rows": [ { "id", "name", "phone", "due_on", "updated_at", "deleted_at" } ], "cursor": {...}, "has_more": false }
```
A change moves `customers.updated_at` (trigger), so the normal delta pull sends the row again (tested: the delta after the first
cursor returns exactly the changed customer).

## Device: store API (`lib/data/sales_models.dart`, implemented in `drift_sales.dart`)
```dart
Future<void> setUtangDue({required String customerId, required DateTime? dueOn, required String opId});
Stream<List<CustomerView>> watchOverdueCustomers({DateTime? today});   // balance > 0, due before today, earliest due first, then name
Future<int> overdueCount({DateTime? today});
```
- `CustomerView` (every customer query) gains `DateTime? dueOn` (local date at midnight), `bool overdue(DateTime today)`,
  `int daysOverdue(DateTime today)` (0 when not overdue). Helpers in `sales_models.dart`: `dateOnly`, `daysBetween` (calendar
  days, DST-safe), `parseDay('YYYY-MM-DD')`, constant `utangDueMaxDays = 728` (a little inside the server's 2 years so a time-zone
  difference never makes the server refuse what the phone accepted).
- `setUtangDue` keeps only the calendar date of `dueOn`, throws `ArgumentError` beyond `utangDueMaxDays` from today and
  `StateError` for an unknown customer, writes `customers.due_on` and queues `set_utang_due` with **entity = the customer id**
  (so `CustomerView.pending` is true and the pull leaves the local row alone until the op has gone; then the server copy
  replaces it - nothing to count twice, it is one field).
- `today` on the two overdue calls is for tests; screens leave it out (device local date).
- Drift v9: `customers.due_on` (text `YYYY-MM-DD`), added only if missing; every row and unsent op kept; the `customers` cursor
  is dropped so customers are pulled again (a date set elsewhere is not missed).

## Sync
`set_utang_due` goes through `sync_push` in order with the other ops (same batching, retry, backoff). A `rejected` result parks
it as failed (`failedOps()`); `discardFailed(opId)` drops it and forces the full re-pull, which brings the server's date back.

## Statement (`lib/core/utang_statement.dart`)
```dart
String utangStatementText({required String storeName, required CustomerView customer, required List<LedgerEntryView> ledger,
    required String currency, required String locale, required StatementLabels labels});
class StatementLabels { title, balance, dueOn, recent, charge, payment, adjust }   // all String, from ARB
const statementMaxLines = 10;
```
Output (lines joined with `\n`):
```
Tindahan ni Nena
Utang statement: Aling Rosa
Balance: ₱150.50
Due on: 2026-11-15            <- only when a due date is set

Recent:                       <- block left out when the ledger is empty
2026-11-08  Adjustment  +₱0.50
2026-11-07  Paid  -₱50.00
```
Newest first (ties keep the given order), at most 10 lines, dates `YYYY-MM-DD` in every language, money through
`Money.format(locale)` with an explicit sign on ledger lines (+ owes more, - owes less; a balance paid ahead shows `-`).
**Never** the customer's phone number (it is only the destination) and never ledger notes (a note may hold anything).

## What the UI card must call
1. **Customer screen (Utang detail)**: a "Promised to pay on" row: date picker (today .. +2 years; past allowed) ->
   `setUtangDue(customerId:, dueOn: picked, opId: uuid.v7())`; a clear action -> `setUtangDue(..., dueOn: null, ...)`. Show
   `customer.dueOn`, and when `customer.overdue(DateTime.now())` an "overdue N days" badge (`daysOverdue`), `pending` like now.
2. **Utang list**: mark overdue rows; optional filter "Overdue" fed by `watchOverdueCustomers()`.
3. **Home / Today**: an "Overdue utang (N)" card from `overdueCount()` (or the stream's length), tapping opens the filtered list.
4. **Share statement** on the customer screen: build the text with `utangStatementText(storeName:, customer:, ledger: <the
   watchLedger list>, currency: store.baseCurrency, locale: Localizations.localeOf(context).toLanguageTag(), labels:
   StatementLabels(...ARB strings...))` and hand it to the system share sheet (share_plus `Share.share(text)`), with the
   customer's phone only as the SMS destination if the UI offers SMS. New ARB keys (en + fil) for the 7 labels plus the screen
   texts; colors through theme tokens.
5. Refused op (`not_allowed`, `invalid_value`): show like other parked ops; "discard" = `discardFailed`.
