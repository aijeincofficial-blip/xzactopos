-- P1-05 Admin RPCs
-- Plan: docs/plan.md sections 4, 5 (permission matrix) and 15.
--
-- Every RPC: SECURITY DEFINER, empty search_path, fully qualified names, explicit checks inside
-- (active user, role, location, module), and an audit_log row for every change.
-- Errors: 42501 = not allowed, 22023 = bad argument, P0001 = business rule (hint carries a stable key
-- the client maps to an i18n message, e.g. last_superadmin, limit_locations, base_currency_locked).

-- ---------------------------------------------------------------------------
-- Internal helpers (not callable by clients)
-- ---------------------------------------------------------------------------

create or replace function public.write_audit(
  p_action      text,
  p_entity      text,
  p_entity_id   uuid,
  p_location_id uuid default null,
  p_meta        jsonb default '{}'::jsonb,
  p_tenant_id   uuid default null
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_log (tenant_id, user_id, action, entity, entity_id, location_id, meta)
  values (
    coalesce(p_tenant_id, public.auth_tenant_id()),
    auth.uid(),
    p_action,
    p_entity,
    p_entity_id,
    p_location_id,
    coalesce(p_meta, '{}'::jsonb)
  );
$$;

create or replace function public.assert_superadmin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.assert_active_user();
  if not public.is_superadmin() then
    raise exception 'superadmin only' using errcode = '42501', hint = 'superadmin_only';
  end if;
end;
$$;

-- Target user inside the caller's tenant, locked for update. Raises when missing.
create or replace function public.lock_tenant_profile(p_user uuid)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
begin
  select * into v_profile
  from public.profiles p
  where p.user_id = p_user
    and p.tenant_id = public.auth_tenant_id()
    and p.deleted_at is null
  for update;

  if not found then
    raise exception 'user not found' using errcode = '42501', hint = 'user_not_found';
  end if;
  return v_profile;
end;
$$;

-- Managers may manage cashiers who work in a store they manage. Superadmins may manage anyone.
create or replace function public.can_manage_user(p_target public.profiles)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_superadmin()
      or (
        public.auth_role() = 'admin'
        and p_target.role = 'cashier'
        and exists (
          select 1
          from public.location_access la
          where la.user_id = p_target.user_id
            and la.tenant_id = p_target.tenant_id
            and la.deleted_at is null
            and public.has_location_access(la.location_id, 'manager')
        )
      );
$$;

-- Refuse changes that would leave the tenant without an active superadmin.
create or replace function public.assert_not_last_superadmin(p_tenant uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_others int;
begin
  -- serialize concurrent demotions / deactivations of superadmins in this tenant
  perform 1 from public.profiles p
  where p.tenant_id = p_tenant and p.role = 'superadmin'
  for update;

  select count(*) into v_others
  from public.profiles p
  where p.tenant_id = p_tenant
    and p.role = 'superadmin'
    and p.active
    and p.deleted_at is null
    and p.user_id <> p_user;

  if v_others = 0 then
    raise exception 'a tenant must keep at least one active superadmin'
      using errcode = 'P0001', hint = 'last_superadmin';
  end if;
end;
$$;

revoke execute on function public.write_audit(text, text, uuid, uuid, jsonb, uuid) from public, anon, authenticated;
revoke execute on function public.assert_superadmin() from public, anon, authenticated;
revoke execute on function public.lock_tenant_profile(uuid) from public, anon, authenticated;
revoke execute on function public.can_manage_user(public.profiles) from public, anon, authenticated;
revoke execute on function public.assert_not_last_superadmin(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- provision_tenant: platform operator only (service role or platform_admins)
-- The owner's auth user is created first (invite_user Edge Function); this links it as superadmin.
-- ---------------------------------------------------------------------------

create or replace function public.provision_tenant(
  p_name             text,
  p_slug             text,
  p_base_currency    text,
  p_owner_user_id    uuid,
  p_owner_username   text,
  p_preset           text default 'inventory',
  p_timezone         text default 'UTC',
  p_owner_full_name  text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.uuid_generate_v7();
  v_pos    boolean;
  v_wh     boolean;
begin
  if not (coalesce(auth.role(), '') = 'service_role' or public.is_platform_admin()) then
    raise exception 'platform operator only' using errcode = '42501', hint = 'platform_only';
  end if;

  case p_preset
    when 'inventory' then v_pos := false; v_wh := false;
    when 'pos'       then v_pos := true;  v_wh := false;
    when 'warehouse' then v_pos := false; v_wh := true;
    when 'all'       then v_pos := true;  v_wh := true;
    else raise exception 'unknown preset: %', p_preset using errcode = '22023';
  end case;

  if not exists (select 1 from auth.users u where u.id = p_owner_user_id) then
    raise exception 'owner auth user does not exist' using errcode = '22023';
  end if;
  if exists (select 1 from public.profiles p where p.user_id = p_owner_user_id) then
    raise exception 'owner already belongs to a tenant' using errcode = 'P0001', hint = 'user_has_tenant';
  end if;

  insert into public.tenants (id, name, slug, base_currency, timezone)
    values (v_tenant, p_name, p_slug, upper(p_base_currency), p_timezone);
  insert into public.tenant_modules (tenant_id, inventory, pos, warehouse) values (v_tenant, true, v_pos, v_wh);
  insert into public.tenant_settings (tenant_id) values (v_tenant);
  insert into public.tenant_limits (tenant_id) values (v_tenant);
  insert into public.profiles (user_id, tenant_id, username, full_name, role)
    values (p_owner_user_id, v_tenant, p_owner_username, coalesce(p_owner_full_name, ''), 'superadmin');

  perform public.write_audit('tenant.provision', 'tenant', v_tenant, null,
    jsonb_build_object('slug', p_slug, 'preset', p_preset, 'owner', p_owner_user_id), v_tenant);

  return v_tenant;
end;
$$;

-- ---------------------------------------------------------------------------
-- Setup wizard and modules (superadmin)
-- ---------------------------------------------------------------------------

create or replace function public.set_modules(p_pos boolean, p_warehouse boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_before public.tenant_modules;
begin
  perform public.assert_superadmin();
  v_tenant := public.auth_tenant_id();

  select * into v_before from public.tenant_modules m where m.tenant_id = v_tenant for update;
  if not found then
    insert into public.tenant_modules (tenant_id, pos, warehouse) values (v_tenant, p_pos, p_warehouse);
  else
    -- turning a module off hides it and blocks writes; it never deletes data
    update public.tenant_modules
      set inventory = true, pos = p_pos, warehouse = p_warehouse
      where tenant_id = v_tenant;
  end if;

  perform public.write_audit('modules.set', 'tenant', v_tenant, null, jsonb_build_object(
    'before', jsonb_build_object('pos', v_before.pos, 'warehouse', v_before.warehouse),
    'after',  jsonb_build_object('pos', p_pos, 'warehouse', p_warehouse)));
end;
$$;

create or replace function public.complete_setup(
  p_name            text,
  p_base_currency   text,
  p_timezone        text,
  p_tax_mode        text,
  p_default_locale  text,
  p_locales         text[],
  p_pos             boolean,
  p_warehouse       boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant public.tenants;
begin
  perform public.assert_superadmin();

  select * into v_tenant from public.tenants t where t.id = public.auth_tenant_id() for update;

  -- stock cost and every stored base amount depend on the base currency: fixed once setup is done
  if v_tenant.setup_completed_at is not null and upper(p_base_currency) <> v_tenant.base_currency then
    raise exception 'base currency cannot change after setup'
      using errcode = 'P0001', hint = 'base_currency_locked';
  end if;

  update public.tenants
    set name = p_name,
        base_currency = upper(p_base_currency),
        timezone = p_timezone,
        tax_mode = p_tax_mode,
        setup_completed_at = coalesce(setup_completed_at, now())
    where id = v_tenant.id;

  insert into public.tenant_settings (tenant_id, default_locale, locales)
    values (v_tenant.id, p_default_locale, p_locales)
    on conflict (tenant_id) do update
      set default_locale = excluded.default_locale, locales = excluded.locales;

  perform public.set_modules(p_pos, p_warehouse);

  perform public.write_audit('tenant.setup', 'tenant', v_tenant.id, null, jsonb_build_object(
    'base_currency', upper(p_base_currency), 'timezone', p_timezone, 'tax_mode', p_tax_mode,
    'locales', p_locales, 'first_time', v_tenant.setup_completed_at is null));
end;
$$;

-- ---------------------------------------------------------------------------
-- Locations (superadmin). The client sends its own UUIDv7 id.
-- ---------------------------------------------------------------------------

create or replace function public.upsert_location(
  p_id            uuid,
  p_type          text,
  p_code          text,
  p_name          text,
  p_address       text default null,
  p_bins_enabled  boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_existing public.locations;
  v_count    int;
  v_max      int;
begin
  perform public.assert_superadmin();
  v_tenant := public.auth_tenant_id();

  if p_type = 'warehouse' then
    perform public.assert_module('warehouse');
  end if;

  select * into v_existing from public.locations l where l.id = p_id for update;

  if found then
    if v_existing.tenant_id <> v_tenant then
      raise exception 'location not found' using errcode = '42501', hint = 'location_not_found';
    end if;
    if v_existing.type <> p_type then
      raise exception 'location type cannot change' using errcode = 'P0001', hint = 'location_type_locked';
    end if;

    update public.locations
      set code = p_code, name = p_name, address = p_address, bins_enabled = p_bins_enabled
      where id = p_id;

    perform public.write_audit('location.update', 'location', p_id, p_id,
      jsonb_build_object('code', p_code, 'bins_enabled', p_bins_enabled));
  else
    select count(*) into v_count from public.locations l where l.tenant_id = v_tenant and l.deleted_at is null;
    select tl.max_locations into v_max from public.tenant_limits tl where tl.tenant_id = v_tenant;
    if v_max is not null and v_count >= v_max then
      raise exception 'location limit reached (%)', v_max using errcode = 'P0001', hint = 'limit_locations';
    end if;

    insert into public.locations (id, tenant_id, type, code, name, address, bins_enabled)
      values (p_id, v_tenant, p_type, p_code, p_name, p_address, p_bins_enabled);

    perform public.write_audit('location.create', 'location', p_id, p_id,
      jsonb_build_object('type', p_type, 'code', p_code));
  end if;

  return p_id;
end;
$$;

create or replace function public.archive_location(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.assert_superadmin();

  update public.locations
    set deleted_at = now(), active = false
    where id = p_id and tenant_id = public.auth_tenant_id() and deleted_at is null;
  if not found then
    raise exception 'location not found' using errcode = '42501', hint = 'location_not_found';
  end if;

  update public.location_access set deleted_at = now()
    where location_id = p_id and deleted_at is null;

  perform public.write_audit('location.archive', 'location', p_id, p_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Users: roles, assignments, activation
-- ---------------------------------------------------------------------------

create or replace function public.set_user_role(p_user uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.profiles;
  v_ended  int;
begin
  perform public.assert_superadmin();

  if p_role not in ('superadmin', 'admin', 'warehouse', 'cashier') then
    raise exception 'unknown role: %', p_role using errcode = '22023';
  end if;

  v_target := public.lock_tenant_profile(p_user);
  if v_target.role = p_role then
    return;
  end if;

  if v_target.role = 'superadmin' then
    perform public.assert_not_last_superadmin(v_target.tenant_id, p_user);
  end if;

  update public.profiles set role = p_role where user_id = p_user;

  -- assignments were valid for the old role only; end them (re-assign explicitly)
  update public.location_access set deleted_at = now()
    where user_id = p_user and deleted_at is null;
  get diagnostics v_ended = row_count;

  perform public.write_audit('role.change', 'profile', p_user, null, jsonb_build_object(
    'from', v_target.role, 'to', p_role, 'assignments_ended', v_ended));
end;
$$;

create or replace function public.assign_location(
  p_user      uuid,
  p_location  uuid,
  p_position  text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.profiles;
begin
  perform public.assert_active_user();
  v_target := public.lock_tenant_profile(p_user);

  if not exists (
    select 1 from public.locations l
    where l.id = p_location and l.tenant_id = v_target.tenant_id and l.deleted_at is null
  ) then
    raise exception 'location not found' using errcode = '42501', hint = 'location_not_found';
  end if;

  -- superadmin: anyone, anywhere (the location_access trigger still enforces role/type/position rules)
  -- manager: only cashiers, only into stores they manage, never with a position
  if not (
    public.is_superadmin()
    or (
      public.auth_role() = 'admin'
      and v_target.role = 'cashier'
      and p_position is null
      and public.has_location_access(p_location, 'manager')
    )
  ) then
    raise exception 'not allowed to assign this user here' using errcode = '42501', hint = 'assign_denied';
  end if;

  insert into public.location_access (user_id, location_id, tenant_id, position)
    values (p_user, p_location, v_target.tenant_id, p_position)
    on conflict (user_id, location_id) do update
      set position = excluded.position, deleted_at = null;

  perform public.write_audit('access.assign', 'profile', p_user, p_location,
    jsonb_build_object('position', p_position, 'role', v_target.role));
end;
$$;

create or replace function public.revoke_location(p_user uuid, p_location uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.profiles;
begin
  perform public.assert_active_user();
  v_target := public.lock_tenant_profile(p_user);

  if not (
    public.is_superadmin()
    or (
      public.auth_role() = 'admin'
      and v_target.role = 'cashier'
      and public.has_location_access(p_location, 'manager')
    )
  ) then
    raise exception 'not allowed to change this assignment' using errcode = '42501', hint = 'assign_denied';
  end if;

  update public.location_access
    set deleted_at = now()
    where user_id = p_user and location_id = p_location and deleted_at is null;

  if found then
    perform public.write_audit('access.revoke', 'profile', p_user, p_location);
  end if;
end;
$$;

create or replace function public.set_user_active(p_user uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.profiles;
begin
  perform public.assert_active_user();
  v_target := public.lock_tenant_profile(p_user);

  if p_user = auth.uid() and not p_active then
    raise exception 'you cannot deactivate yourself' using errcode = 'P0001', hint = 'self_deactivate';
  end if;

  if not public.can_manage_user(v_target) then
    raise exception 'not allowed to manage this user' using errcode = '42501', hint = 'manage_denied';
  end if;

  if v_target.active = p_active then
    return;
  end if;

  if v_target.role = 'superadmin' and not p_active then
    perform public.assert_not_last_superadmin(v_target.tenant_id, p_user);
  end if;

  update public.profiles set active = p_active where user_id = p_user;

  perform public.write_audit(case when p_active then 'user.activate' else 'user.deactivate' end,
    'profile', p_user, null, jsonb_build_object('role', v_target.role));
end;
$$;

-- ---------------------------------------------------------------------------
-- get_my_access: everything the client needs to build its permission context in one call
-- ---------------------------------------------------------------------------

create or replace function public.get_my_access()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_result jsonb;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;

  select jsonb_build_object(
    'user_id', p.user_id,
    'username', p.username,
    'full_name', p.full_name,
    'role', p.role,
    'locale', coalesce(p.locale, s.default_locale, 'en'),
    'tenant', jsonb_build_object(
      'id', t.id, 'name', t.name, 'slug', t.slug, 'status', t.status,
      'base_currency', t.base_currency, 'timezone', t.timezone,
      'setup_completed', t.setup_completed_at is not null),
    'modules', jsonb_build_object(
      'inventory', coalesce(m.inventory, false),
      'pos', coalesce(m.pos, false),
      'warehouse', coalesce(m.warehouse, false)),
    'locations', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id, 'type', l.type, 'code', l.code, 'name', l.name,
               'position', la.position) order by l.code)
      from public.locations l
      left join public.location_access la
        on la.location_id = l.id and la.user_id = p.user_id and la.deleted_at is null
      where l.tenant_id = v_tenant
        and l.deleted_at is null
        and (p.role = 'superadmin' or la.user_id is not null)
    ), '[]'::jsonb)
  )
  into v_result
  from public.profiles p
  join public.tenants t on t.id = p.tenant_id
  left join public.tenant_modules m on m.tenant_id = t.id
  left join public.tenant_settings s on s.tenant_id = t.id
  where p.user_id = auth.uid();

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.provision_tenant(text, text, text, uuid, text, text, text, text)',
    'public.set_modules(boolean, boolean)',
    'public.complete_setup(text, text, text, text, text, text[], boolean, boolean)',
    'public.upsert_location(uuid, text, text, text, text, boolean)',
    'public.archive_location(uuid)',
    'public.set_user_role(uuid, text)',
    'public.assign_location(uuid, uuid, text)',
    'public.revoke_location(uuid, uuid)',
    'public.set_user_active(uuid, boolean)',
    'public.get_my_access()'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;

grant execute on function public.provision_tenant(text, text, text, uuid, text, text, text, text) to service_role;
