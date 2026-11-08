-- P8-14 opening cash (sukli) in the day close: close_day without opening_cash unchanged, opening_cash stored and part of
-- server_expected_cash, bad values refused, audit meta, supervisor approval rules unchanged, append-only, pull carries it
begin;
select plan(37);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('id:' || p)::uuid $$;
create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;
create function pg_temp.push1(k text, payload jsonb) returns jsonb language sql as $$
  select public.sync_push(jsonb_build_array(
    jsonb_build_object('op_id', pg_temp.id('op:' || k), 'kind', 'close_day', 'payload', payload))) -> 0
$$;
-- a close of store loc with expected / counted / opening cash (opening null = the key is not sent)
create function pg_temp.close(k text, loc text, expected bigint, counted bigint, opening bigint default null,
                              approval uuid default null, day text default '2026-11-05') returns jsonb language sql as $$
  select pg_temp.push1(k, jsonb_strip_nulls(jsonb_build_object(
    'id', pg_temp.id('dc:' || k), 'location_id', pg_temp.id(loc), 'day', day,
    'expected_cash', expected, 'counted_cash', counted, 'opening_cash', opening, 'approval_id', approval)))
$$;
-- a close of S01 on 2026-11-05 with any opening_cash JSON value (not stripped)
create function pg_temp.raw(k text, opening jsonb) returns jsonb language sql as $$
  select pg_temp.push1(k, jsonb_build_object(
    'id', pg_temp.id('dc:' || k), 'location_id', pg_temp.id('S01'), 'day', '2026-11-05',
    'expected_cash', 1, 'counted_cash', 1, 'opening_cash', opening))
$$;
create function pg_temp.row(k text) returns text language sql as $$
  select (opening_cash, expected_cash, counted_cash, difference, server_expected_cash)::text
  from public.day_closes where id = pg_temp.id('dc:' || k)
