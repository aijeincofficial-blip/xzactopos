-- 054_qa01_functional_fixes.test.sql
-- Regression tests for QA-01 DB fixes:
--   F03: Multi-variant product creation, updates, warehouse cost/sku updates, and sync_pull_catalog name output
--   F04: pull_offline_pins(null) uses resolve_store (works for 1-store caller, raises location_required for multi-store)
--   F05: assert_module('pos') enforced on all POS sync_pull_* RPCs
--   F08: assert_module('warehouse'), assert_location_access, and non-cashier guards on bin, pick-list & transfer RPCs

begin;
select plan(40);

create function pg_temp.tid(p text) returns uuid language sql immutable as $$ select md5('qa01t:' || p)::uuid $$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$ select md5('qa01u:' || p)::uuid $$;
create function pg_temp.id(p text)  returns uuid language sql immutable as $$ select md5('qa01i:' || p)::uuid $$;

create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.uid(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.tid(p_tenant))::text, true);
$$;

create function pg_temp.hint(p_sql text) returns text language plpgsql as $$
declare h text; s text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics h = pg_exception_hint, s = returned_sqlstate;
  return coalesce(nullif(h, ''), s);
end;
$$;

insert into auth.users (id, email)
select pg_temp.uid(n), n || '@qa01.invalid'
from unnest(array['owner', 'cashier1', 'wh1', 'wh2', 'owner_b']) n;

insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.tid('A'), 'QA01 Tenant A', 'qa01-a', 'PHP', 'Asia/Manila'),
  (pg_temp.tid('B'), 'QA01 Tenant B', 'qa01-b', 'PHP', 'Asia/Manila');

insert into public.tenant_modules (tenant_id, inventory, pos, warehouse) values
  (pg_temp.tid('A'), true, true, true),
  (pg_temp.tid('B'), true, true, true);

insert into public.tenant_limits (tenant_id) values (pg_temp.tid('A')), (pg_temp.tid('B'));
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('A')), (pg_temp.tid('B'));

insert into public.profiles (user_id, tenant_id, username, full_name, role, active) values
  (pg_temp.uid('owner'),    pg_temp.tid('A'), 'owner',    'Owner A',     'superadmin', true),
  (pg_temp.uid('cashier1'), pg_temp.tid('A'), 'cashier1', 'Cashier One', 'cashier',    true),
  (pg_temp.uid('wh1'),      pg_temp.tid('A'), 'wh1',      'WH Clerk 1',  'warehouse',  true),
  (pg_temp.uid('wh2'),      pg_temp.tid('A'), 'wh2',      'WH Clerk 2',  'warehouse',  true),
  (pg_temp.uid('owner_b'),  pg_temp.tid('B'), 'owner_b',  'Owner B',     'superadmin', true);

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.tid('A'), 'store',     'S01', 'Store 1'),
  (pg_temp.id('S02'), pg_temp.tid('A'), 'store',     'S02', 'Store 2'),
  (pg_temp.id('W01'), pg_temp.tid('A'), 'warehouse', 'W01', 'Warehouse 1'),
  (pg_temp.id('W02'), pg_temp.tid('A'), 'warehouse', 'W02', 'Warehouse 2'),
  (pg_temp.id('WB1'), pg_temp.tid('B'), 'warehouse', 'WB1', 'Tenant B WH');

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('cashier1'), pg_temp.id('S01'), pg_temp.tid('A'), null),
  (pg_temp.uid('wh1'),      pg_temp.id('W01'), pg_temp.tid('A'), null),
  (pg_temp.uid('wh2'),      pg_temp.id('W02'), pg_temp.tid('A'), null);

select pg_temp.login('owner', 'A');
select public.set_my_pin('1234');
select pg_temp.login('cashier1', 'A');
select public.set_my_pin('1111');

-- ---------------------------------------------------------------------------
-- 1. F04: pull_offline_pins(null)
-- ---------------------------------------------------------------------------
select pg_temp.login('cashier1', 'A');
set local role authenticated;
select is(
  (select count(*) from public.pull_offline_pins(null))::int,
  1,
  'F04: pull_offline_pins(null) resolves single store S01 for approvers only (cashier excluded)'
);
reset role;

select pg_temp.login('owner', 'A');
set local role authenticated;
select is(
  pg_temp.hint('select * from public.pull_offline_pins(null)'),
  'location_required',
  'F04: multi-store superadmin calling pull_offline_pins(null) gets clean location_required hint'
);
reset role;

