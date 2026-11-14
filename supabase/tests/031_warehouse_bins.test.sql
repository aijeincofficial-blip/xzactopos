-- 031_warehouse_bins.test.sql: pgTAP tests for F-09 warehouse bins, zones, put-away, and pick lists

begin;
select plan(30);

-- ---------------------------------------------------------------------------
-- Setup Fixtures
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p_tenant text) returns uuid language sql immutable
  as $$ select md5('tenant:' || p_tenant)::uuid $$;
create function pg_temp.uid(p_tenant text, p_user text) returns uuid language sql immutable
  as $$ select md5('user:' || p_tenant || ':' || p_user)::uuid $$;
create function pg_temp.lid(p_tenant text, p_code text) returns uuid language sql immutable
  as $$ select md5('loc:' || p_tenant || ':' || p_code)::uuid $$;

-- Tenant X
insert into public.tenants (id, name, slug, base_currency)
  values (pg_temp.tid('X'), 'Bins Tenant', 'bins-tenant', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse)
  values (pg_temp.tid('X'), true, true);
insert into public.tenant_settings (tenant_id)
  values (pg_temp.tid('X'));

-- Users in Tenant X
insert into auth.users (id, email) values
  (pg_temp.uid('X', 'owner'), 'owner@bins.invalid'),
  (pg_temp.uid('X', 'pedro'), 'pedro@bins.invalid'),
  (pg_temp.uid('X', 'maria'), 'maria@bins.invalid'),
  (pg_temp.uid('X', 'juan'), 'juan@bins.invalid');

insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('X', 'owner'), pg_temp.tid('X'), 'owner', 'superadmin', true),
  (pg_temp.uid('X', 'pedro'), pg_temp.tid('X'), 'pedro', 'warehouse', true),
  (pg_temp.uid('X', 'maria'), pg_temp.tid('X'), 'maria', 'admin', true),
  (pg_temp.uid('X', 'juan'), pg_temp.tid('X'), 'juan', 'cashier', true);

-- Locations: WH01 (warehouse), ST01 (store)
insert into public.locations (id, tenant_id, type, code, name, bins_enabled) values
  (pg_temp.lid('X', 'WH01'), pg_temp.tid('X'), 'warehouse', 'WH01', 'Central Bins Warehouse', false),
  (pg_temp.lid('X', 'ST01'), pg_temp.tid('X'), 'store', 'ST01', 'Store One', false);

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('X', 'pedro'), pg_temp.lid('X', 'WH01'), pg_temp.tid('X'), null),
  (pg_temp.uid('X', 'maria'), pg_temp.lid('X', 'ST01'), pg_temp.tid('X'), 'manager'),
  (pg_temp.uid('X', 'juan'), pg_temp.lid('X', 'ST01'), pg_temp.tid('X'), null);

-- Product and variant
insert into public.products (id, tenant_id, name) values
  (md5('p:1')::uuid, pg_temp.tid('X'), 'Rice 25kg');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (md5('v:1')::uuid, pg_temp.tid('X'), md5('p:1')::uuid, 'RICE-25KG', true);
insert into public.variant_prices (tenant_id, variant_id, currency, price) values
  (pg_temp.tid('X'), md5('v:1')::uuid, 'PHP', 150000);

-- Opening stock at WH01: 100 sacks
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid('X'), pg_temp.lid('X', 'WH01'), md5('v:1')::uuid, 100, 'receipt', 120000);

create function pg_temp.login(p_tenant text, p_user text) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', pg_temp.uid(p_tenant, p_user), 'role', 'authenticated', 'tenant_id', pg_temp.tid(p_tenant))::text,
    true);
$$;

-- ---------------------------------------------------------------------------
-- 1. Enable Bins & Validations
-- ---------------------------------------------------------------------------

-- Store ST01 cannot enable bins
select pg_temp.login('X', 'owner');
select throws_matching(
  $$ select public.enable_warehouse_bins(pg_temp.lid('X', 'ST01')) $$,
  'only warehouses can enable bins',
  'store cannot enable bins'
);

-- Cashier juan cannot enable bins
select pg_temp.login('X', 'juan');
select throws_matching(
  $$ select public.enable_warehouse_bins(pg_temp.lid('X', 'WH01')) $$,
  'only managers or warehouse staff can manage warehouse bins',
  'cashier cannot enable bins'
);

-- Pedro (warehouse staff assigned to WH01) enables bins
select pg_temp.login('X', 'pedro');
select lives_ok(
  $$ select public.enable_warehouse_bins(pg_temp.lid('X', 'WH01')) $$,
  'warehouse staff enables bins on WH01'
);

select is(
  (select bins_enabled from public.locations where id = pg_temp.lid('X', 'WH01')),
  true,
  'WH01 has bins_enabled = true'
);

-- Default zones created
select is(
  (select count(*)::int from public.warehouse_zones where warehouse_id = pg_temp.lid('X', 'WH01') and code in ('RCV', 'STG', 'GEN')),
  3,
  'default zones (RCV, STG, GEN) created'
);

