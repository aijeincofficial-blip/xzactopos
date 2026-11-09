-- 039_warehouse_counts.test.sql: F-13e. Stock counts in a warehouse (whole warehouse or one bin), applied as count_correction movements.
begin;
select plan(109);

-- ---------------------------------------------------------------------------
-- Fixtures. W1: no bins. W2: bins (RECEIVING + B-01). Stock is put in as the system owner.
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p text) returns uuid language sql immutable as $$ select md5('tenant:SC:' || p)::uuid $$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$ select md5('user:SC:' || p)::uuid $$;
create function pg_temp.lid(p text) returns uuid language sql immutable as $$ select md5('loc:SC:' || p)::uuid $$;
create function pg_temp.vid(p text) returns uuid language sql immutable as $$ select md5('var:SC:' || p)::uuid $$;
create function pg_temp.cid(p text) returns uuid language sql immutable as $$ select md5('cnt:SC:' || p)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.tid('X'), 'SC Tenant X', 'sc-x', 'PHP'), (pg_temp.tid('Y'), 'SC Tenant Y', 'sc-y', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid('X'), true, true), (pg_temp.tid('Y'), true, true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('X')), (pg_temp.tid('Y'));
insert into auth.users (id, email) select pg_temp.uid(n), n || '@sc.invalid' from unnest(array['owner', 'wh1', 'wh2', 'maria', 'juan', 'ownerY']) n;
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
  (md5('p:SC:1')::uuid, pg_temp.tid('X'), 'Rice 25kg'), (md5('p:SC:2')::uuid, pg_temp.tid('X'), 'Cooking oil'), (md5('p:SC:3')::uuid, pg_temp.tid('X'), 'Salt');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (pg_temp.vid('rice'), pg_temp.tid('X'), md5('p:SC:1')::uuid, 'RICE25', true),
  (pg_temp.vid('oil'),  pg_temp.tid('X'), md5('p:SC:2')::uuid, 'OIL1L', true),
  (pg_temp.vid('salt'), pg_temp.tid('X'), md5('p:SC:3')::uuid, 'SALT1', true);

insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('rice'), 100, 'receipt', 1000),
  (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('oil'),   20, 'receipt', 5000),
  (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('salt'),   7, 'receipt', 300),
  (pg_temp.tid('X'), pg_temp.lid('W2'), pg_temp.vid('rice'),  50, 'receipt', 1000),
  (pg_temp.tid('X'), pg_temp.lid('W2'), pg_temp.vid('oil'),   10, 'receipt', 5000);

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
create function pg_temp.bin(p_wh text, p_code text) returns uuid language sql stable as $$
  select id from public.bins where warehouse_id = pg_temp.lid(p_wh) and code = p_code
$$;
-- one count line
create function pg_temp.cl(p_var text, p_qty numeric, p_bin uuid default null) returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('variant_id', pg_temp.vid(p_var), 'qty_counted', p_qty, 'bin_id', p_bin))
$$;
create function pg_temp.start(p_cnt text, p_wh text, p_bin uuid default null) returns text language sql as $$
  select pg_temp.try(format($q$ select public.start_count(%L, %L, %L) $q$, pg_temp.cid(p_cnt), pg_temp.lid(p_wh), p_bin))
$$;
create function pg_temp.rec(p_cnt text, p_items jsonb) returns text language sql as $$
  select pg_temp.try(format($q$ select public.record_count(%L, %L::jsonb) $q$, pg_temp.cid(p_cnt), p_items::text))
$$;
create function pg_temp.fin(p_cnt text, p_zero boolean default false) returns text language sql as $$
  select pg_temp.try(format($q$ select public.close_count(%L, %L) $q$, pg_temp.cid(p_cnt), p_zero))
$$;
create function pg_temp.qty(p_wh text, p_var text) returns numeric language sql stable as $$
  select qty_on_hand from public.stock_levels where location_id = pg_temp.lid(p_wh) and variant_id = pg_temp.vid(p_var)
