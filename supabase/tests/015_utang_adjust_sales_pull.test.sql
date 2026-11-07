-- Gaps B5 and A6: op_adjust_utang and sync_pull_sales
begin;
select plan(23);

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
create function pg_temp.sell(k text, v text, qty numeric, price bigint, pays jsonb, at timestamptz default now(), extra jsonb default '{}') returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:' || k), 'local_no', 'R-' || k, 'sold_at', at,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'qty', qty, 'unit_price', price)),
    'payments', pays) || extra)
$$;
create function pg_temp.bal() returns bigint language sql as $$
  select coalesce(sum(amount), 0)::bigint from public.customer_ledger where customer_id = pg_temp.id('cus')
$$;

insert into auth.users (id, email) select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'juan', 'ownerB']) n;
insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.t('A'), true, false), (pg_temp.t('B'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'MAIN', 'A'), (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'MAIN', 'B');
insert into public.location_access (user_id, location_id, tenant_id, position) values (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null);
insert into public.products (id, tenant_id, name, track_stock) values
  (pg_temp.id('p:kape'), pg_temp.t('A'), 'Kape', true), (pg_temp.id('p:asin'), pg_temp.t('A'), 'Asin', false), (pg_temp.id('p:b'), pg_temp.t('B'), 'B item', true);
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost) values
  (pg_temp.id('v:kape'), pg_temp.t('A'), pg_temp.id('p:kape'), 'KAPE', true, 400),
  (pg_temp.id('v:asin'), pg_temp.t('A'), pg_temp.id('p:asin'), 'ASIN', true, 400),
  (pg_temp.id('v:b'), pg_temp.t('B'), pg_temp.id('p:b'), 'B1', true, 400);

select pg_temp.login('owner', 'A');
set local role authenticated;

-- ===== utang adjust =====
select pg_temp.push1('c1', 'upsert_customer', jsonb_build_object('id', pg_temp.id('cus'), 'name', 'Aling Rosa'));
select pg_temp.sell('u1', 'kape', 2, 1000, jsonb_build_array(jsonb_build_object('method', 'utang', 'amount', 2000)), now(), jsonb_build_object('customer_id', pg_temp.id('cus')));
select is(pg_temp.bal(), 2000::bigint, 'she owes 20.00');
select is(pg_temp.push1('a1', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('cus'), 'amount', -500, 'note', 'bawas')) ->> 'status', 'ok', 'a write-off is accepted');
select is(pg_temp.bal(), 1500::bigint, 'the balance went down by 5.00');
select is((select kind from public.customer_ledger where note = 'bawas'), 'adjust', 'recorded as an adjustment');
select is(pg_temp.push1('a1', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('cus'), 'amount', -500)) -> 'result' ->> 'replay', 'true', 'a replay is recognised');
select is(pg_temp.bal(), 1500::bigint, 'and counts once');
select is(pg_temp.push1('a2', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('cus'), 'amount', 300)) ->> 'status', 'ok', 'a correction upwards is accepted');
select is(pg_temp.bal(), 1800::bigint, 'the balance went up by 3.00');
select is(pg_temp.push1('a3', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('cus'), 'amount', 0)) ->> 'hint', 'amount_invalid', 'a zero adjustment is refused');
select is(pg_temp.push1('a4', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('nobody'), 'amount', 5)) ->> 'hint', 'unknown_customer', 'an unknown customer is refused');
select pg_temp.login('juan', 'A');
select is(pg_temp.push1('a5', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('cus'), 'amount', -100)) ->> 'hint', 'not_allowed', 'a cashier cannot adjust a debt');
select pg_temp.login('ownerB', 'B');
select is(pg_temp.push1('a6', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('cus'), 'amount', -100)) ->> 'hint', 'unknown_customer', 'another tenant cannot touch it');

-- ===== sales pull =====
select pg_temp.login('owner', 'A');
select pg_temp.sell('r1', 'kape', 2, 1000, jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 2000, 'tendered', 5000)), now() - interval '2 days');
select pg_temp.sell('r2', 'asin', 1, 500, jsonb_build_array(jsonb_build_object('method', 'ewallet', 'amount', 500)), now() - interval '1 day');
select pg_temp.sell('old', 'kape', 1, 1000, jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 1000)), now() - interval '60 days');
reset role;
-- age the rows past the 5 s hold-back
set local session_replication_role = replica;
update public.sales set updated_at = now() - interval '1 minute';
set local session_replication_role = origin;
set local role authenticated;

create temp table pull1 as select public.sync_pull_sales(null, 100) as r;
grant select on pull1 to authenticated;
select is((select jsonb_array_length(r -> 'rows') from pull1), 3, 'the first pull returns the last 30 days (the 60-day-old sale is left out; u1 + r1 + r2)');
select is((select x ->> 'local_no' from pull1, jsonb_array_elements(r -> 'rows') x where x ->> 'local_no' = 'R-r1'), 'R-r1', 'a sale comes with its number');
select is((select jsonb_array_length(x -> 'items') from pull1, jsonb_array_elements(r -> 'rows') x where x ->> 'local_no' = 'R-r1'), 1, 'and its lines');
select is((select x -> 'payments' -> 0 ->> 'tendered' from pull1, jsonb_array_elements(r -> 'rows') x where x ->> 'local_no' = 'R-r1'), '5000', 'and its payments with the cash handed over');
select is((select (x -> 'items' -> 0 ->> 'tracked')::boolean from pull1, jsonb_array_elements(r -> 'rows') x where x ->> 'local_no' = 'R-r2'), false, 'lines say whether the product tracks stock');

create temp table pull_small as select public.sync_pull_sales(null, 2) as r;
grant select on pull_small to authenticated;
select is((select r ->> 'has_more' from pull_small), 'true', 'a small page says there is more');
select is(jsonb_array_length(public.sync_pull_sales((select r -> 'cursor' from pull_small), 2) -> 'rows'), 1, 'the next page continues after the cursor');

-- a cancel comes again
select pg_temp.push1('v1', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:r1')));
reset role;
set local session_replication_role = replica;
update public.sales set updated_at = now() - interval '30 seconds' where status = 'voided';
set local session_replication_role = origin;
set local role authenticated;
select is((select x ->> 'status' from jsonb_array_elements(public.sync_pull_sales((select r -> 'cursor' from pull1), 100) -> 'rows') x limit 1),
          'voided', 'a later cancel is delivered after the cursor');

select pg_temp.login('ownerB', 'B');
select is(jsonb_array_length(public.sync_pull_sales(null, 100) -> 'rows'), 0, 'another tenant gets none of our sales');
select pg_temp.login('juan', 'A');
select is(jsonb_array_length(public.sync_pull_sales(null, 100) -> 'rows') > 0, true, 'a cashier gets the sales of their store');
select throws_ok($$ select public.sync_pull_sales(null, 0) $$, '22023', null, 'a bad page size is refused');

reset role;
select * from finish();
rollback;
