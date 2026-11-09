-- P8-14 Opening cash (sukli) in the day close.
--   A store keeps coins and bills in the drawer overnight. Expected cash at the close was only the day's cash flow, so a day
--   with only an expense showed a negative expected cash and the over/short was off by the opening amount.
--   day_closes.opening_cash   the cash the day started with (centavos >= 0, default 0), set only when the close is written.
--   op_close_day              re-created (from 20261108001300): optional `opening_cash`; server_expected_cash is now
--                             opening_cash + day_close_server_expected(...) (the day's cash flow, unchanged). The client's
--                             expected_cash includes the opening cash; difference = counted - expected stays as it was.
--   guard_day_close_change    re-created: opening_cash is append-only like every other column.
--   sync_pull_day_closes      re-created: rows carry opening_cash (additive).
-- The default opening cash (the counted cash of the latest earlier close) is a client suggestion only: the server stores the
-- figure the client sent and never derives it, so a close queued offline keeps the opening the tindera saw.
-- Closes sent without opening_cash behave exactly as before (opening 0). sync_push is unchanged (it calls op_close_day).

alter table public.day_closes
  add column opening_cash bigint not null default 0 check (opening_cash >= 0);

comment on column public.day_closes.opening_cash is
  'Cash in the drawer when the day started (sukli), base-currency minor units. Included in expected_cash and server_expected_cash.';

-- ---------------------------------------------------------------------------
-- guard_day_close_change re-created (from 20261108001300) with opening_cash in the frozen columns
-- ---------------------------------------------------------------------------

create or replace function public.guard_day_close_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'day_closes is append-only' using errcode = '55000', hint = 'append_only';
  end if;
  if (new.id, new.tenant_id, new.location_id, new.client_op_id, new.day, new.currency, new.expected_cash,
      new.counted_cash, new.difference, new.server_expected_cash, new.note, new.closed_at, new.created_at, new.deleted_at,
      new.opening_cash)
     is distinct from
     (old.id, old.tenant_id, old.location_id, old.client_op_id, old.day, old.currency, old.expected_cash,
      old.counted_cash, old.difference, old.server_expected_cash, old.note, old.closed_at, old.created_at, old.deleted_at,
      old.opening_cash)
     or (new.closed_by is distinct from old.closed_by and new.closed_by is not null)
     or (new.approved_by is distinct from old.approved_by and new.approved_by is not null) then
    raise exception 'day_closes is append-only' using errcode = '55000', hint = 'append_only';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_day_close_change() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_close_day re-created (from 20261108001300)
--   p = { id, day: 'YYYY-MM-DD', expected_cash, counted_cash, opening_cash?, note?, closed_at?, currency?, location_id?,
--         approval_id? }
--   opening_cash: whole centavos >= 0 (number or digit string); absent or null = 0. Anything else: hint amount_invalid.
--   expected_cash (client) INCLUDES the opening cash; server_expected_cash = opening_cash + the server's day cash flow.
--   Returns { day_close_id, day, difference, opening_cash, server_expected_cash, approved_by, applied_at }.
--   Everything else (who may close, approvals, day and amount rules, replay) is unchanged.
-- ---------------------------------------------------------------------------

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

  -- whole centavos only: a JSON number or digit string, no fraction, no exponent; expected may carry a minus sign
  v_exp_txt := p ->> 'expected_cash';
  v_cnt_txt := p ->> 'counted_cash';
  if not coalesce(jsonb_typeof(p -> 'expected_cash') in ('number', 'string') and v_exp_txt ~ '^-?[0-9]{1,15}$', false)
     or not coalesce(jsonb_typeof(p -> 'counted_cash') in ('number', 'string') and v_cnt_txt ~ '^[0-9]{1,15}$', false) then
    raise exception 'cash amounts must be whole centavos' using errcode = '22023', hint = 'amount_invalid';
  end if;
  v_exp := v_exp_txt::bigint;
  v_cnt := v_cnt_txt::bigint;

  -- opening cash: optional, whole centavos >= 0 (absent or JSON null = 0)
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

  v_appr := public.authorize_expense_write(v_loc, 'close_day', v_id, (p ->> 'approval_id')::uuid, p_op_id);
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

-- ---------------------------------------------------------------------------
-- sync_pull_day_closes re-created (from 20261108001300); the only change: rows carry opening_cash.
--   Returns { rows: [ { id, location_id, day, currency, opening_cash, expected_cash, counted_cash, difference,
--                       server_expected_cash, note, closed_by, approved_by, closed_at, updated_at } ], cursor, has_more,
--             server_time }.
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_day_closes(p_cursor jsonb default null, p_limit int default 100)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_upto   timestamptz := now() - interval '5 seconds';
  v_ts     timestamptz := nullif(p_cursor ->> 'ts', '')::timestamptz;
  v_k      text := p_cursor ->> 'k';
  v_rows   jsonb;
  v_last   jsonb;
  v_more   boolean;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.id, x.location_id, x.day, x.currency, x.opening_cash, x.expected_cash, x.counted_cash, x.difference,
           x.server_expected_cash, x.note, x.closed_by, x.approved_by, x.closed_at, x.updated_at
    from public.day_closes x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and (v_ts is null and x.closed_at >= now() - interval '30 days'
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'day', g.day, 'currency', g.currency,
        'opening_cash', g.opening_cash, 'expected_cash', g.expected_cash, 'counted_cash', g.counted_cash,
        'difference', g.difference, 'server_expected_cash', g.server_expected_cash, 'note', g.note,
        'closed_by', g.closed_by, 'approved_by', g.approved_by, 'closed_at', g.closed_at, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$$;

revoke execute on function public.sync_pull_day_closes(jsonb, int) from public, anon;
grant execute on function public.sync_pull_day_closes(jsonb, int) to authenticated;
