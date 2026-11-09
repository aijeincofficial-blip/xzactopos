-- 038_goods_receipts.test.sql: F-13d. Receive a delivery against a purchase order (partial, complete, over), receive without a PO, short-close.
begin;
select plan(96);

-- ---------------------------------------------------------------------------
-- Fixtures: warehouses W1 (bins on) and W2, a store, users; tenant Y for the boundary
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p text) returns uuid language sql immutable as $$ select md5('tenant:GR:' || p)::uuid $$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$ select md5('user:GR:' || p)::uuid $$;
create function pg_temp.lid(p text) returns uuid language sql immutable as $$ select md5('loc:GR:' || p)::uuid $$;
create function pg_temp.vid(p text) returns uuid language sql immutable as $$ select md5('var:GR:' || p)::uuid $$;
create function pg_temp.sid(p text) returns uuid language sql immutable as $$ select md5('sup:GR:' || p)::uuid $$;
create function pg_temp.poid(p text) returns uuid language sql immutable as $$ select md5('po:GR:' || p)::uuid $$;
create function pg_temp.gid(p text) returns uuid language sql immutable as $$ select md5('grn:GR:' || p)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.tid('X'), 'GR Tenant X', 'gr-x', 'PHP'), (pg_temp.tid('Y'), 'GR Tenant Y', 'gr-y', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid('X'), true, true), (pg_temp.tid('Y'), true, true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('X')), (pg_temp.tid('Y'));
insert into auth.users (id, email) select pg_temp.uid(n), n || '@gr.invalid'
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
insert into public.products (id, tenant_id, name) values
  (md5('p:GR:1')::uuid, pg_temp.tid('X'), 'Rice 25kg'), (md5('p:GR:2')::uuid, pg_temp.tid('X'), 'Cooking oil'), (md5('p:GR:3')::uuid, pg_temp.tid('X'), 'Salt');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (pg_temp.vid('rice'), pg_temp.tid('X'), md5('p:GR:1')::uuid, 'RICE25', true),
  (pg_temp.vid('oil'),  pg_temp.tid('X'), md5('p:GR:2')::uuid, 'OIL1L', true),
  (pg_temp.vid('salt'), pg_temp.tid('X'), md5('p:GR:3')::uuid, 'SALT1', true);
