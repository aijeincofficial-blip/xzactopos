-- F-13b Receive goods into a warehouse.
-- Until now stock could only be received into a STORE (op_receive_stock resolves a store) and the warehouse role was not
-- allowed to change stock at all, so a warehouse could only be filled by a transfer. This adds the op `receive_warehouse_stock`
-- through the same outbox/idempotency path (claim_op / finish_op, called from sync_push).
--
-- Who: the owner (superadmin) anywhere, a warehouse user in the warehouses they are assigned to (plan: purchasing.manage).
-- Store admins and cashiers are refused. The warehouse module and inventory must both be on.
-- Where: the location MUST be named and MUST be a warehouse (there is no "default warehouse": a tenant may have several).
-- Effects, all through the ledger: one `receipt` movement. The existing triggers route it to the RECEIVING bin when the warehouse
-- has bins, keep the bin invariant, and blend the average cost (an omitted cost leaves the average unchanged).
-- Payload: { location_id, variant_id, qty (> 0, < 1e9, fractional allowed), unit_cost? (>= 0, minor units) }.
-- Errors (hint): not_allowed, location_required, location_not_found, location_denied, not_a_warehouse, qty_invalid,
-- invalid_value, unknown_variant, op_id_reused. sync_push is copied from 20261108002500 with one extra `when`.

create or replace function public.op_receive_warehouse_stock(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_role   text;
  v_replay jsonb;
  v_loc    uuid;
  v_type   text;
  v_vid    uuid;
  v_qty    numeric;
  v_cost   bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();
  if v_role not in ('superadmin', 'warehouse') then
    raise exception 'not allowed to receive warehouse stock' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'stock entry must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'receive_warehouse_stock');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := nullif(p ->> 'location_id', '')::uuid;
  if v_loc is null then
    raise exception 'a warehouse is required' using errcode = '22023', hint = 'location_required';
  end if;
  select l.type into v_type
  from public.locations l
  where l.id = v_loc and l.tenant_id = v_tenant and l.active and l.deleted_at is null;
  if not found then
    raise exception 'location not found' using errcode = '22023', hint = 'location_not_found';
  end if;
  perform public.assert_location_access(v_loc);
  if v_type <> 'warehouse' then
    raise exception 'goods can only be received into a warehouse here' using errcode = '22023', hint = 'not_a_warehouse';
  end if;

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
    jsonb_build_object('qty', v_qty, 'cost', v_cost, 'warehouse', true));
  return public.finish_op(p_op_id,
    jsonb_build_object('variant_id', v_vid, 'location_id', v_loc, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_receive_warehouse_stock(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_push: newest definition (20261108002500) plus the new kind
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
        if (o -> 'payload' ->> 'location_id') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
          v_op_loc := (o -> 'payload' ->> 'location_id')::uuid;
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
