-- 034_platform_admin.test.sql: pgTAP tests for Card F-12 platform administration

begin;
select plan(21);

-- ---------------------------------------------------------------------------
-- Setup Fixtures
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p_tenant text) returns uuid language sql immutable
  as $$ select md5('tenant:' || p_tenant)::uuid $$;
create function pg_temp.uid(p_tenant text, p_user text) returns uuid language sql immutable
  as $$ select md5('user:' || p_tenant || ':' || p_user)::uuid $$;

-- Tenant 1
insert into public.tenants (id, name, slug, base_currency, plan, status)
  values (pg_temp.tid('T1'), 'Store One', 'store-one', 'PHP', 'free', 'active');
insert into public.tenant_modules (tenant_id, pos) values (pg_temp.tid('T1'), true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('T1'));
insert into public.tenant_limits (tenant_id, max_locations, max_users) values (pg_temp.tid('T1'), 2, 5);

-- Tenant 2
insert into public.tenants (id, name, slug, base_currency, plan, status)
  values (pg_temp.tid('T2'), 'Store Two', 'store-two', 'PHP', 'pro', 'suspended');
insert into public.tenant_modules (tenant_id, pos) values (pg_temp.tid('T2'), true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('T2'));
insert into public.tenant_limits (tenant_id, max_locations, max_users) values (pg_temp.tid('T2'), 10, 50);

-- Users
insert into auth.users (id, email) values
  (pg_temp.uid('T1', 'owner'), 'owner@t1.invalid'),
  (pg_temp.uid('T1', 'cashier'), 'cashier@t1.invalid'),
  (pg_temp.uid('T1', 'sysadmin'), 'admin@platform.invalid');

insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('T1', 'owner'), pg_temp.tid('T1'), 'owner', 'superadmin', true),
  (pg_temp.uid('T1', 'cashier'), pg_temp.tid('T1'), 'cashier', 'cashier', true),
  (pg_temp.uid('T1', 'sysadmin'), pg_temp.tid('T1'), 'sysadmin', 'superadmin', true);

-- Make T1/sysadmin a platform operator
insert into public.platform_admins (user_id) values (pg_temp.uid('T1', 'sysadmin'));

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
-- 1. Security & RBAC: Anon blocked
-- ---------------------------------------------------------------------------
set local role anon;

select throws_ok(
  $$ select public.get_platform_metrics() $$,
  '42501',
  null,
  'anon cannot execute get_platform_metrics'
);

select throws_ok(
  $$ select public.list_platform_tenants() $$,
  '42501',
  null,
  'anon cannot execute list_platform_tenants'
);

select throws_ok(
  $$ select public.set_platform_tenant_status(gen_random_uuid(), 'suspended') $$,
  '42501',
  null,
  'anon cannot execute set_platform_tenant_status'
);

select throws_ok(
  $$ select public.set_platform_tenant_plan(gen_random_uuid(), 'pro') $$,
  '42501',
  null,
  'anon cannot execute set_platform_tenant_plan'
);

-- ---------------------------------------------------------------------------
-- 2. Security & RBAC: Standard Tenant Users blocked (Cashier & Tenant Superadmin)
-- ---------------------------------------------------------------------------
set local role authenticated;

-- 2.1 Cashier blocked
select pg_temp.login('T1', 'cashier');
select throws_ok(
  $$ select public.get_platform_metrics() $$,
  '42501',
  null,
  'cashier cannot call get_platform_metrics'
);
select throws_ok(
  $$ select public.list_platform_tenants() $$,
  '42501',
  null,
  'cashier cannot call list_platform_tenants'
);

-- 2.2 Tenant Superadmin (who is not platform admin) blocked
select pg_temp.login('T1', 'owner');
select throws_ok(
  $$ select public.get_platform_metrics() $$,
  '42501',
  null,
  'tenant superadmin cannot call get_platform_metrics'
);
select throws_ok(
  $$ select public.list_platform_tenants() $$,
  '42501',
  null,
  'tenant superadmin cannot call list_platform_tenants'
);
select throws_ok(
  $$ select public.set_platform_tenant_status(pg_temp.tid('T1'), 'suspended') $$,
  '42501',
  null,
  'tenant superadmin cannot change tenant status'
);

-- ---------------------------------------------------------------------------
-- 3. Platform Admin: Access & Metrics
-- ---------------------------------------------------------------------------
select pg_temp.login('T1', 'sysadmin');

-- 3.1 get_my_access returns is_platform_admin = true
select is(
  (public.get_my_access() ->> 'is_platform_admin')::boolean,
  true,
  'get_my_access identifies platform admin'
);

-- 3.2 get_platform_metrics
select ok(
  (public.get_platform_metrics() ->> 'total_tenants')::int >= 2,
  'get_platform_metrics returns total_tenants count'
);

select is(
  (public.get_platform_metrics() -> 'storage' ->> 'ok')::boolean,
  true,
  'get_platform_metrics embeds storage health info'
);

-- 3.3 list_platform_tenants
select ok(
  jsonb_array_length(public.list_platform_tenants()) >= 2,
  'list_platform_tenants returns all tenants'
);

-- 3.4 Filter by status
select is(
  jsonb_array_length(public.list_platform_tenants(null, 'suspended')),
  1,
  'list_platform_tenants filters by status suspended'
);

-- 3.5 Filter by search
select is(
  (public.list_platform_tenants('store-two') -> 0 ->> 'slug'),
  'store-two',
  'list_platform_tenants filters by search keyword'
);

-- ---------------------------------------------------------------------------
-- 4. Status Modification & Auditing
-- ---------------------------------------------------------------------------
select is(
  (public.set_platform_tenant_status(pg_temp.tid('T1'), 'suspended', 'Non-payment') ->> 'status'),
  'suspended',
  'platform admin can suspend a tenant'
);

select is(
  (select status from public.tenants where id = pg_temp.tid('T1')),
  'suspended',
  'tenant status updated in database'
);

select is(
  (select count(*)::int from public.audit_log where action = 'platform.tenant_status' and entity_id = pg_temp.tid('T1')),
  1,
  'audit log recorded for platform.tenant_status'
);

-- ---------------------------------------------------------------------------
-- 5. Plan & Limits Modification
-- ---------------------------------------------------------------------------
select is(
  (public.set_platform_tenant_plan(
    pg_temp.tid('T1'),
    'pro',
    jsonb_build_object('max_locations', 50, 'max_users', 200)
  ) ->> 'plan'),
  'pro',
  'platform admin can upgrade tenant plan to pro'
);

select is(
  (select max_locations from public.tenant_limits where tenant_id = pg_temp.tid('T1')),
  50,
  'tenant limits updated in database'
);

select is(
  (select count(*)::int from public.audit_log where action = 'platform.tenant_plan' and entity_id = pg_temp.tid('T1')),
  1,
  'audit log recorded for platform.tenant_plan'
);

rollback;
