-- P1-03 schema guard (fails the build when a table is unprotected) and policy smoke tests.
-- The full per-role, per-table isolation matrix lives in 004 (P1-04).
begin;
select plan(33);

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

-- Guard queries as views so the same check can be re-run against a probe table.
create view pg_temp.tables_without_rls as
  select c.relname
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity;

create view pg_temp.tables_without_tenant_id as
  select c.relname
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p')
    and c.relname not in ('tenants', 'currencies', 'platform_admins')
    and not exists (
      select 1 from pg_attribute a
      where a.attrelid = c.oid and a.attname = 'tenant_id' and not a.attisdropped
    );

create view pg_temp.tenant_tables_without_tenant_index as
  select c.relname
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_attribute a on a.attrelid = c.oid and a.attname = 'tenant_id' and not a.attisdropped
  where n.nspname = 'public' and c.relkind in ('r', 'p')
    and not exists (
      select 1 from pg_index i where i.indrelid = c.oid and i.indkey[0] = a.attnum
    );

-- ---------------------------------------------------------------------------
-- Schema guard
-- ---------------------------------------------------------------------------
select is_empty($$ select * from pg_temp.tables_without_rls $$, 'every public table has RLS enabled');
select is_empty($$ select * from pg_temp.tables_without_tenant_id $$, 'every tenant-owned table has tenant_id');
select is_empty($$ select * from pg_temp.tenant_tables_without_tenant_index $$, 'every tenant_id has a leading index');

select is_empty(
  $$ select table_name, privilege_type from information_schema.role_table_grants
     where grantee = 'anon' and table_schema = 'public' $$,
  'anon has no privileges on any public table'
);

select is_empty(
  $$ select table_name from information_schema.role_table_grants
     where grantee = 'authenticated' and table_schema = 'public' and privilege_type in ('DELETE', 'TRUNCATE') $$,
  'clients can never hard-delete (soft delete only)'
);

select is_empty(
  $$ select p.proname
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
       and has_function_privilege('anon', p.oid, 'execute') $$,
  'anon cannot execute any function in public'
);

select is_empty(
  $$ select p.proname
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prosecdef
       and not exists (select 1 from unnest(p.proconfig) cfg where cfg like 'search_path=%') $$,
  'every SECURITY DEFINER function pins search_path'
);