insert into public.suppliers (id, tenant_id, name) values
  (pg_temp.sid('A'), pg_temp.tid('X'), 'Mega Rice Trading'), (pg_temp.sid('Y'), pg_temp.tid('Y'), 'Other Tenant Supplier');

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
-- delivery lines: nulls are left out
create function pg_temp.li(p_rice numeric default null, p_oil numeric default null, p_rice_cost bigint default null, p_salt numeric default null) returns jsonb language sql as $$
  select coalesce(jsonb_agg(x), '[]'::jsonb) from (
    select jsonb_strip_nulls(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', p_rice, 'unit_cost', p_rice_cost)) x where p_rice is not null
    union all select jsonb_build_object('variant_id', pg_temp.vid('oil'), 'qty', p_oil) where p_oil is not null
    union all select jsonb_build_object('variant_id', pg_temp.vid('salt'), 'qty', p_salt) where p_salt is not null) q
$$;
create function pg_temp.rcv(p_grn text, p_po text, p_items jsonb) returns text language sql as $$
  select pg_temp.try(format($q$ select public.receive_po(%L, %L, %L::jsonb, 'dock 3', 'DR-1001') $q$, pg_temp.gid(p_grn), pg_temp.poid(p_po), p_items::text))
$$;
create function pg_temp.mkpo(p_po text, p_rice numeric, p_oil numeric default null, p_sup text default 'A', p_wh text default 'W1') returns text language sql as $$
  select pg_temp.try(format($q$ select public.create_po(%L, %L, %L, null, null, %L::jsonb) $q$, pg_temp.poid(p_po), pg_temp.lid(p_wh), pg_temp.sid(p_sup),
    (select jsonb_agg(x) from (
      select jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', p_rice, 'unit_cost', 1000) x where p_rice is not null
      union all select jsonb_build_object('variant_id', pg_temp.vid('oil'), 'qty', p_oil, 'unit_cost', 5000) where p_oil is not null) q)::text))
$$;

-- W1 uses bins; nothing is on hand yet
select pg_temp.login('wh1');
set local role authenticated;
select lives_ok($$ select public.enable_warehouse_bins(pg_temp.lid('W1')) $$, 'wh1 turns on bins in W1');

-- PO1: rice 100 + oil 20; PO2: rice 10; PO3: rice 5 only; PO4: rice 100 (for short-closing); PO5 stays a draft
select is(pg_temp.mkpo('1', 100, 20), 'ok', 'PO1 drafted');
select is(pg_temp.mkpo('2', 10), 'ok', 'PO2 drafted');
select is(pg_temp.mkpo('3', 5), 'ok', 'PO3 drafted');
select is(pg_temp.mkpo('4', 100), 'ok', 'PO4 drafted');
select is(pg_temp.mkpo('5', 7), 'ok', 'PO5 drafted');
select lives_ok(format($$ select public.submit_po(%L) $$, pg_temp.poid('1')), 'PO1 ordered');
select lives_ok(format($$ select public.submit_po(%L) $$, pg_temp.poid('2')), 'PO2 ordered');
select lives_ok(format($$ select public.submit_po(%L) $$, pg_temp.poid('3')), 'PO3 ordered');
select lives_ok(format($$ select public.submit_po(%L) $$, pg_temp.poid('4')), 'PO4 ordered');
reset role;

-- ---------------------------------------------------------------------------
-- 1. A partial delivery against PO1: 60 rice at the invoice cost 1050
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
create temp table r1 as select public.receive_po(pg_temp.gid('a'), pg_temp.poid('1'), pg_temp.li(60, null, 1050), 'dock 3', 'DR-1001') as res;
grant all on r1 to authenticated;
select is((select res ->> 'po_status' from r1), 'partly_received', 'a partial delivery leaves the PO partly received');
select ok((select res ->> 'grn_no' ~ '^GRN-[0-9]{6}-0001$' from r1), 'the first receipt is numbered GRN-YYMMDD-0001');
select is((select (res ->> 'has_discrepancy')::boolean from r1), false, 'a delivery within the order is not a discrepancy');
reset role;

select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 60::numeric, 'W1 holds 60 rice');
select is((select avg_cost from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 1050::bigint, 'the invoice cost sets the average');
select is((select qty_received from public.po_items where po_id = pg_temp.poid('1') and variant_id = pg_temp.vid('rice')), 60::numeric, 'the PO line shows 60 received');
select is((select qty_received from public.po_items where po_id = pg_temp.poid('1') and variant_id = pg_temp.vid('oil')), 0::numeric, 'the oil line is untouched');
select is((select count(*)::int from public.stock_movements where ref_type = 'goods_receipt' and ref_id = pg_temp.gid('a')
            and type = 'receipt' and qty_delta = 60 and unit_cost = 1050 and created_by = pg_temp.uid('wh1')), 1,
  'one receipt movement points back to the goods receipt');
select is((select bsl.qty_on_hand from public.bin_stock_levels bsl join public.bins b on b.id = bsl.bin_id
            where b.warehouse_id = pg_temp.lid('W1') and b.code = 'RECEIVING' and bsl.variant_id = pg_temp.vid('rice')), 60::numeric,
  'the goods landed in the RECEIVING bin');
select ok((select delivery_ref = 'DR-1001' and not without_po and po_id = pg_temp.poid('1') and supplier_id = pg_temp.sid('A')
            and received_by = pg_temp.uid('wh1') from public.goods_receipts where id = pg_temp.gid('a')), 'the receipt records the PO, supplier, delivery number and who');

-- replay
select pg_temp.login('wh1');
set local role authenticated;
select is((public.receive_po(pg_temp.gid('a'), pg_temp.poid('1'), pg_temp.li(60, null, 1050), 'dock 3', 'DR-1001')) ->> 'replay', 'true', 'the same receipt id again is a replay');
reset role;
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 60::numeric, 'the replay added no stock');
select is((select qty_received from public.po_items where po_id = pg_temp.poid('1') and variant_id = pg_temp.vid('rice')), 60::numeric, 'and did not count twice on the PO');
select is((select count(*)::int from public.goods_receipts where tenant_id = pg_temp.tid('X')), 1, 'still one receipt');

