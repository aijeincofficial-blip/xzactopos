-- P8-02b supervisor credential (PIN -> single-use approval) and the audit trail for expenses
begin;
select plan(63);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('id:' || p)::uuid $$;
create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;
create function pg_temp.op(k text, kind text, payload jsonb) returns jsonb language sql immutable as $$
  select jsonb_build_object('op_id', pg_temp.id('op:' || k), 'kind', kind, 'payload', payload)
$$;
create function pg_temp.push1(k text, kind text, payload jsonb) returns jsonb language sql as $$
  select public.sync_push(jsonb_build_array(pg_temp.op(k, kind, payload))) -> 0
$$;
create function pg_temp.spend(k text, exp text, loc text, approval uuid default null, amount bigint default 1000) returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_expense', jsonb_strip_nulls(jsonb_build_object(
    'id', pg_temp.id('exp:' || exp), 'location_id', pg_temp.id(loc), 'amount', amount, 'category', 'other', 'approval_id', approval)))
$$;
create function pg_temp.void(k text, exp text, approval uuid default null, reason text default null) returns jsonb language sql as $$
  select pg_temp.push1(k, 'void_expense', jsonb_strip_nulls(jsonb_build_object(
    'expense_id', pg_temp.id('exp:' || exp), 'approval_id', approval, 'reason', reason)))
$$;

create temp table ap (k text primary key, id uuid, res jsonb);
grant all on ap to authenticated;
-- asks for an approval and keeps its id under key k
create function pg_temp.approve(k text, action text, ref text, pin text, loc text default null, approver text default null)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := public.approve_supervisor_action(action, pg_temp.id('exp:' || ref), pin,
         case when loc is null then null else pg_temp.id(loc) end,
         case when approver is null then null else pg_temp.u(approver) end);
  insert into pg_temp.ap values (k, (r ->> 'approval_id')::uuid, r);
  return r;
end;
$$;
create function pg_temp.ap(k text) returns uuid language sql as $$ select id from pg_temp.ap where ap.k = $1 $$;
-- audit rows (read as postgres)
create function pg_temp.audits(p_action text, p_exp text) returns int language sql as $$
  select count(*)::int from public.audit_log where action = p_action and entity_id = pg_temp.id('exp:' || p_exp)
