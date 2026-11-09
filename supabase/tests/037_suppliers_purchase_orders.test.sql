-- 037_suppliers_purchase_orders.test.sql: F-13c. Suppliers (shared by the tenant) and purchase orders (addressed to ONE warehouse).
begin;
select plan(67);

-- ---------------------------------------------------------------------------
-- Fixtures: tenant X (warehouses W1, W2, store S1) and tenant Y (to prove the tenant boundary)
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p text) returns uuid language sql immutable as $$ select md5('tenant:PO:' || p)::uuid $$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$ select md5('user:PO:' || p)::uuid $$;
create function pg_temp.lid(p text) returns uuid language sql immutable as $$ select md5('loc:PO:' || p)::uuid $$;
create function pg_temp.vid(p text) returns uuid language sql immutable as $$ select md5('var:PO:' || p)::uuid $$;
create function pg_temp.sid(p text) returns uuid language sql immutable as $$ select md5('sup:PO:' || p)::uuid $$;
create function pg_temp.poid(p text) returns uuid language sql immutable as $$ select md5('po:PO:' || p)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.tid('X'), 'PO Tenant X', 'po-x', 'PHP'), (pg_temp.tid('Y'), 'PO Tenant Y', 'po-y', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid('X'), true, true), (pg_temp.tid('Y'), true, true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('X')), (pg_temp.tid('Y'));

insert into auth.users (id, email) select pg_temp.uid(n), n || '@po.invalid'
  from unnest(array['owner', 'wh1', 'wh2', 'maria', 'juan', 'ownerY']) n;
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
  (pg_temp.lid('S1'), pg_temp.tid('X'), 'store',     'S1', 'Store One');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('wh1'),   pg_temp.lid('W1'), pg_temp.tid('X'), null),
  (pg_temp.uid('wh2'),   pg_temp.lid('W2'), pg_temp.tid('X'), null),
  (pg_temp.uid('maria'), pg_temp.lid('S1'), pg_temp.tid('X'), 'manager'),
  (pg_temp.uid('juan'),  pg_temp.lid('S1'), pg_temp.tid('X'), null);

insert into public.products (id, tenant_id, name) values (md5('p:PO:1')::uuid, pg_temp.tid('X'), 'Rice 25kg'), (md5('p:PO:2')::uuid, pg_temp.tid('X'), 'Cooking oil'), (md5('p:PO:3')::uuid, pg_temp.tid('X'), 'Salt');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (pg_temp.vid('rice'), pg_temp.tid('X'), md5('p:PO:1')::uuid, 'RICE25', true),
  (pg_temp.vid('oil'),  pg_temp.tid('X'), md5('p:PO:2')::uuid, 'OIL1L', true),
  (pg_temp.vid('salt'), pg_temp.tid('X'), md5('p:PO:3')::uuid, 'SALT1', true);

-- tenant Y already has a supplier with the same name tenant X will use
insert into public.suppliers (id, tenant_id, name) values (pg_temp.sid('Y'), pg_temp.tid('Y'), 'Mega Rice Trading');

create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.uid(p_user), 'role', 'authenticated',
    'tenant_id', case when p_user = 'ownerY' then pg_temp.tid('Y') else pg_temp.tid('X') end)::text, true);
$$;

-- runs a statement as the current user; 'ok' or 'SQLSTATE:hint'
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

create function pg_temp.items(p_rice numeric default 100, p_oil numeric default 20) returns jsonb language sql as $$
  select jsonb_build_array(
    jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', p_rice, 'unit_cost', 1000),
    jsonb_build_object('variant_id', pg_temp.vid('oil'),  'qty', p_oil,  'unit_cost', 5000));
$$;

-- ---------------------------------------------------------------------------
-- 1. Suppliers: shared by the tenant, managed by the owner and warehouse staff
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;
select is(pg_temp.try(format($$ select public.upsert_supplier(%L, 'Mega Rice Trading', 'Ana Cruz', '0917', null, 'net 30') $$, pg_temp.sid('A'))),
  'ok', 'the owner adds a supplier');
select is(pg_temp.try(format($$ select public.upsert_supplier(%L, '  mega rice trading ') $$, pg_temp.sid('A2'))),
  'P0001:duplicate_supplier', 'the same name (any case or spacing) is refused inside one tenant');
