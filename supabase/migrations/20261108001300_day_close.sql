-- P8-02c Day close (cash count at the end of the day).
--   day_closes              append-only count entry: what the app expected in the drawer, what was counted, the difference.
--                           Several closes for one store and day are allowed (a re-count); the newest closed_at wins in the UI.
--   op_close_day            through sync_push, idempotent by op id. The server recomputes nothing the client sent: it stores
--                           the client's expected / counted cash, and ALSO stores server_expected_cash computed from the
--                           server's own data for that day, so a mismatch is visible (never an error).
--   sync_pull_day_closes    keyset delta pull, same shape and rules as sync_pull_expenses.
-- Who may close: the owner (superadmin), an admin who is manager of the store, or a store supervisor with a single-use
-- supervisor approval (action 'close_day', ref_id = the day close id) exactly like expenses. Cashiers and warehouse never.
-- Reads: superadmin and admins of the store (same as expenses). Nobody writes from a client.
--
-- server_expected_cash for (store, day in the tenant timezone):
--     cash payments of completed sales at the store sold that day
--   + utang payments (customer_ledger kind 'payment') that day        -- see the note below
--   - cash expenses at the store spent that day that are not voided
-- Note: utang payments carry no store on the server (customer_ledger has no location_id, P3-01) and are always cash, so they
-- are counted for the whole tenant. Exact for the solo store; with more than one store each store's figure includes every
-- payment of the day until the ledger records a store.

-- ---------------------------------------------------------------------------
-- Approvals: 'close_day' joins the actions a supervisor approval can cover
-- ---------------------------------------------------------------------------

alter table public.supervisor_approvals drop constraint supervisor_approvals_action_check;
alter table public.supervisor_approvals add constraint supervisor_approvals_action_check
  check (action in ('record_expense', 'void_expense', 'close_day'));