$$;
create function pg_temp.binqty(p_wh text, p_code text, p_var text) returns numeric language sql stable as $$
  select coalesce((select qty_on_hand from public.bin_stock_levels where bin_id = pg_temp.bin(p_wh, p_code) and variant_id = pg_temp.vid(p_var)), 0)
$$;

-- W2 gets bins: rice 30 in RECEIVING and 20 in B-01, oil 10 in RECEIVING
select pg_temp.login('wh2');
set local role authenticated;
select lives_ok($$ select public.enable_warehouse_bins(pg_temp.lid('W2')) $$, 'wh2 turns on bins in W2');
select lives_ok($$ select public.upsert_warehouse_bin(pg_temp.lid('W2'), 'B-01') $$, 'wh2 adds bin B-01');
select lives_ok($$ select public.execute_putaway(pg_temp.lid('W2'), pg_temp.bin('W2', 'RECEIVING'), pg_temp.bin('W2', 'B-01'), pg_temp.vid('rice'), 20) $$, 'wh2 puts 20 rice into B-01');
reset role;

-- ---------------------------------------------------------------------------
-- 1. Starting a count
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.start('c1', 'W1'), 'ok', 'wh1 starts a count of W1');
select is(pg_temp.start('c1', 'W1'), 'ok', 'starting with the same id again is a replay');
select is(pg_temp.start('cx', 'W1'), 'P0001:count_in_progress', 'a warehouse has one open count at a time');
reset role;
select pg_temp.login('wh2');
set local role authenticated;
select is(pg_temp.start('c1', 'W2'), 'P0001:id_conflict', 'a count id already used for another warehouse is refused');
reset role;
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.start('cx', 'W2'), '42501:location_denied', 'wh1 cannot count W2');
select is(pg_temp.start('cx', 'S1'), '42501:location_denied', 'wh1 cannot count a store here');
select is(pg_temp.try(format($$ select public.start_count(%L, %L, %L) $$, pg_temp.cid('cx'), pg_temp.lid('W1'), md5('bin')::uuid)), '22023:bins_not_enabled',
  'a bin count needs a warehouse that uses bins');
reset role;
select pg_temp.login('owner');
set local role authenticated;
select is(pg_temp.start('cx', 'S1'), '22023:not_a_warehouse', 'even the owner cannot count a store here');
reset role;
select pg_temp.login('maria');
set local role authenticated;
select is(pg_temp.start('cx', 'W1'), '42501:not_allowed', 'a store admin cannot start a count');
reset role;
select pg_temp.login('juan');
set local role authenticated;
select is(pg_temp.start('cx', 'W1'), '42501:not_allowed', 'a cashier cannot start a count');
reset role;
select ok((select count_no ~ '^CNT-[0-9]{6}-0001$' and status = 'open' and started_by = pg_temp.uid('wh1') and bin_id is null
           from public.stock_counts where id = pg_temp.cid('c1')), 'the count is open, numbered CNT-YYMMDD-0001, and records who started it');
select is((select count(*)::int from public.stock_counts where tenant_id = pg_temp.tid('X')), 1, 'refused starts left no trace');

-- ---------------------------------------------------------------------------
-- 2. Recording what was counted: rice 97 (system 100), oil 20 (system 20), salt 9 (system 7)
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.rec('c1', jsonb_build_array(pg_temp.cl('rice', 97), pg_temp.cl('oil', 20), pg_temp.cl('salt', 9))), 'ok', 'wh1 records three counted lines');
reset role;
select is((select count(*)::int from public.stock_count_items where count_id = pg_temp.cid('c1')), 3, 'three lines');
select is((select qty_system from public.stock_count_items where count_id = pg_temp.cid('c1') and variant_id = pg_temp.vid('rice')), 100::numeric,
  'the line remembers the system quantity at the moment it was counted');
select is((select qty_counted from public.stock_count_items where count_id = pg_temp.cid('c1') and variant_id = pg_temp.vid('salt')), 9::numeric, 'and the counted quantity');
select is(pg_temp.qty('W1', 'rice'), 100::numeric, 'recording a count does not change stock');
select is((select count(*)::int from public.stock_movements where ref_type = 'stock_count'), 0, 'and writes no movement');

