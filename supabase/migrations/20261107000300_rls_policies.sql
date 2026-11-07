-- P1-03 RLS policies for the Phase 1 tables
-- Plan: docs/plan.md section 5 (permission matrix) and section 10.
--
-- Shape of every policy: tenant_id = (select auth_tenant_id()) plus a role / location condition.
-- Reads follow the permission matrix. Direct writes are limited to simple master data by the
-- authorized role; everything that changes access (modules, roles, assignments, new locations)
-- goes through audited SECURITY DEFINER RPCs (P1-05), so those tables have no client write policy.
-- Deletes are never allowed from clients: soft delete via deleted_at only.

-- ---------------------------------------------------------------------------
-- Defaults for every future table and function created by migrations
-- ---------------------------------------------------------------------------
alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke delete, truncate on tables from authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from anon, public;

-- Functions created before these defaults: keep anon out (authenticated keeps its own grant,
-- needed because uuid_generate_v7() is a column default).
revoke execute on function public.uuid_generate_v7() from public, anon;
grant execute on function public.uuid_generate_v7() to authenticated;

-- Existing tables: no client deletes or truncates anywhere.
revoke delete, truncate on all tables in schema public from authenticated;

-- ---------------------------------------------------------------------------
-- audit_log gets a location so admins can read their own stores' entries (matrix: "Audit log: own stores")
-- ---------------------------------------------------------------------------
alter table public.audit_log
  add column location_id uuid references public.locations (id) on delete set null;

create index audit_log_location_idx on public.audit_log (location_id) where location_id is not null;

-- ---------------------------------------------------------------------------
-- tenants: members read their tenant; superadmin edits a few descriptive fields.
-- slug, base_currency, plan and status are set by provisioning / setup RPCs only.
-- ---------------------------------------------------------------------------
create policy tenants_member_read on public.tenants
  for select to authenticated
  using (id = (select public.auth_tenant_id()));

create policy tenants_superadmin_update on public.tenants
  for update to authenticated
  using (id = (select public.auth_tenant_id()) and (select public.is_superadmin()) and (select public.is_active_user()))
  with check (id = (select public.auth_tenant_id()));

revoke insert, update on public.tenants from authenticated;
grant update (name, timezone, tax_mode) on public.tenants to authenticated;

-- ---------------------------------------------------------------------------
-- tenant_modules: everyone in the tenant reads (route guards); changes via set_modules RPC only.
-- ---------------------------------------------------------------------------
create policy tenant_modules_member_read on public.tenant_modules
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id()));

revoke insert, update on public.tenant_modules from authenticated;

-- ---------------------------------------------------------------------------
-- tenant_settings: everyone reads (locale, offline window, receipt text); superadmin edits.
-- ---------------------------------------------------------------------------
create policy tenant_settings_member_read on public.tenant_settings
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id()));

create policy tenant_settings_superadmin_update on public.tenant_settings
  for update to authenticated
  using (tenant_id = (select public.auth_tenant_id()) and (select public.is_superadmin()) and (select public.is_active_user()))
  with check (tenant_id = (select public.auth_tenant_id()));

revoke insert, update on public.tenant_settings from authenticated;
grant update (default_locale, locales, offline_session_days, receipt_header, receipt_footer)
  on public.tenant_settings to authenticated;

-- ---------------------------------------------------------------------------
-- tenant_limits: superadmin reads; only the platform operator writes (service role).
-- ---------------------------------------------------------------------------
create policy tenant_limits_superadmin_read on public.tenant_limits
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id()) and (select public.is_superadmin()));

-- ---------------------------------------------------------------------------
-- tenant_currencies: everyone reads (devices cache rates offline); superadmin maintains rates.
-- ---------------------------------------------------------------------------
create policy tenant_currencies_member_read on public.tenant_currencies
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id()));

create policy tenant_currencies_superadmin_insert on public.tenant_currencies
  for insert to authenticated
  with check (tenant_id = (select public.auth_tenant_id()) and (select public.is_superadmin()) and (select public.is_active_user()));

