-- 035_multi_warehouse.test.sql: F-13a. One tenant, TWO warehouses (W1, W2) and a store.
-- Proves that warehouse users only see and act in the warehouses they are assigned to, that a
-- warehouse-to-warehouse transfer keeps stock, cost and the bin invariant right, and that two
-- warehouses may reuse the same bin codes.
begin;
select plan(48);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
create function pg_temp.tid() returns uuid language sql immutable as $$ select md5('tenant:MW')::uuid $$;
create function pg_temp.uid(p_user text) returns uuid language sql immutable as $$ select md5('user:MW:' || p_user)::uuid $$;
create function pg_temp.lid(p_code text) returns uuid language sql immutable as $$ select md5('loc:MW:' || p_code)::uuid $$;
create function pg_temp.vid(p text) returns uuid language sql immutable as $$ select md5('var:MW:' || p)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values (pg_temp.tid(), 'Multi Warehouse', 'multi-wh', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid(), true, true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid());

insert into auth.users (id, email) select pg_temp.uid(n), n || '@mw.invalid'
  from unnest(array['owner', 'wh1', 'wh2', 'whboth', 'maria', 'juan']) n;
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('owner'),  pg_temp.tid(), 'owner',  'superadmin', true),
  (pg_temp.uid('wh1'),    pg_temp.tid(), 'wh1',    'warehouse',  true),
  (pg_temp.uid('wh2'),    pg_temp.tid(), 'wh2',    'warehouse',  true),
  (pg_temp.uid('whboth'), pg_temp.tid(), 'whboth', 'warehouse',  true),
  (pg_temp.uid('maria'),  pg_temp.tid(), 'maria',  'admin',      true),
  (pg_temp.uid('juan'),   pg_temp.tid(), 'juan',   'cashier',    true);

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.lid('W1'), pg_temp.tid(), 'warehouse', 'W1', 'Warehouse One'),
  (pg_temp.lid('W2'), pg_temp.tid(), 'warehouse', 'W2', 'Warehouse Two'),
  (pg_temp.lid('S1'), pg_temp.tid(), 'store',     'S1', 'Store One');

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('wh1'),    pg_temp.lid('W1'), pg_temp.tid(), null),
  (pg_temp.uid('wh2'),    pg_temp.lid('W2'), pg_temp.tid(), null),
  (pg_temp.uid('whboth'), pg_temp.lid('W1'), pg_temp.tid(), null),
  (pg_temp.uid('whboth'), pg_temp.lid('W2'), pg_temp.tid(), null),
  (pg_temp.uid('maria'),  pg_temp.lid('S1'), pg_temp.tid(), 'manager'),
  (pg_temp.uid('juan'),   pg_temp.lid('S1'), pg_temp.tid(), null);

insert into public.products (id, tenant_id, name) values (md5('p:MW:1')::uuid, pg_temp.tid(), 'Rice 25kg');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default)
  values (pg_temp.vid('rice'), pg_temp.tid(), md5('p:MW:1')::uuid, 'RICE25', true);

-- W1: 100 sacks @ 1000 centavos. W2: 50 sacks @ 1000.
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid(), pg_temp.lid('W1'), pg_temp.vid('rice'), 100, 'receipt', 1000),
  (pg_temp.tid(), pg_temp.lid('W2'), pg_temp.vid('rice'),  50, 'receipt', 1000);

create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.uid(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.tid())::text, true);
$$;

-- Each warehouse's own staff turn on bins for their warehouse (the existing stock moves into RECEIVING).
select pg_temp.login('wh1');
set local role authenticated;
select lives_ok($$ select public.enable_warehouse_bins(pg_temp.lid('W1')) $$, 'wh1 enables bins in W1');
select throws_ok($$ select public.enable_warehouse_bins(pg_temp.lid('W2')) $$, '42501', null,
  'wh1 cannot enable bins in W2');
reset role;

select pg_temp.login('wh2');
set local role authenticated;
select lives_ok($$ select public.enable_warehouse_bins(pg_temp.lid('W2')) $$, 'wh2 enables bins in W2');
reset role;

-- ---------------------------------------------------------------------------
-- 1. Reads: a warehouse user sees only their own warehouse
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;

select is((select count(*)::int from public.locations where type = 'warehouse'), 1, 'wh1 sees one warehouse');
select is((select array_agg(location_id) from public.stock_levels), array[pg_temp.lid('W1')],
  'wh1 sees stock levels of W1 only');
select is((select count(*)::int from public.stock_movements where location_id <> pg_temp.lid('W1')), 0,
  'wh1 sees no movements of W2');