select is(pg_temp.try(format($$ select public.upsert_supplier(%L, '   ') $$, pg_temp.sid('B'))),
  '22023:name_required', 'a blank name is refused');
reset role;
select is((select count(*)::int from public.suppliers where lower(name) = 'mega rice trading'), 2,
  'the same supplier name exists in two tenants');

select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$ select public.upsert_supplier(%L, 'Golden Oil Co') $$, pg_temp.sid('C'))), 'ok',
  'a warehouse user adds a supplier (suppliers belong to the tenant)');
select is(pg_temp.try(format($$ select public.upsert_supplier(%L, 'Mega Rice Trading', 'Ana Cruz', '0918') $$, pg_temp.sid('A'))), 'ok',
  'a supplier is edited by passing its id again');
reset role;
select is((select phone from public.suppliers where id = pg_temp.sid('A')), '0918', 'the edit was saved');
select is((select count(*)::int from public.suppliers where tenant_id = pg_temp.tid('X')), 2, 'no duplicate row from the edit');

select pg_temp.login('wh2');
set local role authenticated;
select is((select count(*)::int from public.suppliers), 2, 'a warehouse user of another warehouse sees the shared suppliers');
reset role;

select pg_temp.login('maria');
set local role authenticated;
select is(pg_temp.try(format($$ select public.upsert_supplier(%L, 'Sneaky') $$, pg_temp.sid('D'))), '42501:not_allowed', 'a store admin cannot add suppliers');
select is((select count(*)::int from public.suppliers), 0, 'a store admin does not see suppliers');
reset role;

select pg_temp.login('juan');
set local role authenticated;
select is(pg_temp.try(format($$ select public.upsert_supplier(%L, 'Sneaky') $$, pg_temp.sid('D'))), '42501:not_allowed', 'a cashier cannot add suppliers');
select is((select count(*)::int from public.suppliers), 0, 'a cashier does not see suppliers');
reset role;

select pg_temp.login('ownerY');
set local role authenticated;
select is((select count(*)::int from public.suppliers), 1, 'tenant Y sees only its own supplier');
select is(pg_temp.try(format($$ select public.upsert_supplier(%L, 'Hijack') $$, pg_temp.sid('A'))), 'P0001:id_conflict',
  'tenant Y cannot overwrite tenant X''s supplier by reusing its id');
reset role;
select is((select name from public.suppliers where id = pg_temp.sid('A')), 'Mega Rice Trading', 'tenant X''s supplier is untouched');

-- ---------------------------------------------------------------------------
-- 2. Purchase orders: create (draft)
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, '2026-12-01', 'for December', %L::jsonb) $$,
    pg_temp.poid('1'), pg_temp.lid('W1'), pg_temp.sid('A'), pg_temp.items()::text)),
  'ok', 'wh1 drafts a purchase order for W1');
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('1'), pg_temp.lid('W1'), pg_temp.sid('A'), pg_temp.items()::text)),
  'ok', 'sending the same PO id again is a replay, not an error');
select is((select count(*)::int from public.purchase_orders where id = pg_temp.poid('1')), 1, 'the replay made no second PO');
select is((select count(*)::int from public.po_items where po_id = pg_temp.poid('1')), 2, 'the PO has its two lines');
select ok((select po_no ~ '^PO-[0-9]{6}-0001$' from public.purchase_orders where id = pg_temp.poid('1')), 'the first PO number looks like PO-YYMMDD-0001');
select is((select status from public.purchase_orders where id = pg_temp.poid('1')), 'draft', 'a new PO is a draft');
select is((select qty_received from public.po_items where po_id = pg_temp.poid('1') and variant_id = pg_temp.vid('rice')), 0::numeric,
  'nothing is received yet');

select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('2'), pg_temp.lid('W1'), pg_temp.sid('C'), pg_temp.items(5, 5)::text)),
  'ok', 'a second PO is accepted');
select ok((select po_no ~ '^PO-[0-9]{6}-0002$' from public.purchase_orders where id = pg_temp.poid('2')), 'and gets the next number');

