# P1-02 Access token hook and RLS helpers (Opus)
Plan: §5 Implementation, §10.
- `custom_access_token_hook(event)` adds `tenant_id`, `user_role`, `tenant_status` claims from `profiles`/`tenants`; grant only to `supabase_auth_admin`. Wire in `supabase/config.toml`.
- `STABLE SECURITY DEFINER` helpers with fixed search_path, used as `(select fn())` in policies:
  `auth_tenant_id()`, `auth_role()`, `is_superadmin()`, `is_active_user()`,
  `has_location_access(location_id, min_position default null)` (superadmin passes; manager >= supervisor),
  `assert_module(module)`, `assert_active_user()`, `is_platform_admin()`.
Done when: pgTAP covers each helper incl. deactivated user, suspended tenant, position ordering.
