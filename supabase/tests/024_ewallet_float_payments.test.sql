-- P8-15 e-wallet sale payments and e-wallet expenses name their wallet, so wallet_float moves: record with / without a
-- wallet, multi-payment sales, voids, replays, refusals (wallet on cash / utang, the load wallet, unknown values), cash and
-- sales rollups unchanged, append-only columns, permissions unchanged, pulls carry the wallet, sync_pull_service and
-- report_summary floats include sales and expenses, and a seeded property test (sales, expenses and service entries mixed
-- with voids, second voids, replays and refusals) against an independent model.
begin;
select plan(86);

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
-- one sale 'sale:<k>' of one untracked item priced at the sum of the payments, at store p_loc
create function pg_temp.sell(k text, pays jsonb, p_loc text default 'S01', p_at text default '2026-11-05T02:00:00Z')
returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:' || k), 'local_no', 'R-' || k, 'sold_at', p_at, 'location_id', pg_temp.id(p_loc),
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:asin'), 'qty', 1,
               'unit_price', (select sum((x ->> 'amount')::bigint) from jsonb_array_elements(pays) x))),
    'payments', pays))
$$;
create function pg_temp.pay(p_method text, p_amount bigint, p_wallet text default null) returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('method', p_method, 'amount', p_amount, 'wallet', p_wallet))
$$;
create function pg_temp.exp(k text, p_amount bigint, p_from text, p_wallet text default null, p_loc text default 'S01')
returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_expense', jsonb_strip_nulls(jsonb_build_object(
    'id', pg_temp.id('exp:' || k), 'amount', p_amount, 'category', 'other', 'paid_from', p_from, 'wallet', p_wallet,
    'location_id', pg_temp.id(p_loc), 'spent_at', '2026-11-05T03:00:00Z')))
$$;
create function pg_temp.fl(p_loc text, p_wallet text) returns bigint language sql as $$
  select coalesce((select balance from public.wallet_float where location_id = pg_temp.id(p_loc) and wallet = p_wallet), 0)
$$;
create function pg_temp.fc(p_loc text, p_wallet text) returns int language sql as $$
  select coalesce((select txn_count from public.wallet_float where location_id = pg_temp.id(p_loc) and wallet = p_wallet), 0)
$$;
create function pg_temp.floats(p_loc text) returns text language sql as $$
  select coalesce(array_agg(wallet || '=' || balance order by wallet) filter (where balance <> 0), '{}')::text
  from public.wallet_float where location_id = pg_temp.id(p_loc)
$$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'juan', 'pedro', 'ownerB', 'ownerP']) n;
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP', 'Asia/Manila'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP', 'UTC'),
  (pg_temp.t('P'), 'P', 'tenant-p', 'PHP', 'Asia/Manila');
insert into public.tenant_modules (tenant_id, pos, warehouse) values
  (pg_temp.t('A'), true, true), (pg_temp.t('B'), true, false), (pg_temp.t('P'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B')), (pg_temp.t('P'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'admin', true),
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
-- maria: manager S01. juan: cashier S01. pedro: warehouse W01.
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null);
insert into public.products (id, tenant_id, name, track_stock) values
  (pg_temp.id('p:asin'), pg_temp.t('A'), 'Asin', false), (pg_temp.id('p:pitem'), pg_temp.t('P'), 'Item', false);
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost) values
  (pg_temp.id('v:asin'), pg_temp.t('A'), pg_temp.id('p:asin'), 'ASIN', true, 100),
  (pg_temp.id('v:pitem'), pg_temp.t('P'), pg_temp.id('p:pitem'), 'ITEM', true, 100);

-- ===== schema =====
select has_column('public', 'payments', 'wallet', 'payments has a wallet');
select has_column('public', 'expenses', 'wallet', 'expenses has a wallet');

-- ===== sales =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.sell('s1', jsonb_build_array(pg_temp.pay('ewallet', 5000, 'gcash'))) ->> 'status', 'ok',
          'a sale paid by GCash into the store wallet is accepted');
reset role;
select is((select (method, amount, wallet, tendered)::text from public.payments where sale_id = pg_temp.id('sale:s1')),
          '(ewallet,5000,gcash,)', 'the payment row keeps the wallet');
select is((pg_temp.fl('S01', 'gcash'), pg_temp.fc('S01', 'gcash'))::text, '(5000,1)',
          'the GCash float grows by the payment and counts one entry');
set local role authenticated;
select is(pg_temp.sell('s1', jsonb_build_array(pg_temp.pay('ewallet', 5000, 'gcash'))) -> 'result' ->> 'replay', 'true',
          'a resend is a replay');
select is((pg_temp.fl('S01', 'gcash'), pg_temp.fc('S01', 'gcash'))::text, '(5000,1)', 'and does not move the float again');
select is(pg_temp.sell('s2', jsonb_build_array(pg_temp.pay('ewallet', 3000))) ->> 'status', 'ok',
          'an e-wallet payment with no wallet is accepted as before');
