-- Migration: 20261108002900_platform_admin.sql
-- Description: Platform administration RPCs for platform operators (metrics, tenant listing, status changes, plan upgrades)

-- ---------------------------------------------------------------------------
-- 1. Helper: assert_platform_admin
-- ---------------------------------------------------------------------------

create or replace function public.assert_platform_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (coalesce(auth.role(), '') = 'service_role' or public.is_platform_admin()) then
    raise exception 'platform operator only' using errcode = '42501', hint = 'platform_only';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Update get_my_access to include is_platform_admin
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
    'is_platform_admin', public.is_platform_admin(),
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
-- 3. get_platform_metrics
-- ---------------------------------------------------------------------------

create or replace function public.get_platform_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_storage jsonb;
  v_res     jsonb;
begin
  perform public.assert_platform_admin();

  select public.get_storage_metrics() into v_storage;

  select jsonb_build_object(
    'total_tenants', (select count(*)::int from public.tenants where deleted_at is null),
    'active_tenants', (select count(*)::int from public.tenants where status = 'active' and deleted_at is null),
    'suspended_tenants', (select count(*)::int from public.tenants where status = 'suspended' and deleted_at is null),
    'pro_tenants', (select count(*)::int from public.tenants where plan = 'pro' and deleted_at is null),
    'total_users', (select count(*)::int from public.profiles where deleted_at is null),
    'total_sales_count', (select count(*)::int from public.sales where voided_at is null),
    'total_gross_sales', (select coalesce(sum(total), 0)::bigint from public.sales where voided_at is null),
    'storage', v_storage
  ) into v_res;

  return v_res;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. list_platform_tenants
-- ---------------------------------------------------------------------------

create or replace function public.list_platform_tenants(p_search text default null, p_status text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_res jsonb;
begin
  perform public.assert_platform_admin();

  with tenant_stats as (
    select
      t.id,
      t.name,
      t.slug,
      t.status,
      t.plan,
      t.base_currency,
      t.timezone,
      t.created_at,
      (t.setup_completed_at is not null) as setup_completed,
      coalesce(tl.max_locations, 25) as max_locations,
      coalesce(tl.max_users, 100) as max_users,
      coalesce(tl.max_devices, 50) as max_devices,
      coalesce(tl.max_products, 10000) as max_products,
      (select count(*)::int from public.profiles p where p.tenant_id = t.id and p.deleted_at is null) as user_count,
      (select count(*)::int from public.locations l where l.tenant_id = t.id and l.type = 'store' and l.deleted_at is null) as store_count,
      (select count(*)::int from public.locations l where l.tenant_id = t.id and l.type = 'warehouse' and l.deleted_at is null) as warehouse_count,
      (select count(*)::int from public.sales s where s.tenant_id = t.id and s.voided_at is null) as sales_count,
      (select coalesce(sum(s.total), 0)::bigint from public.sales s where s.tenant_id = t.id and s.voided_at is null) as gross_sales
    from public.tenants t
    left join public.tenant_limits tl on tl.tenant_id = t.id
    where t.deleted_at is null
      and (p_status is null or t.status = p_status)
      and (
        p_search is null
        or btrim(p_search) = ''
        or t.name ilike ('%' || btrim(p_search) || '%')
        or t.slug ilike ('%' || btrim(p_search) || '%')
      )
    order by t.created_at desc
  )
  select coalesce(jsonb_agg(to_jsonb(ts)), '[]'::jsonb)
  into v_res
  from tenant_stats ts;

  return v_res;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. set_platform_tenant_status
-- ---------------------------------------------------------------------------

create or replace function public.set_platform_tenant_status(
  p_tenant_id uuid,
  p_status    text,
  p_reason    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_status text;
  v_t          public.tenants;
begin
  perform public.assert_platform_admin();

  if p_status not in ('active', 'suspended', 'archived') then
    raise exception 'invalid status: %', p_status using errcode = '22023', hint = 'invalid_status';
  end if;

  select * into v_t from public.tenants where id = p_tenant_id and deleted_at is null for update;
  if not found then
    raise exception 'tenant not found' using errcode = '22023', hint = 'tenant_not_found';
  end if;

  v_old_status := v_t.status;
  if v_old_status is distinct from p_status then
    update public.tenants
    set status = p_status,
        updated_at = now()
    where id = p_tenant_id;

    perform public.write_audit(
      'platform.tenant_status',
      'tenant',
      p_tenant_id,
      null,
      jsonb_build_object(
        'status', p_status,
        'old_status', v_old_status,
        'reason', coalesce(p_reason, '')
      ),
      p_tenant_id
    );
  end if;

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'status', p_status,
    'old_status', v_old_status
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. set_platform_tenant_plan
-- ---------------------------------------------------------------------------

create or replace function public.set_platform_tenant_plan(
  p_tenant_id uuid,
  p_plan      text,
  p_limits    jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_plan text;
  v_t        public.tenants;
  v_locs     int;
  v_users    int;
  v_devices  int;
  v_products int;
begin
  perform public.assert_platform_admin();

  if p_plan not in ('free', 'pro') then
    raise exception 'invalid plan: %', p_plan using errcode = '22023', hint = 'invalid_plan';
  end if;

  select * into v_t from public.tenants where id = p_tenant_id and deleted_at is null for update;
  if not found then
    raise exception 'tenant not found' using errcode = '22023', hint = 'tenant_not_found';
  end if;

  v_old_plan := v_t.plan;

  update public.tenants
  set plan = p_plan,
      updated_at = now()
  where id = p_tenant_id;

  if p_limits is not null and jsonb_typeof(p_limits) = 'object' then
    v_locs := (p_limits ->> 'max_locations')::int;
    v_users := (p_limits ->> 'max_users')::int;
    v_devices := (p_limits ->> 'max_devices')::int;
    v_products := (p_limits ->> 'max_products')::int;

    update public.tenant_limits
    set max_locations = coalesce(v_locs, max_locations),
        max_users = coalesce(v_users, max_users),
        max_devices = coalesce(v_devices, max_devices),
        max_products = coalesce(v_products, max_products),
        updated_at = now()
    where tenant_id = p_tenant_id;
  end if;

  perform public.write_audit(
    'platform.tenant_plan',
    'tenant',
    p_tenant_id,
    null,
    jsonb_build_object(
      'plan', p_plan,
      'old_plan', v_old_plan,
      'limits', coalesce(p_limits, '{}'::jsonb)
    ),
    p_tenant_id
  );

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'plan', p_plan,
    'old_plan', v_old_plan
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Grants
-- ---------------------------------------------------------------------------

grant execute on function public.provision_tenant(text, text, text, uuid, text, text, text, text) to authenticated;

revoke all on function public.assert_platform_admin() from public, anon;
grant execute on function public.assert_platform_admin() to authenticated;

revoke all on function public.get_platform_metrics() from public, anon;
grant execute on function public.get_platform_metrics() to authenticated;

revoke all on function public.list_platform_tenants(text, text) from public, anon;
grant execute on function public.list_platform_tenants(text, text) to authenticated;

revoke all on function public.set_platform_tenant_status(uuid, text, text) from public, anon;
grant execute on function public.set_platform_tenant_status(uuid, text, text) to authenticated;

revoke all on function public.set_platform_tenant_plan(uuid, text, jsonb) from public, anon;
grant execute on function public.set_platform_tenant_plan(uuid, text, jsonb) to authenticated;
