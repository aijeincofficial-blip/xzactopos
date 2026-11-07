-- P8-11 expiry dates: the stock_expiry table (one date per store and variant, no lots), the set_expiry op (set, clear,
-- no-change, replay, bad dates, permissions, tenants, audit), receive_stock's optional expires_on (the earlier-date rule while
-- stock is on hand, replace on an empty shelf; nothing else about a receipt changes), and the stock_expiry section of
-- sync_pull_pos (fields, delta, store scope).
begin;
select plan(65);

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
-- d: a jsonb value for expires_on ('"2026-12-01"', 'null', ...)
create function pg_temp.exp(k text, v text, d jsonb, extra jsonb default '{}') returns jsonb language sql as $$
  select pg_temp.push1(k, 'set_expiry', jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'expires_on', d) || extra)
$$;
-- d null = no expires_on key at all
create function pg_temp.recv(k text, v text, qty numeric, cost bigint default null, d text default null) returns jsonb language sql as $$
  select pg_temp.push1(k, 'receive_stock', jsonb_strip_nulls(jsonb_build_object(
    'variant_id', pg_temp.id('v:' || v), 'qty', qty, 'unit_cost', cost, 'expires_on', d)))
$$;
create function pg_temp.sell(k text, v text, qty numeric) returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:' || k), 'local_no', 'R-' || k, 'sold_at', '2026-11-08T02:00:00Z',
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'qty', qty, 'unit_price', 100)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', round(qty * 100)::bigint))))
$$;
create function pg_temp.expiry(v text) returns date language sql as $$
  select expires_on from public.stock_expiry where variant_id = pg_temp.id('v:' || v)
$$;
create function pg_temp.lvl(v text) returns text language sql as $$
  select (qty_on_hand, avg_cost, counted)::text from public.stock_levels where variant_id = pg_temp.id('v:' || v)
$$;
create function pg_temp.audits(v text) returns int language sql as $$
  select count(*)::int from public.audit_log where action = 'stock.set_expiry' and entity_id = pg_temp.id('v:' || v)
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
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sara'), pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null);
insert into public.products (id, tenant_id, name)
  select pg_temp.id('p:' || n), pg_temp.t('A'), n from unnest(array['kape', 'gatas', 'tinapay', 'twin']) n;
insert into public.products (id, tenant_id, name) values (pg_temp.id('p:b'), pg_temp.t('B'), 'B item');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default)
  select pg_temp.id('v:' || n), pg_temp.t('A'), pg_temp.id('p:' || n), upper(n), true from unnest(array['kape', 'gatas', 'tinapay', 'twin']) n;
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (pg_temp.id('v:b'), pg_temp.t('B'), pg_temp.id('p:b'), 'B1', true);

select has_table('public', 'stock_expiry', 'the stock_expiry table exists');
select col_type_is('public', 'stock_expiry', 'expires_on', 'date', 'the expiry is a date');
select col_is_pk('public', 'stock_expiry', array['location_id', 'variant_id'], 'one date per store and variant');
select is((select relrowsecurity from pg_class where oid = 'public.stock_expiry'::regclass), true, 'RLS is on');

-- ===== set_expiry =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is((pg_temp.exp('e1', 'kape', '"2026-12-01"') -> 'result')::jsonb - 'applied_at',
          jsonb_build_object('variant_id', pg_temp.id('v:kape'), 'location_id', pg_temp.id('S01'), 'expires_on', '2026-12-01',
                             'changed', true, 'replay', false),
          'the owner sets the earliest expiry on the shelf (the store is found when she has one)');