select is(pg_temp.floats('S01'), '{gcash=5000}', 'and moves no float');
select is(pg_temp.sell('s3', jsonb_build_array(pg_temp.pay('cash', 2000), pg_temp.pay('ewallet', 1500, 'maya'),
                                              pg_temp.pay('ewallet', 500, 'gcash'))) ->> 'status', 'ok',
          'a sale split over cash, Maya and GCash');
select is(pg_temp.floats('S01'), '{gcash=5500,maya=1500}', 'only the e-wallet parts move their floats');
select is(pg_temp.sell('s4', jsonb_build_array(pg_temp.pay('ewallet', 700, 'other'))) ->> 'status', 'ok', 'the other wallet');
select is(pg_temp.sell('s5', jsonb_build_array(jsonb_build_object('method', 'ewallet', 'amount', 100, 'wallet', ''),
                                              jsonb_build_object('method', 'ewallet', 'amount', 200, 'wallet', null))) ->> 'status',
          'ok', 'an empty or null wallet means none');
reset role;
select is((select array_agg(coalesce(wallet, '-') order by amount) from public.payments where sale_id = pg_temp.id('sale:s5'))::text,
          '{-,-}', 'stored as no wallet');
select is(pg_temp.floats('S01'), '{gcash=5500,maya=1500,other=700}', 'and moves nothing');
select is((select (meta - 'no')::text from public.audit_log where action = 'sale.create' and entity_id = pg_temp.id('sale:s3')),
          '{"total": 4000, "utang": 0}', 'the sale audit meta is unchanged (no wallets, no payment details)');

-- refusals: nothing written, no float moved
set local role authenticated;
select is(pg_temp.sell('b1', jsonb_build_array(pg_temp.pay('cash', 100, 'gcash'))) ->> 'hint', 'invalid_value',
          'a wallet on a cash payment is refused');
select is(pg_temp.sell('b2', jsonb_build_array(pg_temp.pay('ewallet', 100, 'load'))) ->> 'hint', 'invalid_value',
          'the load wallet is not a payment wallet');
select is(pg_temp.sell('b3', jsonb_build_array(pg_temp.pay('ewallet', 100, 'paypal'))) ->> 'hint', 'invalid_value',
          'an unknown wallet is refused');
select is(pg_temp.sell('b4', jsonb_build_array(pg_temp.pay('utang', 100, 'maya'))) ->> 'hint', 'invalid_value',
          'a wallet on an utang payment is refused');
select is(pg_temp.sell('b5', jsonb_build_array(pg_temp.pay('ewallet', 100, 'gcash'), pg_temp.pay('cash', 50, 'maya'))) ->> 'hint',
          'invalid_value', 'one bad payment refuses the whole sale');
reset role;
select is((select count(*)::int from public.sales where local_no in ('R-b1', 'R-b2', 'R-b3', 'R-b4', 'R-b5')), 0,
          'refused sales leave no row');
select is(pg_temp.floats('S01'), '{gcash=5500,maya=1500,other=700}', 'and no float movement');

-- cash and the sales rollups are unchanged by the wallet
select is(public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S01'), '2026-11-05'), 2000::bigint,
          'expected cash counts the cash payment only');
-- the sales rollups are deferred triggers: run them now, then defer again (immediate mode would roll later sales up before
-- their payments exist)
set constraints all immediate;
select is((select (cash, ewallet)::text from public.daily_sales_summary where location_id = pg_temp.id('S01') and day = '2026-11-05'),
          '(2000,11000)', 'the day summary still splits by method (every e-wallet payment, named or not)');
set constraints all deferred;

-- voids
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.push1('v3', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:s3'))) -> 'result' ->> 'already',
          'false', 'the owner cancels the split sale');
