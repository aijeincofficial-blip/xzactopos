-- P2-02 upsert_product / archive_product / sync_pull_catalog
begin;
select plan(42);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('id:' || p)::uuid $$;

create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;

-- hint of the error a statement raises (null if it succeeds)
create function pg_temp.hint(p_sql text) returns text language plpgsql as $$
declare
  h text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics h = pg_exception_hint;
  return coalesce(nullif(h, ''), sqlstate);
end;
$$;

-- product payload helper
create function pg_temp.prod(p_key text, p_extra jsonb default '{}', p_variant jsonb default '{}') returns jsonb
language sql immutable as $$
  select jsonb_build_object('id', pg_temp.id('p:' || p_key),
                            'variant', jsonb_build_object('id', pg_temp.id('v:' || p_key)) || p_variant) || p_extra;
$$;

insert into auth.users (id, email)
select pg_temp.u(n), n || '@test.invalid'
from unnest(array['owner', 'maria', 'sup', 'pedro', 'juan', 'ana', 'ownerB']) n;

insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.t('A'), 'Tenant A', 'tenant-a', 'PHP'),
  (pg_temp.t('B'), 'Tenant B', 'tenant-b', 'USD');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.t('A'), true, true), (pg_temp.t('B'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B'));

insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'),  pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'),  pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('sup'),    pg_temp.t('A'), 'sup', 'admin', true),
  (pg_temp.u('pedro'),  pg_temp.t('A'), 'pedro', 'warehouse', true),
  (pg_temp.u('juan'),   pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('ana'),    pg_temp.t('A'), 'ana', 'cashier', false),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true);

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'Store 1'),
  (pg_temp.id('S02'), pg_temp.t('A'), 'store', 'S02', 'Store 2'),
  (pg_temp.id('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'Warehouse');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sup'),   pg_temp.id('S02'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null),
  (pg_temp.u('juan'),  pg_temp.id('S01'), pg_temp.t('A'), null);

-- tenant B already has a product and a category
insert into public.categories (id, tenant_id, name) values (pg_temp.id('catB'), pg_temp.t('B'), 'B stuff');
insert into public.products (id, tenant_id, name) values (pg_temp.id('p:B1'), pg_temp.t('B'), 'B product');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default)
  values (pg_temp.id('v:B1'), pg_temp.t('B'), pg_temp.id('p:B1'), 'B1', true);

-- ===========================================================================
-- Owner (superadmin) of A
-- ===========================================================================
select pg_temp.login('owner', 'A');
set local role authenticated;

select is(
  public.upsert_product(pg_temp.id('op1'), pg_temp.prod('P1', '{"name": " Kape ", "price": 1250}', '{"barcode": "4800000000011"}'))
    - 'sku',
  jsonb_build_object('product_id', pg_temp.id('p:P1'), 'variant_id', pg_temp.id('v:P1'), 'created', true, 'replay', false),
  'owner creates a product');

select is(
  (select row(p.name, p.unit, v.is_default, v.barcode, pr.currency::text, pr.price, v.sku like 'P-%')::text
     from public.products p
     join public.product_variants v on v.product_id = p.id
     join public.variant_prices pr on pr.variant_id = v.id
    where p.id = pg_temp.id('p:P1')),
  row('Kape', 'pc', true, '4800000000011', 'PHP', 1250::bigint, true)::text,
  'name trimmed, default variant, base-currency price, auto SKU');

select is(
  public.upsert_product(pg_temp.id('op1'), pg_temp.prod('P1', '{"name": "Changed", "price": 1}')) ->> 'replay',
  'true', 'replaying the same op id returns the stored result');
select is(
  (select row(name, (select price from public.variant_prices where variant_id = pg_temp.id('v:P1')))::text
     from public.products where id = pg_temp.id('p:P1')),
  row('Kape', 1250::bigint)::text, 'a replay changes nothing');
select is(pg_temp.hint(format('select public.archive_product(%L, %L)', pg_temp.id('op1'), pg_temp.id('p:P1'))),
  'op_id_reused', 'an op id cannot be reused for another kind of op');

select is(
  public.upsert_product(pg_temp.id('op2'), pg_temp.prod('P1', '{"name": "Kape 3-in-1", "price": 1500}')) ->> 'created',
  'false', 'a new op updates the product');
select is(
  (select row(p.name, p.unit, v.barcode, pr.price)::text
     from public.products p join public.product_variants v on v.product_id = p.id
     join public.variant_prices pr on pr.variant_id = v.id where p.id = pg_temp.id('p:P1')),
  row('Kape 3-in-1', 'pc', '4800000000011', 1500::bigint)::text, 'given keys change, missing keys are kept');