select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.rec('c1', jsonb_build_array(pg_temp.cl('rice', 98))), 'ok', 'counting a product again replaces its line');
select is(pg_temp.rec('c1', jsonb_build_array(pg_temp.cl('rice', 97))), 'ok', 'and the last word stands');
select is(pg_temp.rec('c1', jsonb_build_array(pg_temp.cl('rice', -1))), '22023:qty_invalid', 'a negative count is refused');
select is(pg_temp.rec('c1', jsonb_build_array(pg_temp.cl('rice', 1000000000))), '22023:qty_invalid', 'an absurd count is refused');
select is(pg_temp.rec('c1', '[]'::jsonb), '22023:items_required', 'an empty list is refused');
select is(pg_temp.rec('c1', jsonb_build_array(jsonb_build_object('variant_id', md5('nope')::uuid, 'qty_counted', 1))), '22023:unknown_variant', 'an unknown product is refused');
select is(pg_temp.rec('c1', jsonb_build_array(pg_temp.cl('rice', 1), pg_temp.cl('rice', 2))), '22023:duplicate_item', 'the same product twice in one call is refused');
select is(pg_temp.rec('c1', jsonb_build_array(pg_temp.cl('rice', 1, md5('bin')::uuid))), '22023:bin_not_allowed', 'a bin on a warehouse without bins is refused');
-- all-or-nothing
select is(pg_temp.rec('c1', jsonb_build_array(pg_temp.cl('oil', 5), pg_temp.cl('salt', -2))), '22023:qty_invalid', 'a call with one bad line is refused as a whole');
reset role;
select is((select qty_counted from public.stock_count_items where count_id = pg_temp.cid('c1') and variant_id = pg_temp.vid('oil')), 20::numeric, 'the good line of that call was not saved');
select is((select count(*)::int from public.stock_count_items where count_id = pg_temp.cid('c1')), 3, 'still three lines');

select pg_temp.login('wh2');
set local role authenticated;
select is(pg_temp.rec('c1', jsonb_build_array(pg_temp.cl('rice', 1))), '42501:location_denied', 'wh2 cannot record into W1''s count');
select is(pg_temp.fin('c1'), '42501:location_denied', 'nor close it');
reset role;

-- a delivery arrives while the count is open: +10 rice (system 110)
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost)
  values (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('rice'), 10, 'receipt', 1000);
select is(pg_temp.qty('W1', 'rice'), 110::numeric, 'a late delivery makes the system 110');

-- ---------------------------------------------------------------------------
-- 3. Closing: the correction is counted minus the system quantity AT COUNT TIME, so the late delivery survives
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
create temp table close1 as select public.close_count(pg_temp.cid('c1')) as res;
grant all on close1 to authenticated;
select is((select res ->> 'corrections' from close1), '2', 'two products needed a correction (oil matched)');
select is((select res ->> 'net_variance' from close1), '-1', 'net variance is -3 rice + 2 salt = -1');
reset role;
select is(pg_temp.qty('W1', 'rice'), 107::numeric, 'rice is 107: the 97 counted plus the 10 that arrived later');
select is(pg_temp.qty('W1', 'salt'), 9::numeric, 'salt is 9');
select is(pg_temp.qty('W1', 'oil'), 20::numeric, 'oil is untouched');
select is((select avg_cost from public.stock_levels where location_id = pg_temp.lid('W1') and variant_id = pg_temp.vid('rice')), 1000::bigint, 'a correction does not change the average cost');
select is((select count(*)::int from public.stock_movements where ref_type = 'stock_count' and ref_id = pg_temp.cid('c1') and type = 'count_correction'), 2,
  'two count_correction movements, none for the matching product');
