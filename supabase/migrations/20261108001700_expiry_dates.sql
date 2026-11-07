-- P8-11 Expiry dates (kept simple on purpose).
--
-- MODEL AND LIMITATION. No lot accounting: each variant at a store carries at most ONE date, the earliest expiry among what
-- is on the shelf. The tindera sets it when a batch comes in or when she checks the shelf. There are no per-lot quantities,
-- so the app cannot know when the early batch is gone: after selling it she sets the next date by hand (or a stock in on an
-- empty shelf replaces it, see below). Cleared = null.
--
--   stock_expiry        one row per (store, variant): expires_on (null = cleared). A separate table so stock_levels stays
--                       trigger-derived and is never written by anything but the movement trigger. RLS: read like
--                       stock_levels (the user's stores); no client writes.
--   op_set_expiry       through sync_push: set or clear the date (idempotent by op id)
--   op_receive_stock    re-created (from 20261108000700): OPTIONAL expires_on. When sent, the stored date becomes the EARLIER of
--                       the stored one and the new one if there was stock on hand (qty > 0 before this receipt), else the new
--                       one replaces it. Without expires_on nothing at all changes (same movement, audit, result as before).
--   sync_pull_pos       re-created (from 20261108001600): a new `stock_expiry` section (rows, cursor, has_more), additive
--   sync_push           re-created (from 20261108001600) with set_expiry
--
-- Who (the UI hides, this enforces): the same people as receive_stock / adjust_stock (catalog_write_mode() 'full': owner,
-- store managers), stores only (resolve_store). Cashiers, supervisors, warehouse staff: not_allowed. No approvals.
-- Dates: 'YYYY-MM-DD' (a JSON string, a real date) from 2000-01-01 to today + 10 years; a date in the past is allowed (already
-- expired). Anything else: invalid_value. set_expiry needs the key (null clears); receive_stock ignores a missing or null one.
-- A change moves stock_expiry.updated_at (trigger), so the delta pull delivers it; set_expiry with the same date again writes
-- nothing; a receipt with a date always moves updated_at (so a phone that guessed the rule differently is corrected).
-- Audit: 'stock.set_expiry' (entity variant, meta { expires_on, previous, op_id }), only when the date changed; a receipt that
-- changes the date writes it too (meta also has via = 'receive_stock'). Replays (same op id) write nothing.

-- ---------------------------------------------------------------------------
-- stock_expiry
-- ---------------------------------------------------------------------------

create table public.stock_expiry (
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  location_id  uuid not null,
  variant_id   uuid not null,
  expires_on   date,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  updated_by   uuid references auth.users (id) on delete set null,
  primary key (location_id, variant_id),
  constraint stock_expiry_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint stock_expiry_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id)
);

comment on table public.stock_expiry is
  'Expiry: the earliest expiry date on the shelf per store and variant (one date, no lots). Written only by op_set_expiry / op_receive_stock.';

create index stock_expiry_tenant_updated_idx on public.stock_expiry (tenant_id, updated_at, location_id, variant_id);

create trigger stock_expiry_set_updated_at before update on public.stock_expiry
  for each row execute function public.set_updated_at();
create trigger stock_expiry_tenant_immutable before update of tenant_id on public.stock_expiry
  for each row execute function public.prevent_tenant_change();

alter table public.stock_expiry enable row level security;

-- store-scoped like stock_levels: the user's stores (superadmin: all stores)
create policy stock_expiry_store_read on public.stock_expiry
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and location_id = any ((select public.auth_location_ids())::uuid[]));

revoke all on public.stock_expiry from anon;
revoke insert, update, delete, truncate on public.stock_expiry from authenticated;
grant select on public.stock_expiry to authenticated;

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

-- An expiry date from p ->> p_key: a JSON string 'YYYY-MM-DD' that is a real date from 2000-01-01 to today + 10 years.
-- JSON null gives null. Anything else raises invalid_value.
create or replace function public.json_expiry_date(p jsonb, p_key text)
returns date
language plpgsql
stable
set search_path = ''
as $$
declare
  v_raw text := p ->> p_key;
  v_d   date;
begin
  if p -> p_key is null or jsonb_typeof(p -> p_key) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p -> p_key) is distinct from 'string' or v_raw !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'expiry date must be YYYY-MM-DD' using errcode = '22023', hint = 'invalid_value';
  end if;
  begin
    v_d := v_raw::date;
  exception when others then
    raise exception 'expiry date is not a real date' using errcode = '22023', hint = 'invalid_value';
  end;
  if v_d < date '2000-01-01' or v_d > current_date + interval '10 years' then
    raise exception 'expiry date must be from 2000 to 10 years from today' using errcode = '22023', hint = 'invalid_value';
  end if;
  return v_d;
end;
$$;

revoke execute on function public.json_expiry_date(jsonb, text) from public, anon, authenticated;

-- Stores the date for (store, variant) when it differs from the stored one; returns the previous date and whether it changed.
create or replace function public.stock_store_expiry(p_tenant uuid, p_loc uuid, p_vid uuid, p_date date,
                                                     out previous date, out changed boolean)
language plpgsql
security definer
set search_path = ''
as $$
begin
  select e.expires_on into previous from public.stock_expiry e
  where e.location_id = p_loc and e.variant_id = p_vid for update;
  changed := previous is distinct from p_date;
  if changed then
    insert into public.stock_expiry as se (tenant_id, location_id, variant_id, expires_on, updated_by)
    values (p_tenant, p_loc, p_vid, p_date, auth.uid())
    on conflict (location_id, variant_id)
    do update set expires_on = excluded.expires_on, updated_by = excluded.updated_by;
  end if;