select is(pg_temp.floats('S01'), '{gcash=5000,other=700}', 'its Maya and GCash parts leave the floats exactly');
select is((pg_temp.fc('S01', 'gcash'), pg_temp.fc('S01', 'maya'))::text, '(1,0)', 'and the entry counts');
select is(pg_temp.push1('v3b', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:s3'))) -> 'result' ->> 'already',
          'true', 'a second cancel changes nothing');
select is(pg_temp.push1('v3', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:s3'))) -> 'result' ->> 'replay',
          'true', 'a resent cancel is a replay');
select is(pg_temp.floats('S01'), '{gcash=5000,other=700}', 'neither moves the float again');
select is(pg_temp.push1('v2', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:s2'))) ->> 'status', 'ok',
          'cancelling a sale with no wallet named');
select is(pg_temp.floats('S01'), '{gcash=5000,other=700}', 'moves no float');
reset role;
set constraints all immediate;
select is((select (cash, ewallet)::text from public.daily_sales_summary where location_id = pg_temp.id('S01') and day = '2026-11-05'),
          '(0,6000)', 'cancels leave the day summary by method as before');
set constraints all deferred;

-- ===== expenses =====
set local role authenticated;
select is(pg_temp.exp('e1', 1200, 'ewallet', 'gcash') ->> 'status', 'ok', 'an expense paid from the GCash wallet');
select is(pg_temp.fl('S01', 'gcash'), 3800::bigint, 'takes the money out of that float');
reset role;
select is((select (paid_from, wallet)::text from public.expenses where id = pg_temp.id('exp:e1')), '(ewallet,gcash)',
          'the expense keeps the wallet');
select is((select (select array_agg(k order by k) from jsonb_object_keys(meta) k)::text || ' ' || (meta ->> 'wallet')
           from public.audit_log where action = 'expense.record' and entity_id = pg_temp.id('exp:e1')),
          '{amount,category,location_id,op_id,paid_from,wallet} gcash', 'the audit row names the wallet (a small key)');
set local role authenticated;
select is(pg_temp.exp('e1', 1200, 'ewallet', 'gcash') -> 'result' ->> 'replay', 'true', 'a resent expense is a replay');
select is(pg_temp.fl('S01', 'gcash'), 3800::bigint, 'and is not taken twice');
select is(pg_temp.exp('e2', 400, 'ewallet') ->> 'status', 'ok', 'an e-wallet expense with no wallet is accepted as before');
reset role;
select is((select (select array_agg(k order by k) from jsonb_object_keys(meta) k)::text
           from public.audit_log where action = 'expense.record' and entity_id = pg_temp.id('exp:e2')),
          '{amount,category,location_id,op_id,paid_from}', 'its audit row is as before');
select is(pg_temp.floats('S01'), '{gcash=3800,other=700}', 'and moves no float');
set local role authenticated;
select is(pg_temp.exp('e3', 400, 'cash', 'gcash') ->> 'hint', 'invalid_value', 'a wallet on a cash expense is refused');
select is(pg_temp.push1('e4', 'record_expense', jsonb_build_object('id', pg_temp.id('exp:e4'), 'amount', 400,
            'category', 'other', 'wallet', 'maya', 'location_id', pg_temp.id('S01'))) ->> 'hint', 'invalid_value',
          'a wallet with paid_from left out (cash) is refused');
select is(pg_temp.exp('e5', 400, 'ewallet', 'load') ->> 'hint', 'invalid_value', 'the load wallet is not an expense wallet');
select is(pg_temp.exp('e6', 400, 'ewallet', 'GCash ') ->> 'hint', 'invalid_value', 'wallet values are exact');
reset role;
select is((select count(*)::int from public.expenses where id in (pg_temp.id('exp:e3'), pg_temp.id('exp:e4'),
                                                                 pg_temp.id('exp:e5'), pg_temp.id('exp:e6'))), 0,
          'refused expenses leave no row');
select is(public.day_close_server_expected(pg_temp.t('A'), pg_temp.id('S01'), '2026-11-05'), 0::bigint,
          'e-wallet expenses never touch expected cash');
set local role authenticated;
select is(pg_temp.exp('e7', 900, 'ewallet', 'maya') ->> 'status', 'ok', 'a Maya expense with no Maya float yet');
reset role;
select is((select (balance, negative)::text from public.wallet_float where location_id = pg_temp.id('S01') and wallet = 'maya'),
          '(-900,t)', 'the float goes below zero and is flagged');
set local role authenticated;
select is(pg_temp.push1('ve1', 'void_expense', jsonb_build_object('expense_id', pg_temp.id('exp:e1'))) -> 'result' ->> 'already',
          'false', 'voiding the GCash expense');
select is(pg_temp.fl('S01', 'gcash'), 5000::bigint, 'puts the money back in the float');
select is(pg_temp.push1('ve1b', 'void_expense', jsonb_build_object('expense_id', pg_temp.id('exp:e1'))) -> 'result' ->> 'already',
          'true', 'a second void changes nothing');
select is(pg_temp.push1('ve2', 'void_expense', jsonb_build_object('expense_id', pg_temp.id('exp:e2'))) ->> 'status', 'ok',
          'voiding the expense with no wallet');
select is(pg_temp.floats('S01'), '{gcash=5000,maya=-900,other=700}', 'moves nothing more');
reset role;

-- append-only: the wallet is set once, by the op
select throws_ok($$ update public.expenses set wallet = 'gcash' where id = md5('id:exp:e7')::uuid $$, '55000', null,
                 'an expense wallet can never be changed');
select throws_ok($$ update public.payments set wallet = 'maya' where sale_id = md5('id:sale:s1')::uuid $$, '55000', null,
                 'nor a payment wallet');
select throws_ok($$ insert into public.payments (tenant_id, sale_id, location_id, method, amount, wallet)
                    values (md5('t:A')::uuid, md5('id:sale:s1')::uuid, md5('id:S01')::uuid, 'cash', 1, 'gcash') $$,
                 '23514', null, 'the table refuses a wallet on a non-e-wallet payment');
select throws_ok($$ insert into public.expenses (id, tenant_id, location_id, client_op_id, amount, currency, category,
                                                 paid_from, wallet, spent_at)
                    values (gen_random_uuid(), md5('t:A')::uuid, md5('id:S01')::uuid, gen_random_uuid(), 1, 'PHP', 'other',
                            'cash', 'gcash', now()) $$,
                 '23514', null, 'and on a cash expense');

-- ===== permissions unchanged; stores kept apart =====
select pg_temp.login('juan', 'A');
set local role authenticated;
select is(pg_temp.sell('j1', jsonb_build_array(pg_temp.pay('ewallet', 900, 'gcash'))) ->> 'status', 'ok',
          'a cashier rings up a GCash sale');
select is(pg_temp.fl('S01', 'gcash'), 5900::bigint, 'it moves the store''s float');
select is(pg_temp.exp('j2', 100, 'ewallet', 'gcash') ->> 'hint', 'not_allowed', 'a cashier still cannot record expenses');
select is(pg_temp.push1('j3', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:j1'))) ->> 'hint', 'not_allowed',
          'nor cancel sales');
select is(pg_temp.fl('S01', 'gcash'), 5900::bigint, 'refused ops move nothing');
select pg_temp.login('pedro', 'A');
select is(pg_temp.sell('w1', jsonb_build_array(pg_temp.pay('ewallet', 100, 'gcash')), 'W01') ->> 'hint', 'not_allowed',
          'warehouse staff still cannot sell');
select pg_temp.login('maria', 'A');
select is(pg_temp.exp('m1', 300, 'ewallet', 'other') ->> 'status', 'ok', 'the store manager records an e-wallet expense');
select pg_temp.login('owner', 'A');
select is(pg_temp.sell('o2', jsonb_build_array(pg_temp.pay('ewallet', 2500, 'gcash')), 'S02') ->> 'status', 'ok',
          'the owner sells at the second store');
select is((pg_temp.floats('S01'), pg_temp.floats('S02'))::text, '("{gcash=5900,maya=-900,other=400}",{gcash=2500})',
          'each store has its own floats');
reset role;

-- ===== pulls and reports =====
set local session_replication_role = replica;
update public.sales set updated_at = now() - interval '1 minute';
update public.expenses set updated_at = now() - interval '1 minute';
set local session_replication_role = origin;
select pg_temp.login('owner', 'A');
set local role authenticated;
select is((select (select array_agg(k order by k) from jsonb_object_keys(x -> 'payments' -> 0) k)::text || ' ' ||
                  (x -> 'payments' -> 0 ->> 'wallet')
           from jsonb_array_elements(public.sync_pull_sales(null, 200) -> 'rows') x where x ->> 'local_no' = 'R-s1'),
          '{amount,method,reference,tendered,wallet} gcash', 'pulled sale payments carry the wallet');
select is((select x -> 'payments' -> 0 -> 'wallet'
           from jsonb_array_elements(public.sync_pull_sales(null, 200) -> 'rows') x where x ->> 'local_no' = 'R-s2'),
          'null'::jsonb, 'a payment with no wallet pulls null');
select is((select (select array_agg(k order by k) from jsonb_object_keys(x) k)::text || ' ' || (x ->> 'wallet')
           from jsonb_array_elements(public.sync_pull_expenses(null, 200) -> 'rows') x where x ->> 'id' = pg_temp.id('exp:e7')::text),
          '{amount,approved_by,category,created_by,currency,id,location_id,note,paid_from,spent_at,updated_at,void_approved_by,void_reason,voided_at,wallet} maya',
          'pulled expenses carry the wallet');
select is((select jsonb_agg(f ->> 'wallet' || '=' || (f ->> 'balance') order by f ->> 'wallet')
           from jsonb_array_elements(public.sync_pull_service() -> 'floats') f where f ->> 'location_id' = pg_temp.id('S01')::text),
          '["gcash=5900", "maya=-900", "other=400"]'::jsonb,
          'sync_pull_service floats include what sales and expenses moved');
select is((select r -> 'services' -> 'float' from (select public.report_summary('2026-11-05', '2026-11-05') r) x),
          '[{"wallet": "gcash", "balance": 8400}, {"wallet": "maya", "balance": -900}, {"wallet": "other", "balance": 400}]'::jsonb,
          'report_summary services.float: the balance per wallet over the owner''s stores');
select pg_temp.login('juan', 'A');
select is((select count(*)::int from jsonb_array_elements(public.sync_pull_service() -> 'floats') f
           where f ->> 'location_id' <> pg_temp.id('S01')::text), 0, 'a cashier pulls the floats of her store only');
select pg_temp.login('ownerB', 'B');
select is((select jsonb_array_length(public.sync_pull_service() -> 'floats')), 0, 'another tenant pulls none of our floats');
reset role;

-- ===== property: sales, expenses and service entries mixed, against an independent model =====
create temp table m_sale (id uuid primary key, day date, voided boolean not null default false);
create temp table m_pay (sale_id uuid, method text, wallet text, amount bigint);
create temp table m_exp (id uuid primary key, paid_from text, wallet text, amount bigint, day date,
                         voided boolean not null default false);
create temp table m_svc (id uuid primary key, kind text, wallet text, amount bigint, fee bigint, price bigint, day date,
                         voided boolean not null default false);
create temp table sent (n int primary key, op_id uuid, kind text, payload jsonb);
create temp table pstat (k text primary key, v int);
grant all on m_sale, m_pay, m_exp, m_svc, sent, pstat to authenticated;

create function pg_temp.prop(p_ops int) returns void language plpgsql as $$
declare
  v_kinds   text[] := array['cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust'];
  v_all     text[] := array['gcash', 'maya', 'load', 'other'];
  v_cust    text[] := array['gcash', 'maya', 'other'];
  i int; j int; r float8; v_n int := 0; v_parts int;
  v_kind text; v_wallet text; v_method text; v_from text; v_type text; v_vkind text; v_key text;
  v_amt bigint; v_fee bigint; v_price bigint; v_left bigint; v_part bigint;
  v_day date; v_secs float8; v_at timestamptz;
  v_id uuid; v_op uuid; v_payload jsonb; v_pays jsonb; v_res jsonb; s record;
  v_bad int := 0; v_sales int := 0; v_exps int := 0; v_svcs int := 0; v_vs int := 0; v_ve int := 0; v_vt int := 0;
  v_already int := 0; v_replays int := 0; v_refused int := 0;
begin
  perform setseed(0.15082026);
  for i in 1..p_ops loop
    r := random();
    v_n := v_n + 1;
    v_op := md5('p15-op:' || v_n)::uuid;
    v_day := date '2026-11-03' + floor(random() * 3)::int;
    v_secs := case floor(random() * 10)::int when 0 then 0 when 1 then 86399.999 else floor(random() * 86400) end;
    v_at := (v_day::timestamp + make_interval(secs => v_secs)) at time zone 'Asia/Manila';
    if r < 0.22 then
      -- a sale of 1 to 3 payments, cash or e-wallet, the e-wallet ones with a wallet or none
      v_id := md5('p15-sale:' || v_n)::uuid;
      v_amt := 1 + floor(random() * 50000)::bigint;
      v_parts := least(1 + floor(random() * 3)::int, v_amt::int);
      v_pays := '[]'::jsonb;
      v_left := v_amt;
      for j in 1..v_parts loop
        v_part := case when j = v_parts then v_left else 1 + floor(random() * (v_left - (v_parts - j)))::bigint end;
        v_left := v_left - v_part;
        v_method := case when random() < 0.6 then 'ewallet' else 'cash' end;
        v_wallet := case when v_method = 'ewallet' and random() < 0.75 then v_cust[1 + floor(random() * 3)::int] end;
        v_pays := v_pays || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
          'method', v_method, 'amount', v_part, 'wallet', v_wallet)));
      end loop;
      v_payload := jsonb_build_object('id', v_id, 'local_no', 'P-' || v_n, 'sold_at', v_at,
        'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:pitem'), 'qty', 1, 'unit_price', v_amt)),
        'payments', v_pays);
      v_res := public.sync_push(jsonb_build_array(jsonb_build_object(
        'op_id', v_op, 'kind', 'record_sale', 'payload', v_payload))) -> 0;
      if v_res ->> 'status' = 'ok' and v_res -> 'result' ->> 'replay' = 'false' then
        insert into pg_temp.m_sale values (v_id, v_day, false);
        insert into pg_temp.m_pay select v_id, x ->> 'method', x ->> 'wallet', (x ->> 'amount')::bigint
                                  from jsonb_array_elements(v_pays) x;
        insert into pg_temp.sent values (v_n, v_op, 'record_sale', v_payload);
        v_sales := v_sales + 1;
      else
        v_bad := v_bad + 1;
        raise notice 'unexpected answer to a sale: %', v_res;
      end if;
    elsif r < 0.36 then
      -- an expense from the drawer or an e-wallet (with a wallet or none)
      v_id := md5('p15-exp:' || v_n)::uuid;
      v_amt := 1 + floor(random() * 30000)::bigint;
      v_from := case when random() < 0.6 then 'ewallet' else 'cash' end;
      v_wallet := case when v_from = 'ewallet' and random() < 0.75 then v_cust[1 + floor(random() * 3)::int] end;
      v_payload := jsonb_strip_nulls(jsonb_build_object('id', v_id, 'amount', v_amt, 'category', 'other',
        'paid_from', v_from, 'wallet', v_wallet, 'spent_at', v_at));
      v_res := public.sync_push(jsonb_build_array(jsonb_build_object(
        'op_id', v_op, 'kind', 'record_expense', 'payload', v_payload))) -> 0;
      if v_res ->> 'status' = 'ok' and v_res -> 'result' ->> 'replay' = 'false' then
        insert into pg_temp.m_exp values (v_id, v_from, v_wallet, v_amt, v_day, false);
        insert into pg_temp.sent values (v_n, v_op, 'record_expense', v_payload);
        v_exps := v_exps + 1;
      else
        v_bad := v_bad + 1;
        raise notice 'unexpected answer to an expense: %', v_res;
      end if;
    elsif r < 0.56 then
      -- a service entry of any kind (P8-06)
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
      v_id := md5('p15-tx:' || v_n)::uuid;
      v_payload := jsonb_strip_nulls(jsonb_build_object(
        'id', v_id, 'kind', v_kind, 'wallet', v_wallet, 'amount', v_amt,
        'fee', case when v_kind in ('cash_in', 'cash_out') then v_fee end, 'price', v_price,
        'note', case when v_kind = 'float_adjust' then 'bilang' end, 'txn_at', v_at));
      v_res := public.sync_push(jsonb_build_array(jsonb_build_object(
        'op_id', v_op, 'kind', 'record_service_txn', 'payload', v_payload))) -> 0;
      if v_res ->> 'status' = 'ok' and v_res -> 'result' ->> 'replay' = 'false' then
        insert into pg_temp.m_svc values (v_id, v_kind, v_wallet, v_amt, v_fee, v_price, v_day, false);
        insert into pg_temp.sent values (v_n, v_op, 'record_service_txn', v_payload);
        v_svcs := v_svcs + 1;
      else
        v_bad := v_bad + 1;
        raise notice 'unexpected answer to a service entry: %', v_res;
      end if;
    elsif r < 0.78 then
      -- a void of an open record (r < 0.72), or a second void of a voided one (0.72 .. 0.78): nothing changes then
      v_type := (array['sale', 'expense', 'service'])[1 + floor(random() * 3)::int];
      if v_type = 'sale' then
        select x.id into v_id from pg_temp.m_sale x where x.voided = (r >= 0.72) order by random() limit 1;
        v_vkind := 'void_sale'; v_key := 'sale_id';
      elsif v_type = 'expense' then
        select x.id into v_id from pg_temp.m_exp x where x.voided = (r >= 0.72) order by random() limit 1;
        v_vkind := 'void_expense'; v_key := 'expense_id';
      else
        select x.id into v_id from pg_temp.m_svc x where x.voided = (r >= 0.72) order by random() limit 1;
        v_vkind := 'void_service_txn'; v_key := 'txn_id';
      end if;
      continue when not found;
      v_payload := jsonb_build_object(v_key, v_id, 'reason', 'mali');
      v_res := public.sync_push(jsonb_build_array(jsonb_build_object(
        'op_id', v_op, 'kind', v_vkind, 'payload', v_payload))) -> 0;
      if r >= 0.72 then
        if v_res ->> 'status' = 'ok' and v_res -> 'result' ->> 'already' = 'true' then
          v_already := v_already + 1;
        else
          v_bad := v_bad + 1;
          raise notice 'unexpected answer to a second void: %', v_res;
        end if;
      elsif v_res ->> 'status' = 'ok' and v_res -> 'result' ->> 'already' = 'false' then
        if v_type = 'sale' then
          update pg_temp.m_sale set voided = true where id = v_id;
          v_vs := v_vs + 1;
        elsif v_type = 'expense' then
          update pg_temp.m_exp set voided = true where id = v_id;
          v_ve := v_ve + 1;
        else
          update pg_temp.m_svc set voided = true where id = v_id;
          v_vt := v_vt + 1;
        end if;
        insert into pg_temp.sent values (v_n, v_op, v_vkind, v_payload);
      else
        v_bad := v_bad + 1;
        raise notice 'unexpected answer to a void: %', v_res;
      end if;
    elsif r < 0.93 then
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
      -- a refused record (a wallet where none may be): leaves nothing
      v_payload := case floor(random() * 3)::int
        when 0 then jsonb_build_object('kind', 'record_sale', 'payload', jsonb_build_object(
          'id', md5('p15-bad:' || v_n)::uuid, 'local_no', 'PB-' || v_n, 'sold_at', v_at,
          'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:pitem'), 'qty', 1, 'unit_price', 100)),
          'payments', jsonb_build_array(jsonb_build_object('method', 'ewallet', 'amount', 100, 'wallet', 'load'))))
        when 1 then jsonb_build_object('kind', 'record_sale', 'payload', jsonb_build_object(
          'id', md5('p15-bad:' || v_n)::uuid, 'local_no', 'PB-' || v_n, 'sold_at', v_at,
          'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:pitem'), 'qty', 1, 'unit_price', 100)),
          'payments', jsonb_build_array(jsonb_build_object('method', 'ewallet', 'amount', 60, 'wallet', 'gcash'),
                                        jsonb_build_object('method', 'cash', 'amount', 40, 'wallet', 'maya'))))
        else jsonb_build_object('kind', 'record_expense', 'payload', jsonb_build_object(
          'id', md5('p15-bad:' || v_n)::uuid, 'amount', 100, 'category', 'other', 'paid_from', 'cash', 'wallet', 'gcash'))
      end;
      v_res := public.sync_push(jsonb_build_array(v_payload || jsonb_build_object('op_id', v_op))) -> 0;
      if v_res ->> 'status' = 'rejected' and v_res ->> 'hint' = 'invalid_value' then
        v_refused := v_refused + 1;
      else
        v_bad := v_bad + 1;
        raise notice 'unexpected answer to a bad record: %', v_res;
      end if;
    end if;
  end loop;
  insert into pg_temp.pstat values ('ops', v_n), ('bad', v_bad), ('sales', v_sales), ('expenses', v_exps),
    ('services', v_svcs), ('void_sales', v_vs), ('void_expenses', v_ve), ('void_services', v_vt),
    ('already', v_already), ('replays', v_replays), ('refused', v_refused);
