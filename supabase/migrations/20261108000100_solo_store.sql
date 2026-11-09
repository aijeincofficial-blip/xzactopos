-- S-01 Solo mode: one call turns a signed-in user with no business into the owner of a one-store tenant.
-- Additive. Reuses the same tables and rules as provision_tenant / complete_setup; changes no existing object.

create or replace function public.provision_solo_store(
  p_tenant_id   uuid,
  p_location_id uuid,
  p_store_name  text,
  p_locale      text default 'fil'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user     uuid := auth.uid();
  v_email    text;
  v_username text;
  v_name     text := btrim(coalesce(p_store_name, ''));
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if length(v_name) not between 1 and 120 then
    raise exception 'store name must be 1 to 120 characters' using errcode = '22023';
  end if;
  if p_locale not in ('en', 'fil') then
    raise exception 'unsupported locale' using errcode = '22023';
  end if;
  if p_tenant_id is null or p_location_id is null then
    raise exception 'ids are required' using errcode = '22023';
  end if;

  -- one business per user; serialize concurrent double taps for the same user
  perform pg_advisory_xact_lock(hashtextextended('solo:' || v_user::text, 0));
  if exists (select 1 from public.profiles p where p.user_id = v_user) then
    raise exception 'user already belongs to a business' using errcode = 'P0001', hint = 'user_has_tenant';
  end if;

  select u.email into v_email from auth.users u where u.id = v_user;
  v_username := lower(regexp_replace(split_part(coalesce(v_email, ''), '@', 1), '[^a-z0-9._-]', '', 'gi'));
  v_username := regexp_replace(v_username, '^[^a-z0-9]+|[^a-z0-9]+$', '', 'g');
  if v_username !~ '^[a-z0-9][a-z0-9._-]{1,38}[a-z0-9]$' then
    v_username := 'owner';
  end if;

  insert into public.tenants (id, name, slug, base_currency, timezone, setup_completed_at)
    values (p_tenant_id, v_name, 'solo-' || substr(replace(p_tenant_id::text, '-', ''), 21, 12),
            'PHP', 'Asia/Manila', now());
  -- inventory is always on; POS on for selling; warehouse off (turn on later in Settings)
  insert into public.tenant_modules (tenant_id, inventory, pos, warehouse) values (p_tenant_id, true, true, false);
  insert into public.tenant_settings (tenant_id, default_locale, locales)
    values (p_tenant_id, p_locale, array['fil', 'en']::text[]);
  insert into public.tenant_limits (tenant_id) values (p_tenant_id);
  insert into public.profiles (user_id, tenant_id, username, role, locale)
    values (v_user, p_tenant_id, v_username, 'superadmin', p_locale);
  insert into public.locations (id, tenant_id, type, code, name)
    values (p_location_id, p_tenant_id, 'store', 'MAIN', v_name);

  perform public.write_audit('tenant.provision_solo', 'tenant', p_tenant_id, p_location_id,
    jsonb_build_object('owner', v_user, 'locale', p_locale), p_tenant_id);

  return p_tenant_id;
end;
$$;

revoke execute on function public.provision_solo_store(uuid, uuid, text, text) from public, anon;
grant execute on function public.provision_solo_store(uuid, uuid, text, text) to authenticated;
