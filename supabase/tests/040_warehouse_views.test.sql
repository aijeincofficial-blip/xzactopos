-- 040_warehouse_views.test.sql: F-13f. Read-only views across warehouses: where is a product, what needs reordering, what is in transit.
begin;
select plan(78);

-- ---------------------------------------------------------------------------
-- Fixtures: warehouses W1 and W2, store S1, tenant Y
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p text) returns uuid language sql immutable as $$ select md5('tenant:WV:' || p)::uuid $$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$ select md5('user:WV:' || p)::uuid $$;
create function pg_temp.lid(p text) returns uuid language sql immutable as $$ select md5('loc:WV:' || p)::uuid $$;
create function pg_temp.vid(p text) returns uuid language sql immutable as $$ select md5('var:WV:' || p)::uuid $$;
create function pg_temp.oid(p text) returns uuid language sql immutable as $$ select md5('obj:WV:' || p)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.tid('X'), 'WV Tenant X', 'wv-x', 'PHP'), (pg_temp.tid('Y'), 'WV Tenant Y', 'wv-y', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid('X'), true, true), (pg_temp.tid('Y'), true, true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('X')), (pg_temp.tid('Y'));
insert into auth.users (id, email) select pg_temp.uid(n), n || '@wv.invalid' from unnest(array['owner', 'wh1', 'wh2', 'maria', 'juan', 'ownerY']) n;
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('owner'),  pg_temp.tid('X'), 'owner',  'superadmin', true),
  (pg_temp.uid('wh1'),    pg_temp.tid('X'), 'wh1',    'warehouse',  true),
  (pg_temp.uid('wh2'),    pg_temp.tid('X'), 'wh2',    'warehouse',  true),
  (pg_temp.uid('maria'),  pg_temp.tid('X'), 'maria',  'admin',      true),
  (pg_temp.uid('juan'),   pg_temp.tid('X'), 'juan',   'cashier',    true),
  (pg_temp.uid('ownerY'), pg_temp.tid('Y'), 'owner',  'superadmin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.lid('W1'), pg_temp.tid('X'), 'warehouse', 'W1', 'Warehouse One'),
  (pg_temp.lid('W2'), pg_temp.tid('X'), 'warehouse', 'W2', 'Warehouse Two'),
  (pg_temp.lid('S1'), pg_temp.tid('X'), 'store',     'S1', 'Store One'),
  (pg_temp.lid('S2'), pg_temp.tid('X'), 'store',     'S2', 'Store Two'),
  (pg_temp.lid('WY'), pg_temp.tid('Y'), 'warehouse', 'WY', 'Y Warehouse');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('wh1'),   pg_temp.lid('W1'), pg_temp.tid('X'), null),
  (pg_temp.uid('wh2'),   pg_temp.lid('W2'), pg_temp.tid('X'), null),
  (pg_temp.uid('maria'), pg_temp.lid('S1'), pg_temp.tid('X'), 'manager'),
  (pg_temp.uid('juan'),  pg_temp.lid('S1'), pg_temp.tid('X'), null);
insert into public.products (id, tenant_id, name) values
  (md5('p:WV:1')::uuid, pg_temp.tid('X'), 'Rice 25kg'), (md5('p:WV:2')::uuid, pg_temp.tid('X'), 'Cooking oil'), (md5('p:WV:3')::uuid, pg_temp.tid('X'), 'Salt'), (md5('p:WV:4')::uuid, pg_temp.tid('X'), 'Sugar');
-- reorder points: rice 80, oil 10, salt 0 (0 = not managed)
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, reorder_point) values
  (pg_temp.vid('rice'), pg_temp.tid('X'), md5('p:WV:1')::uuid, 'RICE25', true, 80),
  (pg_temp.vid('oil'),  pg_temp.tid('X'), md5('p:WV:2')::uuid, 'OIL1L', true, 10),
  (pg_temp.vid('salt'), pg_temp.tid('X'), md5('p:WV:3')::uuid, 'SALT1', true, 0),
  (pg_temp.vid('sugar'), pg_temp.tid('X'), md5('p:WV:4')::uuid, 'SUGAR1', true, 5);
insert into public.suppliers (id, tenant_id, name) values (pg_temp.oid('sup'), pg_temp.tid('X'), 'Mega Rice Trading');

