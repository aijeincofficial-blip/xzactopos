-- P8-02 expenses: record and void through sync_push, idempotency, permissions, bad input, append-only,
-- the daily rollup (void takes it out), a random record/void mix (rollup = sum of non-voided), the pull and the report.
begin;
select plan(79);

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
-- record an expense with op key k and expense id id('exp:' || k); extra overrides or adds payload keys
create function pg_temp.spend(k text, amount jsonb, category text, extra jsonb default '{}') returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_expense', jsonb_build_object(
    'id', pg_temp.id('exp:' || k), 'location_id', pg_temp.id('S01'), 'amount', amount, 'category', category,
    'paid_from', 'cash', 'spent_at', '2026-11-08T02:00:00Z') || extra)
$$;
create function pg_temp.void(k text, exp text, reason text default null) returns jsonb language sql as $$
  select pg_temp.push1(k, 'void_expense', jsonb_strip_nulls(jsonb_build_object('expense_id', pg_temp.id('exp:' || exp), 'reason', reason)))
$$;
create function pg_temp.roll(p_loc text, p_day date, p_cat text) returns text language sql as $$
  select coalesce((select format('%s/%s/%s/%s', amount, entry_count, cash, ewallet) from public.daily_expense_summary
                   where location_id = pg_temp.id(p_loc) and day = p_day and category = p_cat), 'none')
