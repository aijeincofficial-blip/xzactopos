-- 027_transfers.test.sql: pgTAP tests for F-08 stock transfers

begin;
select plan(25);

-- ---------------------------------------------------------------------------
-- Setup Fixtures
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p_tenant text) returns uuid language sql immutable
  as $$ select md5('tenant:' || p_tenant)::uuid $$;
create function pg_temp.uid(p_tenant text, p_user text) returns uuid language sql immutable
  as $$ select md5('user:' || p_tenant || ':' || p_user)::uuid $$;
create function pg_temp.lid(p_tenant text, p_code text) returns uuid language sql immutable
  as $$ select md5('loc:' || p_tenant || ':' || p_code)::uuid $$;

insert into public.tenants (id, name, slug, base_currency)
  values (pg_temp.tid('X'), 'Transfer Tenant', 'transfer-tenant', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse)
  values (pg_temp.tid('X'), true, true);
insert into public.tenant_settings (tenant_id)
  values (pg_temp.tid('X'));

-- Users: owner (superadmin), pedro (warehouse), maria (admin/manager), juan (cashier)
insert into auth.users (id, email) values
  (pg_temp.uid('X', 'owner'), 'owner@transfer.invalid'),
  (pg_temp.uid('X', 'pedro'), 'pedro@transfer.invalid'),
  (pg_temp.uid('X', 'maria'), 'maria@transfer.invalid'),
  (pg_temp.uid('X', 'juan'), 'juan@transfer.invalid');

insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('X', 'owner'), pg_temp.tid('X'), 'owner', 'superadmin', true),
  (pg_temp.uid('X', 'pedro'), pg_temp.tid('X'), 'pedro', 'warehouse', true),
  (pg_temp.uid('X', 'maria'), pg_temp.tid('X'), 'maria', 'admin', true),
  (pg_temp.uid('X', 'juan'), pg_temp.tid('X'), 'juan', 'cashier', true);

-- Locations: WH01 (warehouse), ST01 (store 1), ST02 (store 2)
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.lid('X', 'WH01'), pg_temp.tid('X'), 'warehouse', 'WH01', 'Central Warehouse'),
  (pg_temp.lid('X', 'ST01'), pg_temp.tid('X'), 'store', 'ST01', 'Store One'),
  (pg_temp.lid('X', 'ST02'), pg_temp.tid('X'), 'store', 'ST02', 'Store Two');

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('X', 'pedro'), pg_temp.lid('X', 'WH01'), pg_temp.tid('X'), null),
  (pg_temp.uid('X', 'maria'), pg_temp.lid('X', 'ST01'), pg_temp.tid('X'), 'manager'),
  (pg_temp.uid('X', 'maria'), pg_temp.lid('X', 'ST02'), pg_temp.tid('X'), 'manager'),
  (pg_temp.uid('X', 'juan'), pg_temp.lid('X', 'ST01'), pg_temp.tid('X'), null);

-- Product and variant
insert into public.products (id, tenant_id, name) values
  (md5('p:1')::uuid, pg_temp.tid('X'), 'Rice 25kg');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (md5('v:1')::uuid, pg_temp.tid('X'), md5('p:1')::uuid, 'RICE-25KG', true);

-- Opening stock at WH01: 100 sacks at 1200 PHP (120000 centavos)
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid('X'), pg_temp.lid('X', 'WH01'), md5('v:1')::uuid, 100, 'receipt', 120000);

create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', pg_temp.uid('X', p_user), 'role', 'authenticated', 'tenant_id', pg_temp.tid('X'))::text,
    true);
$$;

-- ---------------------------------------------------------------------------
-- 1. Permissions & Validations
-- ---------------------------------------------------------------------------

-- Cashier juan cannot create a transfer
select pg_temp.login('juan');
set local role authenticated;
select throws_ok(
  $$ select public.create_transfer(
       pg_temp.lid('X', 'ST01'),
       pg_temp.lid('X', 'ST02'),
       'test notes'::text,
       jsonb_build_array(jsonb_build_object('variant_id', md5('v:1')::uuid, 'qty', 5))
     ) $$,
  '42501', null,
  'cashier cannot create transfer'
);
reset role;

-- Cannot transfer to same location
select pg_temp.login('owner');
set local role authenticated;
select throws_ok(
  $$ select public.create_transfer(
       pg_temp.lid('X', 'WH01'),
       pg_temp.lid('X', 'WH01'),
       'self transfer'::text,
       jsonb_build_array(jsonb_build_object('variant_id', md5('v:1')::uuid, 'qty', 5))
     ) $$,
  '22023', null,
  'cannot transfer to same location'
);
reset role;

-- Warehouse staff pedro cannot transfer from a store he has no access to
select pg_temp.login('pedro');
set local role authenticated;
select throws_ok(
  $$ select public.create_transfer(
       pg_temp.lid('X', 'ST01'),
       pg_temp.lid('X', 'WH01'),
       'store transfer'::text,
       jsonb_build_array(jsonb_build_object('variant_id', md5('v:1')::uuid, 'qty', 5))
     ) $$,
  '42501', null,
  'warehouse staff cannot transfer from unassigned store'
);
reset role;

-- ---------------------------------------------------------------------------
-- 2. Create Draft Transfer and Cancel
-- ---------------------------------------------------------------------------
select pg_temp.login('pedro');
set local role authenticated;

create temp table pg_temp.draft_holder as
select public.create_transfer(
  pg_temp.lid('X', 'WH01'),
  pg_temp.lid('X', 'ST01'),
  'Initial shipment draft',
  jsonb_build_array(jsonb_build_object('variant_id', md5('v:1')::uuid, 'qty', 10)),
  false
) as transfer_id;

