-- 036_warehouse_receiving.test.sql: F-13b. Goods can be received into a warehouse (not only a store), through sync_push.
begin;
select plan(30);

-- ---------------------------------------------------------------------------
-- Fixtures: two warehouses (W1, W2), a store, one user of each kind
-- ---------------------------------------------------------------------------
create function pg_temp.tid() returns uuid language sql immutable as $$ select md5('tenant:RW')::uuid $$;
create function pg_temp.uid(p_user text) returns uuid language sql immutable as $$ select md5('user:RW:' || p_user)::uuid $$;
create function pg_temp.lid(p_code text) returns uuid language sql immutable as $$ select md5('loc:RW:' || p_code)::uuid $$;
create function pg_temp.vid(p text) returns uuid language sql immutable as $$ select md5('var:RW:' || p)::uuid $$;
create function pg_temp.oid(p text) returns uuid language sql immutable as $$ select md5('op:RW:' || p)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values (pg_temp.tid(), 'Receiving WH', 'receiving-wh', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid(), true, true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid());

insert into auth.users (id, email) select pg_temp.uid(n), n || '@rw.invalid'
  from unnest(array['owner', 'wh1', 'wh2', 'maria', 'juan']) n;
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('owner'), pg_temp.tid(), 'owner', 'superadmin', true),
  (pg_temp.uid('wh1'),   pg_temp.tid(), 'wh1',   'warehouse',  true),
  (pg_temp.uid('wh2'),   pg_temp.tid(), 'wh2',   'warehouse',  true),
  (pg_temp.uid('maria'), pg_temp.tid(), 'maria', 'admin',      true),
  (pg_temp.uid('juan'),  pg_temp.tid(), 'juan',  'cashier',    true);

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.lid('W1'), pg_temp.tid(), 'warehouse', 'W1', 'Warehouse One'),
  (pg_temp.lid('W2'), pg_temp.tid(), 'warehouse', 'W2', 'Warehouse Two'),
  (pg_temp.lid('S1'), pg_temp.tid(), 'store',     'S1', 'Store One');

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('wh1'),   pg_temp.lid('W1'), pg_temp.tid(), null),
  (pg_temp.uid('wh2'),   pg_temp.lid('W2'), pg_temp.tid(), null),
  (pg_temp.uid('maria'), pg_temp.lid('S1'), pg_temp.tid(), 'manager'),
  (pg_temp.uid('juan'),  pg_temp.lid('S1'), pg_temp.tid(), null);

insert into public.products (id, tenant_id, name) values (md5('p:RW:1')::uuid, pg_temp.tid(), 'Rice 25kg');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default)
  values (pg_temp.vid('rice'), pg_temp.tid(), md5('p:RW:1')::uuid, 'RICE25', true);

-- W2 already holds 50 sacks at 1000 centavos
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost)
  values (pg_temp.tid(), pg_temp.lid('W2'), pg_temp.vid('rice'), 50, 'receipt', 1000);

create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.uid(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.tid())::text, true);
$$;

-- One op through sync_push, as the signed-in user; returns that op's result entry.
create function pg_temp.push(p_op text, p_payload jsonb) returns jsonb language sql as $$
  select (public.sync_push(jsonb_build_array(jsonb_build_object(
    'op_id', pg_temp.oid(p_op), 'kind', 'receive_warehouse_stock', 'payload', p_payload))) -> 0)
$$;

create function pg_temp.pay(p_loc text, p_qty numeric, p_cost bigint default null) returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'location_id', pg_temp.lid(p_loc), 'variant_id', pg_temp.vid('rice'), 'qty', p_qty, 'unit_cost', p_cost))
$$;

-- ---------------------------------------------------------------------------
-- 1. Happy path: wh2 receives 30 @ 1200 into W2 (50 @ 1000 on hand)
-- ---------------------------------------------------------------------------
select pg_temp.login('wh2');
set local role authenticated;
create temp table r1 as select pg_temp.push('a', pg_temp.pay('W2', 30, 1200)) as res;
grant all on r1 to authenticated;
select is((select res ->> 'status' from r1), 'ok', 'wh2 receives goods into W2');
reset role;

select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W2')), 80::numeric,
  'W2 stock is 80');
select is((select avg_cost from public.stock_levels where location_id = pg_temp.lid('W2')), 1075::bigint,
  'average cost blends to (50*1000 + 30*1200) / 80 = 1075');
select is((select count(*)::int from public.stock_movements
           where location_id = pg_temp.lid('W2') and type = 'receipt' and ref_id = pg_temp.oid('a')
             and ref_type = 'receipt' and created_by = pg_temp.uid('wh2') and unit_cost = 1200),
  1, 'one receipt movement carries the op id, the user and the cost');
select is((select count(*)::int from public.audit_log
           where action = 'stock.receive' and location_id = pg_temp.lid('W2') and entity_id = pg_temp.vid('rice')),
  1, 'the receipt is audited against W2');

