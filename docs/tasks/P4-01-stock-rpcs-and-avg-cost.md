# P4-01 Stock RPCs and average cost
Goal: stock can go up and be corrected only through idempotent ops, with weighted average cost.
- Migration (new file): widen `stock_movements.type` to add `receipt`, `count_correction`, `damage`; add `stock_levels.avg_cost bigint`.
  The movement trigger maintains `avg_cost` on `receipt` rows that carry a `unit_cost` (weighted average of the old quantity, if positive, and the received quantity); other movements leave it alone.
- `op_receive_stock(op, {variant_id, qty > 0, unit_cost?, location_id?, note?})` and `op_adjust_stock(op, {variant_id, counted (>= 0), reason: counted|damage|other, location_id?})`
  (the delta is computed on the server from the current level, so a retry or a late sale never skews it; delta 0 writes nothing). Permission as opening stock; `sync_push` dispatches both.
- `sync_pull_pos` returns `avg_cost`. The sale line cost stays what the client sends (P4-02 makes the phone send the average cost it pulled), so `op_record_sale` is unchanged.
- Tests: pgTAP `013_stock_ops.test.sql`: receipt raises level, replay adds nothing, weighted average math, count writes the right delta (also after a sale in between), damage reason, cashier refused, cross-tenant refused,
  and a property test (a few hundred pseudo-random sales, voids, receipts, counts) where every level equals the sum of its movements and no level is written outside the trigger.
- Done when: `pnpm check` passes. Use Opus.