select is(
  (select status from public.transfers where id = (select transfer_id from pg_temp.draft_holder)),
  'draft',
  'created transfer is in draft status'
);

select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('X', 'WH01') and variant_id = md5('v:1')::uuid),
  100::numeric,
  'draft does not deduct stock'
);

-- Cancel draft
select is(
  public.cancel_transfer((select transfer_id from pg_temp.draft_holder), 'No longer needed'),
  (select transfer_id from pg_temp.draft_holder),
  'cancel_transfer returns transfer_id'
);

select is(
  (select status from public.transfers where id = (select transfer_id from pg_temp.draft_holder)),
  'cancelled',
  'transfer status changed to cancelled'
);

reset role;

-- ---------------------------------------------------------------------------
-- 3. End-to-End Transfer: Create -> Ship -> Receive with Discrepancy
-- ---------------------------------------------------------------------------

-- Pedro creates draft transfer of 20 sacks from WH01 to ST01
select pg_temp.login('pedro');
set local role authenticated;

create temp table pg_temp.active_holder as
select public.create_transfer(
  pg_temp.lid('X', 'WH01'),
  pg_temp.lid('X', 'ST01'),
  'Restock Store 1',
  jsonb_build_array(jsonb_build_object('variant_id', md5('v:1')::uuid, 'qty', 20)),
  false
) as transfer_id;

select is(
  (select status from public.transfers where id = (select transfer_id from pg_temp.active_holder)),
  'draft',
  'active transfer created as draft'
);

-- Pedro ships transfer
select is(
  public.ship_transfer((select transfer_id from pg_temp.active_holder)),
  (select transfer_id from pg_temp.active_holder),
  'ship_transfer returns transfer_id'
);

select is(
  (select status from public.transfers where id = (select transfer_id from pg_temp.active_holder)),
  'shipped',
  'status is now shipped'
);

-- WH01 stock should now be 80
select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('X', 'WH01') and variant_id = md5('v:1')::uuid),
  80::numeric,
  'origin stock deducted by 20 on ship'
);

-- ST01 stock is still 0 (in-transit)
select is(
  (select coalesce(qty_on_hand, 0) from public.stock_levels where location_id = pg_temp.lid('X', 'ST01') and variant_id = md5('v:1')::uuid),
  null,
  'destination stock not added yet while in-transit'
);

-- Cannot cancel after shipped
select throws_ok(
  $$ select public.cancel_transfer((select transfer_id from pg_temp.active_holder), 'Too late') $$,
  '22023', null,
  'cannot cancel shipped transfer'
);

reset role;

-- Maria (Store 1 manager) receives transfer at ST01 with discrepancy (18 counted instead of 20)
select pg_temp.login('maria');
set local role authenticated;

select is(
  public.receive_transfer(
    (select transfer_id from pg_temp.active_holder),
    jsonb_build_array(jsonb_build_object('variant_id', md5('v:1')::uuid, 'qty_received', 18))
  ),
  (select transfer_id from pg_temp.active_holder),
  'receive_transfer returns transfer_id'
);

select is(
  (select status from public.transfers where id = (select transfer_id from pg_temp.active_holder)),
  'received',
  'status changed to received'
);

select is(
  (select has_discrepancy from public.transfers where id = (select transfer_id from pg_temp.active_holder)),
  true,
  'has_discrepancy flagged as true'
);

select is(
  (select qty_received from public.transfer_items where transfer_id = (select transfer_id from pg_temp.active_holder) and variant_id = md5('v:1')::uuid),
  18::numeric,
  'qty_received is 18'
);

-- Destination stock at ST01 is now 18
select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('X', 'ST01') and variant_id = md5('v:1')::uuid),
  18::numeric,
  'destination received 18 sacks'
);

-- Destination average cost is 120000 centavos
select is(
  (select avg_cost from public.stock_levels where location_id = pg_temp.lid('X', 'ST01') and variant_id = md5('v:1')::uuid),
  120000::bigint,
  'destination inherited origin average cost'
);

reset role;

-- ---------------------------------------------------------------------------
-- 4. Direct Ship Transfer (p_ship_now = true)
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;

create temp table pg_temp.direct_holder as
select public.create_transfer(
  pg_temp.lid('X', 'ST01'),
  pg_temp.lid('X', 'ST02'),
  'Inter-store transfer Store 1 to Store 2',
  jsonb_build_array(jsonb_build_object('variant_id', md5('v:1')::uuid, 'qty', 5)),
  true
) as transfer_id;

select is(
  (select status from public.transfers where id = (select transfer_id from pg_temp.direct_holder)),
  'shipped',
  'create_transfer with ship_now created directly in shipped status'
);

-- ST01 stock reduced from 18 to 13
select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('X', 'ST01') and variant_id = md5('v:1')::uuid),
  13::numeric,
  'origin stock deducted on direct ship'
);

-- Receive in full at ST02
select is(
  public.receive_transfer(
    (select transfer_id from pg_temp.direct_holder),
    jsonb_build_array(jsonb_build_object('variant_id', md5('v:1')::uuid, 'qty_received', 5))
  ),
  (select transfer_id from pg_temp.direct_holder),
  'receive_transfer direct transfer succeeded'
);

select is(
  (select has_discrepancy from public.transfers where id = (select transfer_id from pg_temp.direct_holder)),
  false,
  'full receipt has no discrepancy'
);

-- ST02 stock is now 5
select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('X', 'ST02') and variant_id = md5('v:1')::uuid),
  5::numeric,
  'ST02 stock is 5'
);

select is(
  (select avg_cost from public.stock_levels where location_id = pg_temp.lid('X', 'ST02') and variant_id = md5('v:1')::uuid),
  120000::bigint,
  'ST02 stock avg_cost is 120000'
);

reset role;

select * from finish();
rollback;
