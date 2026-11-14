-- QA-03: Performance & Free-Tier Optimisation
-- 1. Missing composite & partial indexes on hot sync, POS, warehouse, and report tables
-- 2. Bounded delta range predicates & tenant filters on all sync_pull_* RPCs
-- 3. SECURITY DEFINER single-initplan consolidation & sargable date filters on report_summary / report_multi_store
-- 4. Server-aggregated customer_utang_balances() RPC to eliminate 50k ledger client pulls

-- ---------------------------------------------------------------------------
-- 1. Hot-path indexes
-- ---------------------------------------------------------------------------
create index if not exists bins_tenant_updated_idx
  on public.bins (tenant_id, updated_at, id);

create index if not exists bin_stock_levels_tenant_updated_idx
  on public.bin_stock_levels (tenant_id, updated_at, bin_id, variant_id);

create index if not exists locations_tenant_updated_idx
  on public.locations (tenant_id, updated_at, id);

create index if not exists purchase_orders_tenant_updated_idx
  on public.purchase_orders (tenant_id, updated_at, id);

create index if not exists sales_tenant_updated_idx
  on public.sales (tenant_id, updated_at, id);

create index if not exists sales_tenant_loc_sold_idx
  on public.sales (tenant_id, location_id, sold_at desc, id);

create index if not exists payments_tenant_sale_cash_idx
  on public.payments (tenant_id, sale_id) include (amount)
  where method = 'cash';

create index if not exists stock_levels_tenant_loc_variant_idx
  on public.stock_levels (tenant_id, location_id, variant_id);

create index if not exists stock_levels_tenant_neg_idx
  on public.stock_levels (tenant_id, location_id, variant_id)
  where qty_on_hand < 0;

create index if not exists stock_movements_tenant_loc_var_created_idx
  on public.stock_movements (tenant_id, location_id, variant_id, created_at desc);

create index if not exists variant_prices_tenant_variant_idx
  on public.variant_prices (tenant_id, variant_id);

create index if not exists variant_prices_tenant_updated_key_idx
  on public.variant_prices (tenant_id, updated_at, variant_id, currency);

create index if not exists product_variants_tenant_product_idx
  on public.product_variants (tenant_id, product_id);

create index if not exists daily_item_sales_tenant_loc_day_idx
  on public.daily_item_sales (tenant_id, location_id, day);

create index if not exists transfers_tenant_created_idx
  on public.transfers (tenant_id, created_at);

create index if not exists customers_tenant_active_name_idx
  on public.customers (tenant_id, name, id)
  where deleted_at is null;

create index if not exists customer_ledger_tenant_cust_amt_idx
  on public.customer_ledger (tenant_id, customer_id) include (amount);

-- ---------------------------------------------------------------------------
-- 2. sync_pull_* RPC optimizations (explicit lower timestamp bounds + tenant filters)
-- ---------------------------------------------------------------------------
create or replace function public.sync_pull_catalog(p_cursors jsonb default '{}'::jsonb, p_limit integer default 500)
 returns jsonb
 language plpgsql
 stable
 set search_path to ''
as $function$
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
  if not exists (
    select 1 from public.tenant_modules m
    where m.tenant_id = v_tenant and m.deleted_at is null and (m.inventory or m.pos or m.warehouse)
  ) then
    raise exception 'required module is not enabled' using errcode = '42501', hint = 'module_disabled';
  end if;
  if p_limit is null or p_limit not between 1 and 1000 then
    raise exception 'limit must be 1 to 1000' using errcode = '22023', hint = 'invalid_value';
  end if;

  for r in select * from (values
    ('categories',       'id, parent_id, name, updated_at, deleted_at',
                         'id::text'),
    ('products',         'id, category_id, name, unit, tax_rate, track_stock, active, photo_path, updated_at, deleted_at',
                         'id::text'),
    ('product_variants', 'id, product_id, name, sku, barcode, is_default, cost, reorder_point, active, '
                         'breaks_into_variant_id, breaks_into_qty, updated_at, deleted_at',
                         'id::text'),
    ('variant_prices',   'variant_id, currency, price, updated_at, deleted_at',
                         'variant_id::text || ''|'' || currency')
  ) t(tbl, cols, keyexpr) loop
    v_cur := p_cursors -> r.tbl;

    execute format($q$
      with s as (
        select %2$s, %3$s as _k
        from public.%1$I
        where tenant_id = $1
          and updated_at <= $2
          and ($3::timestamptz is null or (updated_at >= $3::timestamptz and (updated_at, %3$s) > ($3::timestamptz, $4::text)))
        order by updated_at, _k
        limit $5 + 1
      ), page as (
        select * from s order by updated_at, _k limit $5
      )
      select
        (select count(*) from s) > $5,
        coalesce((select jsonb_agg(to_jsonb(page) - '_k' order by page.updated_at, page._k) from page), '[]'::jsonb),
        (select jsonb_build_object('ts', page.updated_at, 'k', page._k) from page order by page.updated_at desc, page._k desc limit 1)
    $q$, r.tbl, r.cols, r.keyexpr)
    into v_more, v_rows, v_last
    using v_tenant, v_upto, nullif(v_cur ->> 'ts', ''), v_cur ->> 'k', p_limit;

    v_out := v_out || jsonb_build_object(r.tbl, jsonb_build_object(
      'rows', v_rows,
      'cursor', coalesce(v_last, v_cur),
      'has_more', v_more));
  end loop;

  return v_out;
