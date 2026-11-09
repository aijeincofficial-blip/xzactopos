# P8-11 Expiry dates (DONE: server + data layer)

Server: migration `supabase/migrations/20261108001700_expiry_dates.sql`, pgTAP `supabase/tests/022_expiry_dates.test.sql` (65)
plus `stock_expiry` rows in the `004` isolation matrix (50).
Flutter data layer: Drift schema v10, `SalesStore` methods, sync engine, tests `apps/mobile/test/expiry_test.dart` (11).
**No screens**: the UI card (Sonnet) builds them on this API.

## Model and its limitation (read this before building the UI)
- **One date per product per store = the earliest expiry among what is on the shelf.** The tindera sets it when a batch comes
  in (stock in) or when she checks the shelf. Cleared = no date.
- **No lot accounting.** The app keeps no per-batch quantities, so it cannot know when the early batch is sold out while
  later stock remains: after selling or removing the early batch she sets the next date by hand. Only when the shelf is empty
  (quantity <= 0) does a stock in replace the date by itself.
- Stock is untouched by all of this: no movement, `stock_levels` stays trigger-derived; the dates live in their own table.

## Server
- `stock_expiry` (`tenant_id`, `location_id` (a store), `variant_id`, `expires_on date` (null = cleared), `created_at`,
  `updated_at` (trigger), `updated_by`), primary key `(location_id, variant_id)`, composite FKs to `locations` and
  `product_variants`. RLS: read like `stock_levels` (the user's stores; superadmin all); **no client writes**. The row is
  kept when cleared, so the pull can tell phones about the clear.
- Dates: a JSON string `YYYY-MM-DD` that is a real date from **2000-01-01 to today + 10 years**; a date in the past is allowed
  (already expired). Anything else: `invalid_value`.

### Who - mirrors receive_stock / adjust_stock (no new approval rules)
| Who | set_expiry, receive_stock with expires_on |
| --- | --- |
| owner (superadmin), admin who manages a store (`catalog_write_mode() = 'full'`) | yes |
| supervisor-only admin, cashier, warehouse | `not_allowed` |

### Ops (through `sync_push`, idempotent by `op_id`)
`{ op_id, kind: "set_expiry", payload }`
```json
{ "variant_id": "<uuid>", "expires_on": "2026-12-01", "location_id": "<store uuid>" }   // expires_on null = clear (key required)
```
Result `{ variant_id, location_id, expires_on, changed, applied_at, replay }`. The same date again: `changed: false`, nothing
written. `location_id` is optional when the user has exactly one store. Hints: `invalid_value`, `unknown_variant` (also another
tenant's), `location_required`, `location_denied` (a warehouse, another tenant's store), `not_allowed`, `module_disabled`,
`op_id_reused`.

`receive_stock` gains an **optional** `expires_on` (same format; missing or null = no date):
```json
{ "variant_id": "<uuid>", "qty": 12, "unit_cost": 4500, "location_id": "<store uuid>", "expires_on": "2027-03-01" }
```
Rule: if the level had **qty > 0 before this receipt** and a date is stored, the stored date becomes the **earlier** of the two;
otherwise the new date replaces it. Its result and its `stock.receive` audit meta gain `expires_on` (the stored date) **only when
one was sent**; without it receive_stock is exactly as before (013 unchanged, and 022 checks movement, level, average cost and
audit meta). A bad date refuses the whole receipt (no stock comes in). A receipt with a date always moves the row's `updated_at`
(even when the date stays) so a phone that guessed differently is corrected by the next pull.

Audit (only when the date changed; replays write nothing): `stock.set_expiry`, entity `variant`, meta
`{ expires_on, previous, op_id }` (+ `via: "receive_stock"` when a receipt changed it).

### Pull: `sync_pull_pos` (re-created, additive)
A new section with the same keyset rules as `stock_levels` (delta by `(updated_at, location|variant)`, 5 s hold-back):
```json
"stock_expiry": { "rows": [ { "location_id", "variant_id", "expires_on", "updated_at" } ], "cursor": {...}, "has_more": false }
```

## Device: store API (`lib/data/sales_models.dart`, implemented in `drift_sales.dart`)
```dart
Future<void> setExpiry({required String variantId, required DateTime? expiresOn, required String opId});
Future<void> receiveStock({required String variantId, required double qty, int? cost, DateTime? expiresOn,
    required String opId});                                   // expiresOn is new, optional: old calls are unchanged
Stream<List<StockRow>> watchExpiring({int withinDays = 7, DateTime? today});
Future<int> expiringCount({int withinDays = 7, DateTime? today});
```
- `StockRow` (from `watchStockList`, `watchExpiring`) gains `DateTime? expiresOn` (local date at midnight) and
  `bool expired(DateTime today)` (date before today), `bool expiringSoon(DateTime today, {int days = 7})` (not expired and at
  most `days` away; **today is expiring soon, not expired; yesterday is expired**), `int? daysLeft(DateTime today)` (0 = today,
  negative = expired, null = no date). Constants `expiryMinDate` (2000-01-01), `expiryMaxDaysAhead` (3650, a little inside the
  server's 10 calendar years so a time-zone difference never makes the server refuse what the phone accepted).
- `watchExpiring`: rows with **counted** stock on hand (qty > 0; never-counted products are left out) whose date is within
  `withinDays` of today or already past, soonest first, then by name. `today` is for tests.
- `setExpiry` keeps only the calendar date, throws `ArgumentError` outside the range and `StateError` for an unknown product,
  writes the local row and queues `set_expiry` (entity = the variant, so the stock row shows `pending`).
- `receiveStock(expiresOn:)` applies the server's rule to what this device sees (stock left = server level + unconfirmed local
  movements) and sends the batch date as given (`expires_on` only when given); the server decides and its copy replaces the
  phone's on the pull.
- Local table `stock_expiry` keyed by variant (a device works for one store): pulled rows of another store are skipped when
  the device knows its store (`locationId`); with no store set, the last row pulled wins (solo has one store). A local write
  leaves `updated_at` null; the pull leaves the row alone while a `set_expiry` or a `receive_stock` with `expires_on` for that
  variant is unsent.
- Drift v10: new table `stock_expiry` only (no cursor yet, so the first pull brings every date). Every existing row is kept.

## Sync
`set_expiry` goes through `sync_push` in order with the other ops (same batching, retry, backoff); `receive_stock` carries the
new field. A `rejected` result parks the op (`failedOps()`); `discardFailed(opId)` removes the locally written date (unless
another unsent op still carries one for that variant) and forces the full re-pull, which brings the server's date back.

## What the UI card must call
1. **Stock in (receive) sheet**: an optional "Expires on" date field -> `receiveStock(..., expiresOn: picked)`. Hint text: "the
   earliest date on the shelf is kept".
2. **Stock row / product detail**: show `expiresOn` with a badge (`expired(today)` red "Expired", `expiringSoon(today)` amber
   "N days left" from `daysLeft`); an action "Set expiry date" (date picker from 2000 to +10 years, past allowed) ->
   `setExpiry(variantId:, expiresOn:, opId: uuid.v7())`, and "Clear" -> `setExpiry(..., expiresOn: null, ...)`. Owner / manager
   only (others get `not_allowed`): hide for cashiers like stock in.
3. **Home**: an "Expiring soon (N)" tile from `expiringCount()` (or the stream length) opening a list from `watchExpiring()`.
4. **Stock screen**: an "Expiring" filter/section fed by `watchExpiring()`.
5. Explain the limitation once in the UI copy (one date per product: after the early batch is gone, set the next date).
All labels through ARB (en + fil), colors through theme tokens.
