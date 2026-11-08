-- F-01 Store scoping: customer_ledger.location_id / method, ops that write ledger rows, the per-store day close figure,
-- the ledger and sales pulls, record_sale without a store, and the backfill rule. Tenant A has TWO stores (S01, S02);
-- juan (cashier) and maria (manager) work at S01 only; tenant B has one store.
begin;
select plan(52);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('id:' || p)::uuid $$;
create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;
create function pg_temp.push1(k text, kind text, payload jsonb) returns jsonb language sql as $$
  select public.sync_push(jsonb_build_array(
    jsonb_build_object('op_id', pg_temp.id('op:' || k), 'kind', kind, 'payload', payload))) -> 0
$$;
-- a sale of one kape at [price], paid [cash] in cash and the rest on utang to [cus]; [loc] null = no location_id sent
create function pg_temp.sale(k text, loc text, price bigint, cash bigint, cus text default 'cus', variant text default 'kape')
returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_sale', jsonb_strip_nulls(jsonb_build_object(
    'id', pg_temp.id('sale:' || k), 'local_no', 'R-' || k, 'sold_at', '2026-11-05T02:00:00Z',
    'location_id', case when loc is null then null else pg_temp.id(loc) end,
    'customer_id', case when price > cash then pg_temp.id(cus) end,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:' || variant), 'qty', 1, 'unit_price', price)),
    'payments', (select jsonb_agg(x) from (
                   select jsonb_build_object('method', 'cash', 'amount', cash) x where cash > 0
                   union all
                   select jsonb_build_object('method', 'utang', 'amount', price - cash) where price > cash) y))))
$$;
-- an utang payment of [amount]; [loc] / [method] null = not sent
create function pg_temp.pay(k text, loc text, amount bigint, method text default null, cus text default 'cus')
returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_utang_payment', jsonb_strip_nulls(jsonb_build_object(
    'customer_id', pg_temp.id(cus), 'amount', amount, 'occurred_at', '2026-11-05T03:00:00Z',
    'location_id', case when loc is null then null else pg_temp.id(loc) end, 'method', method)))
$$;
create function pg_temp.ledger(k text) returns text language sql as $$
  select (l.kind, l.amount, coalesce((select x.code from public.locations x where x.id = l.location_id), '-'), l.method)::text
  from public.customer_ledger l where l.created_by is not null and l.id = (
    select id from public.customer_ledger where note = k order by created_at desc limit 1)
$$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'juan', 'ownerB']) n;
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP', 'Asia/Manila'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP', 'UTC'),
  (pg_temp.t('C'), 'C', 'tenant-c', 'PHP', 'UTC');
insert into public.tenant_modules (tenant_id, pos, warehouse) values
  (pg_temp.t('A'), true, false), (pg_temp.t('B'), true, false), (pg_temp.t('C'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B')), (pg_temp.t('C'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'A1'),
  (pg_temp.id('S02'), pg_temp.t('A'), 'store', 'S02', 'A2'),
  (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'S01', 'B1');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null);
insert into public.customers (id, tenant_id, name) values
  (pg_temp.id('cus'), pg_temp.t('A'), 'Rosa'), (pg_temp.id('cusB'), pg_temp.t('B'), 'Ben'),
  (pg_temp.id('cusC'), pg_temp.t('C'), 'Cora');
insert into public.products (id, tenant_id, name, track_stock) values
  (pg_temp.id('p:kape'), pg_temp.t('A'), 'Kape', true), (pg_temp.id('p:b'), pg_temp.t('B'), 'B item', true);
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost) values
  (pg_temp.id('v:kape'), pg_temp.t('A'), pg_temp.id('p:kape'), 'KAPE', true, 100),
  (pg_temp.id('v:b'), pg_temp.t('B'), pg_temp.id('p:b'), 'B1', true, 100);