end;
$function$;

create or replace function public.sync_pull_pos(p_cursors jsonb default '{}'::jsonb, p_limit integer default 500)
 returns jsonb
 language plpgsql
 stable
 set search_path to ''
as $function$
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
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if p_limit is null or p_limit not between 1 and 1000 then
    raise exception 'limit must be 1 to 1000' using errcode = '22023', hint = 'invalid_value';
  end if;

  for r in select * from (values
    ('stock_levels',    'location_id, variant_id, qty_on_hand, avg_cost, counted, updated_at',
                        'updated_at', 'location_id::text || ''|'' || variant_id::text'),
    ('customers',       'id, name, phone, due_on, updated_at, deleted_at',
                        'updated_at', 'id::text'),
    ('customer_ledger', 'id, customer_id, kind, amount, sale_id, note, occurred_at, created_at, location_id, method',
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
          and ($3::timestamptz is null or (%4$I >= $3::timestamptz and (%4$I, %3$s) > ($3::timestamptz, $4::text)))
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
    using v_tenant, v_upto, nullif(v_cur ->> 'ts', ''), v_cur ->> 'k', p_limit;

    v_out := v_out || jsonb_build_object(r.tbl, jsonb_build_object(
      'rows', v_rows,
      'cursor', coalesce(v_last, v_cur),
      'has_more', v_more));
  end loop;

  return v_out;
end;
$function$;

create or replace function public.sync_pull_warehouse(p_cursors jsonb default '{}'::jsonb, p_limit integer default 500)
 returns jsonb
 language plpgsql
 stable
 set search_path to ''
as $function$
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
       'location_id in (select l.id from public.locations l where l.tenant_id = $1 and l.type = ''warehouse'')'),
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
          and ($3::timestamptz is null or (%4$I >= $3::timestamptz and (%4$I, %3$s) > ($3::timestamptz, $4::text)))
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
    using v_tenant, v_upto, nullif(v_cur ->> 'ts', ''), v_cur ->> 'k', p_limit;

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
           or (v_ts is not null and po.updated_at >= v_ts and (po.updated_at, po.id::text) > (v_ts, v_k)))
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
$function$;

create or replace function public.sync_pull_sales(p_cursor jsonb default null::jsonb, p_limit integer default 100)
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to ''
as $function$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_locs   uuid[] := coalesce(public.auth_location_ids(), '{}'::uuid[]);
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
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.*
    from public.sales x
    where x.tenant_id = v_tenant
      and x.location_id = any (v_locs)
      and x.updated_at <= v_upto
      and ((v_ts is null and x.sold_at >= now() - interval '30 days')
           or (v_ts is not null and x.updated_at >= v_ts and (x.updated_at, x.id::text) > (v_ts, v_k)))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'local_no', g.local_no, 'sale_no', g.sale_no, 'device_id', g.device_id,
        'status', g.status, 'subtotal', g.subtotal,
        'discount', g.discount, 'tax', g.tax, 'total', g.total, 'customer_id', g.customer_id, 'sold_at', g.sold_at,
        'voided_at', g.voided_at, 'void_reason', g.void_reason, 'updated_at', g.updated_at,
        'items', coalesce((select jsonb_agg(jsonb_build_object(
                    'variant_id', i.variant_id, 'name', i.product_name, 'qty', i.qty, 'unit_price', i.unit_price,
                    'unit_cost', i.unit_cost, 'discount', i.discount, 'tax', i.tax, 'line_total', i.line_total,
                    'tracked', coalesce(pr.track_stock, true)) order by i.created_at, i.id)
                  from public.sale_items i
                  left join public.product_variants v on v.id = i.variant_id and v.tenant_id = i.tenant_id
                  left join public.products pr on pr.id = v.product_id and pr.tenant_id = v.tenant_id
                  where i.tenant_id = g.tenant_id and i.sale_id = g.id), '[]'::jsonb),
        'payments', coalesce((select jsonb_agg(jsonb_build_object(
                    'method', p.method, 'amount', p.amount, 'tendered', p.tendered, 'reference', p.reference,
                    'wallet', p.wallet)
                    order by p.created_at, p.id)
                  from public.payments p
                  where p.tenant_id = g.tenant_id and p.sale_id = g.id), '[]'::jsonb)
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$function$;
revoke execute on function public.sync_pull_sales(jsonb, integer) from public, anon;
grant execute on function public.sync_pull_sales(jsonb, integer) to authenticated;

