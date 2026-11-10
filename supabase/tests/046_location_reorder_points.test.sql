-- 046_location_reorder_points.test.sql: Per-warehouse reorder point thresholds & overrides
begin;
select plan(21);

-- Fixture helpers
create function pg_temp.tid(p text) returns uuid language sql immutable
  as $$ select md5('tenant:' || p)::uuid $$;

create function pg_temp.uid(p_tenant text, p_user text) returns uuid language sql immutable
  as $$ select md5('user:' || p_tenant || ':' || p_user)::uuid $$;

create function pg_temp.lid(p_tenant text, p_code text) returns uuid language sql immutable
  as $$ select md5('loc:' || p_tenant || ':' || p_code)::uuid $$;

create function pg_temp.vid(p_tenant text, p_sku text) returns uuid language sql immutable
  as $$ select md5('var:' || p_tenant || ':' || p_sku)::uuid $$;

create function pg_temp.login(p_tenant text, p_user text, p_role text, p_locations uuid[] default '{}') returns void language plpgsql as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', pg_temp.uid(p_tenant, p_user),
      'role', 'authenticated',
      'tenant_id', pg_temp.tid(p_tenant),
      'user_role', p_role,
      'location_ids', to_jsonb(p_locations)
    )::text,
    true
  );
end;
$$;

-- Setup two tenants (A and B) with warehouses, variants, and stock
insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.tid('A'), 'Tenant A', 'tenant-a', 'PHP'),
  (pg_temp.tid('B'), 'Tenant B', 'tenant-b', 'PHP');

insert into public.locations (id, tenant_id, code, name, type) values
  (pg_temp.lid('A', 'W1'), pg_temp.tid('A'), 'W1', 'Warehouse 1', 'warehouse'),
  (pg_temp.lid('A', 'W2'), pg_temp.tid('A'), 'W2', 'Warehouse 2', 'warehouse'),
  (pg_temp.lid('B', 'W1'), pg_temp.tid('B'), 'W1', 'Tenant B Warehouse', 'warehouse');

insert into public.products (id, tenant_id, name) values
  (md5('p:A:rice')::uuid, pg_temp.tid('A'), 'Jasmine Rice 25kg'),
  (md5('p:A:sugar')::uuid, pg_temp.tid('A'), 'White Sugar 50kg'),
  (md5('p:B:rice')::uuid, pg_temp.tid('B'), 'Tenant B Rice');

-- Variant 1: Jasmine Rice (default reorder point = 50)
-- Variant 2: White Sugar (default reorder point = 0)
insert into public.product_variants (id, tenant_id, product_id, sku, reorder_point) values
  (pg_temp.vid('A', 'RICE25'), pg_temp.tid('A'), md5('p:A:rice')::uuid, 'RICE25', 50),
  (pg_temp.vid('A', 'SUGAR50'), pg_temp.tid('A'), md5('p:A:sugar')::uuid, 'SUGAR50', 0),
  (pg_temp.vid('B', 'RICE25'), pg_temp.tid('B'), md5('p:B:rice')::uuid, 'RICE25', 40);

-- Stock levels:
-- Tenant A W1: RICE25 has 40 on hand (below default 50)
-- Tenant A W2: RICE25 has 40 on hand (below default 50)
-- Tenant A W1: SUGAR50 has 10 on hand (default reorder point is 0 -> not low by default)
-- Tenant B W1: RICE25 has 30 on hand (below default 40)
insert into public.stock_levels (tenant_id, location_id, variant_id, qty_on_hand) values
  (pg_temp.tid('A'), pg_temp.lid('A', 'W1'), pg_temp.vid('A', 'RICE25'), 40),
  (pg_temp.tid('A'), pg_temp.lid('A', 'W2'), pg_temp.vid('A', 'RICE25'), 40),
  (pg_temp.tid('A'), pg_temp.lid('A', 'W1'), pg_temp.vid('A', 'SUGAR50'), 10),
  (pg_temp.tid('B'), pg_temp.lid('B', 'W1'), pg_temp.vid('B', 'RICE25'), 30);

