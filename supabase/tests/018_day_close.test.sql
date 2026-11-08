-- P8-02c day close: close_day op (permissions, supervisor approval, idempotency, audit, bad input),
-- server_expected_cash computed from server data, sync_pull_day_closes, append-only table
begin;
select plan(53);

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
-- a close of store loc for day with expected / counted cash
create function pg_temp.close(k text, dc text, loc text, expected bigint, counted bigint, approval uuid default null,
                              day text default '2026-11-05', note text default null) returns jsonb language sql as $$
  select pg_temp.push1(k, 'close_day', jsonb_strip_nulls(jsonb_build_object(
    'id', pg_temp.id('dc:' || dc), 'location_id', pg_temp.id(loc), 'day', day,
    'expected_cash', expected, 'counted_cash', counted, 'note', note, 'approval_id', approval)))
$$;
create function pg_temp.raw(k text, payload jsonb) returns text language sql as $$
  select pg_temp.push1(k, 'close_day', jsonb_build_object('location_id', pg_temp.id('S01')) || payload) ->> 'hint'
$$;
create temp table ap (k text primary key, id uuid);
grant all on ap to authenticated;
create function pg_temp.approve(k text, action text, ref text, pin text, loc text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := public.approve_supervisor_action(action, pg_temp.id('dc:' || ref), pin, pg_temp.id(loc));
  insert into pg_temp.ap values (k, (r ->> 'approval_id')::uuid);
  return r;
end;
$$;
create function pg_temp.ap(k text) returns uuid language sql as $$ select id from pg_temp.ap where ap.k = $1 $$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'sara', 'juan', 'pedro', 'ownerB']) n;
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP', 'Asia/Manila'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP', 'UTC');
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
  (pg_temp.id('S02'), pg_temp.t('A'), 'store', 'S02', 'A2'),
  (pg_temp.id('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'AW'),
  (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'S01', 'B1');
-- maria: manager S01 only. sara: supervisor S01 + S02. juan: cashier S01. pedro: warehouse W01.
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sara'), pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('sara'), pg_temp.id('S02'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null);

-- ---------------------------------------------------------------------------
-- Server data for 2026-11-05 in Asia/Manila = [2026-11-04T16:00Z, 2026-11-05T16:00Z)
-- ---------------------------------------------------------------------------
insert into public.customers (id, tenant_id, name) values (pg_temp.id('cus'), pg_temp.t('A'), 'Rosa');
insert into public.sales (id, tenant_id, location_id, local_no, status, subtotal, total, sold_at, voided_at) values
  (pg_temp.id('s1'), pg_temp.t('A'), pg_temp.id('S01'), 'D-0001', 'completed', 10000, 10000, '2026-11-05T01:00:00Z', null),
  (pg_temp.id('s2'), pg_temp.t('A'), pg_temp.id('S01'), 'D-0002', 'completed', 5000, 5000, '2026-11-05T15:59:59Z', null),
  (pg_temp.id('s3'), pg_temp.t('A'), pg_temp.id('S01'), 'D-0003', 'voided', 5000, 5000, '2026-11-05T02:00:00Z', '2026-11-05T03:00:00Z'),
  (pg_temp.id('s4'), pg_temp.t('A'), pg_temp.id('S02'), 'D-0004', 'completed', 7000, 7000, '2026-11-05T02:00:00Z', null),
  (pg_temp.id('s5'), pg_temp.t('A'), pg_temp.id('S01'), 'D-0005', 'completed', 900, 900, '2026-11-04T15:59:59Z', null),
  (pg_temp.id('s6'), pg_temp.t('A'), pg_temp.id('S01'), 'D-0006', 'completed', 800, 800, '2026-11-05T16:00:00Z', null),
  (pg_temp.id('s7'), pg_temp.t('A'), pg_temp.id('S01'), 'D-0007', 'completed', 4000, 4000, '2026-11-05T04:00:00Z', null);
insert into public.payments (tenant_id, sale_id, location_id, method, amount, tendered) values
  (pg_temp.t('A'), pg_temp.id('s1'), pg_temp.id('S01'), 'cash', 10000, 10000),
  (pg_temp.t('A'), pg_temp.id('s2'), pg_temp.id('S01'), 'cash', 3000, 5000),     -- change is not counted
  (pg_temp.t('A'), pg_temp.id('s2'), pg_temp.id('S01'), 'ewallet', 2000, null),
  (pg_temp.t('A'), pg_temp.id('s3'), pg_temp.id('S01'), 'cash', 5000, null),     -- voided sale
  (pg_temp.t('A'), pg_temp.id('s4'), pg_temp.id('S02'), 'cash', 7000, null),     -- other store
  (pg_temp.t('A'), pg_temp.id('s5'), pg_temp.id('S01'), 'cash', 900, null),      -- the day before (Manila)
  (pg_temp.t('A'), pg_temp.id('s6'), pg_temp.id('S01'), 'cash', 800, null),      -- the day after (Manila)
  (pg_temp.t('A'), pg_temp.id('s7'), pg_temp.id('S01'), 'utang', 4000, null);
insert into public.customer_ledger (tenant_id, customer_id, kind, amount, sale_id, occurred_at) values
  (pg_temp.t('A'), pg_temp.id('cus'), 'charge', 4000, pg_temp.id('s7'), '2026-11-05T04:00:00Z'),
  (pg_temp.t('A'), pg_temp.id('cus'), 'payment', -1500, null, '2026-11-05T05:00:00Z'),
  (pg_temp.t('A'), pg_temp.id('cus'), 'adjust', -200, null, '2026-11-05T06:00:00Z'),
  (pg_temp.t('A'), pg_temp.id('cus'), 'payment', -700, null, '2026-11-06T05:00:00Z');
insert into public.expenses (id, tenant_id, location_id, client_op_id, amount, currency, category, paid_from, spent_at, voided_at) values
  (pg_temp.id('e1'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('eop1'), 2500, 'PHP', 'utilities', 'cash', '2026-11-05T03:00:00Z', null),
  (pg_temp.id('e2'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('eop2'), 1000, 'PHP', 'transport', 'ewallet', '2026-11-05T03:00:00Z', null),
  (pg_temp.id('e3'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('eop3'), 600, 'PHP', 'other', 'cash', '2026-11-05T03:00:00Z', '2026-11-05T04:00:00Z'),
  (pg_temp.id('e4'), pg_temp.t('A'), pg_temp.id('S02'), pg_temp.id('eop4'), 400, 'PHP', 'other', 'cash', '2026-11-05T03:00:00Z', null);

-- S01: 10000 + 3000 cash sales + 1500 utang paid - 2500 cash expense = 12000
select is(public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S01'), '2026-11-05'), 12000::bigint,
          'server expected cash: completed cash sales + utang payments - cash expenses, Manila day bounds');
-- S02: 7000 + 1500 (utang payments have no store: counted tenant-wide) - 400 = 8100
select is(public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S02'), '2026-11-05'), 8100::bigint,
          'utang payments carry no store and count at every store');
select is(public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S01'), '2026-11-04'), 900::bigint,
          'the sale one second before Manila midnight belongs to the day before');

-- ===== owner =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.close('o1', 'o1', 'S01', 12000, 11800, note => '  kulang ng 2  ') ->> 'status', 'ok', 'the owner closes the day');
select is((select (expected_cash, counted_cash, difference, server_expected_cash, closed_by = pg_temp.u('owner'),
                   approved_by is null, note, day, currency)::text
           from public.day_closes where id = pg_temp.id('dc:o1')),
          '(12000,11800,-200,12000,t,t,"kulang ng 2",2026-11-05,PHP)',
          'the row keeps what was counted, the difference, the server''s own figure and who closed');
select is((select (r ->> 'difference', r ->> 'server_expected_cash', r ->> 'day', r ->> 'day_close_id' = pg_temp.id('dc:o1')::text,
                   r ? 'applied_at')::text
           from (select pg_temp.close('o1', 'o1', 'S01', 12000, 11800) -> 'result' as r) x),
          '(-200,12000,2026-11-05,t,t)', 'the result (here a replay) has the difference and the server figure');
select is(pg_temp.close('o1', 'o1', 'S01', 12000, 11800) -> 'result' ->> 'replay', 'true', 'a resend is a replay');
reset role;
select is((select count(*)::int from public.day_closes where client_op_id = pg_temp.id('op:o1')), 1, 'the replay wrote no second row');
select is((select count(*)::int from public.audit_log where action = 'day.close' and entity_id = pg_temp.id('dc:o1')), 1,
          'one audit row, not one per resend');
select is((select (user_id = pg_temp.u('owner'), entity, location_id = pg_temp.id('S01'), meta ->> 'day', meta ->> 'expected_cash',
                   meta ->> 'counted_cash', meta ->> 'difference', meta ->> 'server_expected_cash',
                   meta ->> 'op_id' = pg_temp.id('op:o1')::text, meta ? 'approved_by')::text
           from public.audit_log where action = 'day.close' and entity_id = pg_temp.id('dc:o1')),
          '(t,day_close,t,2026-11-05,12000,11800,-200,12000,t,f)', 'the audit row has the store, day, amounts and op id');
set local role authenticated;
select is(pg_temp.close('o2', 'o2', 'S01', 12000, 12000) ->> 'status', 'ok', 'a re-count of the same day is another close');
select is((select count(*)::int from public.day_closes where location_id = pg_temp.id('S01') and day = '2026-11-05'), 2,
          'both closes are kept (the app shows the newest)');
select is(pg_temp.close('o3', 'o3', 'S02', 9000, 9100) -> 'result' ->> 'server_expected_cash', '8100',
          'a mismatch between the app''s and the server''s figure is stored, not refused');
select is(pg_temp.close('o4', 'o4', 'S01', -500, 0, day => '2026-11-06') -> 'result' ->> 'difference', '500',
          'expected cash may be below zero');

-- ===== manager, supervisor, others =====
select pg_temp.login('maria', 'A');
select is(pg_temp.close('m1', 'm1', 'S01', 100, 100) ->> 'status', 'ok', 'a store manager closes without an approval');
select is(pg_temp.close('m2', 'm2', 'S02', 100, 100) ->> 'hint', 'location_denied', 'but not at a store that is not hers');

select pg_temp.login('sara', 'A');
select is(pg_temp.close('s1', 's1', 'S01', 100, 90) ->> 'hint', 'approval_required', 'a supervisor needs an approval');
select is(public.set_my_pin('4821') ->> 'ok', 'true', 'she sets her PIN');
select is(pg_temp.approve('a1', 'close_day', 's1', '4821', 'S01') ->> 'ok', 'true', 'and gets a close_day approval');
select is(pg_temp.close('s1', 's1', 'S01', 100, 90, pg_temp.ap('a1')) ->> 'status', 'ok', 'with it she closes');
reset role;
select is((select (closed_by = pg_temp.u('sara'), approved_by = pg_temp.u('sara'))::text from public.day_closes where id = pg_temp.id('dc:s1')),
          '(t,t)', 'the row says who closed and who approved');
select is((select meta ->> 'approved_by' from public.audit_log where action = 'day.close' and entity_id = pg_temp.id('dc:s1')),
          pg_temp.u('sara')::text, 'the audit row names the approver');
set local role authenticated;
select is(pg_temp.close('s1', 's1', 'S01', 100, 90, pg_temp.ap('a1')) -> 'result' ->> 'replay', 'true', 'her resend is a replay');
select is(pg_temp.close('s1b', 's2', 'S01', 100, 90, pg_temp.ap('a1')) ->> 'hint', 'approval_invalid', 'an approval is for one close only');
select pg_temp.approve('a2', 'close_day', 's1', '4821', 'S01');
select is(pg_temp.close('s1c', 's1', 'S01', 100, 90, pg_temp.ap('a2')) ->> 'hint', 'id_conflict', 'a used close id is refused');
reset role;
select is((select used_at from public.supervisor_approvals where id = pg_temp.ap('a2')), null, 'and the approval is not used up');
set local role authenticated;
select pg_temp.approve('a3', 'record_expense', 's3', '4821', 'S01');
select is(pg_temp.close('s3', 's3', 'S01', 100, 90, pg_temp.ap('a3')) ->> 'hint', 'approval_invalid', 'an expense approval cannot close the day');
select pg_temp.approve('a4', 'close_day', 's4', '4821', 'S02');
select is(pg_temp.close('s4', 's4', 'S01', 100, 90, pg_temp.ap('a4')) ->> 'hint', 'approval_invalid', 'an approval for another store is refused');
select pg_temp.approve('a5', 'close_day', 's5', '4821', 'S01');
reset role;
update public.supervisor_approvals set expires_at = now() - interval '1 second' where id = pg_temp.ap('a5');
set local role authenticated;
select is(pg_temp.close('s5', 's5', 'S01', 100, 90, pg_temp.ap('a5')) ->> 'hint', 'approval_expired', 'an expired approval is refused');
select pg_temp.approve('a6', 'close_day', 's6', '4821', 'S01');
select is(pg_temp.close('s6', 's6', 'S01', 100, 90, pg_temp.ap('a6')) ->> 'status', 'ok', 'a fresh approval works');
select is(pg_temp.close('s6b', 's6', 'S01', 100, 90, pg_temp.ap('a6')) ->> 'hint', 'approval_used', 'and only once');

select pg_temp.login('juan', 'A');
select is(pg_temp.close('j1', 'j1', 'S01', 100, 100) ->> 'hint', 'not_allowed', 'a cashier cannot close the day');
select throws_ok($$ select public.approve_supervisor_action('close_day', md5('id:dc:j1')::uuid, '1234', md5('id:S01')::uuid) $$,
                 '42501', null, 'nor ask for an approval to');
select pg_temp.login('pedro', 'A');
select is(pg_temp.close('p1', 'p1', 'S01', 100, 100) ->> 'hint', 'not_allowed', 'warehouse staff cannot close the day');

-- ===== bad input =====
select pg_temp.login('owner', 'A');
select is(pg_temp.raw('b1', jsonb_build_object('day', '2026-11-05', 'expected_cash', 1, 'counted_cash', 1)), 'id_required', 'the id is required');
select is(pg_temp.raw('b2', jsonb_build_object('id', pg_temp.id('dc:b2'), 'day', '05/11/2026', 'expected_cash', 1, 'counted_cash', 1)),
          'invalid_value', 'the day is YYYY-MM-DD');
select is(pg_temp.raw('b3', jsonb_build_object('id', pg_temp.id('dc:b3'), 'day', '2026-02-30', 'expected_cash', 1, 'counted_cash', 1)),
          'invalid_value', 'the day must exist');
select is(pg_temp.close('b4', 'b4', 'S01', 1, 1, day => to_char(now() + interval '5 days', 'YYYY-MM-DD')) ->> 'hint', 'invalid_value',
          'a day in the future is refused');
select is(pg_temp.close('b5', 'b5', 'S01', 100, -1) ->> 'hint', 'amount_invalid', 'counted cash cannot be negative');
select is(pg_temp.raw('b6', jsonb_build_object('id', pg_temp.id('dc:b6'), 'day', '2026-11-05', 'expected_cash', 1, 'counted_cash', 100.5)),
          'amount_invalid', 'cash is whole centavos');
select is(pg_temp.raw('b7', jsonb_build_object('id', pg_temp.id('dc:b7'), 'day', '2026-11-05', 'counted_cash', 1)),
          'amount_invalid', 'expected cash is required');
select is(pg_temp.raw('b8', jsonb_build_object('id', pg_temp.id('dc:b8'), 'day', '2026-11-05', 'expected_cash', 1, 'counted_cash', 1,
                                               'currency', 'USD')), 'invalid_value', 'only the base currency');
reset role;
insert into public.processed_ops (tenant_id, client_op_id, kind, user_id)
  values (pg_temp.t('A'), pg_temp.id('op:px'), 'record_expense', pg_temp.u('owner'));
set local role authenticated;
select is(pg_temp.close('px', 'px', 'S01', 1, 1) ->> 'hint', 'op_id_reused', 'an op id used for another kind is refused');
reset role;
select is((select count(*)::int from public.day_closes where id in (select pg_temp.id('dc:' || x) from unnest(array['b1', 'b2', 'b3',
             'b4', 'b5', 'b6', 'b7', 'b8', 'j1', 'p1', 's3', 's4', 's5', 'm2']) x))
          + (select count(*)::int from public.audit_log where action = 'day.close' and entity_id in
             (select pg_temp.id('dc:' || x) from unnest(array['b2', 'b5', 'j1', 'p1', 's3', 's4', 's5', 'm2']) x)), 0,
          'refused closes leave no row and no audit entry');

update public.tenant_modules set pos = false where tenant_id = pg_temp.t('A');
set local role authenticated;
select is(pg_temp.close('md', 'md', 'S01', 1, 1) ->> 'hint', 'module_disabled', 'no close without the POS module');
reset role;
update public.tenant_modules set pos = true where tenant_id = pg_temp.t('A');

-- ===== append-only =====
select throws_ok(format($$ update public.day_closes set counted_cash = 1 where id = %L $$, pg_temp.id('dc:o1')),
                 '55000', null, 'a close is never edited');
select throws_ok(format($$ delete from public.day_closes where id = %L $$, pg_temp.id('dc:o1')),
                 '55000', null, 'nor deleted');
set local role authenticated;
select throws_ok(format($$ insert into public.day_closes (id, tenant_id, location_id, client_op_id, day, currency, expected_cash,
                            counted_cash, difference, server_expected_cash, closed_at)
                          values (gen_random_uuid(), %L, %L, gen_random_uuid(), '2026-11-05', 'PHP', 0, 0, 0, 0, now()) $$,
                        pg_temp.t('A'), pg_temp.id('S01')), '42501', null, 'clients cannot write closes directly');

-- ===== pull =====
select is(jsonb_array_length(public.sync_pull_day_closes() -> 'rows'), 0, 'closes newer than 5 seconds wait for the next pull');
reset role;
set local session_replication_role = replica;
update public.day_closes set updated_at = now() - interval '1 minute';
set local session_replication_role = origin;
set local role authenticated;
select is((select (jsonb_array_length(r -> 'rows'), r ->> 'has_more',
                   (select array_agg(k order by k) from jsonb_object_keys(r -> 'rows' -> 0) k))::text
           from (select public.sync_pull_day_closes() r) x),
          -- opening_cash added by P8-14 (20261108001800_opening_cash.sql)
          '(7,false,"{approved_by,closed_at,closed_by,counted_cash,currency,day,difference,expected_cash,id,location_id,note,opening_cash,server_expected_cash,updated_at}")',
          'the owner pulls every close of the tenant with the documented fields');
select is((select (jsonb_array_length(p1 -> 'rows'), p1 ->> 'has_more',
                   jsonb_array_length(public.sync_pull_day_closes(p1 -> 'cursor', 200) -> 'rows'))::text
           from (select public.sync_pull_day_closes(null, 5) p1) x),
          '(5,true,2)', 'pages follow the cursor');
select pg_temp.login('juan', 'A');
select is(jsonb_array_length(public.sync_pull_day_closes() -> 'rows'), 0, 'a cashier pulls no closes');
select pg_temp.login('ownerB', 'B');
select is(jsonb_array_length(public.sync_pull_day_closes() -> 'rows'), 0, 'another tenant pulls none of ours');

select * from finish();
rollback;