create or replace function public.sync_pull_conversions(p_cursor jsonb default null::jsonb, p_limit integer default 100)
 returns jsonb
 language plpgsql
 stable
 set search_path to ''
as $function$
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
  perform public.assert_module('inventory');
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.id, x.location_id, x.pack_variant_id, x.piece_variant_id, x.packs, x.ratio, x.pieces, x.pack_cost,
           x.total_cost, x.piece_cost, x.note, x.converted_at, x.created_by, x.voided_at, x.void_reason, x.updated_at
    from public.conversions x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and ((v_ts is null and x.converted_at >= now() - interval '30 days')
           or (v_ts is not null and x.updated_at >= v_ts and (x.updated_at, x.id::text) > (v_ts, v_k)))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'pack_variant_id', g.pack_variant_id,
        'piece_variant_id', g.piece_variant_id, 'packs', g.packs, 'ratio', g.ratio, 'pieces', g.pieces,
        'pack_cost', g.pack_cost, 'total_cost', g.total_cost, 'piece_cost', g.piece_cost, 'note', g.note,
        'converted_at', g.converted_at, 'created_by', g.created_by, 'voided_at', g.voided_at,
        'void_reason', g.void_reason, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more,
                            'server_time', now());
end;
$function$;

create or replace function public.sync_pull_day_closes(p_cursor jsonb default null::jsonb, p_limit integer default 100)
 returns jsonb
 language plpgsql
 stable
 set search_path to ''
as $function$
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
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.id, x.location_id, x.day, x.currency, x.opening_cash, x.expected_cash, x.counted_cash, x.difference,
           x.server_expected_cash, x.note, x.closed_by, x.approved_by, x.closed_at, x.updated_at
    from public.day_closes x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and ((v_ts is null and x.closed_at >= now() - interval '30 days')
           or (v_ts is not null and x.updated_at >= v_ts and (x.updated_at, x.id::text) > (v_ts, v_k)))
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
$function$;

create or replace function public.sync_pull_expenses(p_cursor jsonb default null::jsonb, p_limit integer default 100)
 returns jsonb
 language plpgsql
 stable
 set search_path to ''
as $function$
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
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.id, x.location_id, x.amount, x.currency, x.category, x.note, x.paid_from, x.wallet, x.spent_at, x.created_by,
           x.approved_by, x.voided_at, x.void_reason, x.void_approved_by, x.updated_at
    from public.expenses x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and ((v_ts is null and x.spent_at >= now() - interval '30 days')
           or (v_ts is not null and x.updated_at >= v_ts and (x.updated_at, x.id::text) > (v_ts, v_k)))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'amount', g.amount, 'currency', g.currency,
        'category', g.category, 'note', g.note, 'paid_from', g.paid_from, 'wallet', g.wallet, 'spent_at', g.spent_at,
        'created_by', g.created_by, 'approved_by', g.approved_by, 'voided_at', g.voided_at,
        'void_reason', g.void_reason, 'void_approved_by', g.void_approved_by, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$function$;

create or replace function public.sync_pull_service(p_cursor jsonb default null::jsonb, p_limit integer default 100)
 returns jsonb
 language plpgsql
 stable
 set search_path to ''
