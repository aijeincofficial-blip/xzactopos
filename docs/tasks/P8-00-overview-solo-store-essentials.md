# Phase 8 (solo): Store essentials for a sari-sari tindera

Solo is accepted (Phases 0 to 7) but a real store needs more than sell, utang and stock. This phase adds what a tindera does every day that the app cannot do yet. Barcode hardware and printing stay set aside.

## Goal
A tindera can run a whole day in the app: sell fast, take cash-in/out and load, spend money, count the drawer at night, know what to buy tomorrow, and chase utang politely.
**Done when:** each card below is accepted on the emulator, `pnpm check` is green, and a new-day walk-through (open, 20 sales, load, expense, restock, close with cash count) works offline and syncs without a conflict.

## Decisions (defaults; change before the card starts)
1. **Quick-sell is derived, not stored.** The Sell screen shows a "Top sellers" strip built from the last 30 days of local sale lines. No migration, no sync. A manual pin list can come later.
2. **Expenses and the cash count are append-only ledger entries** (like sales). A day close is a count entry that records expected cash, counted cash and the difference. Nothing is edited, only voided by a reversing entry.
3. **Load / e-wallet service** (GCash cash-in, cash-out, prepaid load) is a service sale: no stock, a fee or commission is the revenue, the principal moves cash <-> e-wallet float. It needs its own `service_txn` kind in the ledger, not a fake product.
4. **Tingi / repack** is a conversion: one movement out of the pack variant, one movement in to the piece variant, in one op, with a stated ratio on the product. Cost splits by the ratio.
5. **Restock list** is derived from low stock and last cost; receiving uses the existing `receipt` movement (P4-01), so average cost keeps working.
6. **Utang upgrades** extend the existing ledger kinds: due date per customer, partial payment is already a payment, the statement is text shared through the system share sheet.
7. **All UI text through ARB (en + fil), colors through theme tokens** (see `AppColors` in `lib/core/theme.dart`). Every new table: RLS + isolation-matrix rows.

## Cards
| Card | Work | Model |
| --- | --- | --- |
| P8-01 Pin favorites on Sell quick tiles | (top sellers already existed as `quickItems`) device-local pins, long-press, tests. DONE | Sonnet |
| P8-02 Expenses: schema, RLS, op, pgTAP | migration, `op_record_expense`, void, rollup into reports. DONE (op and pull shapes: `P8-02-expenses-schema.md`) | Opus |
| P8-02c Expenses on the device + day close | `day_closes` + `close_day` op + pull, Drift v6, store API, sync, PIN calls on `Backend`. DONE (API and supervisor flow: `P8-02c-expenses-client-and-day-close.md`) | Opus |
| P8-03 Expenses + day close screens | add expense, Today shows expenses, count drawer, over/short, fil + en, supervisor PIN retry. DONE | Sonnet |
| P8-04 Net profit in Reports | profit after expenses (stock purchases excluded: already in cost of goods), from the rollup. DONE | Sonnet |
| P8-05 Restock list | derived list from low stock + last cost, copy as text, receive from the list. DONE | Sonnet |
| P8-06 Load / e-wallet service ledger | migration, `record_service_txn` / `void_service_txn` ops, float balance, fee rules, pgTAP property test, Drift v7 + store API + sync. DONE (money model, API and what P8-07 calls: `P8-06-load-ewallet-ledger.md`) | Opus |
| P8-07 Load / e-wallet screens | cash-in/out/load entry, float, daily fee total. DONE | Sonnet |
| P8-08 Tingi / repack | link on the pack variant (piece = own product), `set_tingi_link` / `open_pack` / `void_open_pack` ops, `conversions`, exact cost rule, pgTAP property test, Drift v8 + store API + sync. DONE (model, cost rule, API and what P8-09 calls: `P8-08-tingi-repack.md`) | Opus |
| P8-09 Tingi UI | "Sold by piece too" on the product form, "open a pack" + history/undo on Stock. DONE | Sonnet |
| P8-10 Utang due dates + statement | migration (`due_on`), `set_utang_due` op, overdue list, statement text, Drift v9 + store API + sync. DONE (server + data layer; API, payload and what the UI card calls: `P8-10-utang-due-dates.md`). UI card still open | Opus (schema) then Sonnet (UI) |
| P8-11 Expiry dates | one date per product per store (earliest on the shelf, no lots), `stock_expiry` + `set_expiry` op, optional `expires_on` on `receive_stock` (earlier-date rule), Drift v10 + store API + sync. DONE (server + data layer; model, limitation, API and what the UI card calls: `P8-11-expiry-dates.md`). UI card ("expiring soon" on Home and Stock) still open | Opus (schema) then Sonnet (UI) |
| P8-12 Export and backup | CSV of sales, utang, stock, share sheet (share_plus). DONE | Sonnet |
| P8-13 Acceptance | emulator walk-through, report in docs/tasks/P8-13-acceptance.md. DONE | Sonnet |
| P8-14 Opening cash (sukli) in the day close (added card) | `day_closes.opening_cash`, optional `opening_cash` on `close_day` (in `server_expected_cash`), pull + audit carry it, Drift v11, `defaultOpeningCash` (latest earlier close's count) + `expectedCash` / `closeDay` take an opening. DONE (server + data layer; model, payload, API and what the screen calls: `P8-14-opening-cash.md`). Screen change still open | Opus (data) then Sonnet (screen) |

## Order
P8-01 first (no schema, immediate speed win), then P8-02 to P8-04 (expenses and day close), then P8-05, then P8-06/07 (load), then the rest by the owner's priority.

## Deferred
Price tiers, supplier ledger (utang to suppliers), loyalty, multi-device conflict rules for the day close.