select lives_ok(format('select public.upsert_product(%L, %L)', pg_temp.id('op3'),
  pg_temp.prod('P2', '{"name": "Asukal", "price": 4500, "unit": "kg"}')), 'second product');

select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op4'),
  pg_temp.prod('P2', '{}', '{"barcode": "4800000000011"}'))), 'duplicate_barcode', 'a live barcode cannot be used twice');
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op5'),
  pg_temp.prod('P3', '{"name": "X", "price": 1}',
    jsonb_build_object('sku', (select sku from public.product_variants where id = pg_temp.id('v:P1')))))),
  'duplicate_sku', 'a SKU cannot be used twice');
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op6'), pg_temp.prod('P3', '{"name": "X"}'))),
  'price_required', 'price is required on create');
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op7'), pg_temp.prod('P3', '{"price": 1}'))),
  'name_required', 'name is required on create');
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op8'),
  jsonb_build_object('id', pg_temp.id('p:B1'), 'name', 'Steal', 'price', 1, 'variant', jsonb_build_object('id', pg_temp.id('v:x'))))),
  'id_conflict', 'another tenant''s product id cannot be taken over');
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op9'),
  pg_temp.prod('P1', '{}', jsonb_build_object('id', pg_temp.id('v:other'))))),
  'variant_mismatch', 'update must name the default variant');
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op10'),
  pg_temp.prod('P3', jsonb_build_object('name', 'X', 'price', 1, 'category_id', pg_temp.id('catB'))))),
  'bad_category', 'another tenant''s category is refused');
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op11'),
  pg_temp.prod('P3', '{"name": "X", "price": -5}'))), 'invalid_value', 'negative price is refused');
select is(pg_temp.hint(format('select public.upsert_product(null, %L)', pg_temp.prod('P3', '{"name": "X", "price": 1}'))),
  'op_id_required', 'an op id is required');
reset role;

select is((select count(*)::int from public.products where tenant_id = pg_temp.t('A')), 2, 'failed calls left nothing behind');
select is((select count(*)::int from public.processed_ops where tenant_id = pg_temp.t('A')), 3, 'only successful ops are recorded');

-- ===========================================================================
-- Other roles in A
-- ===========================================================================
select pg_temp.login('maria', 'A');
set local role authenticated;
select lives_ok(format('select public.upsert_product(%L, %L)', pg_temp.id('op20'),
  pg_temp.prod('P4', '{"name": "Sardinas", "price": 2600}')), 'admin who manages a store can add products');
reset role;

select pg_temp.login('sup', 'A');
set local role authenticated;
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op21'),
  pg_temp.prod('P3', '{"name": "X", "price": 1}'))), 'not_allowed', 'supervisor-only admin cannot change the catalog');
reset role;

select pg_temp.login('juan', 'A');
set local role authenticated;
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op22'),
  pg_temp.prod('P3', '{"name": "X", "price": 1}'))), 'not_allowed', 'cashier cannot change the catalog');
reset role;

select pg_temp.login('pedro', 'A');
set local role authenticated;
select lives_ok(format('select public.upsert_product(%L, %L)', pg_temp.id('op23'),
  pg_temp.prod('P2', '{}', '{"sku": "SUGAR-1KG", "cost": 3900}')), 'warehouse changes cost and SKU');
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op24'),
  pg_temp.prod('P2', '{"price": 1}'))), 'cost_and_sku_only', 'warehouse cannot change the price');
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op25'),
  pg_temp.prod('P3', '{"name": "X", "price": 1}'))), 'cost_and_sku_only', 'warehouse cannot add products');
select is(pg_temp.hint(format('select public.archive_product(%L, %L)', pg_temp.id('op26'), pg_temp.id('p:P2'))),
  'not_allowed', 'warehouse cannot archive');
reset role;
select is((select row(sku, cost)::text from public.product_variants where id = pg_temp.id('v:P2')),
  row('SUGAR-1KG', 3900::bigint)::text, 'warehouse change was applied');

-- ===========================================================================
-- Archive
-- ===========================================================================
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(public.archive_product(pg_temp.id('op30'), pg_temp.id('p:P1')) ->> 'replay', 'false', 'owner archives a product');
select is(public.archive_product(pg_temp.id('op30'), pg_temp.id('p:P1')) ->> 'replay', 'true', 'archive replay is safe');
select is(pg_temp.hint(format('select public.upsert_product(%L, %L)', pg_temp.id('op31'),
  pg_temp.prod('P1', '{"name": "Back"}'))), 'product_archived', 'an archived product cannot be edited');