select is((select count(distinct warehouse_id)::int from public.bins), 1, 'wh1 sees bins of one warehouse');
select is((select count(*)::int from public.bins where warehouse_id = pg_temp.lid('W2')), 0, 'wh1 sees no bins of W2');
select is((select count(*)::int from public.warehouse_zones where warehouse_id = pg_temp.lid('W2')), 0,
  'wh1 sees no zones of W2');
-- counted directly: a join to bins would be filtered by bins' own policy and hide a leak
select is((select count(*)::int from public.bin_stock_levels), 1, 'wh1 sees only the bin stock rows of W1 (1 bin, 1 variant)');
reset role;

select pg_temp.login('wh2');
set local role authenticated;
select is((select array_agg(location_id) from public.stock_levels), array[pg_temp.lid('W2')],
  'wh2 sees stock levels of W2 only');
select is((select count(*)::int from public.bin_stock_levels), 1, 'wh2 sees only the bin stock rows of W2 (1 bin, 1 variant)');
reset role;

select pg_temp.login('whboth');
set local role authenticated;
select is((select count(*)::int from public.locations where type = 'warehouse'), 2, 'whboth sees both warehouses');
select is((select count(*)::int from public.stock_levels), 2, 'whboth sees stock of both warehouses');
select is((select count(distinct warehouse_id)::int from public.bins), 2, 'whboth sees bins of both warehouses');
select is((select count(*)::int from public.bin_stock_levels), 2, 'whboth sees the bin stock rows of both warehouses');
reset role;

select pg_temp.login('juan');
set local role authenticated;
select is((select count(*)::int from public.stock_levels), 0, 'a cashier of the store sees no warehouse stock');
reset role;

-- ---------------------------------------------------------------------------
-- 2. Bin codes are per warehouse; the default bins exist in both
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from public.bins where upper(code) = 'RECEIVING' and tenant_id = pg_temp.tid()),
  2, 'both warehouses have their own RECEIVING bin (same code, different ids)');

select pg_temp.login('wh1');
set local role authenticated;
select lives_ok(
  $$ select public.upsert_warehouse_bin(pg_temp.lid('W1'), 'B-01') $$, 'wh1 adds bin B-01 in W1');
select throws_ok(
  $$ select public.upsert_warehouse_bin(pg_temp.lid('W2'), 'B-01') $$, '42501', null,
  'wh1 cannot add a bin in W2');
reset role;

select pg_temp.login('wh2');
set local role authenticated;
select lives_ok(
  $$ select public.upsert_warehouse_bin(pg_temp.lid('W2'), 'B-01') $$, 'wh2 adds the same bin code B-01 in W2');
reset role;

-- A bin of W2 can never be used by a W1 operation, even for someone allowed in both places.
select pg_temp.login('whboth');
set local role authenticated;
select throws_ok(
  format($$ select public.move_bin_stock(%L, %L, %L, %L, 1) $$,
    pg_temp.lid('W1'),
    (select id from public.bins where warehouse_id = pg_temp.lid('W1') and code = 'RECEIVING'),
    (select id from public.bins where warehouse_id = pg_temp.lid('W2') and code = 'B-01'),
    pg_temp.vid('rice')),
  '22023', null, 'moving stock from a W1 bin into a W2 bin is refused');
reset role;

-- ---------------------------------------------------------------------------
-- 2b. Pick lists belong to one warehouse
-- ---------------------------------------------------------------------------
select pg_temp.login('wh2');
set local role authenticated;
select lives_ok(
  format($$ select public.create_transfer(%L, %L, 'W2 to store', %L::jsonb) $$,
    pg_temp.lid('W2'), pg_temp.lid('S1'),
    jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 5))::text),
  'wh2 drafts a transfer W2 -> store');
select lives_ok(
  format($$ select public.generate_pick_list(%L) $$,
    (select id from public.transfers where from_location_id = pg_temp.lid('W2') and to_location_id = pg_temp.lid('S1'))),
  'wh2 generates a pick list for it');
select ok((select count(*) from public.pick_list_items) > 0, 'wh2 sees the pick list items');
reset role;

select pg_temp.login('wh1');
set local role authenticated;
select is((select count(*)::int from public.pick_lists), 0, 'wh1 sees no pick lists of W2');
select is((select count(*)::int from public.pick_list_items), 0, 'wh1 sees no pick list items of W2');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Invariants and access before any transfer
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;
select is((select count(*)::int from public.check_bin_stock_invariant(pg_temp.lid('W1')) where not is_valid), 0,
  'W1 bins add up to W1 stock');
select is((select count(*)::int from public.check_bin_stock_invariant(pg_temp.lid('W2')) where not is_valid), 0,
  'W2 bins add up to W2 stock');
reset role;

