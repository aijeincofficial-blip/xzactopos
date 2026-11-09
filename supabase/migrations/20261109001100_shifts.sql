-- F-05m Cashier shifts: open and close a shift per cashier, with the cash they started with and the cash they counted.
-- See docs/tasks/F-05m-cashier-shifts.md for the decisions.
--
--   shifts                one row per shift; written only by op_open_shift and op_close_shift (never by a client)
--   shift_server_expected the server's own expected cash for a shift: opening cash + the cashier's cash sales + the utang cash
--                         they took - the cash expenses they paid + their load / e-wallet cash effect, all at the store and
--                         inside [opened_at, closed_at]. Attribution is by the user who recorded the entry and by time, so
--                         sales, payments and expenses need no new column and the sale path is unchanged.
--   op_open_shift / op_close_shift   through sync_push, idempotent by op id. The phone sends the expected cash it worked out;
--                         the server stores it and its own figure side by side (a mismatch is visible, never an error).
--   sync_pull_shifts      keyset delta pull; open shifts are always sent, closed ones for 30 days
--
-- Who: cashier, admin and owner, at a store they are assigned to; warehouse staff never. One open shift per cashier at a time
-- (hint shift_already_open). An admin or the owner may close someone else's shift. No supervisor PIN to close.
-- Reads: the cashier's own shifts; owner and admins also the shifts of their stores.
-- Timestamps come from the phone (offline): accepted from 14 days back to 5 minutes ahead of the server's clock.

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table public.shifts (
  id                   uuid primary key,
  tenant_id            uuid not null references public.tenants (id) on delete cascade,
  location_id          uuid not null,
  -- the cashier whose shift it is; goes to null if that user is removed (the history stays)
  cashier_id           uuid references auth.users (id) on delete set null,
  open_op_id           uuid not null,
  close_op_id          uuid,
  currency             char(3) not null references public.currencies (code),
  -- base-currency minor units (centavos)
  opening_cash         bigint not null check (opening_cash >= 0),
  opened_at            timestamptz not null,
  closed_at            timestamptz,
  expected_cash        bigint,
  server_expected_cash bigint,
  counted_cash         bigint check (counted_cash >= 0),
  difference           bigint,
  note                 text check (length(note) <= 200),
  closed_by            uuid references auth.users (id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint shifts_tenant_id unique (tenant_id, id),
  constraint shifts_open_op_per_tenant unique (tenant_id, open_op_id),
  constraint shifts_location_fk foreign key (tenant_id, location_id) references public.locations (tenant_id, id),
  -- a shift is open (all closing fields empty) or closed (all of them set)
  constraint shifts_open_or_closed check (
    (closed_at is null and close_op_id is null and expected_cash is null and server_expected_cash is null
       and counted_cash is null and difference is null)
    or (closed_at is not null and close_op_id is not null and expected_cash is not null and server_expected_cash is not null
       and counted_cash is not null and difference is not null)),
  constraint shifts_difference check (difference is null or difference = counted_cash - expected_cash),
  constraint shifts_window check (closed_at is null or closed_at >= opened_at)
);

comment on table public.shifts is
  'A cashier shift. Opened and closed only by op_open_shift / op_close_shift; closing is a single update, after which the row never changes.';

-- one open shift per cashier
create unique index shifts_one_open_per_cashier on public.shifts (tenant_id, cashier_id) where closed_at is null;
create index shifts_tenant_updated_idx on public.shifts (tenant_id, updated_at, id);
create index shifts_store_idx on public.shifts (tenant_id, location_id, opened_at desc);

create trigger shifts_set_updated_at before update on public.shifts
  for each row execute function public.set_updated_at();

-- Opening is an insert. Closing is ONE update that fills the closing fields. After that nothing changes, except a user
-- reference going to null when that user is removed.
create or replace function public.guard_shift_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'shifts cannot be deleted' using errcode = '55000', hint = 'append_only';
  end if;
  if (new.id, new.tenant_id, new.location_id, new.open_op_id, new.currency, new.opening_cash, new.opened_at, new.created_at)
     is distinct from
     (old.id, old.tenant_id, old.location_id, old.open_op_id, old.currency, old.opening_cash, old.opened_at, old.created_at)
     or (new.cashier_id is distinct from old.cashier_id and new.cashier_id is not null)
     or (new.closed_by is distinct from old.closed_by and new.closed_by is not null and old.closed_by is not null) then
    raise exception 'a shift cannot be changed' using errcode = '55000', hint = 'append_only';
  end if;
  if old.closed_at is not null and
     (new.closed_at, new.close_op_id, new.expected_cash, new.server_expected_cash, new.counted_cash, new.difference, new.note)
     is distinct from
     (old.closed_at, old.close_op_id, old.expected_cash, old.server_expected_cash, old.counted_cash, old.difference, old.note) then
    raise exception 'a closed shift cannot be changed' using errcode = '55000', hint = 'append_only';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_shift_change() from public, anon, authenticated;

create trigger shifts_guard before update or delete on public.shifts
  for each row execute function public.guard_shift_change();

-- ---------------------------------------------------------------------------
-- RLS: the cashier's own shifts; owner and admins also the shifts of their stores; nobody writes from a client
-- ---------------------------------------------------------------------------

alter table public.shifts enable row level security;

create policy shifts_read on public.shifts
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (cashier_id = (select auth.uid())
              or ((select public.auth_role()) in ('superadmin', 'admin')
                  and location_id = any ((select public.auth_location_ids())::uuid[]))));

