-- P1-05 admin RPCs: allowed and refused paths, business rules, audit trail.
begin;
select plan(56);

create function pg_temp.login(p_user uuid, p_tenant uuid default null, p_role text default 'authenticated')
returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    jsonb_strip_nulls(jsonb_build_object('sub', p_user, 'role', p_role, 'tenant_id', p_tenant))::text,
    true);
$$;

-- ids
create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.l(p text) returns uuid language sql immutable as $$ select md5('l:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;

-- ---------------------------------------------------------------------------
-- Fixtures: tenant A (pos only), tenant B, suspended tenant C
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
select pg_temp.u(n), n || '@test.invalid'
from unnest(array['owner', 'maria', 'juan', 'carla', 'pedro', 'ownerB', 'ownerC', 'newowner', 'operator']) n;

insert into public.platform_admins (user_id) values (pg_temp.u('operator'));

insert into public.tenants (id, name, slug, base_currency, status) values
  (pg_temp.t('A'), 'Tenant A', 'tenant-a', 'PHP', 'active'),
  (pg_temp.t('B'), 'Tenant B', 'tenant-b', 'USD', 'active'),
  (pg_temp.t('C'), 'Tenant C', 'tenant-c', 'PHP', 'suspended');
insert into public.tenant_modules (tenant_id, pos, warehouse) values
  (pg_temp.t('A'), true, false), (pg_temp.t('B'), true, false), (pg_temp.t('C'), true, false);
insert into public.tenant_settings (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B')), (pg_temp.t('C'));
insert into public.tenant_limits (tenant_id, max_locations) values
  (pg_temp.t('A'), 10), (pg_temp.t('B'), 10), (pg_temp.t('C'), 10);

insert into public.profiles (user_id, tenant_id, username, role) values
  (pg_temp.u('owner'),  pg_temp.t('A'), 'owner', 'superadmin'),
  (pg_temp.u('maria'),  pg_temp.t('A'), 'maria', 'admin'),
  (pg_temp.u('juan'),   pg_temp.t('A'), 'juan', 'cashier'),
  (pg_temp.u('carla'),  pg_temp.t('A'), 'carla', 'cashier'),
  (pg_temp.u('pedro'),  pg_temp.t('A'), 'pedro', 'warehouse'),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin'),
  (pg_temp.u('ownerC'), pg_temp.t('C'), 'owner', 'superadmin');

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.l('S01'), pg_temp.t('A'), 'store', 'S01', 'Store 1'),
  (pg_temp.l('S02'), pg_temp.t('A'), 'store', 'S02', 'Store 2'),
  (pg_temp.l('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'Warehouse 1');

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.l('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('maria'), pg_temp.l('S02'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'),  pg_temp.l('S01'), pg_temp.t('A'), null),
  (pg_temp.u('carla'), pg_temp.l('S02'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.l('W01'), pg_temp.t('A'), null);

-- ---------------------------------------------------------------------------
-- provision_tenant
-- ---------------------------------------------------------------------------
select pg_temp.login(pg_temp.u('owner'), pg_temp.t('A'));
set local role authenticated;
select throws_ok(
  $$ select public.provision_tenant('X', 'x-co', 'PHP', md5('u:newowner')::uuid, 'boss') $$,
  '42501', null, 'tenant superadmin cannot provision tenants');
reset role;

select pg_temp.login(null, null, 'service_role');
set local role service_role;
select throws_ok(
  $$ select public.provision_tenant('X', 'x-co', 'PHP', md5('u:newowner')::uuid, 'boss', 'everything') $$,
  '22023', null, 'unknown preset is rejected');
select lives_ok(
  $$ select public.provision_tenant('New Co', 'new-co', 'php', md5('u:newowner')::uuid, 'boss', 'pos', 'Asia/Manila') $$,
  'service role provisions a tenant');
select throws_ok(
  $$ select public.provision_tenant('Again', 'again-co', 'PHP', md5('u:newowner')::uuid, 'boss') $$,
  'P0001', null, 'an owner cannot belong to two tenants');
reset role;

select is(
  (select row(t.base_currency, t.timezone, m.inventory, m.pos, m.warehouse)::text
   from public.tenants t join public.tenant_modules m on m.tenant_id = t.id where t.slug = 'new-co'),
  row('PHP', 'Asia/Manila', true, true, false)::text,
  'provisioned tenant has base currency, timezone and preset modules');
select is(
  (select p.role from public.profiles p where p.user_id = pg_temp.u('newowner')),
  'superadmin', 'owner is linked as superadmin');
select ok(
  exists (select 1 from public.tenant_settings s join public.tenants t on t.id = s.tenant_id where t.slug = 'new-co')
  and exists (select 1 from public.tenant_limits l join public.tenants t on t.id = l.tenant_id where t.slug = 'new-co'),
  'provisioning creates settings and limits');
select ok(
  exists (select 1 from public.audit_log a join public.tenants t on t.id = a.tenant_id
          where t.slug = 'new-co' and a.action = 'tenant.provision'),
  'provisioning is audited');

select pg_temp.login(pg_temp.u('operator'), null);
set local role authenticated;
select lives_ok(
  $$ select public.provision_tenant('Op Co', 'op-co', 'USD', md5('u:operator')::uuid, 'operator', 'all') $$,
  'a platform admin can provision through the RPC');
reset role;

-- ---------------------------------------------------------------------------
-- Setup and modules
-- ---------------------------------------------------------------------------
select pg_temp.login(pg_temp.u('maria'), pg_temp.t('A'));
set local role authenticated;
select throws_ok($$ select public.set_modules(true, true) $$, '42501', null, 'admin cannot change modules');
select throws_ok(
  $$ select public.complete_setup('A', 'PHP', 'UTC', 'inclusive', 'en', '{en}', true, false) $$,
  '42501', null, 'admin cannot run setup');
reset role;

select pg_temp.login(pg_temp.u('owner'), pg_temp.t('A'));
set local role authenticated;
select throws_ok(
  $$ select public.upsert_location(md5('l:W02')::uuid, 'warehouse', 'W02', 'Warehouse 2') $$,
  '42501', null, 'warehouse location refused while the warehouse module is off');
select lives_ok(
  $$ select public.complete_setup('Tenant A Retail', 'PHP', 'Asia/Manila', 'inclusive', 'fil', '{en,fil}', true, true) $$,
  'superadmin completes setup');
select throws_ok(
  $$ select public.complete_setup('Tenant A Retail', 'USD', 'Asia/Manila', 'inclusive', 'fil', '{en,fil}', true, true) $$,
  'P0001', 'base currency cannot change after setup', 'base currency is fixed after setup');
reset role;

select is(
  (select row(t.name, t.timezone, t.setup_completed_at is not null, s.default_locale, m.warehouse)::text
   from public.tenants t
   join public.tenant_settings s on s.tenant_id = t.id
   join public.tenant_modules m on m.tenant_id = t.id
   where t.id = pg_temp.t('A')),
  row('Tenant A Retail', 'Asia/Manila', true, 'fil', true)::text,
  'setup stores name, timezone, locale and modules');

select pg_temp.login(pg_temp.u('owner'), pg_temp.t('A'));
set local role authenticated;
select lives_ok($$ select public.set_modules(false, true) $$, 'superadmin turns POS off');
reset role;
select is(
  (select row(inventory, pos, warehouse)::text from public.tenant_modules where tenant_id = pg_temp.t('A')),
  row(true, false, true)::text, 'inventory stays on when add-ons change');
select is(
  (select meta -> 'before' ->> 'pos' from public.audit_log
   where tenant_id = pg_temp.t('A') and action = 'modules.set' order by created_at desc, id desc limit 1),
  'true', 'module change audits the previous state');

-- ---------------------------------------------------------------------------
-- Locations
-- ---------------------------------------------------------------------------
select pg_temp.login(pg_temp.u('owner'), pg_temp.t('A'));
set local role authenticated;
select lives_ok(
  $$ select public.upsert_location(md5('l:S03')::uuid, 'store', 'S03', 'Store 3', 'Main St') $$,
  'superadmin creates a store with a client-generated id');
select lives_ok(
  $$ select public.upsert_location(md5('l:W02')::uuid, 'warehouse', 'W02', 'Warehouse 2', null, true) $$,
  'warehouse with bins once the module is on');
select throws_ok(
  $$ select public.upsert_location(md5('l:S99')::uuid, 'store', 'S01', 'Duplicate code') $$,
  '23505', null, 'location codes stay unique per tenant');
select throws_ok(
  $$ select public.upsert_location(md5('l:S03')::uuid, 'warehouse', 'S03', 'Now a warehouse') $$,
  'P0001', 'location type cannot change', 'location type is fixed');
select lives_ok(
  $$ select public.upsert_location(md5('l:S03')::uuid, 'store', 'S03', 'Store 3 Renamed') $$,
  'same id updates the location');
reset role;

update public.tenant_limits set max_locations = 5 where tenant_id = pg_temp.t('A');
select pg_temp.login(pg_temp.u('owner'), pg_temp.t('A'));
set local role authenticated;
select throws_ok(
  $$ select public.upsert_location(md5('l:S04')::uuid, 'store', 'S04', 'Store 4') $$,
  'P0001', null, 'location limit is enforced');
reset role;

select pg_temp.login(pg_temp.u('ownerB'), pg_temp.t('B'));
set local role authenticated;
select throws_ok(
  $$ select public.upsert_location(md5('l:S01')::uuid, 'store', 'S01', 'Hijack') $$,
  '42501', null, 'another tenant cannot overwrite a location by id');
reset role;

select pg_temp.login(pg_temp.u('maria'), pg_temp.t('A'));
set local role authenticated;
select throws_ok(
  $$ select public.upsert_location(md5('l:S05')::uuid, 'store', 'S05', 'Store 5') $$,
  '42501', null, 'admin cannot create locations');
reset role;

-- ---------------------------------------------------------------------------
-- Assignments: manager may place cashiers in stores they manage, nothing else
-- ---------------------------------------------------------------------------
select pg_temp.login(pg_temp.u('maria'), pg_temp.t('A'));
set local role authenticated;
select lives_ok(
  $$ select public.assign_location(md5('u:carla')::uuid, md5('l:S01')::uuid) $$,
  'manager assigns a cashier to the store they manage');
select throws_ok(
  $$ select public.assign_location(md5('u:juan')::uuid, md5('l:S02')::uuid) $$,
  '42501', null, 'supervisor cannot assign cashiers in that store');
select throws_ok(
  $$ select public.assign_location(md5('u:pedro')::uuid, md5('l:S01')::uuid) $$,
  '42501', null, 'manager cannot assign non-cashiers');
select throws_ok(
  $$ select public.assign_location(md5('u:juan')::uuid, md5('l:S01')::uuid, 'supervisor') $$,
  '42501', null, 'manager cannot hand out positions');
select lives_ok(
  $$ select public.revoke_location(md5('u:carla')::uuid, md5('l:S01')::uuid) $$,
  'manager revokes the cashier again');
reset role;

select ok(
  (select deleted_at is not null from public.location_access
   where user_id = pg_temp.u('carla') and location_id = pg_temp.l('S01')),
  'revoke is a soft delete');

select pg_temp.login(pg_temp.u('maria'), pg_temp.t('A'));
set local role authenticated;
select lives_ok(
  $$ select public.assign_location(md5('u:carla')::uuid, md5('l:S01')::uuid) $$,
  'reassigning restores the assignment');
reset role;
select ok(
  (select deleted_at is null from public.location_access
   where user_id = pg_temp.u('carla') and location_id = pg_temp.l('S01')),
  'restored assignment is live again');

select pg_temp.login(pg_temp.u('owner'), pg_temp.t('A'));
set local role authenticated;
select lives_ok(
  $$ select public.assign_location(md5('u:maria')::uuid, md5('l:S03')::uuid, 'manager') $$,
  'superadmin assigns an admin with a position');
select throws_ok(
  $$ select public.assign_location(md5('u:juan')::uuid, md5('l:W01')::uuid) $$,
  '23514', null, 'role / location type rules still apply to superadmins');
reset role;

select pg_temp.login(pg_temp.u('ownerB'), pg_temp.t('B'));
set local role authenticated;
select throws_ok(
  $$ select public.assign_location(md5('u:juan')::uuid, md5('l:S01')::uuid) $$,
  '42501', 'user not found', 'another tenant''s superadmin cannot touch tenant A users');
reset role;

-- ---------------------------------------------------------------------------
-- Activation
-- ---------------------------------------------------------------------------
select pg_temp.login(pg_temp.u('maria'), pg_temp.t('A'));
set local role authenticated;
select lives_ok(
  $$ select public.set_user_active(md5('u:juan')::uuid, false) $$,
  'manager deactivates a cashier in their store');
select throws_ok(
  $$ select public.set_user_active(md5('u:pedro')::uuid, false) $$,
  '42501', null, 'manager cannot deactivate warehouse staff');
select throws_ok(
  $$ select public.set_user_active(md5('u:owner')::uuid, false) $$,
  '42501', null, 'manager cannot deactivate the owner');
reset role;

select pg_temp.login(pg_temp.u('juan'), pg_temp.t('A'));
set local role authenticated;
select throws_ok($$ select public.get_my_access() $$, '42501', null, 'deactivated user is refused by RPCs');
reset role;

select pg_temp.login(pg_temp.u('owner'), pg_temp.t('A'));
set local role authenticated;
select throws_ok(
  $$ select public.set_user_active(md5('u:owner')::uuid, false) $$,
  'P0001', null, 'nobody deactivates themselves');
reset role;

-- ---------------------------------------------------------------------------
-- Roles and the last superadmin
-- ---------------------------------------------------------------------------
select pg_temp.login(pg_temp.u('maria'), pg_temp.t('A'));
set local role authenticated;
select throws_ok($$ select public.set_user_role(md5('u:juan')::uuid, 'admin') $$, '42501', null, 'admin cannot change roles');
reset role;

select pg_temp.login(pg_temp.u('owner'), pg_temp.t('A'));
set local role authenticated;
select throws_ok(
  $$ select public.set_user_role(md5('u:owner')::uuid, 'admin') $$,
  'P0001', 'a tenant must keep at least one active superadmin', 'the last superadmin cannot be demoted');
select lives_ok(
  $$ select public.set_user_role(md5('u:pedro')::uuid, 'superadmin') $$,
  'superadmin promotes a warehouse user');
reset role;

select ok(
  not exists (select 1 from public.location_access where user_id = pg_temp.u('pedro') and deleted_at is null),
  'role change ends the old assignments');

select pg_temp.login(pg_temp.u('owner'), pg_temp.t('A'));
set local role authenticated;
select lives_ok(
  $$ select public.set_user_role(md5('u:owner')::uuid, 'admin') $$,
  'with a second superadmin, the owner may step down');
reset role;

-- ---------------------------------------------------------------------------
-- Suspended tenant, get_my_access, archive, audit
-- ---------------------------------------------------------------------------
select pg_temp.login(pg_temp.u('ownerC'), pg_temp.t('C'));
set local role authenticated;
select throws_ok($$ select public.set_modules(true, true) $$, '42501', 'tenant is suspended', 'suspended tenant cannot write');
select is(public.get_my_access() -> 'tenant' ->> 'status', 'suspended', 'suspended tenant can still read its access');
reset role;

select pg_temp.login(pg_temp.u('maria'), pg_temp.t('A'));
set local role authenticated;
select is(
  (select jsonb_object_agg(x ->> 'code', x ->> 'position')
   from jsonb_array_elements(public.get_my_access() -> 'locations') x),
  '{"S01": "manager", "S02": "supervisor", "S03": "manager"}'::jsonb,
  'get_my_access returns the per-store positions');
reset role;

-- Locale: the user's own choice wins, else the tenant default, else 'en' (the client applies this after sign-in)
update public.profiles set locale = null where user_id = pg_temp.u('maria');
select pg_temp.login(pg_temp.u('maria'), pg_temp.t('A'));
set local role authenticated;
select is(
  public.get_my_access() ->> 'locale',
  (select s.default_locale from public.tenant_settings s where s.tenant_id = pg_temp.t('A')),
  'get_my_access falls back to the tenant default locale');
select lives_ok(
  $$ update public.profiles set locale = 'fil' where user_id = auth.uid() $$,
  'a user may save their own locale');
select is(public.get_my_access() ->> 'locale', 'fil', 'the saved profile locale wins over the tenant default');
reset role;

select pg_temp.login(pg_temp.u('pedro'), pg_temp.t('A'));
set local role authenticated;
select lives_ok($$ select public.archive_location(md5('l:S03')::uuid) $$, 'superadmin archives a store');
reset role;
select ok(
  not exists (select 1 from public.location_access where location_id = pg_temp.l('S03') and deleted_at is null),
  'archiving ends assignments at that store');

select is(
  (select array_agg(distinct action order by action) from public.audit_log where tenant_id = pg_temp.t('A')),
  array['access.assign', 'access.revoke', 'location.archive', 'location.create', 'location.update',
        'modules.set', 'role.change', 'tenant.setup', 'user.deactivate']::text[],
  'every kind of change left an audit row');

select * from finish();
rollback;
