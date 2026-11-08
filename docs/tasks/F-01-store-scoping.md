# F-01 Store scoping (data layer DONE; picker UI DONE)

First Full-mode card (`F-00-overview-full-mode.md`, solo limitations 1, 2 and the store half of 7; gap B3). A tenant may
now have several stores. This card is the SERVER + Flutter DATA LAYER only (Opus). No screen, no ARB string was changed.
The store picker UI is the next step (Sonnet), see "What the picker step must do" at the end.

## Survey (before) and decisions

"Server" = the server table has `location_id`; "Local" = the phone's Drift table has it; "Pull" = the pull sends it;
"Scoped" = the phone's queries filtered by store before F-01.

| Thing | Server | Local | Pull | Scoped before | Decision (F-01) |
| --- | --- | --- | --- | --- | --- |
| Sales | yes (not null) | **no** | **no** (`sync_pull_sales`) | no | `sales.location_id` added on the phone (v13); `sync_pull_sales` rows carry `location_id` (additive); watchSales, watchToday, quickItems, expected cash filter by the active store |
| Sale items / payments | yes | no | no | no | scoped through their sale (join), no column |
| Expenses | yes | yes | yes | **no** | watchExpenses, watchTodayExpenses, expected cash filter; written with the active store |
| Day closes | yes | yes | yes | opening only | watchLatestDayClose and the opening filter by the active store (closes with no store still count, as in P8-14) |
| Service entries (load / e-wallet) | yes | yes | yes | no | watchServiceTxns, watchTodayServices, expected cash filter |
| Wallet float | yes (`wallet_float` per store) | balances yes, **local effects no** | yes | balances only | `local_float_effects.location_id` added; effects carry the store of their sale / expense / entry (a void: the cancelled row's store) |
| Stock levels | yes | yes | yes | **no (summed across stores)** | watchStock, watchStockList, stockLeft, average cost filter by the active store |
| Local stock movements | n/a | **no** | n/a | no | `local_movements.location_id` added; every movement carries its store (sale, void = the sale's store, receive, count, opening, pack open, pack void = the opening's store) |
| Stock expiry | PK (store, variant) | PK variant only; other stores skipped on pull | yes | n/a | re-keyed to (store, variant) (v13); every pulled store kept; reads use the active store; a local date written with no store known has store `''` until the only store is known |
| Conversions (tingi) | yes | yes | yes | no | watchConversions filter; the pack cost uses the active store's average |
| Customer ledger (utang) | **no** | **no** | **no** | n/a | server `customer_ledger.location_id` + `method` (cash \| ewallet); local `server_ledger` and `local_ledger` gain both; balances stay tenant-wide (a customer owes the business); only CASH payments taken at the closing store count in expected cash (server and phone) |
| Customers | tenant-wide | | | | unchanged (catalog-like) |
| Quick tiles / top sellers | from local sales | | | no | top sellers counted from the active store's sales |
| Pinned favorites | device meta | | | n/a | **kept per device**, not per store: a personal shortcut on one phone, no money or stock effect |
| Opening cash default | from day closes | | | yes (`?5`) | now reads the active store from meta (live) |
| Reports (`report_summary`) | rollups per store | online only | | caller's stores | **not scoped here**: the server sums every store the caller can see (RLS). Per-store reports belong to F-10 (rollup tables already carry `location_id`) |
| Restock list, stock CSV export, reports low-stock card | via watchStockList | | | | follow the active store automatically |
| Catalog (products, variants, prices) | tenant-wide | | | | unchanged |
| Receipt numbers | | | | | unchanged (device code; F-02) |

## Server: `20261108002000_store_scoping.sql`
- `customer_ledger.location_id uuid` (nullable, fk `(tenant_id, location_id)` -> `locations`, so same tenant) and
  `method text not null default 'cash' check in ('cash','ewallet')`, plus `check (method = 'cash' or kind = 'payment')`.
  Partial index `(tenant_id, location_id, occurred_at) where kind = 'payment'`.
- Backfill (`customer_ledger_location_backfill()`, internal, run once by the migration with the append-only guard switched
  off around it): rows tied to a sale (charge, and the void reversal of that charge) -> the sale's store; every other row ->
  the tenant's only store, or with several its first store (active first, then code, created_at, id); a tenant with no store
  -> stays null. `method` = cash for every existing row (before F-01 every payment was counted as cash).
- `op_record_sale`: the utang charge row carries the sale's store. Missing `location_id`: unchanged rule (resolve_store,
  since P3-02): accepted when the user has exactly ONE active store, else refused with hint `location_required` (B3 is
  therefore closed by the phone always sending the active store).
