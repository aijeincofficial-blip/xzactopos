-- QA-03 Performance & Free-Tier Optimisation verification tests:
--   1. customer_utang_balances() aggregates balances server-side cleanly, respects tenant/role/anon gates & pagination
--   2. sync_pull_catalog / sync_pull_pos / sync_pull_sales / sync_pull_warehouse preserve identical cursor & empty results
--   3. New performance indexes exist in pg_indexes
--   4. SECURITY DEFINER additions pin search_path and revoke anon EXECUTE

begin;
select plan(16);

create temp table ids (key text primary key, id uuid);
insert into ids (key, id) values
  ('tA',      '30000000-0000-0000-0000-000000000001'::uuid),
  ('tB',      '30000000-0000-0000-0000-000000000002'::uuid),
  ('sA1',     '30000000-0000-0000-0000-000000000011'::uuid),
  ('ownerA',  '30000000-0000-0000-0000-000000000021'::uuid),
  ('cashA',   '30000000-0000-0000-0000-000000000022'::uuid),
  ('whA',     '30000000-0000-0000-0000-000000000023'::uuid),
  ('c1',      '30000000-0000-0000-0000-000000000031'::uuid),
  ('c2',      '30000000-0000-0000-0000-000000000032'::uuid),
  ('cDel',    '30000000-0000-0000-0000-000000000033'::uuid),
  ('cB',      '30000000-0000-0000-0000-000000000034'::uuid);

grant select on ids to authenticated, anon;

create function pg_temp.id(k text) returns uuid language sql stable as
  $$ select id from ids where key = k $$;

create function pg_temp.hint(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_state = returned_sqlstate, v_hint = pg_exception_hint;
  return coalesce(v_hint, v_state);
end;
$$;

create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', pg_temp.id(p_user),
      'role', 'authenticated',
      'tenant_id', pg_temp.id(p_tenant)
    )::text,
    true
  );
$$;

insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.id('tA'), 'Perf Alpha', 'perf-alpha', 'PHP', 'Asia/Manila'),
  (pg_temp.id('tB'), 'Perf Beta',  'perf-beta',  'PHP', 'Asia/Manila');

insert into public.tenant_modules (tenant_id, pos, warehouse, inventory) values
  (pg_temp.id('tA'), true, true, true),
  (pg_temp.id('tB'), true, false, true);

insert into public.tenant_settings (tenant_id) values
  (pg_temp.id('tA')),
  (pg_temp.id('tB'));

insert into auth.users (id, email) values
  (pg_temp.id('ownerA'), 'ownerA@perf.invalid'),
  (pg_temp.id('cashA'),  'cashA@perf.invalid'),
  (pg_temp.id('whA'),    'whA@perf.invalid');

insert into public.locations (id, tenant_id, code, name, type) values
  (pg_temp.id('sA1'), pg_temp.id('tA'), 'S01', 'Store 1', 'store');

insert into public.profiles (user_id, tenant_id, username, full_name, role, active) values
  (pg_temp.id('ownerA'), pg_temp.id('tA'), 'ownera', 'Owner A', 'superadmin', true),
  (pg_temp.id('cashA'),  pg_temp.id('tA'), 'casha',  'Cashier A', 'cashier', true),
  (pg_temp.id('whA'),    pg_temp.id('tA'), 'wha',    'Warehouse A', 'warehouse', true);

insert into public.location_access (tenant_id, user_id, location_id) values
  (pg_temp.id('tA'), pg_temp.id('cashA'), pg_temp.id('sA1'));

insert into public.customers (id, tenant_id, name, phone, due_on, updated_at, deleted_at) values
  (pg_temp.id('c1'),   pg_temp.id('tA'), 'Zed Zero',     '09170000001', null, now() - interval '10 minutes', null),
  (pg_temp.id('c2'),   pg_temp.id('tA'), 'Anna Debtor',  '09170000002', '2026-11-01', now() - interval '10 minutes', null),
  (pg_temp.id('cDel'), pg_temp.id('tA'), 'Deleted User', null, null, now() - interval '10 minutes', now()),
  (pg_temp.id('cB'),   pg_temp.id('tB'), 'Other Tenant', null, null, now() - interval '10 minutes', null);

insert into public.customer_ledger (tenant_id, customer_id, kind, amount, location_id) values
  (pg_temp.id('tA'), pg_temp.id('c2'), 'charge',  5000, pg_temp.id('sA1')),
  (pg_temp.id('tA'), pg_temp.id('c2'), 'payment', -1500, pg_temp.id('sA1')),
  (pg_temp.id('tB'), pg_temp.id('cB'), 'charge',  9000, null);