-- Profiles for RBAC testing
insert into auth.users (id, email) values
  (pg_temp.uid('A', 'owner'), 'ownerA@test.invalid'),
  (pg_temp.uid('A', 'clerk1'), 'clerk1A@test.invalid'),
  (pg_temp.uid('A', 'clerk2'), 'clerk2A@test.invalid'),
  (pg_temp.uid('A', 'cashier'), 'cashierA@test.invalid'),
  (pg_temp.uid('B', 'owner'), 'ownerB@test.invalid');

insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('A', 'owner'), pg_temp.tid('A'), 'owner', 'superadmin', true),
  (pg_temp.uid('A', 'clerk1'), pg_temp.tid('A'), 'clerk1', 'warehouse', true),
  (pg_temp.uid('A', 'clerk2'), pg_temp.tid('A'), 'clerk2', 'warehouse', true),
  (pg_temp.uid('A', 'cashier'), pg_temp.tid('A'), 'cashier', 'cashier', true),
  (pg_temp.uid('B', 'owner'), pg_temp.tid('B'), 'owner_b', 'superadmin', true);

insert into public.location_access (tenant_id, user_id, location_id) values
  (pg_temp.tid('A'), pg_temp.uid('A', 'clerk1'), pg_temp.lid('A', 'W1')),
  (pg_temp.tid('A'), pg_temp.uid('A', 'clerk2'), pg_temp.lid('A', 'W2'));

-- ---------------------------------------------------------------------------
-- 1. Default variant reorder points
-- ---------------------------------------------------------------------------
select pg_temp.login('A', 'owner', 'superadmin');
set local role authenticated;

select is(
  (select count(*)::int from public.warehouse_reorder_list()),
  2,
  'both W1 and W2 rice lines appear because qty (40) <= default reorder_point (50)'
);

select ok(
  (select not is_override and reorder_point = 50 and shortfall = 10
   from public.warehouse_reorder_list() where location_code = 'W1' and sku = 'RICE25'),
  'W1 rice uses default reorder point (50) and is_override is false'
);

select is(
  (select count(*)::int from public.warehouse_reorder_list() where sku = 'SUGAR50'),
  0,
  'SUGAR50 with default reorder point 0 does not appear'
);

-- ---------------------------------------------------------------------------
-- 2. Set warehouse-specific override (W1 custom reorder point = 30)
-- ---------------------------------------------------------------------------
-- Since on-hand is 40 and new reorder point is 30, W1 rice should now NOT be low!
select is(
  public.set_location_reorder_point(pg_temp.lid('A', 'W1'), pg_temp.vid('A', 'RICE25'), 30),
  30::numeric,
  'owner can set custom reorder point to 30'
);

select is(
  (select count(*)::int from public.warehouse_reorder_list(pg_temp.lid('A', 'W1'))),
  0,
  'W1 rice no longer low because qty 40 > custom reorder_point 30'
);

select is(
  (select count(*)::int from public.warehouse_reorder_list(pg_temp.lid('A', 'W2'))),
  1,
  'W2 rice remains low using default reorder point 50'
);

-- ---------------------------------------------------------------------------
-- 3. Set custom reorder point on product with default 0 (SUGAR50 on W1 = 20)
-- ---------------------------------------------------------------------------
-- SUGAR50 has 10 on hand; with custom reorder point 20, it should now appear!
select is(
  public.set_location_reorder_point(pg_temp.lid('A', 'W1'), pg_temp.vid('A', 'SUGAR50'), 20),
  20::numeric,
  'owner sets SUGAR50 reorder point on W1 to 20'
);

select ok(
  (select is_override and reorder_point = 20 and shortfall = 10
   from public.warehouse_reorder_list(pg_temp.lid('A', 'W1')) where sku = 'SUGAR50'),
  'SUGAR50 now appears for W1 with is_override true and reorder_point 20'
);

