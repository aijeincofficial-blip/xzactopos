# P2-01 Catalog schema
Goal: tables for categories, products, variants and prices, with RLS, following plan section 6. Additive migration only.
- Tables: `categories`, `products` (name, category_id, unit, tax_rate, track_stock, active, `photo_path` text null), `product_variants`
  (sku, barcode, cost, reorder_point, active, `is_default` bool), `variant_prices` (variant_id, currency, price in minor units; base-currency row required).
- Every table: `tenant_id`, `created_at`, `updated_at` (trigger), `deleted_at`, UUIDv7 ids, composite tenant FKs like `location_access`.
- Unique per tenant: `unique (tenant_id, sku)`, `unique (tenant_id, barcode)` (partial, where not null and not deleted).
  Exactly one default variant per product (partial unique index).
- Delta-sync index on `(tenant_id, updated_at)` for each table. Honor `tenant_limits.max_products`.
- RLS: read for any active user of the tenant; direct client writes denied (RPC only, P2-02). Column grants like Phase 1.
- Tests: pgTAP `008_catalog_schema.test.sql`; add a row per role and a probe entry per table to `004_tenant_isolation_matrix.test.sql`
  (the coverage check fails otherwise); guard test stays green.
- Done when: `pnpm check` passes. Use Opus.