-- opening stock: W1 rice 60, oil 50 | W2 rice 55, oil 5, salt 3 | S1 rice 500
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('rice'),  60, 'receipt', 1000),
  (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('oil'),   50, 'receipt', 5000),
  (pg_temp.tid('X'), pg_temp.lid('W2'), pg_temp.vid('rice'),  55, 'receipt', 1000),
  (pg_temp.tid('X'), pg_temp.lid('W2'), pg_temp.vid('oil'),    5, 'receipt', 5000),
  (pg_temp.tid('X'), pg_temp.lid('W2'), pg_temp.vid('salt'),   3, 'receipt', 300),
  (pg_temp.tid('X'), pg_temp.lid('S1'), pg_temp.vid('rice'), 500, 'receipt', 1000),
  (pg_temp.tid('X'), pg_temp.lid('W2'), pg_temp.vid('sugar'),  5, 'receipt', 800),
  (pg_temp.tid('X'), pg_temp.lid('S1'), pg_temp.vid('sugar'),  2, 'receipt', 800);
-- salt at W2 is sold down to exactly 0 (an unmanaged product at 0 must NOT be listed)
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
  values (pg_temp.tid('X'), pg_temp.lid('W2'), pg_temp.vid('salt'), -3, 'damage');

create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.uid(p_user), 'role', 'authenticated',
    'tenant_id', case when p_user = 'ownerY' then pg_temp.tid('Y') else pg_temp.tid('X') end)::text, true);
$$;
create function pg_temp.item(p_var text, p_qty numeric) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid(p_var), 'qty', p_qty, 'unit_cost', 1000))
$$;

-- Documents, all made through the real RPCs by the owner
select pg_temp.login('owner');
set local role authenticated;
-- T1 W1 -> W2 rice 20 (shipped), T2 S1 -> W1 rice 7 (shipped), T3 W2 -> W1 oil 3 (draft), T4 W2 -> W1 oil 1 (shipped then received)
select lives_ok($$ select public.create_transfer(pg_temp.lid('W1'), pg_temp.lid('W2'), 'T1', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 30)), true) $$, 'T1 shipped W1 -> W2');
select lives_ok($$ select public.create_transfer(pg_temp.lid('S1'), pg_temp.lid('W1'), 'T2', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 7), jsonb_build_object('variant_id', pg_temp.vid('sugar'), 'qty', 1)), true) $$, 'T2 shipped S1 -> W1 (two lines)');
select lives_ok($$ select public.create_transfer(pg_temp.lid('S1'), pg_temp.lid('S2'), 'T5', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 3)), true) $$, 'T5 shipped between two stores (no warehouse involved)');
select lives_ok($$ select public.create_transfer(pg_temp.lid('W2'), pg_temp.lid('W1'), 'T3', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('oil'), 'qty', 3)), false) $$, 'T3 left as a draft');
select lives_ok($$ select public.receive_transfer(public.create_transfer(pg_temp.lid('W2'), pg_temp.lid('W1'), 'T4', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('oil'), 'qty', 1)), true),
  jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('oil'), 'qty_received', 1))) $$, 'T4 shipped and received');
-- PO1 W1 rice 100, ordered, 30 received (70 still on order). PO2 W2 oil 40 draft. PO3 W2 oil 25 ordered. PO4 W1 rice 999 cancelled.
select lives_ok($$ select public.create_po(pg_temp.oid('po1'), pg_temp.lid('W1'), pg_temp.oid('sup'), null, null, pg_temp.item('rice', 100)) $$, 'PO1 drafted');
select lives_ok($$ select public.submit_po(pg_temp.oid('po1')) $$, 'PO1 ordered');
select lives_ok($$ select public.receive_po(pg_temp.oid('grn1'), pg_temp.oid('po1'), jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 30))) $$, '30 of PO1 arrive');
select lives_ok($$ select public.create_po(pg_temp.oid('po2'), pg_temp.lid('W2'), pg_temp.oid('sup'), null, null, pg_temp.item('oil', 40)) $$, 'PO2 left as a draft');
select lives_ok($$ select public.create_po(pg_temp.oid('po3'), pg_temp.lid('W2'), pg_temp.oid('sup'), null, null, pg_temp.item('oil', 25)) $$, 'PO3 drafted');
select lives_ok($$ select public.submit_po(pg_temp.oid('po3')) $$, 'PO3 ordered');
select lives_ok($$ select public.create_po(pg_temp.oid('po4'), pg_temp.lid('W1'), pg_temp.oid('sup'), null, null, pg_temp.item('rice', 999)) $$, 'PO4 drafted');
select lives_ok($$ select public.cancel_po(pg_temp.oid('po4'), 'mistake') $$, 'PO4 cancelled');
reset role;

