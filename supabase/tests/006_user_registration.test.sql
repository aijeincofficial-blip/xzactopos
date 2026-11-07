-- P1-06 admin_register_user: the server-side gate behind the create_user / invite_user Edge Functions.
begin;
select plan(16);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.l(p text) returns uuid language sql immutable as $$ select md5('l:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;

insert into auth.users (id, email)
select pg_temp.u(n), n || '@test.invalid'
from unnest(array['owner', 'maria', 'ana', 'ownerC', 'ownerB',
                  'new1', 'new2', 'new3', 'new4', 'new5', 'new6', 'new7', 'new8']) n;

insert into public.tenants (id, name, slug, base_currency, status) values
  (pg_temp.t('A'), 'Tenant A', 'tenant-a', 'PHP', 'active'),
  (pg_temp.t('B'), 'Tenant B', 'tenant-b', 'PHP', 'active'),
  (pg_temp.t('C'), 'Tenant C', 'tenant-c', 'PHP', 'suspended');
insert into public.tenant_limits (tenant_id, max_users) values
  (pg_temp.t('A'), 6), (pg_temp.t('B'), 10), (pg_temp.t('C'), 10);

insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'),  pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'),  pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('ana'),    pg_temp.t('A'), 'ana', 'superadmin', false),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true),
  (pg_temp.u('ownerC'), pg_temp.t('C'), 'owner', 'superadmin', true);

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.l('S01'), pg_temp.t('A'), 'store', 'S01', 'Store 1'),
  (pg_temp.l('S02'), pg_temp.t('A'), 'store', 'S02', 'Store 2'),
  (pg_temp.l('B01'), pg_temp.t('B'), 'store', 'S01', 'Store B1');

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.l('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('maria'), pg_temp.l('S02'), pg_temp.t('A'), 'supervisor');

-- Signed-in users can never call it directly.
select set_config('request.jwt.claims',
  jsonb_build_object('sub', pg_temp.u('owner'), 'role', 'authenticated', 'tenant_id', pg_temp.t('A'))::text, true);
set local role authenticated;
select throws_ok(
  $$ select public.admin_register_user(md5('u:owner')::uuid, md5('u:new1')::uuid, 'x1', '', 'cashier') $$,
  '42501', null, 'clients cannot call admin_register_user');
reset role;

-- Everything below runs as the Edge Function does: service role.
select set_config('request.jwt.claims', '{"role": "service_role"}', true);
set local role service_role;

select is(
  public.admin_register_user(md5('u:owner')::uuid, md5('u:new1')::uuid, 'juan', 'Juan', 'cashier', 'fil', md5('l:S01')::uuid),
  md5('t:A')::uuid,
  'superadmin creates a cashier assigned to a store');

select lives_ok(
  $$ select public.admin_register_user(md5('u:maria')::uuid, md5('u:new2')::uuid, 'pia', 'Pia', 'cashier', null, md5('l:S01')::uuid) $$,
  'manager creates a cashier in the store they manage');

select throws_ok(
  $$ select public.admin_register_user(md5('u:maria')::uuid, md5('u:new3')::uuid, 'lea', '', 'cashier', null, md5('l:S02')::uuid) $$,
  '42501', 'not allowed to create this user', 'supervisor cannot create cashiers in that store');

select throws_ok(
  $$ select public.admin_register_user(md5('u:maria')::uuid, md5('u:new3')::uuid, 'lea', '', 'cashier') $$,
  '42501', null, 'manager must place the cashier in a store');

select throws_ok(
  $$ select public.admin_register_user(md5('u:maria')::uuid, md5('u:new3')::uuid, 'boss', '', 'admin', null, md5('l:S01')::uuid, 'manager') $$,
  '42501', null, 'manager cannot create admins');

select throws_ok(
  $$ select public.admin_register_user(md5('u:ana')::uuid, md5('u:new3')::uuid, 'lea', '', 'cashier') $$,
  '42501', 'caller is not an active user', 'deactivated caller is refused');

select throws_ok(
  $$ select public.admin_register_user(md5('u:ownerC')::uuid, md5('u:new3')::uuid, 'lea', '', 'cashier') $$,
  '42501', 'tenant is suspended', 'suspended tenant cannot add users');

select throws_ok(
  $$ select public.admin_register_user(md5('u:owner')::uuid, md5('u:new3')::uuid, 'lea', '', 'cashier', null, md5('l:B01')::uuid) $$,
  '42501', 'location not found', 'cannot place a user in another tenant''s store');

select throws_ok(
  $$ select public.admin_register_user(md5('u:owner')::uuid, md5('u:new3')::uuid, 'juan', '', 'cashier') $$,
  '23505', null, 'usernames are unique within the tenant');

select lives_ok(
  $$ select public.admin_register_user(md5('u:ownerB')::uuid, md5('u:new4')::uuid, 'juan', '', 'cashier', null, md5('l:B01')::uuid) $$,
  'the same username is fine in another tenant');

select throws_ok(
  $$ select public.admin_register_user(md5('u:owner')::uuid, md5('u:new5')::uuid, 'wh', '', 'warehouse', null, md5('l:S01')::uuid) $$,
  '23514', null, 'role / location type rules still apply');

select throws_ok(
  $$ select public.admin_register_user(md5('u:owner')::uuid, md5('u:new5')::uuid, 'x', '', 'owner') $$,
  '22023', null, 'unknown role is rejected');

-- tenant A now has 5 profiles (owner, maria, ana, juan, pia); limit is 6
select lives_ok(
  $$ select public.admin_register_user(md5('u:owner')::uuid, md5('u:new6')::uuid, 'sixth', '', 'warehouse') $$,
  'creation allowed up to the user limit');
select throws_ok(
  $$ select public.admin_register_user(md5('u:owner')::uuid, md5('u:new7')::uuid, 'seventh', '', 'cashier') $$,
  'P0001', null, 'user limit is enforced');
reset role;

select is(
  (select count(*)::int from public.audit_log
   where tenant_id = pg_temp.t('A') and action = 'user.create' and user_id in (pg_temp.u('owner'), pg_temp.u('maria'))),
  3,
  'each creation is audited with the real caller');

select * from finish();
rollback;
