# P2-02 Catalog RPCs and sync pull
Goal: one call to add or edit a product with its default variant and price, and a delta pull for devices.
- `upsert_product(p_op_id, p_product jsonb)`: client-made ids for product and default variant; creates/updates product + default variant + price row atomically.
  Idempotent through `processed_ops` (create it here if missing, as in plan section 7). Checks role (superadmin, or admin manager) via the existing helpers; module `inventory`.
- `archive_product(p_op_id, p_product_id)`: soft delete via `deleted_at`, never a hard delete.
- `sync_pull_catalog(p_since timestamptz, p_limit int default 500)`: rows with `updated_at > p_since` for the caller's tenant, tombstones included,
  explicit columns, ordered by `(updated_at, id)`, returns a next cursor. No Realtime.
- Errors use stable `hint` keys (duplicate_sku, duplicate_barcode, limit_products, ...). Every change writes `audit_log`.
- Tests: pgTAP `009_catalog_rpcs.test.sql`: idempotent retry, duplicates refused, cross-tenant refused, cashier refused, pull paging and tombstones.
- Done when: `pnpm check` passes. Use Opus.
