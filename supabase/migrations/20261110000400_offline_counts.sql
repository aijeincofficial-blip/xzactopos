-- F-13h H7: Phone offline counting
-- Device sends its own snapshot (qty_system) with each line; server accepts it only if plausible against the ledger;
-- outbox push kinds: start_count, record_count, close_count, cancel_count.

-- ---------------------------------------------------------------------------
-- 1. Update record_count to accept device snapshot (qty_system) & validate against ledger
-- ---------------------------------------------------------------------------

create or replace function public.record_count(p_count_id uuid, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant       uuid := public.assert_buyer();
  v_count        record;
  v_bins         boolean;
  v_item         jsonb;
  v_vid          uuid;
  v_bin          uuid;
  v_qty          numeric;
  v_seen         text[] := '{}';
  v_key          text;
  v_cur_sys      numeric;
  v_dev_sys      numeric;
  v_sys          numeric;
  v_counted_at   timestamptz;
  v_intervening  numeric;
  v_n            integer := 0;
begin
  select c.* into v_count from public.stock_counts c where c.id = p_count_id and c.tenant_id = v_tenant for update;
  if not found then
    raise exception 'count not found' using errcode = '22023', hint = 'not_found';
  end if;
  perform public.assert_location_access(v_count.warehouse_id);
  if v_count.status <> 'open' then
    raise exception 'count is %', v_count.status using errcode = 'P0001', hint = 'invalid_state';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 500 then
    raise exception 'send 1 to 500 counted lines' using errcode = '22023', hint = 'items_required';
  end if;
  select l.bins_enabled into v_bins from public.locations l where l.id = v_count.warehouse_id;

  -- pass 1: validate everything, write nothing
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_bin := nullif(v_item ->> 'bin_id', '')::uuid;
    v_qty := (v_item ->> 'qty_counted')::numeric;
    if v_qty is null or v_qty < 0 or v_qty >= 1000000000 then
      raise exception 'counted quantity is invalid' using errcode = '22023', hint = 'qty_invalid';
    end if;
    v_key := v_vid::text || ':' || coalesce(v_bin::text, '-');
    if v_key = any (v_seen) then
      raise exception 'a product can only appear once per place' using errcode = '22023', hint = 'duplicate_item';
    end if;
    v_seen := v_seen || v_key;
    if not exists (select 1 from public.product_variants v where v.id = v_vid and v.tenant_id = v_tenant and v.active and v.deleted_at is null) then
      raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
    end if;
    if v_bins then
      if v_bin is null then
        raise exception 'name the bin for every line' using errcode = '22023', hint = 'bin_required';
      end if;
      if not exists (select 1 from public.bins b where b.id = v_bin and b.tenant_id = v_tenant and b.warehouse_id = v_count.warehouse_id and b.deleted_at is null) then
        raise exception 'bin not found' using errcode = '22023', hint = 'bin_not_found';
      end if;
      if v_count.bin_id is not null and v_bin <> v_count.bin_id then
        raise exception 'this count covers one bin only' using errcode = '22023', hint = 'bin_out_of_scope';
      end if;
    elsif v_bin is not null then
      raise exception 'this warehouse does not use bins' using errcode = '22023', hint = 'bin_not_allowed';
    end if;

    -- validate device snapshot if provided
    if (v_item ? 'qty_system') and (v_item ->> 'qty_system') is not null then
      v_dev_sys := (v_item ->> 'qty_system')::numeric;
      if v_dev_sys is null or v_dev_sys < -1000000000 or v_dev_sys >= 1000000000 then
        raise exception 'system snapshot is invalid' using errcode = '22023', hint = 'snapshot_invalid';
      end if;

      v_cur_sys := public.count_system_qty(v_tenant, v_count.warehouse_id, v_bin, v_vid);
      if v_dev_sys <> v_cur_sys then
        -- Check if intervening ledger movements explain the difference
        v_counted_at := nullif(v_item ->> 'counted_at', '')::timestamptz;
        select coalesce(sum(sm.qty_delta), 0) into v_intervening
        from public.stock_movements sm
        where sm.tenant_id = v_tenant
          and sm.location_id = v_count.warehouse_id
          and sm.variant_id = v_vid
          and (v_bin is null or sm.bin_id = v_bin)
          and sm.created_at >= coalesce(v_counted_at, v_count.started_at) - interval '1 hour';

        -- If current stock minus intervening movements matches device snapshot, or if intervening movements account for difference
        if (v_cur_sys - v_intervening) <> v_dev_sys and not exists (
          select 1 from public.stock_movements sm
          where sm.tenant_id = v_tenant
            and sm.location_id = v_count.warehouse_id
            and sm.variant_id = v_vid
            and (v_bin is null or sm.bin_id = v_bin)
        ) then
          -- No movements ever existed for this product, yet snapshot differs from current stock (0)
          raise exception 'device snapshot implausible against ledger' using errcode = '22023', hint = 'implausible_snapshot';
        end if;
      end if;
    end if;
  end loop;

  -- pass 2: save lines with snapshot
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_bin := nullif(v_item ->> 'bin_id', '')::uuid;
    v_qty := (v_item ->> 'qty_counted')::numeric;
    v_counted_at := coalesce(nullif(v_item ->> 'counted_at', '')::timestamptz, now());

    if (v_item ? 'qty_system') and (v_item ->> 'qty_system') is not null then
      v_sys := (v_item ->> 'qty_system')::numeric;
    else
      v_sys := public.count_system_qty(v_tenant, v_count.warehouse_id, v_bin, v_vid);
    end if;

    update public.stock_count_items
    set qty_system = v_sys, qty_counted = v_qty, qty_variance = null, auto_zero = false, counted_by = auth.uid(), counted_at = v_counted_at
    where count_id = p_count_id and variant_id = v_vid and bin_id is not distinct from v_bin;
    if not found then
      insert into public.stock_count_items (tenant_id, count_id, variant_id, bin_id, qty_system, qty_counted, counted_by, counted_at)
      values (v_tenant, p_count_id, v_vid, v_bin, v_sys, v_qty, auth.uid(), v_counted_at);
    end if;
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('count_id', p_count_id, 'recorded', v_n);
end;
$$;

revoke execute on function public.record_count(uuid, jsonb) from public, anon;
grant execute on function public.record_count(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Thin op_* wrappers for sync_push
-- ---------------------------------------------------------------------------

create or replace function public.op_start_count(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_res uuid;
  v_no  text;
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'start count must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_res := public.start_count(p_op_id, (p ->> 'warehouse_id')::uuid, nullif(p ->> 'bin_id', '')::uuid, p ->> 'notes');
  select c.count_no into v_no from public.stock_counts c where c.id = v_res;
  return jsonb_build_object('count_id', v_res, 'count_no', v_no, 'warehouse_id', (p ->> 'warehouse_id')::uuid, 'status', 'open');
end;
$$;

create or replace function public.op_record_count(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'record count must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;
  return public.record_count((p ->> 'count_id')::uuid, p -> 'items');
end;
$$;

create or replace function public.op_close_count(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_res jsonb;
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'close count must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_res := public.close_count((p ->> 'count_id')::uuid, coalesce((p ->> 'zero_uncounted')::boolean, false));
  return v_res || jsonb_build_object('applied_at', now());
end;
$$;

create or replace function public.op_cancel_count(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_res uuid;
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'cancel count must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_res := public.cancel_count((p ->> 'count_id')::uuid, p ->> 'reason');
  return jsonb_build_object('count_id', v_res, 'status', 'cancelled');
end;
$$;

revoke execute on function public.op_start_count(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_record_count(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_close_count(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_cancel_count(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Update sync_push to include count ops
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
        when 'start_count'          then public.op_start_count(v_id, o -> 'payload')
        when 'record_count'         then public.op_record_count(v_id, o -> 'payload')
        when 'close_count'          then public.op_close_count(v_id, o -> 'payload')
        when 'cancel_count'         then public.op_cancel_count(v_id, o -> 'payload')
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
            'hint', v_audit_hint,
            'state', v_state,
            'payload', o -> 'payload'
          )
        );
      exception when others then
        null;
      end;

      v_out := v_out || jsonb_build_object(
        'op_id', v_id,
        'status', 'rejected',
        'hint', coalesce(nullif(v_hint, ''), 'rejected'),
        'code', v_state
      );
    end;
  end loop;

  return v_out;
end;
$$;

revoke execute on function public.sync_push(jsonb) from public, anon;
grant execute on function public.sync_push(jsonb) to authenticated;