-- Default bins created
select is(
  (select count(*)::int from public.bins where warehouse_id = pg_temp.lid('X', 'WH01') and code in ('RECEIVING', 'STAGING', 'A-01-1')),
  3,
  'default bins (RECEIVING, STAGING, A-01-1) created'
);

-- Existing 100 units seeded into RECEIVING bin
select is(
  (select bsl.qty_on_hand
   from public.bin_stock_levels bsl
   join public.bins b on b.id = bsl.bin_id
   where b.warehouse_id = pg_temp.lid('X', 'WH01') and b.code = 'RECEIVING' and bsl.variant_id = md5('v:1')::uuid),
  100::numeric,
  'existing stock seeded into RECEIVING bin'
);

-- Invariant holds: check_bin_stock_invariant
select is(
  (select is_valid from public.check_bin_stock_invariant(pg_temp.lid('X', 'WH01')) where variant_id = md5('v:1')::uuid),
  true,
  'initial bin stock invariant holds'
);

-- ---------------------------------------------------------------------------
-- 2. Zone and Bin CRUD
-- ---------------------------------------------------------------------------

-- Cashier cannot create zone
select pg_temp.login('X', 'juan');
select throws_matching(
  $$ select public.upsert_warehouse_zone(pg_temp.lid('X', 'WH01'), 'COLD', 'Cold Storage', 'storage') $$,
  'only managers or warehouse staff can manage warehouse zones',
  'cashier cannot create zone'
);

-- Warehouse staff creates COLD zone
select pg_temp.login('X', 'pedro');
select lives_ok(
  $$ select public.upsert_warehouse_zone(pg_temp.lid('X', 'WH01'), 'COLD', 'Cold Storage', 'storage') $$,
  'warehouse staff creates COLD zone'
);

-- Warehouse staff creates bin C-01-1
select lives_ok(
  $$
    select public.upsert_warehouse_bin(
      pg_temp.lid('X', 'WH01'),
      'C-01-1',
      (select id from public.warehouse_zones where warehouse_id = pg_temp.lid('X', 'WH01') and code = 'COLD'),
      'C', '01', '1', '1', 'shelf', 50
    )
  $$,
  'warehouse staff creates C-01-1 bin'
);

-- Duplicate bin code fails
select throws_matching(
  $$
    select public.upsert_warehouse_bin(
      pg_temp.lid('X', 'WH01'),
      'C-01-1',
      null, 'C', '01', '1', '1', 'shelf', 50
    )
  $$,
  'duplicate key value violates unique constraint',
  'duplicate bin code in same warehouse fails'
);

-- list_warehouse_bins returns bins
select is(
  (select count(*)::int from public.list_warehouse_bins(pg_temp.lid('X', 'WH01'))),
  4,
  'list_warehouse_bins returns all 4 bins'
);

-- ---------------------------------------------------------------------------
-- 3. Put-away Movement (from RECEIVING to A-01-1)
-- ---------------------------------------------------------------------------

select lives_ok(
  $$
    select public.execute_putaway(
      pg_temp.lid('X', 'WH01'),
      (select id from public.bins where warehouse_id = pg_temp.lid('X', 'WH01') and code = 'RECEIVING'),
      (select id from public.bins where warehouse_id = pg_temp.lid('X', 'WH01') and code = 'A-01-1'),
      md5('v:1')::uuid,
      40
    )
  $$,
  'put-away moves 40 units from RECEIVING to A-01-1'
);

select is(
  (select bsl.qty_on_hand from public.bin_stock_levels bsl join public.bins b on b.id = bsl.bin_id where b.code = 'RECEIVING' and b.warehouse_id = pg_temp.lid('X', 'WH01')),
  60::numeric,
  'RECEIVING bin has 60 left'
);

select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('X', 'WH01') and variant_id = md5('v:1')::uuid),
  100::numeric,
  'total warehouse stock remains exactly 100'
);

select is(
  (select is_valid from public.check_bin_stock_invariant(pg_temp.lid('X', 'WH01')) where variant_id = md5('v:1')::uuid),
  true,
  'invariant holds after put-away'
);

-- Over-moving from bin fails with insufficient_bin_stock
select throws_matching(
  $$
    select public.move_bin_stock(
      pg_temp.lid('X', 'WH01'),
      (select id from public.bins where warehouse_id = pg_temp.lid('X', 'WH01') and code = 'A-01-1'),
      (select id from public.bins where warehouse_id = pg_temp.lid('X', 'WH01') and code = 'RECEIVING'),
      md5('v:1')::uuid,
      50
    )
  $$,
  'insufficient stock in source bin',
  'over-moving from bin fails'
);

-- ---------------------------------------------------------------------------
-- 4. Pick List Allocation & Item Pick Confirmation
-- ---------------------------------------------------------------------------

-- Create draft transfer from WH01 to ST01 for 30 units
select pg_temp.login('X', 'pedro');

select lives_ok(
  $$
    select public.create_transfer(
      pg_temp.lid('X', 'WH01'),
      pg_temp.lid('X', 'ST01'),
      'Store replenishment',
      jsonb_build_array(jsonb_build_object('variant_id', md5('v:1')::uuid, 'qty', 30)),
      false
    )
  $$,
  'draft transfer created'
);