end;
$$;

-- the model's own copy of the float and cash rules (written out again here, not taken from the migrations)
create function pg_temp.svc_float(m pg_temp.m_svc) returns bigint language sql immutable as $$
  select case when m.kind in ('cash_in', 'load', 'float_withdraw') then -m.amount else m.amount end
$$;
create function pg_temp.svc_cash(m pg_temp.m_svc) returns bigint language sql immutable as $$
  select case m.kind when 'cash_in' then m.amount + m.fee when 'cash_out' then m.fee - m.amount when 'load' then m.price
                     when 'float_topup' then -m.amount when 'float_withdraw' then m.amount else 0 end
$$;
-- every signed float effect that counts: (wallet, effect)
create view pg_temp.model_effects as
  select m.wallet, pg_temp.svc_float(m) as effect from pg_temp.m_svc m where not m.voided
  union all
  select p.wallet, p.amount from pg_temp.m_pay p join pg_temp.m_sale s on s.id = p.sale_id
  where not s.voided and p.method = 'ewallet' and p.wallet is not null
  union all
  select e.wallet, -e.amount from pg_temp.m_exp e where not e.voided and e.paid_from = 'ewallet' and e.wallet is not null;
grant select on pg_temp.model_effects to authenticated;

select pg_temp.login('ownerP', 'P');
set local role authenticated;
select pg_temp.prop(420);
reset role;
set constraints all immediate;

