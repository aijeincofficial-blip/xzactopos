-- P2-06 product photo bucket and storage.objects policies
begin;
select plan(15);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.path(p_tenant text, p_n int) returns text language sql immutable as
  $$ select pg_temp.t(p_tenant)::text || '/' || md5('p' || p_n)::uuid::text || '/' || md5('o' || p_n)::uuid::text || '.jpg' $$;
create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;
-- runs a statement, returns 'ok' or the SQLSTATE
create function pg_temp.try(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end;
$$;
create function pg_temp.put(p_path text) returns text language sql as
  $$ select pg_temp.try(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'product-photos', p_path)) $$;

insert into auth.users (id, email)
select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'juan', 'pedro', 'ownerB', 'ownerS']) n;
insert into public.tenants (id, name, slug, base_currency, status) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP', 'active'),
  (pg_temp.t('B'), 'B', 'tenant-b', 'PHP', 'active'),
  (pg_temp.t('S'), 'S', 'tenant-s', 'PHP', 'suspended');
insert into public.tenant_modules (tenant_id, pos, warehouse) values
  (pg_temp.t('A'), true, true), (pg_temp.t('B'), true, false), (pg_temp.t('S'), true, false);
insert into public.profiles (user_id, tenant_id, username, role) values
  (pg_temp.u('owner'),  pg_temp.t('A'), 'owner', 'superadmin'),
  (pg_temp.u('maria'),  pg_temp.t('A'), 'maria', 'admin'),
  (pg_temp.u('juan'),   pg_temp.t('A'), 'juan', 'cashier'),
  (pg_temp.u('pedro'),  pg_temp.t('A'), 'pedro', 'warehouse'),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin'),
  (pg_temp.u('ownerS'), pg_temp.t('S'), 'owner', 'superadmin');
insert into public.locations (id, tenant_id, type, code, name) values
  (md5('S01')::uuid, pg_temp.t('A'), 'store', 'S01', 'Store'),
  (md5('W01')::uuid, pg_temp.t('A'), 'warehouse', 'W01', 'Warehouse');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), md5('S01')::uuid, pg_temp.t('A'), 'manager'),
  (pg_temp.u('juan'),  md5('S01')::uuid, pg_temp.t('A'), null),
  (pg_temp.u('pedro'), md5('W01')::uuid, pg_temp.t('A'), null);

select is(
  (select row(public, file_size_limit, allowed_mime_types)::text from storage.buckets where id = 'product-photos'),
  row(false, 204800::bigint, array['image/jpeg'])::text,
  'bucket is private, 200 KB, JPEG only');

-- writers
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.put(pg_temp.path('A', 1)), 'ok', 'owner uploads into their tenant folder');
select is(pg_temp.put(pg_temp.path('B', 2)), '42501', 'owner cannot upload into another tenant''s folder');
select is(pg_temp.put(pg_temp.t('A')::text || '/photo.png'), '42501', 'path must be <tenant>/<product>/<op>.jpg');
select is(pg_temp.try(format('update storage.objects set metadata = ''{}'' where name = %L', pg_temp.path('A', 1))), 'ok',
  'owner can overwrite (retry of the same upload)');
reset role;

select pg_temp.login('maria', 'A');
set local role authenticated;
select is(pg_temp.put(pg_temp.path('A', 3)), 'ok', 'store manager uploads');
reset role;

select pg_temp.login('juan', 'A');
set local role authenticated;
select is(pg_temp.put(pg_temp.path('A', 4)), '42501', 'cashier cannot upload');
select is((select count(*)::int from storage.objects where bucket_id = 'product-photos'), 2, 'cashier sees the tenant''s photos');
reset role;

select pg_temp.login('pedro', 'A');
set local role authenticated;
select is(pg_temp.put(pg_temp.path('A', 5)), '42501', 'warehouse cannot upload photos (cost and SKU only)');
reset role;

select pg_temp.login('ownerB', 'B');
set local role authenticated;
select is((select count(*)::int from storage.objects where bucket_id = 'product-photos'), 0, 'another tenant sees none of them');
select is(pg_temp.try(format('update storage.objects set metadata = ''{"hijack": true}'' where name = %L', pg_temp.path('A', 1))),
  'ok', 'another tenant''s update runs ...');
reset role;
select is((select metadata from storage.objects where name = pg_temp.path('A', 1)), '{}'::jsonb,
  '... but changes nothing in tenant A');

select pg_temp.login('ownerS', 'S');
set local role authenticated;
select is(pg_temp.put(pg_temp.path('S', 6)), '42501', 'a suspended tenant cannot upload');
reset role;

-- nobody deletes from clients
select pg_temp.login('owner', 'A');
set local role authenticated;
select pg_temp.try(format('delete from storage.objects where name = %L', pg_temp.path('A', 1)));
reset role;
select is((select count(*)::int from storage.objects where name = pg_temp.path('A', 1)), 1, 'owner cannot delete a photo');

set local role anon;
select is(pg_temp.try($$ select count(*) from storage.objects where bucket_id = 'product-photos' having count(*) > 0 $$) || '|' ||
          (select count(*)::text from storage.objects where bucket_id = 'product-photos'), 'ok|0', 'anon sees no photos');
reset role;

select * from finish();
rollback;