-- Now: W1 rice 60 - 30 (T1) + 30 (PO1 receipt) = 60, W1 oil 50 + 1 (T4) = 51. W2 rice 55, oil 5 - 1 (T4) = 4, salt 3. S1 rice 500 - 7 (T2) = 493.
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 60::numeric, 'setup: W1 rice is 60');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W2') and variant_id = pg_temp.vid('oil')), 4::numeric, 'setup: W2 oil is 4 after T4 left');

-- ---------------------------------------------------------------------------
-- 1. warehouse_stock_by_variant: where is it, how much, what is coming
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;
select is((select count(*)::int from public.warehouse_stock_by_variant(pg_temp.vid('rice'))), 2, 'the owner sees both warehouses, not the store');
select is((select qty_on_hand from public.warehouse_stock_by_variant(pg_temp.vid('rice')) where code = 'W1'), 60::numeric, 'W1 rice 60');
select is((select qty_on_hand from public.warehouse_stock_by_variant(pg_temp.vid('rice')) where code = 'W2'), 55::numeric, 'W2 rice 55');
select is((select incoming_qty from public.warehouse_stock_by_variant(pg_temp.vid('rice')) where code = 'W1'), 7::numeric, 'W1 has 7 rice in transit from the store');
select is((select incoming_qty from public.warehouse_stock_by_variant(pg_temp.vid('rice')) where code = 'W2'), 30::numeric, 'W2 has 30 rice in transit from W1');
select is((select on_order_qty from public.warehouse_stock_by_variant(pg_temp.vid('rice')) where code = 'W1'), 70::numeric,
  'W1 still has 70 rice on order (100 ordered, 30 received); the cancelled PO is not counted');
select is((select on_order_qty from public.warehouse_stock_by_variant(pg_temp.vid('rice')) where code = 'W2'), 0::numeric, 'W2 has none on order');
select is((select stock_value from public.warehouse_stock_by_variant(pg_temp.vid('rice')) where code = 'W1'), 60000::bigint, 'W1 rice is worth 60 x 1000');
select is((select avg_cost from public.warehouse_stock_by_variant(pg_temp.vid('rice')) where code = 'W2'), 1000::bigint, 'with its average cost');
select is((select on_order_qty from public.warehouse_stock_by_variant(pg_temp.vid('oil')) where code = 'W2'), 25::numeric, 'W2 oil: 25 on order, the draft PO of 40 is not counted');
select is((select incoming_qty from public.warehouse_stock_by_variant(pg_temp.vid('oil')) where code = 'W1'), 0::numeric, 'a draft transfer and a received transfer are not in transit');
select is((select qty_on_hand from public.warehouse_stock_by_variant(pg_temp.vid('salt')) where code = 'W1'), 0::numeric, 'a warehouse that never held the product shows 0, not nothing');
select is((select avg_cost from public.warehouse_stock_by_variant(pg_temp.vid('salt')) where code = 'W1'), null, 'and no cost');
select is((select stock_value from public.warehouse_stock_by_variant(pg_temp.vid('salt')) where code = 'W1'), null, 'so no value');
select is((select count(*)::int from public.warehouse_stock_by_variant(md5('nope')::uuid)), 2, 'an unknown product shows zero in each warehouse');
reset role;

select pg_temp.login('wh1');
set local role authenticated;
select is((select array_agg(code order by code) from public.warehouse_stock_by_variant(pg_temp.vid('rice'))), array['W1'], 'wh1 sees only W1');
select is((select qty_on_hand from public.warehouse_stock_by_variant(pg_temp.vid('rice'))), 60::numeric, 'with its own figures');
select is((select incoming_qty from public.warehouse_stock_by_variant(pg_temp.vid('rice'))), 7::numeric, 'and its own incoming shipment');
reset role;
select pg_temp.login('wh2');
set local role authenticated;
select is((select array_agg(code order by code) from public.warehouse_stock_by_variant(pg_temp.vid('rice'))), array['W2'], 'wh2 sees only W2');
select is((select incoming_qty from public.warehouse_stock_by_variant(pg_temp.vid('rice'))), 30::numeric, 'and the 30 rice on their way to it');
select is((select on_order_qty from public.warehouse_stock_by_variant(pg_temp.vid('oil'))), 25::numeric, 'and its own open order');
reset role;
select pg_temp.login('maria');
set local role authenticated;
select is((select count(*)::int from public.warehouse_stock_by_variant(pg_temp.vid('rice'))), 0, 'a store admin sees no warehouse');
reset role;
select pg_temp.login('juan');
set local role authenticated;
select is((select count(*)::int from public.warehouse_stock_by_variant(pg_temp.vid('rice'))), 0, 'a cashier sees no warehouse');
reset role;
select pg_temp.login('ownerY');
set local role authenticated;
select is((select array_agg(code) from public.warehouse_stock_by_variant(pg_temp.vid('rice'))), array['WY'], 'tenant Y sees only its own warehouse');
select is((select qty_on_hand from public.warehouse_stock_by_variant(pg_temp.vid('rice'))), 0::numeric, 'and none of tenant X''s stock');
reset role;