end;
$$;

revoke execute on function public.stock_store_expiry(uuid, uuid, uuid, date) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_set_expiry   p = { variant_id, expires_on: 'YYYY-MM-DD' | null, location_id? }
--   Returns { variant_id, location_id, expires_on, changed, applied_at }.
-- ---------------------------------------------------------------------------

create or replace function public.op_set_expiry(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_loc    uuid;
  v_vid    uuid;
  v_date   date;
  v_res    record;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  if public.catalog_write_mode() is distinct from 'full' then
    raise exception 'not allowed to change stock' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'expiry must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'set_expiry');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);
  if not (p ? 'expires_on') then
    raise exception 'expires_on is required (null clears it)' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_date := public.json_expiry_date(p, 'expires_on');
  v_vid := (p ->> 'variant_id')::uuid;
  if not exists (select 1 from public.product_variants v where v.id = v_vid and v.tenant_id = v_tenant) then
    raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
  end if;

  select * into v_res from public.stock_store_expiry(v_tenant, v_loc, v_vid, v_date);
  if v_res.changed then
    perform public.write_audit('stock.set_expiry', 'variant', v_vid, v_loc,
      jsonb_build_object('expires_on', v_date, 'previous', v_res.previous, 'op_id', p_op_id));
  end if;

  return public.finish_op(p_op_id, jsonb_build_object(
    'variant_id', v_vid, 'location_id', v_loc, 'expires_on', v_date, 'changed', v_res.changed, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_set_expiry(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_receive_stock re-created (from 20261108000700)   p = { variant_id, qty (> 0), unit_cost?, location_id?, expires_on? }
--   Unchanged except the optional expires_on (rule in the header). Its result gains expires_on (the stored date) only when
--   one was sent; its stock.receive audit meta likewise.
-- ---------------------------------------------------------------------------

create or replace function public.op_receive_stock(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_loc    uuid;
  v_vid    uuid;
  v_qty    numeric;
  v_cost   bigint;
  v_exp    date;
  v_before numeric;
  v_old    date;
  v_new    date;
  v_res    record;
  v_meta   jsonb;
  v_result jsonb;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  if public.catalog_write_mode() is distinct from 'full' then
    raise exception 'not allowed to change stock' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'stock entry must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'receive_stock');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);
  v_vid := (p ->> 'variant_id')::uuid;
  v_qty := (p ->> 'qty')::numeric;
  v_cost := (p ->> 'unit_cost')::bigint;
  if v_qty is null or v_qty <= 0 or v_qty >= 1000000000 then
    raise exception 'quantity must be above zero' using errcode = '22023', hint = 'qty_invalid';
  end if;
  if v_cost is not null and v_cost < 0 then
    raise exception 'cost is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_exp := public.json_expiry_date(p, 'expires_on');
  if not exists (select 1 from public.product_variants v where v.id = v_vid and v.tenant_id = v_tenant) then
    raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
  end if;

  if v_exp is not null then
    -- what was on the shelf before this receipt (locked: the movement below updates the same row)
    select l.qty_on_hand into v_before from public.stock_levels l
    where l.location_id = v_loc and l.variant_id = v_vid for update;
  end if;

  insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id,
                                      unit_cost, created_by)
  values (v_tenant, v_loc, v_vid, v_qty, 'receipt', 'receipt', p_op_id, v_cost, auth.uid());

  v_meta := jsonb_build_object('qty', v_qty, 'cost', v_cost);
  v_result := jsonb_build_object('variant_id', v_vid, 'applied_at', now());
  if v_exp is not null then
    select e.expires_on into v_old from public.stock_expiry e where e.location_id = v_loc and e.variant_id = v_vid;
    v_new := case when coalesce(v_before, 0) > 0 and v_old is not null then least(v_old, v_exp) else v_exp end;
    select * into v_res from public.stock_store_expiry(v_tenant, v_loc, v_vid, v_new);
    if v_res.changed then
      perform public.write_audit('stock.set_expiry', 'variant', v_vid, v_loc, jsonb_build_object(
        'expires_on', v_new, 'previous', v_res.previous, 'op_id', p_op_id, 'via', 'receive_stock'));
    else
      -- same date: still move updated_at, so a phone that guessed differently (it applies the same rule to the stock it
      -- sees) gets the server's date in the next delta pull
      update public.stock_expiry set updated_by = auth.uid() where location_id = v_loc and variant_id = v_vid;
    end if;
    v_meta := v_meta || jsonb_build_object('expires_on', v_new);
    v_result := v_result || jsonb_build_object('expires_on', v_new);
  end if;

  perform public.write_audit('stock.receive', 'variant', v_vid, v_loc, v_meta);
  return public.finish_op(p_op_id, v_result);
end;
$$;

revoke execute on function public.op_receive_stock(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_pos re-created (from 20261108001600): a new stock_expiry section (additive; same keyset rules as stock_levels)
--   "stock_expiry": { rows: [ { location_id, variant_id, expires_on, updated_at } ], cursor, has_more }
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
                        'created_at', 'id::text'),
    ('stock_expiry',    'location_id, variant_id, expires_on, updated_at',
                        'updated_at', 'location_id::text || ''|'' || variant_id::text')
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
-- sync_push re-created (from 20261108001600, the newest definition) with set_expiry
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
        when 'set_expiry'          then public.op_set_expiry(v_id, o -> 'payload')
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