-- The guard really catches a careless new table.
create table public.guard_probe (id int);
select is(
  array(select relname::text from pg_temp.tables_without_rls),
  array['guard_probe']::text[],
  'guard flags a new table without RLS'
);
select is(
  array(select relname::text from pg_temp.tables_without_tenant_id),
  array['guard_probe']::text[],
  'guard flags a new table without tenant_id'
);
select is_empty(
  $$ select 1 from information_schema.role_table_grants where grantee = 'anon' and table_name = 'guard_probe' $$,
  'default privileges keep anon off new tables'
);
drop table public.guard_probe;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@a.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'maria@a.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'juan@a.test'),
  ('00000000-0000-0000-0000-0000000000a4', 'pedro@a.test'),
  ('00000000-0000-0000-0000-0000000000a6', 'rosa@a.test'),
  ('00000000-0000-0000-0000-0000000000b1', 'owner@b.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'owner@c.test');

insert into public.tenants (id, name, slug, base_currency, status) values
  ('10000000-0000-0000-0000-00000000000a', 'Tenant A', 'tenant-a', 'PHP', 'active'),
  ('10000000-0000-0000-0000-00000000000b', 'Tenant B', 'tenant-b', 'USD', 'active'),
  ('10000000-0000-0000-0000-00000000000c', 'Tenant C', 'tenant-c', 'PHP', 'suspended');

insert into public.tenant_settings (tenant_id) values
  ('10000000-0000-0000-0000-00000000000a'), ('10000000-0000-0000-0000-00000000000c');
insert into public.tenant_limits (tenant_id) values ('10000000-0000-0000-0000-00000000000a');

insert into public.profiles (user_id, tenant_id, username, role, pin_hash) values
  ('00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', 'owner', 'superadmin', 'hash-owner'),
  ('00000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a', 'maria', 'admin', 'hash-maria'),
  ('00000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a', 'juan', 'cashier', 'hash-juan'),
  ('00000000-0000-0000-0000-0000000000a4', '10000000-0000-0000-0000-00000000000a', 'pedro', 'warehouse', null),
  ('00000000-0000-0000-0000-0000000000a6', '10000000-0000-0000-0000-00000000000a', 'rosa', 'warehouse', null),
  ('00000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-00000000000b', 'owner', 'superadmin', null),
  ('00000000-0000-0000-0000-0000000000c1', '10000000-0000-0000-0000-00000000000c', 'owner', 'superadmin', null);

insert into public.locations (id, tenant_id, type, code, name) values
  ('20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', 'store', 'S01', 'Store A1'),
  ('20000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a', 'store', 'S02', 'Store A2'),
  ('20000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a', 'warehouse', 'W01', 'Warehouse A1'),
  ('20000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-00000000000b', 'store', 'S01', 'Store B1');

insert into public.location_access (user_id, location_id, tenant_id, position) values
  ('00000000-0000-0000-0000-0000000000a2', '20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', 'manager'),
  ('00000000-0000-0000-0000-0000000000a2', '20000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a', 'supervisor'),
  ('00000000-0000-0000-0000-0000000000a3', '20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', null),
  ('00000000-0000-0000-0000-0000000000a4', '20000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a', null),
  ('00000000-0000-0000-0000-0000000000a6', '20000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a', null);

insert into public.audit_log (tenant_id, action, entity, location_id) values
  ('10000000-0000-0000-0000-00000000000a', 'price.change', 'variant', '20000000-0000-0000-0000-0000000000a1'),
  ('10000000-0000-0000-0000-00000000000a', 'price.change', 'variant', '20000000-0000-0000-0000-0000000000a2'),
  ('10000000-0000-0000-0000-00000000000a', 'role.change', 'profile', null);

-- ---------------------------------------------------------------------------
-- Cashier
-- ---------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a');
set local role authenticated;

select is(
  array(select username from public.profiles),
  array['juan']::text[],
  'cashier sees only their own profile'
);
select throws_ok($$ select pin_hash from public.profiles $$, '42501', null, 'pin_hash is never readable by clients');
select lives_ok(
  $$ update public.profiles set full_name = 'Juan dela Cruz' where user_id = '00000000-0000-0000-0000-0000000000a3' $$,
  'cashier can edit own name'
);
select throws_ok(
  $$ update public.profiles set role = 'superadmin' where user_id = '00000000-0000-0000-0000-0000000000a3' $$,
  '42501', null,
  'cashier cannot change own role'
);
select is(
  array(select code from public.locations),
  array['S01']::text[],
  'cashier sees only the assigned store'
);
select is_empty($$ select 1 from public.tenant_limits $$, 'cashier cannot see tenant limits');
select is_empty($$ select 1 from public.audit_log $$, 'cashier cannot see the audit log');
select throws_ok(
  $$ delete from public.locations where id = '20000000-0000-0000-0000-0000000000a1' $$,
  '42501', null,
  'clients cannot delete rows'
);
reset role;

-- ---------------------------------------------------------------------------
-- Warehouse users see colleagues in the same warehouse
-- ---------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a4', '10000000-0000-0000-0000-00000000000a');
set local role authenticated;
select is(
  array(select username from public.profiles order by username),
  array['pedro', 'rosa']::text[],
  'warehouse user sees colleagues at the same warehouse only'
);
reset role;

-- ---------------------------------------------------------------------------
-- Admin (manager in A1, supervisor in A2)
-- ---------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a');
set local role authenticated;
select is(
  array(select username from public.profiles order by username),
  array['juan', 'maria']::text[],
  'admin sees people in their stores, not warehouse staff'
);
select is(
  array(select l.code from public.audit_log a join public.locations l on l.id = a.location_id),
  array['S01']::text[],
  'admin reads audit entries only for stores they manage'
);
select is(
  (select count(*)::int from public.location_access),
  3,
  'admin sees assignments in stores where they are at least supervisor'
);
with u as (update public.tenants set name = 'Hijacked' returning 1)
select is((select count(*)::int from u), 0, 'admin cannot rename the tenant');
select throws_ok(
  $$ insert into public.locations (tenant_id, type, code, name)
     values ('10000000-0000-0000-0000-00000000000a', 'store', 'S09', 'Sneaky') $$,
  '42501', null,
  'locations cannot be created directly (RPC only)'
);
reset role;

-- ---------------------------------------------------------------------------
-- Superadmin
-- ---------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a');
set local role authenticated;
with u as (update public.tenants set name = 'Tenant A Inc' returning 1)
select is((select count(*)::int from u), 1, 'superadmin can rename the tenant');
select throws_ok(
  $$ update public.tenants set status = 'active', plan = 'pro' $$,
  '42501', null,
  'superadmin cannot change plan or status'
);
select throws_ok(
  $$ update public.tenant_modules set warehouse = true $$,
  '42501', null,
  'modules change only through the RPC'
);
select is((select count(*)::int from public.tenant_limits), 1, 'superadmin reads tenant limits');
select is((select count(*)::int from public.audit_log), 3, 'superadmin reads the whole audit log');
select is((select count(*)::int from public.locations), 3, 'superadmin sees every location of the tenant');
reset role;

-- ---------------------------------------------------------------------------
-- Cross-tenant and suspended
-- ---------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-00000000000b');
set local role authenticated;
select is(
  array(select code from public.locations),
  array['S01']::text[], 'tenant B sees only its own S01');
select is_empty(
  $$ select 1 from public.profiles where tenant_id = '10000000-0000-0000-0000-00000000000a' $$,
  'tenant B cannot read tenant A people'
);
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000c1', '10000000-0000-0000-0000-00000000000c');
set local role authenticated;
with u as (update public.tenant_settings set receipt_footer = 'x' returning 1)
select is((select count(*)::int from u), 0, 'suspended tenant cannot edit settings');
reset role;

select * from finish();
rollback;
