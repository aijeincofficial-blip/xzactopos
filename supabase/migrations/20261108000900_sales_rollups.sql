-- P6-01 Sales rollups and the report RPC (solo reports).
--   daily_sales_summary  per store and day (tenant timezone): gross, discount, net, tax, cogs, transactions, cash / ewallet / utang
--   daily_item_sales     per store, day and variant: qty, revenue, cogs
-- Kept by deferred constraint triggers on sales, so lines and payments exist when they run and a rolled-back op leaves nothing.
-- report_summary reads these tables (and the utang ledger) only; clients never read raw sales for reports.

create table public.daily_sales_summary (
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  location_id  uuid not null,
  day          date not null,
  gross        bigint not null default 0,
  discount     bigint not null default 0,
  net          bigint not null default 0,
  tax          bigint not null default 0,
  cogs         bigint not null default 0,
  txn_count    int not null default 0,
  cash         bigint not null default 0,
  ewallet      bigint not null default 0,
  utang        bigint not null default 0,
  updated_at   timestamptz not null default now(),
  primary key (location_id, day),
  constraint daily_sales_summary_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id)
);

create table public.daily_item_sales (
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  location_id   uuid not null,
  day           date not null,
  variant_id    uuid not null,
  product_name  text not null,
  qty           numeric(14, 3) not null default 0,
  revenue       bigint not null default 0,
  cogs          bigint not null default 0,
  primary key (location_id, day, variant_id),
  constraint daily_item_sales_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint daily_item_sales_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id)
);

create index daily_sales_summary_tenant_day_idx on public.daily_sales_summary (tenant_id, day);
create index daily_item_sales_tenant_day_idx on public.daily_item_sales (tenant_id, day);

-- Adds (p_sign = 1) or removes (p_sign = -1) one sale to the rollups.
create or replace function public.rollup_sale(p_sale uuid, p_sign int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s    public.sales;
  v_tz text;
  v_day date;
begin
  select * into s from public.sales where id = p_sale;
  if not found then
    return;
  end if;
  select coalesce(t.timezone, 'UTC') into v_tz from public.tenants t where t.id = s.tenant_id;
  v_day := (s.sold_at at time zone v_tz)::date;

  insert into public.daily_sales_summary as d
    (tenant_id, location_id, day, gross, discount, net, tax, cogs, txn_count, cash, ewallet, utang, updated_at)
  select s.tenant_id, s.location_id, v_day,
         p_sign * s.subtotal, p_sign * s.discount, p_sign * s.total, p_sign * s.tax,
         p_sign * coalesce((select sum(round(i.unit_cost * i.qty)) from public.sale_items i where i.sale_id = s.id), 0)::bigint,
         p_sign,
         p_sign * coalesce((select sum(p.amount) from public.payments p where p.sale_id = s.id and p.method = 'cash'), 0)::bigint,
         p_sign * coalesce((select sum(p.amount) from public.payments p where p.sale_id = s.id and p.method = 'ewallet'), 0)::bigint,
         p_sign * coalesce((select sum(p.amount) from public.payments p where p.sale_id = s.id and p.method = 'utang'), 0)::bigint,
         now()
  on conflict (location_id, day) do update set
    gross = d.gross + excluded.gross, discount = d.discount + excluded.discount, net = d.net + excluded.net,
    tax = d.tax + excluded.tax, cogs = d.cogs + excluded.cogs, txn_count = d.txn_count + excluded.txn_count,
    cash = d.cash + excluded.cash, ewallet = d.ewallet + excluded.ewallet, utang = d.utang + excluded.utang,
    updated_at = now();

  insert into public.daily_item_sales as d (tenant_id, location_id, day, variant_id, product_name, qty, revenue, cogs)
  select s.tenant_id, s.location_id, v_day, i.variant_id, max(i.product_name),
         p_sign * sum(i.qty), p_sign * sum(i.line_total)::bigint, p_sign * sum(round(i.unit_cost * i.qty))::bigint
  from public.sale_items i
  where i.sale_id = s.id
  group by i.variant_id
  on conflict (location_id, day, variant_id) do update set
    qty = d.qty + excluded.qty, revenue = d.revenue + excluded.revenue, cogs = d.cogs + excluded.cogs,
    product_name = excluded.product_name;
end;
$$;

create or replace function public.trg_rollup_sale_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'completed' then
    perform public.rollup_sale(new.id, 1);
  end if;
  return null;
end;
$$;

create or replace function public.trg_rollup_sale_void()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'completed' and new.status = 'voided' then
    perform public.rollup_sale(new.id, -1);
  end if;
  return null;
end;
$$;

revoke execute on function public.rollup_sale(uuid, int) from public, anon, authenticated;
revoke execute on function public.trg_rollup_sale_insert() from public, anon, authenticated;
revoke execute on function public.trg_rollup_sale_void() from public, anon, authenticated;

create constraint trigger sales_rollup_insert after insert on public.sales
  deferrable initially deferred for each row execute function public.trg_rollup_sale_insert();
create constraint trigger sales_rollup_void after update of status on public.sales
  deferrable initially deferred for each row execute function public.trg_rollup_sale_void();

-- Sales made before this migration
select public.rollup_sale(s.id, 1) from public.sales s where s.status = 'completed';

-- RLS: superadmin and admins read the rollups of their stores; nobody writes from a client
alter table public.daily_sales_summary enable row level security;
alter table public.daily_item_sales enable row level security;

create policy daily_sales_summary_read on public.daily_sales_summary
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'admin')
         and location_id = any ((select public.auth_location_ids())::uuid[]));
