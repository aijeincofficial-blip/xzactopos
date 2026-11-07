# P1-01 Core tenancy schema (Opus)
Plan: §4, §6 Core, §15.
Migration `<ts>_core_tenancy.sql`:
- `uuid_generate_v7()` SQL function (server-side fallback only; clients send their own UUIDv7). Postgres 17 has no built-in.
- Shared triggers: `set_updated_at()`, `prevent_tenant_change()` (tenant_id immutable).
- Tables: `tenants` (slug unique, base currency, timezone, tax_mode, status active|suspended|archived),
  `tenant_modules` (**one row per tenant, booleans** inventory/pos/warehouse, `check (inventory or not (pos or warehouse))`, inventory locked true),
  `tenant_settings` (offline window, receipt header/footer, default locale), `tenant_limits` (max locations/users),
  `platform_admins`, `profiles` (user_id pk, tenant_id, username, full_name, role, pin_hash, locale, active),
  `locations` (type store|warehouse, `unique (tenant_id, code)`), `location_access` (user_id, location_id, tenant_id, position manager|supervisor|null),
  `audit_log` (small `meta` jsonb).
- Every table: tenant_id, created_at, updated_at, deleted_at; indexes on tenant_id / location_id / user_id.
- Constraint: position only allowed for admins; warehouse role only on warehouses; cashier only on stores (enforced in RPC + trigger).
Done when: migration applies on a clean `supabase db reset`.