-- approve_supervisor_action re-created (from 20261108001200); the only change is the 'close_day' action
-- (its ref_id is the day close id the client made; the store is p_location_id or the caller's only store).
create or replace function public.approve_supervisor_action(
  p_action      text,
  p_ref_id      uuid,
  p_pin         text,
  p_location_id uuid default null,
  p_approver_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_loc      uuid;
  v_approver uuid;
  v_try      text;
  v_id       uuid;
  v_exp      timestamptz;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  v_tenant := public.auth_tenant_id();
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin') then
    raise exception 'not allowed to ask for approvals' using errcode = '42501', hint = 'not_allowed';
  end if;
  if p_action is null or p_action not in ('record_expense', 'void_expense', 'close_day') or p_ref_id is null then
    raise exception 'action and reference are required' using errcode = '22023', hint = 'invalid_value';
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{4,8}$' then
    return jsonb_build_object('ok', false, 'hint', 'pin_wrong');
  end if;

  if p_action = 'void_expense' then
    select e.location_id into v_loc from public.expenses e where e.id = p_ref_id and e.tenant_id = v_tenant;
  end if;
  if v_loc is null then
    v_loc := public.resolve_store(p_location_id);
  end if;
  if not public.has_location_access(v_loc, 'supervisor') then
    raise exception 'not a supervisor of this store' using errcode = '42501', hint = 'not_allowed';
  end if;

  v_approver := coalesce(p_approver_id, auth.uid());
  if not public.is_store_approver(v_approver, v_loc) then
    raise exception 'this person cannot approve here' using errcode = '42501', hint = 'approver_invalid';
  end if;

  v_try := public.pin_attempt(v_approver, p_pin, v_loc);
  if v_try = 'locked' then
    return jsonb_build_object('ok', false, 'hint', 'pin_locked');
  elsif v_try = 'not_set' then
    return jsonb_build_object('ok', false, 'hint', 'pin_not_set');
  elsif v_try <> 'ok' then
    return jsonb_build_object('ok', false, 'hint', 'pin_wrong');
  end if;

  v_exp := now() + interval '12 hours';
  insert into public.supervisor_approvals (tenant_id, location_id, action, ref_id, requested_by, approved_by, expires_at)
  values (v_tenant, v_loc, p_action, p_ref_id, auth.uid(), v_approver, v_exp)
  returning id into v_id;

  perform public.write_audit('approval.grant', 'approval', v_id, v_loc,
    jsonb_build_object('action', p_action, 'ref_id', p_ref_id, 'approved_by', v_approver));
  return jsonb_build_object('ok', true, 'approval_id', v_id, 'approved_by', v_approver, 'expires_at', v_exp);
end;
$$;

revoke execute on function public.approve_supervisor_action(text, uuid, text, uuid, uuid) from public, anon;
grant execute on function public.approve_supervisor_action(text, uuid, text, uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table public.day_closes (
  id                    uuid primary key,
  tenant_id             uuid not null references public.tenants (id) on delete cascade,
  location_id           uuid not null,
  client_op_id          uuid not null,
  -- the business day in the tenant timezone (same convention as daily_sales_summary.day)
  day                   date not null,
  currency              char(3) not null references public.currencies (code),
  -- base-currency minor units (centavos). expected may be below zero (more cash paid out than taken in that day)
  expected_cash         bigint not null,
  counted_cash          bigint not null check (counted_cash >= 0),
  difference            bigint not null,
  server_expected_cash  bigint not null,
  note                  text check (length(note) <= 200),
  closed_by             uuid references auth.users (id) on delete set null,
  approved_by           uuid references auth.users (id) on delete set null,
  closed_at             timestamptz not null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz,
  constraint day_closes_tenant_id unique (tenant_id, id),
  constraint day_closes_client_op_per_tenant unique (tenant_id, client_op_id),
  constraint day_closes_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint day_closes_difference check (difference = counted_cash - expected_cash)
);

comment on table public.day_closes is
  'Append-only cash counts. Written only by op_close_day; never edited. Several per store and day = re-counts (newest wins).';

create index day_closes_tenant_day_idx     on public.day_closes (tenant_id, location_id, day, closed_at desc);
create index day_closes_tenant_updated_idx on public.day_closes (tenant_id, updated_at, id);

create trigger day_closes_set_updated_at before update on public.day_closes
  for each row execute function public.set_updated_at();

-- Rows never change, except closed_by / approved_by going to null when that user is removed.
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
      new.counted_cash, new.difference, new.server_expected_cash, new.note, new.closed_at, new.created_at, new.deleted_at)
     is distinct from
     (old.id, old.tenant_id, old.location_id, old.client_op_id, old.day, old.currency, old.expected_cash,
      old.counted_cash, old.difference, old.server_expected_cash, old.note, old.closed_at, old.created_at, old.deleted_at)
     or (new.closed_by is distinct from old.closed_by and new.closed_by is not null)
     or (new.approved_by is distinct from old.approved_by and new.approved_by is not null) then
    raise exception 'day_closes is append-only' using errcode = '55000', hint = 'append_only';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_day_close_change() from public, anon, authenticated;

create trigger day_closes_guard before update or delete on public.day_closes
  for each row execute function public.guard_day_close_change();

-- ---------------------------------------------------------------------------
-- RLS: superadmin and admins read their stores' closes; nobody writes from a client
-- ---------------------------------------------------------------------------

alter table public.day_closes enable row level security;

create policy day_closes_read on public.day_closes
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'admin')
         and location_id = any ((select public.auth_location_ids())::uuid[]));

revoke all on public.day_closes from anon;
revoke insert, update, delete, truncate on public.day_closes from authenticated;
grant select on public.day_closes to authenticated;

-- ---------------------------------------------------------------------------
-- day_close_server_expected(tenant, store, day): the server's own expected cash (see the header). Internal.
-- ---------------------------------------------------------------------------

create or replace function public.day_close_server_expected(p_tenant uuid, p_location_id uuid, p_day date)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz    text;
  v_from  timestamptz;
  v_to    timestamptz;
  v_sales bigint;
  v_utang bigint;
  v_exp   bigint;