-- ---------------------------------------------------------------------------
-- 2. warehouse_reorder_list: at or below the reorder point, with what is already on its way
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;
select is((select count(*)::int from public.warehouse_reorder_list()), 4, 'four warehouse lines are at or below their reorder point (one exactly at it)');
select ok((select not covered and shortfall = 0 and qty_on_hand = 5 from public.warehouse_reorder_list() where sku = 'SUGAR1' and location_code = 'W2'), 'a product exactly AT its reorder point is listed, with nothing coming');
select is((select count(*)::int from public.warehouse_reorder_list() where sku = 'SALT1'), 0, 'a product with reorder point 0 is not managed');
select is((select count(*)::int from public.warehouse_reorder_list() where sku = 'OIL1L' and location_code = 'W1'), 0, 'W1 oil (51 against 10) is fine');
select ok((select covered and shortfall = 0 and qty_on_hand = 60 and incoming_qty = 7 and on_order_qty = 70 and reorder_point = 80
           from public.warehouse_reorder_list() where sku = 'RICE25' and location_code = 'W1'),
  'W1 rice is low (60 against 80) but covered by 7 in transit and 70 on order');
select ok((select covered and shortfall = 0 and qty_on_hand = 55 and incoming_qty = 30 and on_order_qty = 0
           from public.warehouse_reorder_list() where sku = 'RICE25' and location_code = 'W2'),
  'W2 rice is low (55) but the 30 on their way lift it to 85, above 80: covered by incoming stock alone');
select ok((select covered and shortfall = 0 and qty_on_hand = 4 and on_order_qty = 25
           from public.warehouse_reorder_list() where sku = 'OIL1L' and location_code = 'W2'),
  'W2 oil is low (4 against 10) but 25 are on order');
select is((select product_name from public.warehouse_reorder_list() where sku = 'RICE25' and location_code = 'W2'), 'Rice 25kg', 'lines carry the product name');
select is((select count(*)::int from public.warehouse_reorder_list(pg_temp.lid('W2'))), 3, 'filtered to one warehouse: W2 has three lines');
select is((select count(*)::int from public.warehouse_reorder_list(pg_temp.lid('S1'))), 0, 'a store is not a warehouse: no lines');

-- paging
create temp table pg1 as select location_id, variant_id from public.warehouse_reorder_list(null, 2);
grant all on pg1 to authenticated;
select is((select count(*)::int from pg1), 2, 'a page of 2');
select is((select count(*)::int from public.warehouse_reorder_list(null, 10, (select location_id from pg1 order by location_id desc, variant_id desc limit 1),
                                                                   (select variant_id from pg1 order by location_id desc, variant_id desc limit 1))), 2,
  'the next page holds the remaining two lines');
select is((select count(*)::int from public.warehouse_reorder_list(null, 0)), 1, 'a page size below 1 is raised to 1');
select is((select count(*)::int from public.warehouse_reorder_list(null, 100000)), 4, 'a big page size returns everything when it fits');
reset role;

select pg_temp.login('wh1');
set local role authenticated;
select is((select count(*)::int from public.warehouse_reorder_list()), 1, 'wh1 sees only its own line');
reset role;
select pg_temp.login('wh2');
set local role authenticated;
select is((select count(*)::int from public.warehouse_reorder_list()), 3, 'wh2 sees its three lines');
select is((select count(*)::int from public.warehouse_reorder_list(pg_temp.lid('W1'))), 0, 'and asking for W1 returns nothing');
reset role;
select pg_temp.login('maria');
set local role authenticated;
select is((select count(*)::int from public.warehouse_reorder_list()), 0, 'a store admin sees nothing');
reset role;
select pg_temp.login('ownerY');
set local role authenticated;
select is((select count(*)::int from public.warehouse_reorder_list()), 0, 'tenant Y sees nothing of tenant X');
reset role;

-- a negative level is the loudest low stock
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
  values (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('oil'), -60, 'damage');
