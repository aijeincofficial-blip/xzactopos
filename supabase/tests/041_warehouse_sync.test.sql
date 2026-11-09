-- 041_warehouse_sync.test.sql: F-13h H1. The phone's server side: receipts through sync_push, and sync_pull_warehouse.
begin;
select plan(94);

-- ---------------------------------------------------------------------------
-- Fixtures. Tenant X: warehouses W1 (bins) and W2, store S1. Tenant Y: its own warehouse, supplier and order.
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p text) returns uuid language sql immutable as $$ select md5('tenant:WS:' || p)::uuid $$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$ select md5('user:WS:' || p)::uuid $$;
create function pg_temp.lid(p text) returns uuid language sql immutable as $$ select md5('loc:WS:' || p)::uuid $$;
create function pg_temp.vid(p text) returns uuid language sql immutable as $$ select md5('var:WS:' || p)::uuid $$;
create function pg_temp.oid(p text) returns uuid language sql immutable as $$ select md5('obj:WS:' || p)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.tid('X'), 'WS Tenant X', 'ws-x', 'PHP'), (pg_temp.tid('Y'), 'WS Tenant Y', 'ws-y', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid('X'), true, true), (pg_temp.tid('Y'), true, true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('X')), (pg_temp.tid('Y'));
insert into auth.users (id, email) select pg_temp.uid(n), n || '@ws.invalid' from unnest(array['owner', 'wh1', 'wh2', 'maria', 'juan', 'ownerY']) n;
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
  (pg_temp.lid('WY'), pg_temp.tid('Y'), 'warehouse', 'WY', 'Y Warehouse');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('wh1'),   pg_temp.lid('W1'), pg_temp.tid('X'), null),
  (pg_temp.uid('wh2'),   pg_temp.lid('W2'), pg_temp.tid('X'), null),
  (pg_temp.uid('maria'), pg_temp.lid('S1'), pg_temp.tid('X'), 'manager'),
  (pg_temp.uid('juan'),  pg_temp.lid('S1'), pg_temp.tid('X'), null);
insert into public.products (id, tenant_id, name) values
  (md5('p:WS:1')::uuid, pg_temp.tid('X'), 'Rice 25kg'), (md5('p:WS:2')::uuid, pg_temp.tid('X'), 'Cooking oil'),
  (md5('p:WS:3')::uuid, pg_temp.tid('X'), 'Salt'), (md5('p:WS:4')::uuid, pg_temp.tid('Y'), 'Y product');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (pg_temp.vid('rice'), pg_temp.tid('X'), md5('p:WS:1')::uuid, 'RICE25', true),
  (pg_temp.vid('oil'),  pg_temp.tid('X'), md5('p:WS:2')::uuid, 'OIL1L', true),
  (pg_temp.vid('salt'), pg_temp.tid('X'), md5('p:WS:3')::uuid, 'SALT1', true),
  (pg_temp.vid('y'),    pg_temp.tid('Y'), md5('p:WS:4')::uuid, 'Y1', true);
insert into public.suppliers (id, tenant_id, name) values
  (pg_temp.oid('supA'), pg_temp.tid('X'), 'Mega Rice Trading'), (pg_temp.oid('supY'), pg_temp.tid('Y'), 'Y Supplier');

-- opening stock: W1 rice 40, W2 oil 5, S1 rice 500
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('rice'),  40, 'receipt', 1000),
  (pg_temp.tid('X'), pg_temp.lid('W2'), pg_temp.vid('oil'),    5, 'receipt', 5000),
  (pg_temp.tid('X'), pg_temp.lid('S1'), pg_temp.vid('rice'), 500, 'receipt', 1000);

create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.uid(p_user), 'role', 'authenticated',
    'tenant_id', case when p_user = 'ownerY' then pg_temp.tid('Y') else pg_temp.tid('X') end)::text, true);
$$;
create function pg_temp.try(p_sql text) returns text language plpgsql as $$
declare v_state text; v_hint text;
begin
  execute p_sql;
  return 'ok';
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  v_state := sqlstate;
  return v_state || ':' || coalesce(v_hint, '');