select diag('property mix: ' || (select string_agg(k || '=' || v, ', ' order by k) from pg_temp.pstat)
            || '; unnamed e-wallet payments=' || (select count(*) from pg_temp.m_pay where method = 'ewallet' and wallet is null)
            || ', split sales=' || (select count(*) from (select sale_id from pg_temp.m_pay group by sale_id having count(*) > 1) x)
            || ', unnamed e-wallet expenses=' || (select count(*) from pg_temp.m_exp where paid_from = 'ewallet' and wallet is null)
            || ', payment wallets=' || (select count(distinct wallet) from pg_temp.m_pay));
select is((select v from pg_temp.pstat where k = 'bad'), 0,
          'property: every op got the expected answer (applied, replay, already voided, or refused)');
select ok((select bool_and(case k when 'ops' then v >= 400 when 'sales' then v >= 60 when 'expenses' then v >= 40
                                  when 'services' then v >= 60 when 'void_sales' then v >= 8 when 'void_expenses' then v >= 8
                                  when 'void_services' then v >= 8 when 'already' then v >= 5 when 'replays' then v >= 30
                                  when 'refused' then v >= 10 else true end) from pg_temp.pstat)
          and (select count(*) from pg_temp.m_pay where method = 'ewallet' and wallet is null) >= 10
          and (select count(*) from (select sale_id from pg_temp.m_pay group by sale_id having count(*) > 1) x) >= 20
          and (select count(*) from pg_temp.m_exp where paid_from = 'ewallet' and wallet is null) >= 3
          and (select count(distinct wallet) from pg_temp.m_pay) = 3,
          'property: 400+ ops with sales (split, named and unnamed wallets), expenses, service entries, voids of each, '
          || 'second voids, replays and refusals');
