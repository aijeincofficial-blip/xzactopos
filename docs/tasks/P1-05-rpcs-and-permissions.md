# P1-05 Admin RPCs and permission keys (Opus for RPCs)
Plan: §4, §5 matrix, §15.
- RPCs (`SECURITY DEFINER`, fixed search_path, check role/location/module/active, write `audit_log`):
  `provision_tenant(name, slug, owner_email, preset)` (service role only), `complete_setup(...)`, `set_modules(...)`,
  `upsert_location(...)`, `set_user_role(...)`, `assign_location(user, location, position)`, `revoke_location(...)`,
  `set_user_active(...)`. Last-superadmin protection. Managers may only manage cashiers in their own stores.
- `packages/core/permissions.ts`: permission keys + `can(ctx, key, locationId)` mirroring the §5 matrix, with Vitest table tests.
- pgTAP for each RPC: allowed and refused paths.
Done when: RPC tests and permission tests pass.