end;
$$;
create function pg_temp.items(p_rice numeric default null, p_oil numeric default null, p_salt numeric default null) returns jsonb language sql as $$
  select coalesce(jsonb_agg(x), '[]'::jsonb) from (
    select jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', p_rice) x where p_rice is not null
    union all select jsonb_build_object('variant_id', pg_temp.vid('oil'), 'qty', p_oil) where p_oil is not null
    union all select jsonb_build_object('variant_id', pg_temp.vid('salt'), 'qty', p_salt) where p_salt is not null) q
$$;

-- bins on in W1 (the existing 40 rice move into RECEIVING), set up as the owner through the real RPCs
select pg_temp.login('owner');
set local role authenticated;
select lives_ok($$ select public.enable_warehouse_bins(pg_temp.lid('W1')) $$, 'bins are on in W1');
-- PO1 W1 ordered (rice 100, oil 20); PO2 W2 ordered (rice 10); PO3 W1 draft; PO4 W1 cancelled; PO5 W1 received
select lives_ok($$ select public.create_po(pg_temp.oid('po1'), pg_temp.lid('W1'), pg_temp.oid('supA'), null, null,
  jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 100, 'unit_cost', 1000), jsonb_build_object('variant_id', pg_temp.vid('oil'), 'qty', 20, 'unit_cost', 5000))) $$, 'PO1');
select lives_ok($$ select public.create_po(pg_temp.oid('po2'), pg_temp.lid('W2'), pg_temp.oid('supA'), null, null, jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 10))) $$, 'PO2');
select lives_ok($$ select public.create_po(pg_temp.oid('po3'), pg_temp.lid('W1'), pg_temp.oid('supA'), null, null, jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 5))) $$, 'PO3');
select lives_ok($$ select public.create_po(pg_temp.oid('po4'), pg_temp.lid('W1'), pg_temp.oid('supA'), null, null, jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 5))) $$, 'PO4');
select lives_ok($$ select public.create_po(pg_temp.oid('po5'), pg_temp.lid('W1'), pg_temp.oid('supA'), null, null, jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 3))) $$, 'PO5');
select lives_ok($$ select public.submit_po(pg_temp.oid('po1')) $$, 'PO1 ordered');
select lives_ok($$ select public.submit_po(pg_temp.oid('po2')) $$, 'PO2 ordered');
select lives_ok($$ select public.submit_po(pg_temp.oid('po4')) $$, 'PO4 ordered');
select lives_ok($$ select public.cancel_po(pg_temp.oid('po4'), 'mistake') $$, 'PO4 cancelled');
select lives_ok($$ select public.submit_po(pg_temp.oid('po5')) $$, 'PO5 ordered');
select lives_ok($$ select public.receive_po(pg_temp.oid('grn5'), pg_temp.oid('po5'), jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 3))) $$, 'PO5 received in full');
reset role;

-- tenant Y: a warehouse order of its own
insert into public.purchase_orders (id, tenant_id, po_no, warehouse_id, supplier_id, status, ordered_at)
  values (pg_temp.oid('poY'), pg_temp.tid('Y'), 'PO-Y-1', pg_temp.lid('WY'), pg_temp.oid('supY'), 'ordered', now());
insert into public.po_items (tenant_id, po_id, variant_id, qty_ordered) values (pg_temp.tid('Y'), pg_temp.oid('poY'), pg_temp.vid('y'), 9);

-- Everything above was created "now", and a pull holds back the last 5 seconds. Age the rows so they can be pulled.
create function pg_temp.age(p_interval interval) returns void language plpgsql as $$
begin
  set local session_replication_role = replica;
  update public.locations set updated_at = now() - p_interval where updated_at > now() - interval '10 seconds';
  update public.bins set updated_at = now() - p_interval where updated_at > now() - interval '10 seconds';
  update public.bin_stock_levels set updated_at = now() - p_interval where updated_at > now() - interval '10 seconds';
  update public.stock_levels set updated_at = now() - p_interval where updated_at > now() - interval '10 seconds';
  update public.suppliers set updated_at = now() - p_interval where updated_at > now() - interval '10 seconds';
  update public.purchase_orders set updated_at = now() - p_interval where updated_at > now() - interval '10 seconds';
  set local session_replication_role = origin;