as $function$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_upto   timestamptz := now() - interval '5 seconds';
  v_ts     timestamptz := nullif(p_cursor ->> 'ts', '')::timestamptz;
  v_k      text := p_cursor ->> 'k';
  v_rows   jsonb;
  v_last   jsonb;
  v_more   boolean;
  v_floats jsonb;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.id, x.location_id, x.kind, x.wallet, x.amount, x.fee, x.price, x.currency, x.ref, x.note, x.txn_at,
           x.created_by, x.approved_by, x.voided_at, x.void_reason, x.void_approved_by, x.updated_at
    from public.service_txns x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and ((v_ts is null and x.txn_at >= now() - interval '30 days')
           or (v_ts is not null and x.updated_at >= v_ts and (x.updated_at, x.id::text) > (v_ts, v_k)))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'kind', g.kind, 'wallet', g.wallet, 'amount', g.amount,
        'fee', g.fee, 'price', g.price, 'currency', g.currency, 'ref', g.ref, 'note', g.note, 'txn_at', g.txn_at,
        'created_by', g.created_by, 'approved_by', g.approved_by, 'voided_at', g.voided_at,
        'void_reason', g.void_reason, 'void_approved_by', g.void_approved_by, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1),
    coalesce((select jsonb_agg(jsonb_build_object(
        'location_id', w.location_id, 'wallet', w.wallet, 'balance', w.balance, 'negative', w.negative,
        'txn_count', w.txn_count, 'updated_at', w.updated_at) order by w.location_id, w.wallet)
      from public.wallet_float w where w.tenant_id = v_tenant), '[]'::jsonb)
  into v_more, v_rows, v_last, v_floats;

  return jsonb_build_object('rows', v_rows, 'floats', v_floats, 'cursor', coalesce(v_last, p_cursor),
                            'has_more', v_more, 'server_time', now());
end;
$function$;

create or replace function public.sync_pull_shifts(p_cursor jsonb default null::jsonb, p_limit integer default 100)
 returns jsonb
 language plpgsql
 stable
 set search_path to ''
as $function$
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
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.id, x.location_id, x.cashier_id, x.currency, x.opening_cash, x.opened_at, x.closed_at, x.expected_cash,
           x.server_expected_cash, x.counted_cash, x.difference, x.note, x.closed_by, x.updated_at
    from public.shifts x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and ((v_ts is null and (x.closed_at is null or x.closed_at >= now() - interval '30 days'))
           or (v_ts is not null and x.updated_at >= v_ts and (x.updated_at, x.id::text) > (v_ts, v_k)))
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
$function$;

