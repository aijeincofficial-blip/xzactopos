# P1-03 RLS policies + schema guard (Opus)
Plan: §10, §15 CI guard.
- RLS on every Phase 1 table. Base: `tenant_id = (select auth_tenant_id())`.
- Read: superadmin all tenant rows; others see own profile, tenant, modules, settings, and locations they can access.
- Direct writes only for simple master data by authorized roles; `audit_log`, `platform_admins`, `tenant_limits` have no client insert/update policy.
- Guard test (pgTAP): every table in `public` has RLS enabled and a `tenant_id` column (allow-list: `tenants`, `platform_admins`).
Done when: guard test passes and fails if a table without RLS is added.
