# P3-03 Local sales store and sync (Flutter)
Goal: a sale is committed on the device in one transaction and reaches the server exactly once.
- Drift schema v4 (migration keeps all v3 data): `customers`, `customer_ledger`, `sales`, `sale_items`, `sale_payments`, `stock_levels` (server copy), `local_movements`
  (with `confirmed_after` for decision 9), `counters` (device code, per-day receipt counter in `meta`). `opening_stock` rows are converted into `post_opening_stock` ops once.
- `LocalStore` gains: `commitSale(SaleDraft)` (sale + items + payments + movements + ledger + outbox op, one transaction, returns `local_no`), `voidSale`, `saveCustomer`,
  `recordUtangPayment`, `watchCustomers` (with balances), `stockLeft(variantId)`, `todayTotals()`, `topSellers()`; sync side `applyPullPos`.
- Engine: push drains in batches of 50 through `Backend.syncPush`, per-op results map to done / failed (permanent) / retry-later; catalog ops still use their own calls
  (order preserved by `seq`). Pull `sync_pull_pos` after the catalog pull. Same triggers: after local change (2 s), every 120 s idle, backoff 15 s to 15 min. No Realtime.
- Money math in Dart only through `lib/core/money.dart` (add `taxIncluded`, `changeDue`), mirrored by the server totals check.
- Tests (`flutter test`, fake Backend): sale commit atomic (crash between rows leaves nothing), receipt numbers increase and survive restart, forced failure mid-batch then
  retry gives one server copy (fake server dedupes by op id), stock shown = level + unconfirmed movements without double count, void reverses, balances equal ledger sum,
  v3 -> v4 migration keeps products and converts opening stock.
- Done when: `flutter analyze` and `flutter test` pass. Use Opus.