create policy daily_item_sales_read on public.daily_item_sales
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'admin')
         and location_id = any ((select public.auth_location_ids())::uuid[]));

revoke all on public.daily_sales_summary, public.daily_item_sales from anon;
revoke insert, update, delete, truncate on public.daily_sales_summary, public.daily_item_sales from authenticated;
grant select on public.daily_sales_summary, public.daily_item_sales to authenticated;

-- ---------------------------------------------------------------------------
-- report_summary(from, to): { days, totals, top_items, utang }, from the rollups only. Runs as the caller (RLS applies).
-- ---------------------------------------------------------------------------

create or replace function public.report_summary(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_days   jsonb;
  v_totals jsonb;
  v_top    jsonb;
  v_utang  jsonb;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then
    raise exception 'date range is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.day), '[]'::jsonb) into v_days from (
    select d.day, sum(d.net)::bigint as net, sum(d.gross)::bigint as gross, sum(d.discount)::bigint as discount,
           sum(d.cogs)::bigint as cogs, sum(d.txn_count)::int as txns,
           sum(d.cash)::bigint as cash, sum(d.ewallet)::bigint as ewallet, sum(d.utang)::bigint as utang
    from public.daily_sales_summary d
    where d.tenant_id = v_tenant and d.day between p_from and p_to
    group by d.day
  ) x;

  select jsonb_build_object(
    'net', coalesce(sum(d.net), 0), 'gross', coalesce(sum(d.gross), 0), 'discount', coalesce(sum(d.discount), 0),
    'cogs', coalesce(sum(d.cogs), 0), 'txns', coalesce(sum(d.txn_count), 0),
    'cash', coalesce(sum(d.cash), 0), 'ewallet', coalesce(sum(d.ewallet), 0), 'utang', coalesce(sum(d.utang), 0))
  into v_totals
  from public.daily_sales_summary d
  where d.tenant_id = v_tenant and d.day between p_from and p_to;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc, x.name), '[]'::jsonb) into v_top from (
    select i.variant_id, max(i.product_name) as name, sum(i.qty) as qty, sum(i.revenue)::bigint as revenue
    from public.daily_item_sales i
    where i.tenant_id = v_tenant and i.day between p_from and p_to
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
    where c.tenant_id = v_tenant and c.deleted_at is null
    group by c.id, c.name
  ) b;

  return jsonb_build_object('from', p_from, 'to', p_to, 'days', v_days, 'totals', v_totals,
                            'top_items', v_top, 'utang', v_utang, 'server_time', now());
end;
$$;

revoke execute on function public.report_summary(date, date) from public, anon;
grant execute on function public.report_summary(date, date) to authenticated;