select is(pg_temp.expiry('kape'), '2026-12-01'::date, 'the store and variant carry it');
select is(pg_temp.exp('e1', 'kape', '"2026-12-01"') -> 'result' ->> 'replay', 'true', 'a resent op is a replay');
select is(pg_temp.exp('e2', 'kape', '"2026-12-01"') -> 'result' ->> 'changed', 'false', 'the same date again changes nothing');
reset role;
select is(pg_temp.audits('kape'), 1, 'one audit row: the replay and the no-change send write none');
select is((select (select array_agg(k order by k) from jsonb_object_keys(meta) k)::text from public.audit_log
           where action = 'stock.set_expiry' and entity_id = pg_temp.id('v:kape')), '{expires_on,op_id,previous}',
          'the audit row has small meta');
select is((select pg_temp.lvl('kape')), null, 'setting an expiry writes no stock movement or level');
set local role authenticated;
select is(pg_temp.exp('e3', 'kape', '"2020-05-01"') ->> 'status', 'ok', 'a date in the past is allowed (already expired)');
select is(pg_temp.exp('e4', 'kape', '"2000-01-01"') ->> 'status', 'ok', 'the year 2000 is the earliest allowed');
select is((pg_temp.exp('e5', 'kape', 'null') -> 'result')::jsonb ->> 'expires_on', null, 'null clears the date');
select is((select (count(*), max(expires_on))::text from public.stock_expiry where variant_id = pg_temp.id('v:kape')), '(1,)',
          'the row stays with no date (so the pull can tell phones it was cleared)');
select is(pg_temp.exp('e6', 'kape', 'null') -> 'result' ->> 'changed', 'false', 'clearing again changes nothing');

-- bad input
select is(pg_temp.push1('b1', 'set_expiry', jsonb_build_object('variant_id', pg_temp.id('v:kape'))) ->> 'hint', 'invalid_value',
          'expires_on must be sent (null to clear)');
select is(pg_temp.exp('b2', 'kape', '"2026/12/01"') ->> 'hint', 'invalid_value', 'a date with slashes is refused');
select is(pg_temp.exp('b3', 'kape', '"2026-02-30"') ->> 'hint', 'invalid_value', 'a day that does not exist is refused');
select is(pg_temp.exp('b4', 'kape', '"1999-12-31"') ->> 'hint', 'invalid_value', 'a date before 2000 is refused');
select is(pg_temp.exp('b5', 'kape', to_jsonb(to_char(current_date + interval '10 years' + interval '1 day', 'YYYY-MM-DD'))) ->> 'hint',
          'invalid_value', 'more than 10 years ahead is refused');
select is(pg_temp.exp('b6', 'kape', to_jsonb(to_char(current_date + interval '10 years', 'YYYY-MM-DD'))) ->> 'status', 'ok',
          'exactly 10 years ahead is allowed');
select is(pg_temp.exp('b7', 'kape', '20261201') ->> 'hint', 'invalid_value', 'a number is refused');
select is(pg_temp.exp('b8', 'kape', '"2026-12-01T00:00:00Z"') ->> 'hint', 'invalid_value', 'a timestamp is refused (a date only)');
select is(pg_temp.exp('b9', 'nope', '"2026-12-01"') ->> 'hint', 'unknown_variant', 'an unknown product is refused');
select is(pg_temp.exp('b10', 'b', '"2026-12-01"') ->> 'hint', 'unknown_variant', 'another tenant''s product is unknown');
select is(pg_temp.exp('b11', 'kape', '"2026-12-01"', jsonb_build_object('location_id', pg_temp.id('W01'))) ->> 'hint',
          'location_denied', 'a warehouse is not a store');
select is(pg_temp.exp('b12', 'kape', '"2026-12-01"', jsonb_build_object('location_id', pg_temp.id('SB'))) ->> 'hint',
          'location_denied', 'another tenant''s store is refused');
select is(pg_temp.expiry('kape'), (current_date + interval '10 years')::date, 'refusals changed nothing');