select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('1'), pg_temp.lid('W1'), pg_temp.sid('C'), pg_temp.items()::text)),
  'P0001:id_conflict', 'reusing a PO id for a different order is refused');
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('x'), pg_temp.lid('W2'), pg_temp.sid('A'), pg_temp.items()::text)),
  '42501:location_denied', 'wh1 cannot order for W2');
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('x'), pg_temp.lid('S1'), pg_temp.sid('A'), pg_temp.items()::text)),
  '42501:location_denied', 'wh1 cannot order for a store');
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, '[]'::jsonb) $$,
    pg_temp.poid('x'), pg_temp.lid('W1'), pg_temp.sid('A'))), '22023:items_required', 'a PO needs at least one line');
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('x'), pg_temp.lid('W1'), pg_temp.sid('A'), pg_temp.items(0, 5)::text)), '22023:qty_invalid', 'a zero quantity is refused');
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('x'), pg_temp.lid('W1'), pg_temp.sid('A'),
    jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 1), jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 2))::text)),
  '22023:duplicate_item', 'the same product twice on one PO is refused');
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('x'), pg_temp.lid('W1'), pg_temp.sid('A'),
    jsonb_build_array(jsonb_build_object('variant_id', md5('nope')::uuid, 'qty', 1))::text)),
  '22023:unknown_variant', 'an unknown product is refused');
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('x'), pg_temp.lid('W1'), pg_temp.sid('A'),
    jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 1, 'unit_cost', -5))::text)),
  '22023:invalid_value', 'a negative cost is refused');
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('x'), pg_temp.lid('W1'), pg_temp.sid('Y'), pg_temp.items()::text)),
  '22023:supplier_not_found', 'a supplier of another tenant is not found');
select is((select count(*)::int from public.purchase_orders where tenant_id = pg_temp.tid('X')), 2, 'refused orders left no trace');
reset role;

select pg_temp.login('owner');
set local role authenticated;
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('x'), pg_temp.lid('S1'), pg_temp.sid('A'), pg_temp.items()::text)),
  '22023:not_a_warehouse', 'even the owner cannot address a PO to a store');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Who sees purchase orders
-- ---------------------------------------------------------------------------
select pg_temp.login('wh2');
set local role authenticated;
select is((select count(*)::int from public.purchase_orders), 0, 'wh2 sees no PO of W1');
select is((select count(*)::int from public.po_items), 0, 'wh2 sees no PO lines of W1');
select is(pg_temp.try(format($$ select public.submit_po(%L) $$, pg_temp.poid('1'))), '42501:location_denied', 'wh2 cannot submit W1''s PO');
select is(pg_temp.try(format($$ select public.cancel_po(%L, 'no') $$, pg_temp.poid('1'))), '42501:location_denied', 'wh2 cannot cancel W1''s PO');
reset role;

select pg_temp.login('wh1');
set local role authenticated;
select is((select count(*)::int from public.purchase_orders), 2, 'wh1 sees both POs of W1');
select is((select count(*)::int from public.po_items), 4, 'wh1 sees the four lines');
reset role;

select pg_temp.login('owner');
set local role authenticated;
select is((select count(*)::int from public.purchase_orders), 2, 'the owner sees every PO');
reset role;

select pg_temp.login('maria');
set local role authenticated;
select is((select count(*)::int from public.purchase_orders), 0, 'a store admin sees no PO');
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('x'), pg_temp.lid('W1'), pg_temp.sid('A'), pg_temp.items()::text)), '42501:not_allowed', 'a store admin cannot order');
reset role;

select pg_temp.login('juan');
set local role authenticated;
select is((select count(*)::int from public.purchase_orders) + (select count(*)::int from public.po_items), 0, 'a cashier sees no PO or lines');
reset role;

select pg_temp.login('ownerY');
set local role authenticated;
select is((select count(*)::int from public.purchase_orders) + (select count(*)::int from public.po_items), 0, 'tenant Y sees no PO of tenant X');
reset role;

-- ---------------------------------------------------------------------------
-- 4. Submit, cancel and the status rules
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$ select public.submit_po(%L) $$, pg_temp.poid('1'))), 'ok', 'wh1 submits the PO (draft -> ordered)');
select is(pg_temp.try(format($$ select public.submit_po(%L) $$, pg_temp.poid('1'))), 'ok', 'submitting again is harmless');
reset role;
select is((select status from public.purchase_orders where id = pg_temp.poid('1')), 'ordered', 'the PO is ordered');
select ok((select ordered_at is not null and ordered_by = pg_temp.uid('wh1') from public.purchase_orders where id = pg_temp.poid('1')), 'who and when are recorded');

