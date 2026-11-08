# P8-15 E-wallet payments and expenses move the wallet float (DONE: server + data layer)

Added card (not in the original P8 list). Closes the P8-06 gap "e-wallet sale payments and expenses name no wallet, so they
don't move `wallet_float`" and P8-13 finding 5, **on the data side**. Server: migration
`supabase/migrations/20261108001900_ewallet_float_payments.sql`, pgTAP `supabase/tests/024_ewallet_float_payments.test.sql`
(86, incl. a seeded 420-op property test). No new table, no matrix rows. Flutter data layer: Drift schema v12, store API
below, tests `apps/mobile/test/ewallet_float_test.dart` (10). **No screens, no ARB keys**: the Pay screen and the expense
sheet (Sonnet) build on this API.

## Money model (base-currency centavos)
| record | float effect | void / cancel |
| --- | --- | --- |
| sale payment `method = 'ewallet'` of A with `wallet = W` | float(W) + A (the customer paid into the store's wallet) | float(W) - A |
| expense `paid_from = 'ewallet'` of A with `wallet = W` | float(W) - A | float(W) + A |
| any of them with no wallet (old rows, older apps, wallet left out) | none (exactly as before) | none |

- Wallets: `gcash`, `maya`, `other`. **Never `load`** (the prepaid-load float): refused with `invalid_value`.
- Only e-wallet payments move a float: a cash + GCash split moves GCash by its e-wallet part only. A wallet on a cash or utang
  payment, or on a cash expense, is refused (`invalid_value`); the table check constraints say the same.
- A float may go below zero (flagged `negative`), as in P8-06.
- `wallet_float.balance` = signed effects of service entries not voided + named e-wallet payments of sales not cancelled -
  named e-wallet expenses not voided (+ float adjustments, which are service entries). `txn_count` counts all of them.
- Unchanged: cash, expected cash (`day_close_server_expected`, the phone's `expectedCash`), `daily_sales_summary` (cash /
  ewallet / utang by method, named or not), `daily_expense_summary`, `report_summary` keys. `report_summary.services.float`
  (balance per wallet) now simply includes what sales and expenses moved.

## Server
- `payments.wallet text null check (in gcash, maya, other)` + `payments_wallet_ewallet_only` (wallet null or method ewallet);
  `expenses.wallet` the same + `expenses_wallet_ewallet_only` (wallet null or paid_from ewallet). Set once, by the op insert:
  payments are append-only (`reject_ledger_change`), `guard_expense_change` re-created with `wallet` among the frozen columns.
- Float maintenance: plain AFTER triggers (inside the op's subtransaction, so a refused op leaves nothing):
  `payments_wallet_float` (insert of a named e-wallet payment of a completed sale), `sales_wallet_float_void` (completed ->
  voided takes the sale's named e-wallet payments back out), `expenses_wallet_float_insert` / `expenses_wallet_float_void`.
  Helper `move_wallet_float(tenant, store, wallet, delta, count)`. `op_void_sale` / `op_void_expense` are unchanged.
- Timing: the float rows move at the push's `now()` = the op's `applied_at`; `sync_pull_service` reads `floats` in one
  statement at `server_time`. So the P8-06 device rule (drop a local effect once a balance with `server_time >= applied_at`
  is pulled) applies unchanged to sales and expenses.
- Audit: `expense.record` meta gains `wallet` only when one is named (otherwise identical); `sale.create` meta unchanged
  (`{ no, total, utang }`; the wallets are on the payment rows). No customer data.
- Re-created (additive): `op_record_sale`, `op_record_expense`, `guard_expense_change`, `sync_pull_sales`,
  `sync_pull_expenses`. `sync_push` is unchanged (no new op kinds).

### Op payload changes (through `sync_push`, idempotent by `op_id`; a replay moves nothing)
`record_sale`: each payment may carry `wallet`:
```json
"payments": [ { "method": "cash", "amount": 2000, "tendered": 5000 },
              { "method": "ewallet", "amount": 1500, "wallet": "gcash" },
              { "method": "ewallet", "amount": 500 } ]
```
`record_expense`: optional `wallet` next to `paid_from`:
```json
{ "id": "<uuid>", "amount": 900, "category": "utilities", "paid_from": "ewallet", "wallet": "maya", "spent_at": "..." }
```
`wallet` missing, `null` or `""` = not named. Trimmed; values are exact lower case (`"GCash"` is refused). Anything else
(`load`, unknown, on a non-e-wallet payment / cash expense) = `invalid_value`, nothing written. Results unchanged.

### Pulls (additive)
- `sync_pull_sales`: each payment gains `wallet` (`null` when not named): `{ method, amount, tendered, reference, wallet }`.
- `sync_pull_expenses`: rows gain `wallet`.
- `sync_pull_service`: unchanged shape; its `floats` now include sale / expense movements.

## Device: store API (`lib/data/sales_models.dart`, implemented in `drift_sales.dart`)
```dart
const paymentWallets = ['gcash', 'maya', 'other'];
const PaymentDraft(String method, int amount, {int? tendered, String? reference, String? wallet});
const SalePaymentView(String method, int amount, int? tendered, String? reference, {String? wallet});
ExpenseView(..., String? wallet, ...)          // named, optional
Future<SaleReceipt> commitSale(SaleDraft draft, {required String opId});      // payments may carry wallet
Future<void> voidSale(String saleId, {required String opId, String? reason}); // takes named payments back out
Future<void> recordExpense({required String id, required int amount, required String category, String paidFrom = 'cash',
    String? wallet, String? note, DateTime? spentAt, String? approvalId, required String opId});
Future<void> voidExpense({required String expenseId, String? reason, String? approvalId, required String opId}); // puts it back
Stream<List<WalletFloatView>> watchWalletFloat();   // now includes sales and expenses
```
- Validation like the server, before anything is written: a wallet on a non-`ewallet` payment / a non-`ewallet` expense, or a
  value outside `paymentWallets`, throws `ArgumentError`. No wallet = exactly the old behaviour and payload (no `wallet` key).
- **Float on the phone** (P8-06 rule, unchanged): pulled server balance + `local_float_effects`. `commitSale` adds one row per
  named e-wallet payment (+amount, op = the sale's op, txn id = the sale id); `voidSale` adds -amount per named e-wallet payment
  of the sale (read from `sale_payments`, so a pulled sale cancelled here works too); `recordExpense` adds -amount;
  `voidExpense` adds +amount for a named e-wallet expense. Each row is confirmed by `posOpApplied` (the op's `applied_at`)
  and dropped once a pulled balance with `server_time >= applied_at` arrives, so a stale balance never swallows an unsent op
  and nothing is counted twice. `discardFailed` deletes the op's rows (refused sale, expense or void), as for service ops.
- Pulled sales and expenses replace local rows as before and carry `wallet` (missing key from an older server = null). Pulled
  rows never add local float effects: the server balance carries them.
- `getSale(...).payments[i].wallet`, `watchExpenses(...)[i].wallet`.
- Drift v12: `sale_payments.wallet`, `expenses.wallet` (nullable) added, every row kept with none; no re-pull (server rows
  before P8-15 have no wallet either).

## What the screens must call (Sonnet)
1. **Pay screen**: when the method is e-wallet, show a wallet chooser (GCash / Maya / Other, ARB en + fil; hidden for cash and
   utang), default to the last used or GCash, and pass `PaymentDraft('ewallet', amount, wallet: chosen)`. Never offer `load`.
   Do not change cash / change-due logic.
2. **Expense sheet**: when "paid from" is e-wallet, show the same chooser and pass `recordExpense(..., paidFrom: 'ewallet',
   wallet: chosen)`; hide it (and pass no wallet) for cash.
3. Optional: show the wallet on the receipt / sale detail (`SalePaymentView.wallet`) and in the expense list
   (`ExpenseView.wallet`). The Load & e-wallet screen needs nothing new: `watchWalletFloat()` already moves.
4. Copy hint for the float card: "Includes e-wallet sales and expenses that named the wallet".

## Tests
- pgTAP `024` (86): with / without wallet, `""` / null = none, multi-payment sale, the other wallet, refusals (wallet on cash /
  utang / cash expense / paid_from omitted, `load`, unknown, wrong case, one bad payment refuses the sale) leaving nothing,
  float after sale / cancel / second cancel / replay, expense / void / second void / replay, negative flag, expected cash and
  the sales day summary unchanged, audit meta, append-only columns and check constraints, permissions unchanged (cashier
  sells, cannot record expenses or cancel; warehouse cannot sell; manager records), stores kept apart, pulls carry `wallet`,
  `sync_pull_service` floats (owner, cashier store-only, other tenant none), `report_summary.services.float`; and a seeded
  property test (420 ops: ~95 sales with 1-3 cash / named / unnamed e-wallet payments, ~48 expenses, ~104 service entries
  of every kind over 3 Manila days, voids of each type, second voids, replays, refusals) proving float and entry count per
  wallet = the model, expected cash per day = cash payments - cash expenses + service cash, the sales day summary by method,
  one row / void per effective op, stored payment wallets, report and pulled floats.
- Flutter `ewallet_float_test.dart` (10): sale float + payload shapes (wallet only when given) + totals/expected cash
  unchanged, no-wallet sale as before, cancel reverses exactly, bad wallets refused, expense float / payload / void, a stale
  balance arriving after the ops were applied does not swallow them (and a later balance does not double count), a random
  mix (4 seeds: sales, expenses, float moves, voids) through a lost-reply + replay sync, discard of a refused expense / void /
  sale, pulled sales and expenses carry wallet (older server: none) without moving the local float, v11 -> v12 upgrade.