end;
$$;
select pg_temp.age(interval '1 minute');

create function pg_temp.pull(p_user text, p_cursors jsonb default '{}'::jsonb, p_limit int default 500) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.login(p_user);
  execute 'set local role authenticated';
  v := public.sync_pull_warehouse(p_cursors, p_limit);
  execute 'reset role';
  return v;
end;
$$;
-- sorted values of one key over one table's rows
create function pg_temp.vals(p_res jsonb, p_tbl text, p_key text) returns text[] language sql as $$
  select coalesce(array_agg(x ->> p_key order by x ->> p_key), '{}') from jsonb_array_elements(p_res -> p_tbl -> 'rows') x
$$;

-- ---------------------------------------------------------------------------
-- 1. Pull: what each user's phone receives
-- ---------------------------------------------------------------------------
create temp table p1 as select pg_temp.pull('wh1') as res;
select is(pg_temp.vals((select res from p1), 'warehouses', 'code'), array['W1'], 'wh1 gets only warehouse W1 (no store, no other warehouse)');
select is(pg_temp.vals((select res from p1), 'bins', 'code'), array['A-01-1', 'RECEIVING', 'STAGING'], 'wh1 gets the three bins of W1');
select is(jsonb_array_length((select res -> 'bin_stock_levels' -> 'rows' from p1)), 1, 'and the one bin stock row (rice in RECEIVING)');
select is((select (res -> 'bin_stock_levels' -> 'rows' -> 0 ->> 'qty_on_hand')::numeric from p1), 43::numeric, 'holding 43 (40 opening + 3 received on PO5)');
select is(jsonb_array_length((select res -> 'stock_levels' -> 'rows' from p1)), 1, 'wh1 gets one warehouse stock row');
select is((select res -> 'stock_levels' -> 'rows' -> 0 ->> 'location_id' from p1), pg_temp.lid('W1')::text, 'for W1, not the store or W2');
select is(pg_temp.vals((select res from p1), 'suppliers', 'name'), array['Mega Rice Trading'], 'wh1 gets the tenant''s suppliers, not tenant Y''s');
select is(pg_temp.vals((select res from p1), 'purchase_orders', 'po_no') , (select array_agg(po_no order by po_no) from public.purchase_orders where id = pg_temp.oid('po1')),
  'the first pull sends only the open order of W1: not the draft, the cancelled or the finished ones');
select is(jsonb_array_length((select res -> 'purchase_orders' -> 'rows' -> 0 -> 'items' from p1)), 2, 'an order arrives with its two lines');
select is((select (x ->> 'qty_ordered')::numeric from p1, jsonb_array_elements(res -> 'purchase_orders' -> 'rows' -> 0 -> 'items') x where x ->> 'variant_id' = pg_temp.vid('rice')::text),
  100::numeric, 'with quantities');
select is((select res -> 'purchase_orders' -> 'rows' -> 0 ->> 'warehouse_id' from p1), pg_temp.lid('W1')::text, 'and its warehouse');
select ok((select (res ->> 'server_time') is not null from p1), 'every pull says what time the server is');

create temp table p2 as select pg_temp.pull('wh2') as res;
select is(pg_temp.vals((select res from p2), 'warehouses', 'code'), array['W2'], 'wh2 gets only W2');
select is(jsonb_array_length((select res -> 'bins' -> 'rows' from p2)), 0, 'W2 has no bins, and wh2 sees none of W1''s');
select is(jsonb_array_length((select res -> 'bin_stock_levels' -> 'rows' from p2)), 0, 'nor any of W1''s bin stock');
select is((select res -> 'stock_levels' -> 'rows' -> 0 ->> 'location_id' from p2), pg_temp.lid('W2')::text, 'wh2''s stock row is W2''s');
select is(jsonb_array_length((select res -> 'purchase_orders' -> 'rows' from p2)), 1, 'wh2 gets one open order');
select is((select res -> 'purchase_orders' -> 'rows' -> 0 ->> 'po_no' from p2), (select po_no from public.purchase_orders where id = pg_temp.oid('po2')), 'W2''s order, not W1''s');