-- ---------------------------------------------------------------------------
-- 4. Transfer W1 -> W2
-- ---------------------------------------------------------------------------
select pg_temp.login('wh2');
set local role authenticated;
select throws_ok(
  format($$ select public.create_transfer(%L, %L, 'steal', %L::jsonb) $$,
    pg_temp.lid('W1'), pg_temp.lid('W2'),
    jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 5))::text),
  '42501', null, 'wh2 cannot start a transfer out of W1');
reset role;

select pg_temp.login('wh1');
set local role authenticated;
select lives_ok(
  format($$ select public.create_transfer(%L, %L, 'top up W2', %L::jsonb) $$,
    pg_temp.lid('W1'), pg_temp.lid('W2'),
    jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 30))::text),
  'wh1 drafts a transfer W1 -> W2 of 30');
reset role;

-- keep the id of the draft
create temp table t_ids as
  select id as transfer_id from public.transfers where from_location_id = pg_temp.lid('W1') and to_location_id = pg_temp.lid('W2');
grant all on t_ids to authenticated;

select pg_temp.login('wh2');
set local role authenticated;
select throws_ok(format($$ select public.ship_transfer(%L) $$, (select transfer_id from t_ids)), '42501', null,
  'the receiving warehouse cannot ship the draft');
reset role;

select pg_temp.login('wh1');
set local role authenticated;

-- shipping before anything is picked into STAGING is refused and moves nothing
select throws_ok(format($$ select public.ship_transfer(%L) $$, (select transfer_id from t_ids)), '55000', null,
  'shipping without a pick is refused (pick_required)');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1')), 100::numeric,
  'the refused shipment left W1 stock untouched');

-- the intended flow: put away to a storage bin, generate the pick list, pick into STAGING, then ship
select lives_ok(
  format($$ select public.execute_putaway(%L, %L, %L, %L, 100) $$, pg_temp.lid('W1'),
    (select id from public.bins where warehouse_id = pg_temp.lid('W1') and code = 'RECEIVING'),
    (select id from public.bins where warehouse_id = pg_temp.lid('W1') and code = 'A-01-1'),
    pg_temp.vid('rice')),
  'wh1 puts the 100 sacks away into A-01-1');
select lives_ok(format($$ select public.generate_pick_list(%L) $$, (select transfer_id from t_ids)),
  'wh1 generates the pick list for the transfer');
select lives_ok(
  format($$ select public.confirm_pick_item(%L, %L, 30) $$,
    (select id from public.pick_lists where transfer_id = (select transfer_id from t_ids)),
    (select pli.id from public.pick_list_items pli
       join public.pick_lists pl on pl.id = pli.pick_list_id where pl.transfer_id = (select transfer_id from t_ids) limit 1)),
  'wh1 picks 30 into STAGING');

select lives_ok(format($$ select public.ship_transfer(%L) $$, (select transfer_id from t_ids)), 'wh1 ships the transfer');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1')), 70::numeric,
  'W1 stock fell to 70 on shipment');
reset role;

select pg_temp.login('wh1');
set local role authenticated;
select throws_ok(
  format($$ select public.receive_transfer(%L, %L::jsonb) $$, (select transfer_id from t_ids),
    jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty_received', 30))::text),
  '42501', null, 'the sending warehouse cannot receive its own shipment at W2');
reset role;

select pg_temp.login('wh2');
set local role authenticated;
select lives_ok(
  format($$ select public.receive_transfer(%L, %L::jsonb) $$, (select transfer_id from t_ids),
    jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty_received', 28))::text),
  'wh2 receives 28 of 30 (2 short)');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W2')), 78::numeric,
  'W2 stock is 78 after receiving 28');
select ok((select has_discrepancy from public.transfers where id = (select transfer_id from t_ids)),
  'the short receipt is flagged as a discrepancy');
reset role;

-- costs: both lots cost 1000, so the blended average stays 1000 at W2
select is((select avg_cost from public.stock_levels where location_id = pg_temp.lid('W2')), 1000::bigint,
  'W2 average cost stays 1000 (same-cost lots)');

-- total stock: 100 + 50 - 2 lost in transit = 148
select is((select sum(qty_on_hand) from public.stock_levels where tenant_id = pg_temp.tid()), 148::numeric,
  'the 2 short units are the only stock that left the system');

-- ---------------------------------------------------------------------------
-- 5. Bin invariants after the transfer, in BOTH warehouses
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;
select is((select count(*)::int from public.check_bin_stock_invariant(pg_temp.lid('W1')) where not is_valid), 0,
  'W1 bins still add up to W1 stock after shipping');
select is((select count(*)::int from public.check_bin_stock_invariant(pg_temp.lid('W2')) where not is_valid), 0,
  'W2 bins still add up to W2 stock after receiving');
select is((select count(*)::int from public.bin_stock_levels where qty_on_hand < 0), 0,
  'no bin went negative (shipping without a pick must not drive STAGING below zero)');
reset role;

select * from finish();
rollback;