revoke all on public.shifts from anon;
revoke insert, update, delete, truncate on public.shifts from authenticated;
grant select on public.shifts to authenticated;

-- ---------------------------------------------------------------------------
-- shift_server_expected(tenant, store, cashier, from, to): the server's own expected cash for a shift. Internal.
-- ---------------------------------------------------------------------------

create or replace function public.shift_server_expected(
  p_tenant uuid, p_location_id uuid, p_cashier uuid, p_from timestamptz, p_to timestamptz, p_opening bigint)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_sales bigint;
  v_utang bigint;
  v_exp   bigint;
  v_svc   bigint;
begin
  select coalesce(sum(p.amount), 0) into v_sales
  from public.sales s
  join public.payments p on p.sale_id = s.id and p.tenant_id = s.tenant_id
  where s.tenant_id = p_tenant and s.location_id = p_location_id and s.created_by = p_cashier and s.status = 'completed'
    and s.sold_at >= p_from and s.sold_at <= p_to and p.method = 'cash';

  -- payments are stored negative; cash ones taken by this cashier at this store
  select coalesce(-sum(l.amount), 0) into v_utang
  from public.customer_ledger l
  where l.tenant_id = p_tenant and l.kind = 'payment' and l.method = 'cash' and l.location_id = p_location_id
    and l.created_by = p_cashier and l.occurred_at >= p_from and l.occurred_at <= p_to;

  select coalesce(sum(e.amount), 0) into v_exp
  from public.expenses e
  where e.tenant_id = p_tenant and e.location_id = p_location_id and e.created_by = p_cashier
    and e.voided_at is null and e.paid_from = 'cash' and e.spent_at >= p_from and e.spent_at <= p_to;

  select coalesce(sum(public.service_cash_effect(t.kind, t.amount, t.fee, t.price)), 0) into v_svc
  from public.service_txns t
  where t.tenant_id = p_tenant and t.location_id = p_location_id and t.created_by = p_cashier
    and t.voided_at is null and t.txn_at >= p_from and t.txn_at <= p_to;

  return p_opening + v_sales + v_utang - v_exp + v_svc;
end;
$$;

