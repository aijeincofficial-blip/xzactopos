-- F-10 Multi-Store Reports & Analytics (Full Mode).
-- 1. stock_snapshots_daily: end-of-day stock levels and valuation per store/warehouse.
-- 2. snapshot_daily_stock(p_day): RPC to snapshot stock levels.
-- 3. report_multi_store(from, to, location_id): multi-store analytics RPC for back-office.

-- ---------------------------------------------------------------------------
-- 1. Table: stock_snapshots_daily
-- ---------------------------------------------------------------------------

create table public.stock_snapshots_daily (
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  location_id   uuid not null,
  day           date not null,
  variant_id    uuid not null,
  qty_on_hand   numeric(14, 3) not null default 0,
  unit_cost     bigint not null default 0,
  total_value   bigint not null default 0,
  updated_at    timestamptz not null default now(),
  primary key (location_id, day, variant_id),
  constraint stock_snapshots_daily_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint stock_snapshots_daily_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id)
);

create index stock_snapshots_daily_tenant_day_idx on public.stock_snapshots_daily (tenant_id, day);
create index stock_snapshots_daily_location_day_idx on public.stock_snapshots_daily (location_id, day);

-- ---------------------------------------------------------------------------
-- 2. RPC: snapshot_daily_stock
-- ---------------------------------------------------------------------------

create or replace function public.snapshot_daily_stock(p_day date default null)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_tz     text;
  v_day    date;
  v_count  int;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();
  select coalesce(timezone, 'Asia/Manila') into v_tz from public.tenants where id = v_tenant;
  v_day := coalesce(p_day, (now() at time zone v_tz)::date);

  insert into public.stock_snapshots_daily (
    tenant_id, location_id, day, variant_id, qty_on_hand, unit_cost, total_value, updated_at
  )
  select
    sl.tenant_id,
    sl.location_id,
    v_day,
    sl.variant_id,
    sl.qty_on_hand,
    coalesce(sl.avg_cost, 0),
    round(sl.qty_on_hand * coalesce(sl.avg_cost, 0))::bigint,
    now()
  from public.stock_levels sl
  where sl.tenant_id = v_tenant
  on conflict (location_id, day, variant_id) do update set
    qty_on_hand = excluded.qty_on_hand,
    unit_cost   = excluded.unit_cost,
    total_value = excluded.total_value,
    updated_at  = now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. RLS for stock_snapshots_daily
-- ---------------------------------------------------------------------------

alter table public.stock_snapshots_daily enable row level security;

create policy stock_snapshots_daily_read on public.stock_snapshots_daily
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'admin', 'warehouse')
    and (
      (select public.is_superadmin())
      or location_id = any ((select public.auth_location_ids())::uuid[])
    )
  );

revoke all on public.stock_snapshots_daily from anon;
revoke insert, update, delete, truncate on public.stock_snapshots_daily from authenticated;
grant select on public.stock_snapshots_daily to authenticated;

revoke execute on function public.snapshot_daily_stock(date) from public, anon;
grant execute on function public.snapshot_daily_stock(date) to authenticated;

-- Backfill initial snapshot from current stock levels
insert into public.stock_snapshots_daily (
  tenant_id, location_id, day, variant_id, qty_on_hand, unit_cost, total_value, updated_at
)
select
  sl.tenant_id,
  sl.location_id,
  (now() at time zone coalesce(t.timezone, 'Asia/Manila'))::date,
  sl.variant_id,
  sl.qty_on_hand,
  sl.avg_cost,
  round(sl.qty_on_hand * sl.avg_cost)::bigint,
  now()
from public.stock_levels sl
join public.tenants t on t.id = sl.tenant_id
on conflict (location_id, day, variant_id) do nothing;

-- ---------------------------------------------------------------------------
-- 4. RPC: report_multi_store
-- ---------------------------------------------------------------------------