select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$ select public.cancel_po(%L, 'supplier ran out') $$, pg_temp.poid('2'))), 'ok', 'a draft PO can be cancelled');
select is(pg_temp.try(format($$ select public.submit_po(%L) $$, pg_temp.poid('2'))), 'P0001:invalid_state', 'a cancelled PO cannot be submitted');
reset role;
select is((select cancel_reason from public.purchase_orders where id = pg_temp.poid('2')), 'supplier ran out', 'the reason is kept');

-- a PO with receipts cannot be cancelled (simulated receipt; F-13d does this properly)
update public.po_items set qty_received = 40 where po_id = pg_temp.poid('1') and variant_id = pg_temp.vid('rice');
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$ select public.cancel_po(%L, 'too late') $$, pg_temp.poid('1'))), 'P0001:po_has_receipts',
  'received quantity alone blocks cancelling, whatever the status says');
reset role;
update public.purchase_orders set status = 'partly_received' where id = pg_temp.poid('1');
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$ select public.cancel_po(%L, 'too late') $$, pg_temp.poid('1'))), 'P0001:po_has_receipts', 'a PO that received goods cannot be cancelled');
reset role;

-- a supplier with an open PO cannot be archived; one without can
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$ select public.archive_supplier(%L) $$, pg_temp.sid('A'))), 'P0001:supplier_in_use', 'a supplier with an open PO cannot be archived');
select is(pg_temp.try(format($$ select public.archive_supplier(%L) $$, pg_temp.sid('C'))), 'ok', 'a supplier whose only PO is cancelled can be archived');
reset role;
select ok((select deleted_at is not null from public.suppliers where id = pg_temp.sid('C')), 'archiving is a soft delete');

-- ---------------------------------------------------------------------------
-- 5. Schema guards and audit
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;
select throws_ok($$ insert into public.purchase_orders (tenant_id, po_no, warehouse_id, supplier_id, status)
  values (md5('tenant:PO:X')::uuid, 'PO-HACK', md5('loc:PO:W1')::uuid, md5('sup:PO:A')::uuid, 'draft') $$,
  '42501', null, 'even the owner cannot insert a PO directly');
select throws_ok($$ update public.po_items set qty_received = 999 $$, '42501', null, 'nobody edits received quantities directly');
reset role;

select throws_ok(format($$ insert into public.purchase_orders (tenant_id, po_no, warehouse_id, supplier_id, status)
  values (%L, 'PO-BAD-1', %L, %L, 'draft') $$, pg_temp.tid('X'), pg_temp.lid('S1'), pg_temp.sid('A')),
  null, null, 'a PO cannot be addressed to a store');
select throws_ok(format($$ insert into public.purchase_orders (tenant_id, po_no, warehouse_id, supplier_id, status)
  values (%L, (select po_no from public.purchase_orders where id = %L), %L, %L, 'draft') $$,
  pg_temp.tid('X'), pg_temp.poid('1'), pg_temp.lid('W2'), pg_temp.sid('A')),
  '23505', null, 'PO numbers are unique per tenant');
select throws_ok(format($$ insert into public.po_items (tenant_id, po_id, variant_id, qty_ordered)
  values (%L, %L, %L, 1) $$, pg_temp.tid('Y'), pg_temp.poid('1'), pg_temp.vid('salt')),
  '23503', null, 'a line cannot point at another tenant''s PO');

select is((select count(*)::int from public.audit_log where action in ('po.create', 'po.submit', 'po.cancel')
           and location_id = pg_temp.lid('W1')), 4, 'create x2, submit and cancel are audited against W1');
select is((select count(*)::int from public.audit_log where action in ('supplier.save', 'supplier.archive')), 4,
  'three supplier saves (owner, wh1 x2) and the archive are audited');

-- ---------------------------------------------------------------------------
-- 6. The warehouse module must be on
-- ---------------------------------------------------------------------------
update public.tenant_modules set warehouse = false where tenant_id = pg_temp.tid('X');
select pg_temp.login('owner');
set local role authenticated;
select is(pg_temp.try(format($$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $$,
    pg_temp.poid('m'), pg_temp.lid('W1'), pg_temp.sid('A'), pg_temp.items()::text)) <> 'ok', true, 'ordering is refused when the warehouse module is off');
reset role;

select * from finish();
rollback;