begin
  select coalesce(t.timezone, 'UTC') into v_tz from public.tenants t where t.id = p_tenant;
  v_from := p_day::timestamp at time zone coalesce(v_tz, 'UTC');
  v_to   := (p_day + 1)::timestamp at time zone coalesce(v_tz, 'UTC');

  select coalesce(sum(p.amount), 0) into v_sales
  from public.sales s
  join public.payments p on p.sale_id = s.id and p.tenant_id = s.tenant_id
  where s.tenant_id = p_tenant and s.location_id = p_location_id and s.status = 'completed'
    and s.sold_at >= v_from and s.sold_at < v_to and p.method = 'cash';

  -- payments are stored negative
  select coalesce(-sum(l.amount), 0) into v_utang
  from public.customer_ledger l
  where l.tenant_id = p_tenant and l.kind = 'payment' and l.occurred_at >= v_from and l.occurred_at < v_to;

  select coalesce(sum(e.amount), 0) into v_exp
  from public.expenses e
  where e.tenant_id = p_tenant and e.location_id = p_location_id and e.voided_at is null and e.paid_from = 'cash'
    and e.spent_at >= v_from and e.spent_at < v_to;

  return v_sales + v_utang - v_exp;
end;
$$;

revoke execute on function public.day_close_server_expected(uuid, uuid, date) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_close_day   p = { id, day: 'YYYY-MM-DD', expected_cash, counted_cash, note?, closed_at?, currency?, location_id?,
--                      approval_id? }
--   expected_cash: whole centavos, may be negative; counted_cash: whole centavos >= 0 (number or digit string).
--   day: not later than tomorrow in the tenant timezone (clock skew); any past day is fine (queued offline).
--   Returns { day_close_id, day, difference, server_expected_cash, approved_by, applied_at }.
-- ---------------------------------------------------------------------------