$$;
create temp table ap (k text primary key, id uuid);
grant all on ap to authenticated;
create function pg_temp.approve(k text, ref text, pin text, loc text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := public.approve_supervisor_action('close_day', pg_temp.id('dc:' || ref), pin, pg_temp.id(loc));
  insert into pg_temp.ap values (k, (r ->> 'approval_id')::uuid);
  return r;
end;
$$;
create function pg_temp.ap(k text) returns uuid language sql as $$ select id from pg_temp.ap where ap.k = $1 $$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'sara', 'juan']) n;
insert into public.tenants (id, name, slug, base_currency, timezone) values (pg_temp.t('A'), 'A', 'tenant-a', 'PHP', 'Asia/Manila');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.t('A'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('sara'), pg_temp.t('A'), 'sara', 'admin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'A1'),
  (pg_temp.id('S02'), pg_temp.t('A'), 'store', 'S02', 'A2');
-- maria: manager S01. sara: supervisor S01. juan: cashier S01.
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sara'), pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null);

-- S01, 2026-11-05 (Manila): one cash sale 10000, one cash expense 2500 -> day flow 7500.
-- S01, 2026-11-06 (Manila): only a cash expense of 300 -> day flow -300.
insert into public.sales (id, tenant_id, location_id, local_no, status, subtotal, total, sold_at) values
  (pg_temp.id('s1'), pg_temp.t('A'), pg_temp.id('S01'), 'D-0001', 'completed', 10000, 10000, '2026-11-05T01:00:00Z');
insert into public.payments (tenant_id, sale_id, location_id, method, amount, tendered) values
  (pg_temp.t('A'), pg_temp.id('s1'), pg_temp.id('S01'), 'cash', 10000, 10000);
insert into public.expenses (id, tenant_id, location_id, client_op_id, amount, currency, category, paid_from, spent_at) values
  (pg_temp.id('e1'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('eop1'), 2500, 'PHP', 'utilities', 'cash', '2026-11-05T03:00:00Z'),
  (pg_temp.id('e2'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('eop2'), 300, 'PHP', 'other', 'cash', '2026-11-06T03:00:00Z');

select is((public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S01'), '2026-11-05'),
           public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S01'), '2026-11-06'))::text, '(7500,-300)',
          'the day cash flow itself is unchanged (no opening cash in it)');

-- ===== owner =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.close('n1', 'S01', 7500, 7400) ->> 'status', 'ok', 'a close without opening_cash is accepted as before');
select is(pg_temp.row('n1'), '(0,7500,7400,-100,7500)', 'it stores opening 0 and the server figure is the day flow, as before');
select is((select (r ->> 'opening_cash', r ->> 'server_expected_cash', r ->> 'difference')::text
           from (select pg_temp.close('o1', 'S01', 57500, 57400, 50000) -> 'result' as r) x),
          '(50000,57500,-100)', 'with opening_cash the result has it and the server figure includes it');
select is(pg_temp.row('o1'), '(50000,57500,57400,-100,57500)',
          'the row keeps the opening cash; expected (from the phone) includes it; difference = counted - expected');
select is((select (r ->> 'replay', r ->> 'opening_cash')::text
           from (select pg_temp.close('o1', 'S01', 1, 1, 1) -> 'result' as r) x),
          '(true,50000)', 'a resend with other figures is a replay of the first result');
reset role;
select is((select (count(*), max(opening_cash))::text from public.day_closes where client_op_id = pg_temp.id('op:o1')),
          '(1,50000)', 'the replay wrote nothing');
set local role authenticated;
select is(pg_temp.raw('str', '"2500"') ->> 'status', 'ok', 'opening_cash may be a digit string');
select is(pg_temp.row('str'), '(2500,1,1,0,10000)', 'and is stored as centavos (server figure 2500 + 7500)');
select is(pg_temp.raw('nul', 'null') ->> 'status', 'ok', 'a JSON null opening_cash is accepted');
select is(pg_temp.row('nul'), '(0,1,1,0,7500)', 'and means 0');
select is(pg_temp.close('z1', 'S01', 7500, 7500, 0) -> 'result' ->> 'server_expected_cash', '7500', 'an explicit 0 is fine');
select is(pg_temp.close('x6', 'S01', 49700, 49700, 50000, day => '2026-11-06') -> 'result' ->> 'server_expected_cash', '49700',
          'a day with only an expense: opening 50000 - 300 = 49700, no longer below zero');
select is(pg_temp.row('x6'), '(50000,49700,49700,0,49700)', 'and the count matches exactly');

-- ===== bad opening cash =====
select is(pg_temp.raw('b1', '-1') ->> 'hint', 'amount_invalid', 'a negative opening cash is refused');
select is(pg_temp.raw('b2', '100.5') ->> 'hint', 'amount_invalid', 'a fractional opening cash is refused');
select is(pg_temp.raw('b3', '"12.50"') ->> 'hint', 'amount_invalid', 'a decimal string is refused');
select is(pg_temp.raw('b4', '"abc"') ->> 'hint', 'amount_invalid', 'text is refused');
select is(pg_temp.raw('b5', 'true') ->> 'hint', 'amount_invalid', 'a boolean is refused');
select is(pg_temp.raw('b6', '"-5"') ->> 'hint', 'amount_invalid', 'a negative digit string is refused');
select is(pg_temp.raw('b7', '{}') ->> 'hint', 'amount_invalid', 'an object is refused');
select is(pg_temp.raw('b8', '1234567890123456') ->> 'hint', 'amount_invalid', 'more than 15 digits is refused');
reset role;
select is((select count(*)::int from public.day_closes where id in (select pg_temp.id('dc:b' || g) from generate_series(1, 8) g))
          + (select count(*)::int from public.audit_log where action = 'day.close'
             and entity_id in (select pg_temp.id('dc:b' || g) from generate_series(1, 8) g)), 0,
          'refused closes leave no row and no audit entry');

-- ===== audit =====
select is((select array_agg(meta ->> 'opening_cash' order by meta ->> 'opening_cash') from public.audit_log
           where action = 'day.close' and entity_id in (pg_temp.id('dc:n1'), pg_temp.id('dc:o1'))),
          array['0', '50000'], 'the audit meta has the opening cash (0 when none was sent)');
select is((select (meta ->> 'expected_cash', meta ->> 'server_expected_cash', meta ->> 'difference')::text from public.audit_log
           where action = 'day.close' and entity_id = pg_temp.id('dc:o1')),
          '(57500,57500,-100)', 'and the same figures as the row');

-- ===== who may close: unchanged =====
select pg_temp.login('sara', 'A');
set local role authenticated;
select is(pg_temp.close('s1', 'S01', 1100, 1100, 1000) ->> 'hint', 'approval_required', 'a supervisor still needs an approval');
select is(public.set_my_pin('4821') ->> 'ok', 'true', 'she sets her PIN');
select is(pg_temp.approve('a1', 's1', '4821', 'S01') ->> 'ok', 'true', 'and gets a close_day approval');
select is(pg_temp.close('s1', 'S01', 1100, 1100, 1000, pg_temp.ap('a1')) ->> 'status', 'ok', 'with it she closes with an opening');
reset role;
select is((select (opening_cash, approved_by = pg_temp.u('sara'))::text from public.day_closes where id = pg_temp.id('dc:s1')),
          '(1000,t)', 'the opening cash and the approver are stored');
select pg_temp.login('maria', 'A');
set local role authenticated;
select is(pg_temp.close('m1', 'S01', 500, 500, 500) ->> 'status', 'ok', 'a store manager closes with an opening without approval');
select is(pg_temp.close('m2', 'S02', 500, 500, 500) ->> 'hint', 'location_denied', 'but not at a store that is not hers');
select pg_temp.login('juan', 'A');
select is(pg_temp.close('j1', 'S01', 500, 500, 500) ->> 'hint', 'not_allowed', 'a cashier cannot close the day');
reset role;

-- ===== append-only and the column rules =====
select throws_ok(format($$ update public.day_closes set opening_cash = 1 where id = %L $$, pg_temp.id('dc:o1')),
                 '55000', null, 'the opening cash is never edited');
select throws_ok(format($$ insert into public.day_closes (id, tenant_id, location_id, client_op_id, day, currency, opening_cash,
                            expected_cash, counted_cash, difference, server_expected_cash, closed_at)
                          values (gen_random_uuid(), %L, %L, gen_random_uuid(), '2026-11-05', 'PHP', -1, 0, 0, 0, 0, now()) $$,
                        pg_temp.t('A'), pg_temp.id('S01')), '23514', null, 'the table refuses an opening cash below zero');

-- ===== pull =====
set local session_replication_role = replica;
update public.day_closes set updated_at = now() - interval '1 minute';
set local session_replication_role = origin;
select pg_temp.login('owner', 'A');
set local role authenticated;
select is((select (select array_agg(k order by k) from jsonb_object_keys(r -> 'rows' -> 0) k)::text
           from (select public.sync_pull_day_closes() r) x),
          '{approved_by,closed_at,closed_by,counted_cash,currency,day,difference,expected_cash,id,location_id,note,opening_cash,server_expected_cash,updated_at}',
          'pulled rows carry opening_cash');
select is((select string_agg(e ->> 'opening_cash' || '/' || (e ->> 'server_expected_cash'), ',' order by e ->> 'opening_cash')
           from jsonb_array_elements(public.sync_pull_day_closes() -> 'rows') e
           where e ->> 'id' in (pg_temp.id('dc:n1')::text, pg_temp.id('dc:o1')::text)),
          '0/7500,50000/57500', 'with the stored opening and server figures');

select * from finish();
rollback;
