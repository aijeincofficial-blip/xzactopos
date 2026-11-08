-- F-10 Multi-Store Reports & Analytics tests.
-- Verifies:
--   1. stock_snapshots_daily and snapshot_daily_stock()
--   2. Multi-store rollups report across all locations
--   3. Scoped report for single store
--   4. Warehouse inventory valuation and transfer stats
--   5. Store manager permissions & location isolation
--   6. Cashier restrictions and range validation

begin;
select plan(21);

-- ---------------------------------------------------------------------------
-- Setup Fixtures
-- ---------------------------------------------------------------------------

create temp table ids (key text primary key, id uuid);

insert into ids (key, id) values
  ('tenant', '10000000-0000-0000-0000-000000000001'::uuid),
  ('s01',    '10000000-0000-0000-0000-000000000011'::uuid),
  ('s02',    '10000000-0000-0000-0000-000000000012'::uuid),
  ('w01',    '10000000-0000-0000-0000-000000000013'::uuid),
  ('owner',  '10000000-0000-0000-0000-000000000021'::uuid),
  ('mgr1',   '10000000-0000-0000-0000-000000000022'::uuid),
  ('cashier','10000000-0000-0000-0000-000000000023'::uuid),
  ('p1',     '10000000-0000-0000-0000-000000000031'::uuid),
  ('v1',     '10000000-0000-0000-0000-000000000041'::uuid),
  ('p2',     '10000000-0000-0000-0000-000000000032'::uuid),
  ('v2',     '10000000-0000-0000-0000-000000000042'::uuid);

grant select on ids to authenticated;

create function pg_temp.id(k text) returns uuid language sql stable as
  $$ select id from ids where key = k $$;

insert into public.tenants (id, name, slug, base_currency, timezone)
values (pg_temp.id('tenant'), 'Report Test Co', 'report-test-co', 'PHP', 'Asia/Manila');

insert into public.tenant_modules (tenant_id, pos, warehouse) values
  (pg_temp.id('tenant'), true, true);

insert into public.tenant_settings (tenant_id)
values (pg_temp.id('tenant'));

insert into auth.users (id, email) values
  (pg_temp.id('owner'), 'owner@report.invalid'),
  (pg_temp.id('mgr1'), 'mgr1@report.invalid'),
  (pg_temp.id('cashier'), 'cashier@report.invalid');

insert into public.locations (id, tenant_id, code, name, type) values
  (pg_temp.id('s01'), pg_temp.id('tenant'), 'S01', 'Store One', 'store'),
  (pg_temp.id('s02'), pg_temp.id('tenant'), 'S02', 'Store Two', 'store'),
  (pg_temp.id('w01'), pg_temp.id('tenant'), 'W01', 'Central Warehouse', 'warehouse');

insert into public.profiles (user_id, tenant_id, username, full_name, role, active) values
  (pg_temp.id('owner'), pg_temp.id('tenant'), 'owner', 'Owner User', 'superadmin', true),
  (pg_temp.id('mgr1'),  pg_temp.id('tenant'), 'mgr1', 'Manager One', 'admin', true),
  (pg_temp.id('cashier'), pg_temp.id('tenant'), 'cashier', 'Cashier One', 'cashier', true);

insert into public.location_access (tenant_id, user_id, location_id, position) values
  (pg_temp.id('tenant'), pg_temp.id('mgr1'), pg_temp.id('s01'), 'manager'),
  (pg_temp.id('tenant'), pg_temp.id('cashier'), pg_temp.id('s01'), null);

-- Catalog
insert into public.products (id, tenant_id, name) values
  (pg_temp.id('p1'), pg_temp.id('tenant'), 'Premium Rice'),
  (pg_temp.id('p2'), pg_temp.id('tenant'), 'Canned Tuna');

insert into public.product_variants (id, tenant_id, product_id, sku) values
  (pg_temp.id('v1'), pg_temp.id('tenant'), pg_temp.id('p1'), 'RICE-01'),
  (pg_temp.id('v2'), pg_temp.id('tenant'), pg_temp.id('p2'), 'TUNA-01');

insert into public.variant_prices (tenant_id, variant_id, currency, price) values
  (pg_temp.id('tenant'), pg_temp.id('v1'), 'PHP', 15000),
  (pg_temp.id('tenant'), pg_temp.id('v2'), 'PHP', 6000);

-- Stock levels
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.id('tenant'), pg_temp.id('s01'), pg_temp.id('v1'), 10, 'receipt', 10000),
  (pg_temp.id('tenant'), pg_temp.id('s01'), pg_temp.id('v2'), 5,  'receipt', 4000),
  (pg_temp.id('tenant'), pg_temp.id('s02'), pg_temp.id('v1'), 4,  'receipt', 10000),
  (pg_temp.id('tenant'), pg_temp.id('w01'), pg_temp.id('v1'), 50, 'receipt', 9000);

-- Sales & Rollups
insert into public.daily_sales_summary (
  tenant_id, location_id, day, gross, discount, net, tax, cogs, txn_count, cash, ewallet, utang
) values
  (pg_temp.id('tenant'), pg_temp.id('s01'), '2026-11-08', 30000, 2000, 28000, 0, 20000, 2, 28000, 0, 0),
  (pg_temp.id('tenant'), pg_temp.id('s02'), '2026-11-08', 15000, 0, 15000, 0, 10000, 1, 0, 15000, 0);