-- ===== schema =====
select has_column('public', 'customer_ledger', 'location_id', 'the ledger has a store');
select col_is_null('public', 'customer_ledger', 'location_id', 'the store may be empty (adjustments without a store)');
select col_default_is('public', 'customer_ledger', 'method', 'cash', 'the payment method defaults to cash');
select col_not_null('public', 'customer_ledger', 'method', 'the payment method is never empty');
select throws_ok(format($$ insert into public.customer_ledger (tenant_id, customer_id, kind, amount, method)
                          values (%L, %L, 'charge', 10, 'ewallet') $$, pg_temp.t('A'), pg_temp.id('cus')),
                 '23514', null, 'only a payment can be an e-wallet entry');
select throws_ok(format($$ insert into public.customer_ledger (tenant_id, customer_id, kind, amount, location_id)
                          values (%L, %L, 'payment', -10, %L) $$, pg_temp.t('A'), pg_temp.id('cus'), pg_temp.id('SB')),
                 '23503', null, 'the store must belong to the same tenant');

-- ===== sales at each store (owner sees both) =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.sale('a1', 'S01', 5000, 3000) ->> 'status', 'ok', 'a split cash + utang sale at S01');
select is(pg_temp.sale('a2', 'S02', 4000, 1000) ->> 'status', 'ok', 'a split cash + utang sale at S02');
select is(pg_temp.sale('a3', null, 1000, 1000) ->> 'hint', 'location_required',
          'with two stores, a sale must name its store (B3: stable hint, nothing written)');
reset role;
select is((select array_agg((s.local_no, x.code, l.amount)::text order by s.local_no)
           from public.customer_ledger l join public.sales s on s.id = l.sale_id join public.locations x on x.id = l.location_id
           where l.kind = 'charge' and s.tenant_id = pg_temp.t('A')),
          array['(R-a1,S01,2000)', '(R-a2,S02,3000)'], 'each utang charge carries its sale''s store');
select is((select count(*)::int from public.sales where local_no = 'R-a3'), 0, 'the refused sale left nothing');

-- ===== one-store users: the store is defaulted =====
select pg_temp.login('juan', 'A');
set local role authenticated;
select is(pg_temp.sale('j1', null, 1000, 1000) ->> 'status', 'ok', 'a cashier with one store sells without naming it');
select is(pg_temp.sale('j2', 'S02', 1000, 1000) ->> 'hint', 'location_denied', 'but not at a store that is not his');
reset role;
select is((select x.code from public.sales s join public.locations x on x.id = s.location_id where s.local_no = 'R-j1'), 'S01',
          'the defaulted sale is at his store');
select pg_temp.login('ownerB', 'B');
set local role authenticated;
select is(pg_temp.sale('b1', null, 900, 0, 'cusB', 'b') ->> 'status', 'ok', 'a solo owner sells on utang without a store id');
select is(pg_temp.pay('bp1', null, 400, cus => 'cusB') ->> 'status', 'ok', 'and records a payment without one');
reset role;
select is((select array_agg((l.kind, l.location_id = pg_temp.id('SB'), l.method)::text order by l.kind)
           from public.customer_ledger l where l.tenant_id = pg_temp.t('B')),
          array['(charge,t,cash)', '(payment,t,cash)'], 'both rows are at the solo store, as cash');

-- ===== utang payments at each store =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.pay('p1', 'S01', 1500) ->> 'status', 'ok', 'a cash payment at S01 (method left out = cash)');
select is(pg_temp.pay('p2', 'S02', 700, 'ewallet') ->> 'status', 'ok', 'an e-wallet payment at S02');
select is(pg_temp.pay('p3', 'S02', 300, 'cash') ->> 'status', 'ok', 'a cash payment at S02');
select is(pg_temp.pay('p4', null, 100) ->> 'hint', 'location_required', 'with two stores a payment must name its store');
select is(pg_temp.pay('p5', 'S01', 100, 'card') ->> 'hint', 'invalid_value', 'an unknown method is refused');
select is(pg_temp.pay('p6', 'S01', 100, 'utang') ->> 'hint', 'invalid_value', 'utang is not a way to pay utang');
select is(pg_temp.pay('p7', 'SB', 100) ->> 'hint', 'location_denied', 'another tenant''s store is refused');
select is(pg_temp.pay('p1', 'S01', 1500) -> 'result' ->> 'replay', 'true', 'a resent payment is a replay');
select pg_temp.login('juan', 'A');
select is(pg_temp.pay('p8', null, 200) ->> 'status', 'ok', 'a cashier with one store pays in without naming it');
select is(pg_temp.pay('p9', 'S02', 200) ->> 'hint', 'location_denied', 'no payment at a store he has no access to');
reset role;
select is((select array_agg((x.code, -l.amount, l.method)::text order by l.created_at, l.id)
           from public.customer_ledger l join public.locations x on x.id = l.location_id
           where l.kind = 'payment' and l.tenant_id = pg_temp.t('A')),
          array['(S01,1500,cash)', '(S02,700,ewallet)', '(S02,300,cash)', '(S01,200,cash)'],
          'each payment carries its store and method; refused ones left nothing, the replay added nothing');
