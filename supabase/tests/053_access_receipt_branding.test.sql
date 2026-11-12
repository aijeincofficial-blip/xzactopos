-- Receipt branding pass-through in public.get_my_access():
--   1. tenant.receipt_header and tenant.receipt_footer reflect public.tenant_settings
--   2. locations[i].address reflects public.locations.address
--   3. Assigned cashiers also receive their store's address and tenant receipt branding

begin;
select plan(6);

create temp table ids (key text primary key, id uuid);

insert into ids (key, id) values
  ('tenant',  '21000000-0000-0000-0000-000000000001'::uuid),
  ('s01',     '21000000-0000-0000-0000-000000000011'::uuid),
  ('s02',     '21000000-0000-0000-0000-000000000012'::uuid),
  ('owner',   '21000000-0000-0000-0000-000000000021'::uuid),
  ('cashier', '21000000-0000-0000-0000-000000000022'::uuid);

grant select on ids to authenticated;

create function pg_temp.id(k text) returns uuid language sql stable as
  $$ select id from ids where key = k $$;

insert into public.tenants (id, name, slug, base_currency, timezone)
values (pg_temp.id('tenant'), 'Nena Sari-Sari', 'nena-sari-sari', 'PHP', 'Asia/Manila');

insert into public.tenant_modules (tenant_id, pos, warehouse)
values (pg_temp.id('tenant'), true, false);

insert into public.tenant_settings (tenant_id, mode, receipt_header, receipt_footer)
values (
  pg_temp.id('tenant'),
  'full',
  'TIN 123-456-789-000 VAT REG',
  'Maraming salamat po! No return without receipt.'
);

insert into auth.users (id, email) values
  (pg_temp.id('owner'),   'owner@receipt-branding.invalid'),
  (pg_temp.id('cashier'), 'cashier@receipt-branding.invalid');

insert into public.locations (id, tenant_id, code, name, type, address) values
  (pg_temp.id('s01'), pg_temp.id('tenant'), 'S01', 'Poblacion Main', 'store', '123 Rizal St, Poblacion'),
  (pg_temp.id('s02'), pg_temp.id('tenant'), 'S02', 'Public Market Stall', 'store', null);

insert into public.profiles (user_id, tenant_id, username, full_name, role, active) values
  (pg_temp.id('owner'),   pg_temp.id('tenant'), 'owner',   'Aling Nena', 'superadmin', true),
  (pg_temp.id('cashier'), pg_temp.id('tenant'), 'cashier', 'Jun Cashier', 'cashier', true);

insert into public.location_access (tenant_id, user_id, location_id) values
  (pg_temp.id('tenant'), pg_temp.id('cashier'), pg_temp.id('s01'));

create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', pg_temp.id(p_user),
      'role', 'authenticated',
      'tenant_id', pg_temp.id('tenant')
    )::text,
    true
  );
$$;

-- 1. Superadmin sees receipt_header, receipt_footer, and per-location address
select pg_temp.login('owner');
set local role authenticated;

select is(
  public.get_my_access() -> 'tenant' ->> 'receipt_header',
  'TIN 123-456-789-000 VAT REG',
  '1. get_my_access exposes tenant receipt_header'
);

select is(
  public.get_my_access() -> 'tenant' ->> 'receipt_footer',
  'Maraming salamat po! No return without receipt.',
  '2. get_my_access exposes tenant receipt_footer'
);

select is(
  public.get_my_access() -> 'locations' -> 0 ->> 'address',
  '123 Rizal St, Poblacion',
  '3. get_my_access exposes populated store address on S01'
);

select is(
  public.get_my_access() -> 'locations' -> 1 ->> 'address',
  null,
  '4. get_my_access returns null address when location has none'
);

reset role;

-- 2. Cashier assigned to S01 also receives receipt branding & S01 address
select pg_temp.login('cashier');
set local role authenticated;

select is(
  public.get_my_access() -> 'tenant' ->> 'receipt_footer',
  'Maraming salamat po! No return without receipt.',
  '5. cashier receives tenant receipt_footer via get_my_access'
);

select is(
  public.get_my_access() -> 'locations' -> 0 ->> 'address',
  '123 Rizal St, Poblacion',
  '6. cashier receives assigned store address via get_my_access'
);

reset role;
select * from finish();
rollback;
