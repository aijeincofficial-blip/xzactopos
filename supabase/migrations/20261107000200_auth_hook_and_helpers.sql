-- P1-02 Custom access token hook and RLS helper functions
-- Plan: docs/plan.md section 5 (Implementation) and section 10.
--
-- JWT claims (tenant_id, user_role, tenant_status, platform_admin) are for the UI and routing.
-- Authorization never trusts the role claim alone: helpers read role and active flag live from
-- profiles (one PK lookup, cached per statement when wrapped as `(select fn())` in policies),
-- so a demoted or deactivated user loses access immediately instead of at the next token refresh.
-- The tenant must still match the JWT tenant_id claim, so a token without the hook gets nothing.

-- ---------------------------------------------------------------------------
-- Custom access token hook (runs inside GoTrue as supabase_auth_admin)
-- ---------------------------------------------------------------------------

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_claims      jsonb := coalesce(event -> 'claims', '{}'::jsonb);
  v_user_id     uuid  := (event ->> 'user_id')::uuid;
  v_tenant_id   uuid;
  v_role        text;
  v_status      text;
  v_active      boolean;
  v_platform    boolean;
begin
  select p.tenant_id, p.role, t.status, p.active
    into v_tenant_id, v_role, v_status, v_active
  from public.profiles p
  join public.tenants t on t.id = p.tenant_id
  where p.user_id = v_user_id
    and p.deleted_at is null
    and t.deleted_at is null;

  select exists (select 1 from public.platform_admins pa where pa.user_id = v_user_id)
    into v_platform;

  -- never let stale or client-supplied values survive
  v_claims := v_claims - 'tenant_id' - 'user_role' - 'tenant_status' - 'user_active' - 'platform_admin';

  if v_tenant_id is not null then
    v_claims := v_claims || jsonb_build_object(
      'tenant_id', v_tenant_id,
      'user_role', v_role,
      'tenant_status', v_status,
      'user_active', v_active
    );
  end if;

  if v_platform then
    v_claims := v_claims || jsonb_build_object('platform_admin', true);
  end if;

  return jsonb_set(event, '{claims}', v_claims);
end;
$$;

comment on function public.custom_access_token_hook(jsonb) is
  'Adds tenant_id, user_role, tenant_status, user_active (and platform_admin) to the JWT. UI hint only; RLS re-checks live.';

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook(jsonb) from authenticated, anon, public;

grant select on public.profiles, public.tenants, public.platform_admins to supabase_auth_admin;

create policy profiles_auth_admin_read on public.profiles
  for select to supabase_auth_admin using (true);
create policy tenants_auth_admin_read on public.tenants
  for select to supabase_auth_admin using (true);
create policy platform_admins_auth_admin_read on public.platform_admins
  for select to supabase_auth_admin using (true);

-- ---------------------------------------------------------------------------
-- Identity helpers
-- All: STABLE SECURITY DEFINER, empty search_path, fully qualified names.
-- ---------------------------------------------------------------------------

-- Tenant of the caller, or null when: no hook claim, claim does not match the profile,
-- user deactivated or soft-deleted, tenant archived or deleted.
-- Suspended tenants still resolve so they can read and export; writes are refused by assert_active_user().
create or replace function public.auth_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.tenant_id
  from public.profiles p
  join public.tenants t on t.id = p.tenant_id
  where p.user_id = auth.uid()
    and p.tenant_id = nullif(auth.jwt() ->> 'tenant_id', '')::uuid
    and p.active
    and p.deleted_at is null
    and t.deleted_at is null
    and t.status <> 'archived';
$$;

-- Live role of the caller (null when auth_tenant_id() is null).
create or replace function public.auth_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.user_id = auth.uid()
    and p.tenant_id = public.auth_tenant_id();
$$;

create or replace function public.is_superadmin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.auth_role() = 'superadmin', false);
$$;