-- ---------------------------------------------------------------------------
-- 2. F03: Multi-variant products create, edit, omit-archive, warehouse update, sync_pull_catalog
-- ---------------------------------------------------------------------------
select pg_temp.login('owner', 'A');
set local role authenticated;

select is(
  public.upsert_product(
    pg_temp.id('op_mv_create'),
    jsonb_build_object(
      'id', pg_temp.id('p:latte'),
      'name', 'Iced Latte',
      'unit', 'cup',
      'variants', jsonb_build_array(
        jsonb_build_object('id', pg_temp.id('v:latte_reg'), 'name', 'Regular', 'sku', 'LATTE-R', 'price', 12000, 'cost', 4000, 'is_default', true),
        jsonb_build_object('id', pg_temp.id('v:latte_lrg'), 'name', 'Large',   'sku', 'LATTE-L', 'price', 15000, 'cost', 5000, 'is_default', false)
      )
    )
  ) ->> 'created',
  'true',
  'F03: upsert_product creates multi-variant product with variants array'
);

select is(
  (select count(*)::int from public.product_variants where product_id = pg_temp.id('p:latte') and deleted_at is null),
  2,
  'F03: both Regular and Large variants exist live'
);

select is(
  (select price from public.variant_prices where variant_id = pg_temp.id('v:latte_lrg') and currency = 'PHP'),
  15000::bigint,
  'F03: non-default variant Large stores its own price (15000)'
);

-- Update: switch default to Large, add XL, remove Regular
select lives_ok(
  format($$
    select public.upsert_product(
      %L,
      jsonb_build_object(
        'id', %L,
        'name', 'Iced Latte',
        'variants', jsonb_build_array(
          jsonb_build_object('id', %L, 'name', 'Large 16oz', 'sku', 'LATTE-L', 'price', 16000, 'cost', 5200, 'is_default', true),
          jsonb_build_object('id', %L, 'name', 'XL 22oz',    'sku', 'LATTE-XL', 'price', 18500, 'cost', 6000, 'is_default', false)
        )
      )
    )
  $$, pg_temp.id('op_mv_upd'), pg_temp.id('p:latte'), pg_temp.id('v:latte_lrg'), pg_temp.id('v:latte_xl')),
  'F03: update switches default variant, adds XL, and soft-deletes omitted Regular without violating default index'
);

select is(
  (select deleted_at is not null from public.product_variants where id = pg_temp.id('v:latte_reg')),
  true,
  'F03: omitted Regular variant is archived'
);

select is(
  (select is_default from public.product_variants where id = pg_temp.id('v:latte_lrg')),
  true,
  'F03: Large became the new default variant'
);

reset role;

-- Warehouse role can update SKU/cost across multiple variants, but cannot add/rename
select pg_temp.login('wh1', 'A');
set local role authenticated;
select lives_ok(
  format($$
    select public.upsert_product(
      %L,
      jsonb_build_object(
        'id', %L,
        'variants', jsonb_build_array(
          jsonb_build_object('id', %L, 'cost', 5500),
          jsonb_build_object('id', %L, 'cost', 6200, 'sku', 'LATTE-XL-2')
        )
      )
    )
  $$, pg_temp.id('op_mv_wh'), pg_temp.id('p:latte'), pg_temp.id('v:latte_lrg'), pg_temp.id('v:latte_xl')),
  'F03: warehouse role updates cost/sku across multi-variant product'
);

select is(
  pg_temp.hint(format($$
    select public.upsert_product(
      %L,
      jsonb_build_object(
        'id', %L,
        'variants', jsonb_build_array(
          jsonb_build_object('id', %L, 'name', 'Tampered')
        )
      )
    )
  $$, pg_temp.id('op_mv_wh_bad'), pg_temp.id('p:latte'), pg_temp.id('v:latte_lrg'))),
  'cost_and_sku_only',
  'F03: warehouse role cannot rename variant via variants array'
);
reset role;

-- Age catalog rows and verify sync_pull_catalog includes variant name
alter table public.products disable trigger products_set_updated_at;
alter table public.product_variants disable trigger product_variants_set_updated_at;
update public.products set updated_at = now() - interval '1 minute' where tenant_id = pg_temp.tid('A');
update public.product_variants set updated_at = now() - interval '1 minute' where tenant_id = pg_temp.tid('A');
alter table public.products enable trigger products_set_updated_at;
alter table public.product_variants enable trigger product_variants_set_updated_at;