-- ---------------------------------------------------------------------------
-- 2. Completing the order: 40 rice (no cost given: the PO cost 1000 is used) + 20 oil
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.rcv('b', '1', pg_temp.li(40, 20)), 'ok', 'the rest of the order arrives');
reset role;
select is((select status from public.purchase_orders where id = pg_temp.poid('1')), 'received', 'every line is complete: the PO is received');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 100::numeric, 'W1 rice is 100');
select is((select avg_cost from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 1030::bigint,
  'average cost blends (60*1050 + 40*1000) / 100 = 1030');
select is((select avg_cost from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('oil')), 5000::bigint, 'oil uses the PO cost 5000');
select ok((select grn_no ~ '-0002$' from public.goods_receipts where id = pg_temp.gid('b')), 'the second receipt is number 0002');
select is((select qty_remaining_before from public.goods_receipt_items where grn_id = pg_temp.gid('a') and variant_id = pg_temp.vid('rice')), 100::numeric,
  'the first delivery saw 100 rice still expected');
select is((select qty_remaining_before from public.goods_receipt_items where grn_id = pg_temp.gid('b') and variant_id = pg_temp.vid('rice')), 40::numeric,
  'the second delivery saw only 40 rice still expected (60 had arrived)');
select is((select bool_or(over_received) from public.goods_receipt_items where grn_id in (pg_temp.gid('a'), pg_temp.gid('b'))), false,
  'completing an order exactly is not an over-delivery');

select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.rcv('c', '1', pg_temp.li(1)), 'P0001:invalid_state', 'a received PO takes no more deliveries');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Over-delivery is accepted and flagged
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
create temp table r2 as select public.receive_po(pg_temp.gid('d'), pg_temp.poid('2'), pg_temp.li(15)) as res;
grant all on r2 to authenticated;
select is((select (res ->> 'has_discrepancy')::boolean from r2), true, '15 delivered against 10 ordered is flagged');
select is((select res ->> 'po_status' from r2), 'received', 'and the PO counts as received');
reset role;
select is((select qty_received from public.po_items where po_id = pg_temp.poid('2')), 15::numeric, 'the PO line shows the 15 actually received');
select ok((select i.over_received and i.qty_remaining_before = 10 from public.goods_receipt_items i where i.grn_id = pg_temp.gid('d')), 'the line records 10 were still expected');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 115::numeric, 'all 15 went into stock');

-- ---------------------------------------------------------------------------
-- 4. Refusals
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.rcv('e', '3', pg_temp.li(null, 4)), 'P0001:not_on_po', 'a product that is not on the PO is refused');
select is(pg_temp.rcv('e', '3', pg_temp.li(0)), '22023:qty_invalid', 'zero quantity is refused');
select is(pg_temp.rcv('e', '3', '[]'::jsonb), '22023:items_required', 'an empty delivery is refused');
select is(pg_temp.rcv('e', '3', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 1), jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 1))),
  '22023:duplicate_item', 'the same product twice is refused');
select is(pg_temp.rcv('e', '3', pg_temp.li(2, null, -1)), '22023:invalid_value', 'a negative cost is refused');
select is(pg_temp.rcv('e', '5', pg_temp.li(1)), 'P0001:invalid_state', 'a draft PO cannot receive goods');
select is(pg_temp.rcv('e', 'nope', pg_temp.li(1)), '22023:not_found', 'an unknown PO is not found');
select is(pg_temp.rcv('a', '3', pg_temp.li(1)), 'P0001:id_conflict', 'a receipt id already used for another PO is refused');
-- all-or-nothing: line 1 is fine, line 2 is not on the PO
select is(pg_temp.rcv('f', '3', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 2), jsonb_build_object('variant_id', pg_temp.vid('oil'), 'qty', 1))),
  'P0001:not_on_po', 'a delivery with one bad line is refused as a whole');
reset role;
select is((select qty_received from public.po_items where po_id = pg_temp.poid('3')), 0::numeric, 'nothing of the refused delivery reached the PO');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 115::numeric, 'nor the stock');
select is((select count(*)::int from public.goods_receipts where id in (pg_temp.gid('e'), pg_temp.gid('f'))), 0, 'and no receipt was written');

select pg_temp.login('wh2');
set local role authenticated;
select is(pg_temp.rcv('g', '3', pg_temp.li(1)), '42501:location_denied', 'a user of W2 cannot receive against a W1 PO');
reset role;
select pg_temp.login('maria');
set local role authenticated;
select is(pg_temp.rcv('g', '3', pg_temp.li(1)), '42501:not_allowed', 'a store admin cannot receive goods');
reset role;
select pg_temp.login('juan');
set local role authenticated;
select is(pg_temp.rcv('g', '3', pg_temp.li(1)), '42501:not_allowed', 'a cashier cannot receive goods');
reset role;

