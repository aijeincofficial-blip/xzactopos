# P4-02 Local stock ops and sync (Flutter)
Goal: stock-in and counts work offline and show at once, then reach the server once.
- Drift schema v5: `stock_levels.avg_cost`; a `counted_variants` notion is derived (a variant is "counted" when it has a server level row or a local movement).
- `SalesStore` gains `receiveStock(variantId, qty, cost?, note?, opId)`, `adjustStock(variantId, counted, reason, opId)` (local effect = counted - current shown stock), `watchStockList(query, lowOnly)`, `lowStockCount()`.
  Engine kinds `receive_stock`, `adjust_stock` join the pos batch. A count whose server delta differs from the local guess is fine: the pull brings the real level and the effect is dropped by the P3-03 rule.
- Tests: effects visible at once, replay safe, count after a sale, low-stock query, not-counted vs zero, fake server round trip including a lost response.
- Done when: analyze and test pass. Use Opus.
