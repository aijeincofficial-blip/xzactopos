-- 042_transfer_stock_guard.test.sql: a transfer cannot send out more than the origin holds (F-13i finding).
-- Shipping goes through stock_movements of type transfer_out, from ship_transfer and from create_transfer(ship_now).
-- Sales, adjustments and count corrections keep their own rules (offline sales may go below zero).

begin;
select plan(16);

create function pg_temp.tid(p_tenant text) returns uuid language sql immutable
  as $$ select md5('tenant:' || p_tenant)::uuid $$;
create function pg_temp.uid(p_tenant text, p_user text) returns uuid language sql immutable
  as $$ select md5('user:' || p_tenant || ':' || p_user)::uuid $$;
create function pg_temp.lid(p_tenant text, p_code text) returns uuid language sql immutable
  as $$ select md5('loc:' || p_tenant || ':' || p_code)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values (pg_temp.tid('G'), 'Guard Tenant', 'guard-tenant', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid('G'), true, true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('G'));

insert into auth.users (id, email) values
  (pg_temp.uid('G', 'owner'), 'owner@guard.invalid'),
  (pg_temp.uid('G', 'pedro'), 'pedro@guard.invalid');
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('G', 'owner'), pg_temp.tid('G'), 'owner', 'superadmin', true),
  (pg_temp.uid('G', 'pedro'), pg_temp.tid('G'), 'pedro', 'warehouse', true);

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.lid('G', 'W1'), pg_temp.tid('G'), 'warehouse', 'W1', 'Warehouse 1'),
  (pg_temp.lid('G', 'W2'), pg_temp.tid('G'), 'warehouse', 'W2', 'Warehouse 2'),
  (pg_temp.lid('G', 'S1'), pg_temp.tid('G'), 'store', 'S1', 'Store 1');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('G', 'pedro'), pg_temp.lid('G', 'W1'), pg_temp.tid('G'), null);

insert into public.products (id, tenant_id, name) values (md5('p:g1')::uuid, pg_temp.tid('G'), 'Rice 25kg'), (md5('p:g2')::uuid, pg_temp.tid('G'), 'Oil 1L');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (md5('v:g1')::uuid, pg_temp.tid('G'), md5('p:g1')::uuid, 'G-RICE', true),
  (md5('v:g2')::uuid, pg_temp.tid('G'), md5('p:g2')::uuid, 'G-OIL', true);

-- W1 holds 20 rice and no oil
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost)
  values (pg_temp.tid('G'), pg_temp.lid('G', 'W1'), md5('v:g1')::uuid, 20, 'receipt', 1000);

create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.uid('G', p_user), 'role', 'authenticated', 'tenant_id', pg_temp.tid('G'))::text, true);
$$;
create function pg_temp.qty(p_loc text, p_variant text) returns numeric language sql as $$
  select coalesce((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('G', p_loc) and variant_id = md5(p_variant)::uuid), 0)
$$;

-- ---------------------------------------------------------------------------
-- ship_now: more than the origin holds is refused, nothing moves
-- ---------------------------------------------------------------------------
select pg_temp.login('pedro');
set local role authenticated;
select throws_ok(
  $$ select public.create_transfer(pg_temp.lid('G', 'W1'), pg_temp.lid('G', 'W2'), null,
       jsonb_build_array(jsonb_build_object('variant_id', md5('v:g1')::uuid, 'qty', 21)), true) $$,
  '55000', null, 'shipping 21 when 20 are held is refused (create_transfer, ship now)');
select throws_ok(
  $$ select public.create_transfer(pg_temp.lid('G', 'W1'), pg_temp.lid('G', 'W2'), null,
       jsonb_build_array(jsonb_build_object('variant_id', md5('v:g2')::uuid, 'qty', 1)), true) $$,
  '55000', null, 'shipping a product the origin has never held is refused');
reset role;
select is(pg_temp.qty('W1', 'v:g1'), 20::numeric, 'a refused shipment moved nothing');
select is((select count(*)::int from public.transfers where tenant_id = pg_temp.tid('G')), 0, 'and left no transfer behind');

