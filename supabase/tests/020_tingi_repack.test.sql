-- P8-08 tingi / repack: the pack -> piece link (validation, chains, tenants), open_pack / void_open_pack ops (movements,
-- derived levels, the cost rule, idempotency, refusals, permissions, audit), the conversions table (append-only, RLS),
-- sync_pull_conversions, the link in sync_pull_catalog, and a seeded property test: stock value is conserved within the
-- documented rounding bound, the piece average matches an independent calculation, a void restores both levels exactly,
-- and every level equals the sum of its movements.
begin;
select plan(102);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('id:' || p)::uuid $$;
create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;
create function pg_temp.push1(k text, kind text, payload jsonb) returns jsonb language sql as $$
  select public.sync_push(jsonb_build_array(
    jsonb_build_object('op_id', pg_temp.id('op:' || k), 'kind', kind, 'payload', payload))) -> 0
$$;
create function pg_temp.link(k text, pack text, piece text, ratio jsonb default '20') returns jsonb language sql as $$
  select pg_temp.push1(k, 'set_tingi_link', jsonb_build_object('variant_id', pg_temp.id('v:' || pack),
    'piece_variant_id', case when piece is null then null else pg_temp.id('v:' || piece) end, 'pieces_per_pack', ratio))
$$;
create function pg_temp.open(k text, conv text, pack text, packs jsonb, extra jsonb default '{}') returns jsonb language sql as $$
  select pg_temp.push1(k, 'open_pack', jsonb_build_object('id', pg_temp.id('c:' || conv), 'pack_variant_id', pg_temp.id('v:' || pack),
    'packs', packs, 'at', '2026-11-08T02:00:00Z') || extra)
$$;
create function pg_temp.vd(k text, conv text, reason text default null) returns jsonb language sql as $$
  select pg_temp.push1(k, 'void_open_pack', jsonb_strip_nulls(jsonb_build_object('conversion_id', pg_temp.id('c:' || conv), 'reason', reason)))
$$;
create function pg_temp.recv(k text, v text, qty numeric, cost bigint default null) returns jsonb language sql as $$
  select pg_temp.push1(k, 'receive_stock', jsonb_strip_nulls(jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'qty', qty, 'unit_cost', cost)))
$$;
create function pg_temp.sell(k text, v text, qty numeric) returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:' || k), 'local_no', 'R-' || k, 'sold_at', '2026-11-08T02:00:00Z',
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'qty', qty, 'unit_price', 100)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', round(qty * 100)::bigint))))
$$;
create function pg_temp.lvl(v text) returns numeric language sql as $$
  select qty_on_hand from public.stock_levels where variant_id = pg_temp.id('v:' || v)
$$;
create function pg_temp.avg(v text) returns bigint language sql as $$
  select avg_cost from public.stock_levels where variant_id = pg_temp.id('v:' || v)
