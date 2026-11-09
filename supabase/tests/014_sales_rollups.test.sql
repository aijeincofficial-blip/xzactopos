-- P6-01 rollups equal the raw sales; cancelling removes a sale; report_summary reads the rollups; access by role
begin;
select plan(25);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('id:' || p)::uuid $$;
create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;
create function pg_temp.op(k text, kind text, payload jsonb) returns jsonb language sql immutable as $$
  select jsonb_build_object('op_id', pg_temp.id('op:' || k), 'kind', kind, 'payload', payload)
$$;
create function pg_temp.push1(k text, kind text, payload jsonb) returns jsonb language sql as $$
  select public.sync_push(jsonb_build_array(pg_temp.op(k, kind, payload))) -> 0
$$;
-- sale of one line; sold_at is a UTC timestamp string; pays = jsonb array
create function pg_temp.sell(k text, v text, qty numeric, price bigint, pays jsonb, at text default '2026-11-08T02:00:00Z', extra jsonb default '{}') returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:' || k), 'local_no', 'R-' || k, 'sold_at', at,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'qty', qty, 'unit_price', price, 'unit_cost', 400)),
    'payments', pays) || extra)
$$;

insert into auth.users (id, email) select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'juan', 'ownerB']) n;
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP', 'Asia/Manila'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP', 'UTC');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.t('A'), true, false), (pg_temp.t('B'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'MAIN', 'A'), (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'MAIN', 'B');
insert into public.location_access (user_id, location_id, tenant_id, position) values (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null);
insert into public.products (id, tenant_id, name) values
  (pg_temp.id('p:kape'), pg_temp.t('A'), 'Kape'), (pg_temp.id('p:asin'), pg_temp.t('A'), 'Asin'), (pg_temp.id('p:b'), pg_temp.t('B'), 'B item');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost) values
  (pg_temp.id('v:kape'), pg_temp.t('A'), pg_temp.id('p:kape'), 'KAPE', true, 400),
  (pg_temp.id('v:asin'), pg_temp.t('A'), pg_temp.id('p:asin'), 'ASIN', true, 400),
  (pg_temp.id('v:b'), pg_temp.t('B'), pg_temp.id('p:b'), 'B1', true, 400);

select pg_temp.login('owner', 'A');
set local role authenticated;

select pg_temp.push1('c1', 'upsert_customer', jsonb_build_object('id', pg_temp.id('cus'), 'name', 'Aling Rosa'));
-- day 2026-11-08 Manila (02:00Z = 10:00): cash 2 x 10.00 = 20.00 with 1.00 discount; e-wallet 1 x 50.00 (asin); utang 3 x 10.00
select pg_temp.sell('s1', 'kape', 2, 1000, jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 1900, 'tendered', 2000)), '2026-11-08T02:00:00Z', '{"discount": 100}');
select pg_temp.sell('s2', 'asin', 1, 5000, jsonb_build_array(jsonb_build_object('method', 'ewallet', 'amount', 5000)));
select pg_temp.sell('s3', 'kape', 3, 1000, jsonb_build_array(jsonb_build_object('method', 'utang', 'amount', 3000)), '2026-11-08T03:00:00Z', jsonb_build_object('customer_id', pg_temp.id('cus')));
-- 17:00Z on the 8th is 01:00 on the 9th in Manila: it belongs to the 9th
select pg_temp.sell('s4', 'kape', 1, 1000, jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 1000)), '2026-11-08T17:00:00Z');
reset role;

-- the rollups are written when the transaction ends; make that happen now
set constraints all immediate;
set local role authenticated;

select is((select net from public.daily_sales_summary where day = '2026-11-08'), 9900::bigint, 'net of the 8th = 19.00 + 50.00 + 30.00');
select is((select gross from public.daily_sales_summary where day = '2026-11-08'), 10000::bigint, 'gross is before the discount');
select is((select discount from public.daily_sales_summary where day = '2026-11-08'), 100::bigint, 'discount');
select is((select txn_count from public.daily_sales_summary where day = '2026-11-08'), 3, 'three sales on the 8th');
select is((select (cash, ewallet, utang) from public.daily_sales_summary where day = '2026-11-08')::text, '(1900,5000,3000)', 'split by how it was paid');
select is((select cogs from public.daily_sales_summary where day = '2026-11-08'), 2400::bigint, 'cost of goods: 6 items x 4.00');
select is((select net from public.daily_sales_summary where day = '2026-11-09'), 1000::bigint, 'a sale at 01:00 Manila time falls on the 9th (tenant timezone)');
select is((select sum(qty) from public.daily_item_sales where variant_id = pg_temp.id('v:kape') and day = '2026-11-08'), 5::numeric, 'item rollup: 5 Kape on the 8th');
select is((select revenue from public.daily_item_sales where variant_id = pg_temp.id('v:asin')), 5000::bigint, 'item revenue');

-- rollups equal raw sales
select is((select sum(net) from public.daily_sales_summary), (select sum(total) from public.sales where status = 'completed'),
          'the rollup total equals the sum of the raw sales');

-- cancelling takes the sale out
select pg_temp.login('owner', 'A');
select pg_temp.push1('v1', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:s3')));
reset role;
set constraints all immediate;
set local role authenticated;
select is((select net from public.daily_sales_summary where day = '2026-11-08'), 6900::bigint, 'cancelling the utang sale lowers the day by 30.00');
select is((select txn_count from public.daily_sales_summary where day = '2026-11-08'), 2, 'and the count by one');
select is((select utang from public.daily_sales_summary where day = '2026-11-08'), 0::bigint, 'and the utang given');
select is((select qty from public.daily_item_sales where variant_id = pg_temp.id('v:kape') and day = '2026-11-08'), 2::numeric, 'item quantity is reduced');
select is((select sum(net) from public.daily_sales_summary), (select sum(total) from public.sales where status = 'completed'),
          'still equal to the raw completed sales');

-- the report
create temp table rep as select public.report_summary('2026-11-08', '2026-11-09') as r;
grant select on rep to authenticated;
select is((select r -> 'totals' ->> 'net' from rep), '7900', 'report total net over both days');
select is((select jsonb_array_length(r -> 'days') from rep), 2, 'report has a row per day');
select is((select r -> 'top_items' -> 0 ->> 'name' from rep), 'Asin', 'top item is the one with most revenue');
select is((select r -> 'utang' ->> 'owed' from rep), '0', 'utang owed is 0 after the cancel');
select is((select (public.report_summary('2026-11-10', '2026-11-12') -> 'totals' ->> 'net')), '0', 'an empty range reports zeros');
select throws_ok($$ select public.report_summary('2026-11-12', '2026-11-10') $$, '22023', null, 'a backwards range is refused');

-- access
select pg_temp.login('juan', 'A');
select is((select count(*)::int from public.daily_sales_summary), 0, 'a cashier reads no rollups');
select is((public.report_summary('2026-11-08', '2026-11-09') -> 'totals' ->> 'net'), '0', 'and the report is empty for a cashier');
select pg_temp.login('ownerB', 'B');
select is((select count(*)::int from public.daily_sales_summary), 0, 'another tenant reads none of ours');
select throws_ok($$ insert into public.daily_sales_summary (tenant_id, location_id, day) values (md5('t:A')::uuid, md5('id:S01')::uuid, '2026-01-01') $$,
                 '42501', null, 'clients cannot write rollups');

reset role;
select * from finish();
rollback;
