# Phase 3 (solo): Sell screen, cash, utang, receipt, stock ledger, in Flutter

Replaces the shifts/PIN/Playwright wording of plan section 12 Phase 3 for solo tenants. Plan sections 6 (Sales) and 7 (sync, offline sale flow) still apply.

## Goal
A tindera rings up a sale in a few taps (scan, search or quick-tap item), takes cash and sees the change, or writes the rest as utang,
and gets a receipt number, with no signal. The sale and its stock deduction reach the server later, exactly once.
**Done when:** 20 sales (cash, utang, mixed) are made offline; the app reconnects; the server has exactly 20 sales with the right totals,
20 sets of stock movements, correct utang balances and no duplicates, including after a forced mid-push failure and a retry;
`pnpm check`, `flutter analyze` and `flutter test` are green.

## Decisions (change them here before starting P3-01)
1. **Stock ledger arrives now, but only what a sale needs.** `stock_movements` (append-only) + `stock_levels` (trigger-derived, never written by
   clients). Types used in Phase 3: `sale`, `sale_void` (reverses), `opening`. Receipts, adjustments, counts, low-stock screens stay Phase 4.
   A sale writes a movement only for products with `track_stock` and only when the inventory module is on (it always is). Negative stock is
   accepted (the sale already happened); the screen warns at 0 but never blocks.
2. **Opening stock becomes real.** The device `opening_stock` rows turn into `opening` movements through a `post_opening_stock` op
   (idempotent). Rows already waiting on devices are converted once on the first sync after the upgrade.
3. **Utang = customers + an append-only credit ledger.** `customers(id, name, phone?)` and `customer_ledger(id, customer_id, kind[charge|payment|adjust],
   amount, sale_id?, note?)`. Balance = sum, derived (stored nowhere, so it cannot drift). A customer must be picked to sell on utang; no credit limit in solo.
   Partial payments on utang are plain `payment` rows ("nagbayad si Aling Rosa ng 200").
4. **Payment methods in solo:** cash, utang, and one e-wallet label (GCash/Maya, optional reference, no integration). Card and split tender are Full mode.
   A sale can mix cash + utang (customer pays 100 of 150, 50 goes to utang). *Confirm whether to include the e-wallet label.*
5. **Receipt numbers:** `local_no` = `<device code>-YYMMDD-NNNN`, made on the device, unique per tenant. The server stores it and assigns no `sale_no` in solo
   (one device, nothing to arbitrate). A server `sale_no` is added when a tenant gets a second device (Full mode).
6. **Receipt = on-screen** (items, total, paid, change, utang, number, date). Sharing as text/image and thermal printing wait for Phase 7 (`ReceiptPrinter` interface only).
7. **Sync shape:** new RPC `sync_push(ops jsonb)` takes up to 50 ops in order and returns a result per op (ok / rejected with hint / error).
   It dispatches to per-kind functions that reuse `claim_op` / `finish_op` from P2-02, so a retried op returns its stored result. Kinds: `record_sale`,
   `void_sale`, `upsert_customer`, `record_utang_payment`, `post_opening_stock`. Catalog ops keep their own RPCs and the existing engine path.
   One bad op never blocks the ones after it from being tried; it parks as "needs attention" like catalog ops.
8. **Pull:** one new `sync_pull_pos` (stock levels, customers, ledger entries), keyset cursors and the 5 s hold-back, same shape as `sync_pull_catalog`.
   Sales history is **not** pulled; "today" is computed from sales made on this device (a second device's sales appear in Phase 6 reports).
9. **Local stock on screen** = server level + movements still waiting to be confirmed. A movement counts until a pull has passed the time the server applied
   its op (the op result carries `applied_at`), so the 5 s hold-back can never show a number that is too high for a moment.
10. **Prices and cost are snapshots.** `sale_items` keeps `unit_price`, `unit_cost`, `tax`; a later price change never alters a past sale. Tax: price includes tax;
    `tax = round(line_total * rate / (1 + rate))`, 0 for the usual 0% product. Totals are integer centavos from `lib/core/money.dart`.
11. **Quantities** are `numeric(12,3)` so kilo/pack items work later; the Sell screen uses whole-number steps and a keypad for decimals only on non-`pc` units.
12. **Discounts:** one optional peso-off amount per sale (typed). Per-line discounts, percent and PIN-gated permissions are Full mode.
13. **Deferred to Full mode:** shifts and cash drawer count, PIN unlock (the owner stays signed in on her own phone; the offline-PIN RPC gap stays open and is
    carried forward), cashier roles on the Sell screen, refunds of cash, card payments, server `sale_no`, devices table.
14. **Void (P3-07)** is included for the owner: same-day or any-day "cancel sale" as a compensating op that reverses stock and utang, never a delete.
    *Confirm: keep void in Phase 3 or push it to Phase 4.*
15. **Quick-tap items:** the 12 most sold products of the last 30 days on this device, topped up with the newest products when there is little history.
    Pinning favourites is local-only for now (no sync).
16. **`flutter analyze` and `flutter test` join `pnpm check`** (a `check:mobile` script), so Flutter can no longer drift unnoticed. *Confirm.*
17. **Web test limits unchanged:** the in-app browser uses safe-mode storage; offline first load of the web app is still a Phase 7 gap.

## Cards (one at a time, in order)
| Card | Work | Model |
| --- | --- | --- |
| P3-01 ledger + sales schema | migration, RLS, triggers, isolation-matrix rows, pgTAP | Opus |
| P3-02 sale RPCs, `sync_push`, `sync_pull_pos` | `record_sale`, `void_sale`, customers/utang RPCs, opening stock, batch push, pull | Opus |
| P3-03 local sales store + sync | Drift v4, atomic local sale commit, local stock and balances, outbox kinds, engine push/pull | Opus |
| P3-04 Sell screen | search, scan, quick-tap, cart | Sonnet |
| P3-05 pay + receipt | cash and change, utang, e-wallet, discount, receipt screen | Sonnet |
| P3-06 utang screen | customers, balances, history, "nagbayad" | Sonnet |
| P3-07 today + void | daily total, sales list, cancel sale | Sonnet (stock reversal reviewed with Opus) |
| P3-08 acceptance | 20 offline sales, forced mid-push failure, browser walk-through, report in handoff | Sonnet |

Rules for every card: migration + pgTAP before UI; each new table gets RLS and isolation-matrix rows; no edits to existing migrations, `apps/client`,
`apps/mobile/android/` or `run-android.ps1`; fil + en strings with `{count}` plurals; commit per card; handoff updated.