create or replace function public.op_close_day(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant  uuid;
  v_replay  jsonb;
  v_loc     uuid;
  v_id      uuid;
  v_day     date;
  v_tz      text;
  v_exp_txt text;
  v_cnt_txt text;
  v_exp     bigint;
  v_cnt     bigint;
  v_base    text;
  v_ccy     text;
  v_closed  timestamptz;
  v_note    text;
  v_appr    uuid;
  v_server  bigint;
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

  v_ccy := coalesce(upper(nullif(btrim(p ->> 'currency'), '')), v_base);
  if v_ccy is distinct from v_base then
    raise exception 'the cash count is in the base currency' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_closed := coalesce((p ->> 'closed_at')::timestamptz, now());
  v_note := left(nullif(btrim(p ->> 'note'), ''), 200);

  v_appr := public.authorize_expense_write(v_loc, 'close_day', v_id, (p ->> 'approval_id')::uuid, p_op_id);
  v_server := public.day_close_server_expected(v_tenant, v_loc, v_day);

  begin
    insert into public.day_closes (id, tenant_id, location_id, client_op_id, day, currency, expected_cash, counted_cash,
                                   difference, server_expected_cash, note, closed_by, approved_by, closed_at)
    values (v_id, v_tenant, v_loc, p_op_id, v_day, v_ccy, v_exp, v_cnt, v_cnt - v_exp, v_server, v_note,
            auth.uid(), v_appr, v_closed);
  exception when unique_violation then
    raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  perform public.write_audit('day.close', 'day_close', v_id, v_loc, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_loc, 'day', v_day, 'expected_cash', v_exp, 'counted_cash', v_cnt, 'difference', v_cnt - v_exp,
    'server_expected_cash', v_server, 'op_id', p_op_id, 'approved_by', v_appr)));
  return public.finish_op(p_op_id, jsonb_build_object(
    'day_close_id', v_id, 'day', v_day, 'difference', v_cnt - v_exp, 'server_expected_cash', v_server,
    'approved_by', v_appr, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_close_day(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_day_closes(cursor, limit)   same shape and rules as sync_pull_expenses
--   first pull (cursor null) = closes from the last 30 days by closed_at; afterwards delta by (updated_at, id);
--   rows newer than now - 5 s wait for the next pull. Runs as the caller: cashiers get no rows (RLS).
--   Returns { rows: [ { id, location_id, day, currency, expected_cash, counted_cash, difference, server_expected_cash,
--                       note, closed_by, approved_by, closed_at, updated_at } ], cursor, has_more, server_time }.
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
    select x.id, x.location_id, x.day, x.currency, x.expected_cash, x.counted_cash, x.difference,
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
        'expected_cash', g.expected_cash, 'counted_cash', g.counted_cash, 'difference', g.difference,
        'server_expected_cash', g.server_expected_cash, 'note', g.note, 'closed_by', g.closed_by,
        'approved_by', g.approved_by, 'closed_at', g.closed_at, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$$;

revoke execute on function public.sync_pull_day_closes(jsonb, int) from public, anon;
grant execute on function public.sync_pull_day_closes(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- sync_push re-created (from 20261108001100, the newest definition) with the close_day kind
-- ---------------------------------------------------------------------------

create or replace function public.sync_push(p_ops jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o        jsonb;
  v_out    jsonb := '[]'::jsonb;
  v_id     uuid;
  v_kind   text;
  v_res    jsonb;
  v_state  text;
  v_hint   text;
begin
  perform public.assert_active_user();
  if jsonb_typeof(p_ops) is distinct from 'array' or jsonb_array_length(p_ops) not between 1 and 50 then
    raise exception 'send 1 to 50 ops' using errcode = '22023', hint = 'batch_invalid';
  end if;

  for o in select * from jsonb_array_elements(p_ops) loop
    begin
      v_id := (o ->> 'op_id')::uuid;
      v_kind := o ->> 'kind';
      v_res := case v_kind
        when 'record_sale'         then public.op_record_sale(v_id, o -> 'payload')
        when 'void_sale'           then public.op_void_sale(v_id, o -> 'payload')
        when 'upsert_customer'     then public.op_upsert_customer(v_id, o -> 'payload')
        when 'record_utang_payment' then public.op_record_utang_payment(v_id, o -> 'payload')
        when 'post_opening_stock'  then public.op_post_opening_stock(v_id, o -> 'payload')
        when 'receive_stock'       then public.op_receive_stock(v_id, o -> 'payload')
        when 'adjust_stock'        then public.op_adjust_stock(v_id, o -> 'payload')
        when 'adjust_utang'        then public.op_adjust_utang(v_id, o -> 'payload')
        when 'record_expense'      then public.op_record_expense(v_id, o -> 'payload')
        when 'void_expense'        then public.op_void_expense(v_id, o -> 'payload')
        when 'close_day'           then public.op_close_day(v_id, o -> 'payload')
        else null
      end;
      if v_res is null then
        v_out := v_out || jsonb_build_object('op_id', v_id, 'status', 'rejected', 'hint', 'unknown_kind');
      else
        v_out := v_out || jsonb_build_object('op_id', v_id, 'status', 'ok', 'result', v_res);
      end if;
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      v_state := sqlstate;
      if v_state in ('40001', '40P01', '55P03', '57014', '53300', '53200', '08006') then
        -- transient: stop here so later ops are not applied before this one
        v_out := v_out || jsonb_build_object('op_id', v_id, 'status', 'error', 'code', v_state);
        return v_out;
      end if;
      v_out := v_out || jsonb_build_object(
        'op_id', v_id, 'status', 'rejected', 'code', v_state,
        'hint', coalesce(nullif(v_hint, ''), case v_state
          when '22P02' then 'invalid_value' when '22003' then 'invalid_value' when '22007' then 'invalid_value'
          when '23503' then 'unknown_reference' when '23514' then 'invalid_value'
          when '23505' then 'id_conflict' when '42501' then 'not_allowed'
          else 'rejected' end));
    end;
  end loop;

  return v_out;
end;
$$;

revoke execute on function public.sync_push(jsonb) from public, anon;
grant execute on function public.sync_push(jsonb) to authenticated;