insert into public.daily_item_sales (
  tenant_id, location_id, day, variant_id, product_name, qty, revenue, cogs
) values
  (pg_temp.id('tenant'), pg_temp.id('s01'), '2026-11-08', pg_temp.id('v1'), 'Premium Rice', 2, 28000, 20000),
  (pg_temp.id('tenant'), pg_temp.id('s02'), '2026-11-08', pg_temp.id('v1'), 'Premium Rice', 1, 15000, 10000);

-- Transfer
insert into public.transfers (
  id, tenant_id, transfer_no, from_location_id, to_location_id, status, shipped_at, shipped_by, created_at
) values
  (public.uuid_generate_v7(), pg_temp.id('tenant'), 'TRF-261108-0001', pg_temp.id('w01'), pg_temp.id('s01'), 'shipped', now(), pg_temp.id('owner'), '2026-11-08T04:00:00Z');

-- Helper login function
create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', pg_temp.id(p_user),
      'role', 'authenticated',
      'tenant_id', pg_temp.id('tenant')
    )::text,
    true
  );
$$;

-- ---------------------------------------------------------------------------
-- 1. Test Daily Stock Snapshots
-- ---------------------------------------------------------------------------

select pg_temp.login('owner');
set local role authenticated;

select is(
  public.snapshot_daily_stock('2026-11-08'::date),
  4,
  'snapshot_daily_stock writes 4 snapshots across locations and variants'
);

select is(
  (select count(*)::int from public.stock_snapshots_daily where tenant_id = pg_temp.id('tenant')),
  4,
  'stock_snapshots_daily has exactly 4 rows'
);

select is(
  (select sum(total_value)::bigint from public.stock_snapshots_daily where tenant_id = pg_temp.id('tenant')),
  (10*10000 + 5*4000 + 4*10000 + 50*9000)::bigint,
  'total valuation of snapshot matches current stock levels'
);

-- ---------------------------------------------------------------------------
-- 2. Test Multi-Store Report (All Locations / Superadmin)
-- ---------------------------------------------------------------------------

create temp table all_rep as
select public.report_multi_store('2026-11-08'::date, '2026-11-08'::date) as r;
grant select on all_rep to authenticated;

select is(
  (select r -> 'totals' ->> 'net' from all_rep),
  '43000',
  'all stores: combined net sales is 43000'
);

select is(
  (select r -> 'totals' ->> 'cogs' from all_rep),
  '30000',
  'all stores: combined cogs is 30000'
);

select is(
  (select r -> 'totals' ->> 'profit' from all_rep),
  '13000',
  'all stores: combined profit is 13000'
);

select is(
  (select r -> 'totals' ->> 'txns' from all_rep),
  '3',
  'all stores: combined txns is 3'
);

select is(
  (select r -> 'totals' ->> 'cash' from all_rep),
  '28000',
  'all stores: cash payments 28000'
);

select is(
  (select r -> 'totals' ->> 'ewallet' from all_rep),
  '15000',
  'all stores: ewallet payments 15000'
);

select is(
  (select jsonb_array_length(r -> 'stores') from all_rep),
  3,
  'all stores: stores array contains 3 locations (S01, S02, W01)'
);

select is(
  (select r -> 'transfers' ->> 'shipped_count' from all_rep),
  '1',
  'all stores: transfer count is 1'
);

select is(
  (select r -> 'top_items' -> 0 ->> 'qty' from all_rep),
  '3.000',
  'all stores: top item total qty is 3'
);

-- ---------------------------------------------------------------------------
-- 3. Test Scoped Report (Single Store S01)
-- ---------------------------------------------------------------------------

create temp table s01_rep as
select public.report_multi_store('2026-11-08'::date, '2026-11-08'::date, pg_temp.id('s01')) as r;
grant select on s01_rep to authenticated;

select is(
  (select r -> 'totals' ->> 'net' from s01_rep),
  '28000',
  'scoped s01: net sales is 28000'
);

select is(
  (select r -> 'totals' ->> 'cogs' from s01_rep),
  '20000',
  'scoped s01: cogs is 20000'
);

select is(
  (select r -> 'totals' ->> 'txns' from s01_rep),
  '2',
  'scoped s01: txns is 2'
);

select is(
  (select jsonb_array_length(r -> 'stores') from s01_rep),
  1,
  'scoped s01: stores array contains only 1 store'
);

-- ---------------------------------------------------------------------------
-- 4. Manager Access Checks
-- ---------------------------------------------------------------------------

select pg_temp.login('mgr1');

-- Manager 1 has access to S01
select lives_ok(
  $$ select public.report_multi_store('2026-11-08'::date, '2026-11-08'::date, '10000000-0000-0000-0000-000000000011'::uuid) $$,
  'manager of S01 can generate report for S01'
);

-- Manager 1 does not have access to S02
select throws_ok(
  $$ select public.report_multi_store('2026-11-08'::date, '2026-11-08'::date, '10000000-0000-0000-0000-000000000012'::uuid) $$,
  '42501',
  null,
  'manager of S01 is forbidden from generating report for S02'
);

-- ---------------------------------------------------------------------------
-- 5. Cashier & Range Restrictions
-- ---------------------------------------------------------------------------

select pg_temp.login('cashier');

select is(
  (public.report_multi_store('2026-11-08'::date, '2026-11-08'::date) -> 'totals' ->> 'net'),
  '0',
  'cashier receives empty report totals'
);

select throws_ok(
  $$ select public.report_multi_store('2026-11-09'::date, '2026-11-08'::date) $$,
  '22023',
  null,
  'invalid date range is rejected'
);

select throws_ok(
  $$ select public.report_multi_store('2025-01-01'::date, '2026-06-01'::date) $$,
  '22023',
  null,
  'date range exceeding 366 days is rejected'
);

reset role;
select * from finish();
rollback;
