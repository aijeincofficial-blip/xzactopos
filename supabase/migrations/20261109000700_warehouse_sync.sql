-- F-13h H1 The phone's server side for warehouse staff.
--
-- 1. sync_push learns two kinds, so receipts made offline on a phone can be queued and replayed:
--      receive_po           lines of one delivery against an ordered purchase order   (payload: po_id, items, notes?, delivery_ref?)
--      receive_without_po   a walk-in delivery with no order                         (payload: warehouse_id, supplier_id?, items, notes?, delivery_ref?)
--    They are thin wrappers over the F-13d RPCs. The outbox op id IS the goods receipt id, so a replay is harmless
--    (`replay: true`) and one op id cannot be used for two different receipts (`id_conflict`). Every refusal keeps its stable
--    `hint` (location_denied, not_allowed, invalid_state, not_on_po, items_required, ...). Counts are NOT queued: a count line
--    is measured against the system quantity at the moment it is counted, which an offline queue cannot know (see F-13h card).
--    sync_push is copied from 20261109000200 (the newest definition) with those two `when` lines, and a refused op whose payload
--    names `warehouse_id` is now audited against that warehouse (before, only `location_id` was read).
--
-- 2. sync_pull_warehouse(cursors, limit): what a warehouse phone keeps on the device, in the same shape as sync_pull_pos
--    ({server_time, <table>: {rows, cursor, has_more}}), keyset paged by (updated_at, key) with the same 5 second hold-back:
--      warehouses         locations of type warehouse
--      bins, bin_stock_levels
--      stock_levels       warehouse locations only (stores keep using sync_pull_pos)
--      suppliers
--      purchase_orders    never drafts. The first pull sends only ordered and partly received orders; after that every change,
--                         including an order that is received or cancelled, so the phone can drop it. Lines are embedded.
--    It runs as the caller (security invoker), so row-level security decides the rows: a warehouse clerk gets only their own
--    warehouses, the owner gets all of them, a store admin or cashier gets nothing. The warehouse module must be on.

create or replace function public.op_receive_po(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'receipt must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;
  return public.receive_po(p_op_id, (p ->> 'po_id')::uuid, p -> 'items', p ->> 'notes', p ->> 'delivery_ref');
end;
$$;

create or replace function public.op_receive_without_po(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'receipt must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;
  return public.receive_without_po(p_op_id, (p ->> 'warehouse_id')::uuid, nullif(p ->> 'supplier_id', '')::uuid,
                                   p -> 'items', p ->> 'notes', p ->> 'delivery_ref');
end;
$$;

revoke execute on function public.op_receive_po(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_receive_without_po(uuid, jsonb) from public, anon, authenticated;

create or replace function public.sync_pull_warehouse(p_cursors jsonb default '{}'::jsonb, p_limit int default 500)
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
  v_ts     timestamptz;
  v_k      text;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  perform public.assert_module('warehouse');
  if p_limit is null or p_limit not between 1 and 1000 then
    raise exception 'limit must be 1 to 1000' using errcode = '22023', hint = 'invalid_value';
  end if;

  for r in select * from (values
    ('locations',        'warehouses',
       'id, code, name, bins_enabled, active, updated_at, deleted_at',
       'updated_at', 'id::text', 'type = ''warehouse'''),
    ('bins',             'bins',
       'id, warehouse_id, zone_id, code, aisle, rack, shelf, position, type, max_qty, active, updated_at, deleted_at',
       'updated_at', 'id::text', 'true'),
    ('bin_stock_levels', 'bin_stock_levels',
       'bin_id, variant_id, qty_on_hand, updated_at',
       'updated_at', 'bin_id::text || ''|'' || variant_id::text', 'true'),
    ('stock_levels',     'stock_levels',
       'location_id, variant_id, qty_on_hand, avg_cost, updated_at',
       'updated_at', 'location_id::text || ''|'' || variant_id::text',
       'location_id in (select l.id from public.locations l where l.type = ''warehouse'')'),
    ('suppliers',        'suppliers',
       'id, name, contact_name, phone, email, notes, updated_at, deleted_at',
       'updated_at', 'id::text', 'true')
  ) t(tbl, outname, cols, tscol, keyexpr, filter) loop
    v_cur := p_cursors -> r.outname;

    execute format($q$
      with s as (
        select %2$s, %3$s as _k
        from public.%1$I
        where tenant_id = $1
          and %5$s
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
    $q$, r.tbl, r.cols, r.keyexpr, r.tscol, r.filter)
    into v_more, v_rows, v_last
    using v_tenant, v_upto, v_cur ->> 'ts', v_cur ->> 'k', p_limit;

    v_out := v_out || jsonb_build_object(r.outname, jsonb_build_object(
      'rows', v_rows,
      'cursor', coalesce(v_last, v_cur),
      'has_more', v_more));
  end loop;

  -- purchase orders: never drafts; the first pull is the open ones; lines are embedded
  v_cur := p_cursors -> 'purchase_orders';
  v_ts := nullif(v_cur ->> 'ts', '')::timestamptz;
  v_k := v_cur ->> 'k';
  with s as (
    select po.*
    from public.purchase_orders po
    where po.tenant_id = v_tenant
      and po.status <> 'draft'
      and po.updated_at <= v_upto
      and ((v_ts is null and po.status in ('ordered', 'partly_received'))
           or (v_ts is not null and (po.updated_at, po.id::text) > (v_ts, v_k)))
    order by po.updated_at, po.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'po_no', g.po_no, 'warehouse_id', g.warehouse_id, 'supplier_id', g.supplier_id, 'status', g.status,
        'expected_at', g.expected_at, 'notes', g.notes, 'updated_at', g.updated_at,
        'items', coalesce((select jsonb_agg(jsonb_build_object(
                    'id', i.id, 'variant_id', i.variant_id, 'qty_ordered', i.qty_ordered, 'qty_received', i.qty_received,
                    'unit_cost', i.unit_cost) order by i.created_at, i.id)
                  from public.po_items i where i.po_id = g.id and i.tenant_id = g.tenant_id), '[]'::jsonb)
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;
  v_out := v_out || jsonb_build_object('purchase_orders', jsonb_build_object(
    'rows', v_rows, 'cursor', coalesce(v_last, v_cur), 'has_more', v_more));

  return v_out;
end;
$$;

revoke execute on function public.sync_pull_warehouse(jsonb, int) from public, anon;
grant execute on function public.sync_pull_warehouse(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- sync_push: newest definition (20261109000200) plus receive_po and receive_without_po
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