-- the hint tells the screens what to say
select pg_temp.login('pedro');
set local role authenticated;
do $$
declare v_hint text;
begin
  begin
    perform public.create_transfer(pg_temp.lid('G', 'W1'), pg_temp.lid('G', 'W2'), null,
      jsonb_build_array(jsonb_build_object('variant_id', md5('v:g1')::uuid, 'qty', 99)), true);
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint;
  end;
  perform set_config('test.hint', coalesce(v_hint, ''), true);
end $$;
reset role;
select is(current_setting('test.hint'), 'insufficient_stock', 'the refusal carries the hint insufficient_stock');

-- one short line refuses the whole shipment
select pg_temp.login('pedro');
set local role authenticated;
select throws_ok(
  $$ select public.create_transfer(pg_temp.lid('G', 'W1'), pg_temp.lid('G', 'W2'), null,
       jsonb_build_array(jsonb_build_object('variant_id', md5('v:g1')::uuid, 'qty', 5),
                         jsonb_build_object('variant_id', md5('v:g2')::uuid, 'qty', 1)), true) $$,
  '55000', null, 'one line that is short refuses the whole shipment');
reset role;
select is(pg_temp.qty('W1', 'v:g1'), 20::numeric, 'the good line did not ship either');

-- ---------------------------------------------------------------------------
-- exactly what is held can go; draft then ship is guarded too
-- ---------------------------------------------------------------------------
select pg_temp.login('pedro');
set local role authenticated;
create temp table pg_temp.t_draft as
  select public.create_transfer(pg_temp.lid('G', 'W1'), pg_temp.lid('G', 'W2'), null,
    jsonb_build_array(jsonb_build_object('variant_id', md5('v:g1')::uuid, 'qty', 15)), false) as id;
select lives_ok($$ select public.ship_transfer((select id from pg_temp.t_draft)) $$, 'a draft within stock ships');
reset role;
select is(pg_temp.qty('W1', 'v:g1'), 5::numeric, 'stock fell by what shipped');

-- a draft made while stock was there, shipped after it was used up
select pg_temp.login('pedro');
set local role authenticated;
create temp table pg_temp.t_draft2 as
  select public.create_transfer(pg_temp.lid('G', 'W1'), pg_temp.lid('G', 'S1'), null,
    jsonb_build_array(jsonb_build_object('variant_id', md5('v:g1')::uuid, 'qty', 5)), false) as id;
reset role;
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
  values (pg_temp.tid('G'), pg_temp.lid('G', 'W1'), md5('v:g1')::uuid, -3, 'damage');
select pg_temp.login('pedro');
set local role authenticated;
select throws_ok($$ select public.ship_transfer((select id from pg_temp.t_draft2)) $$, '55000', null,
  'a draft that is no longer covered is refused when shipped (ship_transfer)');
reset role;
select is(pg_temp.qty('W1', 'v:g1'), 2::numeric, 'nothing was taken');
select is((select status from public.transfers where id = (select id from pg_temp.t_draft2)), 'draft', 'and the draft stays a draft');

-- ---------------------------------------------------------------------------
-- other ways out are not touched: a sale or an adjustment may still go below zero
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
       values (pg_temp.tid('G'), pg_temp.lid('G', 'W1'), md5('v:g1')::uuid, -10, 'damage') $$,
  'a write-off below zero is still recorded (offline sales and counts keep their rules)');
select is(pg_temp.qty('W1', 'v:g1'), (-8)::numeric, 'the level shows it');

-- a receipt-side movement is never blocked
select lives_ok(
  $$ insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
       values (pg_temp.tid('G'), pg_temp.lid('G', 'W2'), md5('v:g1')::uuid, 4, 'transfer_in') $$,
  'a transfer_in is not guarded');

-- an origin that is below zero cannot ship at all
select pg_temp.login('owner');
set local role authenticated;
select throws_ok(
  $$ select public.create_transfer(pg_temp.lid('G', 'W1'), pg_temp.lid('G', 'W2'), null,
       jsonb_build_array(jsonb_build_object('variant_id', md5('v:g1')::uuid, 'qty', 1)), true) $$,
  '55000', null, 'an origin already below zero cannot ship');
reset role;

select * from finish();
rollback;