-- Generate pick list for the transfer
select is(
  (select count(*)::int
   from public.pick_list_items pli
   join public.pick_lists pl on pl.id = pli.pick_list_id
   where pl.warehouse_id = pg_temp.lid('X', 'WH01')),
  0,
  'no pick list items before generation'
);

do $$
declare
  v_trf_id uuid;
  v_pck_id uuid;
begin
  select id into v_trf_id from public.transfers where from_location_id = pg_temp.lid('X', 'WH01') and status = 'draft' limit 1;
  v_pck_id := public.generate_pick_list(v_trf_id);
end;
$$;

-- Confirm pick item: picker picks 30 from A-01-1 to STAGING
do $$
declare
  v_pck_id uuid;
  v_item_id uuid;
begin
  select id into v_pck_id from public.pick_lists where warehouse_id = pg_temp.lid('X', 'WH01') and status = 'pending' limit 1;
  select id into v_item_id from public.pick_list_items where pick_list_id = v_pck_id limit 1;
  perform public.confirm_pick_item(v_pck_id, v_item_id, 30);
end;
$$;

select is(
  (select status from public.pick_lists where warehouse_id = pg_temp.lid('X', 'WH01') limit 1),
  'completed',
  'pick list status is completed after all items picked'
);

select is(
  (select bsl.qty_on_hand from public.bin_stock_levels bsl join public.bins b on b.id = bsl.bin_id where b.code = 'STAGING' and b.warehouse_id = pg_temp.lid('X', 'WH01')),
  30::numeric,
  'STAGING bin received 30 picked units'
);

select is(
  (select is_valid from public.check_bin_stock_invariant(pg_temp.lid('X', 'WH01')) where variant_id = md5('v:1')::uuid),
  true,
  'invariant holds after picking to STAGING'
);

-- ---------------------------------------------------------------------------
-- 5. Shipping Transfer Deducts from STAGING & Preserves Invariant
-- ---------------------------------------------------------------------------

do $$
declare
  v_trf_id uuid;
begin
  select id into v_trf_id from public.transfers where from_location_id = pg_temp.lid('X', 'WH01') and status = 'draft' limit 1;
  perform public.ship_transfer(v_trf_id);
end;
$$;

select is(
  (select bsl.qty_on_hand from public.bin_stock_levels bsl join public.bins b on b.id = bsl.bin_id where b.code = 'STAGING' and b.warehouse_id = pg_temp.lid('X', 'WH01')),
  0::numeric,
  'STAGING bin deducted to 0 upon transfer ship'
);

select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('X', 'WH01') and variant_id = md5('v:1')::uuid),
  70::numeric,
  'warehouse total reduced from 100 to 70 upon ship'
);

select is(
  (select is_valid from public.check_bin_stock_invariant(pg_temp.lid('X', 'WH01')) where variant_id = md5('v:1')::uuid),
  true,
  'invariant holds after shipping transfer (warehouse = 70, bins = 70)'
);

-- ---------------------------------------------------------------------------
-- 6. Receipt without bin_id automatically lands in RECEIVING
-- ---------------------------------------------------------------------------

insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost)
values (pg_temp.tid('X'), pg_temp.lid('X', 'WH01'), md5('v:1')::uuid, 50, 'receipt', 120000);

select is(
  (select bsl.qty_on_hand from public.bin_stock_levels bsl join public.bins b on b.id = bsl.bin_id where b.code = 'RECEIVING' and b.warehouse_id = pg_temp.lid('X', 'WH01')),
  110::numeric, -- 60 remaining + 50 new
  'receipt lands in RECEIVING bin automatically'
);

select is(
  (select is_valid from public.check_bin_stock_invariant(pg_temp.lid('X', 'WH01')) where variant_id = md5('v:1')::uuid),
  true,
  'invariant holds after new receipt (warehouse = 120, bins = 120)'
);

-- ---------------------------------------------------------------------------
-- 7. Tenant Isolation & Permissions
-- ---------------------------------------------------------------------------

-- Setup Tenant Y
insert into public.tenants (id, name, slug, base_currency)
  values (pg_temp.tid('Y'), 'Other Tenant', 'other-tenant', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse)
  values (pg_temp.tid('Y'), true, true);
insert into auth.users (id, email) values (pg_temp.uid('Y', 'user_y'), 'y@bins.invalid');
insert into public.profiles (user_id, tenant_id, username, role, active)
  values (pg_temp.uid('Y', 'user_y'), pg_temp.tid('Y'), 'user_y', 'warehouse', true);

select pg_temp.login('Y', 'user_y');
set local role authenticated;

select is(
  (select count(*)::int from public.bins where warehouse_id = pg_temp.lid('X', 'WH01')),
  0,
  'Tenant Y cannot see Tenant X bins'
);
reset role;

-- Cashier juan cannot query warehouse_zones
select pg_temp.login('X', 'juan');
set local role authenticated;
select is(
  (select count(*)::int from public.warehouse_zones where warehouse_id = pg_temp.lid('X', 'WH01')),
  0,
  'cashier cannot see warehouse zones'
);
reset role;

select * from finish();
rollback;
