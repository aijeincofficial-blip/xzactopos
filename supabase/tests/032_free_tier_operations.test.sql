-- 032_free_tier_operations.test.sql: pgTAP tests for Card F-11 free-tier operations and maintenance

begin;
select plan(25);

-- ---------------------------------------------------------------------------
-- Setup Fixtures
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p_tenant text) returns uuid language sql immutable
  as $$ select md5('tenant:' || p_tenant)::uuid $$;
create function pg_temp.uid(p_tenant text, p_user text) returns uuid language sql immutable
  as $$ select md5('user:' || p_tenant || ':' || p_user)::uuid $$;
create function pg_temp.lid(p_tenant text, p_code text) returns uuid language sql immutable
  as $$ select md5('loc:' || p_tenant || ':' || p_code)::uuid $$;

-- Tenant A
insert into public.tenants (id, name, slug, base_currency)
  values (pg_temp.tid('A'), 'Tenant Alpha', 'tenant-alpha', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse)
  values (pg_temp.tid('A'), true, true);
insert into public.tenant_settings (tenant_id)
  values (pg_temp.tid('A'));

-- Users in Tenant A
insert into auth.users (id, email) values
  (pg_temp.uid('A', 'owner'), 'owner@alpha.invalid'),
  (pg_temp.uid('A', 'maria'), 'maria@alpha.invalid'),
  (pg_temp.uid('A', 'juan'),  'juan@alpha.invalid');

insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('A', 'owner'), pg_temp.tid('A'), 'owner', 'superadmin', true),
  (pg_temp.uid('A', 'maria'), pg_temp.tid('A'), 'maria', 'admin', true),
  (pg_temp.uid('A', 'juan'),  pg_temp.tid('A'), 'juan', 'cashier', true);

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.lid('A', 'S01'), pg_temp.tid('A'), 'store', 'S01', 'Store Alpha 1');

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('A', 'maria'), pg_temp.lid('A', 'S01'), pg_temp.tid('A'), 'manager'),
  (pg_temp.uid('A', 'juan'),  pg_temp.lid('A', 'S01'), pg_temp.tid('A'), null);

-- Tenant B
insert into public.tenants (id, name, slug, base_currency)
  values (pg_temp.tid('B'), 'Tenant Beta', 'tenant-beta', 'USD');
insert into public.tenant_modules (tenant_id, pos, warehouse)
  values (pg_temp.tid('B'), true, true);
insert into auth.users (id, email) values
  (pg_temp.uid('B', 'owner'), 'owner@beta.invalid');
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('B', 'owner'), pg_temp.tid('B'), 'owner', 'superadmin', true);

create function pg_temp.login(p_tenant text, p_user text) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', pg_temp.uid(p_tenant, p_user), 'role', 'authenticated', 'tenant_id', pg_temp.tid(p_tenant))::text,
    true);
$$;

create function pg_temp.logout() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
$$;

-- ---------------------------------------------------------------------------
-- 1. Keep-Alive Health Ping
-- ---------------------------------------------------------------------------

-- Anon cannot call health_ping (rule in 003: anon has no execute grants in public)
select pg_temp.logout();
set local role anon;

select throws_ok(
  $$ select public.health_ping() $$,
  '42501', null,
  'anon cannot execute health_ping'
);

reset role;

-- Callable as authenticated
select pg_temp.login('A', 'owner');
set local role authenticated;

select is(
  (public.health_ping() ->> 'ok')::boolean,
  true,
  'health_ping returns ok = true as authenticated'
);

select is(
  public.health_ping() ->> 'status',
  'healthy',
  'health_ping status is healthy'
);

select ok(
  (public.health_ping() ? 'timestamp'),
  'health_ping returns timestamp'
);

reset role;

-- ---------------------------------------------------------------------------
-- 2. Database Storage Metrics & Quotas
-- ---------------------------------------------------------------------------

-- Cashier and regular store admin cannot query storage metrics
select pg_temp.login('A', 'juan');
set local role authenticated;

select throws_matching(
  $$ select public.get_storage_metrics() $$,
  'only platform admins or account owners can view storage metrics',
  'cashier cannot view storage metrics'
);

reset role;

select pg_temp.login('A', 'maria');
set local role authenticated;

select throws_matching(
  $$ select public.get_storage_metrics() $$,
  'only platform admins or account owners can view storage metrics',
  'branch admin cannot view storage metrics'
);

reset role;

-- Non-platform superadmin receives strictly tenant-scoped stats (no global DB sizes/tables)
select pg_temp.login('A', 'owner');
set local role authenticated;

select is(
  (public.get_storage_metrics() ->> 'ok')::boolean,
  true,
  'superadmin can call get_storage_metrics'
);

select is(
  public.get_storage_metrics() ->> 'scope',
  'tenant',
  'non-platform superadmin gets tenant scope'
);

select is(
  (public.get_storage_metrics() -> 'total_bytes'),
  'null'::jsonb,
  'non-platform superadmin does not see global total_bytes'
);