select is((select (meta, location_id is null)::text from public.audit_log
           where action = 'utang.payment' and user_id = pg_temp.u('juan')),
          '("{""amount"": 200}",t)', 'the audit row is unchanged ({ amount }, no store)');

-- ===== the per-store server figure (Manila day 2026-11-05) =====
-- S01: cash sales 3000 (a1) + 1000 (j1) + cash utang payments taken at S01 1500 + 200 = 5700
select is(public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S01'), '2026-11-05'), 5700::bigint,
          'S01 counts its own cash sales and the cash utang payments taken at S01');
-- S02: cash sale 1000 (a2) + cash payment 300; the 700 e-wallet payment is not cash; S01's payments are not S02's
select is(public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S02'), '2026-11-05'), 1300::bigint,
          'S02 counts only its cash utang payments, not e-wallet ones and not S01''s');
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.push1('c2', 'close_day', jsonb_build_object('id', pg_temp.id('dc:c2'), 'location_id', pg_temp.id('S02'),
            'day', '2026-11-05', 'expected_cash', 1300, 'counted_cash', 1300)) -> 'result' ->> 'server_expected_cash', '1300',
          'a close at S02 stores the S02 figure');

-- ===== adjustments and the void =====
select is(pg_temp.push1('ad1', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('cus'), 'amount', -100,
            'note', 'ad1', 'location_id', pg_temp.id('S02'))) ->> 'status', 'ok', 'an adjustment at S02');
select is(pg_temp.push1('ad2', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('cus'), 'amount', 50,
            'note', 'ad2')) ->> 'status', 'ok', 'an adjustment without a store is not refused (it is not cash)');
select is(pg_temp.push1('v1', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:a2'))) ->> 'status', 'ok',
          'the S02 utang sale is cancelled');
select pg_temp.login('maria', 'A');
select is(pg_temp.push1('ad3', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('cus'), 'amount', -10,
            'note', 'ad3')) ->> 'status', 'ok', 'a manager with one store adjusts without naming it');
select is(pg_temp.push1('ad4', 'adjust_utang', jsonb_build_object('customer_id', pg_temp.id('cus'), 'amount', -10,
            'note', 'ad4', 'location_id', pg_temp.id('S02'))) ->> 'hint', 'location_denied',
          'but not at a store that is not hers');
reset role;
select is(pg_temp.ledger('ad1'), '(adjust,-100,S02,cash)', 'the named store is kept');
select is(pg_temp.ledger('ad2'), '(adjust,50,-,cash)', 'two stores and none named: no store');
select is(pg_temp.ledger('ad3'), '(adjust,-10,S01,cash)', 'one store: defaulted');
select is((select (l.amount, x.code)::text from public.customer_ledger l join public.locations x on x.id = l.location_id
           where l.sale_id = pg_temp.id('sale:a2') and l.kind = 'adjust'),
          '(-3000,S02)', 'the reversal of a cancelled sale''s utang is at the sale''s store');
select is(public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S02'), '2026-11-05'), 300::bigint,
          'the cancelled sale''s cash leaves S02''s figure; its cash utang payment stays');