revoke execute on function public.shift_server_expected(uuid, uuid, uuid, timestamptz, timestamptz, bigint) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_open_shift(op, { id, location_id?, opening_cash?, opened_at? })
--   Returns { shift_id, opened_at, applied_at }. Refusals: not_allowed, location_required, location_denied, amount_invalid,
--   invalid_value (time out of range), shift_already_open, id_conflict.
-- ---------------------------------------------------------------------------

create or replace function public.op_open_shift(p_op_id uuid, p jsonb)
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
  v_open_txt text;
  v_open     bigint;
  v_base     text;
  v_at       timestamptz;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin', 'cashier') then
    raise exception 'not allowed to open a shift' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'shift must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'open_shift');
  if v_replay is not null then
    return v_replay;
  end if;

  v_id := (p ->> 'id')::uuid;
  if v_id is null then
    raise exception 'shift id is required' using errcode = '22023', hint = 'id_required';
  end if;
  v_loc := public.resolve_store((p ->> 'location_id')::uuid);

  if coalesce(jsonb_typeof(p -> 'opening_cash'), 'null') = 'null' then
    v_open := 0;
  else
    v_open_txt := p ->> 'opening_cash';
    if not coalesce(jsonb_typeof(p -> 'opening_cash') in ('number', 'string') and v_open_txt ~ '^[0-9]{1,15}$', false) then
      raise exception 'opening cash must be whole centavos, not below zero' using errcode = '22023', hint = 'amount_invalid';
    end if;
    v_open := v_open_txt::bigint;
  end if;

  v_at := coalesce((p ->> 'opened_at')::timestamptz, now());
  if v_at > now() + interval '5 minutes' or v_at < now() - interval '14 days' then
    raise exception 'opened_at is out of range' using errcode = '22023', hint = 'invalid_value';
  end if;
  select t.base_currency into v_base from public.tenants t where t.id = v_tenant;

  begin
    insert into public.shifts (id, tenant_id, location_id, cashier_id, open_op_id, currency, opening_cash, opened_at)
    values (v_id, v_tenant, v_loc, auth.uid(), p_op_id, v_base, v_open, v_at);
  exception when unique_violation then
    if exists (select 1 from public.shifts s where s.tenant_id = v_tenant and s.cashier_id = auth.uid() and s.closed_at is null) then
      raise exception 'you already have an open shift' using errcode = '22023', hint = 'shift_already_open';
    end if;
    raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  perform public.write_audit('shift.open', 'shift', v_id, v_loc, jsonb_build_object(
    'location_id', v_loc, 'opening_cash', v_open, 'opened_at', v_at, 'op_id', p_op_id));
  return public.finish_op(p_op_id, jsonb_build_object('shift_id', v_id, 'opened_at', v_at, 'applied_at', now()));
