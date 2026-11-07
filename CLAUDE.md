# Project: Multi-tenant POS + Inventory + Warehouse (Supabase, offline-first)

Source of truth: docs/plan.md (exported from the architecture plan). Read only the section a task needs.
Work one phase at a time, one task card at a time. Task cards live in docs/tasks/.

## Architecture rules
- Modules: Inventory is the always-on core. POS and Warehouse are add-ons that each require it.
- Multi-tenant: shared schema, `tenant_id` on every table, RLS on every table, no exceptions.
  Business keys are unique per tenant: `unique (tenant_id, sku)`, never globally unique.
- Roles: superadmin, admin (per-store position: manager | supervisor), warehouse, cashier.
  The UI hides; the database enforces (RPC checks role, location and module).
- Stock is never edited directly. Only append to `stock_movements`. `stock_levels` is trigger-derived.
- The variant is the stockable and sellable unit. Every product has at least one variant. Use `variant_id` everywhere.
- Warehouse bins are opt-in per warehouse (`bins_enabled`). Sum of bin stock must equal warehouse stock.
- Money = integer minor units + currency code. Sales snapshot `fx_rate`. Base currency per tenant.
- i18n: i18next keys, English + Tagalog (fil). No hard-coded UI strings.
- IDs are UUIDv7 generated on the client. All timestamps UTC. Soft delete via `deleted_at`.

## Offline and sync
- Local store behind a `LocalStore` interface (Dexie first). Outbox with `client_op_id`, idempotent `sync_push`.
- Transactions are append-only and conflict-free. Master data is last-write-wins by server `updated_at`.
- Never add Realtime subscriptions to POS screens. Poll at 120 s idle with backoff.

## Free-tier discipline (Supabase)
- Business logic in Postgres RPC, not Edge Functions, unless the service role is required.
- Select explicit columns, paginate, delta-sync. Reports read rollup tables, not raw rows.
- Never put the service role key in client code. Never store images or large JSON in the DB.

## Workflow
- Migrations and pgTAP tests before UI. Every new table: RLS policies + a test.
- Run `pnpm check` (lint, types, tests, pgTAP) before declaring a task done.
- Commit per task, update docs/handoff.md, then /clear before the next unrelated task.
- Sonnet by default. Opus only for RLS, sync engine, ledger and stock math.
