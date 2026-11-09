-- 033_catalog_categories.test.sql: pgTAP tests for Card W-03 category management (upsert_category, archive_category)

begin;
select plan(18);

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

-- Category in Tenant B
insert into public.categories (id, tenant_id, name) values
  (md5('cat:B:snacks')::uuid, pg_temp.tid('B'), 'Snacks Beta');

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
  $$ select public.upsert_category(gen_random_uuid(), '{"name": "Beverages"}'::jsonb) $$,
  '42501',
  null,
  'anon cannot execute upsert_category'
);

select throws_ok(
  $$ select public.archive_category(gen_random_uuid(), gen_random_uuid()) $$,
  '42501',
  null,
  'anon cannot execute archive_category'
);

-- ---------------------------------------------------------------------------
-- 2. Security & RBAC: Cashier blocked
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.login('A', 'juan');

select throws_ok(
  $$ select public.upsert_category(gen_random_uuid(), '{"name": "Beverages"}'::jsonb) $$,
  '42501',
  null,
  'cashier cannot upsert_category'
);

select throws_ok(
  $$ select public.archive_category(gen_random_uuid(), gen_random_uuid()) $$,
  '42501',
  null,
  'cashier cannot archive_category'
);

-- ---------------------------------------------------------------------------
-- 3. Superadmin Validation & Category Creation
-- ---------------------------------------------------------------------------
select pg_temp.login('A', 'owner');

-- 3.1 Empty name rejected
select throws_ok(
  $$ select public.upsert_category(gen_random_uuid(), '{"name": "   "}'::jsonb) $$,
  '22023',
  null,
  'blank category name is rejected'
);

-- 3.2 Create category
select is(
  (public.upsert_category(
    md5('op:cat1')::uuid,
    jsonb_build_object('id', md5('cat:bev')::uuid, 'name', 'Beverages')
  ) ->> 'created')::boolean,
  true,
  'owner can create category'
);

-- 3.3 Verify row in database
select is(
  (select name from public.categories where id = md5('cat:bev')::uuid and tenant_id = pg_temp.tid('A')),
  'Beverages',
  'category row inserted with correct tenant and name'
);

-- 3.4 Verify audit log for create
select is(
  (select count(*)::int from public.audit_log where action = 'category.create' and entity_id = md5('cat:bev')::uuid),
  1,
  'audit log recorded for category.create'
);

-- 3.5 Replay with same op_id
select is(
  (public.upsert_category(
    md5('op:cat1')::uuid,
    jsonb_build_object('id', md5('cat:bev')::uuid, 'name', 'Beverages')
  ) ->> 'created')::boolean,
  true,
  'replay with same op_id returns cached result'
);

-- ---------------------------------------------------------------------------
-- 4. Parent Category Validations & Sub-categories
-- ---------------------------------------------------------------------------
-- 4.1 Self as parent rejected
select throws_ok(
  $$ select public.upsert_category(
       gen_random_uuid(),
       jsonb_build_object('id', md5('cat:bev')::uuid, 'name', 'Beverages', 'parent_id', md5('cat:bev')::uuid)
     ) $$,
  '22023',
  null,
  'category cannot be its own parent'
);

-- 4.2 Cross-tenant parent rejected
select throws_ok(
  $$ select public.upsert_category(
       gen_random_uuid(),
       jsonb_build_object('id', gen_random_uuid(), 'name', 'Snacks', 'parent_id', md5('cat:B:snacks')::uuid)
     ) $$,
  '22023',
  null,
  'parent from another tenant is rejected'
);

-- 4.3 Create valid subcategory
select is(
  (public.upsert_category(
    md5('op:cat2')::uuid,
    jsonb_build_object('id', md5('cat:soft')::uuid, 'name', 'Soft Drinks', 'parent_id', md5('cat:bev')::uuid)
  ) ->> 'parent_id')::uuid,
  md5('cat:bev')::uuid,
  'subcategory created with valid parent'
);

-- ---------------------------------------------------------------------------
-- 5. Update Category
-- ---------------------------------------------------------------------------
select is(
  (public.upsert_category(
    md5('op:cat3')::uuid,
    jsonb_build_object('id', md5('cat:bev')::uuid, 'name', 'Cold Drinks')
  ) ->> 'name'),
  'Cold Drinks',
  'category name updated successfully'
);

select is(
  (select count(*)::int from public.audit_log where action = 'category.update' and entity_id = md5('cat:bev')::uuid),
  1,
  'audit log recorded for category.update'
);

-- ---------------------------------------------------------------------------
-- 6. Category Archive & Active Product Detachment
-- ---------------------------------------------------------------------------
-- Attach category to product via upsert_product
select public.upsert_product(
  md5('op:prod1')::uuid,
  jsonb_build_object(
    'id', md5('prod:coke')::uuid,
    'name', 'Coca Cola 330ml',
    'price', 2500,
    'category_id', md5('cat:bev')::uuid,
    'variant', jsonb_build_object('id', md5('var:coke')::uuid, 'cost', 2000)
  )
);

-- Archive category
select is(
  (public.archive_category(md5('op:cat_arc')::uuid, md5('cat:bev')::uuid) ->> 'archived')::boolean,
  true,
  'owner can archive category'
);

-- Verify category is archived
select ok(
  (select deleted_at is not null from public.categories where id = md5('cat:bev')::uuid),
  'category deleted_at is set'
);

-- Verify product had its category_id detached (cleared to null)
select is(
  (select category_id from public.products where id = md5('prod:coke')::uuid),
  null,
  'active product category_id was safely cleared to null upon category archival'
);

-- Verify audit log for archive
select is(
  (select count(*)::int from public.audit_log where action = 'category.archive' and entity_id = md5('cat:bev')::uuid),
  1,
  'audit log recorded for category.archive'
);

rollback;
