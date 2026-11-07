-- P8-06 load / e-wallet service ledger: record_service_txn / void_service_txn ops (money model, permissions, supervisor
-- approvals, idempotency, audit without the customer reference, bad input), wallet_float and daily_service_summary
-- triggers, expected cash for the day close, report_summary.services, sync_pull_service, append-only table,
-- and a seeded property test (300+ random ops, voids, replays, refusals) against an independent model.
begin;
select plan(109);

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
-- one service entry (txn id 'tx:<p_txn>') at store p_loc
create function pg_temp.svc(p_k text, p_txn text, p_kind text, p_wallet text, p_amount bigint, p_fee bigint default null,
                            p_price bigint default null, p_loc text default 'S01', p_approval uuid default null,
                            p_note text default null, p_ref text default null,
                            p_at text default '2026-11-05T02:00:00Z') returns jsonb language sql as $$
  select pg_temp.push1(p_k, 'record_service_txn', jsonb_strip_nulls(jsonb_build_object(
    'id', pg_temp.id('tx:' || p_txn), 'kind', p_kind, 'wallet', p_wallet, 'amount', p_amount, 'fee', p_fee,
    'price', p_price, 'location_id', pg_temp.id(p_loc), 'approval_id', p_approval, 'note', p_note, 'ref', p_ref,
    'txn_at', p_at)))
$$;
create function pg_temp.vd(p_k text, p_txn text, p_approval uuid default null, p_reason text default null)
returns jsonb language sql as $$
  select pg_temp.push1(p_k, 'void_service_txn', jsonb_strip_nulls(jsonb_build_object(
    'txn_id', pg_temp.id('tx:' || p_txn), 'reason', p_reason, 'approval_id', p_approval)))
$$;
create function pg_temp.raw(k text, payload jsonb) returns text language sql as $$
  select pg_temp.push1(k, 'record_service_txn', jsonb_build_object('location_id', pg_temp.id('S01')) || payload) ->> 'hint'
$$;
create function pg_temp.fl(p_loc text, p_wallet text) returns bigint language sql as $$
  select balance from public.wallet_float where location_id = pg_temp.id(p_loc) and wallet = p_wallet
$$;
create temp table ap (k text primary key, id uuid);
grant all on ap to authenticated;
create function pg_temp.approve(k text, action text, ref text, pin text, loc text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := public.approve_supervisor_action(action, pg_temp.id('tx:' || ref), pin, pg_temp.id(loc));
  insert into pg_temp.ap values (k, (r ->> 'approval_id')::uuid);
  return r;
end;
$$;
create function pg_temp.ap(k text) returns uuid language sql as $$ select id from pg_temp.ap where ap.k = $1 $$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid'
  from unnest(array['owner', 'maria', 'sara', 'juan', 'pedro', 'ownerB', 'ownerP']) n;
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP', 'Asia/Manila'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP', 'UTC'),
  (pg_temp.t('P'), 'P', 'tenant-p', 'PHP', 'Asia/Manila');
