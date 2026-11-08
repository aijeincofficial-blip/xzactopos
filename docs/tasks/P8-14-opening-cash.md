# P8-14 Opening cash (sukli) in the day close (DONE: server + data layer)

Added card (not in the original P8 list). Server: migration `supabase/migrations/20261108001800_opening_cash.sql`, pgTAP
`supabase/tests/023_opening_cash.test.sql` (37); `018` pull key list gained `opening_cash`. No new table, no matrix rows.
Flutter data layer: Drift schema v11, `SalesStore` API below, tests `apps/mobile/test/opening_cash_test.dart` (10).
**No screens**: the day close screen (Sonnet) builds on this API.

## Problem
Expected cash at the close was only the day's cash flow (cash sales + utang payments + service cash - cash expenses). A store
keeps coins and bills in the drawer overnight (the sukli), so a day with only an expense showed a negative expected cash and
the over/short was off by exactly the opening amount.

## Model
- **Opening cash** = the cash the tindera started the day with, centavos >= 0.
- **Default** = the counted cash of the most recent earlier close: the close with the newest `closed_at` among closes of a
  day **before** this day, at this device's store (closes with no store count too); 0 when there is none. Closes of the same
  day (re-counts) and of later days never count. Computed **on the device only**; the owner may override it when closing.
- **Expected cash = opening cash + day cash flow.** `difference = counted - expected` is unchanged (both sides now include
  the opening). Closes made before P8-14 have opening 0 and keep their meaning.

## Server
- `day_closes.opening_cash bigint not null default 0 check (opening_cash >= 0)`; append-only like the other columns (the
  guard trigger freezes it; it is set only by the insert in `op_close_day`).
- `op_close_day` (re-created; sync_push unchanged, it calls it) accepts an optional `opening_cash`:
  ```json
  { "id": "<uuid>", "day": "2026-11-08", "opening_cash": 50000, "expected_cash": 49700, "counted_cash": 49600,
    "closed_at": "...", "note": "...", "location_id": "<store uuid>", "approval_id": "<uuid>" }
  ```
  `opening_cash`: whole centavos >= 0, JSON number or digit string; absent or `null` = 0; anything else (negative, fraction,
  decimal string, text, boolean, object, > 15 digits) = `amount_invalid`, nothing written. `expected_cash` (the phone's) now
  **includes** the opening cash. The server stores the opening as sent and sets
  `server_expected_cash = opening_cash + day_close_server_expected(tenant, store, day)` (the day cash flow function itself is
  unchanged). Result gains `opening_cash`: `{ day_close_id, day, difference, opening_cash, server_expected_cash, approved_by,
  applied_at }`. Who may close, approvals, day/amount rules and replays are unchanged.
- Audit `day.close` meta gains `opening_cash` (0 when none was sent).
- `sync_pull_day_closes` rows gain `opening_cash` (additive).

## Device: store API (`lib/data/sales_models.dart`, implemented in `drift_sales.dart`)
```dart
Future<int> defaultOpeningCash(DateTime day);
Future<int> expectedCash(DateTime day, {int? openingCash});
Stream<int> watchExpectedCash(DateTime day, {int? openingCash});
Future<void> closeDay({required String id, required DateTime day, required int countedCash, int? openingCash,
    String? note, String? approvalId, required String opId});
```
- `expectedCash` / `watchExpectedCash`: day cash flow **plus** `openingCash` when given, otherwise plus
  `defaultOpeningCash(day)`. **Existing callers that pass nothing now get the default opening included** (that is the fix);
  pass `openingCash: 0` for the cash flow alone. Negative `openingCash` throws `ArgumentError`. The watched figure also moves
  when an earlier close arrives (it reads `day_closes`).
- `closeDay`: opening used = `openingCash ?? defaultOpeningCash(day)` (negative = `ArgumentError`, nothing written); stores
  it in the row, computes `expected = expectedCash(day, openingCash: opening)` and `difference = counted - expected`, and
  queues `close_day` with `opening_cash` (always sent, 0 included) and that `expected_cash`.
- `DayCloseView.openingCash` (int, 0 for older closes); `watchLatestDayClose` fills it.
- Pulled closes replace local rows as before and carry `opening_cash` (missing from an older server = 0).
- Drift v11: column `day_closes.opening_cash` (default 0) added, every row kept; no re-pull (server rows before P8-14 are 0).

## What the screen must call
1. On open: `defaultOpeningCash(day)` to prefill an "Opening cash (sukli)" field the owner can change (money input, >= 0).
2. Show `watchExpectedCash(day, openingCash: typedOpening)`; update the help line to "Opening cash + cash sales + utang
   payments + services - cash expenses" (ARB en + fil).
3. Save with `closeDay(..., openingCash: typedOpening)` so the stored opening, expected and difference match what was shown.
4. After a close, show `DayCloseView.openingCash` with the other figures.
Until the screen changes, the current screen already gets the default opening in both the shown expected cash and the saved
close (both calls pass nothing, so both use the same default).