-- a cancelled PO takes nothing
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.mkpo('6', 3), 'ok', 'PO6 drafted');
select lives_ok(format($$ select public.submit_po(%L) $$, pg_temp.poid('6')), 'PO6 ordered');
select lives_ok(format($$ select public.cancel_po(%L, 'wrong supplier') $$, pg_temp.poid('6')), 'PO6 cancelled');
select is(pg_temp.rcv('h', '6', pg_temp.li(1)), 'P0001:invalid_state', 'a cancelled PO cannot receive goods');
reset role;

-- ---------------------------------------------------------------------------
-- 5. Receiving without a PO
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$ select public.receive_without_po(%L, %L, %L, %L::jsonb, 'walk-in', 'DR-77') $$,
  pg_temp.gid('n1'), pg_temp.lid('W1'), pg_temp.sid('A'), pg_temp.li(null, null, null, 10)::text)), 'ok', 'a delivery with no PO is accepted');
select is(pg_temp.try(format($$ select public.receive_without_po(%L, %L, null, %L::jsonb) $$,
  pg_temp.gid('n2'), pg_temp.lid('W1'), jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty', 5, 'unit_cost', 1200))::text)), 'ok',
  'a supplier is optional');
select is(pg_temp.try(format($$ select public.receive_without_po(%L, %L, null, %L::jsonb) $$,
  pg_temp.gid('n3'), pg_temp.lid('W2'), pg_temp.li(1)::text)), '42501:location_denied', 'wh1 cannot receive without a PO into W2');
select is(pg_temp.try(format($$ select public.receive_without_po(%L, %L, null, %L::jsonb) $$,
  pg_temp.gid('n3'), pg_temp.lid('S1'), pg_temp.li(1)::text)), '42501:location_denied', 'nor into a store');
select is(pg_temp.try(format($$ select public.receive_without_po(%L, %L, %L, %L::jsonb) $$,
  pg_temp.gid('n3'), pg_temp.lid('W1'), pg_temp.sid('Y'), pg_temp.li(1)::text)), '22023:supplier_not_found', 'a supplier of another tenant is refused');
select is(pg_temp.try(format($$ select public.receive_without_po(%L, %L, null, '[]'::jsonb) $$, pg_temp.gid('n3'), pg_temp.lid('W1'))),
  '22023:items_required', 'an empty delivery is refused');
reset role;
select pg_temp.login('owner');
set local role authenticated;
select is(pg_temp.try(format($$ select public.receive_without_po(%L, %L, null, %L::jsonb) $$,
  pg_temp.gid('n3'), pg_temp.lid('S1'), pg_temp.li(1)::text)), '22023:not_a_warehouse', 'even the owner cannot receive goods into a store here');
reset role;
select ok((select without_po and po_id is null and supplier_id = pg_temp.sid('A') from public.goods_receipts where id = pg_temp.gid('n1')), 'the receipt is flagged as having no PO');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('salt')), 10::numeric, 'the salt is in stock');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 120::numeric, 'and 5 more rice (115 + 5)');
select is((select count(*)::int from public.audit_log where action = 'grn.receive_no_po' and location_id = pg_temp.lid('W1')), 2, 'both no-PO receipts are audited as such');

-- ---------------------------------------------------------------------------
-- 6. Short-closing: PO4 ordered 100 rice, only 60 will ever come
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$ select public.close_po(%L, 'supplier cannot deliver the rest') $$, pg_temp.poid('4'))), 'P0001:nothing_received', 'a PO with no goods is cancelled, not closed');
select is(pg_temp.rcv('i', '4', pg_temp.li(60)), 'ok', '60 of 100 arrive');
reset role;
select is((select status from public.purchase_orders where id = pg_temp.poid('4')), 'partly_received', 'PO4 is partly received');

select pg_temp.login('wh2');
set local role authenticated;
select is(pg_temp.try(format($$ select public.close_po(%L, 'x') $$, pg_temp.poid('4'))), '42501:location_denied', 'wh2 cannot close W1''s PO');
reset role;
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.try(format($$ select public.close_po(%L, 'supplier cannot deliver the rest') $$, pg_temp.poid('4'))), 'ok', 'wh1 closes PO4 short');
select is(pg_temp.try(format($$ select public.close_po(%L, 'again') $$, pg_temp.poid('4'))), 'ok', 'closing again is harmless');
select is(pg_temp.rcv('j', '4', pg_temp.li(1)), 'P0001:invalid_state', 'a closed PO takes no more goods');
select is(pg_temp.try(format($$ select public.close_po(%L, 'x') $$, pg_temp.poid('5'))), 'P0001:invalid_state', 'a draft PO cannot be closed');
reset role;
select ok((select status = 'received' and short_closed_at is not null and short_closed_by = pg_temp.uid('wh1') and close_reason = 'supplier cannot deliver the rest'
            from public.purchase_orders where id = pg_temp.poid('4')), 'the PO is received, marked short-closed with who and why');
