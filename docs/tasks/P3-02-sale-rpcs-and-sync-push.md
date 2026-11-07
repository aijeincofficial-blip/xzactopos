# P3-02 Sale RPCs, `sync_push` and `sync_pull_pos`
Goal: one idempotent server entry for everything a sale touches, and a delta pull for stock and utang.
- Per-kind functions (SECURITY DEFINER, pinned search_path, `claim_op`/`finish_op`, `assert_active_user`, `assert_module('pos')`, location access):
  - `record_sale(op_id, sale jsonb)`: validates totals (sum of lines - discount = total; payments sum = total; utang needs a customer), inserts sale, items, payments,
    `sale` movements (only `track_stock` products), a `charge` ledger row for the utang part, and `audit_log`. Unknown/archived products are still accepted
    (the sale happened) and flagged in the result. Result carries `applied_at`.
  - `void_sale(op_id, sale_id, reason?)`: marks voided, writes reversing `sale_void` movements and a negative ledger row; voiding twice is a no-op with the stored result.
  - `upsert_customer(op_id, customer)`, `record_utang_payment(op_id, customer_id, amount, note?)`, `post_opening_stock(op_id, variant_id, qty)`.
  - Permission: solo superadmin, or admin managing the store, or cashier assigned to it (sales only). Everyone else `not_allowed`.
- `sync_push(ops jsonb)`: up to 50 ops in order, each `{op_id, kind, payload}`; one savepoint per op so a failure rolls back only that op;
  returns `[{op_id, status: ok|rejected|error, result|hint}]`. Unknown kinds are rejected. Revoke from anon/public, grant authenticated.
- `sync_pull_pos(cursors, limit)`: stock levels, customers, ledger entries; keyset `(updated_at, key)`, explicit columns, 5 s hold-back, runs as caller.
- Hints for i18n: totals_mismatch, payments_mismatch, customer_required, qty_invalid, sale_not_found, already_voided, plus the existing ones.
- Tests: pgTAP `012_sale_rpcs.test.sql`: retry returns the same result and adds no rows (sale, movements, ledger), mid-batch failure leaves the other ops applied,
  totals/payments mismatch refused, cross-tenant refused, void reverses exactly, negative stock accepted, `track_stock=false` writes no movement, pull paging and hold-back,
  stock equals the sum of movements after a random sequence of sales and voids.
- Done when: `pnpm check` passes. Use Opus.
