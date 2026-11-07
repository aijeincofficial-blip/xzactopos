-- P1-01 core tenancy schema: structure, constraints and triggers.
begin;
select plan(38);

-- ---------------------------------------------------------------------------
-- Tables exist and RLS is enabled on every one
-- ---------------------------------------------------------------------------
select has_table('public', t, t || ' exists')
from unnest(array[
  'currencies', 'tenants', 'tenant_modules', 'tenant_settings', 'tenant_limits', 'tenant_currencies',
  'platform_admins', 'profiles', 'locations', 'location_access', 'audit_log'
]) as t;

select is(
  (select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity),
  0,
  'every table in public has RLS enabled'
);

-- ---------------------------------------------------------------------------
-- Fixtures: two tenants that reuse the same business keys
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@a.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'admin@a.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'cashier@a.test'),
  ('00000000-0000-0000-0000-0000000000a4', 'wh@a.test'),
  ('00000000-0000-0000-0000-0000000000b1', 'owner@b.test');

insert into public.tenants (id, name, slug, base_currency) values
  ('10000000-0000-0000-0000-00000000000a', 'Tenant A', 'tenant-a', 'PHP'),
  ('10000000-0000-0000-0000-00000000000b', 'Tenant B', 'tenant-b', 'USD');

insert into public.profiles (user_id, tenant_id, username, role) values
  ('00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', 'owner', 'superadmin'),
  ('00000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a', 'maria', 'admin'),
  ('00000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a', 'juan', 'cashier'),
  ('00000000-0000-0000-0000-0000000000a4', '10000000-0000-0000-0000-00000000000a', 'pedro', 'warehouse');

insert into public.locations (id, tenant_id, type, code, name) values
  ('20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', 'store', 'S01', 'Store A1'),
  ('20000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a', 'warehouse', 'W01', 'Warehouse A1'),
  ('20000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-00000000000b', 'store', 'S01', 'Store B1');

-- ---------------------------------------------------------------------------
-- Business keys are unique per tenant, never globally
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ insert into public.profiles (user_id, tenant_id, username, role)
     values ('00000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-00000000000b', 'owner', 'superadmin') $$,
  'same username allowed in another tenant'
);

select throws_ok(
  $$ insert into public.locations (tenant_id, type, code, name)
     values ('10000000-0000-0000-0000-00000000000a', 'store', 'S01', 'Duplicate') $$,
  '23505', null,
  'location code is unique within a tenant'
);

select throws_ok(
  $$ insert into public.tenants (name, slug, base_currency) values ('Dup', 'tenant-a', 'PHP') $$,
  '23505', null,
  'tenant slug is globally unique (it is the login namespace)'
);

select throws_ok(
  $$ insert into public.tenants (name, slug, base_currency) values ('Bad', 'Bad Slug', 'PHP') $$,
  '23514', null,
  'slug format is enforced'
);

select throws_ok(
  $$ insert into public.tenants (name, slug, base_currency) values ('Bad', 'bad-ccy', 'XXX') $$,
  '23503', null,
  'base currency must exist in currencies'
);

-- ---------------------------------------------------------------------------
-- Modules: inventory is always on; add-ons are optional
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ insert into public.tenant_modules (tenant_id, pos, warehouse)
     values ('10000000-0000-0000-0000-00000000000a', true, true) $$,
  'tenant can enable POS and Warehouse'
);

select throws_ok(
  $$ update public.tenant_modules set inventory = false
     where tenant_id = '10000000-0000-0000-0000-00000000000a' $$,
  '23514', null,
  'inventory cannot be turned off'
);

select throws_ok(
  $$ insert into public.tenant_modules (tenant_id, inventory, pos)
     values ('10000000-0000-0000-0000-00000000000b', false, true) $$,
  '23514', null,
  'POS without inventory is rejected'
);

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.tenant_settings (tenant_id, default_locale, locales)
     values ('10000000-0000-0000-0000-00000000000a', 'fil', '{en}') $$,
  '23514', null,
  'default locale must be one of the enabled locales'
);

select lives_ok(
  $$ insert into public.tenant_settings (tenant_id, default_locale, locales)
     values ('10000000-0000-0000-0000-00000000000a', 'fil', '{en,fil}') $$,
  'Tagalog default with both locales enabled'
);

-- ---------------------------------------------------------------------------
-- Location access rules
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ insert into public.location_access (user_id, location_id, tenant_id, position)
     values ('00000000-0000-0000-0000-0000000000a2', '20000000-0000-0000-0000-0000000000a1',
             '10000000-0000-0000-0000-00000000000a', 'manager') $$,
  'admin assigned to a store as manager'
);