-- ===== pulls =====
set local session_replication_role = replica;
update public.customer_ledger set created_at = now() - interval '1 minute';
update public.sales set updated_at = now() - interval '1 minute';
set local session_replication_role = origin;
select pg_temp.login('owner', 'A');
set local role authenticated;
select is((select (count(*), count(*) filter (where r ? 'location_id' and r ? 'method'))::text
           from jsonb_array_elements(public.sync_pull_pos('{}', 100) -> 'customer_ledger' -> 'rows') r),
          '(10,10)', 'every pulled ledger row carries location_id and method');
select is((select (r ->> 'location_id' = pg_temp.id('S02')::text, r ->> 'method')::text
           from jsonb_array_elements(public.sync_pull_pos('{}', 100) -> 'customer_ledger' -> 'rows') r
           where (r ->> 'amount')::int = -700),
          '(t,ewallet)', 'the e-wallet payment comes with its store and method');
select is((select array_agg((r ->> 'local_no', r ->> 'location_id' = pg_temp.id('S01')::text)::text order by r ->> 'local_no')
           from jsonb_array_elements(public.sync_pull_sales() -> 'rows') r),
          array['(R-a1,t)', '(R-a2,f)', '(R-j1,t)'], 'pulled sales carry their store');
select pg_temp.login('juan', 'A');
select is((select array_agg(r ->> 'local_no' order by r ->> 'local_no')
           from jsonb_array_elements(public.sync_pull_sales() -> 'rows') r),
          array['R-a1', 'R-j1'], 'a one-store cashier pulls only his store''s sales');
select is((select count(*)::int from jsonb_array_elements(public.sync_pull_pos('{}', 100) -> 'customer_ledger' -> 'rows') r),
          10, 'the utang ledger stays tenant-wide (a customer''s balance is the same at every store)');
reset role;

-- ===== the backfill rule (the function the migration ran) =====
insert into public.customer_ledger (id, tenant_id, customer_id, kind, amount, sale_id, location_id) values
  (pg_temp.id('bf1'), pg_temp.t('A'), pg_temp.id('cus'), 'charge', 10, pg_temp.id('sale:a2'), null),
  (pg_temp.id('bf2'), pg_temp.t('A'), pg_temp.id('cus'), 'payment', -10, null, null),
  (pg_temp.id('bf3'), pg_temp.t('B'), pg_temp.id('cusB'), 'payment', -10, null, null),
  (pg_temp.id('bf4'), pg_temp.t('C'), pg_temp.id('cusC'), 'payment', -10, null, null);
alter table public.customer_ledger disable trigger customer_ledger_append_only;
select is(public.customer_ledger_location_backfill(), 4,
          'the backfill fills every row it can (bf1..bf3 and the earlier store-less adjustment ad2)');
alter table public.customer_ledger enable trigger customer_ledger_append_only;
select is((select array_agg((x.k, coalesce(loc.code || '@' || loc.tenant_id::text, '-'), l.method)::text order by x.k)
           from (values ('bf1'), ('bf2'), ('bf3'), ('bf4')) x(k)
           join public.customer_ledger l on l.id = pg_temp.id(x.k)
           left join public.locations loc on loc.id = l.location_id),
          array['(bf1,S02@' || pg_temp.t('A') || ',cash)', '(bf2,S01@' || pg_temp.t('A') || ',cash)',
                '(bf3,S01@' || pg_temp.t('B') || ',cash)', '(bf4,-,cash)'],
          'a row tied to a sale gets the sale''s store; others the first (or only) store; a tenant with no store: none');
select is(pg_temp.ledger('ad2'), '(adjust,50,S01,cash)', 'a row with no sale in a two-store tenant goes to its first store');
select throws_ok(format($$ update public.customer_ledger set location_id = %L where id = %L $$,
                        pg_temp.id('S01'), pg_temp.id('bf1')),
                 '55000', null, 'with the guard back on, ledger rows cannot be changed');

set local role authenticated;
select throws_ok($$ select public.customer_ledger_location_backfill() $$, '42501', null, 'clients cannot run the backfill');
reset role;

select * from finish();
rollback;
