-- P1-02 access token hook and RLS helpers.
begin;
select plan(42);

-- Simulate a signed-in request: PostgREST sets request.jwt.claims, auth.uid() reads `sub`.
create function pg_temp.login(p_user uuid, p_tenant uuid default null)
returns void
language sql
as $$
  select set_config(
    'request.jwt.claims',
    jsonb_strip_nulls(jsonb_build_object('sub', p_user, 'role', 'authenticated', 'tenant_id', p_tenant))::text,
    true
  );
$$;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@a.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'maria@a.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'juan@a.test'),
  ('00000000-0000-0000-0000-0000000000a4', 'pedro@a.test'),
  ('00000000-0000-0000-0000-0000000000a5', 'ana@a.test'),
  ('00000000-0000-0000-0000-0000000000b1', 'owner@b.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'owner@c.test'),
  ('00000000-0000-0000-0000-0000000000d1', 'owner@d.test'),
  ('00000000-0000-0000-0000-0000000000f1', 'operator@platform.test');

insert into public.tenants (id, name, slug, base_currency, status) values
  ('10000000-0000-0000-0000-00000000000a', 'Tenant A', 'tenant-a', 'PHP', 'active'),
  ('10000000-0000-0000-0000-00000000000b', 'Tenant B', 'tenant-b', 'USD', 'active'),
  ('10000000-0000-0000-0000-00000000000c', 'Tenant C', 'tenant-c', 'PHP', 'suspended'),
  ('10000000-0000-0000-0000-00000000000d', 'Tenant D', 'tenant-d', 'PHP', 'archived');

insert into public.tenant_modules (tenant_id, pos, warehouse) values
  ('10000000-0000-0000-0000-00000000000a', true, false);

insert into public.profiles (user_id, tenant_id, username, role, active) values
  ('00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', 'owner', 'superadmin', true),
  ('00000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a', 'maria', 'admin', true),
  ('00000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a', 'juan', 'cashier', true),
  ('00000000-0000-0000-0000-0000000000a4', '10000000-0000-0000-0000-00000000000a', 'pedro', 'warehouse', true),
  ('00000000-0000-0000-0000-0000000000a5', '10000000-0000-0000-0000-00000000000a', 'ana', 'cashier', false),
  ('00000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-00000000000b', 'owner', 'superadmin', true),
  ('00000000-0000-0000-0000-0000000000c1', '10000000-0000-0000-0000-00000000000c', 'owner', 'superadmin', true),
  ('00000000-0000-0000-0000-0000000000d1', '10000000-0000-0000-0000-00000000000d', 'owner', 'superadmin', true);

insert into public.platform_admins (user_id) values ('00000000-0000-0000-0000-0000000000f1');

insert into public.locations (id, tenant_id, type, code, name, deleted_at) values
  ('20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', 'store', 'S01', 'Store A1', null),
  ('20000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a', 'store', 'S02', 'Store A2', null),
  ('20000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a', 'warehouse', 'W01', 'Warehouse A1', null),
  ('20000000-0000-0000-0000-0000000000a4', '10000000-0000-0000-0000-00000000000a', 'store', 'S03', 'Closed store', now()),
  ('20000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-00000000000b', 'store', 'S01', 'Store B1', null);

insert into public.location_access (user_id, location_id, tenant_id, position) values
  -- maria: manager in Store A1, supervisor in Store A2
  ('00000000-0000-0000-0000-0000000000a2', '20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', 'manager'),
  ('00000000-0000-0000-0000-0000000000a2', '20000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a', 'supervisor'),
  ('00000000-0000-0000-0000-0000000000a3', '20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', null),
  ('00000000-0000-0000-0000-0000000000a4', '20000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a', null),
  ('00000000-0000-0000-0000-0000000000a5', '20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', null);

-- ---------------------------------------------------------------------------
-- Access token hook
-- ---------------------------------------------------------------------------
select is(
  public.custom_access_token_hook(jsonb_build_object(
    'user_id', '00000000-0000-0000-0000-0000000000a2', 'claims', jsonb_build_object('sub', '00000000-0000-0000-0000-0000000000a2')
  )) -> 'claims' ->> 'tenant_id',
  '10000000-0000-0000-0000-00000000000a',
  'hook adds tenant_id'
);

select is(
  public.custom_access_token_hook(jsonb_build_object(
    'user_id', '00000000-0000-0000-0000-0000000000a2', 'claims', '{}'::jsonb
  )) -> 'claims' ->> 'user_role',
  'admin',
  'hook adds user_role'
);

select is(
  public.custom_access_token_hook(jsonb_build_object(
    'user_id', '00000000-0000-0000-0000-0000000000c1', 'claims', '{}'::jsonb
  )) -> 'claims' ->> 'tenant_status',
  'suspended',
  'hook adds tenant_status'
);

select is(
  public.custom_access_token_hook(jsonb_build_object(
    'user_id', '00000000-0000-0000-0000-0000000000a5', 'claims', '{}'::jsonb
  )) -> 'claims' ->> 'user_active',
  'false',
  'hook reports deactivated users'
);

select ok(
  (select c ? 'tenant_id' = false and c ->> 'platform_admin' = 'true'
   from (select public.custom_access_token_hook(jsonb_build_object(
     'user_id', '00000000-0000-0000-0000-0000000000f1',
     'claims', jsonb_build_object('tenant_id', '10000000-0000-0000-0000-00000000000b', 'user_role', 'superadmin')
   )) -> 'claims' as c) s),
  'hook strips spoofed claims and flags platform admins'
);

-- ---------------------------------------------------------------------------
-- Admin with different positions in two stores
-- ---------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a');
set local role authenticated;

select is(public.auth_tenant_id(), '10000000-0000-0000-0000-00000000000a'::uuid, 'admin resolves own tenant');
select is(public.auth_role(), 'admin', 'admin role read live');
select ok(not public.is_superadmin(), 'admin is not superadmin');
select ok(public.has_location_access('20000000-0000-0000-0000-0000000000a1'), 'admin has Store A1');
select ok(public.has_location_access('20000000-0000-0000-0000-0000000000a1', 'manager'), 'admin is manager in Store A1');
select ok(public.has_location_access('20000000-0000-0000-0000-0000000000a2'), 'admin has Store A2');
select ok(not public.has_location_access('20000000-0000-0000-0000-0000000000a2', 'manager'), 'admin is not manager in Store A2');
select ok(public.has_location_access('20000000-0000-0000-0000-0000000000a2', 'supervisor'), 'admin is supervisor in Store A2');
select ok(not public.has_location_access('20000000-0000-0000-0000-0000000000a3'), 'admin has no warehouse access');
select ok(not public.has_location_access('20000000-0000-0000-0000-0000000000b1'), 'admin cannot reach another tenant''s store');
select is(
  (select array(select unnest(public.auth_location_ids()) order by 1)),
  array['20000000-0000-0000-0000-0000000000a1', '20000000-0000-0000-0000-0000000000a2']::uuid[],
  'auth_location_ids lists exactly the assigned stores'
);
select throws_ok(
  $$ select public.has_location_access('20000000-0000-0000-0000-0000000000a1', 'owner') $$,
  '22023', null,
  'unknown position is rejected'
);
select lives_ok($$ select public.assert_module('pos') $$, 'POS module enabled');
select lives_ok($$ select public.assert_module('inventory') $$, 'inventory module enabled');
select throws_ok($$ select public.assert_module('warehouse') $$, '42501', null, 'warehouse module disabled is refused');
select throws_ok($$ select public.assert_module('bogus') $$, '22023', null, 'unknown module is rejected');
reset role;

-- ---------------------------------------------------------------------------
-- Superadmin: every live location of own tenant only
-- ---------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a');
set local role authenticated;
select ok(public.is_superadmin(), 'owner is superadmin');
select ok(public.has_location_access('20000000-0000-0000-0000-0000000000a3', 'manager'), 'superadmin passes any position check');
select ok(not public.has_location_access('20000000-0000-0000-0000-0000000000a4'), 'soft-deleted location is not accessible');
select ok(not public.has_location_access('20000000-0000-0000-0000-0000000000b1'), 'superadmin cannot reach another tenant');
select is(cardinality(public.auth_location_ids()), 3, 'superadmin sees the 3 live locations');
reset role;

-- ---------------------------------------------------------------------------
-- Cashier and warehouse
-- ---------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a');
set local role authenticated;
select ok(public.has_location_access('20000000-0000-0000-0000-0000000000a1'), 'cashier has own store');
select ok(not public.has_location_access('20000000-0000-0000-0000-0000000000a1', 'supervisor'), 'cashier holds no position');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a4', '10000000-0000-0000-0000-00000000000a');
set local role authenticated;
select ok(public.has_location_access('20000000-0000-0000-0000-0000000000a3'), 'warehouse user has own warehouse');
reset role;

-- ---------------------------------------------------------------------------
-- Refusals: spoofed tenant, missing claim, deactivated user, suspended and archived tenants
-- ---------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000b');
set local role authenticated;
select is(public.auth_tenant_id(), null, 'tenant claim that does not match the profile resolves to nothing');
select ok(not public.has_location_access('20000000-0000-0000-0000-0000000000b1'), 'spoofed tenant claim grants no access');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a2');
set local role authenticated;
select is(public.auth_tenant_id(), null, 'token without the hook claim resolves to nothing');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a5', '10000000-0000-0000-0000-00000000000a');
set local role authenticated;
select is(public.auth_tenant_id(), null, 'deactivated user resolves to nothing');
select throws_ok($$ select public.assert_active_user() $$, '42501', null, 'deactivated user is refused');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000c1', '10000000-0000-0000-0000-00000000000c');
set local role authenticated;
select is(public.auth_tenant_id(), '10000000-0000-0000-0000-00000000000c'::uuid, 'suspended tenant can still read (export)');
select ok(not public.is_active_user(), 'suspended tenant is not active');
select throws_ok($$ select public.assert_active_user() $$, '42501', 'tenant is suspended', 'suspended tenant cannot write');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000d1', '10000000-0000-0000-0000-00000000000d');
set local role authenticated;
select is(public.auth_tenant_id(), null, 'archived tenant resolves to nothing');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok($$ select public.assert_module('inventory') $$, '42501', null, 'tenant without a modules row is refused');
reset role;

-- Deactivation takes effect immediately, without waiting for a token refresh.
update public.profiles set active = false where user_id = '00000000-0000-0000-0000-0000000000a2';
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a');
set local role authenticated;
select ok(not public.has_location_access('20000000-0000-0000-0000-0000000000a1'), 'deactivation revokes location access immediately');
reset role;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
set local role anon;
select throws_ok($$ select public.auth_tenant_id() $$, '42501', null, 'anon cannot call helpers');
reset role;

set local role authenticated;
select throws_ok(
  $$ select public.custom_access_token_hook('{}'::jsonb) $$,
  '42501', null,
  'signed-in users cannot call the token hook'
);
reset role;

select * from finish();
rollback;
