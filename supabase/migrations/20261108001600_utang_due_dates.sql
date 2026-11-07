-- P8-10 Utang due dates: a customer may carry the date she promised to pay ("babayaran ko sa Biyernes").
--
--   customers.due_on    date, nullable: the promised payment date (one per customer, not per charge)
--   op_set_utang_due    through sync_push: set or clear it (idempotent by op id)
--   sync_pull_pos       re-created (from 20261108000800, the newest definition): customers rows also carry due_on
--   sync_push           re-created (from 20261108001500, the newest definition) with the set_utang_due kind
--
-- Overdue is derived, never stored: balance (sum of the ledger) > 0 and due_on < today. Paying in full does not clear
-- the date by itself (the app shows nothing when nothing is owed); the next promise simply replaces it.
--
-- Who (the UI hides, this enforces): the same people as upsert_customer / record_utang_payment (assert_seller: owner,
-- admins, cashiers of a tenant with POS). A due date is a promise noted at the counter and moves no money, so it does not
-- need the owner-only rule of adjust_utang. Warehouse staff: not_allowed.
-- Rules: due_on is 'YYYY-MM-DD' or null (clear); the key must be present; at most 2 years before or after today
-- (anything else: invalid_value). The customer must exist in the caller's tenant (unknown_customer).
-- A change moves customers.updated_at (set_updated_at trigger), so the delta pull delivers it. Sending the same date again
-- changes nothing (no update, no audit row). Replays (same op id) write nothing.
-- Audit: 'utang.set_due' (entity customer, meta { due_on, previous, op_id }), only when the date changed.

alter table public.customers add column due_on date;

comment on column public.customers.due_on is
  'Utang: the date the customer promised to pay (null = none). Overdue = balance > 0 and due_on < today (derived).';

-- ---------------------------------------------------------------------------
-- op_set_utang_due   p = { customer_id, due_on: 'YYYY-MM-DD' | null }
--   Returns { customer_id, due_on, changed, applied_at }.
-- ---------------------------------------------------------------------------

create or replace function public.op_set_utang_due(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_cust   uuid;
  v_raw    text;
  v_due    date;
  v_old    date;
  v_changed boolean;
begin
  perform public.assert_seller();
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'due date must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'set_utang_due');
  if v_replay is not null then
    return v_replay;
  end if;

  if not (p ? 'due_on') then
    raise exception 'due_on is required (null clears it)' using errcode = '22023', hint = 'invalid_value';
  end if;
  if jsonb_typeof(p -> 'due_on') = 'null' then
    v_due := null;
  else
    v_raw := p ->> 'due_on';
    if jsonb_typeof(p -> 'due_on') is distinct from 'string' or v_raw !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
      raise exception 'due date must be YYYY-MM-DD' using errcode = '22023', hint = 'invalid_value';
    end if;
    begin
      v_due := v_raw::date;
    exception when others then
      raise exception 'due date is not a real date' using errcode = '22023', hint = 'invalid_value';
    end;
    if v_due < current_date - interval '2 years' or v_due > current_date + interval '2 years' then
      raise exception 'due date must be within 2 years of today' using errcode = '22023', hint = 'invalid_value';
    end if;
  end if;

  v_cust := (p ->> 'customer_id')::uuid;
  select c.due_on into v_old from public.customers c where c.id = v_cust and c.tenant_id = v_tenant for update;
  if not found then
    raise exception 'unknown customer' using errcode = '22023', hint = 'unknown_customer';
  end if;

  v_changed := v_old is distinct from v_due;
  if v_changed then
    update public.customers set due_on = v_due where id = v_cust and tenant_id = v_tenant;
    perform public.write_audit('utang.set_due', 'customer', v_cust, null,
      jsonb_build_object('due_on', v_due, 'previous', v_old, 'op_id', p_op_id));
  end if;

  return public.finish_op(p_op_id, jsonb_build_object(
    'customer_id', v_cust, 'due_on', v_due, 'changed', v_changed, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_set_utang_due(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_pos re-created (from 20261108000800): customers rows also carry due_on (additive)
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_pos(p_cursors jsonb default '{}'::jsonb, p_limit int default 500)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_upto   timestamptz := now() - interval '5 seconds';
  v_out    jsonb := jsonb_build_object('server_time', now());
  r        record;
  v_cur    jsonb;
  v_rows   jsonb;
  v_last   jsonb;
  v_more   boolean;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  if p_limit is null or p_limit not between 1 and 1000 then
    raise exception 'limit must be 1 to 1000' using errcode = '22023', hint = 'invalid_value';
  end if;

  for r in select * from (values
    ('stock_levels',    'location_id, variant_id, qty_on_hand, avg_cost, counted, updated_at',
                        'updated_at', 'location_id::text || ''|'' || variant_id::text'),
    ('customers',       'id, name, phone, due_on, updated_at, deleted_at',
                        'updated_at', 'id::text'),
    ('customer_ledger', 'id, customer_id, kind, amount, sale_id, note, occurred_at, created_at',
                        'created_at', 'id::text')
  ) t(tbl, cols, tscol, keyexpr) loop
    v_cur := p_cursors -> r.tbl;

    execute format($q$
      with s as (
        select %2$s, %3$s as _k
        from public.%1$I
        where tenant_id = $1
          and %4$I <= $2
          and ($3::timestamptz is null or (%4$I, %3$s) > ($3::timestamptz, $4::text))
        order by %4$I, _k
        limit $5 + 1
      ), page as (
        select * from s order by %4$I, _k limit $5
      )
      select
        (select count(*) from s) > $5,
        coalesce((select jsonb_agg(to_jsonb(page) - '_k' order by page.%4$I, page._k) from page), '[]'::jsonb),
        (select jsonb_build_object('ts', page.%4$I, 'k', page._k) from page order by page.%4$I desc, page._k desc limit 1)
    $q$, r.tbl, r.cols, r.keyexpr, r.tscol)
    into v_more, v_rows, v_last
    using v_tenant, v_upto, v_cur ->> 'ts', v_cur ->> 'k', p_limit;

    v_out := v_out || jsonb_build_object(r.tbl, jsonb_build_object(
      'rows', v_rows,
      'cursor', coalesce(v_last, v_cur),
      'has_more', v_more));
  end loop;

  return v_out;
end;
$$;

revoke execute on function public.sync_pull_pos(jsonb, int) from public, anon;
grant execute on function public.sync_pull_pos(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- sync_push re-created (from 20261108001500, the newest definition) with set_utang_due
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
        when 'record_service_txn'  then public.op_record_service_txn(v_id, o -> 'payload')
        when 'void_service_txn'    then public.op_void_service_txn(v_id, o -> 'payload')
        when 'set_tingi_link'      then public.op_set_tingi_link(v_id, o -> 'payload')
        when 'open_pack'           then public.op_open_pack(v_id, o -> 'payload')
        when 'void_open_pack'      then public.op_void_open_pack(v_id, o -> 'payload')
        when 'set_utang_due'       then public.op_set_utang_due(v_id, o -> 'payload')
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