select lives_ok(format('select public.upsert_product(%L, %L)', pg_temp.id('op32'),
  pg_temp.prod('P5', '{"name": "Kape bago", "price": 1300}', '{"barcode": "4800000000011"}')),
  'the archived product''s barcode can be reused');
reset role;
select is(
  (select row((select deleted_at is not null from public.products where id = pg_temp.id('p:P1')),
              (select deleted_at is not null from public.product_variants where id = pg_temp.id('v:P1')),
              (select deleted_at is not null from public.variant_prices where variant_id = pg_temp.id('v:P1')))::text),
  row(true, true, true)::text, 'archive tombstones product, variant and price');

-- ===========================================================================
-- Tenant B cannot reach A, and op ids are per tenant
-- ===========================================================================
select pg_temp.login('ownerB', 'B');
set local role authenticated;
select is(pg_temp.hint(format('select public.archive_product(%L, %L)', pg_temp.id('op40'), pg_temp.id('p:P2'))),
  'not_found', 'another tenant''s product is not found');
select is(public.upsert_product(pg_temp.id('op1'), pg_temp.prod('BP2', '{"name": "B two", "price": 100}')) ->> 'created',
  'true', 'the same op id in another tenant is a new op (no leak of A''s result)');
reset role;

-- ===========================================================================
-- Pull. Age A's rows past the 5 s settle window (triggers off for this one update).
-- ===========================================================================
alter table public.products disable trigger products_set_updated_at;
alter table public.product_variants disable trigger product_variants_set_updated_at;
alter table public.variant_prices disable trigger variant_prices_set_updated_at;
update public.products set updated_at = updated_at - interval '1 minute' where tenant_id = pg_temp.t('A');
update public.product_variants set updated_at = updated_at - interval '1 minute' where tenant_id = pg_temp.t('A');
update public.variant_prices set updated_at = updated_at - interval '1 minute' where tenant_id = pg_temp.t('A');
alter table public.products enable trigger products_set_updated_at;
alter table public.product_variants enable trigger product_variants_set_updated_at;
alter table public.variant_prices enable trigger variant_prices_set_updated_at;

-- follows cursors page by page and returns every product id seen
create function pg_temp.pull_all(p_limit int) returns uuid[] language plpgsql as $$
declare
  v_cur jsonb := '{}';
  v_res jsonb;
  v_ids uuid[] := '{}';
  i int := 0;
begin
  loop
    v_res := public.sync_pull_catalog(v_cur, p_limit);
    v_ids := v_ids || array(select (x ->> 'id')::uuid from jsonb_array_elements(v_res -> 'products' -> 'rows') x);
    v_cur := jsonb_build_object('products', v_res -> 'products' -> 'cursor');
    i := i + 1;
    exit when not (v_res -> 'products' ->> 'has_more')::boolean or i > 20;
  end loop;
  return v_ids;
end;
$$;

select pg_temp.login('owner', 'A');
set local role authenticated;
select set_eq(
  $$ select unnest(pg_temp.pull_all(500)) $$,
  array[pg_temp.id('p:P1'), pg_temp.id('p:P2'), pg_temp.id('p:P4'), pg_temp.id('p:P5')],
  'pull returns all of A''s products, archived included, and nothing of B');
select is(
  (select count(*)::int from jsonb_array_elements(public.sync_pull_catalog('{}', 500) -> 'products' -> 'rows') x
    where x ->> 'deleted_at' is not null), 1, 'the archived product comes as a tombstone');
select is(
  (select array_length(pg_temp.pull_all(1), 1)), 4, 'paging one row at a time sees every product exactly once');
select is(
  (select (public.sync_pull_catalog('{}', 500) -> 'variant_prices' -> 'rows') @> '[{"currency": "PHP", "price": 1500}]'::jsonb),
  true, 'prices are pulled with currency and minor units');

select lives_ok(format('select public.upsert_product(%L, %L)', pg_temp.id('op50'),
  pg_temp.prod('P6', '{"name": "Fresh", "price": 1}')), 'add a product now');
select ok(not (pg_temp.id('p:P6') = any (pg_temp.pull_all(500))), 'a write younger than 5 s is held back');
reset role;

select pg_temp.login('juan', 'A');
set local role authenticated;
select is(array_length(pg_temp.pull_all(500), 1), 4, 'a cashier pulls the catalog too');
reset role;

select pg_temp.login('ana', 'A');
set local role authenticated;
select is(pg_temp.hint($$ select public.sync_pull_catalog('{}', 10) $$), 'no_account', 'a deactivated user cannot pull');
reset role;

select * from finish();
rollback;