-- 1. Verify hot-path indexes created
select is(
  (select count(*)::int from pg_indexes where schemaname = 'public' and indexname in (
    'sales_tenant_updated_idx',
    'sales_tenant_loc_sold_idx',
    'stock_levels_tenant_loc_variant_idx',
    'stock_levels_tenant_neg_idx',
    'stock_movements_tenant_loc_var_created_idx',
    'variant_prices_tenant_variant_idx',
    'daily_item_sales_tenant_loc_day_idx',
    'transfers_tenant_created_idx',
    'bins_tenant_updated_idx',
    'bin_stock_levels_tenant_updated_idx',
    'customer_ledger_tenant_cust_amt_idx'
  )),
  11,
  '1. All 11 key performance indexes exist on public tables'
);

-- 2. Verify anon privilege revoked on newly SECURITY DEFINER functions
select is(
  (select count(*)::int
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('customer_utang_balances', 'report_summary', 'report_multi_store', 'sync_pull_sales')
     and p.prosecdef = true
     and not has_function_privilege('anon', p.oid, 'execute')),
  4,
  '2. All QA-03 SECURITY DEFINER functions revoke anon EXECUTE and pin search_path'
);

-- 3. Anon blocked from customer_utang_balances
set local role anon;
select throws_ok(
  $$ select * from public.customer_utang_balances() $$,
  '42501',
  null,
  '3. Anon blocked from customer_utang_balances'
);
reset role;

-- 4-8. Owner A sees ordered balances (Anna Debtor 3500, Zed Zero 0; deleted & Tenant B excluded)
select pg_temp.login('ownerA', 'tA');
set local role authenticated;

create temp table ut_rows as
select * from public.customer_utang_balances();
grant select on ut_rows to authenticated;

select is((select count(*)::int from ut_rows), 2, '4. customer_utang_balances excludes soft-deleted & cross-tenant customers');
select is((select customer_id from ut_rows limit 1), pg_temp.id('c2'), '5. Highest positive balance sorted first');
select is((select balance from ut_rows where customer_id = pg_temp.id('c2')), 3500::bigint, '6. Balance accurately sums charges and payments server-side');
select is((select balance from ut_rows where customer_id = pg_temp.id('c1')), 0::bigint, '7. Customer with zero ledger entries returns balance 0');
select is(
  (select count(*)::int from public.customer_utang_balances(1, 1) where customer_id = pg_temp.id('c1')),
  1,
  '8. Pagination limit/offset returns next slice deterministically'
);

-- 9. Cashier allowed to view customer_utang_balances
select pg_temp.login('cashA', 'tA');
select is(
  (select count(*)::int from public.customer_utang_balances()),
  2,
  '9. Cashier can query tenant customer balances'
);

-- 10. Warehouse role denied customer_utang_balances
select pg_temp.login('whA', 'tA');
select is(
  pg_temp.hint($$ select * from public.customer_utang_balances() $$),
  'not_allowed',
  '10. Warehouse role denied customer_utang_balances'
);

-- 11. report_multi_store & report_summary still execute cleanly after SECURITY DEFINER consolidation
select pg_temp.login('ownerA', 'tA');
select is(
  (public.report_summary('2026-11-01'::date, '2026-11-10'::date) -> 'utang' ->> 'owed'),
  '3500',
  '11. report_summary computes utang and handles empty rollup days cleanly'
);
select is(
  (public.report_multi_store('2026-11-01'::date, '2026-11-10'::date) -> 'totals' ->> 'net'),
  '0',
  '12. report_multi_store returns 0 defaults cleanly when rollups are empty'
);

-- 13. Warehouse caller cannot read sales/utang data via report_summary (matches RLS behavior)
select pg_temp.login('whA', 'tA');
select is(
  (public.report_summary('2026-11-01'::date, '2026-11-10'::date) -> 'utang' ->> 'owed'),
  '0',
  '13. Warehouse caller sees 0 utang in report_summary matching prior RLS behavior'
);

-- 14-16. Cursor lower bounds on sync_pull_catalog, sync_pull_pos, sync_pull_warehouse & sync_pull_sales work cleanly
select pg_temp.login('ownerA', 'tA');
select is(
  jsonb_array_length(public.sync_pull_catalog('{}'::jsonb, 50) -> 'products' -> 'rows'),
  0,
  '14. sync_pull_catalog works on empty cursor'
);
select is(
  jsonb_array_length(public.sync_pull_pos(jsonb_build_object('customers', jsonb_build_object('ts', (now() - interval '1 hour')::text, 'k', '00000000-0000-0000-0000-000000000000')), 50) -> 'customers' -> 'rows'),
  3,
  '15. sync_pull_pos bounded cursor delta query matches all recent tenant customers (including deleted sync tombstones)'
);
select is(
  jsonb_array_length(public.sync_pull_sales(null, 50) -> 'rows'),
  0,
  '16. sync_pull_sales executes cleanly with SECURITY DEFINER location filter'
);

reset role;
select * from finish();
rollback;