-- who: the same people as receive_stock
select pg_temp.login('maria', 'A');
select is(pg_temp.exp('w1', 'tinapay', '"2026-11-20"') ->> 'status', 'ok', 'a store manager may set it');
select pg_temp.login('sara', 'A');
select is(pg_temp.exp('w2', 'tinapay', '"2026-11-10"') ->> 'hint', 'not_allowed', 'a supervisor may not (like stock in)');
select pg_temp.login('juan', 'A');
select is(pg_temp.exp('w3', 'tinapay', '"2026-11-10"') ->> 'hint', 'not_allowed', 'a cashier may not');
select pg_temp.login('pedro', 'A');
select is(pg_temp.exp('w4', 'tinapay', '"2026-11-10"') ->> 'hint', 'not_allowed', 'warehouse staff may not');
select pg_temp.login('ownerB', 'B');
select is(pg_temp.exp('w5', 'tinapay', '"2026-11-10"') ->> 'hint', 'unknown_variant', 'another tenant cannot touch it');
select pg_temp.login('owner', 'A');
select is(pg_temp.expiry('tinapay'), '2026-11-20'::date, 'only the manager''s write landed');

-- ===== receive_stock with expires_on: the earlier-date rule =====
select is(pg_temp.recv('r1', 'gatas', 10, 100, '2026-12-31') -> 'result' ->> 'expires_on', '2026-12-31',
          'stock in on an empty shelf: the new date is stored (and returned)');
select is(pg_temp.lvl('gatas'), '(10.000,100,t)', 'the receipt itself is as always (quantity, average cost, counted)');
reset role;
set local session_replication_role = replica;
update public.stock_expiry set updated_at = now() - interval '1 hour' where variant_id = pg_temp.id('v:gatas');
set local session_replication_role = origin;
set local role authenticated;
select is(pg_temp.recv('r2', 'gatas', 5, 160, '2027-03-01') -> 'result' ->> 'expires_on', '2026-12-31',
          'a later batch while milk is on the shelf keeps the earlier date');
select is((select updated_at from public.stock_expiry where variant_id = pg_temp.id('v:gatas')), now(),
          'a receipt with a date moves updated_at even when the date stays (a phone that guessed otherwise is corrected)');
select is(pg_temp.lvl('gatas'), '(15.000,120,t)', 'and the average cost blends exactly as without a date');
select is(pg_temp.recv('r3', 'gatas', 5, null, '2026-12-15') ->> 'status', 'ok', 'an earlier batch comes in');
select is(pg_temp.expiry('gatas'), '2026-12-15'::date, 'the earlier date wins');
select is(pg_temp.recv('r3', 'gatas', 5, null, '2026-12-15') -> 'result' ->> 'replay', 'true', 'a resent receipt is a replay');
select is(pg_temp.lvl('gatas'), '(20.000,120,t)', 'counted once');
select is(pg_temp.recv('r4', 'gatas', 2, null) -> 'result' ? 'expires_on', false, 'a receipt without a date says nothing about it');
select is(pg_temp.expiry('gatas'), '2026-12-15'::date, 'and leaves the date alone');
select is(pg_temp.push1('r5', 'receive_stock', jsonb_build_object('variant_id', pg_temp.id('v:gatas'), 'qty', 1, 'expires_on', null))
          -> 'result' ? 'expires_on', false, 'a null date counts as no date');
select pg_temp.sell('s1', 'gatas', 23);
select is(pg_temp.lvl('gatas'), '(0.000,120,t)', 'everything sold: the shelf is empty');
select is(pg_temp.recv('r6', 'gatas', 6, null, '2027-06-01') -> 'result' ->> 'expires_on', '2027-06-01',
          'stock in on an empty shelf replaces the old date, even with a later one');
select pg_temp.sell('s2', 'gatas', 8);
select is(pg_temp.recv('r7', 'gatas', 5, null, '2027-08-01') -> 'result' ->> 'expires_on', '2027-08-01',
          'below zero (-2 before this receipt) counts as empty too');
select is(pg_temp.exp('e7', 'gatas', 'null') ->> 'status', 'ok', 'the date is cleared while milk is on the shelf');
select is(pg_temp.recv('r8', 'gatas', 1, null, '2027-09-01') -> 'result' ->> 'expires_on', '2027-09-01',
          'with no stored date the new one is taken even with stock on hand');