end;
$$;
revoke execute on function public.op_open_shift(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_close_shift(op, { id, counted_cash, expected_cash, closed_at?, note? })
--   expected_cash is what the phone worked out (may be below zero); the server stores it next to its own figure.
--   Returns { shift_id, difference, server_expected_cash, applied_at }. Refusals: not_allowed, shift_not_found, shift_closed,
--   amount_invalid, invalid_value.
-- ---------------------------------------------------------------------------

create or replace function public.op_close_shift(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant  uuid;
  v_replay  jsonb;
  v_id      uuid;
  v_shift   record;
  v_exp_txt text;
  v_cnt_txt text;
  v_exp     bigint;
  v_cnt     bigint;
  v_closed  timestamptz;
  v_note    text;
  v_server  bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin', 'cashier') then
    raise exception 'not allowed to close a shift' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'shift must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'close_shift');
  if v_replay is not null then
    return v_replay;
  end if;

  v_id := (p ->> 'id')::uuid;
  select * into v_shift from public.shifts s where s.id = v_id and s.tenant_id = v_tenant for update;
  if not found then
    raise exception 'shift not found' using errcode = '22023', hint = 'shift_not_found';
  end if;
  -- the cashier closes their own shift; an admin or the owner may close another one at a store they can see
  if v_shift.cashier_id is distinct from auth.uid() then
    if public.auth_role() not in ('superadmin', 'admin') then
      raise exception 'not your shift' using errcode = '42501', hint = 'not_allowed';
    end if;
    perform public.assert_location_access(v_shift.location_id);
  end if;
  if v_shift.closed_at is not null then
    raise exception 'this shift is already closed' using errcode = '22023', hint = 'shift_closed';
  end if;

  v_exp_txt := p ->> 'expected_cash';
  v_cnt_txt := p ->> 'counted_cash';
  if not coalesce(jsonb_typeof(p -> 'expected_cash') in ('number', 'string') and v_exp_txt ~ '^-?[0-9]{1,15}$', false)
     or not coalesce(jsonb_typeof(p -> 'counted_cash') in ('number', 'string') and v_cnt_txt ~ '^[0-9]{1,15}$', false) then
    raise exception 'cash amounts must be whole centavos' using errcode = '22023', hint = 'amount_invalid';
  end if;
  v_exp := v_exp_txt::bigint;
  v_cnt := v_cnt_txt::bigint;

  v_closed := coalesce((p ->> 'closed_at')::timestamptz, now());
  if v_closed > now() + interval '5 minutes' or v_closed < v_shift.opened_at then
    raise exception 'closed_at is out of range' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_note := left(nullif(btrim(p ->> 'note'), ''), 200);

  v_server := public.shift_server_expected(v_tenant, v_shift.location_id, v_shift.cashier_id, v_shift.opened_at, v_closed, v_shift.opening_cash);

  update public.shifts
     set closed_at = v_closed, close_op_id = p_op_id, expected_cash = v_exp, server_expected_cash = v_server,
         counted_cash = v_cnt, difference = v_cnt - v_exp, note = v_note, closed_by = auth.uid()
   where id = v_id;

  perform public.write_audit('shift.close', 'shift', v_id, v_shift.location_id, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_shift.location_id, 'cashier_id', v_shift.cashier_id, 'expected_cash', v_exp, 'counted_cash', v_cnt,
    'difference', v_cnt - v_exp, 'server_expected_cash', v_server, 'op_id', p_op_id)));
  return public.finish_op(p_op_id, jsonb_build_object(
    'shift_id', v_id, 'difference', v_cnt - v_exp, 'server_expected_cash', v_server, 'applied_at', now()));