- `op_void_sale`: the reversal row carries the sale's store (a `location_id` in the payload is ignored).
- `op_record_utang_payment`: optional `location_id` (resolve_store: access required, `location_denied` otherwise; missing =
  the only store, else `location_required`) and optional `method` (cash default; anything else `invalid_value`).
- `op_adjust_utang`: optional `location_id` (given: resolve_store; missing: the user's only store via `user_sole_store()`,
  else null; not refused, an adjustment moves no cash).
- `day_close_server_expected`: utang payments count only when `method = 'cash'` AND `location_id` = the closing store.
- `sync_pull_pos`: customer_ledger rows carry `location_id`, `method`. `sync_pull_sales`: rows carry `location_id`.
- Unchanged: `sync_push` (no new kind), RLS (customer_ledger stays tenant-wide for superadmin/admin/cashier), audit rows
  (utang.payment / utang.adjust meta still `{amount}`), report_summary, every other op. No new table (no isolation row).
- pgTAP `025_store_scoping.test.sql` (52): two-store tenant, one-store cashier and manager, solo tenant, sales and payments
  per store, the per-store server figure with cash vs e-wallet, adjustments, void, pulls, permissions, the backfill rule.
  `018_day_close` fixture: its ledger rows now name store S01, and S02's figure changed 8100 -> 6600 (the S01 utang payment
  no longer counts at S02; that was the solo limitation).

## Phone: Drift schema v13
Migration (`AppDatabase._storeScopingStep`) keeps every row and every unsent op:
- adds `sales.location_id` (+ index `(location_id, sold_at)`), `local_movements.location_id`, `local_ledger.location_id` /
  `method`, `server_ledger.location_id` / `method`, `local_float_effects.location_id`; re-keys `stock_expiry` to
  `(location_id, variant_id)` (`location_id` not null, `''` for a row that had none);
- local rows take their store from the payload of the unsent op that made them (`location_id`), a void's movements from the
  cancelled sale / opening, float effects from their sale / expense / service entry;
- drops the cursors of `sales`, `customer_ledger`, `stock_expiry` (server copies come again with their store);
- creates `meta` if a (test-simulated) old database lacks it;
- rows still without a store: on the next `ensureTenant`, a user with exactly ONE store gets them filled with it (every solo
  device; `initStores` runs that every start, it is cheap). With several stores they stay null and are not shown in any
  store's view until the re-pull brings their store (server copies) - see "Not scoped" below for local-only rows.

### Store API (`SalesStore` / `LocalStore`, implemented in `DriftSales` / `DriftStore`)
```dart
class StoreRef { const StoreRef({required String id, required String name}); }   // sales_models.dart
const utangPaymentMethods = ['cash', 'ewallet'];

String? get activeLocationId;                       // null = no store known: nothing filtered (pre-F-01 behaviour)
Future<void> setActiveStore(String locationId);     // only one of myStores(), else ArgumentError (nothing changes)
Future<List<StoreRef>> myStores();                  // from the access payload given to ensureTenant, server order
Stream<String?> watchActiveStore();

Future<bool> ensureTenant(String tenantId,
    {required String baseCurrency, String? locationId, List<StoreRef>? stores, bool discardUnsent = false});
Future<void> recordUtangPayment({required String customerId, required int amount, String? note,
    String method = 'cash', required String opId});
```
- Removed: the old `String? locationId` getter/setter on `SalesStore` (only `DriftStore.ensureTenant` used it).
- Active store choice: kept in `meta` (`active_location_id`, plus `stores` JSON). `ensureTenant` picks the store chosen
  before on this device if still allowed, else `locationId` if allowed, else the first store (the only one for a solo owner).
  `stores: null` means "just `locationId`" (how the existing tests and older callers name one store).
- `StoreSession` now passes `stores: storesOf(access)` (locations of type `store`, by code; warehouses left out).
- Every scoped SQL reads the active store from `meta` inside the query (`DriftSales.activeSql` / `inActive(col)`) and lists
  `meta` among its tables, so EVERY watched stream (Today, sales, stock, expected cash, float, expenses, services, closes,
  conversions, stock list) re-emits on a switch without subscribing again. Writes read it in their own transaction.
- Pulled rows that name no store (an older server or a fake in tests) belong to the user's only store, if exactly one.