select is((select qty_delta from public.stock_movements where ref_id = pg_temp.cid('c1') and variant_id = pg_temp.vid('rice')), -3::numeric, 'the rice correction is -3');
select is((select created_by from public.stock_movements where ref_id = pg_temp.cid('c1') and variant_id = pg_temp.vid('rice')), pg_temp.uid('wh1'), 'attributed to the closer');
select ok((select status = 'closed' and closed_by = pg_temp.uid('wh1') and closed_at is not null from public.stock_counts where id = pg_temp.cid('c1')), 'the count is closed with who and when');
select is((select qty_variance from public.stock_count_items where count_id = pg_temp.cid('c1') and variant_id = pg_temp.vid('rice')), -3::numeric, 'the line keeps its variance');

select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.fin('c1'), 'ok', 'closing again is harmless');
select is(pg_temp.rec('c1', jsonb_build_array(pg_temp.cl('rice', 1))), 'P0001:invalid_state', 'a closed count takes no more lines');
reset role;
select is((select count(*)::int from public.stock_movements where ref_id = pg_temp.cid('c1')), 2, 'the second close wrote nothing');
select is(pg_temp.qty('W1', 'rice'), 107::numeric, 'and stock did not move');

-- ---------------------------------------------------------------------------
-- 4. A full count: products left out are treated as zero when asked
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.start('c2', 'W1'), 'ok', 'a new count can start once the last one is closed');
select is(pg_temp.rec('c2', jsonb_build_array(pg_temp.cl('rice', 107))), 'ok', 'only rice is counted');
reset role;
-- 5 more sacks arrive after rice was counted; the shelf is counted again and now shows 112
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost)
  values (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('rice'), 5, 'receipt', 1000);
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.rec('c2', jsonb_build_array(pg_temp.cl('rice', 112))), 'ok', 'rice is counted again after the delivery: 112');
create temp table close2 as select public.close_count(pg_temp.cid('c2'), true) as res;
grant all on close2 to authenticated;
select is((select res ->> 'corrections' from close2), '2', 'oil and salt were not found, so they are zeroed');
select is((select res ->> 'zeroed' from close2), '2', 'and reported as zeroed');
reset role;
select is(pg_temp.qty('W1', 'oil'), 0::numeric, 'oil is 0');
select is(pg_temp.qty('W1', 'salt'), 0::numeric, 'salt is 0');
select is(pg_temp.qty('W1', 'rice'), 112::numeric, 'rice, which matched the recount, is unchanged at 112 (a stale snapshot would add 5)');
select is((select qty_system from public.stock_count_items where count_id = pg_temp.cid('c2') and variant_id = pg_temp.vid('rice')), 112::numeric,
  'a recount refreshes the system quantity the line is measured against');
select is((select count(*)::int from public.stock_count_items where count_id = pg_temp.cid('c2') and auto_zero), 2, 'the zeroed lines are marked as automatic');
select is((select qty_variance from public.stock_count_items where count_id = pg_temp.cid('c2') and variant_id = pg_temp.vid('oil')), -20::numeric, 'oil variance -20');

-- closing with nothing counted
select pg_temp.login('wh1');
set local role authenticated;
select is(pg_temp.start('c3', 'W1'), 'ok', 'another count starts');
select is(pg_temp.fin('c3'), '22023:nothing_counted', 'a count with no lines cannot be closed');
-- cancel
select is(pg_temp.try(format($$ select public.cancel_count(%L, 'wrong day') $$, pg_temp.cid('c3'))), 'ok', 'an open count can be cancelled');
select is(pg_temp.try(format($$ select public.cancel_count(%L, 'again') $$, pg_temp.cid('c3'))), 'ok', 'cancelling again is harmless');
select is(pg_temp.rec('c3', jsonb_build_array(pg_temp.cl('rice', 1))), 'P0001:invalid_state', 'a cancelled count takes no lines');
select is(pg_temp.fin('c3'), 'P0001:invalid_state', 'and cannot be closed');
select is(pg_temp.try(format($$ select public.cancel_count(%L, 'x') $$, pg_temp.cid('c1'))), 'P0001:invalid_state', 'a closed count cannot be cancelled');
select is(pg_temp.start('c4', 'W1'), 'ok', 'a cancelled count frees the warehouse for a new one');
reset role;
select ok((select status = 'cancelled' and cancelled_by = pg_temp.uid('wh1') and cancel_reason = 'wrong day' from public.stock_counts where id = pg_temp.cid('c3')), 'the cancellation keeps who and why');

