-- 044_shifts.test.sql: cashier shifts (F-05m): open_shift / close_shift ops, the server's expected cash for a shift,
-- who may do what, the table's protection, row-level reads, sync_pull_shifts.
begin;
select plan(46);

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
-- open a shift: key, shift name, store (null = the cashier's only store), opening cash, opened_at offset
create function pg_temp.open(k text, sh text, loc text, opening bigint default 0, ago interval default interval '3 hours') returns jsonb language sql as $$
  select pg_temp.push1(k, 'open_shift', jsonb_strip_nulls(jsonb_build_object(
    'id', pg_temp.id('sh:' || sh), 'location_id', case when loc is null then null else pg_temp.id(loc) end,
    'opening_cash', opening, 'opened_at', now() - ago)))
$$;
create function pg_temp.close(k text, sh text, expected bigint, counted bigint, closed_ago interval default interval '0 seconds', note text default null)
returns jsonb language sql as $$
  select pg_temp.push1(k, 'close_shift', jsonb_strip_nulls(jsonb_build_object(
    'id', pg_temp.id('sh:' || sh), 'expected_cash', expected, 'counted_cash', counted,
    'closed_at', now() - closed_ago, 'note', note)))
$$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'juan', 'pia', 'pedro', 'ownerB', 'bea']) n;
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'A', 'shift-a', 'PHP', 'Asia/Manila'), (pg_temp.t('B'), 'B', 'shift-b', 'PHP', 'UTC');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.t('A'), true, true), (pg_temp.t('B'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('pia'), pg_temp.t('A'), 'pia', 'cashier', true),
  (pg_temp.u('pedro'), pg_temp.t('A'), 'pedro', 'warehouse', true),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true),
  (pg_temp.u('bea'), pg_temp.t('B'), 'bea', 'cashier', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'A1'),
  (pg_temp.id('S02'), pg_temp.t('A'), 'store', 'S02', 'A2'),
  (pg_temp.id('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'AW'),
  (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'S01', 'B1');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pia'), pg_temp.id('S02'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null),
  (pg_temp.u('bea'), pg_temp.id('SB'), pg_temp.t('B'), null);

-- ---------------------------------------------------------------------------
-- opening a shift
-- ---------------------------------------------------------------------------
select pg_temp.login('juan', 'A');
set local role authenticated;
select is(pg_temp.open('j1', 'j1', null, 20000) ->> 'status', 'ok', 'a cashier opens a shift (store taken from their only store)');
reset role;
select is((select location_id from public.shifts where id = pg_temp.id('sh:j1')), pg_temp.id('S01'), 'at their store');
select is((select cashier_id from public.shifts where id = pg_temp.id('sh:j1')), pg_temp.u('juan'), 'and the shift is theirs');

select pg_temp.login('juan', 'A');
set local role authenticated;
select is(pg_temp.open('j2', 'j2', 'S01') ->> 'hint', 'shift_already_open', 'a second open shift is refused');
select is((pg_temp.push1('j1', 'open_shift', jsonb_build_object('id', pg_temp.id('sh:j1'), 'opening_cash', 20000)) ->> 'status'), 'ok', 'sending the same op again is harmless');
reset role;
select is((select count(*)::int from public.shifts where cashier_id = pg_temp.u('juan')), 1, 'and made no second shift');

select pg_temp.login('pedro', 'A');
set local role authenticated;
select is(pg_temp.open('p1', 'p1', 'W01') ->> 'hint', 'not_allowed', 'warehouse staff have no shifts');
select pg_temp.login('pia', 'A');
select is(pg_temp.open('pi0', 'pi0', 'S01') ->> 'hint', 'location_denied', 'a cashier cannot open a shift at a store they are not assigned to');
select is(pg_temp.open('pi1', 'pi1', 'S02', 0, interval '-1 hour') ->> 'hint', 'invalid_value', 'a start time in the future is refused');
select is(pg_temp.open('pi2', 'pi2', 'S02', 0, interval '20 days') ->> 'hint', 'invalid_value', 'and one more than 14 days back');
select is(pg_temp.open('pi3', 'pi3', 'S02', -5) ->> 'hint', 'amount_invalid', 'opening cash below zero is refused');
select is(pg_temp.push1('pi4', 'open_shift', jsonb_build_object('id', pg_temp.id('sh:pi4'), 'opening_cash', 10.5)) ->> 'hint', 'amount_invalid', 'and so is a fraction of a centavo');
select pg_temp.login('maria', 'A');
select is(pg_temp.open('m0', 'j1', 'S01') ->> 'hint', 'id_conflict', 'a shift id that is already used is refused');
reset role;

-- ---------------------------------------------------------------------------
-- the server's expected cash: only this cashier, this store, inside the window
--   opened 3 h ago with 20000 in the drawer
-- ---------------------------------------------------------------------------
insert into public.customers (id, tenant_id, name) values (pg_temp.id('cus'), pg_temp.t('A'), 'Rosa');
insert into public.sales (id, tenant_id, location_id, local_no, status, subtotal, total, sold_at, voided_at, created_by) values
  (pg_temp.id('s1'), pg_temp.t('A'), pg_temp.id('S01'), 'D-1', 'completed', 10000, 10000, now() - interval '2 hours', null, pg_temp.u('juan')),
  (pg_temp.id('s2'), pg_temp.t('A'), pg_temp.id('S01'), 'D-2', 'completed', 5000, 5000, now() - interval '1 hour', null, pg_temp.u('juan')),
  (pg_temp.id('s3'), pg_temp.t('A'), pg_temp.id('S01'), 'D-3', 'voided', 5000, 5000, now() - interval '90 minutes', now() - interval '80 minutes', pg_temp.u('juan')),
  (pg_temp.id('s4'), pg_temp.t('A'), pg_temp.id('S01'), 'D-4', 'completed', 7000, 7000, now() - interval '1 hour', null, pg_temp.u('maria')),
  (pg_temp.id('s5'), pg_temp.t('A'), pg_temp.id('S01'), 'D-5', 'completed', 900, 900, now() - interval '4 hours', null, pg_temp.u('juan')),
  (pg_temp.id('s6'), pg_temp.t('A'), pg_temp.id('S02'), 'D-6', 'completed', 600, 600, now() - interval '1 hour', null, pg_temp.u('juan'));
insert into public.payments (tenant_id, sale_id, location_id, method, amount, tendered) values
  (pg_temp.t('A'), pg_temp.id('s1'), pg_temp.id('S01'), 'cash', 10000, 10000),
  (pg_temp.t('A'), pg_temp.id('s2'), pg_temp.id('S01'), 'cash', 3000, 5000),          -- change is not counted
  (pg_temp.t('A'), pg_temp.id('s2'), pg_temp.id('S01'), 'ewallet', 2000, null),
  (pg_temp.t('A'), pg_temp.id('s3'), pg_temp.id('S01'), 'cash', 5000, null),          -- voided
  (pg_temp.t('A'), pg_temp.id('s4'), pg_temp.id('S01'), 'cash', 7000, null),          -- another cashier
  (pg_temp.t('A'), pg_temp.id('s5'), pg_temp.id('S01'), 'cash', 900, null),           -- before the shift
  (pg_temp.t('A'), pg_temp.id('s6'), pg_temp.id('S02'), 'cash', 600, null);           -- another store
insert into public.customer_ledger (tenant_id, customer_id, kind, amount, occurred_at, location_id, method, created_by) values
  (pg_temp.t('A'), pg_temp.id('cus'), 'payment', -1500, now() - interval '1 hour', pg_temp.id('S01'), 'cash', pg_temp.u('juan')),
  (pg_temp.t('A'), pg_temp.id('cus'), 'payment', -400, now() - interval '1 hour', pg_temp.id('S01'), 'ewallet', pg_temp.u('juan')),
  (pg_temp.t('A'), pg_temp.id('cus'), 'payment', -800, now() - interval '1 hour', pg_temp.id('S01'), 'cash', pg_temp.u('maria'));
insert into public.expenses (id, tenant_id, location_id, client_op_id, amount, currency, category, paid_from, spent_at, voided_at, created_by) values
  (pg_temp.id('e1'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('eop1'), 2500, 'PHP', 'utilities', 'cash', now() - interval '2 hours', null, pg_temp.u('juan')),
  (pg_temp.id('e2'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('eop2'), 1000, 'PHP', 'transport', 'ewallet', now() - interval '2 hours', null, pg_temp.u('juan')),
  (pg_temp.id('e3'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('eop3'), 600, 'PHP', 'other', 'cash', now() - interval '2 hours', now() - interval '1 hour', pg_temp.u('juan')),
  (pg_temp.id('e4'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('eop4'), 400, 'PHP', 'other', 'cash', now() - interval '2 hours', null, pg_temp.u('maria'));
insert into public.service_txns (id, tenant_id, location_id, client_op_id, kind, wallet, amount, fee, currency, txn_at, created_by) values
  (pg_temp.id('v1'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('vop1'), 'cash_in', 'gcash', 2000, 50, 'PHP', now() - interval '1 hour', pg_temp.u('juan'));

-- 20000 opening + 10000 + 3000 cash sales + 1500 utang - 2500 expense + (2000 + 50) cash-in = 34050
select is(public.shift_server_expected(pg_temp.t('A'), pg_temp.id('S01'), pg_temp.u('juan'), now() - interval '3 hours', now(), 20000), 34050::bigint,
          'the server expected cash counts only this cashier, this store and this window, voids and non-cash left out');

-- ---------------------------------------------------------------------------
-- closing a shift
-- ---------------------------------------------------------------------------
select pg_temp.login('juan', 'A');
set local role authenticated;
select is(pg_temp.close('c0', 'zz', 1, 1) ->> 'hint', 'shift_not_found', 'closing a shift that does not exist is refused');
select is(pg_temp.close('c1', 'j1', 34000, -1) ->> 'hint', 'amount_invalid', 'a negative count is refused');
select is(pg_temp.push1('c2', 'close_shift', jsonb_build_object('id', pg_temp.id('sh:j1'), 'expected_cash', 1.5, 'counted_cash', 1)) ->> 'hint', 'amount_invalid', 'and a fraction');
select is(pg_temp.close('c3', 'j1', 34000, 33900, interval '4 hours') ->> 'hint', 'invalid_value', 'a close before the shift began is refused');
select is(pg_temp.close('c4', 'j1', 34000, 33900, interval '-1 hour') ->> 'hint', 'invalid_value', 'and one in the future');
select is((pg_temp.close('c5', 'j1', 34000, 33900, interval '0 seconds', 'short by a hundred') -> 'result' ->> 'server_expected_cash')::bigint, 34050::bigint,
          'closing returns the server''s own figure next to what the phone sent');
reset role;
select is((select (expected_cash, server_expected_cash, counted_cash, difference, closed_by) = (34000, 34050, 33900, -100, pg_temp.u('juan'))
           from public.shifts where id = pg_temp.id('sh:j1')), true, 'the row holds both figures, the difference and who closed it');
select pg_temp.login('juan', 'A');
set local role authenticated;
select is(pg_temp.close('c6', 'j1', 34000, 33900) ->> 'hint', 'shift_closed', 'a closed shift cannot be closed again');
select is(pg_temp.open('j3', 'j3', 'S01', 5000) ->> 'status', 'ok', 'after closing, the cashier can open the next shift');
reset role;

-- someone else's shift: another cashier cannot close it, an admin or the owner can
select pg_temp.login('maria', 'A');
set local role authenticated;
select is(pg_temp.open('m1', 'm1', 'S01', 1000) ->> 'status', 'ok', 'an admin opens their own shift');
select pg_temp.login('juan', 'A');
select is(pg_temp.close('c7', 'm1', 1000, 1000) ->> 'hint', 'not_allowed', 'a cashier cannot close another person''s shift');
select pg_temp.login('owner', 'A');
select is(pg_temp.close('c8', 'm1', 1000, 1000) ->> 'status', 'ok', 'the owner can close it');
reset role;
select is((select (cashier_id, closed_by) = (pg_temp.u('maria'), pg_temp.u('owner')) from public.shifts where id = pg_temp.id('sh:m1')), true,
          'and the record keeps whose shift it was and who closed it');

-- ---------------------------------------------------------------------------
-- the table protects itself
-- ---------------------------------------------------------------------------
select throws_ok($$ update public.shifts set counted_cash = 1 where id = pg_temp.id('sh:j1') $$, '55000', null, 'a closed shift cannot be edited');
select throws_ok($$ update public.shifts set opening_cash = 1 where id = pg_temp.id('sh:j3') $$, '55000', null, 'an open shift cannot have its opening cash changed');
select throws_ok($$ delete from public.shifts where id = pg_temp.id('sh:j1') $$, '55000', null, 'a shift cannot be deleted');
select throws_ok($$ insert into public.shifts (id, tenant_id, location_id, cashier_id, open_op_id, currency, opening_cash, opened_at, closed_at)
                    values (pg_temp.id('sh:bad'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.u('pia'), pg_temp.id('op:bad'), 'PHP', 0, now(), now()) $$,
                 '23514', null, 'a half-closed shift cannot be stored');

-- ---------------------------------------------------------------------------
-- who can read, and the pull
-- ---------------------------------------------------------------------------
select pg_temp.login('pia', 'A');
set local role authenticated;
select is(pg_temp.open('pi5', 'pi', 'S02', 100) ->> 'status', 'ok', 'another cashier opens at the other store');
select is((select count(*)::int from public.shifts), 1, 'a cashier reads only their own shifts');
select pg_temp.login('maria', 'A');
select is((select count(*)::int from public.shifts), 3, 'an admin reads the shifts of their store (juan 2, her own 1), not the other store');
select pg_temp.login('owner', 'A');
select is((select count(*)::int from public.shifts), 4, 'the owner reads every shift of the business');
select pg_temp.login('pedro', 'A');
select is((select count(*)::int from public.shifts), 0, 'warehouse staff read none');
select pg_temp.login('ownerB', 'B');
select is((select count(*)::int from public.shifts), 0, 'another business reads none');
select throws_ok($$ insert into public.shifts (id, tenant_id, location_id, cashier_id, open_op_id, currency, opening_cash, opened_at)
                    values (pg_temp.id('sh:w'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.u('ownerB'), pg_temp.id('op:w'), 'PHP', 0, now()) $$,
                 '42501', null, 'nobody writes a shift from a client');
-- the pull holds back rows younger than 5 seconds; age the fixtures (triggers off for this one statement)
reset role;
set local session_replication_role = replica;
update public.shifts set updated_at = now() - interval '1 minute';
set local session_replication_role = origin;
select pg_temp.login('juan', 'A');
set local role authenticated;
select is(jsonb_array_length(public.sync_pull_shifts() -> 'rows'), 2, 'the pull sends a cashier their own shifts');
select is((public.sync_pull_shifts() -> 'rows' -> 0 ->> 'closed_at') is not null or (public.sync_pull_shifts() -> 'rows' -> 1 ->> 'closed_at') is not null, true, 'closed and open ones');
reset role;


-- ---------------------------------------------------------------------------
-- shift_expected_now: the server's figure for an open shift, for the cashier and for admins only
-- ---------------------------------------------------------------------------
reset role;
insert into public.sales (id, tenant_id, location_id, local_no, status, subtotal, total, sold_at, voided_at, created_by) values
  (pg_temp.id('s9'), pg_temp.t('A'), pg_temp.id('S01'), 'D-9', 'completed', 700, 700, now(), null, pg_temp.u('juan'));
insert into public.payments (tenant_id, sale_id, location_id, method, amount, tendered) values
  (pg_temp.t('A'), pg_temp.id('s9'), pg_temp.id('S01'), 'cash', 700, 700);
select pg_temp.login('juan', 'A');
set local role authenticated;
select is((public.shift_expected_now(pg_temp.id('sh:j3')) ->> 'server_expected_cash')::bigint, 19750::bigint, 'an open shift: its opening cash plus everything the cashier took in its window (5000 + 13000 + 1500 - 2500 + 2050 + 700)');
select pg_temp.login('pia', 'A');
select throws_ok($$ select public.shift_expected_now(pg_temp.id('sh:j3')) $$, '42501', null, 'another cashier cannot ask for it');
select pg_temp.login('maria', 'A');
select is((public.shift_expected_now(pg_temp.id('sh:j3')) ->> 'server_expected_cash')::bigint, 19750::bigint, 'an admin of the store can');
select throws_ok($$ select public.shift_expected_now(pg_temp.id('sh:nope')) $$, '22023', null, 'an unknown shift is refused');
reset role;
set local role anon;
select throws_ok($$ select public.shift_expected_now(pg_temp.id('sh:j3')) $$, '42501', null, 'and so is someone not signed in');
reset role;

select is((select count(*)::int from public.audit_log where tenant_id = pg_temp.t('A') and action in ('shift.open', 'shift.close')), 6, 'every open and close is in the audit log');

select * from finish();
rollback;