select pg_temp.login('cashier1', 'A');
set local role authenticated;
select ok(
  exists (
    select 1
    from jsonb_array_elements(public.sync_pull_catalog('{}', 500) -> 'product_variants' -> 'rows') r
    where r ->> 'id' = pg_temp.id('v:latte_lrg')::text
      and r ->> 'name' = 'Large 16oz'
  ),
  'F03: sync_pull_catalog includes product_variants.name'
);
reset role;

-- ---------------------------------------------------------------------------
-- 3. F05: POS module guards on sync_pull_*
-- ---------------------------------------------------------------------------
update public.tenant_modules set pos = false, warehouse = true where tenant_id = pg_temp.tid('A');

select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.hint($$ select public.sync_pull_pos() $$),        'module_disabled', 'F05: sync_pull_pos refused when pos=false');
select is(pg_temp.hint($$ select public.sync_pull_sales() $$),      'module_disabled', 'F05: sync_pull_sales refused when pos=false');
select is(pg_temp.hint($$ select public.sync_pull_expenses() $$),   'module_disabled', 'F05: sync_pull_expenses refused when pos=false');
select is(pg_temp.hint($$ select public.sync_pull_day_closes() $$), 'module_disabled', 'F05: sync_pull_day_closes refused when pos=false');
select is(pg_temp.hint($$ select public.sync_pull_service() $$),    'module_disabled', 'F05: sync_pull_service refused when pos=false');
select is(pg_temp.hint($$ select public.sync_pull_shifts() $$),     'module_disabled', 'F05: sync_pull_shifts refused when pos=false');
select lives_ok($$ select public.sync_pull_catalog() $$, 'F05: sync_pull_catalog remains available when pos=false and warehouse=true');
reset role;

-- ---------------------------------------------------------------------------
-- 4. F08: Warehouse, bin, pick-list, and transfer security + module checks
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1', 'A');
set local role authenticated;
select lives_ok(format('select public.enable_warehouse_bins(%L)', pg_temp.id('W01')), 'F08 setup: wh1 enables bins on W01');
reset role;

insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid('A'), pg_temp.id('W01'), pg_temp.id('v:latte_lrg'), 20, 'receipt', 5200);

select pg_temp.login('wh1', 'A');
set local role authenticated;
select public.create_transfer(
  pg_temp.id('W01'),
  pg_temp.id('S01'),
  'W01->S01',
  jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:latte_lrg'), 'qty', 5)),
  false
) as id into temp table pg_temp.trf_w1;
select public.generate_pick_list((select id from pg_temp.trf_w1)) as id into temp table pg_temp.pck_w1;
reset role;

select id into temp table pg_temp.w1_rcv_bin from public.bins where warehouse_id = pg_temp.id('W01') and code = 'RECEIVING' limit 1;
grant select on pg_temp.w1_rcv_bin to authenticated;

-- Cross-warehouse & cashier & cross-tenant access checks
select pg_temp.login('wh2', 'A');
set local role authenticated;
select is(pg_temp.hint(format('select * from public.check_bin_stock_invariant(%L)', pg_temp.id('W01'))), 'location_denied',
  'F08: wh2 (W02) cannot inspect W01 bin stock invariant');
select is(pg_temp.hint(format('select * from public.list_warehouse_bins(%L)', pg_temp.id('W01'))), 'location_denied',
  'F08: wh2 (W02) cannot list W01 bins');
select is(pg_temp.hint(format('select * from public.list_bin_stock(%L)', (select id from pg_temp.w1_rcv_bin))), 'location_denied',
  'F08: wh2 (W02) cannot list W01 bin stock');
select is(pg_temp.hint(format('select public.get_pick_list_for_transfer(%L)', (select id from pg_temp.trf_w1))), 'location_denied',
  'F08: wh2 (W02) cannot view pick list for W01 transfer');
reset role;

select pg_temp.login('cashier1', 'A');
set local role authenticated;
select is(pg_temp.hint(format('select * from public.list_warehouse_bins(%L)', pg_temp.id('W01'))), 'not_allowed',
  'F08: cashier cannot call list_warehouse_bins');