create temp table p3 as select pg_temp.pull('owner') as res;
select is(pg_temp.vals((select res from p3), 'warehouses', 'code'), array['W1', 'W2'], 'the owner gets both warehouses and no store');
select is(jsonb_array_length((select res -> 'stock_levels' -> 'rows' from p3)), 2, 'the owner gets warehouse stock only: W1 rice and W2 oil, not the store''s rice');
select is(jsonb_array_length((select res -> 'purchase_orders' -> 'rows' from p3)), 2, 'and both open orders');

create temp table p4 as select pg_temp.pull('maria') as res;
select is((select sum(jsonb_array_length(res -> t -> 'rows'))::int from p4, unnest(array['warehouses', 'bins', 'bin_stock_levels', 'stock_levels', 'suppliers', 'purchase_orders']) t), 0,
  'a store admin receives nothing of the warehouse side');
create temp table p5 as select pg_temp.pull('juan') as res;
select is((select sum(jsonb_array_length(res -> t -> 'rows'))::int from p5, unnest(array['warehouses', 'bins', 'bin_stock_levels', 'stock_levels', 'suppliers', 'purchase_orders']) t), 0,
  'and neither does a cashier');
create temp table p6 as select pg_temp.pull('ownerY') as res;
select is(pg_temp.vals((select res from p6), 'warehouses', 'code'), array['WY'], 'tenant Y gets only its own warehouse');
select is(pg_temp.vals((select res from p6), 'purchase_orders', 'po_no'), array['PO-Y-1'], 'and only its own order');
select is(pg_temp.vals((select res from p6), 'suppliers', 'name'), array['Y Supplier'], 'and its own suppliers');

-- ---------------------------------------------------------------------------
-- 2. Pull: paging, the hold-back and argument checks
-- ---------------------------------------------------------------------------
create temp table pg1 as select pg_temp.pull('wh1', '{}'::jsonb, 2) as res;
select is(jsonb_array_length((select res -> 'bins' -> 'rows' from pg1)), 2, 'a page of 2 bins');
select is((select (res -> 'bins' -> 'has_more')::boolean from pg1), true, 'says there is more');
create temp table pg2 as select pg_temp.pull('wh1', (select jsonb_build_object('bins', res -> 'bins' -> 'cursor') from pg1), 2) as res;
select is(jsonb_array_length((select res -> 'bins' -> 'rows' from pg2)), 1, 'the next page holds the remaining bin');
select is((select (res -> 'bins' -> 'has_more')::boolean from pg2), false, 'and says it is the end');
select is(
  (select array_agg(x ->> 'code' order by x ->> 'code') from (
     select x from pg1, jsonb_array_elements(res -> 'bins' -> 'rows') x union all select x from pg2, jsonb_array_elements(res -> 'bins' -> 'rows') x) q(x)),
  array['A-01-1', 'RECEIVING', 'STAGING'], 'the two pages together are the three bins, none twice');
select is((select res -> 'bins' -> 'cursor' ->> 'k' from pg2), (select x ->> 'id' from pg2, jsonb_array_elements(res -> 'bins' -> 'rows') x limit 1), 'the cursor points at the last row sent');

create temp table pc as select pg_temp.pull('wh1', (select jsonb_object_agg(k, v -> 'cursor') from p1, jsonb_each(res) e(k, v) where jsonb_typeof(v) = 'object' and v ? 'cursor')) as res;
select is((select sum(jsonb_array_length(v -> 'rows'))::int from pc, jsonb_each(res) e(k, v) where jsonb_typeof(v) = 'object' and v ? 'rows'), 0, 'pulling again with the cursors returns nothing new');

-- a row touched a moment ago is held back
update public.suppliers set name = 'Mega Rice Trading Co' where id = pg_temp.oid('supA');
select is(pg_temp.vals(pg_temp.pull('wh1', (select jsonb_build_object('suppliers', res -> 'suppliers' -> 'cursor') from p1)), 'suppliers', 'name'), '{}'::text[],
  'a change made in the last 5 seconds is held back');
