-- 045_web_gaps.test.sql: Tests for stored mode flag, update_po RPC, put-away and pick list helpers
begin;
select plan(28);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p text) returns uuid language sql immutable as $$ select md5('tenant:WG:' || p)::uuid $$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$ select md5('user:WG:' || p)::uuid $$;
create function pg_temp.lid(p text) returns uuid language sql immutable as $$ select md5('loc:WG:' || p)::uuid $$;
create function pg_temp.vid(p text) returns uuid language sql immutable as $$ select md5('var:WG:' || p)::uuid $$;
create function pg_temp.sid(p text) returns uuid language sql immutable as $$ select md5('sup:WG:' || p)::uuid $$;
create function pg_temp.poid(p text) returns uuid language sql immutable as $$ select md5('po:WG:' || p)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.tid('X'), 'WG Tenant X', 'wg-x', 'PHP'),
  (pg_temp.tid('Y'), 'WG Tenant Y', 'wg-y', 'PHP');

insert into public.tenant_modules (tenant_id, pos, warehouse) values
  (pg_temp.tid('X'), true, true),
  (pg_temp.tid('Y'), true, true);

insert into public.tenant_settings (tenant_id, mode) values
  (pg_temp.tid('X'), 'solo'),
  (pg_temp.tid('Y'), 'solo');

insert into auth.users (id, email) select pg_temp.uid(n), n || '@wg.invalid'
  from unnest(array['owner', 'wh1', 'wh2', 'cashier', 'ownerY']) n;

insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('owner'),   pg_temp.tid('X'), 'owner',   'superadmin', true),
  (pg_temp.uid('wh1'),     pg_temp.tid('X'), 'wh1',     'warehouse',  true),
  (pg_temp.uid('wh2'),     pg_temp.tid('X'), 'wh2',     'warehouse',  true),
  (pg_temp.uid('cashier'), pg_temp.tid('X'), 'cashier', 'cashier',    true),
  (pg_temp.uid('ownerY'),  pg_temp.tid('Y'), 'owner',   'superadmin', true);

insert into public.locations (id, tenant_id, type, code, name, bins_enabled) values
  (pg_temp.lid('W1'), pg_temp.tid('X'), 'warehouse', 'W1', 'Warehouse One', true),
  (pg_temp.lid('W2'), pg_temp.tid('X'), 'warehouse', 'W2', 'Warehouse Two', false),
  (pg_temp.lid('WY'), pg_temp.tid('Y'), 'warehouse', 'WY', 'Warehouse Y',   false);

insert into public.location_access (user_id, location_id, tenant_id) values
  (pg_temp.uid('wh1'), pg_temp.lid('W1'), pg_temp.tid('X')),
  (pg_temp.uid('wh2'), pg_temp.lid('W2'), pg_temp.tid('X'));

insert into public.products (id, tenant_id, name) values
  (md5('p:WG:1')::uuid, pg_temp.tid('X'), 'Product 1'),
  (md5('p:WG:2')::uuid, pg_temp.tid('X'), 'Product 2'),
  (md5('p:WG:3')::uuid, pg_temp.tid('X'), 'Product 3');

insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (pg_temp.vid('v1'), pg_temp.tid('X'), md5('p:WG:1')::uuid, 'SKU-01', true),
  (pg_temp.vid('v2'), pg_temp.tid('X'), md5('p:WG:2')::uuid, 'SKU-02', true),
  (pg_temp.vid('v3'), pg_temp.tid('X'), md5('p:WG:3')::uuid, 'SKU-03', true);

insert into public.suppliers (id, tenant_id, name) values
  (pg_temp.sid('S1'), pg_temp.tid('X'), 'Supplier 1'),
  (pg_temp.sid('S2'), pg_temp.tid('X'), 'Supplier 2');

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

-- ---------------------------------------------------------------------------
-- 1. Mode tests: stored flag, set_tenant_mode, set_modules, get_my_access
-- ---------------------------------------------------------------------------
select is((select mode from public.tenant_settings where tenant_id = pg_temp.tid('X')), 'solo', 'default mode is solo');

select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try($$ select public.set_tenant_mode('full') $$), '42501:superadmin_only', 'wh1 cannot change tenant mode');

select pg_temp.login('owner');
set local role authenticated;
select is(pg_temp.try($$ select public.set_tenant_mode('full') $$), 'ok', 'owner sets tenant mode to full');
reset role;
select is((select mode from public.tenant_settings where tenant_id = pg_temp.tid('X')), 'full', 'mode updated to full');

select pg_temp.login('owner');
set local role authenticated;
select is((public.get_my_access() -> 'tenant' ->> 'mode'), 'full', 'get_my_access reflects mode full');

select is(pg_temp.try($$ select public.set_tenant_mode('solo') $$), 'ok', 'owner sets tenant mode back to solo');
reset role;
select is((select mode from public.tenant_settings where tenant_id = pg_temp.tid('X')), 'solo', 'mode reset to solo');

-- Turning on warehouse in set_modules updates mode to full
select pg_temp.login('owner');
set local role authenticated;
select is(pg_temp.try($$ select public.set_modules(true, true) $$), 'ok', 'set_modules called with warehouse=true');
reset role;
select is((select mode from public.tenant_settings where tenant_id = pg_temp.tid('X')), 'full', 'set_modules switched mode to full');