$$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'sara', 'juan', 'pedro', 'ownerB']) n;
insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.t('A'), true, true), (pg_temp.t('B'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('sara'), pg_temp.t('A'), 'sara', 'admin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('pedro'), pg_temp.t('A'), 'pedro', 'warehouse', true),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'A1'),
  (pg_temp.id('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'AW'),
  (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'S01', 'B1');
-- maria: manager S01 (full catalog rights). sara: supervisor S01 only (no catalog rights). juan: cashier. pedro: warehouse.
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sara'), pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null);

insert into public.products (id, tenant_id, name, track_stock)
  select pg_temp.id('p:' || n), pg_temp.t('A'), n, n <> 'asin'
  from unnest(array['kaha', 'stick', 'shpack', 'sachet', 'asin', 'kape', 'gatas', 'tasa', 'xpack', 'xpiece', 'tmp']) n;
insert into public.products (id, tenant_id, name) values (pg_temp.id('p:b'), pg_temp.t('B'), 'B item');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost)
  select pg_temp.id('v:' || n), pg_temp.t('A'), pg_temp.id('p:' || n), upper(n), true, 0
  from unnest(array['kaha', 'stick', 'shpack', 'sachet', 'asin', 'kape', 'gatas', 'tasa', 'xpack', 'xpiece', 'tmp']) n;
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (pg_temp.id('v:b'), pg_temp.t('B'), pg_temp.id('p:b'), 'B1', true);

-- ===== the link =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.link('l1', 'kaha', 'stick', '20') ->> 'status', 'ok', 'the owner says a kaha breaks into 20 sticks');
select is((select (breaks_into_variant_id = pg_temp.id('v:stick'), breaks_into_qty)::text from public.product_variants
           where id = pg_temp.id('v:kaha')), '(t,20)', 'the pack variant carries the piece and the ratio');
select is(pg_temp.link('l1', 'kaha', 'stick', '20') -> 'result' ->> 'replay', 'true', 'a resent link is a replay');
select is(pg_temp.link('l1b', 'kaha', 'stick', '"20"') -> 'result' ->> 'changed', 'false', 'the same link again changes nothing (a digit string is fine)');
reset role;
select is((select count(*)::int from public.audit_log where action = 'product.tingi_link' and entity_id = pg_temp.id('v:kaha')), 1,
          'one audit row: replays and no-change sends write none');
select is((select (select array_agg(k order by k) from jsonb_object_keys(meta) k)::text from public.audit_log
           where action = 'product.tingi_link' and entity_id = pg_temp.id('v:kaha')),
          '{op_id,piece_variant_id,pieces_per_pack}', 'the link audit row has small meta');
set local role authenticated;
select is(pg_temp.link('l2', 'kaha', 'kaha') ->> 'hint', 'link_self', 'a pack cannot break into itself');
select is(pg_temp.link('l3', 'shpack', 'sachet', '0') ->> 'hint', 'ratio_invalid', 'zero pieces per pack is refused');
select is(pg_temp.link('l4', 'shpack', 'sachet', '2.5') ->> 'hint', 'ratio_invalid', 'a fractional ratio is refused');
select is(pg_temp.link('l5', 'shpack', 'sachet', '10001') ->> 'hint', 'ratio_invalid', 'a ratio over 10000 is refused');
select is(pg_temp.link('l6', 'shpack', 'sachet', 'null') ->> 'hint', 'ratio_invalid', 'a link needs a ratio');
select is(pg_temp.link('l7', 'stick', 'sachet') ->> 'hint', 'link_chain', 'a piece cannot also be a pack (no chains)');
select is(pg_temp.link('l8', 'shpack', 'kaha') ->> 'hint', 'link_chain', 'a pack cannot also be a piece (no chains)');
select is(pg_temp.link('l9', 'stick', 'kaha') ->> 'hint', 'link_chain', 'no two-way link (cycle)');
select is(pg_temp.push1('l10', 'set_tingi_link', jsonb_build_object('variant_id', pg_temp.id('v:shpack'),
          'piece_variant_id', pg_temp.id('v:b'), 'pieces_per_pack', 5)) ->> 'hint', 'unknown_variant',
          'a piece of another tenant is unknown');
select is(pg_temp.link('l11', 'shpack', 'asin') ->> 'hint', 'not_tracked', 'a piece that keeps no stock count is refused');
select is(pg_temp.link('l12', 'asin', 'sachet') ->> 'hint', 'not_tracked', 'a pack that keeps no stock count is refused');
select is(pg_temp.push1('l13', 'set_tingi_link', jsonb_build_object('variant_id', pg_temp.id('v:nope'),
          'piece_variant_id', pg_temp.id('v:sachet'), 'pieces_per_pack', 5)) ->> 'hint', 'unknown_variant', 'an unknown pack is refused');
select is(pg_temp.link('l14', 'shpack', 'sachet', '12') ->> 'status', 'ok', 'a shampoo pack breaks into 12 sachets');
select is(pg_temp.link('l15', 'gatas', 'tasa', '8') ->> 'status', 'ok', 'a second link');
select is(pg_temp.link('l16', 'xpack', 'xpiece', '5') ->> 'status', 'ok', 'a third link');
select is(pg_temp.link('l17', 'tmp', 'sachet', '3') ->> 'status', 'ok', 'two packs may break into the same piece');
select is((pg_temp.link('l18', 'tmp', null, 'null') -> 'result')::jsonb - 'applied_at' - 'variant_id',
          '{"changed": true, "replay": false, "pieces_per_pack": null, "piece_variant_id": null}'::jsonb,
          'a null piece clears the link');
select is((select (breaks_into_variant_id, breaks_into_qty)::text from public.product_variants where id = pg_temp.id('v:tmp')),
          '(,)', 'both link columns are cleared');
select is(pg_temp.link('l19', 'tmp', null, 'null') -> 'result' ->> 'changed', 'false', 'clearing again changes nothing');
reset role;

-- the database itself refuses what the op refuses (even a direct write as the owner of the schema)
select throws_ok(format('update public.product_variants set breaks_into_variant_id = %L, breaks_into_qty = 2 where id = %L',
                        pg_temp.id('v:b'), pg_temp.id('v:kape')), '23503', null, 'the link cannot point into another tenant (composite key)');
select throws_ok(format('update public.product_variants set breaks_into_variant_id = id, breaks_into_qty = 2 where id = %L',
                        pg_temp.id('v:kape')), '23514', null, 'the link cannot point at itself (check)');
select throws_ok(format('update public.product_variants set breaks_into_variant_id = %L where id = %L',
                        pg_temp.id('v:sachet'), pg_temp.id('v:kape')), '23514', null, 'the piece and the ratio are set together (check)');
select throws_ok(format('update public.product_variants set breaks_into_variant_id = %L, breaks_into_qty = 0 where id = %L',
                        pg_temp.id('v:sachet'), pg_temp.id('v:kape')), '23514', null, 'the ratio is at least 1 (check)');
select throws_ok(format('update public.product_variants set breaks_into_variant_id = %L, breaks_into_qty = 2 where id = %L',
                        pg_temp.id('v:kaha'), pg_temp.id('v:kape')), '22023', 'the piece is itself a pack',
                 'the chain guard trigger runs on direct writes too');

-- ===== opening packs =====
set local role authenticated;
select pg_temp.recv('r1', 'kaha', 5, 10350);
select is(pg_temp.open('o1', 'c1', 'kaha', '1') ->> 'status', 'ok', 'the owner opens one kaha');
select is((pg_temp.open('o1', 'c1', 'kaha', '1') -> 'result')::jsonb - 'applied_at' - 'conversion_id' - 'piece_variant_id',
          '{"pieces": 20, "pack_cost": 10350, "total_cost": 10350, "piece_cost": 518, "replay": true}'::jsonb,
          'the result: 20 pieces carrying the pack cost 103.50, 5.18 a stick (5.175 rounded half up); a resend is a replay');
select is((pg_temp.lvl('kaha'), pg_temp.lvl('stick'))::text, '(4.000,20.000)', 'one kaha out, twenty sticks in');
select is(pg_temp.avg('stick'), 518::bigint, 'the sticks average 5.18 (half_up(10350 / 20))');
select is(pg_temp.avg('kaha'), 10350::bigint, 'opening a pack never moves the pack average');
select is((select (pg_temp.lvl('stick') * pg_temp.avg('stick')) - 10350), 10::numeric,
          'stick value 20 x 518 = 10360: 10 centavos over the 10350 that left the kaha, the bound for 20 pieces (2 x 10 <= 20)');
select is((select array_agg((type, qty_delta, unit_cost, total_cost)::text order by type) from public.stock_movements
           where ref_type = 'conversion' and ref_id = pg_temp.id('c:c1')),
          array['(conversion_in,20.000,518,10350)', '(conversion_out,-1.000,10350,)'],
          'two movements share the opening id: out of the pack, into the piece with the value it carries');
select is((select (location_id = pg_temp.id('S01'), packs, ratio, pieces, pack_cost, total_cost, piece_cost,
                   client_op_id = pg_temp.id('op:o1'), created_by = pg_temp.u('owner'), voided_at is null)::text
           from public.conversions where id = pg_temp.id('c:c1')), '(t,1,20,20,10350,10350,518,t,t,t)',
          'the conversions row records the opening');
select is((select counted from public.stock_levels where variant_id = pg_temp.id('v:stick')), true,
          'pieces from a pack make the piece counted, like a stock in');
select is((select count(*)::int from public.conversions), 1, 'the replay wrote no second opening');
select is((select count(*)::int from public.stock_movements where ref_id = pg_temp.id('c:c1')), 2, 'nor more movements');
reset role;
select is((select count(*)::int from public.audit_log where action = 'stock.open_pack'), 1, 'one audit row for the opening');
select is((select (entity, location_id = pg_temp.id('S01'), (select array_agg(k order by k) from jsonb_object_keys(meta) k))::text
           from public.audit_log where action = 'stock.open_pack'),
          '(conversion,t,"{op_id,pack_variant_id,packs,piece_variant_id,pieces,total_cost}")', 'with small meta');
set local role authenticated;

-- a second opening blends with the 20 sticks on hand: (20 x 518 + 2 x 10350) / 60 = 517.67 -> 518
select is(pg_temp.open('o2', 'c2', 'kaha', '2', jsonb_build_object('piece_variant_id', pg_temp.id('v:stick'), 'pieces_per_pack', 20))
          -> 'result' ->> 'total_cost', '20700', 'two packs carry 2 x 10350 (the phone''s link guard matches)');
select is((pg_temp.lvl('kaha'), pg_temp.lvl('stick'), pg_temp.avg('stick'))::text, '(2.000,60.000,518)',
          'two kaha out, forty sticks in, the stick average is the weighted one');
select is(pg_temp.open('o3', 'c3', 'kaha', '1', jsonb_build_object('pieces_per_pack', 10)) ->> 'hint', 'link_changed',
          'when the ratio the phone showed is not the ratio now, the opening is refused');
select is(pg_temp.open('o4', 'c4', 'kaha', '1', jsonb_build_object('piece_variant_id', pg_temp.id('v:sachet'))) ->> 'hint',
          'link_changed', 'same for the piece');
select is(pg_temp.open('o5', 'c5', 'kaha', '0') ->> 'hint', 'qty_invalid', 'zero packs are refused');
select is(pg_temp.open('o6', 'c6', 'kaha', '1.5') ->> 'hint', 'qty_invalid', 'half a pack is refused (whole packs only)');
select is(pg_temp.open('o7', 'c7', 'kaha', '-1') ->> 'hint', 'qty_invalid', 'a negative count is refused');
select is(pg_temp.push1('o8', 'open_pack', jsonb_build_object('pack_variant_id', pg_temp.id('v:kaha'), 'packs', 1)) ->> 'hint',
          'id_required', 'an opening needs its client id');
select is(pg_temp.open('o9', 'c9', 'kape', '1') ->> 'hint', 'no_tingi_link', 'a product with no link cannot be opened');
select is(pg_temp.open('o10', 'c10', 'stick', '1') ->> 'hint', 'no_tingi_link', 'nor a piece');
select is(pg_temp.open('o11', 'c1', 'kaha', '1') ->> 'hint', 'id_conflict', 'an opening id is used once');
select is(pg_temp.open('o12', 'c12', 'nope', '1') ->> 'hint', 'unknown_variant', 'an unknown pack is refused');
reset role;
update public.products set track_stock = false where id = pg_temp.id('p:tasa');
update public.products set deleted_at = now() where id = pg_temp.id('p:xpiece');
update public.product_variants set deleted_at = now() where id = pg_temp.id('v:xpiece');
set local role authenticated;
select is(pg_temp.open('o13', 'c13', 'gatas', '1') ->> 'hint', 'not_tracked', 'both products must keep a stock count');
select is(pg_temp.open('o14', 'c14', 'xpack', '1') ->> 'hint', 'piece_archived', 'an archived piece cannot receive pieces');
select is(pg_temp.link('l20', 'shpack', 'xpiece', '2') ->> 'hint', 'piece_archived', 'nor be linked');
select is((select count(*)::int from public.conversions), 2, 'refused openings left no row');

-- opening more than counted is allowed (like a sale): the pack level goes below zero
select is(pg_temp.open('o15', 'c15', 'kaha', '3') ->> 'status', 'ok', 'opening more packs than counted is allowed');
select is((pg_temp.lvl('kaha'), pg_temp.lvl('stick'))::text, '(-1.000,120.000)', 'the pack level goes below zero, like a sale would');

-- no cost known: the pieces' average is left alone; then the variant cost is the fallback
select is((select (r ->> 'pack_cost', r ->> 'total_cost', r ->> 'piece_cost')::text
           from (select pg_temp.open('o16', 'c16', 'shpack', '1') -> 'result' r) x), '(,,)',
          'no pack average and no variant cost: no cost moves');
select is((pg_temp.lvl('sachet'), pg_temp.avg('sachet') is null)::text, '(12.000,t)', 'twelve sachets in, average left alone');
reset role;
update public.product_variants set cost = 600 where id = pg_temp.id('v:shpack');
set local role authenticated;
select is((select (r ->> 'pack_cost', r ->> 'total_cost', r ->> 'piece_cost')::text
           from (select pg_temp.open('o17', 'c17', 'shpack', '1') -> 'result' r) x), '(600,600,50)',
          'no pack average: the variant cost (6.00) is used, 0.50 a sachet');
select is(pg_temp.avg('sachet'), 50::bigint, 'the sachets had no average: they take the carried cost');

-- ===== voiding an opening =====
select is(pg_temp.vd('v1', 'c1', ' mali ') ->> 'status', 'ok', 'the owner voids the first opening');
select is((pg_temp.lvl('kaha'), pg_temp.lvl('stick'), pg_temp.avg('kaha'), pg_temp.avg('stick'))::text, '(0.000,100.000,10350,518)',
          'the kaha comes back, the twenty sticks go out, both averages stay');
select is((select array_agg((variant_id = pg_temp.id('v:kaha'), qty_delta)::text order by qty_delta) from public.stock_movements
           where ref_type = 'conversion_void' and ref_id = pg_temp.id('c:c1') and type = 'conversion_void'),
          array['(f,-20.000)', '(t,1.000)'], 'two reversing movements, nothing deleted');
select is((select count(*)::int from public.stock_movements where ref_id = pg_temp.id('c:c1')), 4, 'the original two are still there');
select is((select (voided_at is not null, void_reason, voided_by = pg_temp.u('owner'))::text from public.conversions
           where id = pg_temp.id('c:c1')), '(t,mali,t)', 'the opening is marked voided with the trimmed reason');
select is(pg_temp.vd('v1', 'c1') -> 'result' ->> 'replay', 'true', 'a resent void is a replay');
select is((select count(*)::int from public.stock_movements where ref_id = pg_temp.id('c:c1')), 4, 'and reverses nothing twice');
select is(pg_temp.vd('v2', 'c1') ->> 'hint', 'already_voided', 'a second void (new op) is refused');
select is(pg_temp.vd('v3', 'nope') ->> 'hint', 'conversion_not_found', 'an unknown opening cannot be voided');
select pg_temp.sell('s1', 'sachet', 20);
select is(pg_temp.vd('v4', 'c17') ->> 'status', 'ok', 'voiding after the pieces were sold is allowed');
select is(pg_temp.lvl('sachet'), -8::numeric, 'and may push the piece level below zero (24 in, 20 sold, 12 taken back)');
reset role;
select is((select count(*)::int from public.audit_log where action = 'stock.void_open_pack'), 2, 'one audit row per void');
select is((select (select array_agg(k order by k) from jsonb_object_keys(meta) k)::text from public.audit_log
           where action = 'stock.void_open_pack' and entity_id = pg_temp.id('c:c1')),
          '{op_id,packs,pieces,reason}', 'with small meta');

-- the table is append-only, even for the schema owner
select throws_ok(format('delete from public.conversions where id = %L', pg_temp.id('c:c2')), '55000', null,
                 'an opening is never deleted');
select throws_ok(format('update public.conversions set packs = 9 where id = %L', pg_temp.id('c:c2')), '55000', null,
                 'nor edited');
select throws_ok(format('update public.conversions set voided_at = null where id = %L', pg_temp.id('c:c1')), '55000', null,
                 'nor un-voided');

-- ===== who may =====
select pg_temp.login('maria', 'A');
set local role authenticated;
select is(pg_temp.open('m1', 'm1', 'kaha', '1') ->> 'status', 'ok', 'a store manager opens a pack');
select is(pg_temp.vd('m2', 'm1') ->> 'status', 'ok', 'and voids an opening');
select is(pg_temp.link('m3', 'shpack', 'sachet', '10') ->> 'status', 'ok', 'and changes a link');
select pg_temp.login('sara', 'A');
select is((pg_temp.open('sa1', 'sa1', 'kaha', '1') ->> 'hint', pg_temp.vd('sa2', 'c2') ->> 'hint',
           pg_temp.link('sa3', 'shpack', 'sachet', '9') ->> 'hint')::text, '(not_allowed,not_allowed,not_allowed)',
          'a supervisor (no catalog or stock rights) can do none of it');
select pg_temp.login('juan', 'A');
select is((pg_temp.open('j1', 'j1', 'kaha', '1') ->> 'hint', pg_temp.vd('j2', 'c2') ->> 'hint',
           pg_temp.link('j3', 'shpack', 'sachet', '9') ->> 'hint')::text, '(not_allowed,not_allowed,not_allowed)',
          'a cashier can do none of it');
select pg_temp.login('pedro', 'A');
select is((pg_temp.open('p1', 'p1', 'kaha', '1') ->> 'hint', pg_temp.link('p3', 'shpack', 'sachet', '9') ->> 'hint')::text,
          '(not_allowed,not_allowed)', 'warehouse staff (cost and SKU only) can do none of it');
select pg_temp.login('ownerB', 'B');
select is((pg_temp.open('b1', 'b1', 'kaha', '1') ->> 'hint', pg_temp.vd('b2', 'c2') ->> 'hint',
           pg_temp.link('b3', 'kaha', 'stick') ->> 'hint')::text, '(unknown_variant,conversion_not_found,unknown_variant)',
          'another tenant can neither open, void nor link our products');
reset role;
select is((select count(*)::int from public.conversions where id in (pg_temp.id('c:sa1'), pg_temp.id('c:j1'), pg_temp.id('c:p1'), pg_temp.id('c:b1'))),
          0, 'refused people left no opening');

-- ===== reading and pulling =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(jsonb_array_length(public.sync_pull_conversions() -> 'rows'), 0, 'openings newer than 5 seconds wait for the next pull');
reset role;
set local session_replication_role = replica;
update public.conversions set updated_at = now() - interval '1 minute';
update public.product_variants set updated_at = now() - interval '1 minute';
set local session_replication_role = origin;
set local role authenticated;
select is((select (jsonb_array_length(r -> 'rows'), r ->> 'has_more',
                   (select array_agg(k order by k) from jsonb_object_keys(r -> 'rows' -> 0) k))::text
           from (select public.sync_pull_conversions() r) x),
          '(6,false,"{converted_at,created_by,id,location_id,note,pack_cost,pack_variant_id,packs,piece_cost,piece_variant_id,pieces,ratio,total_cost,updated_at,void_reason,voided_at}")',
          'the owner pulls every opening with the documented fields');
select is((select (e ->> 'voided_at' is not null, e ->> 'void_reason')::text
           from jsonb_array_elements(public.sync_pull_conversions() -> 'rows') e where e ->> 'id' = pg_temp.id('c:c1')::text),
          '(t,mali)', 'a voided opening comes with its void');
select is((select (jsonb_array_length(p1 -> 'rows'), p1 ->> 'has_more', jsonb_array_length(public.sync_pull_conversions(p1 -> 'cursor') -> 'rows'))::text
           from (select public.sync_pull_conversions(null, 4) p1) x), '(4,true,2)', 'pages follow the cursor');
select is((select (e ->> 'breaks_into_variant_id', e ->> 'breaks_into_qty')::text
           from jsonb_array_elements(public.sync_pull_catalog('{}', 500) -> 'product_variants' -> 'rows') e
           where e ->> 'id' = pg_temp.id('v:kaha')::text), format('(%s,20)', pg_temp.id('v:stick')),
          'the catalog pull carries the link');
select pg_temp.login('juan', 'A');
select is(jsonb_array_length(public.sync_pull_conversions() -> 'rows'), 6, 'a cashier of the store reads its openings');
select pg_temp.login('pedro', 'A');
select is(jsonb_array_length(public.sync_pull_conversions() -> 'rows'), 0, 'warehouse staff of another place read none');
select pg_temp.login('ownerB', 'B');
select is(jsonb_array_length(public.sync_pull_conversions() -> 'rows'), 0, 'another tenant reads none of ours');
reset role;

-- ===== property: seeded random packs, ratios, costs, openings, voids, sales, receipts and replays =====
create temp table pairs (n int primary key, pack text, piece text, ratio int);
create temp table opened (conv text primary key, pack text, piece text, packs int, pieces int, voided boolean not null default false);
create temp table pstat (k text primary key, v int not null default 0);
create temp table viol (what text);

create function pg_temp.bump(k text) returns void language sql as $$
  insert into pg_temp.pstat values (k, 1) on conflict (k) do update set v = pstat.v + 1
$$;

do $$
declare
  i int;
begin
  for i in 1..6 loop
    insert into public.products (id, tenant_id, name) values
      (pg_temp.id('p:pp' || i), pg_temp.t('A'), 'Pack ' || i), (pg_temp.id('p:pc' || i), pg_temp.t('A'), 'Piece ' || i);
    insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
      (pg_temp.id('v:pp' || i), pg_temp.t('A'), pg_temp.id('p:pp' || i), 'PP' || i, true),
      (pg_temp.id('v:pc' || i), pg_temp.t('A'), pg_temp.id('p:pc' || i), 'PC' || i, true);
  end loop;
end;
$$;

select pg_temp.login('owner', 'A');

do $$
declare
  i int; r float8; n int; v_pick int; pr record; o record; k text;
  v_packs int; v_qty numeric; v_cost bigint; v_res jsonb; v_t bigint; v_exp bigint;
  qp0 numeric; ap0 bigint; qs0 numeric; as0 bigint; qp1 numeric; ap1 bigint; qs1 numeric; as1 bigint; v_diff numeric;
  v_sent jsonb := '[]'::jsonb;
begin
  perform setseed(0.0808);
  for i in 1..6 loop
    insert into pg_temp.pairs values (i, 'pp' || i, 'pc' || i, 1 + floor(random() * 50)::int);
    select * into pr from pg_temp.pairs where pairs.n = i;
    if pg_temp.link('pl' || i, pr.pack, pr.piece, to_jsonb(pr.ratio)) ->> 'status' <> 'ok' then
      insert into pg_temp.viol values ('link ' || i);
    end if;
  end loop;

  for i in 1..400 loop
    r := random();
    v_pick := 1 + floor(random() * 6)::int; -- drawn once (random() in a WHERE runs per row)
    select * into pr from pg_temp.pairs where pairs.n = v_pick;
    k := 'q' || i;
    if r < 0.22 then
      -- packs come in, usually with a cost
      v_qty := 1 + floor(random() * 6);
      v_cost := case when random() < 0.85 then 1 + floor(random() * 99999)::bigint end;
      v_res := pg_temp.recv(k, pr.pack, v_qty, v_cost);
      v_sent := v_sent || jsonb_build_array(jsonb_build_object('k', k, 'kind', 'receive_stock', 'p', jsonb_strip_nulls(
        jsonb_build_object('variant_id', pg_temp.id('v:' || pr.pack), 'qty', v_qty, 'unit_cost', v_cost))));
    elsif r < 0.30 then
      -- pieces come in on their own (bought loose), sometimes with a cost
      v_qty := 1 + floor(random() * 30);
      v_cost := case when random() < 0.6 then 1 + floor(random() * 5000)::bigint end;
      perform pg_temp.recv(k, pr.piece, v_qty, v_cost);
    elsif r < 0.62 then
      -- open 1 to 3 packs
      v_packs := 1 + floor(random() * 3)::int;
      select qty_on_hand, avg_cost into qp0, ap0 from public.stock_levels where variant_id = pg_temp.id('v:' || pr.pack);
      select qty_on_hand, avg_cost into qs0, as0 from public.stock_levels where variant_id = pg_temp.id('v:' || pr.piece);
      v_res := pg_temp.open(k, k, pr.pack, to_jsonb(v_packs));
      if v_res ->> 'status' <> 'ok' then
        insert into pg_temp.viol values ('open refused ' || k || ' ' || v_res::text);
        continue;
      end if;
      insert into pg_temp.opened values (k, pr.pack, pr.piece, v_packs, v_packs * pr.ratio);
      v_sent := v_sent || jsonb_build_array(jsonb_build_object('k', k, 'kind', 'open_pack', 'p', jsonb_build_object(
        'id', pg_temp.id('c:' || k), 'pack_variant_id', pg_temp.id('v:' || pr.pack), 'packs', v_packs, 'at', '2026-11-08T02:00:00Z')));
      select qty_on_hand, avg_cost into qp1, ap1 from public.stock_levels where variant_id = pg_temp.id('v:' || pr.pack);
      select qty_on_hand, avg_cost into qs1, as1 from public.stock_levels where variant_id = pg_temp.id('v:' || pr.piece);
      perform pg_temp.bump('opens');
      -- quantities: exactly packs out, packs x ratio in
      if qp1 <> coalesce(qp0, 0) - v_packs or qs1 <> coalesce(qs0, 0) + v_packs * pr.ratio then
        insert into pg_temp.viol values ('qty ' || k);
      end if;
      if ap1 is distinct from ap0 then
        insert into pg_temp.viol values ('pack avg moved ' || k);
      end if;
      v_t := (v_res -> 'result' ->> 'total_cost')::bigint;
      if v_t is distinct from (v_packs * ap0) then
        insert into pg_temp.viol values ('total ' || k);
      end if;
      -- independent piece average: rounded numeric division, not the integer formula the trigger uses
      v_exp := case
        when v_t is null then as0
        when coalesce(qs0, 0) > 0 and as0 is not null
          then round((qs0 * as0 + v_t)::numeric(38, 12) / (qs0 + v_packs * pr.ratio))::bigint
        else round(v_t::numeric(38, 12) / (v_packs * pr.ratio))::bigint end;
      if as1 is distinct from v_exp then
        insert into pg_temp.viol values ('piece avg ' || k || ' got ' || coalesce(as1::text, 'null') || ' want ' || coalesce(v_exp::text, 'null'));
      end if;
      -- stock value of pack + piece conserved within half a centavo per piece on hand
      if v_t is not null and coalesce(qs0, 0) >= 0 and (coalesce(qs0, 0) = 0 or as0 is not null) then
        v_diff := (qp1 * ap1 + qs1 * as1) - (coalesce(qp0, 0) * ap0 + coalesce(qs0, 0) * coalesce(as0, 0));
        perform pg_temp.bump('value_checks');
        if v_diff <> 0 then
          perform pg_temp.bump('value_rounded');
        end if;
        if 2 * abs(v_diff) > qs1 then
          insert into pg_temp.viol values ('value ' || k || ' diff ' || v_diff || ' pieces ' || qs1);
        end if;
      end if;
    elsif r < 0.80 then
      -- sell some pieces (may go below zero)
      perform pg_temp.sell(k, pr.piece, (1 + floor(random() * 15))::numeric);
    elsif r < 0.92 then
      -- void a random opening that is still standing
      select * into o from pg_temp.opened where not voided order by random() limit 1;
      if not found then
        continue;
      end if;
      select qty_on_hand, avg_cost into qp0, ap0 from public.stock_levels where variant_id = pg_temp.id('v:' || o.pack);
      select qty_on_hand, avg_cost into qs0, as0 from public.stock_levels where variant_id = pg_temp.id('v:' || o.piece);
      v_res := pg_temp.vd(k, o.conv);
      if v_res ->> 'status' <> 'ok' then
        insert into pg_temp.viol values ('void refused ' || k);
        continue;
      end if;
      update pg_temp.opened set voided = true where conv = o.conv;
      select qty_on_hand, avg_cost into qp1, ap1 from public.stock_levels where variant_id = pg_temp.id('v:' || o.pack);
      select qty_on_hand, avg_cost into qs1, as1 from public.stock_levels where variant_id = pg_temp.id('v:' || o.piece);
      perform pg_temp.bump('voids');
      if qp1 <> qp0 + o.packs or qs1 <> qs0 - o.pieces or ap1 is distinct from ap0 or as1 is distinct from as0 then
        insert into pg_temp.viol values ('void ' || k);
      end if;
      -- a second void is refused and changes nothing
      if pg_temp.vd(k || 'x', o.conv) ->> 'hint' <> 'already_voided'
         or (select qty_on_hand from public.stock_levels where variant_id = pg_temp.id('v:' || o.piece)) <> qs1 then
        insert into pg_temp.viol values ('double void ' || k);
      end if;
    else
      -- resend an earlier stock in or opening with its op id: nothing may change
      if jsonb_array_length(v_sent) = 0 then
        continue;
      end if;
      n := floor(random() * jsonb_array_length(v_sent))::int;
      select qty_on_hand into qp0 from public.stock_levels where variant_id = pg_temp.id('v:' || pr.pack);
      select sum(qty_on_hand) into qs0 from public.stock_levels where tenant_id = pg_temp.t('A');
      v_res := pg_temp.push1(v_sent -> n ->> 'k', v_sent -> n ->> 'kind', v_sent -> n -> 'p');
      perform pg_temp.bump('replays');
      if v_res -> 'result' ->> 'replay' <> 'true'
         or (select sum(qty_on_hand) from public.stock_levels where tenant_id = pg_temp.t('A')) <> qs0 then
        insert into pg_temp.viol values ('replay ' || k);
      end if;
    end if;
  end loop;
end;
$$;

select is((select coalesce(string_agg(what, '; '), '') from pg_temp.viol), '',
          'property: quantities exact, pack average unmoved, total = packs x pack average, piece average = independent rounding, value within bound, voids restore exactly, replays change nothing');
select ok((select (select v from pg_temp.pstat where k = 'opens') >= 80 and (select v from pg_temp.pstat where k = 'value_checks') >= 40
                  and (select v from pg_temp.pstat where k = 'value_rounded') >= 5 and (select v from pg_temp.pstat where k = 'voids') >= 20
                  and (select v from pg_temp.pstat where k = 'replays') >= 10),
          'property: the run was not vacuous (enough openings, value checks incl. rounded ones, voids and replays)');
select is((select count(*)::int from public.stock_levels l
           where l.qty_on_hand <> (select coalesce(sum(m.qty_delta), 0) from public.stock_movements m
                                   where m.location_id = l.location_id and m.variant_id = l.variant_id)),
          0, 'every level (packs and pieces) equals the sum of its movements');
select is((select count(*)::int from public.conversions c
           where (select count(*) from public.stock_movements m where m.ref_id = c.id)
                 <> case when c.voided_at is null then 2 else 4 end),
          0, 'every opening has its two movements, every voided one its two reversals');
select is((select count(*)::int from public.conversions c
           where (select coalesce(sum(m.qty_delta), 0) from public.stock_movements m where m.ref_id = c.id and m.variant_id = c.piece_variant_id)
                 <> case when c.voided_at is null then c.pieces else 0 end),
          0, 'the movements of an opening add up to its pieces, and to zero once voided');

select * from finish();
rollback;
