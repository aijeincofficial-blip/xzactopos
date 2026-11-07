-- P4-01 stock in, counts, weighted average cost, and the "levels equal the sum of movements" property
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
create function pg_temp.recv(k text, v text, qty numeric, cost bigint default null) returns jsonb language sql as $$
  select pg_temp.push1(k, 'receive_stock', jsonb_strip_nulls(jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'qty', qty, 'unit_cost', cost)))
$$;
create function pg_temp.count(k text, v text, counted numeric, reason text default 'counted') returns jsonb language sql as $$
  select pg_temp.push1(k, 'adjust_stock', jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'counted', counted, 'reason', reason))
$$;
create function pg_temp.sell(k text, v text, qty numeric) returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:' || k), 'local_no', 'R-' || k, 'sold_at', '2026-11-08T02:00:00Z',
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'qty', qty, 'unit_price', 1000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', round(qty * 1000)::bigint))))
$$;
create function pg_temp.lvl(v text) returns numeric language sql as $$
  select qty_on_hand from public.stock_levels where variant_id = pg_temp.id('v:' || v)
$$;
create function pg_temp.avg(v text) returns bigint language sql as $$
  select avg_cost from public.stock_levels where variant_id = pg_temp.id('v:' || v)
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
insert into public.location_access (user_id, location_id, tenant_id, position)
  values (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null);
insert into public.products (id, tenant_id, name, track_stock) values
  (pg_temp.id('p:kape'), pg_temp.t('A'), 'Kape', true),
  (pg_temp.id('p:asin'), pg_temp.t('A'), 'Asin', false),
  (pg_temp.id('p:new'), pg_temp.t('A'), 'Bago', true),
  (pg_temp.id('p:b'), pg_temp.t('B'), 'B item', true);
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost) values
  (pg_temp.id('v:kape'), pg_temp.t('A'), pg_temp.id('p:kape'), 'KAPE', true, 900),
  (pg_temp.id('v:asin'), pg_temp.t('A'), pg_temp.id('p:asin'), 'ASIN', true, 100),
  (pg_temp.id('v:new'), pg_temp.t('A'), pg_temp.id('p:new'), 'NEW', true, 100),
  (pg_temp.id('v:b'), pg_temp.t('B'), pg_temp.id('p:b'), 'B1', true, 100);

select pg_temp.login('owner', 'A');
set local role authenticated;

-- receipts and weighted average cost
select is(pg_temp.recv('r1', 'kape', 10, 100) ->> 'status', 'ok', 'stock in is accepted');
select is(pg_temp.lvl('kape'), 10::numeric, 'stock in raises the level');
select is(pg_temp.avg('kape'), 100::bigint, 'the first cost becomes the average');
select is((select type from public.stock_movements where ref_id = pg_temp.id('op:r1')), 'receipt', 'it is a receipt movement');
select pg_temp.recv('r2', 'kape', 10, 200);
select is(pg_temp.avg('kape'), 150::bigint, '10 at 1.00 and 10 at 2.00 average 1.50');
select pg_temp.recv('r3', 'kape', 5);
select is(pg_temp.lvl('kape'), 25::numeric, 'stock in without a cost still adds');
select is(pg_temp.avg('kape'), 150::bigint, 'and leaves the average alone');
select is(pg_temp.recv('r1', 'kape', 10, 100) -> 'result' ->> 'replay', 'true', 'a replayed stock in is recognised');
select is(pg_temp.lvl('kape'), 25::numeric, 'and adds nothing');

-- counts
select is((pg_temp.count('c1', 'kape', 20) -> 'result' ->> 'delta')::numeric, -5::numeric, 'a count of 20 against 25 is a -5 correction');
select is(pg_temp.lvl('kape'), 20::numeric, 'the level follows the count');
select is((select type from public.stock_movements where ref_id = pg_temp.id('op:c1')), 'count_correction', 'recorded as a count correction');
select pg_temp.count('c2', 'kape', 20);
select is((select count(*)::int from public.stock_movements where ref_id = pg_temp.id('op:c2')), 0, 'counting the same number writes nothing');
select pg_temp.count('c3', 'kape', 18, 'damage');
select is((select type from public.stock_movements where ref_id = pg_temp.id('op:c3')), 'damage', 'a lower count with reason damage is a damage movement');
select pg_temp.sell('s1', 'kape', 2); -- 16 left
select is((pg_temp.count('c4', 'kape', 10) -> 'result' ->> 'delta')::numeric, -6::numeric, 'the correction is computed from the level at the time, after a sale in between');
select is((pg_temp.count('c5', 'new', 5) -> 'result' ->> 'delta')::numeric, 5::numeric, 'a first count of a never-counted product starts it');
select is(pg_temp.avg('kape'), 150::bigint, 'sales and counts never move the average cost');

-- refusals
select is(pg_temp.recv('x1', 'kape', 0) ->> 'hint', 'qty_invalid', 'a zero stock in is refused');
select is(pg_temp.count('x2', 'kape', -1) ->> 'hint', 'qty_invalid', 'a negative count is refused');
select is(pg_temp.count('x3', 'kape', 3, 'stolen') ->> 'hint', 'invalid_value', 'an unknown reason is refused');
select is(pg_temp.recv('x4', 'kape', 1) ->> 'status', 'ok', 'a good stock in right after refusals still works');

-- property: after a few hundred random sales, voids, stock-ins and counts every level equals its movements
do $$
declare
  i int;
  r double precision;
  q numeric;
  sold text[] := '{}';
  pick text;
begin
  perform setseed(0.42);
  for i in 1..300 loop
    r := random();
    q := 1 + floor(random() * 5);
    if r < 0.45 then
      perform pg_temp.sell('p' || i, 'kape', q);
      sold := sold || ('p' || i);
    elsif r < 0.6 and array_length(sold, 1) > 0 then
      pick := sold[1 + floor(random() * array_length(sold, 1))::int];
      perform pg_temp.push1('pv' || i, 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:' || pick)));
    elsif r < 0.8 then
      perform pg_temp.recv('pr' || i, 'kape', q, (50 + floor(random() * 200))::bigint);
    else
      perform pg_temp.count('pc' || i, 'kape', floor(random() * 40)::numeric);
    end if;
  end loop;
end;
$$;
select is((select count(*)::int from public.stock_levels l
           where l.qty_on_hand <> (select coalesce(sum(m.qty_delta), 0) from public.stock_movements m
                                   where m.location_id = l.location_id and m.variant_id = l.variant_id)),
          0, 'after 300 random operations every level equals the sum of its movements');

-- not allowed / other tenants
select pg_temp.login('juan', 'A');
select is(pg_temp.recv('j1', 'kape', 1) ->> 'hint', 'not_allowed', 'a cashier cannot stock in');
select is(pg_temp.count('j2', 'kape', 1) ->> 'hint', 'not_allowed', 'a cashier cannot count');
select pg_temp.login('ownerB', 'B');
select is(pg_temp.recv('b1', 'kape', 1) ->> 'hint', 'unknown_variant', 'another tenant cannot add stock to our product');

reset role;
select * from finish();
rollback;
