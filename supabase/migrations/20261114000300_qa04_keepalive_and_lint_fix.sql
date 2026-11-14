-- 20261114000300_qa04_keepalive_and_lint_fix.sql
-- Pure automatic hardening & SQL lint cleanup following QA-04:
--   1. health_ping(): allow service_role caller (matching keep-alive CI workflow) while
--      keeping anon revoked and enforcing assert_active_user() for authenticated callers.
--   2. S12 op_return_sale_items(): replace runtime temp table _ret_lines with PL/pgSQL
--      jsonb array (jsonb_to_recordset) so `supabase db lint -s public` exits with 0 errors.

create or replace function public.health_ping()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    perform public.assert_active_user();
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', 'healthy',
    'timestamp', now(),
    'version', '1.0.0'
  );
end;
$$;

revoke execute on function public.health_ping() from public, anon;
grant execute on function public.health_ping() to authenticated, service_role;

create or replace function public.op_return_sale_items(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant           uuid;
  v_replay           jsonb;
  v_sale             public.sales;
  v_sid              uuid;
  v_return_id        uuid;
  v_method           text;
  v_reason           text;
  v_returned_at      timestamptz;
  v_is_super         boolean;
  v_can_void_own     boolean;
  v_max_void_amt     bigint;
  v_tz               text;
  v_day              date;
  v_appr             uuid := null;
  v_item             jsonb;
  v_vid              uuid;
  v_req_qty          numeric;
  v_sold_qty         numeric;
  v_prev_qty         numeric;
  v_rem_qty          numeric;
  v_take             numeric;
  v_si               record;
  v_si_prev_qty      numeric;
  v_si_prev_sub      bigint;
  v_si_prev_tax      bigint;
  v_line_sub         bigint;
  v_line_disc        bigint;
  v_line_tax         bigint;
  v_line_ref         bigint;
  v_sub_refund       bigint := 0;
  v_disc_refund      bigint := 0;
  v_tax_refund       bigint := 0;
  v_total_refund     bigint := 0;
  v_cogs_refund      bigint := 0;
  v_prev_sub_all     bigint := 0;
  v_prev_disc_all    bigint := 0;
  v_prev_tax_all     bigint := 0;
  v_total_sold_units numeric := 0;
  v_total_prev_units numeric := 0;
  v_total_req_units  numeric := 0;
  v_track            boolean;
  v_seen_variants    uuid[] := '{}'::uuid[];
  v_ret_lines        jsonb := '[]'::jsonb;
begin
  perform public.assert_seller();
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object'
     or jsonb_typeof(p -> 'items') is distinct from 'array' then
    raise exception 'return payload must be an object with items' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'return_sale_items');
  if v_replay is not null then
    return v_replay;
  end if;

  v_sid := (p ->> 'sale_id')::uuid;
  if v_sid is null then
    raise exception 'sale_id is required' using errcode = '22023', hint = 'id_required';
  end if;

  select * into v_sale from public.sales where id = v_sid and tenant_id = v_tenant for update;
  if not found then
    raise exception 'sale not found' using errcode = '22023', hint = 'sale_not_found';
  end if;

  if not public.has_location_access(v_sale.location_id) then
    raise exception 'not allowed to return sales here' using errcode = '42501', hint = 'not_allowed';
  end if;

  if v_sale.status = 'voided' then
    raise exception 'cannot return items from a voided sale' using errcode = '22023', hint = 'sale_voided';
  end if;

  v_method := coalesce(nullif(btrim(p ->> 'refund_method'), ''), 'cash');
  if v_method not in ('cash', 'utang', 'ewallet', 'card') then
    raise exception 'invalid refund method' using errcode = '22023', hint = 'invalid_value';
  end if;
  if v_method = 'utang' and v_sale.customer_id is null then
    raise exception 'utang refund requires a customer on the sale' using errcode = '22023', hint = 'customer_required';
  end if;

  if jsonb_array_length(p -> 'items') not between 1 and 200 then
    raise exception 'a return needs 1 to 200 items' using errcode = '22023', hint = 'items_required';
  end if;

  v_reason := left(nullif(btrim(p ->> 'reason'), ''), 200);
  v_returned_at := coalesce((p ->> 'returned_at')::timestamptz, now());
  v_return_id := coalesce((p ->> 'id')::uuid, public.uuid_generate_v7());

  -- Pre-validate all requested lines & compute aggregate quantities
  for v_item in select * from jsonb_array_elements(p -> 'items') loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_req_qty := (v_item ->> 'qty')::numeric;
    if v_vid is null or v_req_qty is null or v_req_qty <= 0 or v_req_qty >= 1000000000 then
      raise exception 'return quantity must be above zero' using errcode = '22023', hint = 'qty_invalid';
    end if;
    if v_vid = any(v_seen_variants) then
      raise exception 'duplicate variant in return payload' using errcode = '22023', hint = 'invalid_value';
    end if;
    v_seen_variants := array_append(v_seen_variants, v_vid);

    select coalesce(sum(qty), 0) into v_sold_qty
      from public.sale_items
     where tenant_id = v_tenant and sale_id = v_sid and variant_id = v_vid;
    if v_sold_qty <= 0 then
      raise exception 'item was not part of this sale' using errcode = '22023', hint = 'unknown_variant';
    end if;

    select coalesce(sum(qty), 0) into v_prev_qty
      from public.sale_return_items
     where tenant_id = v_tenant and sale_id = v_sid and variant_id = v_vid;

    if v_prev_qty + v_req_qty > v_sold_qty then
      raise exception 'return quantity exceeds remaining sold quantity' using errcode = '22023', hint = 'return_exceeds_sold';
    end if;

    v_total_req_units := v_total_req_units + v_req_qty;
  end loop;

  select coalesce(sum(qty), 0) into v_total_sold_units
    from public.sale_items where tenant_id = v_tenant and sale_id = v_sid;
  select coalesce(sum(subtotal_refund), 0), coalesce(sum(discount_refund), 0),
         coalesce(sum(tax_refund), 0)
    into v_prev_sub_all, v_prev_disc_all, v_prev_tax_all
    from public.sale_returns where tenant_id = v_tenant and sale_id = v_sid;
  select coalesce(sum(qty), 0) into v_total_prev_units
    from public.sale_return_items where tenant_id = v_tenant and sale_id = v_sid;

  for v_item in select * from jsonb_array_elements(p -> 'items') loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_rem_qty := (v_item ->> 'qty')::numeric;

    select pr.track_stock into v_track
      from public.product_variants pv
      join public.products pr on pr.tenant_id = pv.tenant_id and pr.id = pv.product_id
     where pv.tenant_id = v_tenant and pv.id = v_vid;
    v_track := coalesce(v_track, false);

    for v_si in
      select * from public.sale_items
       where tenant_id = v_tenant and sale_id = v_sid and variant_id = v_vid
       order by created_at, id
    loop
      exit when v_rem_qty <= 0;

      select coalesce(sum(qty), 0), coalesce(sum(tax_refund), 0)
        into v_si_prev_qty, v_si_prev_tax
        from public.sale_return_items
       where tenant_id = v_tenant and sale_item_id = v_si.id;

      if v_si_prev_qty >= v_si.qty then
        continue;
      end if;

      v_take := least(v_rem_qty, v_si.qty - v_si_prev_qty);

      -- Pro-rata line subtotal (before cart-level discount)
      if v_si_prev_qty + v_take = v_si.qty then
        -- Compute previous line_sub for exact remainder
        v_si_prev_sub := round(v_si.line_total * (v_si_prev_qty / v_si.qty))::bigint;
        v_line_sub := greatest(0, v_si.line_total - v_si_prev_sub);
        v_line_tax := greatest(0, v_si.tax - v_si_prev_tax);
      else
        v_line_sub := round(v_si.line_total * (v_take / v_si.qty))::bigint;
        v_line_tax := round(v_si.tax * (v_take / v_si.qty))::bigint;
      end if;

      if v_sale.subtotal > 0 and v_sale.discount > 0 then
        v_line_disc := least(v_line_sub, round(v_sale.discount * (v_line_sub::numeric / v_sale.subtotal))::bigint);
      else
        v_line_disc := 0;
      end if;
      v_line_ref := greatest(0, v_line_sub - v_line_disc);

      v_ret_lines := v_ret_lines || jsonb_build_array(
        jsonb_build_object(
          'sale_item_id', v_si.id,
          'variant_id', v_vid,
          'product_name', v_si.product_name,
          'qty', v_take::numeric(12, 3),
          'unit_price', v_si.unit_price,
          'unit_cost', v_si.unit_cost,
          'line_sub', v_line_sub,
          'line_disc', v_line_disc,
          'line_tax', v_line_tax,
          'line_ref', v_line_ref,
          'track_stock', v_track
        )
      );

      v_sub_refund := v_sub_refund + v_line_sub;
      v_disc_refund := v_disc_refund + v_line_disc;
      v_tax_refund := v_tax_refund + v_line_tax;
      v_total_refund := v_total_refund + v_line_ref;
      v_cogs_refund := v_cogs_refund + round(v_si.unit_cost * v_take)::bigint;
      v_rem_qty := v_rem_qty - v_take;
    end loop;
  end loop;

  -- Exact penny reconciliation when all remaining units on the sale are now returned
  if v_total_prev_units + v_total_req_units = v_total_sold_units then
    v_sub_refund := greatest(0, v_sale.subtotal - v_prev_sub_all);
    v_disc_refund := least(v_sub_refund, greatest(0, v_sale.discount - v_prev_disc_all));
    v_tax_refund := greatest(0, v_sale.tax - v_prev_tax_all);
    v_total_refund := v_sub_refund - v_disc_refund;
  end if;

  -- Permission & supervisor PIN check (mirrors op_void_sale)
  select coalesce(timezone, 'Asia/Manila') into v_tz from public.tenants where id = v_tenant;
  v_is_super := public.has_location_access(v_sale.location_id, 'supervisor');

  if not v_is_super then
    if public.auth_role() is distinct from 'cashier' then
      raise exception 'not allowed to return sales here' using errcode = '42501', hint = 'not_allowed';
    end if;

    select coalesce(cashier_can_void_own, false), coalesce(max_cashier_void_amount, 50000)
      into v_can_void_own, v_max_void_amt
      from public.tenant_settings
     where tenant_id = v_tenant;

    if v_sale.created_by is distinct from auth.uid() then
      raise exception 'cashier may only return own sales' using errcode = '42501', hint = 'not_allowed';
    end if;

    if (v_sale.sold_at at time zone v_tz)::date <> (now() at time zone v_tz)::date then
      raise exception 'cashier can only return sales from today' using errcode = '42501', hint = 'not_allowed';
    end if;

    if (not v_can_void_own) or (v_total_refund > v_max_void_amt) or (p ->> 'approval_id') is not null or (p -> 'offline_approval') is not null then
      v_appr := public.consume_supervisor_approval(v_sale.location_id, 'void_sale', v_sid, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval');
    end if;
  elsif (p ->> 'approval_id') is not null or (p -> 'offline_approval') is not null then
    v_appr := public.consume_supervisor_approval(v_sale.location_id, 'void_sale', v_sid, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval');
  end if;

  insert into public.sale_returns (
    id, tenant_id, location_id, sale_id, client_op_id, refund_method,
    subtotal_refund, discount_refund, tax_refund, refund_total,
    reason, returned_at, created_by, approved_by
  ) values (
    v_return_id, v_tenant, v_sale.location_id, v_sid, p_op_id, v_method,
    v_sub_refund, v_disc_refund, v_tax_refund, v_total_refund,
    v_reason, v_returned_at, auth.uid(), v_appr
  );

  insert into public.sale_return_items (
    tenant_id, return_id, sale_id, sale_item_id, location_id, variant_id,
    product_name, qty, unit_price, unit_cost, refund_amount, tax_refund
  )
  select v_tenant, v_return_id, v_sid, r.sale_item_id, v_sale.location_id, r.variant_id,
         r.product_name, r.qty, r.unit_price, r.unit_cost, r.line_ref, r.line_tax
    from jsonb_to_recordset(v_ret_lines) as r(
      sale_item_id uuid,
      variant_id   uuid,
      product_name text,
      qty          numeric(12, 3),
      unit_price   bigint,
      unit_cost    bigint,
      line_sub     bigint,
      line_disc    bigint,
      line_tax     bigint,
      line_ref     bigint,
      track_stock  boolean
    );

  -- Restore stock for tracked items
  insert into public.stock_movements (
    tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id,
    unit_cost, occurred_at, created_by
  )
  select v_tenant, v_sale.location_id, r.variant_id, sum(r.qty), 'sale_return', 'sale_return', v_return_id,
         max(r.unit_cost), v_returned_at, auth.uid()
    from jsonb_to_recordset(v_ret_lines) as r(
      sale_item_id uuid,
      variant_id   uuid,
      product_name text,
      qty          numeric(12, 3),
      unit_price   bigint,
      unit_cost    bigint,
      line_sub     bigint,
      line_disc    bigint,
      line_tax     bigint,
      line_ref     bigint,
      track_stock  boolean
    )
   where r.track_stock
   group by r.variant_id;

  -- Credit customer utang balance when refunded to utang
  if v_method = 'utang' and v_total_refund > 0 and v_sale.customer_id is not null then
    insert into public.customer_ledger (
      tenant_id, customer_id, kind, amount, sale_id, note, occurred_at, created_by, location_id
    ) values (
      v_tenant, v_sale.customer_id, 'adjust', -v_total_refund, v_sid,
      coalesce(v_reason, 'return'), v_returned_at, auth.uid(), v_sale.location_id
    );
  end if;

  -- Adjust daily_sales_summary & daily_item_sales on return business day
  v_day := (v_returned_at at time zone v_tz)::date;

  insert into public.daily_sales_summary as d
    (tenant_id, location_id, day, gross, discount, net, tax, cogs, txn_count, cash, ewallet, card, utang, updated_at)
  values (
    v_tenant, v_sale.location_id, v_day,
    -v_sub_refund, -v_disc_refund, -v_total_refund, -v_tax_refund, -v_cogs_refund, 0,
    case when v_method = 'cash'    then -v_total_refund else 0 end,
    case when v_method = 'ewallet' then -v_total_refund else 0 end,
    case when v_method = 'card'    then -v_total_refund else 0 end,
    case when v_method = 'utang'   then -v_total_refund else 0 end,
    now()
  )
  on conflict (location_id, day) do update set
    gross = d.gross + excluded.gross,
    discount = d.discount + excluded.discount,
    net = d.net + excluded.net,
    tax = d.tax + excluded.tax,
    cogs = d.cogs + excluded.cogs,
    cash = d.cash + excluded.cash,
    ewallet = d.ewallet + excluded.ewallet,
    card = d.card + excluded.card,
    utang = d.utang + excluded.utang,
    updated_at = now();

  insert into public.daily_item_sales as d (tenant_id, location_id, day, variant_id, product_name, qty, revenue, cogs)
  select v_tenant, v_sale.location_id, v_day, r.variant_id, max(r.product_name),
         -sum(r.qty), -sum(r.line_ref)::bigint, -sum(round(r.unit_cost * r.qty))::bigint
    from jsonb_to_recordset(v_ret_lines) as r(
      sale_item_id uuid,
      variant_id   uuid,
      product_name text,
      qty          numeric(12, 3),
      unit_price   bigint,
      unit_cost    bigint,
      line_sub     bigint,
      line_disc    bigint,
      line_tax     bigint,
      line_ref     bigint,
      track_stock  boolean
    )
   group by r.variant_id
  on conflict (location_id, day, variant_id) do update set
    qty = d.qty + excluded.qty,
    revenue = d.revenue + excluded.revenue,
    cogs = d.cogs + excluded.cogs;

  perform public.write_audit(
    'sale.return', 'sale_return', v_return_id, v_sale.location_id,
    jsonb_strip_nulls(jsonb_build_object(
      'sale_id', v_sid,
      'no', coalesce(v_sale.sale_no, v_sale.local_no),
      'refund_total', v_total_refund,
      'refund_method', v_method,
      'approved_by', v_appr
    ))
  );

  return public.finish_op(
    p_op_id,
    jsonb_build_object(
      'return_id', v_return_id,
      'sale_id', v_sid,
      'refund_total', v_total_refund,
      'refund_method', v_method,
      'applied_at', now()
    )
  );
end;
$$;

revoke execute on function public.op_return_sale_items(uuid, jsonb) from public, anon, authenticated;