select is(pg_temp.recv('r9', 'gatas', 1, null, '2027/09/01') ->> 'hint', 'invalid_value', 'a bad date refuses the whole receipt');
select is(pg_temp.lvl('gatas'), '(4.000,120,t)', 'so no stock came in');
reset role;
select is((select count(*)::int from public.stock_movements where variant_id = pg_temp.id('v:gatas') and type = 'receipt'), 8,
          'one movement per accepted receipt (r1 r2 r3 r4 r5 r6 r7 r8)');
select is(pg_temp.audits('gatas'), 6, 'a receipt that changed the date audits it (r1 r3 r6 r7 r8) and so does the clear; r2 did not');
select is((select (select array_agg(k order by k) from jsonb_object_keys(meta) k)::text from public.audit_log
           where action = 'stock.receive' and entity_id = pg_temp.id('v:gatas') and meta ? 'expires_on' limit 1),
          '{cost,expires_on,qty}', 'the receipt audit names the stored date when one was sent');
select is((select (select array_agg(k order by k) from jsonb_object_keys(meta) k)::text from public.audit_log
           where action = 'stock.receive' and entity_id = pg_temp.id('v:gatas') and not meta ? 'expires_on' limit 1),
          '{cost,qty}', 'and is exactly as before without one');

-- ===== pull =====
set local session_replication_role = replica;
update public.stock_expiry set updated_at = now() - interval '1 hour';
set local session_replication_role = origin;
set local role authenticated;
create temp table pull0 as select public.sync_pull_pos('{}'::jsonb, 500) as r;
grant select on pull0 to authenticated;
select is((select (select array_agg(k order by k) from jsonb_object_keys(x) k)::text
           from pull0, jsonb_array_elements(r -> 'stock_expiry' -> 'rows') x limit 1),
          '{expires_on,location_id,updated_at,variant_id}', 'the pos pull has a stock_expiry section with these fields');
select is((select x ->> 'expires_on' from pull0, jsonb_array_elements(r -> 'stock_expiry' -> 'rows') x
           where x ->> 'variant_id' = pg_temp.id('v:tinapay')::text), '2026-11-20', 'dates come as YYYY-MM-DD');
select is((select (r ? 'stock_levels') and (r ? 'customers') and (r ? 'customer_ledger') from pull0), true,
          'the other sections are still there (additive)');
select pg_temp.exp('e8', 'tinapay', '"2026-11-12"');
reset role;
set local session_replication_role = replica;
update public.stock_expiry set updated_at = now() - interval '30 seconds' where variant_id = pg_temp.id('v:tinapay');
set local session_replication_role = origin;
set local role authenticated;
select is((select jsonb_agg(x ->> 'expires_on') from jsonb_array_elements(public.sync_pull_pos(
             (select jsonb_build_object('stock_expiry', r -> 'stock_expiry' -> 'cursor') from pull0), 500) -> 'stock_expiry' -> 'rows') x),
          '["2026-11-12"]'::jsonb, 'the delta pull after the first cursor returns only the changed date');
select pg_temp.login('juan', 'A');
select is(jsonb_array_length(public.sync_pull_pos('{}'::jsonb, 500) -> 'stock_expiry' -> 'rows'), 3,
          'a cashier of the store gets its dates (kape, tinapay, gatas)');
select pg_temp.login('pedro', 'A');
select is(jsonb_array_length(public.sync_pull_pos('{}'::jsonb, 500) -> 'stock_expiry' -> 'rows'), 0,
          'warehouse staff of another location get none');
select pg_temp.login('ownerB', 'B');
select is(jsonb_array_length(public.sync_pull_pos('{}'::jsonb, 500) -> 'stock_expiry' -> 'rows'), 0, 'another tenant gets none');

reset role;
select * from finish();
rollback;
