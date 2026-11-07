-- P2-01 catalog schema: keys per tenant, default variant, cross-tenant FKs, limits, triggers, no client writes.
begin;
select plan(20);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.p(p text) returns uuid language sql immutable as $$ select md5('p:' || p)::uuid $$;
create function pg_temp.v(p text) returns uuid language sql immutable as $$ select md5('v:' || p)::uuid $$;

insert into auth.users (id, email) values (pg_temp.u('ownerA'), 'ownera@test.invalid');
insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.t('A'), 'Tenant A', 'tenant-a', 'PHP'),
  (pg_temp.t('B'), 'Tenant B', 'tenant-b', 'PHP');
insert into public.tenant_limits (tenant_id, max_products) values (pg_temp.t('A'), 3), (pg_temp.t('B'), 100);
insert into public.profiles (user_id, tenant_id, username, role) values (pg_temp.u('ownerA'), pg_temp.t('A'), 'owner', 'superadmin');

insert into public.products (id, tenant_id, name) values
  (pg_temp.p('A1'), pg_temp.t('A'), 'Kape'),
  (pg_temp.p('A2'), pg_temp.t('A'), 'Asukal'),
  (pg_temp.p('B1'), pg_temp.t('B'), 'Kape');
insert into public.product_variants (id, tenant_id, product_id, sku, barcode, is_default, reorder_point) values
  (pg_temp.v('A1'), pg_temp.t('A'), pg_temp.p('A1'), 'KAPE', '4800000000011', true, 0),
  (pg_temp.v('A2'), pg_temp.t('A'), pg_temp.p('A2'), 'ASUKAL', null, true, 2.5),
  (pg_temp.v('B1'), pg_temp.t('B'), pg_temp.p('B1'), 'KAPE', '4800000000011', true, 0);

select has_table('public', t, 'table ' || t || ' exists')
from unnest(array['categories', 'products', 'product_variants', 'variant_prices']) t;

-- business keys are per tenant
select pass('same SKU and barcode live in two tenants');
select throws_ok(
  $$ insert into public.product_variants (tenant_id, product_id, sku) values (md5('t:A')::uuid, md5('p:A2')::uuid, 'KAPE') $$,
  '23505', null, 'duplicate SKU in one tenant is refused');
select throws_ok(
  $$ insert into public.product_variants (tenant_id, product_id, sku, barcode) values (md5('t:A')::uuid, md5('p:A2')::uuid, 'X1', '4800000000011') $$,
  '23505', null, 'duplicate live barcode in one tenant is refused');

update public.product_variants set deleted_at = now() where id = pg_temp.v('A1');
select lives_ok(
  $$ insert into public.product_variants (tenant_id, product_id, sku, barcode) values (md5('t:A')::uuid, md5('p:A2')::uuid, 'X2', '4800000000011') $$,
  'an archived variant frees its barcode');

select throws_ok(
  $$ insert into public.product_variants (tenant_id, product_id, sku, is_default) values (md5('t:A')::uuid, md5('p:A2')::uuid, 'X3', true) $$,
  '23505', null, 'a product has only one live default variant');

-- tenant boundaries in foreign keys
select throws_ok(
  $$ insert into public.product_variants (tenant_id, product_id, sku) values (md5('t:A')::uuid, md5('p:B1')::uuid, 'X4') $$,
  '23503', null, 'a variant cannot point at another tenant''s product');
select throws_ok(
  $$ insert into public.variant_prices (tenant_id, variant_id, currency, price) values (md5('t:A')::uuid, md5('v:B1')::uuid, 'PHP', 100) $$,
  '23503', null, 'a price cannot point at another tenant''s variant');

-- value checks
select throws_ok(
  $$ insert into public.variant_prices (tenant_id, variant_id, currency, price) values (md5('t:A')::uuid, md5('v:A2')::uuid, 'PHP', -1) $$,
  '23514', null, 'negative price is refused');
select throws_ok(
  $$ insert into public.product_variants (tenant_id, product_id, sku) values (md5('t:A')::uuid, md5('p:A2')::uuid, 'bad sku!') $$,
  '23514', null, 'malformed SKU is refused');
select is((select reorder_point from public.product_variants where id = pg_temp.v('A2')), 2.5::numeric(12, 3),
  'fractional quantities are kept (sold by the kilo)');

-- product limit (A allows 3; 2 exist)
select lives_ok($$ insert into public.products (tenant_id, name) values (md5('t:A')::uuid, 'Third') $$, 'third product fits the limit');
select throws_ok($$ insert into public.products (tenant_id, name) values (md5('t:A')::uuid, 'Fourth') $$,
  'P0001', null, 'product limit is enforced');

-- triggers
update public.products set name = 'Kape 3-in-1', updated_at = '2000-01-01' where id = pg_temp.p('A1');
select is((select updated_at from public.products where id = pg_temp.p('A1')), now(), 'updated_at is server time');
select throws_ok($$ update public.products set tenant_id = md5('t:B')::uuid where id = md5('p:A1')::uuid $$,
  null, null, 'tenant_id cannot change');

-- clients: read only
select set_config('request.jwt.claims',
  jsonb_build_object('sub', pg_temp.u('ownerA'), 'role', 'authenticated', 'tenant_id', pg_temp.t('A'))::text, true);
set local role authenticated;
select throws_ok($$ insert into public.products (tenant_id, name) values (md5('t:A')::uuid, 'Direct') $$,
  '42501', null, 'even a superadmin cannot insert products directly');
reset role;
set local role anon;
select throws_ok($$ select 1 from public.products $$, '42501', null, 'anon cannot read the catalog');
reset role;

select * from finish();
rollback;