select is((select count(*)::int
           from (select wallet, balance from public.wallet_float where tenant_id = pg_temp.t('P')) w
           full join (select wallet, sum(effect)::bigint as b from pg_temp.model_effects group by wallet) x using (wallet)
           where coalesce(w.balance, 0) <> coalesce(x.b, 0)), 0,
          'property: float per wallet = signed effects of service entries + named e-wallet payments of open sales '
          || '- named e-wallet expenses not voided');
select is((select count(*)::int
           from (select wallet, txn_count from public.wallet_float where tenant_id = pg_temp.t('P')) w
           full join (select wallet, count(*)::int as n from pg_temp.model_effects group by wallet) x using (wallet)
           where coalesce(w.txn_count, 0) <> coalesce(x.n, 0)), 0,
          'property: the entry count per wallet = the effects that count');
select is((select array_agg(public.day_close_server_expected(pg_temp.t('P'), pg_temp.id('SP'), d::date) order by d)
           from generate_series(date '2026-11-02', date '2026-11-06', interval '1 day') d),
          (select array_agg(
             coalesce((select sum(p.amount) from pg_temp.m_pay p join pg_temp.m_sale s on s.id = p.sale_id
                       where not s.voided and p.method = 'cash' and s.day = d::date), 0)
           - coalesce((select sum(e.amount) from pg_temp.m_exp e where not e.voided and e.paid_from = 'cash' and e.day = d::date), 0)
           + coalesce((select sum(pg_temp.svc_cash(m)) from pg_temp.m_svc m where not m.voided and m.day = d::date), 0)
             order by d)::bigint[]
           from generate_series(date '2026-11-02', date '2026-11-06', interval '1 day') d),
          'property: expected cash per day = cash payments - cash expenses + service cash (e-wallets never count as cash)');
