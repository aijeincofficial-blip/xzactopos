-- ============================================================================
-- Migration: 20261113000100_qa01_functional_fixes.sql
-- Purpose  : QA-01 Critical & High Functional Fixes (F03, F04, F05, F08):
--   1. F04: Fix pull_offline_pins(null) calling nonexistent resolve_caller_store.
--   2. F05: Enforce assert_module('pos') on POS sync_pull_* RPCs.
--   3. F08: Enforce active user, warehouse module, location access, and non-cashier
--           guards across warehouse bin, pick-list, and transfer RPCs.
--   4. F03: Add product_variants.name + multi-variant upsert_product & sync_pull_catalog
--           while preserving backward-compatible single-variant payloads.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. F04: pull_offline_pins(p_location_id uuid default null)
-- ---------------------------------------------------------------------------

create or replace function public.pull_offline_pins(p_location_id uuid default null)
returns table (
  user_id   uuid,
  username  text,
  full_name text,
  role      text,
  "position" text,
  pin_hash  text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_loc    uuid := p_location_id;
begin
  perform public.assert_active_user();

  if v_loc is null then
    v_loc := public.resolve_store(v_loc);
  end if;

  if not public.is_superadmin() and not public.has_location_access(v_loc) then
    raise exception 'location access denied' using errcode = '42501', hint = 'location_denied';
  end if;

  return query
  select distinct
    p.user_id,
    p.username,
    p.full_name,
    p.role,
    la.position,
    p.pin_hash
  from public.profiles p
  left join public.location_access la
    on la.user_id = p.user_id
   and la.tenant_id = v_tenant
   and la.location_id = v_loc
   and la.deleted_at is null
  where p.tenant_id = v_tenant
    and p.active = true
    and p.deleted_at is null
    and p.pin_hash is not null
    and (
      p.role = 'superadmin'
      or la.user_id is not null
    )
  order by p.username;
end;
$$;

revoke execute on function public.pull_offline_pins(uuid) from public, anon;
grant execute on function public.pull_offline_pins(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. F05: POS sync_pull_* module assertions ('pos')
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

create or replace function public.sync_pull_sales(p_cursor jsonb default null, p_limit int default 100)
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
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.*
    from public.sales x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and (v_ts is null and x.sold_at >= now() - interval '30 days'
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
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
                  where i.sale_id = g.id), '[]'::jsonb),
        'payments', coalesce((select jsonb_agg(jsonb_build_object(
                    'method', p.method, 'amount', p.amount, 'tendered', p.tendered, 'reference', p.reference,
                    'wallet', p.wallet)
                    order by p.created_at, p.id)
                  from public.payments p where p.sale_id = g.id), '[]'::jsonb)
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$$;

revoke execute on function public.sync_pull_sales(jsonb, int) from public, anon;
grant execute on function public.sync_pull_sales(jsonb, int) to authenticated;

create or replace function public.sync_pull_expenses(p_cursor jsonb default null, p_limit int default 100)
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
      and (v_ts is null and x.spent_at >= now() - interval '30 days'
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
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
$$;

revoke execute on function public.sync_pull_expenses(jsonb, int) from public, anon;
grant execute on function public.sync_pull_expenses(jsonb, int) to authenticated;

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
        'opening_cash', g.opening_cash, 'expected_cash', g.expected_cash, 'counted_cash', g.counted_cash,
        'difference', g.difference, 'server_expected_cash', g.server_expected_cash, 'note', g.note,
        'closed_by', g.closed_by, 'approved_by', g.approved_by, 'closed_at', g.closed_at, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$$;

revoke execute on function public.sync_pull_day_closes(jsonb, int) from public, anon;
grant execute on function public.sync_pull_day_closes(jsonb, int) to authenticated;

create or replace function public.sync_pull_service(p_cursor jsonb default null, p_limit int default 100)
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
      and (v_ts is null and x.txn_at >= now() - interval '30 days'
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
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
$$;

revoke execute on function public.sync_pull_service(jsonb, int) from public, anon;
grant execute on function public.sync_pull_service(jsonb, int) to authenticated;

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
-- 3. F08: Warehouse, bin, pick-list, and transfer security + module checks
-- ---------------------------------------------------------------------------

create or replace function public.enable_warehouse_bins(p_warehouse_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant         uuid;
  v_role           text;
  v_type           text;
  v_rcv_zone       uuid;
  v_stg_zone       uuid;
  v_gen_zone       uuid;
  v_rcv_bin        uuid;
  v_stg_bin        uuid;
  v_gen_bin        uuid;
  v_migrated_count int := 0;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot manage warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  select type into v_type
  from public.locations
  where id = p_warehouse_id and tenant_id = v_tenant and active and deleted_at is null;

  if not found then
    raise exception 'location not found' using errcode = '22023', hint = 'location_not_found';
  end if;

  if v_type <> 'warehouse' then
    raise exception 'only warehouses can enable bins' using errcode = '22023', hint = 'not_a_warehouse';
  end if;

  update public.locations
  set bins_enabled = true, updated_at = now()
  where id = p_warehouse_id and tenant_id = v_tenant;

  select id into v_rcv_zone from public.warehouse_zones
  where warehouse_id = p_warehouse_id and code = 'RCV' and tenant_id = v_tenant;

  if v_rcv_zone is null then
    v_rcv_zone := public.uuid_generate_v7();
    insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type)
    values (v_rcv_zone, v_tenant, p_warehouse_id, 'RCV', 'Receiving', 'receiving');
  end if;

  select id into v_stg_zone from public.warehouse_zones
  where warehouse_id = p_warehouse_id and code = 'STG' and tenant_id = v_tenant;

  if v_stg_zone is null then
    v_stg_zone := public.uuid_generate_v7();
    insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type)
    values (v_stg_zone, v_tenant, p_warehouse_id, 'STG', 'Staging', 'staging');
  end if;

  select id into v_gen_zone from public.warehouse_zones
  where warehouse_id = p_warehouse_id and code = 'GEN' and tenant_id = v_tenant;

  if v_gen_zone is null then
    v_gen_zone := public.uuid_generate_v7();
    insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type)
    values (v_gen_zone, v_tenant, p_warehouse_id, 'GEN', 'General Storage', 'storage');
  end if;

  select id into v_rcv_bin from public.bins
  where warehouse_id = p_warehouse_id and code = 'RECEIVING' and tenant_id = v_tenant;

  if v_rcv_bin is null then
    v_rcv_bin := public.uuid_generate_v7();
    insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, type, active)
    values (v_rcv_bin, v_tenant, p_warehouse_id, v_rcv_zone, 'RECEIVING', 'floor', true);
  end if;

  select id into v_stg_bin from public.bins
  where warehouse_id = p_warehouse_id and code = 'STAGING' and tenant_id = v_tenant;

  if v_stg_bin is null then
    v_stg_bin := public.uuid_generate_v7();
    insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, type, active)
    values (v_stg_bin, v_tenant, p_warehouse_id, v_stg_zone, 'STAGING', 'floor', true);
  end if;

  select id into v_gen_bin from public.bins
  where warehouse_id = p_warehouse_id and code = 'A-01-1' and tenant_id = v_tenant;

  if v_gen_bin is null then
    v_gen_bin := public.uuid_generate_v7();
    insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, aisle, rack, shelf, position, type, active)
    values (v_gen_bin, v_tenant, p_warehouse_id, v_gen_zone, 'A-01-1', 'A', '01', '1', '1', 'shelf', true);
  end if;

  insert into public.bin_stock_levels (tenant_id, bin_id, variant_id, qty_on_hand, updated_at)
  select sl.tenant_id, v_rcv_bin, sl.variant_id, sl.qty_on_hand, now()
  from public.stock_levels sl
  where sl.location_id = p_warehouse_id and sl.tenant_id = v_tenant and sl.qty_on_hand <> 0
  on conflict (bin_id, variant_id)
  do update set qty_on_hand = excluded.qty_on_hand, updated_at = now();

  get diagnostics v_migrated_count = row_count;

  perform public.write_audit('warehouse.bins_enabled', 'location', p_warehouse_id, p_warehouse_id,
    jsonb_build_object('migrated_stock_count', v_migrated_count));

  return jsonb_build_object(
    'ok', true,
    'warehouse_id', p_warehouse_id,
    'receiving_bin_id', v_rcv_bin,
    'staging_bin_id', v_stg_bin,
    'general_bin_id', v_gen_bin,
    'migrated_count', v_migrated_count
  );