select pg_temp.age(interval '30 seconds');
select is(pg_temp.vals(pg_temp.pull('wh1', (select jsonb_build_object('suppliers', res -> 'suppliers' -> 'cursor') from p1)), 'suppliers', 'name'), array['Mega Rice Trading Co'],
  'and arrives once it is older');

select is(pg_temp.try($$ select pg_temp.pull('wh1', '{}'::jsonb, 0) $$), '22023:invalid_value', 'a page size of 0 is refused');
select is(pg_temp.try($$ select pg_temp.pull('wh1', '{}'::jsonb, 1001) $$), '22023:invalid_value', 'and 1001 is too many');

-- ---------------------------------------------------------------------------
-- 3. Push: receive against a purchase order, through sync_push
-- ---------------------------------------------------------------------------
create function pg_temp.push(p_user text, p_kind text, p_op text, p_payload jsonb) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.login(p_user);
  execute 'set local role authenticated';
  v := public.sync_push(jsonb_build_array(jsonb_build_object('op_id', pg_temp.oid(p_op), 'kind', p_kind, 'payload', p_payload))) -> 0;
  execute 'reset role';
  return v;
end;
$$;
create function pg_temp.rpo(p_po text, p_items jsonb) returns jsonb language sql as $$
  select jsonb_build_object('po_id', pg_temp.oid(p_po), 'items', p_items, 'delivery_ref', 'DR-9', 'notes', 'phone')
$$;

create temp table b1 as select pg_temp.push('wh1', 'receive_po', 'g1', pg_temp.rpo('po1', pg_temp.items(60))) as res;
select is((select res ->> 'status' from b1), 'ok', 'wh1 receives 60 rice against PO1 through the outbox');
select is((select res -> 'result' ->> 'po_status' from b1), 'partly_received', 'the order is partly received');
select ok((select res -> 'result' ->> 'grn_no' ~ '^GRN-[0-9]{6}-[0-9]{4}$' from b1), 'and the answer carries the receipt number the phone will show');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 103::numeric, 'W1 rice is 40 + 3 + 60');
select is((select qty_on_hand from public.bin_stock_levels bsl join public.bins b on b.id = bsl.bin_id where b.code = 'RECEIVING' and b.warehouse_id = pg_temp.lid('W1')), 103::numeric, 'all of it in the RECEIVING bin');
select is((select count(*)::int from public.goods_receipts where id = pg_temp.oid('g1') and delivery_ref = 'DR-9' and notes = 'phone' and received_by = pg_temp.uid('wh1')), 1,
  'the receipt id is the outbox op id and carries the delivery number, notes and clerk');
select is(pg_temp.push('wh1', 'receive_po', 'g1', pg_temp.rpo('po1', pg_temp.items(60))) -> 'result' ->> 'replay', 'true', 'sending the same op again is a replay');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 103::numeric, 'which adds nothing');
select is((select count(*)::int from public.goods_receipts where tenant_id = pg_temp.tid('X')), 2, 'and makes no second receipt (PO5''s and this one)');

select is(pg_temp.push('wh1', 'receive_po', 'g2', pg_temp.rpo('po2', pg_temp.items(1))) ->> 'hint', 'location_denied', 'wh1 cannot receive against W2''s order');
select is(pg_temp.push('wh1', 'receive_po', 'g2', pg_temp.rpo('po2', pg_temp.items(1))) ->> 'status', 'rejected', 'which is a refusal the phone parks, not a retry');
select is(pg_temp.push('maria', 'receive_po', 'g3', pg_temp.rpo('po1', pg_temp.items(1))) ->> 'hint', 'not_allowed', 'a store admin cannot receive warehouse goods');
select is(pg_temp.push('juan', 'receive_po', 'g3', pg_temp.rpo('po1', pg_temp.items(1))) ->> 'hint', 'not_allowed', 'nor a cashier');
select is(pg_temp.push('wh1', 'receive_po', 'g4', pg_temp.rpo('po3', pg_temp.items(1))) ->> 'hint', 'invalid_state', 'a draft order takes no goods');
select is(pg_temp.push('wh1', 'receive_po', 'g5', pg_temp.rpo('po4', pg_temp.items(1))) ->> 'hint', 'invalid_state', 'nor a cancelled one');
select is(pg_temp.push('wh1', 'receive_po', 'g6', pg_temp.rpo('po1', pg_temp.items(null, null, 2))) ->> 'hint', 'not_on_po', 'a product that is not on the order is refused');
select is(pg_temp.push('wh1', 'receive_po', 'g7', pg_temp.rpo('po1', '[]'::jsonb)) ->> 'hint', 'items_required', 'an empty delivery is refused');
select is(pg_temp.push('wh1', 'receive_po', 'g8', jsonb_build_object('items', pg_temp.items(1))) ->> 'hint', 'not_found', 'a payload without a PO id is not found');
select is(pg_temp.push('wh1', 'receive_po', 'g9', jsonb_build_object('po_id', 'not-a-uuid', 'items', pg_temp.items(1))) ->> 'status', 'rejected', 'a malformed id is refused, not a crash');
select is(pg_temp.push('wh1', 'receive_po', 'g1', pg_temp.rpo('po5', pg_temp.items(1))) ->> 'hint', 'id_conflict', 'an op id already used for another order is refused');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W2') and variant_id = pg_temp.vid('rice')), null, 'refused receipts moved no stock in W2');

