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

## S3 result: phone screens (2026-11-09)
Files: `apps/mobile/lib/screens/shift_screen.dart` (new), `sell_screen.dart` (shift button beside the Today strip, the strip text now shrinks instead of overflowing), `home_shell.dart` (More > Shift for every selling role), `lib/l10n/*.arb` (30 `shift*` keys, en + fil), `test/shift_screen_test.dart` (12). Flutter 532 tests.

- **Shift screen:** with no shift open: the cash in the drawer to start with (prefilled with what the last shift counted) and Start shift. With one open: the **X reading** (cash that should be in the drawer, opening cash, cash sales, utang paid in cash, cash paid out, load / e-wallet cash, number of sales and total, e-wallet and utang tenders, a note that sales made on other phones are not included), Share this reading (text), and Close shift. History of recent shifts (tap for the report).
- **Closing:** a sheet asks for the cash counted and shows short / over live. Online, it first asks the server for its own expected cash and uses that ("Figure from the server"); offline, or for a shift the server has not heard of yet, it uses the phone's ("Figure from this phone"). Confirm waits until the question is answered. The count and the figure shown are what is saved and sent.
- **Z report:** shown right after closing and from the history: store, opened and closed times, opening cash, expected, counted, short or over, note, a warning when the server worked out a different figure, "not sent yet" while it waits; shareable as text.
- **Entry points:** a small lock button next to Today on Sell (open or not) and Shift under More, for owner, admins and cashiers.
- **Mutation checks:** 12 rules broken on purpose (unsent shift asked about, server figure ignored, confirm allowed while asking, note not sent, disagreement hidden, opening default ignored, bad opening accepted, wrong cashier's shift, share without the figure, history not listing closed shifts, no chip, no tile); all caught after two tests were added (the prefilled opening and the disabled confirm).

## S4 result: emulator acceptance (2026-11-09)
Android 13 emulator, debug build, local Supabase, the Solo test store (`solo-e423847bcdeb`) with its owner `tindera.p1@example.test` and a cashier `pia` made through the `create_user` function. English UI.

| Check | Result |
| --- | --- |
| Upgrade of the phone's database from schema 15 to 16 with real data on it | **Pass.** The app opened with every sale, product, pin and stock figure intact (₱103 sales today, pinned item, stock) and the new lock button beside the Today strip |
| Owner, airplane mode on: open a shift with ₱200, sell 2 Kape for cash (₱16), read the X, close with ₱214 counted | **Pass.** X showed ₱216.00 (opening 200 + cash sales 16; the ₱103 sold earlier that day is not in it), 1 sale; the close sheet said "Figure from this phone" and "Short by ₱2.00"; the Z report showed opened and closed times, 200 / 216 / 214 and the short amount, with the "not sent" icon; 3 changes waited |
| Reconnect | **Pass.** The three ops went through in order; the server row has opening 20000, the phone's expected 21600, the server's own 21600, counted 21400, difference -200, cashier = the owner |
| Cashier signs in on the same phone | **Pass.** No shift shown as open for her (the owner's was not hers) |
| Cashier, online: start with ₱100, sell one Kape (₱8), read the X, close with ₱107 | **Pass.** X ₱108.00; the close sheet said "Figure from the server" (₱108.00); the server row: opening 10000, expected 10800, server 10800, counted 10700, difference -100 |
| Who can read what on the server (over the API) | **Pass.** The cashier reads and pulls her own shift only (1); the owner reads and pulls both (2) |

**Finding (fixed):** on a shared phone the cashier's "Recent shifts" also listed the owner's earlier shift (the phone made it, so it is in the local database). The history now shows a cashier only their own shifts; owner and admins see all of them on the phone. Test added; fails without the filter.

**Not covered:** closing a shift while the server's figure differs from the phone's (covered by tests only), a shift left open overnight, an admin closing someone else's shift from the phone (the server allows it; there is no screen for it yet), the supervisor PIN (shifts need none by decision 4), and a real printer.

## What is done and what is not (F-05m)
Done: server (S1), phone data and sync (S2), screens (S3), acceptance (S4). **Not done:** printing an X or Z slip (sharing text only), closing someone else's shift from the phone, staff management on the phone (the other half of priority 3: creating cashiers and assigning stores still happens on the web).

