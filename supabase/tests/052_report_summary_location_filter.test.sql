-- F-10 Per-branch report filtering on public.report_summary(p_from, p_to, p_location_id).
-- Verifies:
--   1. 2-argument call returns combined totals across stores and preserves exact top-level keys
--   2. Scoped call for Store 1 isolates sales, top items, utang, expenses, services, and wallet floats
--   3. Scoped call for Store 2 isolates Store 2 metrics
--   4. Store manager assigned only to Store 1 can query Store 1, and is refused (42501 / forbidden) on Store 2

begin;
select plan(18);

create temp table ids (key text primary key, id uuid);

insert into ids (key, id) values
  ('tenant', '20000000-0000-0000-0000-000000000001'::uuid),
  ('s01',    '20000000-0000-0000-0000-000000000011'::uuid),
  ('s02',    '20000000-0000-0000-0000-000000000012'::uuid),
  ('owner',  '20000000-0000-0000-0000-000000000021'::uuid),
  ('mgr1',   '20000000-0000-0000-0000-000000000022'::uuid),
  ('p1',     '20000000-0000-0000-0000-000000000031'::uuid),
  ('v1',     '20000000-0000-0000-0000-000000000041'::uuid),
  ('p2',     '20000000-0000-0000-0000-000000000032'::uuid),
  ('v2',     '20000000-0000-0000-0000-000000000042'::uuid),
  ('c1',     '20000000-0000-0000-0000-000000000051'::uuid),
  ('c2',     '20000000-0000-0000-0000-000000000052'::uuid);

grant select on ids to authenticated;

create function pg_temp.id(k text) returns uuid language sql stable as
  $$ select id from ids where key = k $$;

insert into public.tenants (id, name, slug, base_currency, timezone)
values (pg_temp.id('tenant'), 'Branch Filter Co', 'branch-filter-co', 'PHP', 'Asia/Manila');

insert into public.tenant_modules (tenant_id, pos, warehouse)
values (pg_temp.id('tenant'), true, true);

insert into public.tenant_settings (tenant_id)
values (pg_temp.id('tenant'));

insert into auth.users (id, email) values
  (pg_temp.id('owner'), 'owner@branch-report.invalid'),
  (pg_temp.id('mgr1'),  'mgr1@branch-report.invalid');

insert into public.locations (id, tenant_id, code, name, type) values
  (pg_temp.id('s01'), pg_temp.id('tenant'), 'S01', 'Downtown Branch', 'store'),
  (pg_temp.id('s02'), pg_temp.id('tenant'), 'S02', 'Uptown Branch', 'store');

insert into public.profiles (user_id, tenant_id, username, full_name, role, active) values
  (pg_temp.id('owner'), pg_temp.id('tenant'), 'owner', 'Owner User', 'superadmin', true),
  (pg_temp.id('mgr1'),  pg_temp.id('tenant'), 'mgr1',  'Manager S01', 'admin', true);

insert into public.location_access (tenant_id, user_id, location_id, position) values
  (pg_temp.id('tenant'), pg_temp.id('mgr1'), pg_temp.id('s01'), 'manager');

insert into public.products (id, tenant_id, name) values
  (pg_temp.id('p1'), pg_temp.id('tenant'), 'Barako Coffee'),
  (pg_temp.id('p2'), pg_temp.id('tenant'), 'Calamansi Juice');

insert into public.product_variants (id, tenant_id, product_id, sku) values
  (pg_temp.id('v1'), pg_temp.id('tenant'), pg_temp.id('p1'), 'COFFEE-01'),
  (pg_temp.id('v2'), pg_temp.id('tenant'), pg_temp.id('p2'), 'JUICE-01');

insert into public.customers (id, tenant_id, name) values
  (pg_temp.id('c1'), pg_temp.id('tenant'), 'Aling Nena'),
  (pg_temp.id('c2'), pg_temp.id('tenant'), 'Mang Tomas');

insert into public.customer_ledger (tenant_id, customer_id, kind, amount, location_id) values
  (pg_temp.id('tenant'), pg_temp.id('c1'), 'charge', 4500, pg_temp.id('s01')),
  (pg_temp.id('tenant'), pg_temp.id('c2'), 'charge', 8000, pg_temp.id('s02'));

insert into public.daily_sales_summary (
  tenant_id, location_id, day, gross, discount, net, tax, cogs, txn_count, cash, ewallet, card, utang
) values
  (pg_temp.id('tenant'), pg_temp.id('s01'), '2026-11-08', 25000, 1000, 24000, 0, 15000, 3, 19500, 0, 0, 4500),
  (pg_temp.id('tenant'), pg_temp.id('s02'), '2026-11-08', 18000, 0,    18000, 0, 11000, 2, 0, 10000, 0, 8000);

insert into public.daily_item_sales (
  tenant_id, location_id, day, variant_id, product_name, qty, revenue, cogs
) values
  (pg_temp.id('tenant'), pg_temp.id('s01'), '2026-11-08', pg_temp.id('v1'), 'Barako Coffee',   5, 24000, 15000),
  (pg_temp.id('tenant'), pg_temp.id('s02'), '2026-11-08', pg_temp.id('v2'), 'Calamansi Juice', 3, 18000, 11000);