select is((select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 180::numeric, 'closing short did not touch stock (120 + 60)');

-- ---------------------------------------------------------------------------
-- 7. Who sees receipts
-- ---------------------------------------------------------------------------
select pg_temp.login('wh2');
set local role authenticated;
select is((select count(*)::int from public.goods_receipts) + (select count(*)::int from public.goods_receipt_items), 0, 'wh2 sees no receipts or lines of W1');
reset role;
select pg_temp.login('wh1');
set local role authenticated;
select is((select count(*)::int from public.goods_receipts), 6, 'wh1 sees the six receipts of W1');
reset role;
select pg_temp.login('maria');
set local role authenticated;
select is((select count(*)::int from public.goods_receipts) + (select count(*)::int from public.goods_receipt_items), 0, 'a store admin sees none');
reset role;
select pg_temp.login('ownerY');
set local role authenticated;
select is((select count(*)::int from public.goods_receipts) + (select count(*)::int from public.goods_receipt_items), 0, 'tenant Y sees none');
reset role;
select pg_temp.login('owner');
set local role authenticated;
select is((select count(*)::int from public.goods_receipts), 6, 'the owner sees all');
select throws_ok($$ insert into public.goods_receipts (tenant_id, grn_no, warehouse_id, without_po) values (md5('tenant:GR:X')::uuid, 'GRN-HACK', md5('loc:GR:W1')::uuid, true) $$,
  '42501', null, 'nobody inserts receipts directly');
select throws_ok($$ update public.po_items set qty_received = 0 $$, '42501', null, 'nor edits received quantities');
reset role;

-- ---------------------------------------------------------------------------
-- 8. Ledger and schema guards
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.check_bin_stock_invariant(pg_temp.lid('W1')) where not is_valid), 0, 'W1 bins still add up to W1 stock');
select is((select sum(qty_delta) from public.stock_movements where ref_type = 'goods_receipt' and location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')),
  (select sum(i.qty) from public.goods_receipt_items i where i.variant_id = pg_temp.vid('rice')),
  'rice movements from receipts equal the rice on the receipt lines');
select throws_ok(format($$ update public.goods_receipts set notes = 'edited' where id = %L $$, pg_temp.gid('a')), null, null, 'a receipt cannot be edited');
select throws_ok(format($$ delete from public.goods_receipt_items where grn_id = %L $$, pg_temp.gid('a')), null, null, 'receipt lines cannot be deleted');
select throws_ok(format($$ insert into public.goods_receipts (tenant_id, grn_no, warehouse_id, without_po) values (%L, (select grn_no from public.goods_receipts where id = %L), %L, true) $$,
  pg_temp.tid('X'), pg_temp.gid('a'), pg_temp.lid('W2')), '23505', null, 'receipt numbers are unique per tenant');
select throws_ok(format($$ insert into public.goods_receipts (tenant_id, grn_no, warehouse_id, without_po) values (%L, 'GRN-BAD', %L, true) $$,
  pg_temp.tid('X'), pg_temp.lid('S1')), null, null, 'a receipt cannot be addressed to a store');
select throws_ok(format($$ insert into public.goods_receipts (tenant_id, grn_no, warehouse_id, po_id, without_po) values (%L, 'GRN-BAD2', %L, %L, true) $$,
  pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.poid('1')), '23514', null, 'without_po must agree with po_id');

select is((select count(*)::int from public.audit_log where action = 'grn.receive' and location_id = pg_temp.lid('W1')), 4, 'four PO receipts are audited (a, b, d, i)');
select is((select count(*)::int from public.audit_log where action = 'po.close' and location_id = pg_temp.lid('W1')), 1, 'the short-close is audited once');

-- ---------------------------------------------------------------------------
-- 9. The warehouse module must be on
-- ---------------------------------------------------------------------------
update public.tenant_modules set warehouse = false where tenant_id = pg_temp.tid('X');
select pg_temp.login('owner');
set local role authenticated;
select isnt(pg_temp.rcv('k', '3', pg_temp.li(1)), 'ok', 'receiving is refused when the warehouse module is off');
reset role;

select * from finish();
rollback;