create temp table b2 as select pg_temp.push('wh1', 'receive_po', 'g10', pg_temp.rpo('po1', pg_temp.items(null, 25))) as res;
select is((select (res -> 'result' ->> 'has_discrepancy')::boolean from b2), true, 'over-delivery (25 oil against 20) is accepted and flagged');

-- ---------------------------------------------------------------------------
-- 4. Push: receive without an order
-- ---------------------------------------------------------------------------
create temp table b3 as select pg_temp.push('wh1', 'receive_without_po', 'w1',
  jsonb_build_object('warehouse_id', pg_temp.lid('W1'), 'supplier_id', pg_temp.oid('supA'), 'items', pg_temp.items(null, null, 7), 'delivery_ref', 'WALK-1')) as res;
select is((select res ->> 'status' from b3), 'ok', 'wh1 records a walk-in delivery');
select is((select (res -> 'result' ->> 'without_po')::boolean from b3), true, 'flagged as having no order');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('salt')), 7::numeric, 'salt is in stock');
select ok((select supplier_id = pg_temp.oid('supA') and delivery_ref = 'WALK-1' from public.goods_receipts where id = pg_temp.oid('w1')), 'the walk-in keeps its supplier and delivery number');
select is(pg_temp.push('wh1', 'receive_without_po', 'w1',
  jsonb_build_object('warehouse_id', pg_temp.lid('W1'), 'supplier_id', pg_temp.oid('supA'), 'items', pg_temp.items(null, null, 7), 'delivery_ref', 'WALK-1')) -> 'result' ->> 'replay', 'true', 'a repeat is a replay');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('salt')), 7::numeric, 'adding nothing');
select is(pg_temp.push('wh1', 'receive_without_po', 'w2', jsonb_build_object('warehouse_id', pg_temp.lid('W2'), 'items', pg_temp.items(null, null, 1))) ->> 'hint', 'location_denied',
  'wh1 cannot receive without an order into W2');
select is(pg_temp.push('wh2', 'receive_without_po', 'w3', jsonb_build_object('warehouse_id', pg_temp.lid('W2'), 'items', pg_temp.items(null, null, 1))) ->> 'status', 'ok',
  'wh2 can into its own warehouse (no supplier given)');
select is(pg_temp.push('maria', 'receive_without_po', 'w4', jsonb_build_object('warehouse_id', pg_temp.lid('W1'), 'items', pg_temp.items(null, null, 1))) ->> 'hint', 'not_allowed',
  'a store admin cannot');
select is((select count(*)::int from public.audit_log where action = 'op.refused' and entity = 'receive_without_po' and location_id = pg_temp.lid('W2')), 1,
  'the refused walk-in is audited against the warehouse it named');