insert into public.daily_expense_summary (
  tenant_id, location_id, day, category, amount, entry_count, cash, ewallet
) values
  (pg_temp.id('tenant'), pg_temp.id('s01'), '2026-11-08', 'utilities', 3000, 1, 3000, 0),
  (pg_temp.id('tenant'), pg_temp.id('s02'), '2026-11-08', 'transport', 1200, 1, 1200, 0);

insert into public.daily_service_summary (
  tenant_id, location_id, day, kind, txn_count, amount, fee, cash, float_change
) values
  (pg_temp.id('tenant'), pg_temp.id('s01'), '2026-11-08', 'cash_in', 2, 100000, 2000, 102000, -100000),
  (pg_temp.id('tenant'), pg_temp.id('s02'), '2026-11-08', 'load',    1,  50000,  500,  50500,  -50000);

insert into public.wallet_float (tenant_id, location_id, wallet, balance, txn_count) values
  (pg_temp.id('tenant'), pg_temp.id('s01'), 'gcash', 75000, 2),
  (pg_temp.id('tenant'), pg_temp.id('s02'), 'gcash', 25000, 1);

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
-- 1. Combined 2-arg call (all stores)
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;

create temp table rep_all as
select public.report_summary('2026-11-08'::date, '2026-11-08'::date) as r;
grant select on rep_all to authenticated;

select is(
  (select (select array_agg(k order by k) from jsonb_object_keys(r) k)::text from rep_all),
  '{days,expenses,from,server_time,services,to,top_items,totals,utang}',
  '1. 2-arg report_summary preserves exact default top-level keys'
);

select is((select r -> 'totals' ->> 'net' from rep_all), '42000', '2. all stores combined net is 42000');
select is((select r -> 'utang' ->> 'owed' from rep_all), '12500', '3. all stores combined utang owed is 12500');
select is((select r -> 'expenses' ->> 'total' from rep_all), '4200', '4. all stores combined expenses is 4200');
select is((select r -> 'services' ->> 'fee_total' from rep_all), '2500', '5. all stores combined service fees is 2500');
select is((select r -> 'services' -> 'float' -> 0 ->> 'balance' from rep_all), '100000', '6. all stores combined gcash float is 100000');

-- ---------------------------------------------------------------------------
-- 2. Scoped 3-arg call for Store 1 (S01)
-- ---------------------------------------------------------------------------
create temp table rep_s01 as
select public.report_summary('2026-11-08'::date, '2026-11-08'::date, pg_temp.id('s01')) as r;
grant select on rep_s01 to authenticated;

select is((select r ->> 'location_id' from rep_s01), pg_temp.id('s01')::text, '7. scoped S01 echoes location_id');
select is((select r -> 'totals' ->> 'net' from rep_s01), '24000', '8. scoped S01 net sales is 24000');
select is((select jsonb_array_length(r -> 'top_items') from rep_s01), 1, '9. scoped S01 has 1 top item');
select is((select r -> 'top_items' -> 0 ->> 'name' from rep_s01), 'Barako Coffee', '10. scoped S01 top item is Barako Coffee');
select is((select r -> 'utang' ->> 'owed' from rep_s01), '4500', '11. scoped S01 utang owed is 4500 (Aling Nena only)');
select is((select r -> 'expenses' ->> 'total' from rep_s01), '3000', '12. scoped S01 expenses total is 3000');
select is((select r -> 'services' ->> 'fee_total' from rep_s01), '2000', '13. scoped S01 service fee total is 2000');
select is((select r -> 'services' -> 'float' -> 0 ->> 'balance' from rep_s01), '75000', '14. scoped S01 gcash float is 75000');

-- ---------------------------------------------------------------------------
-- 3. Scoped 3-arg call for Store 2 (S02)
-- ---------------------------------------------------------------------------
create temp table rep_s02 as
select public.report_summary('2026-11-08'::date, '2026-11-08'::date, pg_temp.id('s02')) as r;
grant select on rep_s02 to authenticated;

select is((select r -> 'totals' ->> 'net' from rep_s02), '18000', '15. scoped S02 net sales is 18000');
select is((select r -> 'utang' ->> 'owed' from rep_s02), '8000', '16. scoped S02 utang owed is 8000 (Mang Tomas only)');

-- ---------------------------------------------------------------------------
-- 4. Store manager location isolation
-- ---------------------------------------------------------------------------
select pg_temp.login('mgr1');

select is(
  (public.report_summary('2026-11-08'::date, '2026-11-08'::date, '20000000-0000-0000-0000-000000000011'::uuid) -> 'totals' ->> 'net'),
  '24000',
  '17. manager assigned to S01 can query S01 report_summary'
);

select throws_ok(
  $$ select public.report_summary('2026-11-08'::date, '2026-11-08'::date, '20000000-0000-0000-0000-000000000012'::uuid) $$,
  '42501',
  null,
  '18. manager assigned only to S01 is refused (42501) when querying S02'
);

reset role;
select * from finish();
rollback;