$$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'juan', 'pedro', 'ownerB']) n;
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP', 'Asia/Manila'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP', 'UTC');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.t('A'), true, true), (pg_temp.t('B'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('pedro'), pg_temp.t('A'), 'pedro', 'warehouse', true),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'A1'),
  (pg_temp.id('S02'), pg_temp.t('A'), 'store', 'S02', 'A2'),
  (pg_temp.id('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'AW'),
  (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'S01', 'B1');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('maria'), pg_temp.id('S02'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null);

-- ===== schema =====
select has_table('public', 'expenses', 'expenses table exists');
select has_table('public', 'daily_expense_summary', 'expense rollup table exists');
select col_type_is('public', 'expenses', 'amount', 'bigint', 'amount is integer minor units');

select pg_temp.login('owner', 'A');
set local role authenticated;

-- ===== record =====
select is(pg_temp.spend('e1', '15000', 'utilities') ->> 'status', 'ok', 'the owner records an electricity bill');
select is((select (amount, currency, category, paid_from, location_id = pg_temp.id('S01'), created_by = pg_temp.u('owner'))::text
           from public.expenses where id = pg_temp.id('exp:e1')),
          '(15000,PHP,utilities,cash,t,t)', 'stored with the base currency, store and who recorded it');
select is((select client_op_id from public.expenses where id = pg_temp.id('exp:e1')), pg_temp.id('op:e1'), 'the op id is kept on the row');
select is(pg_temp.spend('e1', '15000', 'utilities') -> 'result' ->> 'replay', 'true', 'the same op id again is a replay');
select is(pg_temp.spend('e1', '99999', 'rent') -> 'result' ->> 'replay', 'true', 'even with a changed payload');
select is((select count(*)::int from public.expenses where client_op_id = pg_temp.id('op:e1')), 1, 'one row for one op id');
select is((select amount from public.expenses where id = pg_temp.id('exp:e1')), 15000::bigint, 'the replay changed nothing');
select is(pg_temp.push1('e1-dup', 'record_expense', jsonb_build_object('id', pg_temp.id('exp:e1'), 'location_id', pg_temp.id('S01'),
            'amount', 100, 'category', 'other')) ->> 'hint', 'id_conflict', 'a second op with the same expense id is refused');
select is(pg_temp.push1('e1', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('x'))) ->> 'hint', 'op_id_reused',
          'the op id cannot be reused for another kind');

select is(pg_temp.spend('e2', '250000', 'stock_purchase', '{"paid_from": "ewallet", "spent_at": "2026-11-08T03:00:00Z", "note": "  Puregold  "}') ->> 'status', 'ok',
          'a supplier payment from the e-wallet');
select is((select note from public.expenses where id = pg_temp.id('exp:e2')), 'Puregold', 'the note is trimmed');
select is(pg_temp.spend('e3', '4000', 'transport', '{"spent_at": "2026-11-08T17:00:00Z", "currency": "php"}') ->> 'status', 'ok',
          'fare, with the base currency spelled out');
select is(pg_temp.spend('e5', '5000', 'utilities', jsonb_build_object('location_id', pg_temp.id('S02'))) ->> 'status', 'ok',
          'the owner records at the second store');
select is(pg_temp.spend('e6', '700', 'other', '{"location_id": null}') ->> 'hint', 'location_required',
          'with two stores the store must be given');

-- ===== bad input =====
select is(pg_temp.spend('b1', '0', 'other') ->> 'hint', 'amount_invalid', 'zero is refused');
select is(pg_temp.spend('b2', '-500', 'other') ->> 'hint', 'amount_invalid', 'a negative amount is refused');
select is(pg_temp.spend('b3', '12.5', 'other') ->> 'hint', 'amount_invalid', 'a fraction of a centavo is refused');
select is(pg_temp.spend('b4', '"12.50"', 'other') ->> 'hint', 'amount_invalid', 'a decimal string is refused');
select is(pg_temp.spend('b5', 'true', 'other') ->> 'hint', 'amount_invalid', 'a boolean is refused');
select is(pg_temp.push1('b6', 'record_expense', jsonb_build_object('id', pg_temp.id('exp:b6'), 'location_id', pg_temp.id('S01'), 'category', 'other')) ->> 'hint',
          'amount_invalid', 'a missing amount is refused');
select is(pg_temp.spend('b7', '1000000000000000000', 'other') ->> 'hint', 'amount_invalid', 'an absurd amount is refused');
select is(pg_temp.spend('b8', '500', 'snacks') ->> 'hint', 'invalid_value', 'an unknown category is refused');
select is(pg_temp.spend('b9', '500', null) ->> 'hint', 'invalid_value', 'a missing category is refused');
select is(pg_temp.spend('b10', '500', 'other', '{"paid_from": "card"}') ->> 'hint', 'invalid_value', 'paid from must be cash or ewallet');
select is(pg_temp.spend('b11', '500', 'other', '{"currency": "USD"}') ->> 'hint', 'invalid_value', 'a foreign currency is refused');
select is(pg_temp.spend('b12', '500', 'other', '{"id": null}') ->> 'hint', 'id_required', 'the expense id is required');
select is(pg_temp.spend('b13', '500', 'other', jsonb_build_object('location_id', pg_temp.id('W01'))) ->> 'hint', 'location_denied',
          'a warehouse is not a store');
select is((select count(*)::int from public.expenses where id in (select pg_temp.id('exp:b' || n) from generate_series(1, 13) n)), 0,
          'refused ops leave no rows');
select is(pg_temp.spend('b1', '700', 'other') ->> 'status', 'ok', 'a refused op id can be sent again once fixed');

-- ===== permissions =====
select pg_temp.login('maria', 'A');
select is(pg_temp.spend('e4', '1000', 'other', '{"spent_at": "2026-11-08T04:00:00Z"}') ->> 'status', 'ok', 'a store manager records at her store');
select is(pg_temp.spend('m2', '1000', 'other', jsonb_build_object('location_id', pg_temp.id('S02'))) ->> 'hint', 'not_allowed',
          'but not where she is only supervisor');
select is(pg_temp.void('m3', 'e5') ->> 'hint', 'not_allowed', 'nor void an expense of that store');
select is((select count(*)::int from public.expenses), 6, 'she reads the expenses of both her stores');
select pg_temp.login('juan', 'A');
select is(pg_temp.spend('j1', '1000', 'other') ->> 'hint', 'not_allowed', 'a cashier cannot record an expense');
select is(pg_temp.void('j2', 'e1') ->> 'hint', 'not_allowed', 'nor void one');
select is((select count(*)::int from public.expenses), 0, 'nor read them');
select is((select count(*)::int from public.daily_expense_summary), 0, 'nor the rollup');
select pg_temp.login('pedro', 'A');
select is(pg_temp.spend('p1', '1000', 'other') ->> 'hint', 'not_allowed', 'warehouse staff cannot record an expense');
select pg_temp.login('ownerB', 'B');
select is(pg_temp.spend('x1', '1000', 'other') ->> 'hint', 'location_denied', 'another tenant cannot record at our store');
select is(pg_temp.void('x2', 'e1') ->> 'hint', 'expense_not_found', 'nor void our expense');
select is((select count(*)::int from public.expenses), 0, 'nor read ours');

-- ===== no direct writes, append-only =====
select pg_temp.login('owner', 'A');
select throws_ok(format($$ insert into public.expenses (id, tenant_id, location_id, client_op_id, amount, currency, category, paid_from, spent_at)
                           values (gen_random_uuid(), %L, %L, gen_random_uuid(), 1, 'PHP', 'other', 'cash', now()) $$,
                        pg_temp.t('A'), pg_temp.id('S01')),
                 '42501', null, 'clients cannot insert expenses directly');
select throws_ok($$ update public.expenses set amount = 1 $$, '42501', null, 'clients cannot edit expenses');
select throws_ok($$ insert into public.daily_expense_summary (tenant_id, location_id, day, category) values (md5('t:A')::uuid, md5('id:S01')::uuid, '2026-01-01', 'other') $$,
                 '42501', null, 'clients cannot write the rollup');
reset role;
select throws_ok($$ update public.expenses set amount = 1 where id = md5('id:exp:e1')::uuid $$, '55000', null, 'even the server cannot change an amount');
select throws_ok($$ delete from public.expenses where id = md5('id:exp:e1')::uuid $$, '55000', null, 'or delete an expense');
select throws_ok($$ update public.expenses set deleted_at = now() where id = md5('id:exp:e1')::uuid $$, '55000', null, 'or soft-delete it (void instead)');
select pg_temp.login('owner', 'A');
set local role authenticated;

-- ===== rollup (tenant day = Asia/Manila) =====
select is(pg_temp.roll('S01', '2026-11-08', 'utilities'), '15000/1/15000/0', 'S01 utilities on the 8th');
select is(pg_temp.roll('S01', '2026-11-08', 'stock_purchase'), '250000/1/0/250000', 'paid from the e-wallet goes to ewallet');
select is(pg_temp.roll('S01', '2026-11-09', 'transport'), '4000/1/4000/0', '17:00Z on the 8th is the 9th in Manila');
select is(pg_temp.roll('S02', '2026-11-08', 'utilities'), '5000/1/5000/0', 'each store has its own rows');

-- ===== void =====
select is(pg_temp.void('v1', 'e2', 'maling halaga') -> 'result' ->> 'already', 'false', 'the owner voids the supplier payment');
select is((select (voided_at is not null, void_reason, amount)::text from public.expenses where id = pg_temp.id('exp:e2')),
          '(t,"maling halaga",250000)', 'the row stays, marked void with the reason and its amount');
select is(pg_temp.roll('S01', '2026-11-08', 'stock_purchase'), '0/0/0/0', 'the void takes it out of the rollup');
select is(pg_temp.void('v1', 'e2') -> 'result' ->> 'replay', 'true', 'the same void op again is a replay');
select is(pg_temp.void('v2', 'e2') -> 'result' ->> 'already', 'true', 'voiding again is a no-op');
select is(pg_temp.roll('S01', '2026-11-08', 'stock_purchase'), '0/0/0/0', 'and does not take it out twice');
select is(pg_temp.void('v3', 'nothing') ->> 'hint', 'expense_not_found', 'an unknown expense cannot be voided');
reset role;
select throws_ok($$ update public.expenses set voided_at = null where id = md5('id:exp:e2')::uuid $$, '55000', null, 'a void cannot be undone');
select throws_ok($$ update public.expenses set void_reason = 'x' where id = md5('id:exp:e2')::uuid $$, '55000', null, 'nor its reason changed');
select pg_temp.login('owner', 'A');
set local role authenticated;

-- ===== report reads the rollup =====
create temp table rep as select public.report_summary('2026-11-08', '2026-11-09') as r;
grant select on rep to authenticated;
select is((select r -> 'expenses' ->> 'total' from rep), '25700', 'expense total over both days leaves out the void (150 + 40 + 50 + 10 + 7)');
select is((select r -> 'expenses' -> 'by_category' -> 0 ->> 'category' from rep), 'utilities', 'largest category first');
select is((select jsonb_array_length(r -> 'expenses' -> 'by_category') from rep), 3, 'a category with only voided entries is left out');
select is((select r -> 'expenses' -> 'days' -> 1 ->> 'amount' from rep), '4000', 'per day totals');
select pg_temp.login('juan', 'A');
select is(public.report_summary('2026-11-08', '2026-11-09') -> 'expenses' ->> 'total', '0', 'a cashier''s report has no expenses');

-- ===== random mix: rollup = sum of non-voided expenses =====
select pg_temp.login('owner', 'A');
do $$
declare
  cats  text[] := array['stock_purchase', 'utilities', 'transport', 'wages', 'rent', 'other'];
  locs  uuid[] := array[md5('id:S01')::uuid, md5('id:S02')::uuid];
  ids   uuid[] := '{}';
  sent  jsonb[] := '{}';
  ops   jsonb := '[]';
  o     jsonb;
  res   jsonb;
  i     int;
begin
  perform setseed(0.2026);
  for i in 1..400 loop
    if cardinality(ids) = 0 or random() < 0.6 then
      o := pg_temp.op('mix:' || i, 'record_expense', jsonb_build_object(
        'id', md5('mixexp:' || i)::uuid,
        'location_id', locs[1 + floor(random() * 2)::int],
        'amount', 1 + floor(random() * 500000)::bigint,
        'category', cats[1 + floor(random() * 6)::int],
        'paid_from', case when random() < 0.7 then 'cash' else 'ewallet' end,
        'spent_at', '2026-10-01T00:00:00Z'::timestamptz + random() * interval '6 days'));
      ids := ids || md5('mixexp:' || i)::uuid;
    elsif random() < 0.2 then
      o := sent[1 + floor(random() * cardinality(sent))::int];   -- a resend of an earlier op (replay)
    else
      o := pg_temp.op('mix:' || i, 'void_expense', jsonb_build_object('expense_id', ids[1 + floor(random() * cardinality(ids))::int]));
    end if;
    ops := ops || jsonb_build_array(o);
    sent := sent || o;
    if jsonb_array_length(ops) = 50 or i = 400 then
      res := public.sync_push(ops);
      if exists (select 1 from jsonb_array_elements(res) x where x ->> 'status' <> 'ok') then
        raise exception 'mix op failed: %', res;
      end if;
      ops := '[]';
    end if;
  end loop;
end;
$$;
reset role;

select ok((select count(*) from public.expenses where tenant_id = md5('t:A')::uuid and voided_at is not null) > 10
          and (select count(*) from public.expenses where id = any (select md5('mixexp:' || n)::uuid from generate_series(1, 400) n)) > 150,
          'the mix recorded and voided plenty');
select is_empty($$
  with tz as (select id, timezone from public.tenants),
  raw as (
    select e.tenant_id, e.location_id, (e.spent_at at time zone tz.timezone)::date as day, e.category,
           sum(e.amount)::bigint as amount, count(*)::int as n,
           sum(e.amount) filter (where e.paid_from = 'cash')::bigint as cash,
           sum(e.amount) filter (where e.paid_from = 'ewallet')::bigint as ewallet
    from public.expenses e join tz on tz.id = e.tenant_id
    where e.voided_at is null
    group by 1, 2, 3, 4
  )
  select coalesce(r.location_id, d.location_id), coalesce(r.day, d.day), coalesce(r.category, d.category)
  from raw r
  full join (select * from public.daily_expense_summary where entry_count <> 0 or amount <> 0) d
    on d.location_id = r.location_id and d.day = r.day and d.category = r.category
  where r.location_id is null or d.location_id is null
     or (r.amount, r.n, coalesce(r.cash, 0), coalesce(r.ewallet, 0)) is distinct from (d.amount, d.entry_count, d.cash, d.ewallet)
$$, 'every rollup row equals the sum of the non-voided expenses (amount, count, cash, ewallet)');
select is((select sum(amount) from public.daily_expense_summary), (select sum(amount) from public.expenses where voided_at is null),
          'the rollup total equals the sum of the non-voided expenses');
select is((select count(*)::int from public.daily_expense_summary where amount < 0 or entry_count < 0 or cash < 0 or ewallet < 0), 0,
          'no rollup row goes negative');

-- ===== pull (tenant B, timestamps relative to now) =====
select pg_temp.login('ownerB', 'B');
set local role authenticated;
select pg_temp.push1('pb1', 'record_expense', jsonb_build_object('id', pg_temp.id('exp:pb1'), 'amount', 1000, 'category', 'rent', 'spent_at', now() - interval '2 days'));
select pg_temp.push1('pb2', 'record_expense', jsonb_build_object('id', pg_temp.id('exp:pb2'), 'amount', 2000, 'category', 'wages', 'paid_from', 'ewallet', 'note', 'sweldo'));
select pg_temp.push1('pb3', 'record_expense', jsonb_build_object('id', pg_temp.id('exp:pb3'), 'amount', 3000, 'category', 'other', 'spent_at', now() - interval '1 day'));
select pg_temp.push1('pbold', 'record_expense', jsonb_build_object('id', pg_temp.id('exp:pbold'), 'amount', 9000, 'category', 'rent', 'spent_at', now() - interval '60 days'));
reset role;
set local session_replication_role = replica;
update public.expenses set updated_at = now() - interval '1 minute';
set local session_replication_role = origin;
set local role authenticated;

create temp table pullb as select public.sync_pull_expenses(null, 100) as r;
grant select on pullb to authenticated;
select is((select jsonb_array_length(r -> 'rows') from pullb), 3, 'the first pull returns the last 30 days (the 60-day-old one is left out)');
select is((select (x ->> 'amount', x ->> 'category', x ->> 'paid_from', x ->> 'note', x ->> 'currency', x ->> 'location_id')::text
           from pullb, jsonb_array_elements(r -> 'rows') x where x ->> 'id' = pg_temp.id('exp:pb2')::text),
          format('(2000,wages,ewallet,sweldo,PHP,%s)', pg_temp.id('SB')), 'a row carries amount, category, paid from, note, currency and store');
create temp table pullsmall as select public.sync_pull_expenses(null, 2) as r;
grant select on pullsmall to authenticated;
select is((select r ->> 'has_more' from pullsmall), 'true', 'a small page says there is more');
select is(jsonb_array_length(public.sync_pull_expenses((select r -> 'cursor' from pullsmall), 2) -> 'rows'), 1, 'the next page continues after the cursor');
select pg_temp.push1('pbv', 'void_expense', jsonb_build_object('expense_id', pg_temp.id('exp:pb1'), 'reason', 'doble'));
reset role;
set local session_replication_role = replica;
update public.expenses set updated_at = now() - interval '30 seconds' where id = md5('id:exp:pb1')::uuid;
set local session_replication_role = origin;
set local role authenticated;
select is((select x ->> 'void_reason' from jsonb_array_elements(public.sync_pull_expenses((select r -> 'cursor' from pullb), 100) -> 'rows') x limit 1),
          'doble', 'a later void is delivered after the cursor');
select pg_temp.login('owner', 'A');
select is((select count(*)::int from jsonb_array_elements(public.sync_pull_expenses(null, 200) -> 'rows') x
           where (x ->> 'location_id')::uuid = pg_temp.id('SB')), 0, 'another tenant gets none of B''s expenses');
select pg_temp.login('juan', 'A');
select throws_ok($$ select public.sync_pull_expenses(null, 0) $$, '22023', null, 'a bad page size is refused');

reset role;
select * from finish();
rollback;
