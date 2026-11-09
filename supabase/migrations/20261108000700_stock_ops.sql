-- P4-01 Stock in, counts and weighted average cost (solo stock, plan section 12 Phase 4).
--   op_receive_stock   stock coming in (type receipt), optional unit cost -> weighted average cost
--   op_adjust_stock    "I counted N": the server writes the difference as count_correction (or damage)
--   stock_levels.avg_cost maintained by the movement trigger, returned by sync_pull_pos
-- Both ops run through sync_push (idempotent by op id) with the same permission as opening stock.

alter table public.stock_movements drop constraint stock_movements_type_check;
alter table public.stock_movements add constraint stock_movements_type_check
  check (type in ('opening', 'sale', 'sale_void', 'receipt', 'count_correction', 'damage'));

alter table public.stock_levels add column avg_cost bigint check (avg_cost >= 0);

-- The level trigger also keeps the weighted average: only a receipt with a cost moves it.
create or replace function public.apply_stock_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_qty  numeric;
  v_old_cost bigint;
  v_cost     bigint;
begin
  select l.qty_on_hand, l.avg_cost into v_old_qty, v_old_cost
  from public.stock_levels l
  where l.location_id = new.location_id and l.variant_id = new.variant_id
  for update;

  v_cost := v_old_cost;
  if new.type = 'receipt' and new.unit_cost is not null then
    if coalesce(v_old_qty, 0) <= 0 or v_old_cost is null then
      v_cost := new.unit_cost;
    else
      v_cost := round((v_old_qty * v_old_cost + new.qty_delta * new.unit_cost) / (v_old_qty + new.qty_delta))::bigint;
    end if;
  end if;

  insert into public.stock_levels as sl (tenant_id, location_id, variant_id, qty_on_hand, avg_cost, updated_at)
  values (new.tenant_id, new.location_id, new.variant_id, new.qty_delta, v_cost, now())
  on conflict (location_id, variant_id)
  do update set qty_on_hand = sl.qty_on_hand + excluded.qty_on_hand, avg_cost = excluded.avg_cost, updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- op_receive_stock   p = { variant_id, qty (> 0), unit_cost?, location_id? }
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
  if not exists (select 1 from public.product_variants v where v.id = v_vid and v.tenant_id = v_tenant) then
    raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
  end if;

  insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id,
                                      unit_cost, created_by)
  values (v_tenant, v_loc, v_vid, v_qty, 'receipt', 'receipt', p_op_id, v_cost, auth.uid());

  perform public.write_audit('stock.receive', 'variant', v_vid, v_loc,
    jsonb_build_object('qty', v_qty, 'cost', v_cost));
  return public.finish_op(p_op_id, jsonb_build_object('variant_id', v_vid, 'applied_at', now()));
end;
$$;

-- ---------------------------------------------------------------------------
-- op_adjust_stock   p = { variant_id, counted (>= 0), reason: counted | damage | other, location_id? }
-- The difference is computed here from the current level, so a late sale or a retry never skews the count.
-- ---------------------------------------------------------------------------

create or replace function public.op_adjust_stock(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant  uuid;
  v_replay  jsonb;
  v_loc     uuid;
  v_vid     uuid;
  v_counted numeric;
  v_reason  text;
  v_now     numeric;
  v_delta   numeric;
  v_type    text;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  if public.catalog_write_mode() is distinct from 'full' then
    raise exception 'not allowed to change stock' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'count must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'adjust_stock');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);
  v_vid := (p ->> 'variant_id')::uuid;
  v_counted := (p ->> 'counted')::numeric;
  v_reason := coalesce(p ->> 'reason', 'counted');
  if v_counted is null or v_counted < 0 or v_counted >= 1000000000 then
    raise exception 'count is invalid' using errcode = '22023', hint = 'qty_invalid';
  end if;
  if v_reason not in ('counted', 'damage', 'other') then
    raise exception 'reason is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;
  if not exists (select 1 from public.product_variants v where v.id = v_vid and v.tenant_id = v_tenant) then
    raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
  end if;

  select l.qty_on_hand into v_now from public.stock_levels l
  where l.location_id = v_loc and l.variant_id = v_vid for update;
  v_delta := v_counted - coalesce(v_now, 0);

  if v_delta <> 0 then
    v_type := case when v_reason = 'damage' and v_delta < 0 then 'damage' else 'count_correction' end;
    insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id, created_by)
    values (v_tenant, v_loc, v_vid, v_delta, v_type, 'count', p_op_id, auth.uid());
    perform public.write_audit('stock.count', 'variant', v_vid, v_loc,
      jsonb_build_object('counted', v_counted, 'delta', v_delta, 'reason', v_reason));
  end if;

  return public.finish_op(p_op_id, jsonb_build_object('variant_id', v_vid, 'delta', v_delta, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_receive_stock(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_adjust_stock(uuid, jsonb) from public, anon, authenticated;


-- sync_push and sync_pull_pos, re-created with the new kinds and avg_cost

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
    ('stock_levels',    'location_id, variant_id, qty_on_hand, avg_cost, updated_at',
                        'updated_at', 'location_id::text || ''|'' || variant_id::text'),
    ('customers',       'id, name, phone, updated_at, deleted_at',
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

revoke execute on function public.sync_push(jsonb) from public, anon;
revoke execute on function public.sync_pull_pos(jsonb, int) from public, anon;
grant execute on function public.sync_push(jsonb) to authenticated;
grant execute on function public.sync_pull_pos(jsonb, int) to authenticated;