end;
$$;

revoke execute on function public.enable_warehouse_bins(uuid) from public, anon;
grant execute on function public.enable_warehouse_bins(uuid) to authenticated;

create or replace function public.check_bin_stock_invariant(p_warehouse_id uuid)
returns table (
  variant_id    uuid,
  sku           text,
  warehouse_qty numeric,
  bins_qty      numeric,
  diff          numeric,
  is_valid      boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() = 'cashier' then
    raise exception 'cashiers cannot inspect warehouse bin invariants' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  return query
  with b_sum as (
    select bsl.variant_id, coalesce(sum(bsl.qty_on_hand), 0) as total_bins_qty
    from public.bin_stock_levels bsl
    join public.bins b on b.id = bsl.bin_id
    where b.warehouse_id = p_warehouse_id and b.tenant_id = v_tenant and bsl.tenant_id = v_tenant
    group by bsl.variant_id
  ),
  all_vars as (
    select sl.variant_id
    from public.stock_levels sl
    where sl.location_id = p_warehouse_id and sl.tenant_id = v_tenant
    union
    select bs.variant_id
    from b_sum bs
  )
  select
    av.variant_id,
    pv.sku,
    coalesce(sl.qty_on_hand, 0) as warehouse_qty,
    coalesce(bs.total_bins_qty, 0) as bins_qty,
    (coalesce(sl.qty_on_hand, 0) - coalesce(bs.total_bins_qty, 0)) as diff,
    (coalesce(sl.qty_on_hand, 0) = coalesce(bs.total_bins_qty, 0)) as is_valid
  from all_vars av
  join public.product_variants pv on pv.id = av.variant_id and pv.tenant_id = v_tenant
  left join public.stock_levels sl on sl.location_id = p_warehouse_id and sl.variant_id = av.variant_id and sl.tenant_id = v_tenant
  left join b_sum bs on bs.variant_id = av.variant_id
  order by pv.sku;
end;
$$;

revoke execute on function public.check_bin_stock_invariant(uuid) from public, anon;
grant execute on function public.check_bin_stock_invariant(uuid) to authenticated;

create or replace function public.upsert_warehouse_zone(
  p_warehouse_id uuid,
  p_code         text,
  p_name         text,
  p_type         text,
  p_id           uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_role   text;
  v_id     uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot manage warehouse zones' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if p_code !~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,19}$' then
    raise exception 'invalid zone code' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if length(btrim(p_name)) < 1 or length(p_name) > 120 then
    raise exception 'invalid zone name' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if p_type not in ('receiving', 'storage', 'picking', 'staging', 'quarantine', 'damaged') then
    raise exception 'invalid zone type' using errcode = '22023', hint = 'invalid_argument';
  end if;

  v_id := coalesce(p_id, public.uuid_generate_v7());

  insert into public.warehouse_zones (
    id, tenant_id, warehouse_id, code, name, type
  ) values (
    v_id, v_tenant, p_warehouse_id, upper(p_code), btrim(p_name), p_type
  )
  on conflict (tenant_id, id)
  do update set
    code = excluded.code,
    name = excluded.name,
    type = excluded.type,
    updated_at = now();

  return v_id;
end;
$$;

revoke execute on function public.upsert_warehouse_zone(uuid, text, text, text, uuid) from public, anon;
grant execute on function public.upsert_warehouse_zone(uuid, text, text, text, uuid) to authenticated;

create or replace function public.upsert_warehouse_bin(
  p_warehouse_id uuid,
  p_code         text,
  p_zone_id      uuid default null,
  p_aisle        text default null,
  p_rack         text default null,
  p_shelf        text default null,
  p_position     text default null,
  p_type         text default 'shelf',
  p_max_qty      numeric default null,
  p_id           uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_role   text;
  v_id     uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot manage warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if p_code !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,29}$' then
    raise exception 'invalid bin code' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if p_type not in ('pallet', 'shelf', 'floor', 'bin') then
    raise exception 'invalid bin type' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if p_max_qty is not null and p_max_qty <= 0 then
    raise exception 'max qty must be positive' using errcode = '22023', hint = 'positive_qty';
  end if;

  if p_zone_id is not null and not exists (
    select 1 from public.warehouse_zones
    where id = p_zone_id and warehouse_id = p_warehouse_id and tenant_id = v_tenant and deleted_at is null
  ) then
    raise exception 'zone not found' using errcode = '22023', hint = 'not_found';
  end if;

  v_id := coalesce(p_id, public.uuid_generate_v7());

  insert into public.bins (
    id, tenant_id, warehouse_id, zone_id, code,
    aisle, rack, shelf, position, type, max_qty, active
  ) values (
    v_id, v_tenant, p_warehouse_id, p_zone_id, upper(p_code),
    p_aisle, p_rack, p_shelf, p_position, p_type, p_max_qty, true
  )
  on conflict (tenant_id, id)
  do update set
    zone_id = excluded.zone_id,
    code = excluded.code,
    aisle = excluded.aisle,
    rack = excluded.rack,
    shelf = excluded.shelf,
    position = excluded.position,
    type = excluded.type,
    max_qty = excluded.max_qty,
    updated_at = now();

  return v_id;
end;
$$;

revoke execute on function public.upsert_warehouse_bin(uuid, text, uuid, text, text, text, text, text, numeric, uuid) from public, anon;
grant execute on function public.upsert_warehouse_bin(uuid, text, uuid, text, text, text, text, text, numeric, uuid) to authenticated;

create or replace function public.list_warehouse_bins(
  p_warehouse_id uuid,
  p_zone_id      uuid default null
)
returns table (
  id           uuid,
  code         text,
  zone_id      uuid,
  zone_code    text,
  zone_name    text,
  zone_type    text,
  aisle        text,
  rack         text,
  shelf        text,
  "position"   text,
  type         text,
  max_qty      numeric,
  active       boolean,
  item_count   bigint,
  total_qty    numeric
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() = 'cashier' then
    raise exception 'cashiers cannot inspect warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  return query
  select
    b.id,
    b.code,
    b.zone_id,
    z.code as zone_code,
    z.name as zone_name,
    z.type as zone_type,
    b.aisle,
    b.rack,
    b.shelf,
    b."position",
    b.type,
    b.max_qty,
    b.active,
    coalesce(count(distinct case when bsl.qty_on_hand <> 0 then bsl.variant_id end), 0) as item_count,
    coalesce(sum(case when bsl.qty_on_hand <> 0 then bsl.qty_on_hand else 0 end), 0) as total_qty
  from public.bins b
  left join public.warehouse_zones z on z.id = b.zone_id
  left join public.bin_stock_levels bsl on bsl.bin_id = b.id
  where b.warehouse_id = p_warehouse_id
    and b.tenant_id = v_tenant
    and b.deleted_at is null
    and (p_zone_id is null or b.zone_id = p_zone_id)
  group by b.id, b.code, b.zone_id, z.code, z.name, z.type, b.aisle, b.rack, b.shelf, b."position", b.type, b.max_qty, b.active
  order by
    coalesce(b.aisle, ''),
    coalesce(b.rack, ''),
    coalesce(b.shelf, ''),
    coalesce(b."position", ''),
    b.code;
end;
$$;

revoke execute on function public.list_warehouse_bins(uuid, uuid) from public, anon;
grant execute on function public.list_warehouse_bins(uuid, uuid) to authenticated;

create or replace function public.list_bin_stock(p_bin_id uuid)
returns table (
  variant_id   uuid,
  sku          text,
  product_name text,
  qty_on_hand  numeric,
  updated_at   timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant       uuid;
  v_warehouse_id uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() = 'cashier' then
    raise exception 'cashiers cannot inspect warehouse bin stock' using errcode = '42501', hint = 'not_allowed';
  end if;

  select b.warehouse_id into v_warehouse_id
  from public.bins b
  where b.id = p_bin_id and b.tenant_id = v_tenant and b.deleted_at is null;

  if v_warehouse_id is null then
    return;
  end if;

  perform public.assert_location_access(v_warehouse_id);

  return query
  select
    bsl.variant_id,
    pv.sku,
    case
      when pv.is_default and pv.name = 'Default' then p.name
      else p.name || ' (' || pv.name || ')'
    end as product_name,
    bsl.qty_on_hand,
    bsl.updated_at
  from public.bin_stock_levels bsl
  join public.product_variants pv on pv.id = bsl.variant_id
  join public.products p on p.id = pv.product_id
  where bsl.bin_id = p_bin_id
    and bsl.tenant_id = v_tenant
    and bsl.qty_on_hand <> 0
  order by p.name, pv.name, pv.sku;
end;
$$;

revoke execute on function public.list_bin_stock(uuid) from public, anon;
grant execute on function public.list_bin_stock(uuid) to authenticated;

create or replace function public.move_bin_stock(
  p_warehouse_id uuid,
  p_from_bin_id  uuid,
  p_to_bin_id    uuid,
  p_variant_id   uuid,
  p_qty          numeric,
  p_reason       text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_role   text;
  v_avail  numeric := 0;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot move bin stock' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if p_from_bin_id = p_to_bin_id then
    raise exception 'source and destination bins must be different' using errcode = '22023', hint = 'same_bin';
  end if;

  if p_qty <= 0 then
    raise exception 'quantity must be positive' using errcode = '22023', hint = 'positive_qty';
  end if;

  if not exists (
    select 1 from public.bins where id = p_from_bin_id and warehouse_id = p_warehouse_id and tenant_id = v_tenant and deleted_at is null
  ) or not exists (
    select 1 from public.bins where id = p_to_bin_id and warehouse_id = p_warehouse_id and tenant_id = v_tenant and deleted_at is null
  ) then
    raise exception 'bin not found' using errcode = '22023', hint = 'not_found';
  end if;

  select coalesce(qty_on_hand, 0) into v_avail
  from public.bin_stock_levels
  where bin_id = p_from_bin_id and variant_id = p_variant_id;

  if v_avail < p_qty then
    raise exception 'insufficient stock in source bin' using errcode = '55000', hint = 'insufficient_bin_stock';
  end if;

  insert into public.stock_movements (
    tenant_id, location_id, bin_id, variant_id, qty_delta, type, ref_type, created_by
  ) values (
    v_tenant, p_warehouse_id, p_from_bin_id, p_variant_id, -p_qty, 'bin_move', p_reason, auth.uid()
  );

  insert into public.stock_movements (
    tenant_id, location_id, bin_id, variant_id, qty_delta, type, ref_type, created_by
  ) values (
    v_tenant, p_warehouse_id, p_to_bin_id, p_variant_id, p_qty, 'bin_move', p_reason, auth.uid()
  );
end;
$$;

revoke execute on function public.move_bin_stock(uuid, uuid, uuid, uuid, numeric, text) from public, anon;
grant execute on function public.move_bin_stock(uuid, uuid, uuid, uuid, numeric, text) to authenticated;

create or replace function public.generate_pick_list(p_transfer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant       uuid;
  v_role         text;
  v_transfer     record;
  v_pick_list_id uuid;
  v_pick_no      text;
  v_item         record;
  v_bin_rec      record;
  v_needed       numeric;
  v_take         numeric;
  v_day          text := to_char(now() at time zone 'Asia/Manila', 'YYMMDD');
  v_seq          integer;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot generate pick lists' using errcode = '42501', hint = 'not_allowed';
  end if;

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_transfer.status <> 'draft' then
    raise exception 'pick lists can only be generated for draft transfers' using errcode = '42501', hint = 'transfer_not_draft';
  end if;

  perform public.assert_location_access(v_transfer.from_location_id);

  select id into v_pick_list_id
  from public.pick_lists
  where transfer_id = p_transfer_id and tenant_id = v_tenant and status <> 'cancelled';

  if v_pick_list_id is not null then
    return v_pick_list_id;
  end if;

  select coalesce(max(substring(pick_list_no from 'PCK-[0-9]{6}-([0-9]+)')::int), 0) + 1
  into v_seq
  from public.pick_lists
  where tenant_id = v_tenant and pick_list_no like 'PCK-' || v_day || '-%';

  v_pick_no := 'PCK-' || v_day || '-' || lpad(v_seq::text, 4, '0');
  v_pick_list_id := public.uuid_generate_v7();

  insert into public.pick_lists (
    id, tenant_id, warehouse_id, transfer_id, pick_list_no, status, created_by
  ) values (
    v_pick_list_id, v_tenant, v_transfer.from_location_id, p_transfer_id, v_pick_no, 'pending', auth.uid()
  );

  for v_item in (
    select ti.variant_id, ti.qty_shipped
    from public.transfer_items ti
    where ti.transfer_id = p_transfer_id and ti.tenant_id = v_tenant
  ) loop
    v_needed := v_item.qty_shipped;

    for v_bin_rec in (
      select bsl.bin_id, bsl.qty_on_hand, b.aisle, b.rack, b.shelf, b."position", b.code
      from public.bin_stock_levels bsl
      join public.bins b on b.id = bsl.bin_id
      left join public.warehouse_zones z on z.id = b.zone_id
      where b.warehouse_id = v_transfer.from_location_id
        and bsl.variant_id = v_item.variant_id
        and bsl.qty_on_hand > 0
        and b.active
        and b.deleted_at is null
      order by
        case when z.type in ('picking', 'storage') then 0 else 1 end,
        coalesce(b.aisle, ''),
        coalesce(b.rack, ''),
        coalesce(b.shelf, ''),
        coalesce(b."position", ''),
        b.code
    ) loop
      exit when v_needed <= 0;

      v_take := least(v_needed, v_bin_rec.qty_on_hand);
      insert into public.pick_list_items (
        id, tenant_id, pick_list_id, variant_id, bin_id, qty_requested, qty_picked
      ) values (
        public.uuid_generate_v7(), v_tenant, v_pick_list_id, v_item.variant_id, v_bin_rec.bin_id, v_take, 0
      );

      v_needed := v_needed - v_take;
    end loop;

    if v_needed > 0 then
      select b.id into v_bin_rec.bin_id
      from public.bins b
      where b.warehouse_id = v_transfer.from_location_id and b.deleted_at is null
      order by b.code limit 1;

      if v_bin_rec.bin_id is not null then
        insert into public.pick_list_items (
          id, tenant_id, pick_list_id, variant_id, bin_id, qty_requested, qty_picked
        ) values (
          public.uuid_generate_v7(), v_tenant, v_pick_list_id, v_item.variant_id, v_bin_rec.bin_id, v_needed, 0
        );
      end if;
    end if;
  end loop;

  perform public.write_audit('warehouse.pick_list_generated', 'pick_list', v_pick_list_id, v_transfer.from_location_id,
    jsonb_build_object('pick_list_no', v_pick_no, 'transfer_id', p_transfer_id));

  return v_pick_list_id;
end;
$$;

revoke execute on function public.generate_pick_list(uuid) from public, anon;
grant execute on function public.generate_pick_list(uuid) to authenticated;

create or replace function public.confirm_pick_item(
  p_pick_list_id  uuid,
  p_item_id       uuid,
  p_qty_picked    numeric,
  p_short_reason  text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant        uuid;
  v_role          text;
  v_pick_list     record;
  v_item          record;
  v_stg_bin       uuid;
  v_unpicked_cnt  integer;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot confirm picks' using errcode = '42501', hint = 'not_allowed';
  end if;

  select * into v_pick_list
  from public.pick_lists
  where id = p_pick_list_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'pick list not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_pick_list.status = 'completed' or v_pick_list.status = 'cancelled' then
    raise exception 'pick list is already completed or cancelled' using errcode = '42501', hint = 'invalid_state';
  end if;

  perform public.assert_location_access(v_pick_list.warehouse_id);

  select * into v_item
  from public.pick_list_items
  where id = p_item_id and pick_list_id = p_pick_list_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'pick item not found' using errcode = '22023', hint = 'not_found';
  end if;

  if p_qty_picked < 0 then
    raise exception 'picked quantity cannot be negative' using errcode = '22023', hint = 'non_negative_qty';
  end if;

  select b.id into v_stg_bin
  from public.bins b
  join public.warehouse_zones z on z.id = b.zone_id
  where b.warehouse_id = v_pick_list.warehouse_id and z.type = 'staging' and b.deleted_at is null
  order by b.code limit 1;

  if v_stg_bin is null then
    select b.id into v_stg_bin
    from public.bins b
    where b.warehouse_id = v_pick_list.warehouse_id and b.deleted_at is null
    order by b.code limit 1;
  end if;

  if p_qty_picked > 0 and v_item.bin_id <> v_stg_bin then
    perform public.move_bin_stock(
      v_pick_list.warehouse_id,
      v_item.bin_id,
      v_stg_bin,
      v_item.variant_id,
      p_qty_picked,
      'pick'
    );
  end if;

  update public.pick_list_items
  set qty_picked = p_qty_picked,
      short_reason = case when p_qty_picked < qty_requested then p_short_reason else null end,
      updated_at = now()
  where id = p_item_id and tenant_id = v_tenant;

  update public.pick_lists
  set status = 'in_progress', updated_at = now()
  where id = p_pick_list_id and status = 'pending';

  select count(*) into v_unpicked_cnt
  from public.pick_list_items
  where pick_list_id = p_pick_list_id and tenant_id = v_tenant and qty_picked = 0;

  if v_unpicked_cnt = 0 then
    update public.pick_lists
    set status = 'completed',
        completed_at = now(),
        completed_by = auth.uid(),
        updated_at = now()
    where id = p_pick_list_id;
  end if;
end;
$$;

revoke execute on function public.confirm_pick_item(uuid, uuid, numeric, text) from public, anon;
grant execute on function public.confirm_pick_item(uuid, uuid, numeric, text) to authenticated;

create or replace function public.list_receiving_stock(p_warehouse_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_result jsonb;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() = 'cashier' then
    raise exception 'cashiers cannot inspect warehouse receiving stock' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  select coalesce(jsonb_agg(jsonb_build_object(
    'bin_id', b.id,
    'bin_code', b.code,
    'variant_id', bsl.variant_id,
    'sku', pv.sku,
    'variant_name', pv.name,
    'product_name', p.name,
    'qty_on_hand', bsl.qty_on_hand,
    'updated_at', bsl.updated_at
  ) order by b.code, p.name, pv.name, pv.sku), '[]'::jsonb)
  into v_result
  from public.bin_stock_levels bsl
  join public.bins b on b.id = bsl.bin_id
  join public.warehouse_zones z on z.id = b.zone_id
  join public.product_variants pv on pv.id = bsl.variant_id
  join public.products p on p.id = pv.product_id
  where b.warehouse_id = p_warehouse_id
    and b.tenant_id = v_tenant
    and b.deleted_at is null
    and z.type = 'receiving'
    and bsl.qty_on_hand > 0;

  return v_result;
end;
$$;

revoke execute on function public.list_receiving_stock(uuid) from public, anon;
grant execute on function public.list_receiving_stock(uuid) to authenticated;

create or replace function public.get_pick_list_for_transfer(p_transfer_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_from_loc uuid;
  v_result   jsonb;
begin
  perform public.assert_active_user();
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() = 'cashier' then
    raise exception 'cashiers cannot view warehouse pick lists' using errcode = '42501', hint = 'not_allowed';
  end if;

  select t.from_location_id into v_from_loc
  from public.transfers t
  where t.id = p_transfer_id and t.tenant_id = v_tenant;

  if v_from_loc is null then
    return null;
  end if;

  perform public.assert_location_access(v_from_loc);

  select jsonb_build_object(
    'id', pl.id,
    'warehouse_id', pl.warehouse_id,
    'transfer_id', pl.transfer_id,
    'pick_list_no', pl.pick_list_no,
    'status', pl.status,
    'created_at', pl.created_at,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pli.id,
        'pick_list_id', pli.pick_list_id,
        'variant_id', pli.variant_id,
        'sku', pv.sku,
        'variant_name', pv.name,
        'product_name', p.name,
        'bin_id', pli.bin_id,
        'bin_code', b.code,
        'location_info', concat_ws('-', b.aisle, b.rack, b.shelf, b."position"),
        'qty_requested', pli.qty_requested,
        'qty_picked', pli.qty_picked,
        'short_reason', pli.short_reason
      ) order by coalesce(b.aisle, ''), coalesce(b.rack, ''), coalesce(b.shelf, ''), coalesce(b."position", ''), b.code)
      from public.pick_list_items pli
      join public.product_variants pv on pv.id = pli.variant_id
      join public.products p on p.id = pv.product_id
      join public.bins b on b.id = pli.bin_id
      where pli.pick_list_id = pl.id and pli.tenant_id = v_tenant
    ), '[]'::jsonb)
  )
  into v_result
  from public.pick_lists pl
  where pl.transfer_id = p_transfer_id and pl.tenant_id = v_tenant
  order by pl.created_at desc
  limit 1;

  return v_result;
end;
$$;

revoke execute on function public.get_pick_list_for_transfer(uuid) from public, anon;
grant execute on function public.get_pick_list_for_transfer(uuid) to authenticated;

create or replace function public.create_transfer(
  p_from_location_id uuid,
  p_to_location_id   uuid,
  p_notes            text default null,
  p_items            jsonb default '[]'::jsonb,
  p_ship_now         boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant       uuid;
  v_role         text;
  v_transfer_id  uuid;
  v_transfer_no  text;
  v_status       text;
  v_item         jsonb;
  v_variant_id   uuid;
  v_qty          numeric;
  v_unit_cost    bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot create transfers' using errcode = '42501', hint = 'not_allowed';
  end if;

  if p_from_location_id = p_to_location_id then
    raise exception 'from and to locations must be different' using errcode = '22023', hint = 'invalid_argument';
  end if;

  perform public.assert_location_access(p_from_location_id);

  if not exists (
    select 1 from public.locations
    where id = p_to_location_id and tenant_id = v_tenant and active and deleted_at is null
  ) then
    raise exception 'destination location not found' using errcode = '22023', hint = 'location_not_found';
  end if;

  if exists (
    select 1 from public.locations l
    where l.tenant_id = v_tenant
      and l.id in (p_from_location_id, p_to_location_id)
      and l.type = 'warehouse'
  ) then
    perform public.assert_module('warehouse');
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'transfer must have at least one item' using errcode = '22023', hint = 'items_required';
  end if;

  v_transfer_id := public.uuid_generate_v7();
  v_transfer_no := public.next_transfer_no(v_tenant);
  v_status := case when p_ship_now then 'shipped' else 'draft' end;

  insert into public.transfers (
    id, tenant_id, transfer_no, from_location_id, to_location_id,
    status, notes, shipped_at, shipped_by, created_by
  ) values (
    v_transfer_id, v_tenant, v_transfer_no, p_from_location_id, p_to_location_id,
    v_status, p_notes, case when p_ship_now then now() else null end,
    case when p_ship_now then auth.uid() else null end, auth.uid()
  );

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_variant_id := (v_item ->> 'variant_id')::uuid;
    v_qty := (v_item ->> 'qty')::numeric;

    if v_qty is null or v_qty <= 0 then
      raise exception 'quantity must be greater than zero' using errcode = '22023', hint = 'qty_invalid';
    end if;

    if not exists (
      select 1 from public.product_variants
      where id = v_variant_id and tenant_id = v_tenant and active and deleted_at is null
    ) then
      raise exception 'product variant not found' using errcode = '22023', hint = 'unknown_variant';
    end if;

    insert into public.transfer_items (
      tenant_id, transfer_id, variant_id, qty_shipped
    ) values (
      v_tenant, v_transfer_id, v_variant_id, v_qty
    );

    if p_ship_now then
      select avg_cost into v_unit_cost
      from public.stock_levels
      where location_id = p_from_location_id and variant_id = v_variant_id;

      insert into public.stock_movements (
        tenant_id, location_id, variant_id, qty_delta, type,
        ref_type, ref_id, unit_cost, created_by
      ) values (
        v_tenant, p_from_location_id, v_variant_id, -v_qty, 'transfer_out',
        'transfer', v_transfer_id, v_unit_cost, auth.uid()
      );
    end if;
  end loop;

  if p_ship_now then
    perform public.write_audit('transfer.ship', 'transfer', v_transfer_id, p_from_location_id,
      jsonb_build_object('transfer_no', v_transfer_no, 'items_count', jsonb_array_length(p_items)));
  else
    perform public.write_audit('transfer.create', 'transfer', v_transfer_id, p_from_location_id,
      jsonb_build_object('transfer_no', v_transfer_no, 'items_count', jsonb_array_length(p_items)));
  end if;

  return v_transfer_id;
end;
$$;

revoke execute on function public.create_transfer from public, anon;
grant execute on function public.create_transfer to authenticated;

create or replace function public.ship_transfer(p_transfer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_transfer record;
  v_item     record;
  v_unit_cost bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  if public.auth_role() = 'cashier' then
    raise exception 'cashiers cannot ship transfers' using errcode = '42501', hint = 'not_allowed';
  end if;

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if exists (
    select 1 from public.locations l
    where l.tenant_id = v_tenant
      and l.id in (v_transfer.from_location_id, v_transfer.to_location_id)
      and l.type = 'warehouse'
  ) then
    perform public.assert_module('warehouse');
  end if;

  if v_transfer.status <> 'draft' then
    raise exception 'transfer is not in draft status' using errcode = '22023', hint = 'invalid_argument';
  end if;

  perform public.assert_location_access(v_transfer.from_location_id);

  update public.transfers
  set status = 'shipped', shipped_at = now(), shipped_by = auth.uid(), updated_at = now()
  where id = p_transfer_id;

  for v_item in
    select variant_id, qty_shipped
    from public.transfer_items
    where transfer_id = p_transfer_id
  loop
    select avg_cost into v_unit_cost
    from public.stock_levels
    where location_id = v_transfer.from_location_id and variant_id = v_item.variant_id;

    insert into public.stock_movements (
      tenant_id, location_id, variant_id, qty_delta, type,
      ref_type, ref_id, unit_cost, created_by
    ) values (
      v_tenant, v_transfer.from_location_id, v_item.variant_id, -v_item.qty_shipped, 'transfer_out',
      'transfer', p_transfer_id, v_unit_cost, auth.uid()
    );
  end loop;

  perform public.write_audit('transfer.ship', 'transfer', p_transfer_id, v_transfer.from_location_id,
    jsonb_build_object('transfer_no', v_transfer.transfer_no));

  return p_transfer_id;
end;
$$;

revoke execute on function public.ship_transfer from public, anon;
grant execute on function public.ship_transfer to authenticated;

create or replace function public.receive_transfer(
  p_transfer_id uuid,
  p_items       jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant          uuid;
  v_transfer        record;
  v_item            jsonb;
  v_variant_id      uuid;
  v_qty_received    numeric;
  v_qty_shipped     numeric;
  v_has_discrepancy boolean := false;
  v_unit_cost       bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if exists (
    select 1 from public.locations l
    where l.tenant_id = v_tenant
      and l.id in (v_transfer.from_location_id, v_transfer.to_location_id)
      and l.type = 'warehouse'
  ) then
    perform public.assert_module('warehouse');
  end if;

  if v_transfer.status <> 'shipped' then
    raise exception 'transfer is not in shipped status' using errcode = '22023', hint = 'invalid_argument';
  end if;

  perform public.assert_location_access(v_transfer.to_location_id);

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'received items list required' using errcode = '22023', hint = 'items_required';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_variant_id := (v_item ->> 'variant_id')::uuid;
    v_qty_received := (v_item ->> 'qty_received')::numeric;

    if v_qty_received is null or v_qty_received < 0 then
      raise exception 'received quantity cannot be negative' using errcode = '22023', hint = 'qty_invalid';
    end if;

    select qty_shipped into v_qty_shipped
    from public.transfer_items
    where transfer_id = p_transfer_id and variant_id = v_variant_id;

    if not found then
      raise exception 'item not part of this transfer' using errcode = '22023', hint = 'unknown_variant';
    end if;

    if v_qty_received <> v_qty_shipped then
      v_has_discrepancy := true;
    end if;

    update public.transfer_items
    set qty_received = v_qty_received
    where transfer_id = p_transfer_id and variant_id = v_variant_id;

    if v_qty_received > 0 then
      select unit_cost into v_unit_cost
      from public.stock_movements
      where tenant_id = v_tenant and ref_type = 'transfer' and ref_id = p_transfer_id
        and location_id = v_transfer.from_location_id and variant_id = v_variant_id
        and type = 'transfer_out'
      order by occurred_at desc
      limit 1;

      insert into public.stock_movements (
        tenant_id, location_id, variant_id, qty_delta, type,
        ref_type, ref_id, unit_cost, created_by
      ) values (
        v_tenant, v_transfer.to_location_id, v_variant_id, v_qty_received, 'transfer_in',
        'transfer', p_transfer_id, v_unit_cost, auth.uid()
      );
    end if;
  end loop;

  update public.transfers
  set status = 'received', received_at = now(), received_by = auth.uid(),
      has_discrepancy = v_has_discrepancy, updated_at = now()
  where id = p_transfer_id;

  perform public.write_audit('transfer.receive', 'transfer', p_transfer_id, v_transfer.to_location_id,
    jsonb_build_object(
      'transfer_no', v_transfer.transfer_no,
      'has_discrepancy', v_has_discrepancy
    ));

  return p_transfer_id;
end;
$$;

revoke execute on function public.receive_transfer from public, anon;
grant execute on function public.receive_transfer to authenticated;

create or replace function public.cancel_transfer(
  p_transfer_id uuid,
  p_reason      text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_transfer record;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  if public.auth_role() = 'cashier' then
    raise exception 'cashiers cannot cancel transfers' using errcode = '42501', hint = 'not_allowed';
  end if;

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if exists (
    select 1 from public.locations l
    where l.tenant_id = v_tenant
      and l.id in (v_transfer.from_location_id, v_transfer.to_location_id)
      and l.type = 'warehouse'
  ) then
    perform public.assert_module('warehouse');
  end if;

  if v_transfer.status <> 'draft' then
    raise exception 'can only cancel draft transfers' using errcode = '22023', hint = 'invalid_argument';
  end if;

  perform public.assert_location_access(v_transfer.from_location_id);

  update public.transfers
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = auth.uid(),
      notes = case
        when p_reason is not null and btrim(p_reason) <> '' then
          coalesce(notes || E'\nCancellation reason: ' || p_reason, 'Cancellation reason: ' || p_reason)
        else notes
      end,
      updated_at = now()
  where id = p_transfer_id;

  perform public.write_audit('transfer.cancel', 'transfer', p_transfer_id, v_transfer.from_location_id,
    jsonb_build_object('transfer_no', v_transfer.transfer_no, 'reason', p_reason));

  return p_transfer_id;
end;
$$;

revoke execute on function public.cancel_transfer from public, anon;
grant execute on function public.cancel_transfer to authenticated;

-- ---------------------------------------------------------------------------
-- 4. F03: Multi-variant product_variants.name + catalog pull & upsert_product
-- ---------------------------------------------------------------------------

alter table public.product_variants
  add column if not exists name text not null default 'Default';

alter table public.product_variants
  drop constraint if exists product_variants_name_check;

alter table public.product_variants
  add constraint product_variants_name_check check (length(btrim(name)) between 1 and 80);

create or replace function public.sync_pull_catalog(p_cursors jsonb default '{}'::jsonb, p_limit int default 500)
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
          and ($3::timestamptz is null or (updated_at, %3$s) > ($3::timestamptz, $4::text))
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
    using v_tenant, v_upto, v_cur ->> 'ts', v_cur ->> 'k', p_limit;

    v_out := v_out || jsonb_build_object(r.tbl, jsonb_build_object(
      'rows', v_rows,
      'cursor', coalesce(v_last, v_cur),
      'has_more', v_more));
  end loop;

  return v_out;
end;
$$;

revoke execute on function public.sync_pull_catalog(jsonb, int) from public, anon;
grant execute on function public.sync_pull_catalog(jsonb, int) to authenticated;

create or replace function public.upsert_product(p_op_id uuid, p_product jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant        uuid;
  v_mode          text;
  v_replay        jsonb;
  p               jsonb := p_product;
  v_has_variants  boolean;
  v               jsonb := coalesce(p_product -> 'variant', '{}'::jsonb);
  v_arr           jsonb;
  v_el            jsonb;
  v_pid           uuid;
  v_vid           uuid;
  v_default_vid   uuid;
  v_default_cnt   int := 0;
  v_item_vid      uuid;
  v_item_sku      text;
  v_item_name     text;
  v_item_price    bigint;
  v_prod          public.products;
  v_var           public.product_variants;
  v_created       boolean;
  v_base          char(3);
  v_sku           text;
  v_con           text;
  v_submitted_ids uuid[] := '{}'::uuid[];
  v_var_results   jsonb := '[]'::jsonb;
  v_result        jsonb;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  v_mode := public.catalog_write_mode();
  if v_mode is null then
    raise exception 'not allowed to change the catalog' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'product must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_has_variants := p ? 'variants';
  if v_has_variants then
    v_arr := p -> 'variants';
    if jsonb_typeof(v_arr) is distinct from 'array' or jsonb_array_length(v_arr) < 1 then
      raise exception 'variants must be a non-empty array' using errcode = '22023', hint = 'invalid_value';
    end if;
    for v_el in select * from jsonb_array_elements(v_arr) loop
      if jsonb_typeof(v_el) is distinct from 'object' then
        raise exception 'variant entry must be an object' using errcode = '22023', hint = 'invalid_value';
      end if;
      v_item_vid := (v_el ->> 'id')::uuid;
      if v_item_vid is null then
        raise exception 'product id and variant id are required' using errcode = '22023', hint = 'id_required';
      end if;
      if v_item_vid = any(v_submitted_ids) then
        raise exception 'duplicate variant id' using errcode = '22023', hint = 'invalid_value';
      end if;
      v_submitted_ids := array_append(v_submitted_ids, v_item_vid);
      if coalesce((v_el ->> 'is_default')::boolean, false) then
        v_default_cnt := v_default_cnt + 1;
        v_default_vid := v_item_vid;
      end if;
    end loop;
    if v_default_cnt > 1 then
      raise exception 'only one default variant is allowed' using errcode = '22023', hint = 'invalid_value';
    end if;
    if v_default_vid is null then
      v_default_vid := v_submitted_ids[1];
    end if;
  else
    if jsonb_typeof(v) is distinct from 'object' then
      raise exception 'product must be an object' using errcode = '22023', hint = 'invalid_value';
    end if;
  end if;

  v_replay := public.claim_op(p_op_id, 'upsert_product');
  if v_replay is not null then
    return v_replay;
  end if;

  v_pid := (p ->> 'id')::uuid;
  if not v_has_variants then
    v_vid := (v ->> 'id')::uuid;
  else
    v_vid := v_default_vid;
  end if;
  if v_pid is null or v_vid is null then
    raise exception 'product id and variant id are required' using errcode = '22023', hint = 'id_required';
  end if;

  select * into v_prod from public.products where id = v_pid and tenant_id = v_tenant for update;
  v_created := not found;
  select t.base_currency into v_base from public.tenants t where t.id = v_tenant;

  begin
    if not v_has_variants then
      if v_created then
        if v_mode <> 'full' then
          raise exception 'warehouse can only change cost and SKU' using errcode = '42501', hint = 'cost_and_sku_only';
        end if;
        if nullif(btrim(p ->> 'name'), '') is null then
          raise exception 'name is required' using errcode = '22023', hint = 'name_required';
        end if;
        if (p ->> 'price') is null then
          raise exception 'price is required' using errcode = '22023', hint = 'price_required';
        end if;

        v_sku := coalesce(nullif(btrim(v ->> 'sku'), ''),
                          'P-' || upper(substr(replace(v_vid::text, '-', ''), 21, 12)));

        insert into public.products (id, tenant_id, category_id, name, unit, tax_rate, track_stock, active, photo_path)
        values (
          v_pid, v_tenant, (p ->> 'category_id')::uuid, btrim(p ->> 'name'),
          coalesce(nullif(btrim(p ->> 'unit'), ''), 'pc'),
          coalesce((p ->> 'tax_rate')::numeric, 0),
          coalesce((p ->> 'track_stock')::boolean, true),
          coalesce((p ->> 'active')::boolean, true),
          p ->> 'photo_path');

        insert into public.product_variants (id, tenant_id, product_id, name, sku, barcode, is_default, cost, reorder_point, active)
        values (
          v_vid, v_tenant, v_pid,
          coalesce(nullif(btrim(v ->> 'name'), ''), 'Default'),
          v_sku, nullif(btrim(v ->> 'barcode'), ''), true,
          coalesce((v ->> 'cost')::bigint, 0),
          coalesce((v ->> 'reorder_point')::numeric, 0),
          coalesce((v ->> 'active')::boolean, true));
      else
        if v_prod.deleted_at is not null then
          raise exception 'product is archived' using errcode = 'P0001', hint = 'product_archived';
        end if;

        select * into v_var from public.product_variants
         where tenant_id = v_tenant and product_id = v_pid and is_default and deleted_at is null
         for update;
        if v_var.id is distinct from v_vid then
          raise exception 'variant id does not match the default variant' using errcode = '22023', hint = 'variant_mismatch';
        end if;

        if v_mode = 'cost_sku' and ((p - 'id' - 'variant') <> '{}'::jsonb or (v - 'id' - 'sku' - 'cost') <> '{}'::jsonb) then
          raise exception 'warehouse can only change cost and SKU' using errcode = '42501', hint = 'cost_and_sku_only';
        end if;
        if p ? 'name' and nullif(btrim(p ->> 'name'), '') is null then
          raise exception 'name is required' using errcode = '22023', hint = 'name_required';
        end if;

        update public.products set
          name        = case when p ? 'name' then btrim(p ->> 'name') else name end,
          category_id = case when p ? 'category_id' then (p ->> 'category_id')::uuid else category_id end,
          unit        = case when p ? 'unit' then coalesce(nullif(btrim(p ->> 'unit'), ''), 'pc') else unit end,
          tax_rate    = case when p ? 'tax_rate' then coalesce((p ->> 'tax_rate')::numeric, 0) else tax_rate end,
          track_stock = case when p ? 'track_stock' then coalesce((p ->> 'track_stock')::boolean, true) else track_stock end,
          active      = case when p ? 'active' then coalesce((p ->> 'active')::boolean, true) else active end,
          photo_path  = case when p ? 'photo_path' then p ->> 'photo_path' else photo_path end
        where id = v_pid;

        update public.product_variants set
          name          = case when v ? 'name' then coalesce(nullif(btrim(v ->> 'name'), ''), 'Default') else name end,
          sku           = case when nullif(btrim(v ->> 'sku'), '') is not null then btrim(v ->> 'sku') else sku end,
          barcode       = case when v ? 'barcode' then nullif(btrim(v ->> 'barcode'), '') else barcode end,
          cost          = case when v ? 'cost' then coalesce((v ->> 'cost')::bigint, 0) else cost end,
          reorder_point = case when v ? 'reorder_point' then coalesce((v ->> 'reorder_point')::numeric, 0) else reorder_point end,
          active        = case when v ? 'active' then coalesce((v ->> 'active')::boolean, true) else active end
        where id = v_vid
        returning sku into v_sku;
      end if;

      if p ? 'price' then
        insert into public.variant_prices (tenant_id, variant_id, currency, price)
        values (v_tenant, v_vid, v_base, (p ->> 'price')::bigint)
        on conflict (variant_id, currency) do update set price = excluded.price, deleted_at = null;
      end if;
    else
      if v_created then
        if v_mode <> 'full' then
          raise exception 'warehouse can only change cost and SKU' using errcode = '42501', hint = 'cost_and_sku_only';
        end if;
        if nullif(btrim(p ->> 'name'), '') is null then
          raise exception 'name is required' using errcode = '22023', hint = 'name_required';
        end if;

        insert into public.products (id, tenant_id, category_id, name, unit, tax_rate, track_stock, active, photo_path)
        values (
          v_pid, v_tenant, (p ->> 'category_id')::uuid, btrim(p ->> 'name'),
          coalesce(nullif(btrim(p ->> 'unit'), ''), 'pc'),
          coalesce((p ->> 'tax_rate')::numeric, 0),
          coalesce((p ->> 'track_stock')::boolean, true),
          coalesce((p ->> 'active')::boolean, true),
          p ->> 'photo_path');

        for v_el in select * from jsonb_array_elements(v_arr) loop
          v_item_vid := (v_el ->> 'id')::uuid;
          v_item_price := coalesce(
            (v_el ->> 'price')::bigint,
            case when jsonb_array_length(v_arr) = 1 then (p ->> 'price')::bigint end
          );
          if v_item_price is null then
            raise exception 'price is required' using errcode = '22023', hint = 'price_required';
          end if;
          v_item_sku := coalesce(nullif(btrim(v_el ->> 'sku'), ''),
                                 'P-' || upper(substr(replace(v_item_vid::text, '-', ''), 21, 12)));
          v_item_name := coalesce(nullif(btrim(v_el ->> 'name'), ''), 'Default');

          insert into public.product_variants (
            id, tenant_id, product_id, name, sku, barcode, is_default, cost, reorder_point, active
          ) values (
            v_item_vid, v_tenant, v_pid, v_item_name, v_item_sku,
            nullif(btrim(v_el ->> 'barcode'), ''),
            (v_item_vid = v_default_vid),
            coalesce((v_el ->> 'cost')::bigint, 0),
            coalesce((v_el ->> 'reorder_point')::numeric, 0),
            coalesce((v_el ->> 'active')::boolean, true)
          );

          insert into public.variant_prices (tenant_id, variant_id, currency, price)
          values (v_tenant, v_item_vid, v_base, v_item_price)
          on conflict (variant_id, currency) do update set price = excluded.price, deleted_at = null;

          if v_item_vid = v_default_vid then
            v_sku := v_item_sku;
          end if;
          v_var_results := v_var_results || jsonb_build_array(jsonb_build_object(
            'variant_id', v_item_vid,
            'name', v_item_name,
            'sku', v_item_sku,
            'is_default', (v_item_vid = v_default_vid)
          ));
        end loop;
      else
        if v_prod.deleted_at is not null then
          raise exception 'product is archived' using errcode = 'P0001', hint = 'product_archived';
        end if;

        if v_mode = 'cost_sku' then
          if (p - 'id' - 'variants') <> '{}'::jsonb then
            raise exception 'warehouse can only change cost and SKU' using errcode = '42501', hint = 'cost_and_sku_only';
          end if;
          for v_el in select * from jsonb_array_elements(v_arr) loop
            if (v_el - 'id' - 'sku' - 'cost') <> '{}'::jsonb then
              raise exception 'warehouse can only change cost and SKU' using errcode = '42501', hint = 'cost_and_sku_only';
            end if;
          end loop;
        end if;

        if p ? 'name' and nullif(btrim(p ->> 'name'), '') is null then
          raise exception 'name is required' using errcode = '22023', hint = 'name_required';
        end if;

        if v_mode = 'full' then
          update public.products set
            name        = case when p ? 'name' then btrim(p ->> 'name') else name end,
            category_id = case when p ? 'category_id' then (p ->> 'category_id')::uuid else category_id end,
            unit        = case when p ? 'unit' then coalesce(nullif(btrim(p ->> 'unit'), ''), 'pc') else unit end,
            tax_rate    = case when p ? 'tax_rate' then coalesce((p ->> 'tax_rate')::numeric, 0) else tax_rate end,
            track_stock = case when p ? 'track_stock' then coalesce((p ->> 'track_stock')::boolean, true) else track_stock end,
            active      = case when p ? 'active' then coalesce((p ->> 'active')::boolean, true) else active end,
            photo_path  = case when p ? 'photo_path' then p ->> 'photo_path' else photo_path end
          where id = v_pid;

          -- Clear existing default flag before re-assigning so partial unique index never conflicts
          update public.product_variants set is_default = false
          where tenant_id = v_tenant and product_id = v_pid and deleted_at is null;
        end if;

        for v_el in select * from jsonb_array_elements(v_arr) loop
          v_item_vid := (v_el ->> 'id')::uuid;
          select * into v_var from public.product_variants
           where id = v_item_vid and tenant_id = v_tenant for update;

          if found then
            if v_var.product_id <> v_pid or v_var.deleted_at is not null then
              raise exception 'variant belongs to another product or is archived' using errcode = '22023', hint = 'id_conflict';
            end if;

            if v_mode = 'cost_sku' then
              update public.product_variants set
                sku  = case when nullif(btrim(v_el ->> 'sku'), '') is not null then btrim(v_el ->> 'sku') else sku end,
                cost = case when v_el ? 'cost' then coalesce((v_el ->> 'cost')::bigint, 0) else cost end
              where id = v_item_vid
              returning name, sku into v_item_name, v_item_sku;
            else
              update public.product_variants set
                name          = case when v_el ? 'name' then coalesce(nullif(btrim(v_el ->> 'name'), ''), 'Default') else name end,
                sku           = case when nullif(btrim(v_el ->> 'sku'), '') is not null then btrim(v_el ->> 'sku') else sku end,
                barcode       = case when v_el ? 'barcode' then nullif(btrim(v_el ->> 'barcode'), '') else barcode end,
                is_default    = (v_item_vid = v_default_vid),
                cost          = case when v_el ? 'cost' then coalesce((v_el ->> 'cost')::bigint, 0) else cost end,
                reorder_point = case when v_el ? 'reorder_point' then coalesce((v_el ->> 'reorder_point')::numeric, 0) else reorder_point end,
                active        = case when v_el ? 'active' then coalesce((v_el ->> 'active')::boolean, true) else active end
              where id = v_item_vid
              returning name, sku into v_item_name, v_item_sku;

              v_item_price := coalesce(
                case when v_el ? 'price' then (v_el ->> 'price')::bigint end,
                case when jsonb_array_length(v_arr) = 1 and p ? 'price' then (p ->> 'price')::bigint end
              );
              if v_item_price is not null then
                insert into public.variant_prices (tenant_id, variant_id, currency, price)
                values (v_tenant, v_item_vid, v_base, v_item_price)
                on conflict (variant_id, currency) do update set price = excluded.price, deleted_at = null;
              end if;
            end if;
          else
            if v_mode <> 'full' then
              raise exception 'warehouse can only change cost and SKU' using errcode = '42501', hint = 'cost_and_sku_only';
            end if;
            v_item_price := coalesce(
              (v_el ->> 'price')::bigint,
              case when jsonb_array_length(v_arr) = 1 then (p ->> 'price')::bigint end
            );
            if v_item_price is null then
              raise exception 'price is required' using errcode = '22023', hint = 'price_required';
            end if;
            v_item_sku := coalesce(nullif(btrim(v_el ->> 'sku'), ''),
                                   'P-' || upper(substr(replace(v_item_vid::text, '-', ''), 21, 12)));
            v_item_name := coalesce(nullif(btrim(v_el ->> 'name'), ''), 'Default');

            insert into public.product_variants (
              id, tenant_id, product_id, name, sku, barcode, is_default, cost, reorder_point, active
            ) values (
              v_item_vid, v_tenant, v_pid, v_item_name, v_item_sku,
              nullif(btrim(v_el ->> 'barcode'), ''),
              (v_item_vid = v_default_vid),
              coalesce((v_el ->> 'cost')::bigint, 0),
              coalesce((v_el ->> 'reorder_point')::numeric, 0),
              coalesce((v_el ->> 'active')::boolean, true)
            );

            insert into public.variant_prices (tenant_id, variant_id, currency, price)
            values (v_tenant, v_item_vid, v_base, v_item_price)
            on conflict (variant_id, currency) do update set price = excluded.price, deleted_at = null;
          end if;

          if v_item_vid = v_default_vid then
            v_sku := v_item_sku;
          end if;
          v_var_results := v_var_results || jsonb_build_array(jsonb_build_object(
            'variant_id', v_item_vid,
            'name', v_item_name,
            'sku', v_item_sku,
            'is_default', (v_item_vid = v_default_vid)
          ));
        end loop;

        if v_mode = 'full' then
          update public.product_variants
             set active = false, deleted_at = now(), is_default = false
           where tenant_id = v_tenant
             and product_id = v_pid
             and deleted_at is null
             and not (id = any(v_submitted_ids));

          update public.variant_prices vp
             set deleted_at = now()
            from public.product_variants pv
           where vp.variant_id = pv.id
             and pv.tenant_id = v_tenant
             and pv.product_id = v_pid
             and pv.deleted_at is not null
             and vp.deleted_at is null;
        else
          select id, sku into v_vid, v_sku
          from public.product_variants
          where tenant_id = v_tenant and product_id = v_pid and is_default and deleted_at is null
          limit 1;
        end if;
      end if;
    end if;
  exception
    when unique_violation then
      get stacked diagnostics v_con = constraint_name;
      if v_con = 'product_variants_sku_per_tenant' then
        raise exception 'SKU already used' using errcode = '23505', hint = 'duplicate_sku';
      elsif v_con = 'product_variants_barcode_per_tenant' then
        raise exception 'barcode already used' using errcode = '23505', hint = 'duplicate_barcode';
      elsif v_con in ('products_pkey', 'product_variants_pkey') then
        raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
      end if;
      raise;
    when foreign_key_violation then
      raise exception 'unknown category' using errcode = '22023', hint = 'bad_category';
    when check_violation then
      raise exception 'invalid value' using errcode = '23514', hint = 'invalid_value';
  end;

  if v_has_variants then
    v_result := jsonb_build_object(
      'product_id', v_pid,
      'variant_id', v_vid,
      'sku', v_sku,
      'created', v_created,
      'variants', v_var_results
    );
  else
    v_result := jsonb_build_object(
      'product_id', v_pid,
      'variant_id', v_vid,
      'sku', v_sku,
      'created', v_created
    );
  end if;

  perform public.write_audit(
    case when v_created then 'product.create' else 'product.update' end, 'product', v_pid, null,
    jsonb_build_object('sku', v_sku, 'price', p -> 'price', 'mode', v_mode));

  return public.finish_op(p_op_id, v_result);
end;
$$;

revoke execute on function public.upsert_product(uuid, jsonb) from public, anon;
grant execute on function public.upsert_product(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- F10. Transfer destination locations visible to non-superadmin roles
--      without weakening public.locations SELECT RLS.
-- ---------------------------------------------------------------------------
create or replace function public.list_transfer_destinations()
returns table (
  id uuid,
  code text,
  name text,
  type text,
  address text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_wh_enabled boolean := false;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  if public.auth_role() = 'cashier' then
    raise exception 'cashiers cannot manage transfers'
      using errcode = '42501', hint = 'not_allowed';
  end if;

  select coalesce(m.warehouse, false)
    into v_wh_enabled
  from public.tenant_modules m
  where m.tenant_id = public.auth_tenant_id();

  return query
  select l.id, l.code, l.name, l.type, l.address
  from public.locations l
  where l.tenant_id = public.auth_tenant_id()
    and l.active
    and l.deleted_at is null
    and (l.type <> 'warehouse' or v_wh_enabled)
  order by l.name;
end;
$$;

revoke execute on function public.list_transfer_destinations() from public, anon;
grant execute on function public.list_transfer_destinations() to authenticated;