$$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'sara', 'lito', 'nopin', 'juan', 'ownerB', 'saraB']) n;
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP', 'Asia/Manila'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP', 'UTC');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.t('A'), true, false), (pg_temp.t('B'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('sara'), pg_temp.t('A'), 'sara', 'admin', true),
  (pg_temp.u('lito'), pg_temp.t('A'), 'lito', 'admin', true),
  (pg_temp.u('nopin'), pg_temp.t('A'), 'nopin', 'admin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true),
  (pg_temp.u('saraB'), pg_temp.t('B'), 'sara', 'admin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'A1'),
  (pg_temp.id('S02'), pg_temp.t('A'), 'store', 'S02', 'A2'),
  (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'S01', 'B1');
-- maria: manager S01. sara: supervisor S01 + S02. lito: supervisor S02. nopin: supervisor S01, never set a PIN.
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sara'), pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('sara'), pg_temp.id('S02'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('lito'), pg_temp.id('S02'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('nopin'), pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('saraB'), pg_temp.id('SB'), pg_temp.t('B'), 'supervisor');

-- ===== PINs =====
select pg_temp.login('sara', 'A');
set local role authenticated;
select is(public.set_my_pin('4821') ->> 'ok', 'true', 'a supervisor sets her PIN');
select throws_ok($$ select pin_hash from public.profiles $$, '42501', null, 'the PIN hash is not readable by clients');
select throws_ok($$ select public.set_my_pin('12a4', '4821') $$, '22023', null, 'a PIN is 4 to 8 digits');
select throws_ok($$ select public.set_my_pin('9999') $$, '22023', null, 'changing a PIN needs the current one');
select is(public.set_my_pin('9999', '0000') ->> 'hint', 'pin_wrong', 'a wrong current PIN does not change it');
select is(public.set_my_pin('4821', '4821') ->> 'ok', 'true', 'the right current PIN does');
reset role;
select ok(public.pin_hash_check('4821', (select pin_hash from public.profiles where user_id = pg_temp.u('sara')))
          and not public.pin_hash_check('4822', (select pin_hash from public.profiles where user_id = pg_temp.u('sara')))
          and (select pin_hash like 'pbkdf2_sha256$20000$%' from public.profiles where user_id = pg_temp.u('sara')),
          'stored as a PBKDF2-SHA256 hash that checks the right PIN only');
select pg_temp.login('maria', 'A');  select public.set_my_pin('7734');
select pg_temp.login('lito', 'A');   select public.set_my_pin('5555');
select pg_temp.login('juan', 'A');   select public.set_my_pin('2468');
select pg_temp.login('saraB', 'B');  select public.set_my_pin('4821');

-- ===== record by a supervisor =====
select pg_temp.login('sara', 'A');
set local role authenticated;
select is(pg_temp.spend('r1', 'r1', 'S01') ->> 'hint', 'approval_required', 'a supervisor without an approval is refused');
select is(pg_temp.approve('bad', 'record_expense', 'r1', '1111', 'S01') ->> 'hint', 'pin_wrong', 'a wrong PIN gets no approval');
reset role;
select is((select count(*)::int from public.audit_log where action = 'pin.failed' and entity_id = pg_temp.u('sara')), 2,
          'wrong PINs are kept in the audit log (the PIN change try and this one)');
set local role authenticated;
select is(pg_temp.approve('a1', 'record_expense', 'r1', '4821', 'S01') ->> 'ok', 'true', 'her own PIN gets an approval');
select is(pg_temp.spend('r1', 'r1', 'S01', pg_temp.ap('a1')) ->> 'status', 'ok', 'with the approval the expense is recorded');
select is((select (created_by = pg_temp.u('sara'), approved_by = pg_temp.u('sara'))::text from public.expenses where id = pg_temp.id('exp:r1')),
          '(t,t)', 'the row says who recorded and who approved');
reset role;
select is(pg_temp.audits('expense.record', 'r1'), 1, 'one audit row for the record');
select is((select (user_id = pg_temp.u('sara'), meta ->> 'approved_by' = pg_temp.u('sara')::text, meta ->> 'op_id' = pg_temp.id('op:r1')::text,
                   meta ->> 'amount', meta ->> 'category', meta ->> 'paid_from', meta ->> 'location_id' = pg_temp.id('S01')::text,
                   location_id = pg_temp.id('S01'))::text
           from public.audit_log where action = 'expense.record' and entity_id = pg_temp.id('exp:r1')),
          '(t,t,t,1000,other,cash,t,t)', 'the audit row has the actor, approver, op id, amount, category, paid from and store');
set local role authenticated;
select is(pg_temp.spend('r1', 'r1', 'S01', pg_temp.ap('a1')) -> 'result' ->> 'replay', 'true', 'a resend is a replay');
reset role;
select is(pg_temp.audits('expense.record', 'r1'), 1, 'and is not logged twice');
set local role authenticated;
select is(pg_temp.spend('r1b', 'r1', 'S01', pg_temp.ap('a1')) ->> 'hint', 'approval_used', 'an approval works once');

select pg_temp.approve('a2', 'record_expense', 'r1', '4821', 'S01');
select is(pg_temp.spend('r2x', 'r1', 'S01', pg_temp.ap('a2')) ->> 'hint', 'id_conflict', 'an op refused after the approval check ...');
reset role;
select is((select used_at from public.supervisor_approvals where id = pg_temp.ap('a2')), null, '... does not use up the approval');
set local role authenticated;

select pg_temp.approve('a3', 'record_expense', 'r3', '4821', 'S01');
reset role;
update public.supervisor_approvals set expires_at = now() - interval '1 second' where id = pg_temp.ap('a3');
set local role authenticated;
select is(pg_temp.spend('r3', 'r3', 'S01', pg_temp.ap('a3')) ->> 'hint', 'approval_expired', 'an expired approval is refused');

select pg_temp.approve('a4', 'record_expense', 'r4', '4821', 'S02');
select is(pg_temp.spend('r4', 'r4', 'S01', pg_temp.ap('a4')) ->> 'hint', 'approval_invalid', 'an approval for another store is refused');
select pg_temp.approve('a5', 'record_expense', 'r5', '4821', 'S01');
select is(pg_temp.spend('r6', 'r6', 'S01', pg_temp.ap('a5')) ->> 'hint', 'approval_invalid', 'an approval for another expense is refused');
select pg_temp.approve('a7', 'void_expense', 'r7', '4821', 'S01');
select is(pg_temp.spend('r7', 'r7', 'S01', pg_temp.ap('a7')) ->> 'hint', 'approval_invalid', 'a void approval cannot record');
select pg_temp.login('lito', 'A');
select pg_temp.approve('a8', 'record_expense', 'r8', '5555', 'S02');
select pg_temp.login('saraB', 'B');
select pg_temp.approve('a9', 'record_expense', 'r9', '4821');
select pg_temp.login('sara', 'A');
select is(pg_temp.spend('r8', 'r8', 'S02', pg_temp.ap('a8')) ->> 'hint', 'approval_invalid', 'someone else''s approval is refused');
select is(pg_temp.spend('r9', 'r9', 'S01', pg_temp.ap('a9')) ->> 'hint', 'approval_invalid', 'another tenant''s approval is refused');
select is(pg_temp.spend('r9b', 'r9', 'S01', gen_random_uuid()) ->> 'hint', 'approval_invalid', 'a made-up approval is refused');
select throws_ok($$ select pg_temp.approve('x1', 'record_expense', 'r10', '5555', 'S01', 'lito') $$, '42501', 'this person cannot approve here',
                 'a supervisor of another store cannot approve here');
select throws_ok($$ select pg_temp.approve('x2', 'record_expense', 'r10', '2468', 'S01', 'juan') $$, '42501', 'this person cannot approve here',
                 'a cashier cannot approve');
select is(pg_temp.approve('a10', 'record_expense', 'r10', '7734', 'S01', 'maria') ->> 'ok', 'true', 'the manager approves on the supervisor''s phone');
select is(pg_temp.spend('r10', 'r10', 'S01', pg_temp.ap('a10')) ->> 'status', 'ok', 'and the supervisor records');
select is((select approved_by from public.expenses where id = pg_temp.id('exp:r10')), pg_temp.u('maria'), 'approved_by is the manager');

select pg_temp.approve('a11', 'record_expense', 'r11', '7734', 'S01', 'maria');
reset role;
update public.profiles set active = false where user_id = pg_temp.u('maria');
set local role authenticated;
select is(pg_temp.spend('r11', 'r11', 'S01', pg_temp.ap('a11')) ->> 'hint', 'approval_invalid', 'an approval from someone since deactivated is refused');
reset role;
update public.profiles set active = true where user_id = pg_temp.u('maria');
set local role authenticated;

-- ===== who needs none, who is refused =====
select pg_temp.login('maria', 'A');
select is(pg_temp.spend('m1', 'm1', 'S01') ->> 'status', 'ok', 'a store manager needs no approval');
reset role;
select is((select (approved_by is null)::text from public.expenses where id = pg_temp.id('exp:m1'))
          || (select (user_id = pg_temp.u('maria') and not meta ? 'approved_by')::text from public.audit_log
              where action = 'expense.record' and entity_id = pg_temp.id('exp:m1')),
          'truetrue', 'no approver on the row or in the audit row');
set local role authenticated;
select pg_temp.login('owner', 'A');
select is(pg_temp.spend('o1', 'o1', 'S02') ->> 'status', 'ok', 'the owner needs no approval');
select pg_temp.login('juan', 'A');
select throws_ok($$ select pg_temp.approve('x3', 'record_expense', 'j1', '2468', 'S01') $$, '42501', 'not allowed to ask for approvals',
                 'a cashier cannot ask for an approval');
select is(pg_temp.spend('j1', 'j1', 'S01', pg_temp.ap('a5')) ->> 'hint', 'not_allowed', 'nor record with one');
select pg_temp.login('lito', 'A');
select is(pg_temp.spend('l1', 'l1', 'S01') ->> 'hint', 'location_denied', 'a supervisor cannot record at a store that is not his');
select pg_temp.login('nopin', 'A');
select is(pg_temp.approve('n1', 'record_expense', 'n1', '1234', 'S01') ->> 'hint', 'pin_not_set', 'without a PIN there is no approval');

-- lockout: five wrong tries in 15 minutes
select pg_temp.login('lito', 'A');
select pg_temp.approve('lk' || n, 'record_expense', 'lk', '0000', 'S02') from generate_series(1, 5) n;
select is(pg_temp.approve('lk6', 'record_expense', 'lk', '5555', 'S02') ->> 'hint', 'pin_locked', 'after five wrong PINs even the right one is locked out');
select is(public.set_my_pin('1212', '5555') ->> 'hint', 'pin_locked', 'also for changing the PIN');

-- ===== void by a supervisor =====
select pg_temp.login('sara', 'A');
select is(pg_temp.void('v1', 'r1') ->> 'hint', 'approval_required', 'a void needs an approval too');
select pg_temp.approve('vr', 'record_expense', 'r1', '4821', 'S01');
select is(pg_temp.void('v1', 'r1', pg_temp.ap('vr')) ->> 'hint', 'approval_invalid', 'a record approval cannot void');
select is(pg_temp.approve('va', 'void_expense', 'r1', '4821') -> 'ok', 'true'::jsonb, 'a void approval (the store comes from the expense)');
select is(pg_temp.void('v1', 'r1', pg_temp.ap('va'), 'mali') -> 'result' ->> 'already', 'false', 'the supervisor voids with it');
select is((select (voided_at is not null, void_reason, void_approved_by = pg_temp.u('sara'), approved_by = pg_temp.u('sara'))::text
           from public.expenses where id = pg_temp.id('exp:r1')), '(t,mali,t,t)', 'the row keeps both approvers and the reason');
reset role;
select is((select (user_id = pg_temp.u('sara'), meta ->> 'reason', meta ->> 'approved_by' = pg_temp.u('sara')::text,
                   meta ->> 'op_id' = pg_temp.id('op:v1')::text, meta ->> 'amount')::text
           from public.audit_log where action = 'expense.void' and entity_id = pg_temp.id('exp:r1')),
          '(t,mali,t,t,1000)', 'one void audit row with actor, reason, approver, op id and amount');
set local role authenticated;
select is(pg_temp.void('v1', 'r1', pg_temp.ap('va'), 'mali') -> 'result' ->> 'replay', 'true', 'a resent void is a replay');
select pg_temp.approve('va2', 'void_expense', 'r1', '4821');
select is(pg_temp.void('v2', 'r1', pg_temp.ap('va2')) -> 'result' ->> 'already', 'true', 'voiding again changes nothing');
reset role;
select is(pg_temp.audits('expense.void', 'r1'), 1, 'neither the replay nor the second void is logged again');
set local role authenticated;
select pg_temp.login('maria', 'A');
select is(pg_temp.void('mv', 'r10') ->> 'status', 'ok', 'a manager voids without an approval');

-- ===== who reads the audit trail =====
select pg_temp.login('juan', 'A');
select is((select count(*)::int from public.audit_log), 0, 'a cashier reads no audit rows');
select throws_ok($$ insert into public.audit_log (tenant_id, action, entity) values (md5('t:A')::uuid, 'expense.record', 'expense') $$,
                 '42501', null, 'nor writes them');
select pg_temp.login('sara', 'A');
select is((select count(*)::int from public.audit_log), 0, 'a supervisor does not read the audit log (manager and owner only)');
select pg_temp.login('maria', 'A');
select ok((select count(*) > 0 and bool_and(location_id = pg_temp.id('S01')) from public.audit_log where entity = 'expense'),
          'the manager reads the expense audit rows of her store only');
select pg_temp.login('ownerB', 'B');
select is((select count(*)::int from public.audit_log where entity = 'expense' or tenant_id = pg_temp.t('A')), 0,
          'another tenant reads none of ours');

-- ===== clearing a forgotten PIN =====
select pg_temp.login('maria', 'A');
select throws_ok(format($$ select public.clear_user_pin(%L) $$, pg_temp.u('lito')), '42501', null, 'only the owner clears a PIN');
select pg_temp.login('owner', 'A');
select is(public.clear_user_pin(pg_temp.u('lito')) ->> 'ok', 'true', 'the owner clears it');
select pg_temp.login('lito', 'A');
select is(public.set_my_pin('8080') ->> 'ok', 'true', 'and he sets a new one without the old');

-- ===== no plaintext PIN anywhere =====
reset role;
select is((select count(*)::int from (
             select to_jsonb(a) j from public.audit_log a where a.tenant_id in (pg_temp.t('A'), pg_temp.t('B'))
             union all select to_jsonb(o) from public.processed_ops o where o.tenant_id in (pg_temp.t('A'), pg_temp.t('B'))
             union all select to_jsonb(s) from public.supervisor_approvals s where s.tenant_id in (pg_temp.t('A'), pg_temp.t('B'))
             union all select to_jsonb(e) from public.expenses e where e.tenant_id in (pg_temp.t('A'), pg_temp.t('B'))
           ) x, jsonb_each_text(x.j) kv
           where kv.value in ('4821', '7734', '5555', '2468', '0000', '1111', '9999', '8080', '1234')
              or kv.value ~ '"(4821|7734|5555|2468|0000|1111|9999|8080|1234)"' or kv.value like '%"pin"%' or kv.key like '%pin%'), 0,
          'no PIN is stored in the audit log, processed ops, approvals or expenses');
select is((select array_agg(k order by k) from jsonb_object_keys((select res from ap where k = 'a1')) k),
          array['approval_id', 'approved_by', 'expires_at', 'ok'], 'the approval answer carries no PIN or hash');
select is((select count(*)::int from public.profiles where tenant_id in (pg_temp.t('A'), pg_temp.t('B'))
             and pin_hash is not null and pin_hash not like 'pbkdf2_sha256$%'), 0, 'every stored PIN is a hash');

select * from finish();
rollback;
