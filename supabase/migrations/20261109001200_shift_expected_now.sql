-- F-05m: shift_expected_now(shift): the server's own expected cash for a shift right now.
-- The phone works out an expected figure from what it holds, but it cannot tell another cashier's entries from this one's. While
-- the phone is online at closing time it asks here and shows the server's figure; offline it uses its own and the server stores
-- both when the close arrives (see op_close_shift). Read only.
-- Who: the shift's own cashier; an admin or the owner for the shifts of their stores. For an open shift the window runs up to now.

create or replace function public.shift_expected_now(p_shift_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_s      record;
begin
  perform public.assert_active_user();
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  perform public.assert_module('pos');
  select s.* into v_s from public.shifts s where s.id = p_shift_id and s.tenant_id = v_tenant;
  if not found then
    raise exception 'shift not found' using errcode = '22023', hint = 'shift_not_found';
  end if;
  if v_s.cashier_id is distinct from auth.uid() then
    if public.auth_role() not in ('superadmin', 'admin') then
      raise exception 'not your shift' using errcode = '42501', hint = 'not_allowed';
    end if;
    perform public.assert_location_access(v_s.location_id);
  end if;
  return jsonb_build_object(
    'shift_id', v_s.id,
    'server_expected_cash', public.shift_server_expected(v_tenant, v_s.location_id, v_s.cashier_id, v_s.opened_at,
                                                         coalesce(v_s.closed_at, now()), v_s.opening_cash),
    'as_of', now());
end;
$$;

revoke execute on function public.shift_expected_now(uuid) from public, anon;
grant execute on function public.shift_expected_now(uuid) to authenticated;
