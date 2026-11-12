-- Migration: 20261112000100_offline_supervisor_pin_complete.sql
-- F-06: Complete offline supervisor PIN override parity across close_day, service float moves,
--       service txn voids, and action/ref_id binding in consume_supervisor_approval.

-- 1. Tighten consume_supervisor_approval offline action / ref_id binding when provided
create or replace function public.consume_supervisor_approval(
  p_location_id      uuid,
  p_action           text,
  p_ref_id           uuid,
  p_approval_id      uuid,
  p_op_id            uuid,
  p_offline_approval jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  a             public.supervisor_approvals;
  v_approver    uuid;
  v_approved_at timestamptz;
  v_off_action  text;
  v_off_ref_txt text;
  v_off_ref     uuid;
  v_tenant      uuid := public.auth_tenant_id();
  v_hash        text;
begin
  -- Path A: Online approval token
  if p_approval_id is not null then
    select * into a from public.supervisor_approvals x
    where x.id = p_approval_id and x.tenant_id = v_tenant
    for update;

    if not found or a.requested_by is distinct from auth.uid() or a.location_id is distinct from p_location_id
       or a.action is distinct from p_action or a.ref_id is distinct from p_ref_id
       or not public.is_store_approver(a.approved_by, p_location_id) then
      raise exception 'approval does not match' using errcode = '42501', hint = 'approval_invalid';
    end if;

    if a.used_at is not null then
      raise exception 'approval already used' using errcode = '42501', hint = 'approval_used';
    end if;

    if a.expires_at <= now() then
      raise exception 'approval expired' using errcode = '42501', hint = 'approval_expired';
    end if;

    update public.supervisor_approvals set used_at = now(), used_op_id = p_op_id where id = a.id;
    return a.approved_by;
  end if;

  -- Path B: Offline supervisor override validated on sync
  if p_offline_approval is not null and jsonb_typeof(p_offline_approval) = 'object' then
    begin
      v_approver := (p_offline_approval ->> 'approver_id')::uuid;
      v_approved_at := coalesce((p_offline_approval ->> 'approved_at')::timestamptz, now());
    exception when others then
      raise exception 'invalid offline approval' using errcode = '22023', hint = 'approval_invalid';
    end;

    if v_approver is null then
      raise exception 'missing approver' using errcode = '22023', hint = 'approval_invalid';
    end if;

    -- Optional client-bound action and ref_id checks prevent cross-action / cross-entity replay
    v_off_action := nullif(btrim(p_offline_approval ->> 'action'), '');
    if v_off_action is not null and v_off_action is distinct from p_action then
      raise exception 'offline approval action mismatch' using errcode = '42501', hint = 'approval_invalid';
    end if;

    v_off_ref_txt := nullif(btrim(p_offline_approval ->> 'ref_id'), '');
    if v_off_ref_txt is not null then
      begin
        v_off_ref := v_off_ref_txt::uuid;
      exception when others then
        raise exception 'offline approval ref_id invalid' using errcode = '22023', hint = 'approval_invalid';
      end;
      if v_off_ref is distinct from p_ref_id then
        raise exception 'offline approval ref_id mismatch' using errcode = '42501', hint = 'approval_invalid';
      end if;
    end if;

    -- Approver must exist, be active in this tenant, and have a configured PIN
    select p.pin_hash into v_hash from public.profiles p
    where p.user_id = v_approver and p.tenant_id = v_tenant and p.active = true and p.deleted_at is null;

    if v_hash is null then
      raise exception 'approver has no active PIN or is inactive' using errcode = '42501', hint = 'approval_invalid';
    end if;

    -- Approver must have supervisor/manager/owner authority for this location
    if not public.is_store_approver(v_approver, p_location_id) then
      raise exception 'approver not authorized for this location' using errcode = '42501', hint = 'approval_invalid';
    end if;

    -- Approver PIN must not be locked out (5 failed attempts within 15 min)
    if (select count(*) from public.audit_log l
        where l.tenant_id = v_tenant and l.action = 'pin.failed' and l.entity = 'profile' and l.entity_id = v_approver
          and l.created_at > now() - interval '15 minutes') >= 5 then
      raise exception 'approver PIN is locked' using errcode = '42501', hint = 'pin_locked';
    end if;

    -- Timestamp sanity: not in the future by > 10 min, not older than 7 days
    if v_approved_at > now() + interval '10 minutes' or v_approved_at < now() - interval '7 days' then
      raise exception 'offline approval timestamp expired or invalid' using errcode = '42501', hint = 'approval_expired';
    end if;

    -- Audit offline supervisor override
    perform public.write_audit(
      'approval.offline',
      'supervisor_approval',
      v_approver,
      p_location_id,
      jsonb_build_object(
        'action', p_action,
        'ref_id', p_ref_id,
        'op_id', p_op_id,
        'approved_at', v_approved_at,
        'requester_id', auth.uid()
      )
    );

    return v_approver;
  end if;

  raise exception 'a supervisor approval is required' using errcode = '42501', hint = 'approval_required';
end;
$$;

revoke execute on function public.consume_supervisor_approval(uuid, text, uuid, uuid, uuid, jsonb) from public, anon, authenticated;

-- 2. Update op_close_day to pass p -> 'offline_approval' to authorize_expense_write
create or replace function public.op_close_day(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_replay   jsonb;
  v_loc      uuid;
  v_id       uuid;
  v_day      date;
  v_tz       text;
  v_exp_txt  text;
  v_cnt_txt  text;
  v_open_txt text;
  v_exp      bigint;
  v_cnt      bigint;
  v_open     bigint;
  v_base     text;
  v_ccy      text;
  v_closed   timestamptz;
  v_note     text;
  v_appr     uuid;
  v_server   bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin') then
    raise exception 'not allowed to close the day' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'day close must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'close_day');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);

  v_id := (p ->> 'id')::uuid;
  if v_id is null then
    raise exception 'day close id is required' using errcode = '22023', hint = 'id_required';
  end if;

  select coalesce(t.timezone, 'UTC'), t.base_currency into v_tz, v_base from public.tenants t where t.id = v_tenant;
  if coalesce(p ->> 'day', '') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'day must be YYYY-MM-DD' using errcode = '22023', hint = 'invalid_value';
  end if;
  begin
    v_day := (p ->> 'day')::date;
  exception when others then
    raise exception 'day is not a date' using errcode = '22023', hint = 'invalid_value';
  end;
  if v_day > (now() at time zone v_tz)::date + 1 then
    raise exception 'day is in the future' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_exp_txt := p ->> 'expected_cash';
  v_cnt_txt := p ->> 'counted_cash';
  if not coalesce(jsonb_typeof(p -> 'expected_cash') in ('number', 'string') and v_exp_txt ~ '^-?[0-9]{1,15}$', false)
     or not coalesce(jsonb_typeof(p -> 'counted_cash') in ('number', 'string') and v_cnt_txt ~ '^[0-9]{1,15}$', false) then
    raise exception 'cash amounts must be whole centavos' using errcode = '22023', hint = 'amount_invalid';
  end if;
  v_exp := v_exp_txt::bigint;
  v_cnt := v_cnt_txt::bigint;

  if coalesce(jsonb_typeof(p -> 'opening_cash'), 'null') = 'null' then
    v_open := 0;
  else
    v_open_txt := p ->> 'opening_cash';
    if not coalesce(jsonb_typeof(p -> 'opening_cash') in ('number', 'string') and v_open_txt ~ '^[0-9]{1,15}$', false) then
      raise exception 'opening cash must be whole centavos, not below zero' using errcode = '22023', hint = 'amount_invalid';
    end if;
    v_open := v_open_txt::bigint;
  end if;

  v_ccy := coalesce(upper(nullif(btrim(p ->> 'currency'), '')), v_base);
  if v_ccy is distinct from v_base then
    raise exception 'the cash count is in the base currency' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_closed := coalesce((p ->> 'closed_at')::timestamptz, now());
  v_note := left(nullif(btrim(p ->> 'note'), ''), 200);

  v_appr := public.authorize_expense_write(
    v_loc, 'close_day', v_id, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval'
  );
  v_server := v_open + public.day_close_server_expected(v_tenant, v_loc, v_day);

  begin
    insert into public.day_closes (id, tenant_id, location_id, client_op_id, day, currency, opening_cash, expected_cash,
                                   counted_cash, difference, server_expected_cash, note, closed_by, approved_by, closed_at)
    values (v_id, v_tenant, v_loc, p_op_id, v_day, v_ccy, v_open, v_exp, v_cnt, v_cnt - v_exp, v_server, v_note,
            auth.uid(), v_appr, v_closed);
  exception when unique_violation then
    raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  perform public.write_audit('day.close', 'day_close', v_id, v_loc, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_loc, 'day', v_day, 'opening_cash', v_open, 'expected_cash', v_exp, 'counted_cash', v_cnt,
    'difference', v_cnt - v_exp, 'server_expected_cash', v_server, 'op_id', p_op_id, 'approved_by', v_appr)));
  return public.finish_op(p_op_id, jsonb_build_object(
    'day_close_id', v_id, 'day', v_day, 'difference', v_cnt - v_exp, 'opening_cash', v_open,
    'server_expected_cash', v_server, 'approved_by', v_appr, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_close_day(uuid, jsonb) from public, anon, authenticated;

-- 3. Update op_record_service_txn to pass p -> 'offline_approval' to authorize_expense_write
create or replace function public.op_record_service_txn(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_replay   jsonb;
  v_loc      uuid;
  v_id       uuid;
  v_kind     text;
  v_wallet   text;
  v_txt      text;
  v_amt      bigint;
  v_fee      bigint;
  v_price    bigint;
  v_base     text;
  v_ccy      text;
  v_at       timestamptz;
  v_ref      text;
  v_note     text;
  v_appr     uuid;
begin
  perform public.assert_seller();
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'service entry must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'record_service_txn');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);

  v_id := (p ->> 'id')::uuid;
  if v_id is null then
    raise exception 'service entry id is required' using errcode = '22023', hint = 'id_required';
  end if;

  v_kind := p ->> 'kind';
  if v_kind is null or v_kind not in ('cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust') then
    raise exception 'kind is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_wallet := coalesce(nullif(p ->> 'wallet', ''), case when v_kind = 'load' then 'load' end);
  if v_wallet is null or v_wallet not in ('gcash', 'maya', 'load', 'other')
     or (v_kind in ('cash_in', 'cash_out') and v_wallet = 'load') then
    raise exception 'wallet is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_txt := p ->> 'amount';
  if not coalesce(jsonb_typeof(p -> 'amount') in ('number', 'string')
                  and v_txt ~ (case when v_kind = 'float_adjust' then '^-?[0-9]{1,15}$' else '^[0-9]{1,15}$' end), false) then
    raise exception 'amount must be whole centavos' using errcode = '22023', hint = 'amount_invalid';
  end if;
  v_amt := v_txt::bigint;
  if v_amt = 0 then
    raise exception 'amount must not be zero' using errcode = '22023', hint = 'amount_invalid';
  end if;

  if coalesce(jsonb_typeof(p -> 'fee'), 'null') <> 'null' then
    v_txt := p ->> 'fee';
    if not coalesce(jsonb_typeof(p -> 'fee') in ('number', 'string') and v_txt ~ '^[0-9]{1,15}$', false) then
      raise exception 'fee must be whole centavos' using errcode = '22023', hint = 'amount_invalid';
    end if;
    v_fee := v_txt::bigint;
  end if;

  if v_kind = 'load' then
    v_txt := p ->> 'price';
    if not coalesce(jsonb_typeof(p -> 'price') in ('number', 'string') and v_txt ~ '^[0-9]{1,15}$', false) then
      raise exception 'a load needs the price the customer pays' using errcode = '22023', hint = 'amount_invalid';
    end if;
    v_price := v_txt::bigint;
    if v_price < v_amt or (v_fee is not null and v_fee <> v_price - v_amt) then
      raise exception 'load price must cover the amount; fee = price - amount' using errcode = '22023', hint = 'amount_invalid';
    end if;
    v_fee := v_price - v_amt;
  else
    if coalesce(jsonb_typeof(p -> 'price'), 'null') <> 'null' then
      raise exception 'only a load has a price' using errcode = '22023', hint = 'invalid_value';
    end if;
    if v_kind in ('float_topup', 'float_withdraw', 'float_adjust') and coalesce(v_fee, 0) <> 0 then
      raise exception 'moving float has no fee' using errcode = '22023', hint = 'amount_invalid';
    end if;
    v_fee := coalesce(v_fee, 0);
  end if;

  select t.base_currency into v_base from public.tenants t where t.id = v_tenant;
  v_ccy := coalesce(upper(nullif(btrim(p ->> 'currency'), '')), v_base);
  if v_ccy is distinct from v_base then
    raise exception 'service entries are in the base currency' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_at := coalesce((p ->> 'txn_at')::timestamptz, now());
  v_ref := left(nullif(btrim(p ->> 'ref'), ''), 200);
  v_note := left(nullif(btrim(p ->> 'note'), ''), 200);
  if v_kind = 'float_adjust' and v_note is null then
    raise exception 'a float correction needs a note' using errcode = '22023', hint = 'note_required';
  end if;

  if v_kind = 'float_adjust' then
    if not public.is_store_manager_or_owner(v_loc) then
      raise exception 'only the owner or the store manager corrects a float' using errcode = '42501', hint = 'not_allowed';
    end if;
  elsif v_kind in ('float_topup', 'float_withdraw') then
    v_appr := public.authorize_expense_write(
      v_loc, 'record_service_txn', v_id, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval'
    );
  end if;

  begin
    insert into public.service_txns (id, tenant_id, location_id, client_op_id, kind, wallet, amount, fee, price, currency,
                                     ref, note, txn_at, created_by, approved_by)
    values (v_id, v_tenant, v_loc, p_op_id, v_kind, v_wallet, v_amt, v_fee, v_price, v_ccy,
            v_ref, v_note, v_at, auth.uid(), v_appr);
  exception when unique_violation then
    raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  perform public.write_audit('service.record', 'service_txn', v_id, v_loc, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_loc, 'kind', v_kind, 'wallet', v_wallet, 'amount', v_amt, 'fee', v_fee,
    'op_id', p_op_id, 'approved_by', v_appr)));
  return public.finish_op(p_op_id, jsonb_build_object(
    'txn_id', v_id, 'kind', v_kind, 'fee', v_fee, 'approved_by', v_appr, 'applied_at', now()));
end;
$$;

-- 4. Update op_void_service_txn to pass p -> 'offline_approval' to authorize_expense_write
create or replace function public.op_void_service_txn(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_tid    uuid;
  v_txn    public.service_txns;
  v_appr   uuid;
  v_reason text;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin') then
    raise exception 'not allowed to void service entries' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'void must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'void_service_txn');
  if v_replay is not null then
    return v_replay;
  end if;

  v_tid := (p ->> 'txn_id')::uuid;
  select * into v_txn from public.service_txns where id = v_tid and tenant_id = v_tenant for update;
  if not found then
    raise exception 'service entry not found' using errcode = '22023', hint = 'txn_not_found';
  end if;
  if v_txn.kind = 'float_adjust' and not public.is_store_manager_or_owner(v_txn.location_id) then
    raise exception 'only the owner or the store manager voids a float correction' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_appr := public.authorize_expense_write(
    v_txn.location_id, 'void_service_txn', v_tid, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval'
  );

  if v_txn.voided_at is not null then
    return public.finish_op(p_op_id, jsonb_build_object('txn_id', v_tid, 'already', true, 'approved_by', v_appr,
                                                        'applied_at', now()));
  end if;

  v_reason := left(nullif(btrim(p ->> 'reason'), ''), 200);
  update public.service_txns
     set voided_at = now(), void_reason = v_reason, void_approved_by = v_appr
   where id = v_tid and tenant_id = v_tenant;

  perform public.write_audit('service.void', 'service_txn', v_tid, v_txn.location_id, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_txn.location_id, 'kind', v_txn.kind, 'wallet', v_txn.wallet, 'amount', v_txn.amount, 'fee', v_txn.fee,
    'reason', v_reason, 'op_id', p_op_id, 'approved_by', v_appr)));
  return public.finish_op(p_op_id, jsonb_build_object('txn_id', v_tid, 'already', false, 'approved_by', v_appr,
                                                      'applied_at', now()));
end;
$$;

revoke execute on function public.op_record_service_txn(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_void_service_txn(uuid, jsonb) from public, anon, authenticated;