-- ---------------------------------------------------------------------------
-- 4. Audit trail verification
-- ---------------------------------------------------------------------------
select ok(
  exists (
    select 1 from public.audit_log
    where action = 'location.set_reorder_point'
      and entity_id = pg_temp.lid('A', 'W1')
      and (meta ->> 'reorder_point')::numeric = 20
  ),
  'audit log records setting custom reorder point'
);

-- ---------------------------------------------------------------------------
-- 5. Clear override by passing null (revert to default)
-- ---------------------------------------------------------------------------
select is(
  public.set_location_reorder_point(pg_temp.lid('A', 'W1'), pg_temp.vid('A', 'RICE25'), null),
  50::numeric,
  'clearing W1 rice override reverts effective reorder point to default 50'
);

select ok(
  (select not is_override and reorder_point = 50
   from public.warehouse_reorder_list(pg_temp.lid('A', 'W1')) where sku = 'RICE25'),
  'W1 rice is low again under default reorder point 50'
);

-- Clear SUGAR50 override with negative value
select is(
  public.set_location_reorder_point(pg_temp.lid('A', 'W1'), pg_temp.vid('A', 'SUGAR50'), -1),
  0::numeric,
  'negative reorder point clears override, reverting SUGAR50 to 0'
);

select is(
  (select count(*)::int from public.warehouse_reorder_list(pg_temp.lid('A', 'W1')) where sku = 'SUGAR50'),
  0,
  'SUGAR50 disappears after clearing override'
);

reset role;

-- ---------------------------------------------------------------------------
-- 6. RBAC & Location permissions
-- ---------------------------------------------------------------------------
-- W1 clerk can update W1 reorder point
select pg_temp.login('A', 'clerk1', 'warehouse', array[pg_temp.lid('A', 'W1')]);
set local role authenticated;

select is(
  public.set_location_reorder_point(pg_temp.lid('A', 'W1'), pg_temp.vid('A', 'RICE25'), 100),
  100::numeric,
  'W1 warehouse clerk can set reorder point for W1'
);

-- W1 clerk cannot update W2 reorder point
select throws_ok(
  $$ select public.set_location_reorder_point(pg_temp.lid('A', 'W2'), pg_temp.vid('A', 'RICE25'), 100) $$,
  '42501',
  null,
  'W1 clerk cannot set reorder point for W2'
);

reset role;

-- Cashier cannot update any reorder point
select pg_temp.login('A', 'cashier', 'cashier');
set local role authenticated;

select throws_ok(
  $$ select public.set_location_reorder_point(pg_temp.lid('A', 'W1'), pg_temp.vid('A', 'RICE25'), 100) $$,
  '42501',
  null,
  'cashier cannot set location reorder point'
);

reset role;

-- ---------------------------------------------------------------------------
-- 7. Tenant isolation
-- ---------------------------------------------------------------------------
select pg_temp.login('B', 'owner', 'superadmin');
set local role authenticated;

-- Tenant B cannot set reorder point on Tenant A location
select throws_ok(
  $$ select public.set_location_reorder_point(pg_temp.lid('A', 'W1'), pg_temp.vid('B', 'RICE25'), 100) $$,
  '22023',
  null,
  'tenant B cannot set reorder point on tenant A location'
);

-- Tenant B cannot set reorder point with Tenant A variant
select throws_ok(
  $$ select public.set_location_reorder_point(pg_temp.lid('B', 'W1'), pg_temp.vid('A', 'RICE25'), 100) $$,
  '22023',
  null,
  'tenant B cannot set reorder point using tenant A variant'
);

-- Tenant B sees only its own reorder list
select is(
  (select count(*)::int from public.warehouse_reorder_list()),
  1,
  'tenant B sees only its own low stock row'
);

select ok(
  (select sku = 'RICE25' and reorder_point = 40 from public.warehouse_reorder_list()),
  'tenant B low stock row has its own reorder point 40'
);

-- Tenant B cannot read Tenant A location_reorder_points table
select is(
  (select count(*)::int from public.location_reorder_points where tenant_id = pg_temp.tid('A')),
  0,
  'tenant B cannot read tenant A location_reorder_points via RLS'
);

reset role;

select * from finish();
rollback;