-- Active user in an active (not suspended) tenant: the bar for any write.
create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tenants t
    where t.id = public.auth_tenant_id()
      and t.status = 'active'
  );
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.platform_admins pa where pa.user_id = auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- Location scope (looked up live, never stored in the JWT)
-- ---------------------------------------------------------------------------

-- Position ordering: manager >= supervisor. p_min_position null means "any assignment".
-- Superadmin passes for every live location of their tenant.
create or replace function public.has_location_access(
  p_location_id uuid,
  p_min_position text default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
begin
  if p_min_position is not null and p_min_position not in ('manager', 'supervisor') then
    raise exception 'invalid position: %', p_min_position using errcode = '22023';
  end if;

  if v_tenant is null or p_location_id is null then
    return false;
  end if;

  if public.is_superadmin() then
    return exists (
      select 1 from public.locations l
      where l.id = p_location_id and l.tenant_id = v_tenant and l.deleted_at is null
    );
  end if;

  return exists (
    select 1
    from public.location_access la
    join public.locations l on l.id = la.location_id
    where la.user_id = auth.uid()
      and la.location_id = p_location_id
      and la.tenant_id = v_tenant
      and la.deleted_at is null
      and l.deleted_at is null
      and (
        p_min_position is null
        or (p_min_position = 'supervisor' and la.position in ('supervisor', 'manager'))
        or (p_min_position = 'manager' and la.position = 'manager')
      )
  );
end;
$$;

-- Every location the caller can see, for set-based policies:
--   using (location_id = any ((select public.auth_location_ids())))
create or replace function public.auth_location_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(l.id), '{}'::uuid[])
  from public.locations l
  where l.tenant_id = public.auth_tenant_id()
    and l.deleted_at is null
    and (
      public.is_superadmin()
      or exists (
        select 1 from public.location_access la
        where la.user_id = auth.uid()
          and la.location_id = l.id
          and la.deleted_at is null
      )
    );
$$;

-- ---------------------------------------------------------------------------
-- Assertions for RPCs (raise instead of returning false)
-- ---------------------------------------------------------------------------

create or replace function public.assert_active_user()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if public.auth_tenant_id() is null then
    raise exception 'not signed in to an active account' using errcode = '42501';
  end if;

  select t.status into v_status from public.tenants t where t.id = public.auth_tenant_id();
  if v_status <> 'active' then
    raise exception 'tenant is %', v_status using errcode = '42501', hint = 'tenant_' || v_status;
  end if;
end;
$$;

create or replace function public.assert_module(p_module text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_enabled boolean;
begin
  if p_module not in ('inventory', 'pos', 'warehouse') then
    raise exception 'unknown module: %', p_module using errcode = '22023';
  end if;

  select case p_module
           when 'inventory' then m.inventory
           when 'pos' then m.pos
           when 'warehouse' then m.warehouse
         end
    into v_enabled
  from public.tenant_modules m
  where m.tenant_id = public.auth_tenant_id()
    and m.deleted_at is null;

  if not coalesce(v_enabled, false) then
    raise exception 'module % is not enabled for this tenant', p_module
      using errcode = '42501', hint = 'module_disabled';
  end if;
end;
$$;

create or replace function public.assert_location_access(
  p_location_id uuid,
  p_min_position text default null
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.has_location_access(p_location_id, p_min_position) then
    raise exception 'no access to this location' using errcode = '42501', hint = 'location_denied';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: signed-in users only. Supabase grants EXECUTE to anon by default; take it back.
-- ---------------------------------------------------------------------------

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.auth_tenant_id()',
    'public.auth_role()',
    'public.is_superadmin()',
    'public.is_active_user()',
    'public.is_platform_admin()',
    'public.has_location_access(uuid, text)',
    'public.auth_location_ids()',
    'public.assert_active_user()',
    'public.assert_module(text)',
    'public.assert_location_access(uuid, text)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;

-- Trigger functions are not callable as RPC anyway, but keep anon away from everything in public.
revoke execute on function public.validate_location_access() from public, anon;
revoke execute on function public.set_updated_at() from public, anon;
revoke execute on function public.prevent_tenant_change() from public, anon;