### Op payload changes (all additive; the server accepted `location_id` on these before unless noted)
| Op | Change |
| --- | --- |
| `record_sale` | `location_id` = the active store, always when one is known (before: only when the user had exactly one store) |
| `void_sale` | gains `location_id` = the sale's store (informational; the server uses the sale row) |
| `record_utang_payment` | gains `location_id` (active store) and `method` (`cash` default \| `ewallet`) - NEW server fields |
| `adjust_utang` | gains `location_id` (active store) - NEW server field |
| `post_opening_stock` | gains `location_id` (active store) |
| `receive_stock`, `adjust_stock`, `set_expiry`, `record_expense`, `close_day`, `record_service_txn`, `open_pack` | `location_id` = the active store (was the one-store id or nothing) |
| `void_expense`, `void_service_txn`, `void_open_pack`, `upsert_customer`, `set_utang_due`, `set_tingi_link` | unchanged (server uses the row / tenant-wide) |

Switching the store never edits a queued op: each keeps the store it was made for (tested).

### Tests
`apps/mobile/test/store_scoping_test.dart` (12): two stores switching Today / sales / expected cash / stock / float /
expenses / services / quick tiles; live streams follow a switch; ops queued under A keep A after switching to B and a void
puts stock back at the sale's store; utang cash vs e-wallet per store with one tenant-wide balance; pulled rows of every
store shown at their own store; tingi per store; one-store user unchanged; no-store user unfiltered; `storesOf`; v12 -> v13
upgrade with two stores (rows placed from their ops, ops unchanged, cursors dropped) and with one store (rows filled).
Changed expectations: `utang_due_test` v8 upgrade and `stock_ops_test` v4 upgrade (the v13 step also drops the
`customer_ledger` cursor), `products_test` `BrokenStore.ensureTenant` signature (new `stores` parameter).

## Not scoped (and why)
- `report_summary` (server, online): sums every store the caller can see. Per-store reports are F-10.
- Pinned favorites: per device on purpose (see table).
- Customer balances, the customer list, overdue list and the ledger screen: tenant-wide on purpose (a customer owes the
  business; the ledger rows now say where each entry happened, the screen could show it later).
- Local-only rows that cannot tell their store on a device with SEVERAL stores (a row whose op was already sent before the
  upgrade and that the 30-day sales re-pull does not cover). No pre-F-01 device could have had several stores working (the
  sale op was refused with `location_required`), so this is theoretical; such rows are kept, just not shown.
- An e-wallet utang payment does not move a wallet float (the ledger has no wallet; out of scope).
- Opening stock: one `post_opening_stock` op per variant (fixed op id), at the store active when the product is created.
  Other stores use stock in / count.
- Receipt numbers (device code) stay per device: F-02.

## What the picker step (Sonnet, UI only) must do
1. Read `CatalogScope.of(context).store`: `myStores()` for the list, `activeLocationId` / `watchActiveStore()` for the
   current one, `setActiveStore(id)` on a pick. Show the picker only when `myStores().length > 1` (a solo owner never sees
   it). Show the active store's name somewhere persistent (Home header / Sell).
2. Future-based reads do not re-run by themselves: after a switch, re-call `quickItems()` (Sell tiles) and anything else the
   screen loaded once (`expectedCash`, `defaultOpeningCash`, `stockLeft`, `averageCost`, `expiringCount`, `overdueCount`).
   Streams already follow the switch.
3. `lib/screens/supervisor_pin.dart`: `askSupervisorApproval` must pass `locationId:` to
   `backend.approveSupervisorAction` - the active store for a new entry, and for `retryWithApproval` the refused op's
   `payload['location_id']` - otherwise a supervisor with several stores gets `location_required`.
4. Utang payment sheet: a cash / e-wallet choice that passes `method:` to `recordUtangPayment` (default cash).
5. ARB keys (en + fil) for the picker title, store names come from the server.
6. Optional: show the store on receipts / ledger rows when the user has several stores.

## Picker step: done (Sonnet)
`lib/screens/store_picker.dart`: `StoreChip` (shows the active store's name, only when the user has more than one store; in the
Sell and Today app bars and under the store name in More) and `showStorePicker` (bottom sheet, snackbar "Now selling at X").
Sell re-reads its top sellers when the store changes. `askSupervisorApproval` takes `locationId`; `retryWithApproval` passes the
refused op's `location_id`. The utang payment dialog has a Cash / GCash-Maya choice that goes to `recordUtangPayment(method:)`.
Tests: `test/store_picker_test.dart` (6). Not done: store name on receipts and ledger rows (optional, item 6).