-- ---------------------------------------------------------------------------
-- 3. Consolidated SECURITY DEFINER report_summary & report_multi_store
--    Eliminates ~15+ redundant RLS auth_* initplan evaluations and duplicate scans
-- ---------------------------------------------------------------------------
create or replace function public.report_summary(p_from date, p_to date, p_location_id uuid default null::uuid)
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to ''
as $function$
declare
  v_tenant    uuid := public.auth_tenant_id();
  v_role      text;
  v_is_super  boolean;
  v_is_mgr    boolean;
  v_can_utang boolean;
  v_locs      uuid[];
  v_days      jsonb;
  v_totals    jsonb;
  v_top       jsonb;
  v_utang     jsonb;
  v_exp       jsonb;
  v_svc       jsonb;
  v_kinds     text[] := array['cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust'];
  v_wals      text[] := array['gcash', 'maya', 'load', 'other'];
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then
    raise exception 'date range is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_role      := public.auth_role();
  v_is_super  := coalesce(v_role = 'superadmin', false);
  v_is_mgr    := coalesce(v_role in ('superadmin', 'admin'), false);
  v_can_utang := coalesce(v_role in ('superadmin', 'admin', 'cashier'), false);
  v_locs      := coalesce(public.auth_location_ids(), '{}'::uuid[]);

  if p_location_id is not null then
    if not (v_is_super or p_location_id = any (v_locs)) then
      raise exception 'access denied for location' using errcode = '42501', hint = 'forbidden';
    end if;
  end if;

  with d_days as (
    select d.day,
           sum(d.net)::bigint as net,
           sum(d.gross)::bigint as gross,
           sum(d.discount)::bigint as discount,
           sum(d.cogs)::bigint as cogs,
           sum(d.txn_count)::int as txns,
           sum(d.cash)::bigint as cash,
           sum(d.ewallet)::bigint as ewallet,
           sum(d.card)::bigint as card,
           sum(d.utang)::bigint as utang
    from public.daily_sales_summary d
    where d.tenant_id = v_tenant
      and v_is_mgr
      and d.location_id = any (v_locs)
      and d.day between p_from and p_to
      and (p_location_id is null or d.location_id = p_location_id)
    group by d.day
  )
  select
    coalesce((select jsonb_agg(to_jsonb(dd) order by dd.day) from d_days dd), '[]'::jsonb),
    jsonb_build_object(
      'net', coalesce(sum(d.net), 0), 'gross', coalesce(sum(d.gross), 0), 'discount', coalesce(sum(d.discount), 0),
      'cogs', coalesce(sum(d.cogs), 0), 'txns', coalesce(sum(d.txns), 0),
      'cash', coalesce(sum(d.cash), 0), 'ewallet', coalesce(sum(d.ewallet), 0),
      'card', coalesce(sum(d.card), 0), 'utang', coalesce(sum(d.utang), 0))
  into v_days, v_totals
  from d_days d;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc, x.name), '[]'::jsonb) into v_top from (
    select i.variant_id, max(i.product_name) as name, sum(i.qty) as qty, sum(i.revenue)::bigint as revenue
    from public.daily_item_sales i
    where i.tenant_id = v_tenant
      and v_is_mgr
      and i.location_id = any (v_locs)
      and i.day between p_from and p_to
      and (p_location_id is null or i.location_id = p_location_id)
    group by i.variant_id
    having sum(i.qty) > 0
    order by sum(i.revenue) desc, max(i.product_name)
    limit 10
  ) x;

  select jsonb_build_object(
    'owed', coalesce(sum(b.balance) filter (where b.balance > 0), 0),
    'customers', coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name, 'balance', b.balance)
                          order by b.balance desc) filter (where b.balance > 0), '[]'::jsonb))
  into v_utang
  from (
    select c.id, c.name, sum(l.amount)::bigint as balance
    from public.customers c
    join public.customer_ledger l on l.customer_id = c.id and l.tenant_id = c.tenant_id
    where c.tenant_id = v_tenant
      and v_can_utang
      and c.deleted_at is null
      and (p_location_id is null or l.location_id = p_location_id)
    group by c.id, c.name
  ) b;

  with exp_base as (
    select e.day, e.category, e.amount, e.cash, e.ewallet, e.entry_count
    from public.daily_expense_summary e
    where e.tenant_id = v_tenant
      and v_is_mgr
      and e.location_id = any (v_locs)
      and e.day between p_from and p_to
      and (p_location_id is null or e.location_id = p_location_id)
  )
  select jsonb_build_object(
    'total', coalesce(sum(e.amount), 0), 'cash', coalesce(sum(e.cash), 0), 'ewallet', coalesce(sum(e.ewallet), 0),
    'count', coalesce(sum(e.entry_count), 0),
    'by_category', coalesce((
      select jsonb_agg(jsonb_build_object('category', c.category, 'amount', c.amount, 'count', c.n)
                       order by c.amount desc, c.category)
      from (select e2.category, sum(e2.amount)::bigint as amount, sum(e2.entry_count)::int as n
            from exp_base e2
            group by e2.category
            having sum(e2.entry_count) > 0) c), '[]'::jsonb),
    'days', coalesce((
      select jsonb_agg(jsonb_build_object('day', dd.day, 'amount', dd.amount) order by dd.day)
      from (select e3.day, sum(e3.amount)::bigint as amount
            from exp_base e3
            group by e3.day
            having sum(e3.entry_count) > 0) dd), '[]'::jsonb))
  into v_exp
  from exp_base e;

  with svc_base as (
    select s.kind, s.txn_count, s.amount, s.fee
    from public.daily_service_summary s
    where s.tenant_id = v_tenant
      and v_is_mgr
      and s.location_id = any (v_locs)
      and s.day between p_from and p_to
      and (p_location_id is null or s.location_id = p_location_id)
  )
  select jsonb_build_object(
    'count', coalesce(sum(s.txn_count) filter (where s.kind in ('cash_in', 'cash_out', 'load')), 0),
    'fee_total', coalesce(sum(s.fee), 0),
    'by_kind', coalesce((
      select jsonb_agg(jsonb_build_object('kind', k.kind, 'count', k.n, 'amount', k.amount, 'fee', k.fee)
                       order by array_position(v_kinds, k.kind))
      from (select s2.kind, sum(s2.txn_count)::int as n, sum(s2.amount)::bigint as amount, sum(s2.fee)::bigint as fee
            from svc_base s2
            group by s2.kind
            having sum(s2.txn_count) > 0) k), '[]'::jsonb),
    'float', coalesce((
      select jsonb_agg(jsonb_build_object('wallet', f.wallet, 'balance', f.balance) order by array_position(v_wals, f.wallet))
      from (select w.wallet, sum(w.balance)::bigint as balance
            from public.wallet_float w
            where w.tenant_id = v_tenant
              and v_can_utang
              and w.location_id = any (v_locs)
              and (p_location_id is null or w.location_id = p_location_id)
            group by w.wallet) f), '[]'::jsonb))
  into v_svc
  from svc_base s;

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'totals', v_totals,
    'days', v_days,
    'top_items', v_top,
    'utang', v_utang,
    'expenses', v_exp,
    'services', v_svc,
    'server_time', now()
  ) || case
    when p_location_id is not null then jsonb_build_object('location_id', p_location_id)
    else '{}'::jsonb
  end;
end;
$function$;
revoke execute on function public.report_summary(date, date, uuid) from public, anon;
grant execute on function public.report_summary(date, date, uuid) to authenticated;

