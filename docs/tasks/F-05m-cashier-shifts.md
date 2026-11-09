# F-05m: Cashier shifts and X/Z reports on the phone

Part of priority 3 in `docs/handoff.md` ("cashier-ready Mobile Full"). The decision log says per-cashier shifts are needed before staff go live. What exists today: the owner's **day close** (one cash count per store and day, owner, admin manager or a supervisor with a PIN; cashiers can never close) and, on the web, X and Z slips drawn over those day closes. There is **no shift record per cashier**, so a cashier has no drawer of their own, and nothing on the phone shows an interim (X) or final (Z) reading.

## Decisions (defaults; change before the step that uses them starts)
1. **A shift is one cashier at one store, from open to close.** Its cash is the cashier's own: `opening cash + cash from the cashier's sales + utang payments the cashier took - cash expenses the cashier paid out`, counted over the shift's time window `[opened_at, closed_at]`. No new columns on sales, payments or expenses: the server attributes by the user who recorded them (`created_by`) and by time. So a shift needs no change to the sale path and works offline.
2. **One open shift per cashier at a time** (any store). Opening a second is refused (`shift_already_open`). A cashier cannot sell on a closed shift because selling does not depend on a shift; the shift only frames the cash count. (Making a sale require an open shift is a later, stricter option.)
3. **Who:** cashier, admin and owner can open and close their own shift at a store they are assigned to. An admin or the owner can also close someone else's shift (forgotten at night); the record says who closed it. Warehouse staff have no shifts.
4. **No supervisor PIN to close.** The count and the difference are recorded and visible to supervisors and owners; nothing blocks the till. (A PIN rule for large shortages can come with F-07.)
5. **The day close stays.** It is the owner's end-of-day count and is independent of shifts. A shift's Z reading is its own closed record.
6. **Offline:** `open_shift` and `close_shift` are ops through `sync_push` (idempotent by op id), like `close_day`. The phone works out the expected cash from its own data and sends it; the server stores that and also its own figure, so a mismatch is visible and never an error. The shift's time window uses the phone's clock for `opened_at` and `closed_at`, accepted within 14 days back and 5 minutes forward of the server's clock.
7. **X reading** (interim, does not reset anything) is drawn on the phone from local data for the open shift: opening cash, cash sales, utang collected, cash paid out, expected cash, number of sales and gross, non-cash tenders. **Z reading** is the closed shift record: counted, expected, difference, note, who closed it; it can be shared as text and reprinted from the history.
8. **Reads:** a cashier sees their own shifts; owner and admins see the shifts of their stores (row-level security).

## Steps
| Step | Work | Model |
| --- | --- | --- |
| S1 Server | migration: `shifts` table with guard and row-level security, `shift_server_expected`, `op_open_shift`, `op_close_shift`, `sync_push` with the two kinds, `sync_pull_shifts`; pgTAP; isolation matrix rows | Opus |
| S2 Phone data | Drift tables, store API (open, close, current shift, X figures, history), engine push and pull, tests | Opus |
| S3 Phone screens | open shift, X reading, close shift with count, Z slip and share, history; en + fil; entry on Sell and More; cashier role can reach it | Sonnet |
| S4 Acceptance | emulator run as a cashier and as the owner, report here | Sonnet |

## S1 result: server (2026-11-09)
Migration `20261109001100_shifts.sql`, pgTAP `044_shifts.test.sql` (41 tests), `shifts` added to the isolation matrix (`004`, 2,558 checks). Whole suite: 44 files, 4,550 tests.

- **`shifts` table** (one row per shift, opened by insert, closed by a single update, then never changed; no deletes; a half-closed row cannot exist). One open shift per cashier (unique index). Row-level security: a cashier reads their own shifts, owner and admins read the shifts of their stores, nobody writes from a client.
- **`op_open_shift`, `op_close_shift`** through `sync_push` (re-created from the newest definition, two new kinds), idempotent by op id. Refusals with hints: `not_allowed`, `location_denied`, `shift_already_open`, `id_conflict`, `shift_not_found`, `shift_closed`, `amount_invalid`, `invalid_value` (a time more than 14 days back or more than 5 minutes ahead, or a close before the open). Audit entries `shift.open` and `shift.close`.
- **`shift_server_expected`**: opening cash + the cashier's cash sales + utang cash they took - cash expenses they paid + their load / e-wallet cash effect, at the store, inside the shift window; voided sales and expenses and non-cash tenders left out. The phone's figure is stored next to it.
- **`sync_pull_shifts`**: keyset pull, open shifts always, closed ones for 30 days.
- **Mutation checks:** 18 rules broken on purpose; 17 caught, one equivalent (the table's own window check rejects a close before the open with the same hint).
- **Two older tests made robust:** `020_tingi_repack` and `021_utang_due_dates` counted audit rows across the whole database, so rows left by a real test account (my Solo emulator run) broke them; they now count only their own business.

## S2 result: phone data layer (2026-11-09)
Files: migration `20261109001200_shift_expected_now.sql` (+5 checks in `044_shifts`, now 46), `apps/mobile/lib/data/shift_models.dart`, `drift_shifts.dart`, `db.dart` (table `Shifts`, schema 16), `sync/sync_engine.dart`, `backend.dart`, `test/shift_store_test.dart` (22). Flutter 520 tests.

- **`shift_expected_now(shift)`** (server, read only): the server's own expected cash for a shift right now, for the cashier and for admins of the store. The phone asks it while online at closing time, because its own figure cannot tell another cashier's entries from this one's.
- **Store (`ShiftStore`, mixed into `DriftStore`):** `startShift` and `closeShift` are applied at once and queued (`open_shift`, `close_shift`); a cashier with a shift open cannot open another (`shift_already_open`), an id cannot be reused, a closed shift cannot be closed again, counts and opening cash cannot be negative, notes are cut to 200. `watchOpenShift`, `watchShifts` (history), and the **X reading** (`xReading` / `watchXReading`): opening cash + cash sales + utang cash taken - cash expenses + load / e-wallet cash effect, plus the number of sales, gross, e-wallet and utang tenders, for the window from the start of the shift to now (or to its close). Reading it changes nothing.
- **What the X reading can and cannot know:** cash sales count only sales made on this phone (or from before devices were numbered); entries without a device (utang payments, expenses, load) count for the whole store as this phone sees it. So a close made offline uses this estimate, and the server keeps both figures side by side (`ShiftView.serverDisagrees`).
- **Sync:** `open_shift` / `close_shift` go through `sync_push` in order; a close brings back the server's own figure; `sync_pull_shifts` (optional `ShiftApi`, store phones only) brings the open shift and 30 days; a pull never undoes a change of this phone that is still unsent; a refused open shows as refused and discarding it removes the shift; the schema step is a new table only (a version 15 phone keeps every row and unsent op); another business's shifts never stay on the phone.
- **Mutation checks:** 25 rules broken on purpose; 21 caught first time, four survivors (pulled utang payment sign, voided expenses, the saved cursor, and a pattern that did not match) led to added tests; all 25 now caught.