select is(pg_temp.hint(format('select public.confirm_pick_item(%L, %L, 0)',
  (select id from pg_temp.pck_w1),
  (select id from public.pick_list_items where pick_list_id = (select id from pg_temp.pck_w1) limit 1))), 'not_allowed',
  'F08: cashier cannot confirm_pick_item even with qty=0');
select is(pg_temp.hint(format('select public.ship_transfer(%L)', (select id from pg_temp.trf_w1))), 'not_allowed',
  'F08: cashier cannot ship_transfer');
select is(pg_temp.hint(format('select public.cancel_transfer(%L)', (select id from pg_temp.trf_w1))), 'not_allowed',
  'F08: cashier cannot cancel_transfer');
reset role;

select pg_temp.login('owner_b', 'B');
set local role authenticated;
select is(
  (select count(*)::int from public.list_bin_stock((select id from pg_temp.w1_rcv_bin))),
  0,
  'F08: cross-tenant list_bin_stock returns 0 rows'
);
select is(
  public.get_pick_list_for_transfer((select id from pg_temp.trf_w1)),
  null,
  'F08: cross-tenant get_pick_list_for_transfer returns null'
);
reset role;

-- F10: list_transfer_destinations returns active tenant destinations to warehouse clerks
-- without loosening public.locations SELECT RLS, rejects cashiers, and isolates tenants.
select pg_temp.login('wh1', 'A');
set local role authenticated;
select is(
  (select count(*)::int from public.list_transfer_destinations()),
  4,
  'F10: warehouse clerk sees all 4 active Tenant A locations via list_transfer_destinations'
);
select is(
  (select count(*)::int from public.list_transfer_destinations() d where d.id = pg_temp.id('WB1')),
  0,
  'F10: Tenant B destinations are excluded for Tenant A caller'
);
reset role;

select pg_temp.login('cashier1', 'A');
set local role authenticated;
select is(pg_temp.hint('select * from public.list_transfer_destinations()'), 'not_allowed',
  'F10: cashier cannot call list_transfer_destinations');
reset role;

select pg_temp.login('owner_b', 'B');
set local role authenticated;
select is(
  (select count(*)::int from public.list_transfer_destinations()),
  1,
  'F10: Tenant B caller sees only Tenant B destinations'
);
reset role;

-- Warehouse module disabled blocks bin/picklist/warehouse transfers while allowing store-to-store transfers
update public.tenant_modules set pos = true, warehouse = false where tenant_id = pg_temp.tid('A');

select pg_temp.login('owner', 'A');
set local role authenticated;
select is(
  (select count(*)::int from public.list_transfer_destinations()),
  2,
  'F10: list_transfer_destinations excludes warehouses when warehouse=false'
);
select is(pg_temp.hint(format('select public.enable_warehouse_bins(%L)', pg_temp.id('W02'))), 'module_disabled',
  'F08: enable_warehouse_bins refused when warehouse=false');
select is(pg_temp.hint(format('select * from public.list_warehouse_bins(%L)', pg_temp.id('W01'))), 'module_disabled',
  'F08: list_warehouse_bins refused when warehouse=false');
select is(pg_temp.hint(format('select * from public.check_bin_stock_invariant(%L)', pg_temp.id('W01'))), 'module_disabled',
  'F08: check_bin_stock_invariant refused when warehouse=false');
select is(pg_temp.hint(format('select public.get_pick_list_for_transfer(%L)', (select id from pg_temp.trf_w1))), 'module_disabled',
  'F08: get_pick_list_for_transfer refused when warehouse=false');
select is(pg_temp.hint(format($$
  select public.create_transfer(%L, %L, 'blocked', jsonb_build_array(jsonb_build_object('variant_id', %L, 'qty', 1)))
$$, pg_temp.id('W01'), pg_temp.id('S01'), pg_temp.id('v:latte_lrg'))), 'module_disabled',
  'F08: warehouse create_transfer refused when warehouse=false');
select lives_ok(format($$
  select public.create_transfer(%L, %L, 'inter-store', jsonb_build_array(jsonb_build_object('variant_id', %L, 'qty', 1)), false)
$$, pg_temp.id('S01'), pg_temp.id('S02'), pg_temp.id('v:latte_lrg')),
  'F08: inter-store transfer remains allowed when pos=true and warehouse=false');
reset role;

select * from finish();
rollback;