create or replace function public.report_multi_store(p_from date, p_to date, p_location_id uuid default null::uuid)
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to ''
as $function$
declare
  v_tenant          uuid := public.auth_tenant_id();
  v_role            text;
  v_is_super        boolean;
  v_is_mgr          boolean;
  v_can_tr          boolean;
  v_locs            uuid[];
  v_tz              text;
  v_from_ts         timestamptz;
  v_to_ts           timestamptz;
  v_days            jsonb;
  v_totals          jsonb;
  v_top             jsonb;
  v_stores          jsonb;
  v_stock_valuation jsonb;
  v_transfers       jsonb;
  v_exp             jsonb;
  v_svc             jsonb;
  v_utang           jsonb;
  v_kinds           text[] := array['cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust'];
  v_wals            text[] := array['gcash', 'maya', 'load', 'other'];
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;

  v_role := public.auth_role();
  if v_role = 'cashier' then
    raise exception 'cashiers cannot view management reports' using errcode = '42501', hint = 'not_allowed';
  end if;

  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then
    raise exception 'date range is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_is_super := coalesce(v_role = 'superadmin', false);
  v_is_mgr   := coalesce(v_role in ('superadmin', 'admin'), false);
  v_can_tr   := coalesce(v_role in ('superadmin', 'admin', 'warehouse'), false);
  v_locs     := coalesce(public.auth_location_ids(), '{}'::uuid[]);

  if p_location_id is not null then
    if not (v_is_super or p_location_id = any (v_locs)) then
      raise exception 'access denied for location' using errcode = '42501', hint = 'forbidden';
    end if;
  end if;

  select coalesce(t.timezone, 'Asia/Manila') into v_tz from public.tenants t where t.id = v_tenant;
  v_from_ts := p_from::timestamp at time zone coalesce(v_tz, 'Asia/Manila');
  v_to_ts   := (p_to + 1)::timestamp at time zone coalesce(v_tz, 'Asia/Manila');

  -- 1 & 2. Daily breakdown & Period totals (single scan)
  with d_days as (
    select d.day,
           sum(d.net)::bigint as net,
           sum(d.gross)::bigint as gross,
           sum(d.discount)::bigint as discount,
           sum(d.tax)::bigint as tax,
           sum(d.cogs)::bigint as cogs,
           sum(d.txn_count)::int as txns,
           sum(d.cash)::bigint as cash,
           sum(d.ewallet)::bigint as ewallet,
           sum(d.card)::bigint as card,
           sum(d.utang)::bigint as utang,
           sum(d.net - d.cogs)::bigint as profit
    from public.daily_sales_summary d
    where d.tenant_id = v_tenant
      and v_is_mgr
      and d.location_id = any (v_locs)
      and d.day between p_from and p_to
      and (p_location_id is null or d.location_id = p_location_id)
    group by d.day
  )
  select
    coalesce((select jsonb_agg(to_jsonb(dd) order by dd.day) from d_days dd), '[]'::jsonb),
    jsonb_build_object(
      'net', coalesce(sum(d.net), 0),
      'gross', coalesce(sum(d.gross), 0),
      'discount', coalesce(sum(d.discount), 0),
      'tax', coalesce(sum(d.tax), 0),
      'cogs', coalesce(sum(d.cogs), 0),
      'txns', coalesce(sum(d.txns), 0),
      'cash', coalesce(sum(d.cash), 0),
      'ewallet', coalesce(sum(d.ewallet), 0),
      'card', coalesce(sum(d.card), 0),
      'utang', coalesce(sum(d.utang), 0),
      'profit', coalesce(sum(d.profit), 0),
      'margin_percent', case when coalesce(sum(d.net), 0) > 0
        then round(((sum(d.net) - sum(d.cogs))::numeric / sum(d.net)::numeric) * 100, 2)
        else 0 end
    )
  into v_days, v_totals
  from d_days d;

  -- 3. Top selling items
  select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc, x.name), '[]'::jsonb) into v_top from (
    select i.variant_id,
           max(i.product_name) as name,
           coalesce(pv.sku, '') as sku,
           sum(i.qty) as qty,
           sum(i.revenue)::bigint as revenue,
           sum(i.cogs)::bigint as cogs,
           sum(i.revenue - i.cogs)::bigint as profit
    from public.daily_item_sales i
    left join public.product_variants pv on pv.id = i.variant_id and pv.tenant_id = v_tenant
    where i.tenant_id = v_tenant
      and v_is_mgr
      and i.location_id = any (v_locs)
      and i.day between p_from and p_to
      and (p_location_id is null or i.location_id = p_location_id)
    group by i.variant_id, pv.sku
    having sum(i.qty) > 0
    order by sum(i.revenue) desc, max(i.product_name)
    limit 20
  ) x;

  -- 4 & 5. Per-store comparison breakdown & stock valuation (single scan of stock_levels!)
  with sl_scoped as (
    select sl.location_id, sl.variant_id, sl.qty_on_hand, sl.avg_cost
    from public.stock_levels sl
    where sl.tenant_id = v_tenant
      and sl.location_id = any (v_locs)
      and (p_location_id is null or sl.location_id = p_location_id)
  ),
  sl_by_loc as (
    select s.location_id,
           coalesce(sum(round(s.qty_on_hand * s.avg_cost)), 0)::bigint as stock_value,
           coalesce(sum(s.qty_on_hand), 0)::numeric(14, 3) as stock_units
    from sl_scoped s
    group by s.location_id
  ),
  ds_by_loc as (
    select d.location_id,
           sum(d.net)::bigint as net,
           sum(d.gross)::bigint as gross,
           sum(d.cogs)::bigint as cogs,
           sum(d.txn_count)::int as txns,
           sum(d.net - d.cogs)::bigint as profit
    from public.daily_sales_summary d
    where d.tenant_id = v_tenant
      and v_is_mgr
      and d.location_id = any (v_locs)
      and d.day between p_from and p_to
      and (p_location_id is null or d.location_id = p_location_id)
    group by d.location_id
  )
  select
    coalesce((
      select jsonb_agg(to_jsonb(st) order by st.code)
      from (
        select l.id as location_id,
               l.code,
               l.name,
               l.type,
               coalesce(ds.net, 0)::bigint as net,
               coalesce(ds.gross, 0)::bigint as gross,
               coalesce(ds.cogs, 0)::bigint as cogs,
               coalesce(ds.txns, 0)::int as txns,
               coalesce(ds.profit, 0)::bigint as profit,
               coalesce(sv.stock_value, 0)::bigint as stock_value,
               coalesce(sv.stock_units, 0)::numeric(14, 3) as stock_units
        from public.locations l
        left join ds_by_loc ds on ds.location_id = l.id
        left join sl_by_loc sv on sv.location_id = l.id
        where l.tenant_id = v_tenant and l.active and l.deleted_at is null
          and (p_location_id is null or l.id = p_location_id)
          and (v_is_super or l.id = any (v_locs))
      ) st
    ), '[]'::jsonb),
    jsonb_build_object(
      'total_value', coalesce(sum(round(s.qty_on_hand * s.avg_cost)), 0)::bigint,
      'total_units', coalesce(sum(s.qty_on_hand), 0)::numeric(14, 3),
      'items_count', count(distinct s.variant_id)::int
    )
  into v_stores, v_stock_valuation
  from sl_scoped s;

  -- 6. Transfers activity summary (sargable created_at timestamp bounds)
  select jsonb_build_object(
    'total_transfers', count(*)::int,
    'shipped_count', count(*) filter (where t.status = 'shipped')::int,
    'received_count', count(*) filter (where t.status = 'received')::int,
    'discrepancy_count', count(*) filter (where t.has_discrepancy)::int
  )
  into v_transfers
  from public.transfers t
  where t.tenant_id = v_tenant
    and v_can_tr
    and t.created_at >= v_from_ts and t.created_at < v_to_ts
    and (p_location_id is null or t.from_location_id = p_location_id or t.to_location_id = p_location_id)
    and (v_is_super or t.from_location_id = any (v_locs) or t.to_location_id = any (v_locs));

  -- 7. Expenses summary (single scan)
  with exp_base as (
    select e.day, e.category, e.amount, e.cash, e.ewallet, e.entry_count
    from public.daily_expense_summary e
    where e.tenant_id = v_tenant
      and v_is_mgr
      and e.location_id = any (v_locs)
      and e.day between p_from and p_to
      and (p_location_id is null or e.location_id = p_location_id)
  )
  select jsonb_build_object(
    'total', coalesce(sum(e.amount), 0),
    'cash', coalesce(sum(e.cash), 0),
    'ewallet', coalesce(sum(e.ewallet), 0),
    'count', coalesce(sum(e.entry_count), 0),
    'by_category', coalesce((
      select jsonb_agg(jsonb_build_object('category', c.category, 'amount', c.amount, 'count', c.n)
                       order by c.amount desc, c.category)
      from (select e2.category, sum(e2.amount)::bigint as amount, sum(e2.entry_count)::int as n
            from exp_base e2
            group by e2.category
            having sum(e2.entry_count) > 0) c), '[]'::jsonb),
    'days', coalesce((
      select jsonb_agg(jsonb_build_object('day', dd.day, 'amount', dd.amount) order by dd.day)
      from (select e3.day, sum(e3.amount)::bigint as amount
            from exp_base e3
            group by e3.day
            having sum(e3.entry_count) > 0) dd), '[]'::jsonb))
  into v_exp
  from exp_base e;

  -- 8. Services summary (single scan)
  with svc_base as (
    select s.kind, s.txn_count, s.amount, s.fee
    from public.daily_service_summary s
    where s.tenant_id = v_tenant
      and v_is_mgr
      and s.location_id = any (v_locs)
      and s.day between p_from and p_to
      and (p_location_id is null or s.location_id = p_location_id)
  )
  select jsonb_build_object(
    'count', coalesce(sum(s.txn_count) filter (where s.kind in ('cash_in', 'cash_out', 'load')), 0),
    'fee_total', coalesce(sum(s.fee), 0),
    'by_kind', coalesce((
      select jsonb_agg(jsonb_build_object('kind', k.kind, 'count', k.n, 'amount', k.amount, 'fee', k.fee)
                       order by array_position(v_kinds, k.kind))
      from (select s2.kind, sum(s2.txn_count)::int as n, sum(s2.amount)::bigint as amount, sum(s2.fee)::bigint as fee
            from svc_base s2
            group by s2.kind
            having sum(s2.txn_count) > 0) k), '[]'::jsonb),
    'float', coalesce((
      select jsonb_agg(jsonb_build_object('wallet', f.wallet, 'balance', f.balance) order by array_position(v_wals, f.wallet))
      from (select w.wallet, sum(w.balance)::bigint as balance
            from public.wallet_float w
            where w.tenant_id = v_tenant
              and v_is_mgr
              and w.location_id = any (v_locs)
              and (p_location_id is null or w.location_id = p_location_id)
            group by w.wallet) f), '[]'::jsonb))
  into v_svc
  from svc_base s;

  -- 9. Utang summary
  select jsonb_build_object(
    'owed', coalesce(sum(b.balance) filter (where b.balance > 0), 0),
    'customers', coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name, 'balance', b.balance)
                          order by b.balance desc) filter (where b.balance > 0), '[]'::jsonb))
  into v_utang
  from (
    select c.id, c.name, sum(l.amount)::bigint as balance
    from public.customers c
    join public.customer_ledger l on l.customer_id = c.id and l.tenant_id = c.tenant_id
    where c.tenant_id = v_tenant
      and v_is_mgr
      and c.deleted_at is null
      and (p_location_id is null or l.location_id = p_location_id)
    group by c.id, c.name
  ) b;

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'location_id', p_location_id,
    'days', v_days,
    'totals', v_totals,
    'top_items', v_top,
    'stores', v_stores,
    'stock_valuation', v_stock_valuation,
    'transfers', v_transfers,
    'expenses', v_exp,
    'services', v_svc,
    'utang', v_utang,
    'server_time', now()
  );