-- ---------------------------------------------------------------------------
-- 2. Idempotent: the same op again changes nothing
-- ---------------------------------------------------------------------------
select pg_temp.login('wh2');
set local role authenticated;
select is((pg_temp.push('a', pg_temp.pay('W2', 30, 1200))) -> 'result' ->> 'replay', 'true', 'a repeated op id is a replay');
reset role;
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W2')), 80::numeric,
  'the replay did not add stock again');
select is((select count(*)::int from public.stock_movements where ref_id = pg_temp.oid('a')), 1,
  'still one movement for that op');

-- ---------------------------------------------------------------------------
-- 3. Who may receive
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is((pg_temp.push('b', pg_temp.pay('W2', 5, 1000))) ->> 'hint', 'location_denied',
  'a user of W1 cannot receive into W2');
reset role;

select pg_temp.login('maria');
set local role authenticated;
select is((pg_temp.push('c', pg_temp.pay('W2', 5, 1000))) ->> 'status', 'rejected', 'a store admin cannot receive into a warehouse');
reset role;

select pg_temp.login('juan');
set local role authenticated;
select is((pg_temp.push('d', pg_temp.pay('W2', 5, 1000))) ->> 'status', 'rejected', 'a cashier cannot receive into a warehouse');
reset role;

select pg_temp.login('owner');
set local role authenticated;
select is((pg_temp.push('e', pg_temp.pay('W1', 10, 900))) ->> 'status', 'ok', 'the owner can receive into any warehouse');
reset role;
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1')), 10::numeric,
  'W1 holds the 10 the owner received');
select is((select avg_cost from public.stock_levels where location_id = pg_temp.lid('W1')), 900::bigint,
  'first receipt sets the cost');

select is((select count(*)::int from public.stock_movements where ref_id in (pg_temp.oid('b'), pg_temp.oid('c'), pg_temp.oid('d'))),
  0, 'refused receipts wrote no movement');

-- ---------------------------------------------------------------------------
-- 4. Validation
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;
select is((pg_temp.push('f', pg_temp.pay('S1', 5, 1000))) ->> 'hint', 'not_a_warehouse', 'a store is not a warehouse');
select is((pg_temp.push('g', pg_temp.pay('W1', 0, 1000))) ->> 'hint', 'qty_invalid', 'zero quantity is refused');
select is((pg_temp.push('h', pg_temp.pay('W1', -3, 1000))) ->> 'hint', 'qty_invalid', 'negative quantity is refused');
select is((pg_temp.push('i', pg_temp.pay('W1', 1000000000, 1000))) ->> 'hint', 'qty_invalid', 'absurd quantity is refused');
select is((pg_temp.push('j', pg_temp.pay('W1', 5, -1))) ->> 'hint', 'invalid_value', 'negative cost is refused');
select is((pg_temp.push('k', jsonb_build_object('location_id', pg_temp.lid('W1'), 'variant_id', md5('nope')::uuid, 'qty', 5))) ->> 'hint',
  'unknown_variant', 'an unknown product is refused');
select is((pg_temp.push('l', jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 5))) ->> 'hint',
  'location_required', 'a warehouse must be named (there is no default)');
select is((pg_temp.push('m', pg_temp.pay('W1', 2.5))) ->> 'status', 'ok', 'a fractional quantity without a cost is accepted');
reset role;
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1')), 12.5::numeric,
  'W1 is now 12.5');
select is((select avg_cost from public.stock_levels where location_id = pg_temp.lid('W1')), 900::bigint,
  'a receipt without a cost keeps the average cost');

-- ---------------------------------------------------------------------------
-- 5. With bins on, goods land in RECEIVING and the invariant holds
-- ---------------------------------------------------------------------------
select pg_temp.login('wh2');
set local role authenticated;
select lives_ok($$ select public.enable_warehouse_bins(pg_temp.lid('W2')) $$, 'wh2 enables bins in W2');
select is((pg_temp.push('n', pg_temp.pay('W2', 20, 1000))) ->> 'status', 'ok', 'wh2 receives into the bin-enabled W2');
reset role;
select is((select bsl.qty_on_hand from public.bin_stock_levels bsl join public.bins b on b.id = bsl.bin_id
           where b.warehouse_id = pg_temp.lid('W2') and b.code = 'RECEIVING'), 100::numeric,
  'all 100 sacks sit in the RECEIVING bin');
select is((select count(*)::int from public.check_bin_stock_invariant(pg_temp.lid('W2')) where not is_valid), 0,
  'W2 bins add up to W2 stock');

-- ---------------------------------------------------------------------------
-- 6. The warehouse module must be on
-- ---------------------------------------------------------------------------
update public.tenant_modules set warehouse = false where tenant_id = pg_temp.tid();
select pg_temp.login('owner');
set local role authenticated;
select is((pg_temp.push('o', pg_temp.pay('W1', 1, 1000))) ->> 'status', 'rejected', 'receiving is refused when the warehouse module is off');
reset role;

select * from finish();
rollback;
