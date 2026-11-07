# P8-06 Load / e-wallet service ledger (DONE)

Server: migration `supabase/migrations/20261108001400_service_ledger.sql`, pgTAP `supabase/tests/019_service_ledger.test.sql` (109,
incl. a seeded 340-op property test) plus `service_txns`, `wallet_float`, `daily_service_summary` rows in the `004` matrix.
Flutter data layer: Drift schema v7, `SalesStore` methods, sync engine, tests `apps/mobile/test/services_test.dart` (14).
**No screens**: P8-07 (Sonnet) builds them on this API.

## Money model
Base-currency centavos. "Cash" = the drawer. "Float" = the store's own money in the wallet named by `wallet`
(`gcash`, `maya`, `load` = the prepaid-load float, `other`). **The fee is always collected in cash, on top of the principal,
and is the store's income for the entry.**

| kind | amount | fee | price | cash effect | float effect | income |
| --- | --- | --- | --- | --- | --- | --- |
| `cash_in` (customer gives cash, store sends from its wallet) | principal > 0 | >= 0 | - | + amount + fee | - amount | fee |
| `cash_out` (customer sends to the store's wallet, store gives cash) | principal > 0 | >= 0 | - | - amount + fee | + amount | fee |
| `load` (prepaid load sold) | what the wallet is debited > 0 | = price - amount | cash paid, >= amount | + price | - amount | fee |
| `float_topup` (drawer -> wallet) | > 0 | 0 | - | - amount | + amount | 0 |
| `float_withdraw` (wallet -> drawer) | > 0 | 0 | - | + amount | - amount | 0 |
| `float_adjust` (correction, needs a note) | signed, not 0 | 0 | - | 0 | + amount | 0 |

- For every kind but `float_adjust`: cash effect + float effect = fee (the store's money grows only by its income).
- Load: type what the wallet actually paid as `amount` (face value, or the discounted cost when the provider debits less) and
  what the customer paid as `price`; the margin is stored as `fee`. A rebate credited to the wallet later is a `float_adjust`.
- `cash_in` / `cash_out` never use the `load` wallet. A load may come from any wallet (GCash "Buy Load" = `gcash`).
- A float may go below zero (recorded a cash-in before the top-up): allowed, never blocks an entry, flagged `negative`.
- Fees are income but are **not** folded into the sales totals (`totals.net`); Reports show them from `services`.
- **Gap (deferred):** `wallet_float` moves only with service entries. A sale paid by e-wallet (`payments.method = 'ewallet'`)
  or an expense `paid_from = 'ewallet'` names no wallet, so it does not move any float; the owner corrects the balance with a
  `float_adjust` (or a top-up / withdraw) until payments and expenses record which wallet they used.

## Server
- `service_txns`: append-only (guard trigger: only one void, `voided_at` + `void_reason` + `void_approved_by`; no edits or
  deletes). Client UUIDv7 `id`, `tenant_id`, `location_id` (a store), `client_op_id` (unique per tenant), `kind`, `wallet`,
  `amount`, `fee`, `price` (load only, = amount + fee), `currency` (base), `ref` (customer phone / reference no., max 200,
  **sensitive: never in audit_log**), `note` (max 200), `txn_at`, `created_by`, `approved_by`, `created_at`, `updated_at`,
  `deleted_at` (never set), `voided_at`, `void_reason`, `void_approved_by`. Check constraints enforce the table above.
- `wallet_float` (per store + wallet: `balance`, `txn_count`, generated `negative`) and `daily_service_summary` (per store,
  day in the tenant timezone, kind: `txn_count`, `amount`, `fee`, `cash` (sum of cash effects), `float_change`): kept by
  AFTER triggers on insert and on void (a void takes the entry back out of both). Never written by clients.
- Read: `service_txns` and `wallet_float` by the owner, admins and cashiers of the store (front of store);
  `daily_service_summary` by the owner and admins (like the other rollups). Warehouse staff: nothing.
- `day_close_server_expected` (used by `close_day`) now adds the day's `daily_service_summary.cash` for the store.
- `report_summary(from, to)` gained (every other key unchanged):
  ```json
  "services": { "count": 6,            // customer entries (cash_in + cash_out + load), voided left out
                "fee_total": 260,      // service income in the range
                "by_kind": [ { "kind": "cash_in", "count": 3, "amount": 2800, "fee": 50 } ],  // fixed kind order, empty kinds left out
                "float": [ { "wallet": "gcash", "balance": 150000 } ] }                    // CURRENT balance per wallet, all the caller's stores
  ```

### Who may record or void (the UI hides; the server enforces)
| Who | cash_in / cash_out / load | float_topup / float_withdraw | float_adjust | void (any kind) | void a float_adjust |
| --- | --- | --- | --- | --- | --- |
| owner (superadmin) | yes | yes | yes | yes | yes |
| admin, **manager** of the store | yes | yes | yes | yes | yes |
| admin, **supervisor** of the store | yes | with an approval (`record_service_txn`) | `not_allowed` | with an approval (`void_service_txn`) | `not_allowed` |
| cashier of the store | yes | `not_allowed` | `not_allowed` | `not_allowed` | `not_allowed` |
| warehouse | `not_allowed` | `not_allowed` | `not_allowed` | `not_allowed` | `not_allowed` |

Approvals are the P8-02b ones: `approve_supervisor_action(p_action, p_ref_id, p_pin, p_location_id, p_approver_id)` now also
accepts `record_service_txn` (ref = the new entry id, made first) and `void_service_txn` (ref = the entry id; the store is the
entry's store when the server has it). Single use, bound to requester + store + action + entry id, 12 hours.
Audit: one row per record / void: `service.record` / `service.void`, entity `service_txn`, meta
`{ location_id, kind, wallet, amount, fee, op_id, approved_by? }` (+ `reason` on a void). Never `ref` or `note`.
Replays and second voids write nothing; refused ops leave no row and no audit entry.

### Ops (through `sync_push`, idempotent by `op_id`)
`{ op_id, kind: "record_service_txn", payload }`
```json
{
  "id": "<uuid v7, required>",
  "kind": "cash_in",              // cash_in | cash_out | load | float_topup | float_withdraw | float_adjust
  "wallet": "gcash",              // gcash | maya | load | other (optional for a load: default load)
  "amount": 50000,                // whole centavos (number or digit string); > 0, signed and not 0 for float_adjust
  "fee": 1500,                    // optional, >= 0; 0 or missing for float kinds; for a load, if sent, must be price - amount
  "price": 5000,                  // load only (required there, >= amount)
  "ref": "0917 123 4567",         // optional, trimmed, max 200 (customer phone / reference no.)
  "note": "bilang",               // optional, max 200; REQUIRED for float_adjust
  "txn_at": "2026-11-08T02:00:00Z", // optional, default server now()
  "currency": "PHP",              // optional; must be the base currency
  "location_id": "<store uuid>",  // optional when the user has exactly one store
  "approval_id": "<uuid>"         // only for a store supervisor's float_topup / float_withdraw
}
```
Result: `{ txn_id, kind, fee, approved_by, applied_at, replay }`.

`{ op_id, kind: "void_service_txn", payload }`
```json
{ "txn_id": "<uuid>", "reason": "maling numero", "approval_id": "<uuid>" }   // reason optional (max 200)
```
Result: `{ txn_id, already, approved_by, applied_at, replay }` (`already: true` when it was voided before; nothing changes).

Rejection hints: `not_allowed`, `amount_invalid` (amount, fee, price), `invalid_value` (kind, wallet, price on a non-load,
currency, bad JSON), `note_required`, `id_required`, `id_conflict`, `txn_not_found`, `location_required`, `location_denied`,
`op_id_reused`, `module_disabled`, and for supervisors `approval_required`, `approval_invalid`, `approval_used`, `approval_expired`.

### Pull: `sync_pull_service(p_cursor jsonb default null, p_limit int default 100)` (1..200)
Same rules as `sync_pull_expenses` for the rows (first pull = last 30 days by `txn_at`, then delta by `(updated_at, id)`,
rows newer than now - 5 s wait, a void comes again). **The float balances come in the same response** (decision: one call;
the set is tiny, at most 4 wallets per store), read in the same statement, never held back:
```json
{
  "rows":   [ { "id", "location_id", "kind", "wallet", "amount", "fee", "price", "currency", "ref", "note", "txn_at",
                "created_by", "approved_by", "voided_at", "void_reason", "void_approved_by", "updated_at" } ],
  "floats": [ { "location_id", "wallet", "balance", "negative", "txn_count", "updated_at" } ],
  "cursor": { "ts": "<updated_at>", "k": "<id>" },
  "has_more": false,
  "server_time": "..."
}
```

## Device: store API (`lib/data/sales_models.dart`, implemented in `drift_sales.dart`)
```dart
Future<void> recordServiceTxn({required String id, required String kind, required String wallet, required int amount,
    int fee = 0, int? price, String? ref, String? note, DateTime? txnAt, String? approvalId, required String opId});
Future<void> voidServiceTxn({required String txnId, String? reason, String? approvalId, required String opId});
Stream<List<ServiceTxnView>> watchServiceTxns({required DateTime from, required DateTime to});
Stream<ServiceTotals> watchTodayServices();
Stream<List<WalletFloatView>> watchWalletFloat();
Future<int> expectedCash(DateTime day);        // now includes service cash (see above)
Future<void> requeueWithApproval({required String opId, required String approvalId});   // also the two service kinds
// sync side
Future<void> applyPullService(Map<String, dynamic> response);
```
- Constants and helpers next to the views: `serviceKinds`, `customerServiceKinds`, `serviceWallets`,
  `serviceCashEffect(kind, amount, fee, price)`, `serviceFloatEffect(kind, amount)`. Labels come from ARB keys (P8-07).
- `recordServiceTxn` validates like the server (ArgumentError) and throws StateError for a used id. For a load pass `price`;
  the fee is derived (`fee` may stay 0, or must equal price - amount).
- `ServiceTxnView`: id, kind, wallet, amount, fee, price, ref, note, txnAt, voidedAt / `voided`, voidReason, approvedBy,
  `pending`, `rejectedHint`, `cashEffect`, `floatEffect`. `ServiceTotals` (today, voided out): `count` (customer entries),
  `fees`, `cashIn`, `cashOut` (principal), `loadSales` (price), `cash` (net drawer effect incl. float moves).
  `WalletFloatView`: wallet, balance, `pending`, `negative`.
- **Float on the phone** = last pulled server balance per wallet (local table `wallet_float`, filtered to `locationId`) +
  `local_float_effects`: one row per record / void made here (the void's row reverses the entry). A row is kept while its op is
  unsent or refused, and after it was applied (`confirmedAfter` = the server's `applied_at`) until a pulled balance with
  `server_time >= applied_at` arrives; then that balance includes it. So the float never counts an op twice or loses one.
  Discarding a refused op deletes its float row; a discarded record removes the entry, a discarded void un-voids it.
- `expectedCash(day)`: completed cash sales + utang payments - cash expenses + service cash effects of the day's entries not
  voided (local rows and pulled rows; a pulled copy replaces the local one).
- Drift v7: tables `service_txns`, `wallet_float`, `local_float_effects` (+ index `service_txns_txn_at`; the step also creates
  the v6 indexes `expenses_spent_at` / `day_closes_day` that the v6 upgrade had left out). Existing rows are kept.

## Sync
- `record_service_txn`, `void_service_txn` go through `sync_push` in order with the other ops (same batching, retry, backoff);
  `rejected` parks the op as failed with the hint (`failedOps()`, `rejectedHint`); a transient `error` keeps it queued in order.
- After day closes the engine pulls `SyncApi.pullService` (cursor `service_txns`), after the push, so the balance read includes
  what was just sent.

## What P8-07 (screens) must call
1. Lists and cards: `watchTodayServices()` (count, daily fee total, cash effect), `watchWalletFloat()` (show `negative` as
   "needs top-up", `pending` as not yet synced), `watchServiceTxns(from, to)` (show `ref`, `voided`, `pending`, `rejectedHint`).
2. Cash-in / cash-out / load entry (anyone who sells, offline): `recordServiceTxn(id: uuid.v7(), kind:, wallet:, amount:, fee:,
   price: (load), ref:, opId: uuid.v7())`.
3. Top-up / withdraw / void: owner and managers call directly. A **supervisor**: make the id first, then
   `backend.approveSupervisorAction(action: 'record_service_txn' | 'void_service_txn', refId: id, pin: pin, locationId: store)`
   (**needs signal**; throws offline: "the supervisor PIN needs signal"), then pass `approvalId: r.approvalId`. On a later
   refusal with `needsApproval(hint)`, ask again and call `requeueWithApproval(opId:, approvalId:)`, or `discardFailed(opId)`.
   Cashiers: hide float moves and void (`not_allowed`).
4. Float correction (`float_adjust`, signed amount, note required): owner / manager only.
5. Day close: nothing new to call; `expectedCash` already includes the service cash. Reports: read `services` from
   `report_summary` (fees are separate from `totals.net`).
The PIN never goes into the outbox, Drift, logs or analytics (a test scans every local table).

## Tests
- pgTAP `019_service_ledger.test.sql` (109): every kind and its effects on the float, the day summary and expected cash;
  replays; audit rows without the customer reference; void reversal and second void; manager / supervisor (approvals: missing,
  wrong entry, expense approval, expired, used) / cashier / warehouse rules; bad input; append-only; no client writes;
  report_summary keys; pull fields, paging, hold-back, per-role visibility; and a seeded property test (340 ops: 183 new
  entries of all kinds over 3 Manila days incl. midnight edges, 54 voids, 29 second voids, 59 replays, 14 refusals) proving
  float per wallet = sum of signed effects of non-voided entries, `day_close_server_expected` per day = sum of cash effects,
  the day summary per day/kind, cash + float = fee, one row / audit row per effective op, and report fees and floats.
- Flutter `services_test.dart` (14): each kind's float / totals / expectedCash / payload, validation, void, ranges, a property test
  (6 seeds: random sales, utang, expenses from `buildRandomDay` + 80 random service entries and voids over two days) and the
  same through a sync (lost reply, replays, held-back rows, server balances), stale balances, approval refusal / requeue /
  discard, cashier refusal, transient error order, paged pulls with an unsent void, v6 -> v7 upgrade, no PIN stored.