end;
$function$;
revoke execute on function public.report_multi_store(date, date, uuid) from public, anon;
grant execute on function public.report_multi_store(date, date, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Server-aggregated customer utang balances RPC (for P01)
-- ---------------------------------------------------------------------------
create or replace function public.customer_utang_balances(
  p_limit integer default 1000,
  p_offset integer default 0
)
 returns table(
   customer_id uuid,
   name text,
   phone text,
   due_on date,
   balance bigint
 )
 language plpgsql
 stable
 security definer
 set search_path to ''
as $function$
declare
  v_tenant uuid := public.auth_tenant_id();
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  perform public.assert_active_user();
  if public.auth_role() not in ('superadmin', 'admin', 'cashier') then
    raise exception 'not allowed to view customer balances' using errcode = '42501', hint = 'not_allowed';
  end if;

  return query
    select c.id as customer_id,
           c.name,
           c.phone,
           c.due_on,
           coalesce(sum(l.amount), 0)::bigint as balance
    from public.customers c
    left join public.customer_ledger l
      on l.customer_id = c.id and l.tenant_id = c.tenant_id
    where c.tenant_id = v_tenant
      and c.deleted_at is null
    group by c.id, c.name, c.phone, c.due_on
    order by coalesce(sum(l.amount), 0)::bigint desc, c.name asc, c.id asc
    limit greatest(1, least(coalesce(p_limit, 1000), 2000))
    offset greatest(0, coalesce(p_offset, 0));
end;
$function$;
revoke execute on function public.customer_utang_balances(integer, integer) from public, anon;
grant execute on function public.customer_utang_balances(integer, integer) to authenticated;