insert into public.tenant_modules (tenant_id, pos, warehouse) values
  (pg_temp.t('A'), true, true), (pg_temp.t('B'), true, false), (pg_temp.t('P'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B')), (pg_temp.t('P'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('sara'), pg_temp.t('A'), 'sara', 'admin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('pedro'), pg_temp.t('A'), 'pedro', 'warehouse', true),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true),
  (pg_temp.u('ownerP'), pg_temp.t('P'), 'owner', 'superadmin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'A1'),
  (pg_temp.id('S02'), pg_temp.t('A'), 'store', 'S02', 'A2'),
  (pg_temp.id('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'AW'),
  (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'S01', 'B1'),
  (pg_temp.id('SP'), pg_temp.t('P'), 'store', 'S01', 'P1');
-- maria: manager S01 only. sara: supervisor S01 + S02. juan: cashier S01. pedro: warehouse W01.
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sara'), pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('sara'), pg_temp.id('S02'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null);

-- ===== owner: every kind, the money model, rollups, idempotency, audit =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.svc('o1', 'o1', 'cash_in', 'gcash', 50000, 1500, p_ref => ' 0917 123 4567 ') ->> 'status', 'ok',
          'the owner records a GCash cash-in');
reset role;
select is((select (kind, wallet, amount, fee, price, ref, currency, created_by = pg_temp.u('owner'), approved_by is null,
                   voided_at is null)::text
           from public.service_txns where id = pg_temp.id('tx:o1')),
          '(cash_in,gcash,50000,1500,,"0917 123 4567",PHP,t,t,t)', 'the row keeps kind, wallet, principal, fee, trimmed ref');
select is(pg_temp.fl('S01', 'gcash'), -50000::bigint, 'a cash-in sends the principal out of the wallet float');
select is((select (txn_count, amount, fee, cash, float_change)::text from public.daily_service_summary
           where location_id = pg_temp.id('S01') and day = '2026-11-05' and kind = 'cash_in'),
          '(1,50000,1500,51500,-50000)', 'the day summary: the drawer gains principal + fee, the float loses the principal');
set local role authenticated;
select is(pg_temp.svc('o1', 'o1', 'cash_in', 'gcash', 50000, 1500) -> 'result' ->> 'replay', 'true', 'a resend is a replay');
reset role;
select is((select count(*)::int from public.service_txns where client_op_id = pg_temp.id('op:o1')), 1, 'the replay wrote no second row');
select is((select (pg_temp.fl('S01', 'gcash'), (select txn_count from public.daily_service_summary
                   where location_id = pg_temp.id('S01') and kind = 'cash_in'))::text), '(-50000,1)',
          'and moved neither the float nor the day summary again');
select is((select count(*)::int from public.audit_log where action = 'service.record' and entity_id = pg_temp.id('tx:o1')), 1,
          'one audit row, not one per resend');
select is((select (user_id = pg_temp.u('owner'), entity, location_id = pg_temp.id('S01'),
                   (select array_agg(k order by k) from jsonb_object_keys(meta) k), meta ->> 'amount', meta ->> 'fee')::text
           from public.audit_log where action = 'service.record' and entity_id = pg_temp.id('tx:o1')),
          '(t,service_txn,t,"{amount,fee,kind,location_id,op_id,wallet}",50000,1500)',
          'the audit row has store, kind, wallet, amounts and op id only');
select is((select count(*)::int from public.audit_log where meta::text like '%0917 123%'), 0,
          'the customer reference never reaches the audit log');

set local role authenticated;
select is(pg_temp.svc('o2', 'o2', 'cash_out', 'maya', 20000, 500) ->> 'status', 'ok', 'a Maya cash-out');
select is(pg_temp.svc('o3', 'o3', 'load', null, 4800, p_price => 5000) -> 'result' ->> 'fee', '200',
          'a load: the margin (price - amount) is the fee; the wallet defaults to load');
select is(pg_temp.svc('o4', 'o4', 'float_topup', 'gcash', 100000) ->> 'status', 'ok', 'the owner tops up a float');
select is(pg_temp.svc('o5', 'o5', 'float_withdraw', 'maya', 5000) ->> 'status', 'ok', 'and takes float back to the drawer');
select is(pg_temp.svc('o6', 'o6', 'float_adjust', 'load', -200, p_note => 'count fix') ->> 'status', 'ok',
          'and corrects a float with a note (signed amount)');
reset role;
select is((select (wallet, price, fee)::text from public.service_txns where id = pg_temp.id('tx:o3')), '(load,5000,200)',
          'the load row stores price and fee');
select is((select array_agg(wallet || '=' || balance || ':' || negative order by wallet) from public.wallet_float
           where location_id = pg_temp.id('S01'))::text,
          '{gcash=50000:false,load=-5000:true,maya=15000:false}',
          'floats: gcash -50000 + 100000, maya +20000 - 5000, load -4800 - 200 (below zero: flagged)');
-- 51500 - 19500 + 5000 - 100000 + 5000 + 0
select is(public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S01'), '2026-11-05'), -58000::bigint,
          'server expected cash adds the service cash: in + fee, out - principal + fee, load price, top-up out, withdraw in');
select is((select sum(cash + float_change - fee)::bigint from public.daily_service_summary
           where location_id = pg_temp.id('S01') and kind <> 'float_adjust'), 0::bigint,
          'for every kind but an adjust: cash effect + float effect = fee');

set local role authenticated;
select is(pg_temp.vd('v1', 'o1', p_reason => '  maling numero ') -> 'result' ->> 'already', 'false', 'the owner voids the cash-in');
reset role;
select is((select (voided_at is not null, void_reason, void_approved_by is null)::text from public.service_txns
           where id = pg_temp.id('tx:o1')), '(t,"maling numero",t)', 'the void is a state on the row');
select is(pg_temp.fl('S01', 'gcash'), 100000::bigint, 'the void gives the principal back to the float');
select is((select (txn_count, amount, fee, cash, float_change)::text from public.daily_service_summary
           where location_id = pg_temp.id('S01') and kind = 'cash_in'), '(0,0,0,0,0)', 'and takes it out of the day summary');
select is(public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S01'), '2026-11-05'), -109500::bigint,
          'a voided entry is out of expected cash');
set local role authenticated;
select is(pg_temp.vd('v1b', 'o1') -> 'result' ->> 'already', 'true', 'a second void changes nothing');
select is(pg_temp.vd('v1', 'o1') -> 'result' ->> 'replay', 'true', 'a resent void is a replay');
reset role;
select is(pg_temp.fl('S01', 'gcash'), 100000::bigint, 'the float moved once');
select is((select count(*)::int from public.audit_log where action = 'service.void' and entity_id = pg_temp.id('tx:o1')), 1,
          'one void audit row');
select is((select (meta ->> 'kind', meta ->> 'amount', meta ->> 'reason', meta ? 'ref')::text from public.audit_log
           where action = 'service.void' and entity_id = pg_temp.id('tx:o1')), '(cash_in,50000,"maling numero",f)',
          'the void audit row has kind, amount and reason, no customer reference');

-- ===== manager =====
select pg_temp.login('maria', 'A');
set local role authenticated;
select is(pg_temp.svc('m1', 'm1', 'float_topup', 'maya', 3000) ->> 'status', 'ok', 'a store manager tops up without an approval');
select is(pg_temp.svc('m2', 'm2', 'float_adjust', 'maya', 100, p_note => 'sobra') ->> 'status', 'ok', 'and corrects a float');
select is(pg_temp.vd('m3', 'o2') ->> 'status', 'ok', 'and voids');
select is(pg_temp.svc('m4', 'm4', 'cash_in', 'gcash', 100, p_loc => 'S02') ->> 'hint', 'location_denied',
          'but not at a store that is not hers');

-- ===== supervisor =====
select pg_temp.login('sara', 'A');
select is(pg_temp.svc('s1', 's1', 'cash_in', 'gcash', 1000, 20) ->> 'status', 'ok', 'a supervisor records a cash-in (she may sell)');
select is(pg_temp.svc('s1b', 's1b', 'cash_in', 'maya', 700, 10, p_loc => 'S02') ->> 'status', 'ok', 'also at her other store');
select is(pg_temp.svc('s2', 's2', 'float_topup', 'gcash', 5000) ->> 'hint', 'approval_required', 'moving float needs an approval');
select is(public.set_my_pin('4821') ->> 'ok', 'true', 'she sets her PIN');
select is(pg_temp.approve('a1', 'record_service_txn', 's2', '4821', 'S01') ->> 'ok', 'true', 'and gets a record_service_txn approval');
select is(pg_temp.svc('s2', 's2', 'float_topup', 'gcash', 5000, p_approval => pg_temp.ap('a1')) ->> 'status', 'ok',
          'with it she tops up');
reset role;
select is((select (created_by = pg_temp.u('sara'), approved_by = pg_temp.u('sara'))::text from public.service_txns
           where id = pg_temp.id('tx:s2')), '(t,t)', 'the row says who recorded and who approved');
select is((select meta ->> 'approved_by' from public.audit_log where action = 'service.record' and entity_id = pg_temp.id('tx:s2')),
          pg_temp.u('sara')::text, 'the audit row names the approver');
set local role authenticated;
select is(pg_temp.svc('s2', 's2', 'float_topup', 'gcash', 5000, p_approval => pg_temp.ap('a1')) -> 'result' ->> 'replay', 'true',
          'her resend is a replay (the used approval is not checked again)');
select is(pg_temp.svc('s3', 's3', 'float_withdraw', 'gcash', 5000, p_approval => pg_temp.ap('a1')) ->> 'hint', 'approval_invalid',
          'an approval is for one entry only');
select pg_temp.approve('a2', 'record_expense', 's4', '4821', 'S01');
select is(pg_temp.svc('s4', 's4', 'float_withdraw', 'gcash', 5000, p_approval => pg_temp.ap('a2')) ->> 'hint', 'approval_invalid',
          'an expense approval cannot move float');
select pg_temp.approve('a3', 'record_service_txn', 's5', '4821', 'S01');
select is(pg_temp.svc('s5', 's5', 'float_adjust', 'gcash', 100, p_note => 'x', p_approval => pg_temp.ap('a3')) ->> 'hint',
          'not_allowed', 'a float correction is the owner''s or manager''s, even with an approval');
select is(pg_temp.vd('s6', 's1') ->> 'hint', 'approval_required', 'a void needs an approval');
select pg_temp.approve('a4', 'void_service_txn', 's1', '4821', 'S02');   -- the store comes from the entry, not the argument
select is(pg_temp.vd('s6', 's1', pg_temp.ap('a4')) ->> 'status', 'ok', 'with a void_service_txn approval she voids');
reset role;
select is((select (supervisor_approvals.location_id = pg_temp.id('S01'))::text from public.supervisor_approvals
           where id = pg_temp.ap('a4')), 'true', 'a void approval is bound to the entry''s store');
select is((select void_approved_by = pg_temp.u('sara') from public.service_txns where id = pg_temp.id('tx:s1')), true,
          'the void approver is stored');
set local role authenticated;
select pg_temp.approve('a5', 'void_service_txn', 'm2', '4821', 'S01');
select is(pg_temp.vd('s7', 'm2', pg_temp.ap('a5')) ->> 'hint', 'not_allowed', 'voiding a float correction is not a supervisor''s');
select pg_temp.approve('a6', 'record_service_txn', 's8', '4821', 'S01');
reset role;
update public.supervisor_approvals set expires_at = now() - interval '1 second' where id = pg_temp.ap('a6');
set local role authenticated;
select is(pg_temp.svc('s8', 's8', 'float_topup', 'gcash', 100, p_approval => pg_temp.ap('a6')) ->> 'hint', 'approval_expired',
          'an expired approval is refused');

-- ===== cashier, warehouse =====
select pg_temp.login('juan', 'A');
select is(pg_temp.svc('j1', 'j1', 'cash_in', 'gcash', 2000, 40) ->> 'status', 'ok', 'a cashier records a cash-in');
select is(pg_temp.svc('j2', 'j2', 'load', 'load', 1000, p_price => 1000) ->> 'status', 'ok', 'and sells load at face value (fee 0)');
select is(pg_temp.svc('j3', 'j3', 'float_topup', 'gcash', 1000) ->> 'hint', 'not_allowed', 'but cannot move float');
select is(pg_temp.svc('j4', 'j4', 'float_adjust', 'gcash', 1000, p_note => 'x') ->> 'hint', 'not_allowed', 'nor correct it');
select is(pg_temp.vd('j5', 'j1') ->> 'hint', 'not_allowed', 'nor void');
select throws_ok($$ select public.approve_supervisor_action('void_service_txn', md5('id:tx:j1')::uuid, '1234', md5('id:S01')::uuid) $$,
                 '42501', null, 'nor ask for an approval');
select is(pg_temp.svc('j6', 'j6', 'cash_in', 'gcash', 100, p_loc => 'S02') ->> 'hint', 'location_denied', 'nor work at another store');
select pg_temp.login('pedro', 'A');
select is(pg_temp.svc('p1', 'p1', 'cash_in', 'gcash', 100) ->> 'hint', 'not_allowed', 'warehouse staff cannot record services');

-- ===== bad input =====
select pg_temp.login('owner', 'A');
select is(pg_temp.raw('b1', jsonb_build_object('kind', 'cash_in', 'wallet', 'gcash', 'amount', 1)), 'id_required', 'the id is required');
select is(pg_temp.svc('b2', 'b2', 'remit', 'gcash', 100) ->> 'hint', 'invalid_value', 'an unknown kind is refused');
select is(pg_temp.svc('b3', 'b3', 'cash_in', 'paypal', 100) ->> 'hint', 'invalid_value', 'an unknown wallet is refused');
select is(pg_temp.svc('b4', 'b4', 'cash_in', 'load', 100) ->> 'hint', 'invalid_value', 'a cash-in never uses the load wallet');
select is(pg_temp.svc('b5', 'b5', 'cash_out', null, 100) ->> 'hint', 'invalid_value', 'a cash-out needs a wallet');
select is(pg_temp.svc('b6', 'b6', 'cash_in', 'gcash', 0) ->> 'hint', 'amount_invalid', 'the amount is above zero');
select is(pg_temp.svc('b7', 'b7', 'cash_out', 'gcash', -100) ->> 'hint', 'amount_invalid', 'only a correction is signed');
select is(pg_temp.raw('b8', jsonb_build_object('id', pg_temp.id('tx:b8'), 'kind', 'cash_in', 'wallet', 'gcash', 'amount', 100.5)),
          'amount_invalid', 'amounts are whole centavos');
select is(pg_temp.svc('b9', 'b9', 'float_adjust', 'gcash', 0, p_note => 'x') ->> 'hint', 'amount_invalid', 'a correction is not zero');
select is(pg_temp.svc('b10', 'b10', 'cash_in', 'gcash', 100, -5) ->> 'hint', 'amount_invalid', 'the fee is not negative');
select is(pg_temp.svc('b11', 'b11', 'float_topup', 'gcash', 100, 5) ->> 'hint', 'amount_invalid', 'moving float has no fee');
select is(pg_temp.svc('b12', 'b12', 'load', 'load', 100) ->> 'hint', 'amount_invalid', 'a load needs its price');
select is(pg_temp.svc('b13', 'b13', 'load', 'load', 100, p_price => 99) ->> 'hint', 'amount_invalid', 'the price covers the amount');
select is(pg_temp.svc('b14', 'b14', 'load', 'load', 100, 5, p_price => 110) ->> 'hint', 'amount_invalid',
          'a fee sent with a load must equal price - amount');
select is(pg_temp.svc('b15', 'b15', 'load', 'load', 100, 10, p_price => 110) ->> 'status', 'ok', 'and is accepted when it does');
select is(pg_temp.svc('b16', 'b16', 'cash_in', 'gcash', 100, p_price => 110) ->> 'hint', 'invalid_value', 'only a load has a price');
select is(pg_temp.svc('b17', 'b17', 'float_adjust', 'gcash', 100) ->> 'hint', 'note_required', 'a correction needs a note');
select is(pg_temp.raw('b18', jsonb_build_object('id', pg_temp.id('tx:b18'), 'kind', 'cash_in', 'wallet', 'gcash', 'amount', 1,
                                                'currency', 'USD')), 'invalid_value', 'only the base currency');
select is(pg_temp.svc('b19', 'b19', 'cash_in', 'gcash', 100, p_ref => repeat('9', 250)) ->> 'status', 'ok', 'a long reference is accepted');
select is((select length(ref) from public.service_txns where id = pg_temp.id('tx:b19')), 200, 'and cut to 200 characters');
select is(pg_temp.svc('b20', 'o2', 'cash_in', 'gcash', 100) ->> 'hint', 'id_conflict', 'a used entry id is refused');
select is(pg_temp.vd('b21', 'nope') ->> 'hint', 'txn_not_found', 'a void of an unknown entry is refused');
reset role;
insert into public.processed_ops (tenant_id, client_op_id, kind, user_id)
  values (pg_temp.t('A'), pg_temp.id('op:bx'), 'record_expense', pg_temp.u('owner'));
set local role authenticated;
select is(pg_temp.svc('bx', 'bx', 'cash_in', 'gcash', 1) ->> 'hint', 'op_id_reused', 'an op id used for another kind is refused');
reset role;
select is((select count(*)::int from public.service_txns where id in (select pg_temp.id('tx:' || x) from unnest(array['b2', 'b3',
             'b4', 'b5', 'b6', 'b7', 'b8', 'b9', 'b10', 'b11', 'b12', 'b13', 'b14', 'b16', 'b17', 'b18', 'bx', 'j3', 'j4', 'p1',
             's3', 's4', 's5', 's8', 'm4', 'j6']) x))
          + (select count(*)::int from public.audit_log where action like 'service.%' and entity_id in
             (select pg_temp.id('tx:' || x) from unnest(array['b2', 'b6', 'b13', 'b17', 'j3', 'j4', 'p1', 's3', 's5', 's8']) x))
          + (select count(*)::int from public.audit_log where action = 'service.void'
             and entity_id in (pg_temp.id('tx:j1'), pg_temp.id('tx:m2'))), 0,
          'refused entries and voids leave no row and no audit entry');
update public.tenant_modules set pos = false where tenant_id = pg_temp.t('A');
set local role authenticated;
select is(pg_temp.svc('md', 'md', 'cash_in', 'gcash', 1) ->> 'hint', 'module_disabled', 'no service entry without the POS module');
reset role;
update public.tenant_modules set pos = true where tenant_id = pg_temp.t('A');

-- ===== append-only, no client writes =====
select throws_ok(format($$ update public.service_txns set amount = 1 where id = %L $$, pg_temp.id('tx:o2')),
                 '55000', null, 'an entry is never edited');
select throws_ok(format($$ update public.service_txns set voided_at = null, void_reason = null where id = %L $$, pg_temp.id('tx:o1')),
                 '55000', null, 'nor un-voided');
select throws_ok(format($$ delete from public.service_txns where id = %L $$, pg_temp.id('tx:o2')), '55000', null, 'nor deleted');
set local role authenticated;
select throws_ok(format($$ insert into public.service_txns (id, tenant_id, location_id, client_op_id, kind, wallet, amount,
                            currency, txn_at) values (gen_random_uuid(), %L, %L, gen_random_uuid(), 'cash_in', 'gcash', 1, 'PHP', now()) $$,
                        pg_temp.t('A'), pg_temp.id('S01')), '42501', null, 'clients cannot write entries directly');
select throws_ok($$ update public.wallet_float set balance = 999999 $$, '42501', null, 'nor floats');
select throws_ok($$ insert into public.daily_service_summary (tenant_id, location_id, day, kind) values
                    (md5('t:A')::uuid, md5('id:S01')::uuid, '2026-11-05', 'cash_in') $$, '42501', null, 'nor the day summary');

-- ===== report_summary =====
select is((select (select array_agg(k order by k) from jsonb_object_keys(r) k)::text
           from (select public.report_summary('2026-11-05', '2026-11-05') r) x),
          '{days,expenses,from,server_time,services,to,top_items,totals,utang}', 'report_summary keeps every key and adds services');
select is((select (r -> 'services' ->> 'count', r -> 'services' ->> 'fee_total',
                   (select array_agg(e ->> 'kind' order by o) from jsonb_array_elements(r -> 'services' -> 'by_kind') with ordinality a(e, o)),
                   r -> 'totals' ->> 'net')::text
           from (select public.report_summary('2026-11-05', '2026-11-05') r) x),
          '(6,260,"{cash_in,load,float_topup,float_withdraw,float_adjust}",0)',
          'services: customer entries and fee income (voided out, not in sales totals), kinds in a fixed order');
select is((select r -> 'services' -> 'float' from (select public.report_summary('2026-11-05', '2026-11-05') r) x),
          (select jsonb_agg(jsonb_build_object('wallet', w, 'balance', b) order by o) from (
             select wallet as w, sum(balance)::bigint as b,
                    array_position(array['gcash', 'maya', 'load', 'other'], wallet) as o
             from public.wallet_float where tenant_id = pg_temp.t('A') group by wallet) z),
          'services.float is the balance per wallet over the owner''s stores');
select pg_temp.login('juan', 'A');
select is((select r -> 'services' ->> 'fee_total' from (select public.report_summary('2026-11-05', '2026-11-05') r) x), '0',
          'a cashier reads no service rollup');

-- ===== pull =====
select pg_temp.login('owner', 'A');
select is((select (jsonb_array_length(r -> 'rows'), jsonb_array_length(r -> 'floats') > 0)::text
           from (select public.sync_pull_service() r) x), '(0,t)',
          'entries newer than 5 seconds wait for the next pull; the float balances come at once');
reset role;
set local session_replication_role = replica;
update public.service_txns set updated_at = now() - interval '1 minute';
set local session_replication_role = origin;
set local role authenticated;
select is((select (jsonb_array_length(r -> 'rows'), r ->> 'has_more',
                   (select array_agg(k order by k) from jsonb_object_keys(r -> 'rows' -> 0) k),
                   (select array_agg(k order by k) from jsonb_object_keys(r -> 'floats' -> 0) k))::text
           from (select public.sync_pull_service() r) x),
          '(15,false,"{amount,approved_by,created_by,currency,fee,id,kind,location_id,note,price,ref,txn_at,updated_at,void_approved_by,void_reason,voided_at,wallet}","{balance,location_id,negative,txn_count,updated_at,wallet}")',
          'the owner pulls every entry of the tenant with the documented fields, and the floats');
select is((select (jsonb_array_length(p1 -> 'rows'), p1 ->> 'has_more',
                   jsonb_array_length(public.sync_pull_service(p1 -> 'cursor', 200) -> 'rows'))::text
           from (select public.sync_pull_service(null, 10) p1) x),
          '(10,true,5)', 'pages follow the cursor');
select pg_temp.login('juan', 'A');
select is((select (jsonb_array_length(r -> 'rows'),
                   (select count(*) from jsonb_array_elements(r -> 'rows') e where e ->> 'location_id' <> pg_temp.id('S01')::text),
                   (select count(*) from jsonb_array_elements(r -> 'floats') e where e ->> 'location_id' <> pg_temp.id('S01')::text))::text
           from (select public.sync_pull_service() r) x), '(14,0,0)', 'a cashier pulls the entries and floats of her store only');
select pg_temp.login('pedro', 'A');
select is((select (jsonb_array_length(r -> 'rows'), jsonb_array_length(r -> 'floats'))::text from (select public.sync_pull_service() r) x),
          '(0,0)', 'warehouse staff pull nothing');
select pg_temp.login('ownerB', 'B');
select is((select (jsonb_array_length(r -> 'rows'), jsonb_array_length(r -> 'floats'))::text from (select public.sync_pull_service() r) x),
          '(0,0)', 'another tenant pulls none of ours');
reset role;

-- ===== property: seeded random mix against an independent model =====
create temp table model (id uuid primary key, kind text, wallet text, amount bigint, fee bigint, price bigint, day date,
                         voided boolean not null default false);
create temp table sent (n int primary key, op_id uuid, kind text, payload jsonb);
create temp table pstat (k text primary key, v int);
grant all on model, sent, pstat to authenticated;

create function pg_temp.prop(p_ops int) returns void language plpgsql as $$
declare
  v_kinds   text[] := array['cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust'];
  v_all     text[] := array['gcash', 'maya', 'load', 'other'];
  v_cust    text[] := array['gcash', 'maya', 'other'];
  i int; r float8; v_n int := 0;
  v_kind text; v_wallet text; v_amt bigint; v_fee bigint; v_price bigint; v_day date; v_secs float8; v_at timestamptz;
  v_id uuid; v_op uuid; v_payload jsonb; v_res jsonb; m record; s record;
  v_bad int := 0; v_new int := 0; v_voids int := 0; v_already int := 0; v_replays int := 0; v_refused int := 0;
begin
  perform setseed(0.20261108);
  for i in 1..p_ops loop
    r := random();
    v_n := v_n + 1;
    v_op := md5('prop-op:' || v_n)::uuid;
    if r < 0.58 then
      -- a new entry of a random kind
      v_kind := v_kinds[1 + floor(random() * 6)::int];
      v_wallet := case
        when v_kind = 'load' then case when random() < 0.7 then 'load' else 'gcash' end
        when v_kind in ('cash_in', 'cash_out') then v_cust[1 + floor(random() * 3)::int]
        else v_all[1 + floor(random() * 4)::int] end;
      v_amt := 1 + floor(random() * 500000)::bigint;
      if v_kind = 'float_adjust' and random() < 0.5 then
        v_amt := -v_amt;
      end if;
      v_fee := case when v_kind in ('cash_in', 'cash_out') then floor(random() * 2500)::bigint else 0 end;
      v_price := case when v_kind = 'load' then v_amt + floor(random() * 300)::bigint end;
      if v_kind = 'load' then
        v_fee := v_price - v_amt;
      end if;
      v_day := date '2026-11-03' + floor(random() * 3)::int;
      v_secs := case floor(random() * 10)::int when 0 then 0 when 1 then 86399.999 else floor(random() * 86400) end;
      v_at := (v_day::timestamp + make_interval(secs => v_secs)) at time zone 'Asia/Manila';
      v_id := md5('prop-tx:' || v_n)::uuid;
      v_payload := jsonb_strip_nulls(jsonb_build_object(
        'id', v_id, 'kind', v_kind, 'wallet', v_wallet, 'amount', v_amt,
        'fee', case when v_kind in ('cash_in', 'cash_out') or (v_kind = 'load' and random() < 0.5) then v_fee end,
        'price', v_price, 'note', case when v_kind = 'float_adjust' then 'bilang' end,
        'ref', '09' || floor(random() * 1000000000)::bigint::text, 'txn_at', v_at));
      v_res := public.sync_push(jsonb_build_array(jsonb_build_object(
        'op_id', v_op, 'kind', 'record_service_txn', 'payload', v_payload))) -> 0;
      if v_res ->> 'status' = 'ok' and v_res -> 'result' ->> 'replay' = 'false' then
        insert into pg_temp.model values (v_id, v_kind, v_wallet, v_amt, v_fee, v_price, v_day, false);
        insert into pg_temp.sent values (v_n, v_op, 'record_service_txn', v_payload);
        v_new := v_new + 1;
      else
        v_bad := v_bad + 1;
        raise notice 'unexpected answer to a new entry: %', v_res;
      end if;
    elsif r < 0.73 then
      -- void an open entry
      select * into m from pg_temp.model where not voided order by random() limit 1;
      continue when not found;
      v_payload := jsonb_build_object('txn_id', m.id, 'reason', 'mali');
      v_res := public.sync_push(jsonb_build_array(jsonb_build_object(
        'op_id', v_op, 'kind', 'void_service_txn', 'payload', v_payload))) -> 0;
      if v_res ->> 'status' = 'ok' and v_res -> 'result' ->> 'already' = 'false' then
        update pg_temp.model set voided = true where id = m.id;
        insert into pg_temp.sent values (v_n, v_op, 'void_service_txn', v_payload);
        v_voids := v_voids + 1;
      else
        v_bad := v_bad + 1;
        raise notice 'unexpected answer to a void: %', v_res;
      end if;
    elsif r < 0.80 then
      -- void an entry that is already voided (new op id): nothing changes
      select * into m from pg_temp.model where voided order by random() limit 1;
      continue when not found;
      v_res := public.sync_push(jsonb_build_array(jsonb_build_object(
        'op_id', v_op, 'kind', 'void_service_txn', 'payload', jsonb_build_object('txn_id', m.id)))) -> 0;
      if v_res ->> 'status' = 'ok' and v_res -> 'result' ->> 'already' = 'true' then
        v_already := v_already + 1;
      else
        v_bad := v_bad + 1;
        raise notice 'unexpected answer to a second void: %', v_res;
      end if;
    elsif r < 0.95 then
      -- resend an earlier op exactly (a lost reply): a replay, nothing changes
      select * into s from pg_temp.sent order by random() limit 1;
      continue when not found;
      v_res := public.sync_push(jsonb_build_array(jsonb_build_object(
        'op_id', s.op_id, 'kind', s.kind, 'payload', s.payload))) -> 0;
      if v_res ->> 'status' = 'ok' and v_res -> 'result' ->> 'replay' = 'true' then
        v_replays := v_replays + 1;
      else
        v_bad := v_bad + 1;
        raise notice 'unexpected answer to a replay: %', v_res;
      end if;
    else
      -- a refused entry: leaves nothing
      v_res := public.sync_push(jsonb_build_array(jsonb_build_object(
        'op_id', v_op, 'kind', 'record_service_txn', 'payload', jsonb_build_object(
          'id', md5('prop-tx:' || v_n)::uuid, 'kind', 'cash_in', 'wallet', 'gcash', 'amount', 0)))) -> 0;
      if v_res ->> 'status' = 'rejected' and v_res ->> 'hint' = 'amount_invalid' then
        v_refused := v_refused + 1;
      else
        v_bad := v_bad + 1;
        raise notice 'unexpected answer to a bad entry: %', v_res;
      end if;
    end if;
  end loop;
  insert into pg_temp.pstat values ('ops', v_n), ('bad', v_bad), ('new', v_new), ('voids', v_voids),
    ('already', v_already), ('replays', v_replays), ('refused', v_refused);
end;
$$;

-- the model's own copy of the money rule (written out again here, not taken from the migration)
create function pg_temp.cash_of(m pg_temp.model) returns bigint language sql immutable as $$
  select case m.kind when 'cash_in' then m.amount + m.fee when 'cash_out' then m.fee - m.amount when 'load' then m.price
                     when 'float_topup' then -m.amount when 'float_withdraw' then m.amount else 0 end
$$;
create function pg_temp.float_of(m pg_temp.model) returns bigint language sql immutable as $$
  select case when m.kind in ('cash_in', 'load', 'float_withdraw') then -m.amount else m.amount end
$$;

select pg_temp.login('ownerP', 'P');
set local role authenticated;
select pg_temp.prop(340);
reset role;

select diag('property mix: ' || (select string_agg(k || '=' || v, ', ' order by k) from pg_temp.pstat));
select is((select v from pg_temp.pstat where k = 'bad'), 0,
          'property: every op got the expected answer (applied, replay, already voided, or refused)');
select ok((select bool_and(case k when 'ops' then v >= 300 when 'new' then v >= 150 when 'voids' then v >= 30
                                  when 'replays' then v >= 30 when 'already' then v >= 5 when 'refused' then v >= 5 else true end)
           from pg_temp.pstat)
          and (select count(distinct kind) from pg_temp.model) = 6,
          'property: 300+ ops, every kind, with voids, second voids, replays and refusals');
select is((select array_agg(wallet || '=' || balance order by wallet) from public.wallet_float where tenant_id = pg_temp.t('P')),
          (select array_agg(wallet || '=' || b order by wallet) from (
             select m.wallet, coalesce(sum(pg_temp.float_of(m)) filter (where not m.voided), 0) as b
             from pg_temp.model m group by m.wallet) x),
          'property: float per wallet = sum of the signed float effects of the entries not voided');
select is((select array_agg(public.day_close_server_expected(pg_temp.t('P'), pg_temp.id('SP'), d::date) order by d)
           from generate_series(date '2026-11-02', date '2026-11-06', interval '1 day') d),
          (select array_agg(coalesce(c, 0) order by d) from generate_series(date '2026-11-02', date '2026-11-06', interval '1 day') d
           left join (select m.day, sum(pg_temp.cash_of(m))::bigint as c from pg_temp.model m where not m.voided group by m.day) x
             on x.day = d::date),
          'property: server expected cash per day = sum of the cash effects of the entries not voided (Manila days)');
select is((select count(*)::int
           from (select day, kind, txn_count, amount, fee from public.daily_service_summary where tenant_id = pg_temp.t('P')) s
           full join (select m.day, m.kind, count(*) filter (where not m.voided) as n,
                             coalesce(sum(m.amount) filter (where not m.voided), 0) as a,
                             coalesce(sum(m.fee) filter (where not m.voided), 0) as f
                      from pg_temp.model m group by m.day, m.kind) x using (day, kind)
           where coalesce(s.txn_count, 0) <> coalesce(x.n, 0) or coalesce(s.amount, 0) <> coalesce(x.a, 0)
              or coalesce(s.fee, 0) <> coalesce(x.f, 0)), 0,
          'property: the day summary per day and kind = count, amount and fee of the entries not voided');
select is((select (sum(cash + float_change - fee) filter (where kind <> 'float_adjust'),
                   sum(cash) filter (where kind = 'float_adjust'))::text
           from public.daily_service_summary where tenant_id = pg_temp.t('P')), '(0,0)',
          'property: cash + float moved by exactly the fee for every kind but an adjust, which moves no cash');
select is((select (count(*), count(*) filter (where voided_at is not null))::text from public.service_txns
           where tenant_id = pg_temp.t('P')),
          (select (v_new, v_voids)::text from (select (select v::bigint from pg_temp.pstat where k = 'new') v_new,
                                                      (select v::bigint from pg_temp.pstat where k = 'voids') v_voids) z),
          'property: one row per new entry, one void per effective void (replays and second voids wrote nothing)');
select is((select (count(*) filter (where action = 'service.record'), count(*) filter (where action = 'service.void'))::text
           from public.audit_log where tenant_id = pg_temp.t('P')),
          (select ((select v::bigint from pg_temp.pstat where k = 'new'), (select v::bigint from pg_temp.pstat where k = 'voids'))::text),
          'property: one audit row per new entry and per effective void');
select pg_temp.login('ownerP', 'P');
set local role authenticated;
select is((select ((r -> 'services' ->> 'fee_total')::bigint, r -> 'services' -> 'float')::text
           from (select public.report_summary('2026-11-03', '2026-11-05') r) x),
          (select ((select coalesce(sum(fee), 0)::bigint from pg_temp.model where not voided),
                   (select jsonb_agg(jsonb_build_object('wallet', wallet, 'balance', b)
                                     order by array_position(array['gcash', 'maya', 'load', 'other'], wallet))
                    from (select m.wallet, coalesce(sum(pg_temp.float_of(m)) filter (where not m.voided), 0)::bigint as b
                          from pg_temp.model m group by m.wallet) y))::text),
          'property: the report''s fee income and floats match the model');
reset role;

select * from finish();
rollback;