select is((select count(*)::int
           from (select day, cash, ewallet from public.daily_sales_summary where tenant_id = pg_temp.t('P')) d
           full join (select s.day, sum(p.amount) filter (where p.method = 'cash') as c,
                             sum(p.amount) filter (where p.method = 'ewallet') as e
                      from pg_temp.m_pay p join pg_temp.m_sale s on s.id = p.sale_id where not s.voided group by s.day) x
             using (day)
           where coalesce(d.cash, 0) <> coalesce(x.c, 0) or coalesce(d.ewallet, 0) <> coalesce(x.e, 0)), 0,
          'property: the sales day summary by method is unchanged (all e-wallet payments, named or not)');
select is((select ((select count(*) from public.sales where tenant_id = pg_temp.t('P')),
                   (select count(*) from public.sales where tenant_id = pg_temp.t('P') and status = 'voided'),
                   (select count(*) from public.expenses where tenant_id = pg_temp.t('P')),
                   (select count(*) from public.expenses where tenant_id = pg_temp.t('P') and voided_at is not null))::text),
          (select ((select count(*) from pg_temp.m_sale), (select count(*) from pg_temp.m_sale where voided),
                   (select count(*) from pg_temp.m_exp), (select count(*) from pg_temp.m_exp where voided))::text),
          'property: one row per new record and one void per effective void (replays, second voids, refusals wrote nothing)');