-- one bad op does not stop the good one after it
select pg_temp.login('wh1');
set local role authenticated;
create temp table batch as select public.sync_push(jsonb_build_array(
  jsonb_build_object('op_id', pg_temp.oid('bt1'), 'kind', 'receive_po', 'payload', pg_temp.rpo('po2', pg_temp.items(1))),
  jsonb_build_object('op_id', pg_temp.oid('bt2'), 'kind', 'receive_without_po', 'payload',
    jsonb_build_object('warehouse_id', pg_temp.lid('W1'), 'items', pg_temp.items(null, null, 2))))) as res;
grant all on batch to authenticated;
reset role;
select is((select array_agg(x ->> 'status' order by ord) from batch, jsonb_array_elements(res) with ordinality t(x, ord)), array['rejected', 'ok'], 'in a batch, the refused op does not block the good one, and order is kept');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('salt')), 9::numeric, 'the good one landed (7 + 2)');
select is(pg_temp.push('wh1', 'receive_warehouse_stock', 'rw1', jsonb_build_object('location_id', pg_temp.lid('W1'), 'variant_id', pg_temp.vid('salt'), 'qty', 1)) ->> 'status', 'ok',
  'the earlier single-line receipt kind still works');
select is(pg_temp.push('wh1', 'no_such_kind', 'x1', '{}'::jsonb) ->> 'hint', 'unknown_kind', 'unknown kinds are still refused');

-- ---------------------------------------------------------------------------
-- 5. Pull after the pushes: the changed order and stock arrive as a delta
-- ---------------------------------------------------------------------------
-- a draft changes on the server too; it must never reach a phone
update public.purchase_orders set notes = 'edited draft' where id = pg_temp.oid('po3');
select pg_temp.age(interval '30 seconds');
create temp table d1 as select pg_temp.pull('wh1', (select jsonb_object_agg(k, v -> 'cursor') from p1, jsonb_each(res) e(k, v) where jsonb_typeof(v) = 'object' and v ? 'cursor')) as res;
select ok(pg_temp.oid('po1')::text = any (pg_temp.vals((select res from d1), 'purchase_orders', 'id')), 'the changed order comes back');
select ok(not (pg_temp.oid('po3')::text = any (pg_temp.vals((select res from d1), 'purchase_orders', 'id'))), 'a changed draft never does');
select is((select x ->> 'status' from d1, jsonb_array_elements(res -> 'purchase_orders' -> 'rows') x where x ->> 'id' = pg_temp.oid('po1')::text), 'partly_received', 'with its new status');
select is((select (i ->> 'qty_received')::numeric from d1, jsonb_array_elements(res -> 'purchase_orders' -> 'rows') x, jsonb_array_elements(x -> 'items') i where x ->> 'id' = pg_temp.oid('po1')::text and i ->> 'variant_id' = pg_temp.vid('rice')::text), 60::numeric,
  'and the quantities received so far');
select is((select (x ->> 'qty_on_hand')::numeric from d1, jsonb_array_elements(res -> 'stock_levels' -> 'rows') x where x ->> 'variant_id' = pg_temp.vid('rice')::text), 103::numeric,
  'and the new stock level');
select is((select (res -> 'bin_stock_levels' -> 'rows' -> 0 ->> 'qty_on_hand')::numeric from d1), 103::numeric, 'and the new bin stock level');

-- a finished order is sent once so the phone can drop it
update public.purchase_orders set status = 'received' where id = pg_temp.oid('po1');
select pg_temp.age(interval '20 seconds');
select ok(pg_temp.oid('po1')::text = any (pg_temp.vals(pg_temp.pull('wh1', (select jsonb_build_object('purchase_orders', res -> 'purchase_orders' -> 'cursor') from d1)), 'purchase_orders', 'id')),
  'an order that finishes is sent again, so the phone can drop it');

-- ---------------------------------------------------------------------------
-- 6. The warehouse module must be on
-- ---------------------------------------------------------------------------
update public.tenant_modules set warehouse = false where tenant_id = pg_temp.tid('X');
select isnt(pg_temp.try($$ select pg_temp.pull('wh1') $$), 'ok', 'a pull is refused when the warehouse module is off');
select isnt(pg_temp.push('wh1', 'receive_po', 'm1', pg_temp.rpo('po2', pg_temp.items(1))) ->> 'status', 'ok', 'and so is a receipt');

select * from finish();
rollback;
