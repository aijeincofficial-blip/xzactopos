-- 050_pos_receive_from_warehouse.test.sql
-- Verifies Warehouse -> POS Store stock dispatch & POS receiving flow:
-- 1. Warehouse staff dispatches transfer from WH01 to Store ST01.
-- 2. POS cashier assigned to ST01 lists incoming transfers via list_store_incoming_transfers (no cost leak).
-- 3. Cashier assigned only to ST02 cannot read ST01 incoming transfers.
-- 4. POS cashier at ST01 receives the shipment via receive_transfer and store stock updates immediately.

begin;
select plan(9);

create function pg_temp.tid(p text) returns uuid language sql immutable
  as $$ select md5('pos_rcv_tenant:' || p)::uuid $$;

create function pg_temp.uid(p text) returns uuid language sql immutable
  as $$ select md5('pos_rcv_user:' || p)::uuid $$;

create function pg_temp.lid(p text) returns uuid language sql immutable
  as $$ select md5('pos_rcv_loc:' || p)::uuid $$;

create function pg_temp.vid(p text) returns uuid language sql immutable
  as $$ select md5('pos_rcv_var:' || p)::uuid $$;

create function pg_temp.login(p_user text, p_role text, p_locations uuid[] default '{}')
returns void language plpgsql as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', pg_temp.uid(p_user),
      'role', 'authenticated',
      'tenant_id', pg_temp.tid('T'),
      'user_role', p_role,
      'location_ids', to_jsonb(p_locations)
    )::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.tid('T'), '050 Retail Group', 't050-pos-rcv', 'PHP', 'Asia/Manila');

insert into public.tenant_modules (tenant_id, inventory, pos, warehouse) values
  (pg_temp.tid('T'), true, true, true);

insert into public.tenant_settings (tenant_id) values
  (pg_temp.tid('T'));

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.lid('WH01'), pg_temp.tid('T'), 'warehouse', 'WH01', 'Central Warehouse'),
  (pg_temp.lid('ST01'), pg_temp.tid('T'), 'store',     'ST01', 'Main POS Store'),
  (pg_temp.lid('ST02'), pg_temp.tid('T'), 'store',     'ST02', 'Branch Two POS');

insert into auth.users (id, email) values
  (pg_temp.uid('owner'),    'owner@050.test'),
  (pg_temp.uid('whclerk'),  'wh@050.test'),
  (pg_temp.uid('cashier1'), 'c1@050.test'),
  (pg_temp.uid('cashier2'), 'c2@050.test');

insert into public.profiles (user_id, tenant_id, role, username) values
  (pg_temp.uid('owner'),    pg_temp.tid('T'), 'superadmin', 'owner'),
  (pg_temp.uid('whclerk'),  pg_temp.tid('T'), 'warehouse',  'whclerk'),
  (pg_temp.uid('cashier1'), pg_temp.tid('T'), 'cashier',    'cashier1'),
  (pg_temp.uid('cashier2'), pg_temp.tid('T'), 'cashier',    'cashier2');

insert into public.location_access (user_id, location_id, tenant_id) values
  (pg_temp.uid('whclerk'),  pg_temp.lid('WH01'), pg_temp.tid('T')),
  (pg_temp.uid('cashier1'), pg_temp.lid('ST01'), pg_temp.tid('T')),
  (pg_temp.uid('cashier2'), pg_temp.lid('ST02'), pg_temp.tid('T'));

insert into public.products (id, tenant_id, name, unit, track_stock) values
  (md5('pos_rcv_prod:rice')::uuid, pg_temp.tid('T'), 'Jasmine Rice 5kg', 'sack', true);

insert into public.product_variants (id, tenant_id, product_id, sku, barcode, cost) values
  (pg_temp.vid('RICE'), pg_temp.tid('T'), md5('pos_rcv_prod:rice')::uuid, 'GRN-501', '4809012345678', 24000);

insert into public.variant_prices (tenant_id, variant_id, currency, price) values
  (pg_temp.tid('T'), pg_temp.vid('RICE'), 'PHP', 29500);

-- Seed 50 sacks in WH01
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid('T'), pg_temp.lid('WH01'), pg_temp.vid('RICE'), 50, 'opening', 24000);

-- 1. Warehouse clerk dispatches 12 sacks from WH01 -> ST01
select pg_temp.login('whclerk', 'warehouse', array[pg_temp.lid('WH01')]);

select public.create_transfer(
  pg_temp.lid('WH01'),
  pg_temp.lid('ST01'),
  'Morning POS restock',
  jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('RICE'), 'qty', 12)),
  true
) as id into temporary table _trf;

reset role;

select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('WH01') and variant_id = pg_temp.vid('RICE')),
  38::numeric,
  'WH01 stock decremented to 38 upon dispatch'
);

-- 2. Cashier at ST02 is denied listing ST01 incoming transfers
select pg_temp.login('cashier2', 'cashier', array[pg_temp.lid('ST02')]);

select throws_ok(
  format($$ select public.list_store_incoming_transfers(%L::uuid, true) $$, pg_temp.lid('ST01')),
  '42501',
  null,
  'Cashier assigned to ST02 cannot view ST01 incoming transfers'
);

reset role;

-- 3. Calling list_store_incoming_transfers on a warehouse ID fails validation
select pg_temp.login('whclerk', 'warehouse', array[pg_temp.lid('WH01')]);

select throws_ok(
  format($$ select public.list_store_incoming_transfers(%L::uuid, true) $$, pg_temp.lid('WH01')),
  '22023',
  null,
  'list_store_incoming_transfers rejects warehouse location IDs'
);

reset role;

-- 4. POS Cashier at ST01 lists incoming shipment and sees SKU/barcode/qty without unit_cost
select pg_temp.login('cashier1', 'cashier', array[pg_temp.lid('ST01')]);

select is(
  jsonb_array_length(public.list_store_incoming_transfers(pg_temp.lid('ST01'), false)),
  1,
  'POS cashier at ST01 sees 1 in-transit shipment from WH01'
);

select is(
  (public.list_store_incoming_transfers(pg_temp.lid('ST01'), false) -> 0 -> 'from_location' ->> 'code'),
  'WH01',
  'Incoming shipment shows origin warehouse code WH01'
);

select is(
  (public.list_store_incoming_transfers(pg_temp.lid('ST01'), false) -> 0 -> 'transfer_items' -> 0 ->> 'barcode'),
  '4809012345678',
  'Incoming shipment item includes barcode for POS scan-to-receive'
);

select is(
  (public.list_store_incoming_transfers(pg_temp.lid('ST01'), false) -> 0 -> 'transfer_items' -> 0 ? 'unit_cost'),
  false,
  'Incoming shipment item does not leak unit_cost to cashier'
);

-- 5. POS Cashier at ST01 receives the 12 sacks into POS store stock
select lives_ok(
  format(
    $$ select public.receive_transfer(%L::uuid, %L::jsonb) $$,
    (select id from _trf),
    jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('RICE'), 'qty_received', 12))
  ),
  'POS cashier at ST01 receives shipment into store inventory'
);

reset role;

select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('ST01') and variant_id = pg_temp.vid('RICE')),
  12::numeric,
  'ST01 POS stock increased to 12 immediately upon receiving'
);

select * from finish();
rollback;