create or replace function public.report_multi_store(
  p_from        date,
  p_to          date,
  p_location_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tenant          uuid := public.auth_tenant_id();
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

  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then
    raise exception 'date range is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;

  if p_location_id is not null then
    if not (
      (select public.is_superadmin())
      or p_location_id = any ((select public.auth_location_ids())::uuid[])
    ) then
      raise exception 'access denied for location' using errcode = '42501', hint = 'forbidden';
    end if;
  end if;

  -- 1. Daily breakdown
  select coalesce(jsonb_agg(to_jsonb(x) order by x.day), '[]'::jsonb) into v_days from (
    select d.day,
           sum(d.net)::bigint as net,
           sum(d.gross)::bigint as gross,
           sum(d.discount)::bigint as discount,
           sum(d.tax)::bigint as tax,
           sum(d.cogs)::bigint as cogs,
           sum(d.txn_count)::int as txns,
           sum(d.cash)::bigint as cash,
           sum(d.ewallet)::bigint as ewallet,
           sum(d.utang)::bigint as utang,
           sum(d.net - d.cogs)::bigint as profit
    from public.daily_sales_summary d
    where d.tenant_id = v_tenant
      and d.day between p_from and p_to
      and (p_location_id is null or d.location_id = p_location_id)
    group by d.day
  ) x;

  -- 2. Period totals
  select jsonb_build_object(
    'net', coalesce(sum(d.net), 0),
    'gross', coalesce(sum(d.gross), 0),
    'discount', coalesce(sum(d.discount), 0),
    'tax', coalesce(sum(d.tax), 0),
    'cogs', coalesce(sum(d.cogs), 0),
    'txns', coalesce(sum(d.txn_count), 0),
    'cash', coalesce(sum(d.cash), 0),
    'ewallet', coalesce(sum(d.ewallet), 0),
    'utang', coalesce(sum(d.utang), 0),
    'profit', coalesce(sum(d.net - d.cogs), 0),
    'margin_percent', case when coalesce(sum(d.net), 0) > 0
      then round(((sum(d.net) - sum(d.cogs))::numeric / sum(d.net)::numeric) * 100, 2)
      else 0 end
  )
  into v_totals
  from public.daily_sales_summary d
  where d.tenant_id = v_tenant
    and d.day between p_from and p_to
    and (p_location_id is null or d.location_id = p_location_id);

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
      and i.day between p_from and p_to
      and (p_location_id is null or i.location_id = p_location_id)
    group by i.variant_id, pv.sku
    having sum(i.qty) > 0
    order by sum(i.revenue) desc, max(i.product_name)
    limit 20
  ) x;

  -- 4. Per-store comparison breakdown
  select coalesce(jsonb_agg(to_jsonb(x) order by x.code), '[]'::jsonb) into v_stores from (
    select l.id as location_id,
           l.code,
           l.name,
           l.type,
           coalesce(sum(d.net), 0)::bigint as net,
           coalesce(sum(d.gross), 0)::bigint as gross,
           coalesce(sum(d.cogs), 0)::bigint as cogs,
           coalesce(sum(d.txn_count), 0)::int as txns,
           coalesce(sum(d.net - d.cogs), 0)::bigint as profit,
           coalesce((
             select sum(round(sl.qty_on_hand * sl.avg_cost))::bigint
             from public.stock_levels sl
             where sl.location_id = l.id and sl.tenant_id = v_tenant
           ), 0)::bigint as stock_value,
           coalesce((
             select sum(sl.qty_on_hand)::numeric(14, 3)
             from public.stock_levels sl
             where sl.location_id = l.id and sl.tenant_id = v_tenant
           ), 0)::numeric(14, 3) as stock_units
    from public.locations l
    left join public.daily_sales_summary d
      on d.location_id = l.id and d.tenant_id = v_tenant and d.day between p_from and p_to
    where l.tenant_id = v_tenant and l.active and l.deleted_at is null
      and (p_location_id is null or l.id = p_location_id)
      and (
        (select public.is_superadmin())
        or l.id = any ((select public.auth_location_ids())::uuid[])
      )
    group by l.id, l.code, l.name, l.type
  ) x;

  -- 5. Stock valuation summary
  select jsonb_build_object(
    'total_value', coalesce(sum(round(sl.qty_on_hand * sl.avg_cost)), 0)::bigint,
    'total_units', coalesce(sum(sl.qty_on_hand), 0)::numeric(14, 3),
    'items_count', count(distinct sl.variant_id)::int
  )
  into v_stock_valuation
  from public.stock_levels sl
  where sl.tenant_id = v_tenant
    and (p_location_id is null or sl.location_id = p_location_id)
    and (
      (select public.is_superadmin())
      or sl.location_id = any ((select public.auth_location_ids())::uuid[])
    );

  -- 6. Transfers activity summary
  select jsonb_build_object(
    'total_transfers', count(*)::int,
    'shipped_count', count(*) filter (where t.status = 'shipped')::int,
    'received_count', count(*) filter (where t.status = 'received')::int,
    'discrepancy_count', count(*) filter (where t.has_discrepancy)::int
  )
  into v_transfers
  from public.transfers t
  where t.tenant_id = v_tenant
    and (t.created_at at time zone coalesce((select timezone from public.tenants where id = v_tenant), 'Asia/Manila'))::date between p_from and p_to
    and (p_location_id is null or t.from_location_id = p_location_id or t.to_location_id = p_location_id)
    and (
      (select public.is_superadmin())
      or t.from_location_id = any ((select public.auth_location_ids())::uuid[])
      or t.to_location_id = any ((select public.auth_location_ids())::uuid[])
    );

  -- 7. Expenses summary
  select jsonb_build_object(
    'total', coalesce(sum(e.amount), 0),
    'cash', coalesce(sum(e.cash), 0),
    'ewallet', coalesce(sum(e.ewallet), 0),
    'count', coalesce(sum(e.entry_count), 0),
    'by_category', coalesce((
      select jsonb_agg(jsonb_build_object('category', c.category, 'amount', c.amount, 'count', c.n)
                       order by c.amount desc, c.category)
      from (select e2.category, sum(e2.amount)::bigint as amount, sum(e2.entry_count)::int as n
            from public.daily_expense_summary e2
            where e2.tenant_id = v_tenant and e2.day between p_from and p_to
              and (p_location_id is null or e2.location_id = p_location_id)
            group by e2.category
            having sum(e2.entry_count) > 0) c), '[]'::jsonb),
    'days', coalesce((
      select jsonb_agg(jsonb_build_object('day', dd.day, 'amount', dd.amount) order by dd.day)
      from (select e3.day, sum(e3.amount)::bigint as amount
            from public.daily_expense_summary e3
            where e3.tenant_id = v_tenant and e3.day between p_from and p_to
              and (p_location_id is null or e3.location_id = p_location_id)
            group by e3.day
            having sum(e3.entry_count) > 0) dd), '[]'::jsonb))
  into v_exp
  from public.daily_expense_summary e
  where e.tenant_id = v_tenant and e.day between p_from and p_to
    and (p_location_id is null or e.location_id = p_location_id);

  -- 8. Services summary
  select jsonb_build_object(
    'count', coalesce(sum(s.txn_count) filter (where s.kind in ('cash_in', 'cash_out', 'load')), 0),
    'fee_total', coalesce(sum(s.fee), 0),
    'by_kind', coalesce((
      select jsonb_agg(jsonb_build_object('kind', k.kind, 'count', k.n, 'amount', k.amount, 'fee', k.fee)
                       order by array_position(v_kinds, k.kind))
      from (select s2.kind, sum(s2.txn_count)::int as n, sum(s2.amount)::bigint as amount, sum(s2.fee)::bigint as fee
            from public.daily_service_summary s2
            where s2.tenant_id = v_tenant and s2.day between p_from and p_to
              and (p_location_id is null or s2.location_id = p_location_id)
            group by s2.kind
            having sum(s2.txn_count) > 0) k), '[]'::jsonb),
    'float', coalesce((
      select jsonb_agg(jsonb_build_object('wallet', f.wallet, 'balance', f.balance) order by array_position(v_wals, f.wallet))
      from (select w.wallet, sum(w.balance)::bigint as balance
            from public.wallet_float w
            where w.tenant_id = v_tenant
              and (p_location_id is null or w.location_id = p_location_id)
            group by w.wallet) f), '[]'::jsonb))
  into v_svc
  from public.daily_service_summary s
  where s.tenant_id = v_tenant and s.day between p_from and p_to
    and (p_location_id is null or s.location_id = p_location_id);

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
    where c.tenant_id = v_tenant and c.deleted_at is null
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
$$;

revoke execute on function public.report_multi_store(date, date, uuid) from public, anon;
grant execute on function public.report_multi_store(date, date, uuid) to authenticated;