select pg_temp.login('owner');
set local role authenticated;
select ok((select qty_on_hand = -9 and not covered and shortfall = 19 from public.warehouse_reorder_list() where sku = 'OIL1L' and location_code = 'W1'),
  'W1 oil at -9 appears, 19 short of 10');
reset role;

-- ---------------------------------------------------------------------------
-- 3. warehouse_transfers_in_transit
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;
select is((select count(*)::int from public.warehouse_transfers_in_transit()), 2, 'two shipments are on their way; the draft, the received one and the store-to-store one are not');
select ok((select from_code = 'W1' and to_code = 'W2' and lines = 1 and units = 30 and hours_in_transit >= 0 and transfer_no like 'TRF-%'
           from public.warehouse_transfers_in_transit() where to_code = 'W2'), 'T1: W1 to W2, one line, 30 units');
select ok((select from_code = 'S1' and to_code = 'W1' and lines = 2 and units = 8 from public.warehouse_transfers_in_transit() where to_code = 'W1'), 'T2: store S1 to W1, two lines, 8 units in total');
select is((select count(*)::int from public.warehouse_transfers_in_transit(pg_temp.lid('W2'))), 1, 'filtered to W2: one shipment');
select is((select count(*)::int from public.warehouse_transfers_in_transit(pg_temp.lid('W1'))), 2, 'filtered to W1: both touch it');
create temp table tp1 as select transfer_id, shipped_at from public.warehouse_transfers_in_transit(null, 1);
grant all on tp1 to authenticated;
select is((select count(*)::int from tp1), 1, 'a page of 1');
select is((select count(*)::int from public.warehouse_transfers_in_transit(null, 1, (select shipped_at from tp1), (select transfer_id from tp1))), 1, 'the next page holds the other shipment');
select is((select count(*)::int from public.warehouse_transfers_in_transit(null, 5, (select shipped_at from tp1), (select transfer_id from tp1))), 1, 'and nothing repeats');
reset role;

select pg_temp.login('wh1');
set local role authenticated;
select is((select count(*)::int from public.warehouse_transfers_in_transit()), 2, 'wh1 sees both shipments (each touches W1)');
select is((select to_code from public.warehouse_transfers_in_transit() where units = 30), null, 'but not the name of W2, which they cannot see');
reset role;
select pg_temp.login('wh2');
set local role authenticated;
select is((select count(*)::int from public.warehouse_transfers_in_transit()), 1, 'wh2 sees only the shipment to W2');
reset role;
select pg_temp.login('maria');
set local role authenticated;
select is((select count(*)::int from public.warehouse_transfers_in_transit()), 0, 'a store admin sees no warehouse shipment');
reset role;
select pg_temp.login('juan');
set local role authenticated;
select is((select count(*)::int from public.warehouse_transfers_in_transit()), 0, 'a cashier sees none');
reset role;
select pg_temp.login('ownerY');
set local role authenticated;
select is((select count(*)::int from public.warehouse_transfers_in_transit()), 0, 'tenant Y sees none');
reset role;

-- ---------------------------------------------------------------------------
-- 4. They only read
-- ---------------------------------------------------------------------------
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname in ('warehouse_stock_by_variant', 'warehouse_reorder_list', 'warehouse_transfers_in_transit')
             and (p.prosecdef or p.provolatile <> 's')), 0, 'all three run as the caller and are marked stable');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname in ('warehouse_stock_by_variant', 'warehouse_reorder_list', 'warehouse_transfers_in_transit')
             and has_function_privilege('anon', p.oid, 'execute')), 0, 'and anonymous users cannot call them');
select throws_ok($$ set local role anon; select * from public.warehouse_reorder_list() $$, '42501', null, 'anon is refused');

-- ---------------------------------------------------------------------------
-- 5. Page size is capped at 500
-- ---------------------------------------------------------------------------
insert into public.products (id, tenant_id, name) select md5('bulkp:' || g)::uuid, pg_temp.tid('X'), 'Bulk ' || g from generate_series(1, 510) g;
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, reorder_point)
  select md5('bulkv:' || g)::uuid, pg_temp.tid('X'), md5('bulkp:' || g)::uuid, 'BULK' || g, true, 1 from generate_series(1, 510) g;
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
  select pg_temp.tid('X'), pg_temp.lid('W1'), md5('bulkv:' || g)::uuid, 1, 'receipt' from generate_series(1, 510) g;
select pg_temp.login('owner');
set local role authenticated;
select is((select count(*)::int from public.warehouse_reorder_list(null, 100000)), 500, 'a huge page size is capped at 500 rows');
reset role;

select * from finish();
rollback;
