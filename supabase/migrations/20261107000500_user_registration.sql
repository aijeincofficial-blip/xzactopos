-- P1-06 User registration for the create_user / invite_user Edge Functions.
-- Plan: docs/plan.md sections 5 and 15.
--
-- The Edge Function verifies the caller's JWT, creates the auth user with the service role, then calls
-- admin_register_user() with the verified caller id. All authorization lives here, so the rules sit
-- next to the other admin RPCs: the function only trusts the caller id, never the request body.
-- On any error the Edge Function deletes the auth user it just created.

create or replace function public.admin_register_user(
  p_caller     uuid,
  p_user       uuid,
  p_username   text,
  p_full_name  text,
  p_role       text,
  p_locale     text default null,
  p_location   uuid default null,
  p_position   text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller public.profiles;
  v_status text;
  v_count  int;
  v_max    int;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'service role only' using errcode = '42501', hint = 'service_only';
  end if;

  select * into v_caller
  from public.profiles p
  where p.user_id = p_caller and p.active and p.deleted_at is null;
  if not found then
    raise exception 'caller is not an active user' using errcode = '42501', hint = 'no_account';
  end if;

  select t.status into v_status
  from public.tenants t
  where t.id = v_caller.tenant_id and t.deleted_at is null;
  if v_status is distinct from 'active' then
    raise exception 'tenant is %', coalesce(v_status, 'missing') using errcode = '42501', hint = 'tenant_' || coalesce(v_status, 'missing');
  end if;

  if p_role not in ('superadmin', 'admin', 'warehouse', 'cashier') then
    raise exception 'unknown role: %', p_role using errcode = '22023';
  end if;

  if p_location is not null and not exists (
    select 1 from public.locations l
    where l.id = p_location and l.tenant_id = v_caller.tenant_id and l.deleted_at is null
  ) then
    raise exception 'location not found' using errcode = '42501', hint = 'location_not_found';
  end if;

  -- superadmin: any role. manager: cashiers only, placed in a store they manage, no position.
  if not (
    v_caller.role = 'superadmin'
    or (
      v_caller.role = 'admin'
      and p_role = 'cashier'
      and p_location is not null
      and p_position is null
      and exists (
        select 1 from public.location_access la
        where la.user_id = p_caller
          and la.location_id = p_location
          and la.position = 'manager'
          and la.deleted_at is null
      )
    )
  ) then
    raise exception 'not allowed to create this user' using errcode = '42501', hint = 'create_denied';
  end if;

  -- serialize concurrent creations in one tenant so the user limit holds
  perform 1 from public.tenant_limits tl where tl.tenant_id = v_caller.tenant_id for update;

  select count(*) into v_count from public.profiles p where p.tenant_id = v_caller.tenant_id and p.deleted_at is null;
  select tl.max_users into v_max from public.tenant_limits tl where tl.tenant_id = v_caller.tenant_id;
  if v_max is not null and v_count >= v_max then
    raise exception 'user limit reached (%)', v_max using errcode = 'P0001', hint = 'limit_users';
  end if;

  insert into public.profiles (user_id, tenant_id, username, full_name, role, locale)
    values (p_user, v_caller.tenant_id, p_username, coalesce(p_full_name, ''), p_role, p_locale);

  if p_location is not null then
    -- the location_access trigger enforces role / location type / position
    insert into public.location_access (user_id, location_id, tenant_id, position)
      values (p_user, p_location, v_caller.tenant_id, p_position);
  end if;

  insert into public.audit_log (tenant_id, user_id, action, entity, entity_id, location_id, meta)
    values (v_caller.tenant_id, p_caller, 'user.create', 'profile', p_user, p_location,
            jsonb_build_object('role', p_role, 'username', p_username, 'position', p_position));

  return v_caller.tenant_id;
end;
$$;

revoke execute on function public.admin_register_user(uuid, uuid, text, text, text, text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_register_user(uuid, uuid, text, text, text, text, uuid, text)
  to service_role;

-- Login needs no lookup function: cashiers sign in as <username>.<slug>@pos.invalid (built on the client),
-- invited users sign in with their own email. No anon-callable function means no account enumeration.
