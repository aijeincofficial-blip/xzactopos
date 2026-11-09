# S-01 Solo provisioning RPC
Goal: a new user can become a working solo store owner in one call.
- New migration (additive): `provision_solo_store(store_name text, location_id uuid, tenant_id uuid)`; ids are client UUIDv7.
  Creates tenant (PHP base currency, `fil` locale, setup complete), one store location, sets caller as superadmin with that location. Inventory module on, POS on, warehouse off.
- Callable by an authenticated user with no tenant; refuses if the user already has one (`user_has_tenant` hint). Writes `audit_log`.
- Must reuse existing helpers/rules; do not weaken RLS or the guard test.
- Tests: pgTAP file `007_solo_store.test.sql` (happy path, repeat call refused, new tenant isolated). Existing 693 tests unchanged and green.
- Done when: `pnpm check` passes. Use Opus (RLS-adjacent).