-- ---------------------------------------------------------------------------
-- 5. Bins: a count of one bin touches only that bin
-- ---------------------------------------------------------------------------
select pg_temp.login('wh2');
set local role authenticated;
select is(pg_temp.try(format($$ select public.cancel_count(%L, 'not mine') $$, pg_temp.cid('c4'))), '42501:location_denied', 'wh2 cannot cancel W1''s open count');
select is(pg_temp.start('c5', 'W2', pg_temp.bin('W2', 'B-01')), 'ok', 'wh2 starts a count of bin B-01');
select is(pg_temp.rec('c5', jsonb_build_array(pg_temp.cl('rice', 18))), '22023:bin_required', 'a warehouse with bins needs the bin on every line');
select is(pg_temp.rec('c5', jsonb_build_array(pg_temp.cl('rice', 18, pg_temp.bin('W2', 'RECEIVING')))), '22023:bin_out_of_scope', 'a line outside the counted bin is refused');
select is(pg_temp.rec('c5', jsonb_build_array(pg_temp.cl('rice', 18, md5('nobin')::uuid))), '22023:bin_not_found', 'a bin that is not in this warehouse is refused');
select is(pg_temp.rec('c5', jsonb_build_array(pg_temp.cl('rice', 18, pg_temp.bin('W2', 'B-01')))), 'ok', 'rice in B-01 is counted as 18 (system 20)');
select is(pg_temp.fin('c5', true), 'ok', 'wh2 closes the bin count, zeroing what it did not find in that bin');
reset role;
select is(pg_temp.binqty('W2', 'B-01', 'rice'), 18::numeric, 'B-01 now holds 18');
select is(pg_temp.binqty('W2', 'RECEIVING', 'rice'), 30::numeric, 'RECEIVING rice is untouched');
select is(pg_temp.binqty('W2', 'RECEIVING', 'oil'), 10::numeric, 'RECEIVING oil is untouched by a count of another bin');
select is(pg_temp.qty('W2', 'rice'), 48::numeric, 'the warehouse total follows: 30 + 18');
select is((select count(*)::int from public.check_bin_stock_invariant(pg_temp.lid('W2')) where not is_valid), 0, 'bins still add up to W2 stock');

select pg_temp.login('wh2');
set local role authenticated;
select is(pg_temp.start('c6', 'W2'), 'ok', 'a whole-warehouse count of W2');
select is(pg_temp.rec('c6', jsonb_build_array(pg_temp.cl('rice', 31, pg_temp.bin('W2', 'RECEIVING')), pg_temp.cl('rice', 18, pg_temp.bin('W2', 'B-01')))), 'ok',
  'rice counted in two bins: 31 in RECEIVING (system 30), 18 in B-01');
create temp table close6 as select public.close_count(pg_temp.cid('c6'), true) as res;
grant all on close6 to authenticated;
select is((select res ->> 'corrections' from close6), '2', 'rice +1 in RECEIVING and the unfound oil zeroed; B-01 matched');
reset role;
select is(pg_temp.binqty('W2', 'RECEIVING', 'rice'), 31::numeric, 'RECEIVING rice is 31');
select is(pg_temp.binqty('W2', 'RECEIVING', 'oil'), 0::numeric, 'RECEIVING oil is zeroed');
select is(pg_temp.qty('W2', 'rice'), 49::numeric, 'W2 rice is 49');
select is(pg_temp.qty('W2', 'oil'), 0::numeric, 'W2 oil is 0');
select is((select count(*)::int from public.check_bin_stock_invariant(pg_temp.lid('W2')) where not is_valid), 0, 'bins still add up after the full count');
select is((select bin_id from public.stock_movements where ref_id = pg_temp.cid('c6') and variant_id = pg_temp.vid('rice')), pg_temp.bin('W2', 'RECEIVING'),
  'the correction landed in the bin that was counted');

