-- P8-10 utang due dates: customers.due_on, the set_utang_due op (set, clear, no-change, replay, bad dates, permissions,
-- tenants, audit) and delivery through sync_pull_pos (the field on customers rows, the change moves updated_at so the
-- delta pull sends it again).
begin;
select plan(38);

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
-- due: a jsonb value for due_on ('"2026-11-20"', 'null', '12', ...); cus: the customer key
create function pg_temp.due(k text, due jsonb, cus text default 'rosa') returns jsonb language sql as $$
  select pg_temp.push1(k, 'set_utang_due', jsonb_build_object('customer_id', pg_temp.id('cus:' || cus), 'due_on', due))
$$;
create function pg_temp.d(offset_days int) returns jsonb language sql stable as $$
  select to_jsonb(to_char(current_date + offset_days, 'YYYY-MM-DD'))
$$;
create function pg_temp.due_on(cus text default 'rosa') returns date language sql as $$
  select due_on from public.customers where id = pg_temp.id('cus:' || cus)
$$;
create function pg_temp.audits() returns int language sql as $$
  select count(*)::int from public.audit_log where tenant_id = pg_temp.t('A') and action = 'utang.set_due'
$$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'sara', 'juan', 'pedro', 'ownerB', 'ownerC']) n;
insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP'), (pg_temp.t('C'), 'C', 'tenant-c', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values
  (pg_temp.t('A'), true, true), (pg_temp.t('B'), true, false), (pg_temp.t('C'), false, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B')), (pg_temp.t('C'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('sara'), pg_temp.t('A'), 'sara', 'admin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('pedro'), pg_temp.t('A'), 'pedro', 'warehouse', true),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true),
  (pg_temp.u('ownerC'), pg_temp.t('C'), 'owner', 'superadmin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'A1'),
  (pg_temp.id('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'AW'),
  (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'S01', 'B1');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sara'), pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null);
insert into public.customers (id, tenant_id, name, phone) values
  (pg_temp.id('cus:rosa'), pg_temp.t('A'), 'Aling Rosa', '09171234567'),
  (pg_temp.id('cus:berto'), pg_temp.t('A'), 'Berto', null),
  (pg_temp.id('cus:bee'), pg_temp.t('B'), 'B customer', null);
-- every customer row is older than the pull hold-back to begin with
set local session_replication_role = replica;
update public.customers set updated_at = now() - interval '1 hour';
set local session_replication_role = origin;

select has_column('public', 'customers', 'due_on', 'customers have a due date column');
select col_type_is('public', 'customers', 'due_on', 'date', 'the due date is a date (no time, no zone)');

-- the first pull: the field is there (null), and its cursor marks "everything so far"
select pg_temp.login('owner', 'A');
set local role authenticated;
create temp table pull0 as select public.sync_pull_pos('{}'::jsonb, 500) as r;
grant select on pull0 to authenticated;
select is((select (x ? 'due_on') and x -> 'due_on' = 'null'::jsonb from pull0, jsonb_array_elements(r -> 'customers' -> 'rows') x
           where x ->> 'id' = pg_temp.id('cus:rosa')::text), true, 'pulled customers carry due_on (null when none)');

-- ===== set =====
select is((pg_temp.due('d1', pg_temp.d(7)) -> 'result')::jsonb - 'applied_at',
          jsonb_build_object('customer_id', pg_temp.id('cus:rosa'), 'due_on', current_date + 7, 'changed', true, 'replay', false),
          'the owner sets a due date a week away');
select is(pg_temp.due_on(), current_date + 7, 'the customer carries it');
reset role;
select is((select updated_at from public.customers where id = pg_temp.id('cus:rosa')), now(),
          'setting it moves updated_at (so the delta pull sends it)');
select is((select updated_at from public.customers where id = pg_temp.id('cus:berto')), now() - interval '1 hour',
          'other customers are untouched');
set local role authenticated;
select is(pg_temp.due('d1', pg_temp.d(7)) -> 'result' ->> 'replay', 'true', 'a resent op is a replay');
select is(pg_temp.due('d2', pg_temp.d(7)) -> 'result' ->> 'changed', 'false', 'the same date again changes nothing');
reset role;
select is(pg_temp.audits(), 1, 'one audit row: the replay and the no-change send write none');
select is((select (select array_agg(k order by k) from jsonb_object_keys(meta) k)::text from public.audit_log
           where tenant_id = pg_temp.t('A') and action = 'utang.set_due'), '{due_on,op_id,previous}', 'the audit row has small meta');
select is((select (entity, entity_id = pg_temp.id('cus:rosa'), meta ->> 'previous')::text from public.audit_log
           where tenant_id = pg_temp.t('A') and action = 'utang.set_due'), '(customer,t,)', 'it names the customer and the old value (none)');

-- ===== delivered by the delta pull =====
set local session_replication_role = replica;
update public.customers set updated_at = now() - interval '30 seconds' where id = pg_temp.id('cus:rosa');
set local session_replication_role = origin;
set local role authenticated;
create temp table pull1 as select public.sync_pull_pos((select jsonb_build_object('customers', r -> 'customers' -> 'cursor') from pull0), 500) as r;
grant select on pull1 to authenticated;
select is((select jsonb_array_length(r -> 'customers' -> 'rows') from pull1), 1, 'the delta pull after the first cursor returns only the changed customer');
select is((select x ->> 'due_on' from pull1, jsonb_array_elements(r -> 'customers' -> 'rows') x),
          to_char(current_date + 7, 'YYYY-MM-DD'), 'with its due date as YYYY-MM-DD');
select is((select (x ? 'phone') and (x ? 'name') from pull1, jsonb_array_elements(r -> 'customers' -> 'rows') x), true,
          'the row keeps its other fields (additive)');

-- ===== change and clear =====
select is(pg_temp.due('d3', pg_temp.d(-1)) ->> 'status', 'ok', 'a date in the past is allowed (a promise already missed)');
select is(pg_temp.due_on(), current_date - 1, 'the date moved');
select is((pg_temp.due('d4', 'null') -> 'result')::jsonb - 'applied_at' - 'customer_id',
          '{"due_on": null, "changed": true, "replay": false}'::jsonb, 'null clears the date');
select is(pg_temp.due_on(), null::date, 'the customer has no due date any more');
select is(pg_temp.due('d5', 'null') -> 'result' ->> 'changed', 'false', 'clearing again changes nothing');
reset role;
select is(pg_temp.audits(), 3, 'set, change and clear: three audit rows');
select is((select meta ->> 'previous' from public.audit_log where tenant_id = pg_temp.t('A') and action = 'utang.set_due' and meta ->> 'due_on' is null),
          to_char(current_date - 1, 'YYYY-MM-DD'), 'the clear records what it cleared');

-- ===== bad input =====
set local role authenticated;
select is(pg_temp.push1('b1', 'set_utang_due', jsonb_build_object('customer_id', pg_temp.id('cus:rosa'))) ->> 'hint',
          'invalid_value', 'due_on must be sent (null to clear), never assumed');
select is(pg_temp.due('b2', '"2026/11/20"') ->> 'hint', 'invalid_value', 'a date with slashes is refused');
select is(pg_temp.due('b3', '"2027-02-30"') ->> 'hint', 'invalid_value', 'a day that does not exist is refused');
select is(pg_temp.due('b4', '20261120') ->> 'hint', 'invalid_value', 'a number is refused');
select is(pg_temp.due('b5', '"2026-11-20T00:00:00Z"') ->> 'hint', 'invalid_value', 'a timestamp is refused (a date only)');
select is(pg_temp.due('b6', pg_temp.d(365 * 2 + 2)) ->> 'hint', 'invalid_value', 'more than 2 years away is refused');
select is(pg_temp.due('b7', pg_temp.d(-(365 * 2 + 2))) ->> 'hint', 'invalid_value', 'more than 2 years ago is refused');
select is(pg_temp.due('b8', pg_temp.d(7), 'nobody') ->> 'hint', 'unknown_customer', 'an unknown customer is refused');
select is(pg_temp.due_on(), null::date, 'refusals changed nothing');
reset role;
select is(pg_temp.audits(), 3, 'and wrote no audit rows');

-- ===== who =====
set local role authenticated;
select pg_temp.login('juan', 'A');
select is(pg_temp.due('w1', pg_temp.d(3)) ->> 'status', 'ok', 'a cashier may note a promise (like recording a payment)');
select pg_temp.login('sara', 'A');
select is(pg_temp.due('w2', pg_temp.d(4), 'berto') ->> 'status', 'ok', 'a supervisor may too');
select pg_temp.login('pedro', 'A');
select is(pg_temp.due('w3', pg_temp.d(5)) ->> 'hint', 'not_allowed', 'warehouse staff may not (they do not see utang)');
select pg_temp.login('ownerB', 'B');
select is(pg_temp.due('w4', pg_temp.d(5)) ->> 'hint', 'unknown_customer', 'another tenant cannot touch our customer');
select pg_temp.login('ownerC', 'C');
select is(pg_temp.due('w5', pg_temp.d(5)) ->> 'hint', 'module_disabled', 'a tenant without POS has no utang');
select pg_temp.login('owner', 'A');
select is((pg_temp.due_on(), pg_temp.due_on('berto'))::text,
          (current_date + 3, current_date + 4)::text, 'only the allowed writes landed');

reset role;
select * from finish();
rollback;