end;
$$;
revoke execute on function public.op_close_shift(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_shifts(cursor, limit): the caller's shifts (row-level security does the scoping). Open shifts are always sent on
-- the first pull; closed ones for the last 30 days. Same keyset rules and 5 s hold-back as the other pulls.
--   Returns { rows: [ { id, location_id, cashier_id, currency, opening_cash, opened_at, closed_at, expected_cash,
--                       server_expected_cash, counted_cash, difference, note, closed_by, updated_at } ], cursor, has_more, server_time }.
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_shifts(p_cursor jsonb default null, p_limit int default 100)
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
    select x.id, x.location_id, x.cashier_id, x.currency, x.opening_cash, x.opened_at, x.closed_at, x.expected_cash,
           x.server_expected_cash, x.counted_cash, x.difference, x.note, x.closed_by, x.updated_at
    from public.shifts x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and (v_ts is null and (x.closed_at is null or x.closed_at >= now() - interval '30 days')
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'cashier_id', g.cashier_id, 'currency', g.currency,
        'opening_cash', g.opening_cash, 'opened_at', g.opened_at, 'closed_at', g.closed_at,
        'expected_cash', g.expected_cash, 'server_expected_cash', g.server_expected_cash,
        'counted_cash', g.counted_cash, 'difference', g.difference, 'note', g.note, 'closed_by', g.closed_by,
        'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$$;
revoke execute on function public.sync_pull_shifts(jsonb, int) from public, anon;
grant execute on function public.sync_pull_shifts(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- sync_push re-created (from 20261109000700, the newest definition) with the open_shift and close_shift kinds
-- ---------------------------------------------------------------------------

create or replace function public.sync_push(p_ops jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o            jsonb;
  v_out        jsonb := '[]'::jsonb;
  v_id         uuid;
  v_kind       text;
  v_res        jsonb;
  v_state      text;
  v_hint       text;
  v_op_loc     uuid;
  v_audit_hint text;
  v_loc_text   text;
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
        when 'record_sale'          then public.op_record_sale(v_id, o -> 'payload')
        when 'void_sale'            then public.op_void_sale(v_id, o -> 'payload')
        when 'upsert_customer'      then public.op_upsert_customer(v_id, o -> 'payload')
        when 'record_utang_payment' then public.op_record_utang_payment(v_id, o -> 'payload')
        when 'post_opening_stock'   then public.op_post_opening_stock(v_id, o -> 'payload')
        when 'receive_stock'        then public.op_receive_stock(v_id, o -> 'payload')
        when 'receive_warehouse_stock' then public.op_receive_warehouse_stock(v_id, o -> 'payload')
        when 'receive_po'             then public.op_receive_po(v_id, o -> 'payload')
        when 'receive_without_po'    then public.op_receive_without_po(v_id, o -> 'payload')
        when 'adjust_stock'         then public.op_adjust_stock(v_id, o -> 'payload')
        when 'adjust_utang'         then public.op_adjust_utang(v_id, o -> 'payload')
        when 'record_expense'       then public.op_record_expense(v_id, o -> 'payload')
        when 'void_expense'         then public.op_void_expense(v_id, o -> 'payload')
        when 'close_day'            then public.op_close_day(v_id, o -> 'payload')
        when 'record_service_txn'   then public.op_record_service_txn(v_id, o -> 'payload')
        when 'void_service_txn'     then public.op_void_service_txn(v_id, o -> 'payload')
        when 'set_tingi_link'       then public.op_set_tingi_link(v_id, o -> 'payload')
        when 'open_pack'            then public.op_open_pack(v_id, o -> 'payload')
        when 'void_open_pack'       then public.op_void_open_pack(v_id, o -> 'payload')
        when 'set_utang_due'        then public.op_set_utang_due(v_id, o -> 'payload')
        when 'set_expiry'           then public.op_set_expiry(v_id, o -> 'payload')
        when 'open_shift'           then public.op_open_shift(v_id, o -> 'payload')
        when 'close_shift'          then public.op_close_shift(v_id, o -> 'payload')
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

      v_audit_hint := coalesce(nullif(v_hint, ''), case v_state
        when '22P02' then 'invalid_value' when '22003' then 'invalid_value' when '22007' then 'invalid_value'
        when '23503' then 'unknown_reference' when '23514' then 'invalid_value'
        when '23505' then 'id_conflict' when '42501' then 'not_allowed'
        else 'rejected' end);

      -- Audit refused op
      begin
        v_loc_text := coalesce(o -> 'payload' ->> 'location_id', o -> 'payload' ->> 'warehouse_id');
        if v_loc_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
          v_op_loc := v_loc_text::uuid;
        else
          v_op_loc := null;
        end if;

        perform public.write_audit(
          'op.refused',
          coalesce(nullif(v_kind, ''), 'op'),
          v_id,
          v_op_loc,
          jsonb_build_object(
            'kind', v_kind,
            'code', v_state,
            'hint', v_audit_hint
          )
        );
      exception when others then
        null;
      end;

      v_out := v_out || jsonb_build_object(
        'op_id', v_id, 'status', 'rejected', 'code', v_state,
        'hint', v_audit_hint);
    end;
  end loop;

  return v_out;
end;
$$;

revoke execute on function public.sync_push(jsonb) from public, anon;
grant execute on function public.sync_push(jsonb) to authenticated;