select is((select array_agg(coalesce(wallet, '-') || '=' || a order by coalesce(wallet, '-'))
           from (select p.wallet, sum(p.amount)::bigint as a from public.payments p where p.tenant_id = pg_temp.t('P')
                 and p.method = 'ewallet' group by p.wallet) z),
          (select array_agg(coalesce(wallet, '-') || '=' || a order by coalesce(wallet, '-'))
           from (select wallet, sum(amount)::bigint as a from pg_temp.m_pay where method = 'ewallet' group by wallet) z),
          'property: the stored payment wallets are the ones sent');
select pg_temp.login('ownerP', 'P');
set local role authenticated;
select is((select r -> 'services' -> 'float' from (select public.report_summary('2026-11-03', '2026-11-05') r) x),
          (select jsonb_agg(jsonb_build_object('wallet', wallet, 'balance', b)
                            order by array_position(array['gcash', 'maya', 'load', 'other'], wallet))
           from (select wallet, sum(effect)::bigint as b from pg_temp.model_effects group by wallet) y),
          'property: the report''s floats match the model');
select is((select jsonb_agg(jsonb_build_object('wallet', f ->> 'wallet', 'balance', (f ->> 'balance')::bigint)
                            order by array_position(array['gcash', 'maya', 'load', 'other'], f ->> 'wallet'))
           from jsonb_array_elements(public.sync_pull_service() -> 'floats') f),
          (select jsonb_agg(jsonb_build_object('wallet', wallet, 'balance', b)
                            order by array_position(array['gcash', 'maya', 'load', 'other'], wallet))
           from (select wallet, sum(effect)::bigint as b from pg_temp.model_effects group by wallet) y),
          'property: the pulled floats match the model');
reset role;

select * from finish();
rollback;