select throws_ok(
  $$ insert into public.location_access (user_id, location_id, tenant_id)
     values ('00000000-0000-0000-0000-0000000000a2', '20000000-0000-0000-0000-0000000000a2',
             '10000000-0000-0000-0000-00000000000a') $$,
  '23514', null,
  'admin cannot be assigned to a warehouse'
);

select throws_ok(
  $$ update public.location_access set position = null
     where user_id = '00000000-0000-0000-0000-0000000000a2' $$,
  '23514', null,
  'admin assignment requires a position'
);

select lives_ok(
  $$ insert into public.location_access (user_id, location_id, tenant_id)
     values ('00000000-0000-0000-0000-0000000000a3', '20000000-0000-0000-0000-0000000000a1',
             '10000000-0000-0000-0000-00000000000a') $$,
  'cashier assigned to a store'
);

select throws_ok(
  $$ insert into public.location_access (user_id, location_id, tenant_id, position)
     values ('00000000-0000-0000-0000-0000000000a3', '20000000-0000-0000-0000-0000000000a1',
             '10000000-0000-0000-0000-00000000000a', 'supervisor')
     on conflict (user_id, location_id) do update set position = excluded.position $$,
  '23514', null,
  'cashier cannot hold a position'
);

select lives_ok(
  $$ insert into public.location_access (user_id, location_id, tenant_id)
     values ('00000000-0000-0000-0000-0000000000a4', '20000000-0000-0000-0000-0000000000a2',
             '10000000-0000-0000-0000-00000000000a') $$,
  'warehouse user assigned to a warehouse'
);

select throws_ok(
  $$ insert into public.location_access (user_id, location_id, tenant_id)
     values ('00000000-0000-0000-0000-0000000000a4', '20000000-0000-0000-0000-0000000000a1',
             '10000000-0000-0000-0000-00000000000a') $$,
  '23514', null,
  'warehouse user cannot be assigned to a store'
);

select throws_ok(
  $$ insert into public.location_access (user_id, location_id, tenant_id)
     values ('00000000-0000-0000-0000-0000000000a1', '20000000-0000-0000-0000-0000000000a1',
             '10000000-0000-0000-0000-00000000000a') $$,
  '23514', null,
  'superadmin is never assigned (implicit access)'
);

select throws_ok(
  $$ insert into public.location_access (user_id, location_id, tenant_id)
     values ('00000000-0000-0000-0000-0000000000a3', '20000000-0000-0000-0000-0000000000b1',
             '10000000-0000-0000-0000-00000000000a') $$,
  '23503', null,
  'cannot assign a location from another tenant'
);

select throws_ok(
  $$ insert into public.locations (tenant_id, type, code, name, bins_enabled)
     values ('10000000-0000-0000-0000-00000000000a', 'store', 'S99', 'Binned store', true) $$,
  '23514', null,
  'bins only on warehouses'
);

-- ---------------------------------------------------------------------------
-- Triggers: tenant_id immutable, updated_at server-set
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ update public.locations set tenant_id = '10000000-0000-0000-0000-00000000000b'
     where id = '20000000-0000-0000-0000-0000000000a1' $$,
  '23514', 'tenant_id is immutable',
  'rows cannot move to another tenant'
);

update public.locations
  set updated_at = '2000-01-01', name = 'Store A1 renamed'
  where id = '20000000-0000-0000-0000-0000000000a1';

select ok(
  (select updated_at > '2001-01-01' from public.locations where id = '20000000-0000-0000-0000-0000000000a1'),
  'updated_at is set by the server, not the client'
);

-- ---------------------------------------------------------------------------
-- Audit log and UUIDv7
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.audit_log (tenant_id, action, entity, meta)
     values ('10000000-0000-0000-0000-00000000000a', 'x', 'y',
             jsonb_build_object('blob', repeat('z', 5000))) $$,
  '23514', null,
  'audit meta must stay small'
);

select is(
  substring(public.uuid_generate_v7()::text from 15 for 1),
  '7',
  'uuid_generate_v7 produces version 7'
);

select ok(
  (select bool_and(substring(u::text from 20 for 1) in ('8', '9', 'a', 'b'))
   from (select public.uuid_generate_v7() as u from generate_series(1, 50)) s),
  'uuid_generate_v7 sets the RFC 9562 variant'
);

do $$
begin
  create temp table v7_order (n int, u uuid);
  insert into v7_order values (1, public.uuid_generate_v7());
  perform pg_sleep(0.003);
  insert into v7_order values (2, public.uuid_generate_v7());
end;
$$;

select ok(
  (select (select u from v7_order where n = 1)::text < (select u from v7_order where n = 2)::text),
  'uuid_generate_v7 is time ordered'
);

select * from finish();
rollback;