create policy tenant_currencies_superadmin_update on public.tenant_currencies
  for update to authenticated
  using (tenant_id = (select public.auth_tenant_id()) and (select public.is_superadmin()) and (select public.is_active_user()))
  with check (tenant_id = (select public.auth_tenant_id()));

revoke insert, update on public.tenant_currencies from authenticated;
grant insert (tenant_id, code, rate_to_base, rate_date, rounding, active) on public.tenant_currencies to authenticated;
grant update (rate_to_base, rate_date, rounding, active, deleted_at) on public.tenant_currencies to authenticated;

-- ---------------------------------------------------------------------------
-- platform_admins: no client access at all (use is_platform_admin()).
-- ---------------------------------------------------------------------------
revoke all on public.platform_admins from authenticated;

-- ---------------------------------------------------------------------------
-- profiles
--   read: own row; superadmin all; admin and warehouse users see people who share one of their locations.
--   cashiers see only themselves.
--   update: own full_name and locale. Role, active, username: RPC only.
--   pin_hash is never readable by clients (offline PIN material is delivered by a dedicated RPC later).
-- ---------------------------------------------------------------------------
-- Does p_user hold a live assignment at one of the caller's locations?
-- SECURITY DEFINER so the answer does not depend on location_access's own read policy.
create or replace function public.shares_location_with(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.location_access la
    where la.user_id = p_user
      and la.tenant_id = public.auth_tenant_id()
      and la.deleted_at is null
      and la.location_id = any (public.auth_location_ids())
  );
$$;

revoke execute on function public.shares_location_with(uuid) from public, anon;
grant execute on function public.shares_location_with(uuid) to authenticated;

create policy profiles_read on public.profiles
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (
      user_id = (select auth.uid())
      or (select public.is_superadmin())
      or ((select public.auth_role()) in ('admin', 'warehouse') and public.shares_location_with(user_id))
    )
  );

create policy profiles_self_update on public.profiles
  for update to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and user_id = (select auth.uid())
    and (select public.is_active_user())
  )
  with check (tenant_id = (select public.auth_tenant_id()) and user_id = (select auth.uid()));

revoke select, insert, update on public.profiles from authenticated;
grant select (user_id, tenant_id, username, full_name, role, locale, active, created_at, updated_at, deleted_at)
  on public.profiles to authenticated;
grant update (full_name, locale) on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- locations
--   read: superadmin every row of the tenant (including soft-deleted, for delta sync);
--         everyone else only their assigned live locations.
--   update: superadmin edits name, address, active. Create, delete, bins: RPC only (limits, audit).
-- ---------------------------------------------------------------------------
create policy locations_read on public.locations
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and ((select public.is_superadmin()) or id = any ((select public.auth_location_ids())::uuid[]))
  );

create policy locations_superadmin_update on public.locations
  for update to authenticated
  using (tenant_id = (select public.auth_tenant_id()) and (select public.is_superadmin()) and (select public.is_active_user()))
  with check (tenant_id = (select public.auth_tenant_id()));

revoke insert, update on public.locations from authenticated;
grant update (name, address, active) on public.locations to authenticated;

-- ---------------------------------------------------------------------------
-- location_access
--   read: own assignments; superadmin all; admins see assignments in stores where they are at least supervisor.
--   writes: assign_location / revoke_location RPCs only.
-- ---------------------------------------------------------------------------
create policy location_access_read on public.location_access
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (
      user_id = (select auth.uid())
      or (select public.is_superadmin())
      or ((select public.auth_role()) = 'admin' and public.has_location_access(location_id, 'supervisor'))
    )
  );

revoke insert, update on public.location_access from authenticated;

-- ---------------------------------------------------------------------------
-- audit_log: superadmin reads all; admins read entries for stores where they are manager. No client writes.
-- ---------------------------------------------------------------------------
create policy audit_log_read on public.audit_log
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (
      (select public.is_superadmin())
      or ((select public.auth_role()) = 'admin' and location_id is not null and public.has_location_access(location_id, 'manager'))
    )
  );

revoke insert, update on public.audit_log from authenticated;