-- ---------------------------------------------------------------------------
-- 6. Who sees counts
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');
set local role authenticated;
select is((select count(*)::int from public.stock_counts), 4, 'wh1 sees the four counts of W1');
select is((select count(*)::int from public.stock_count_items), 6, 'and their six lines');
reset role;
select pg_temp.login('wh2');
set local role authenticated;
select is((select count(*)::int from public.stock_counts), 2, 'wh2 sees only W2''s two counts');
reset role;
select pg_temp.login('maria');
set local role authenticated;
select is((select count(*)::int from public.stock_counts) + (select count(*)::int from public.stock_count_items), 0, 'a store admin sees none');
reset role;
select pg_temp.login('juan');
set local role authenticated;
select is((select count(*)::int from public.stock_counts) + (select count(*)::int from public.stock_count_items), 0, 'a cashier sees none');
reset role;
select pg_temp.login('ownerY');
set local role authenticated;
select is((select count(*)::int from public.stock_counts) + (select count(*)::int from public.stock_count_items), 0, 'tenant Y sees none');
reset role;
select pg_temp.login('owner');
set local role authenticated;
select is((select count(*)::int from public.stock_counts), 6, 'the owner sees all six');
select throws_ok($$ insert into public.stock_counts (tenant_id, count_no, warehouse_id) values (md5('tenant:SC:X')::uuid, 'CNT-HACK', md5('loc:SC:W1')::uuid) $$, '42501', null, 'nobody inserts counts directly');
select throws_ok($$ update public.stock_count_items set qty_counted = 0 $$, '42501', null, 'nor edits count lines');
reset role;

-- ---------------------------------------------------------------------------
-- 7. Schema guards and audit
-- ---------------------------------------------------------------------------
select throws_ok(format($$ insert into public.stock_counts (tenant_id, count_no, warehouse_id) values (%L, 'CNT-BAD', %L) $$, pg_temp.tid('X'), pg_temp.lid('S1')),
  null, null, 'a count cannot be addressed to a store');
select throws_ok(format($$ insert into public.stock_counts (tenant_id, count_no, warehouse_id) values (%L, (select count_no from public.stock_counts where id = %L), %L) $$,
  pg_temp.tid('X'), pg_temp.cid('c1'), pg_temp.lid('W2')), '23505', null, 'count numbers are unique per tenant');
select throws_ok(format($$ insert into public.stock_counts (tenant_id, count_no, warehouse_id, status) values (%L, 'CNT-DUP-OPEN', %L, 'open') $$,
  pg_temp.tid('X'), pg_temp.lid('W1')), '23505', null, 'the database also allows only one open count per warehouse');
select throws_ok(format($$ insert into public.stock_count_items (tenant_id, count_id, variant_id, qty_system, qty_counted) values (%L, %L, %L, 0, -1) $$,
  pg_temp.tid('X'), pg_temp.cid('c4'), pg_temp.vid('rice')), '23514', null, 'a negative counted quantity is refused by the table');
select throws_ok(format($$ insert into public.stock_count_items (tenant_id, count_id, variant_id, qty_system, qty_counted) values (%L, %L, %L, 0, 1) $$,
  pg_temp.tid('Y'), pg_temp.cid('c4'), pg_temp.vid('rice')), '23503', null, 'a line cannot point at another tenant''s count');
select is((select count(*)::int from public.audit_log where action = 'count.start'), 6, 'six counts were started and audited');
select is((select count(*)::int from public.audit_log where action = 'count.close'), 4, 'four closes are audited');
select is((select count(*)::int from public.audit_log where action = 'count.cancel'), 1, 'one cancel is audited');

-- ---------------------------------------------------------------------------
-- 8. The warehouse module must be on
-- ---------------------------------------------------------------------------
update public.tenant_modules set warehouse = false where tenant_id = pg_temp.tid('X');
select pg_temp.login('owner');
set local role authenticated;
select isnt(pg_temp.rec('c4', jsonb_build_array(pg_temp.cl('rice', 1))), 'ok', 'counting is refused when the warehouse module is off');
reset role;

select * from finish();
rollback;