-- ---------------------------------------------------------------------------
-- 2. Purchase orders: create draft, update draft
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;

-- Create draft PO
select is(pg_temp.try(format($$
  select public.create_po(%L, %L, %L, '2026-12-01', 'Initial draft', jsonb_build_array(
    jsonb_build_object('variant_id', %L, 'qty', 10, 'unit_cost', 500)
  ))
$$, pg_temp.poid('1'), pg_temp.lid('W1'), pg_temp.sid('S1'), pg_temp.vid('v1'))),
  'ok', 'wh1 creates draft PO 1');

reset role;
select is((select supplier_id from public.purchase_orders where id = pg_temp.poid('1')), pg_temp.sid('S1'), 'initial supplier is S1');
select is((select notes from public.purchase_orders where id = pg_temp.poid('1')), 'Initial draft', 'initial note is set');
select is((select count(*)::int from public.po_items where po_id = pg_temp.poid('1')), 1, 'initial lines count is 1');

-- Update draft PO: change supplier to S2, notes, expected date, and items to 2 lines
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$
  select public.update_po(%L, %L, '2026-12-15', 'Updated note', jsonb_build_array(
    jsonb_build_object('variant_id', %L, 'qty', 25, 'unit_cost', 450),
    jsonb_build_object('variant_id', %L, 'qty', 50, 'unit_cost', 300)
  ))
$$, pg_temp.poid('1'), pg_temp.sid('S2'), pg_temp.vid('v1'), pg_temp.vid('v2'))),
  'ok', 'wh1 successfully updates draft PO 1');

reset role;
select is((select supplier_id from public.purchase_orders where id = pg_temp.poid('1')), pg_temp.sid('S2'), 'supplier changed to S2');
select is((select notes from public.purchase_orders where id = pg_temp.poid('1')), 'Updated note', 'notes updated');
select is((select expected_at from public.purchase_orders where id = pg_temp.poid('1')), '2026-12-15'::date, 'expected_at updated');
select is((select count(*)::int from public.po_items where po_id = pg_temp.poid('1')), 2, 'lines updated to 2 items');
select is((select qty_ordered from public.po_items where po_id = pg_temp.poid('1') and variant_id = pg_temp.vid('v1')), 25::numeric, 'v1 qty is 25');

-- update_po negative tests
select pg_temp.login('wh2');
set local role authenticated;
select is(pg_temp.try(format($$
  select public.update_po(%L, %L, null, null, jsonb_build_array(jsonb_build_object('variant_id', %L, 'qty', 1)))
$$, pg_temp.poid('1'), pg_temp.sid('S1'), pg_temp.vid('v1'))),
  '42501:location_denied', 'wh2 cannot edit a PO for W1');

select pg_temp.login('cashier');
set local role authenticated;
select is(pg_temp.try(format($$
  select public.update_po(%L, %L, null, null, jsonb_build_array(jsonb_build_object('variant_id', %L, 'qty', 1)))
$$, pg_temp.poid('1'), pg_temp.sid('S1'), pg_temp.vid('v1'))),
  '42501:not_allowed', 'cashier cannot edit purchase orders');

select pg_temp.login('ownerY');
set local role authenticated;
select is(pg_temp.try(format($$
  select public.update_po(%L, %L, null, null, jsonb_build_array(jsonb_build_object('variant_id', %L, 'qty', 1)))
$$, pg_temp.poid('1'), pg_temp.sid('S1'), pg_temp.vid('v1'))),
  '22023:not_found', 'tenant Y cannot see tenant X PO');

select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$
  select public.update_po(%L, %L, null, null, '[]'::jsonb)
$$, pg_temp.poid('1'), pg_temp.sid('S1'))),
  '22023:items_required', 'updating PO with 0 items is refused');

select is(pg_temp.try(format($$
  select public.update_po(%L, %L, null, null, jsonb_build_array(jsonb_build_object('variant_id', %L, 'qty', 0)))
$$, pg_temp.poid('1'), pg_temp.sid('S1'), pg_temp.vid('v1'))),
  '22023:qty_invalid', 'updating PO with qty 0 is refused');

-- Submit the PO so status is 'ordered'
select is(pg_temp.try(format($$ select public.submit_po(%L) $$, pg_temp.poid('1'))), 'ok', 'wh1 submits PO 1');

-- Attempting update on submitted PO fails
select is(pg_temp.try(format($$
  select public.update_po(%L, %L, null, null, jsonb_build_array(jsonb_build_object('variant_id', %L, 'qty', 5)))
$$, pg_temp.poid('1'), pg_temp.sid('S1'), pg_temp.vid('v1'))),
  'P0001:po_not_draft', 'cannot update PO that is not in draft status');

-- ---------------------------------------------------------------------------
-- 3. Helpers: list_receiving_stock and get_pick_list_for_transfer
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is(jsonb_typeof(public.list_receiving_stock(pg_temp.lid('W1'))), 'array', 'list_receiving_stock returns a JSON array');
select is(public.get_pick_list_for_transfer(md5('nonexistent')::uuid), null, 'get_pick_list_for_transfer returns null for non-existent transfer');

rollback;
