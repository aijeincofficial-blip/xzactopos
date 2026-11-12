-- Expose receipt_header, receipt_footer (from tenant_settings) and store address (from locations)
-- in public.get_my_access() so Web and Mobile POS receipts render custom headers, footers, and
-- branch addresses both online and offline without extra round-trips.

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
      'setup_completed', t.setup_completed_at is not null,
      'mode', coalesce(s.mode, 'solo'),
      'receipt_header', s.receipt_header,
      'receipt_footer', s.receipt_footer),
    'modules', jsonb_build_object(
      'inventory', coalesce(m.inventory, false),
      'pos', coalesce(m.pos, false),
      'warehouse', coalesce(m.warehouse, false)),
    'locations', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id, 'type', l.type, 'code', l.code, 'name', l.name,
               'address', l.address,
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