select is(
  (public.get_storage_metrics() -> 'limit_bytes'),
  'null'::jsonb,
  'non-platform superadmin does not see global limit_bytes'
);

select is(
  jsonb_array_length(public.get_storage_metrics() -> 'tables'),
  0,
  'non-platform superadmin does not see global table breakdown'
);

select ok(
  public.get_storage_metrics() -> 'tenant_stats' ? 'products',
  'tenant_stats includes products count for superadmin'
);

reset role;

-- Platform admin receives full global storage metrics and top tables
insert into public.platform_admins (user_id)
  values (pg_temp.uid('A', 'owner'))
  on conflict do nothing;

select pg_temp.login('A', 'owner');
set local role authenticated;

select is(
  public.get_storage_metrics() ->> 'scope',
  'global',
  'platform admin receives global storage scope'
);

select ok(
  (public.get_storage_metrics() ->> 'total_bytes')::bigint > 0,
  'total_bytes is positive for platform admin'
);

select is(
  (public.get_storage_metrics() ->> 'limit_bytes')::bigint,
  524288000::bigint,
  'limit_bytes is 500 MB (524288000)'
);

select is(
  (public.get_storage_metrics() ->> 'limit_mb')::int,
  500,
  'limit_mb is 500'
);

select ok(
  (public.get_storage_metrics() ->> 'status') in ('healthy', 'warning', 'critical'),
  'status is healthy, warning, or critical'
);

select ok(
  jsonb_array_length(public.get_storage_metrics() -> 'tables') > 0,
  'tables list is populated for platform admin'
);

reset role;

delete from public.platform_admins where user_id = pg_temp.uid('A', 'owner');

-- ---------------------------------------------------------------------------
-- 3. Maintenance: Processed Ops & Approvals Retention Cleanup
-- ---------------------------------------------------------------------------

-- Cashier cannot run maintenance
select pg_temp.login('A', 'juan');
set local role authenticated;

select throws_matching(
  $$ select public.archive_processed_ops(30) $$,
  'only administrators can run maintenance tasks',
  'cashier cannot run archive maintenance'
);

reset role;

-- Retention period cannot be less than 7 days
select pg_temp.login('A', 'owner');
set local role authenticated;

select throws_matching(
  $$ select public.archive_processed_ops(5) $$,
  'retention period must be at least 7 days',
  'retention under 7 days is rejected'
);

reset role;

-- Seed historical test data
insert into public.processed_ops (tenant_id, client_op_id, kind, processed_at) values
  (pg_temp.tid('A'), md5('op:a:old')::uuid,    'catalog.upsert', now() - interval '45 days'),
  (pg_temp.tid('A'), md5('op:a:recent')::uuid, 'catalog.upsert', now() - interval '2 days'),
  (pg_temp.tid('B'), md5('op:b:old')::uuid,    'catalog.upsert', now() - interval '45 days');

insert into public.supervisor_approvals (
  id, tenant_id, location_id, action, ref_id, requested_by, approved_by, expires_at, used_at, used_op_id, issued_at
) values
  (md5('app:a:old')::uuid, pg_temp.tid('A'), pg_temp.lid('A', 'S01'), 'void_sale', md5('sale:1')::uuid,
   pg_temp.uid('A', 'maria'), pg_temp.uid('A', 'maria'), now() - interval '40 days', now() - interval '40 days', md5('op:a:old')::uuid, now() - interval '41 days'),
  (md5('app:a:new')::uuid, pg_temp.tid('A'), pg_temp.lid('A', 'S01'), 'void_sale', md5('sale:2')::uuid,
   pg_temp.uid('A', 'maria'), pg_temp.uid('A', 'maria'), now() + interval '1 hour', null, null, now());

-- Run archive maintenance for Tenant A with 30 days retention
select pg_temp.login('A', 'maria');
set local role authenticated;

create temp table pg_temp.archive_result as
select public.archive_processed_ops(30) as result;

select is(
  ((select result from pg_temp.archive_result) ->> 'ops_deleted')::int,
  1,
  'one stale op deleted from Tenant A'
);

select is(
  ((select result from pg_temp.archive_result) ->> 'approvals_deleted')::int,
  1,
  'one stale approval deleted from Tenant A'
);

reset role;

-- Verify Tenant A recent op is kept, old op is deleted
select is(
  (select count(*)::int from public.processed_ops where tenant_id = pg_temp.tid('A')),
  1,
  'Tenant A only has recent op remaining'
);

-- Verify Tenant B old op is preserved (tenant isolation)
select is(
  (select count(*)::int from public.processed_ops where tenant_id = pg_temp.tid('B')),
  1,
  'Tenant B old op is unaffected by Tenant A archive'
);

-- Verify audit log entry was written
select is(
  (select count(*)::int from public.audit_log where tenant_id = pg_temp.tid('A') and action = 'maintenance.archive'),
  1,
  'maintenance.archive audit log entry recorded'
);

select * from finish();
rollback;
