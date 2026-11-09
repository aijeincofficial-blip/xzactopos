-- 043_negative_stock_report.test.sql: the negative stock exception report (plan report 11).
-- negative_stock_list runs as the caller (security invoker, no writes). Row-level security scopes it, a level at or above zero
-- is never listed, and a negative one leaves the list by itself once stock is added (that IS the reconciliation).

begin;
select plan(19);

create function pg_temp.tid(p_tenant text) returns uuid language sql immutable
  as $$ select md5('tenant:' || p_tenant)::uuid $$;
create function pg_temp.uid(p_tenant text, p_user text) returns uuid language sql immutable
  as $$ select md5('user:' || p_tenant || ':' || p_user)::uuid $$;
create function pg_temp.lid(p_tenant text, p_code text) returns uuid language sql immutable
  as $$ select md5('loc:' || p_tenant || ':' || p_code)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values (pg_temp.tid('N'), 'Negative Tenant', 'negative-tenant', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid('N'), true, true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('N'));

insert into auth.users (id, email) values
  (pg_temp.uid('N', 'owner'), 'owner@neg.invalid'),
  (pg_temp.uid('N', 'maria'), 'maria@neg.invalid'),
  (pg_temp.uid('N', 'pedro'), 'pedro@neg.invalid'),
  (pg_temp.uid('N', 'nobody'), 'nobody@neg.invalid');
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('N', 'owner'), pg_temp.tid('N'), 'owner', 'superadmin', true),
  (pg_temp.uid('N', 'maria'), pg_temp.tid('N'), 'maria', 'cashier', true),
  (pg_temp.uid('N', 'pedro'), pg_temp.tid('N'), 'pedro', 'warehouse', true),
  (pg_temp.uid('N', 'nobody'), pg_temp.tid('N'), 'nobody', 'cashier', true);

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.lid('N', 'S1'), pg_temp.tid('N'), 'store', 'S1', 'Store 1'),
  (pg_temp.lid('N', 'S2'), pg_temp.tid('N'), 'store', 'S2', 'Store 2'),
  (pg_temp.lid('N', 'W1'), pg_temp.tid('N'), 'warehouse', 'W1', 'Warehouse 1');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('N', 'maria'), pg_temp.lid('N', 'S1'), pg_temp.tid('N'), null),
  (pg_temp.uid('N', 'pedro'), pg_temp.lid('N', 'W1'), pg_temp.tid('N'), null);

insert into public.products (id, tenant_id, name) values
  (md5('p:n1')::uuid, pg_temp.tid('N'), 'Rice 25kg'),
  (md5('p:n2')::uuid, pg_temp.tid('N'), 'Oil 1L'),
  (md5('p:n3')::uuid, pg_temp.tid('N'), 'Sugar 1kg');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (md5('v:n1')::uuid, pg_temp.tid('N'), md5('p:n1')::uuid, 'N-RICE', true),
  (md5('v:n2')::uuid, pg_temp.tid('N'), md5('p:n2')::uuid, 'N-OIL', true),
  (md5('v:n3')::uuid, pg_temp.tid('N'), md5('p:n3')::uuid, 'N-SUGAR', true);

-- opening stock, then movements that take some places below zero
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid('N'), pg_temp.lid('N', 'S1'), md5('v:n1')::uuid, 2, 'receipt', 1000),
  (pg_temp.tid('N'), pg_temp.lid('N', 'S2'), md5('v:n1')::uuid, 10, 'receipt', 1000),
  (pg_temp.tid('N'), pg_temp.lid('N', 'W1'), md5('v:n2')::uuid, 5, 'receipt', 5000),
  (pg_temp.tid('N'), pg_temp.lid('N', 'W1'), md5('v:n3')::uuid, 4, 'receipt', 700);
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type) values
  (pg_temp.tid('N'), pg_temp.lid('N', 'S1'), md5('v:n1')::uuid, -5, 'damage'),   -- S1 rice: 2 - 5 = -3
  (pg_temp.tid('N'), pg_temp.lid('N', 'W1'), md5('v:n2')::uuid, -8, 'damage'),   -- W1 oil: 5 - 8 = -3 (not the same as rice)
  (pg_temp.tid('N'), pg_temp.lid('N', 'W1'), md5('v:n3')::uuid, -4, 'damage');   -- W1 sugar: exactly zero, not negative

create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.uid('N', p_user), 'role', 'authenticated', 'tenant_id', pg_temp.tid('N'))::text, true);
$$;
create function pg_temp.names(p_who text) returns text language plpgsql as $$
declare v text;
begin
  perform pg_temp.login(p_who);
  set local role authenticated;
  select coalesce(string_agg(location_code || ':' || sku || '=' || trim_scale(qty_on_hand)::text, ', ' order by location_code, sku), '') into v
  from public.negative_stock_list();
  reset role;
  return v;
end $$;

-- ---------------------------------------------------------------------------
-- who sees what
-- ---------------------------------------------------------------------------
select is(pg_temp.names('owner'), 'S1:N-RICE=-3, W1:N-OIL=-3', 'the owner sees every place that is below zero, and not a level at exactly zero');
select is(pg_temp.names('maria'), 'S1:N-RICE=-3', 'a cashier sees only the negative stock of her own store');
select is(pg_temp.names('pedro'), 'W1:N-OIL=-3', 'a warehouse clerk sees only the negative stock of his own warehouse');
select is(pg_temp.names('nobody'), '', 'a user with no location sees nothing');

-- ---------------------------------------------------------------------------
-- what a row says
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;
select is((select location_type from public.negative_stock_list() where sku = 'N-RICE'), 'store', 'the row says what kind of place it is');
select is((select product_name from public.negative_stock_list() where sku = 'N-OIL'), 'Oil 1L', 'and the product name');
select is((select stock_value from public.negative_stock_list() where sku = 'N-OIL'), -15000::bigint, 'the value of the shortfall is negative (-3 x 5000)');
select ok((select last_movement_at is not null from public.negative_stock_list() where sku = 'N-RICE'), 'and when the stock last moved');
reset role;

-- ---------------------------------------------------------------------------
-- filters, paging, order
-- ---------------------------------------------------------------------------
select pg_temp.login('owner');
set local role authenticated;
select is((select count(*)::int from public.negative_stock_list(pg_temp.lid('N', 'W1'))), 1, 'one place can be asked for');
select is((select count(*)::int from public.negative_stock_list(pg_temp.lid('N', 'S2'))), 0, 'a place with nothing negative returns nothing');
select is((select count(*)::int from public.negative_stock_list(null, 1)), 1, 'a page of one returns one row');
create temp table pg_temp.pages as
  select 1 as n, f.sku from public.negative_stock_list(null, 1) f
  union all
  select 2, g.sku from public.negative_stock_list(null, 1,
    (select location_id from public.negative_stock_list(null, 1)), (select variant_id from public.negative_stock_list(null, 1))) g;
select is((select count(distinct sku)::int from pg_temp.pages), 2, 'the second page continues after the first row (keyset), without repeating it');
select is((select count(*)::int from public.negative_stock_list(null, 1,
    (select location_id from public.negative_stock_list(null, 2) offset 1 limit 1), (select variant_id from public.negative_stock_list(null, 2) offset 1 limit 1))),
  0, 'and there is nothing after the last row');
reset role;

-- ---------------------------------------------------------------------------
-- a place leaves the list by itself once stock is added, and comes back if it drops again
-- ---------------------------------------------------------------------------
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost)
  values (pg_temp.tid('N'), pg_temp.lid('N', 'S1'), md5('v:n1')::uuid, 3, 'receipt', 1000);
select is(pg_temp.names('owner'), 'W1:N-OIL=-3', 'bringing a place back to zero reconciles it');
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
  values (pg_temp.tid('N'), pg_temp.lid('N', 'S1'), md5('v:n1')::uuid, -1, 'damage');
select is(pg_temp.names('owner'), 'S1:N-RICE=-1, W1:N-OIL=-3', 'and it is listed again if it drops below zero');

-- ---------------------------------------------------------------------------
-- not listed: archived products, inactive places
-- ---------------------------------------------------------------------------
update public.product_variants set active = false where id = md5('v:n2')::uuid;
select is(pg_temp.names('owner'), 'S1:N-RICE=-1', 'an archived product is not listed');
update public.product_variants set active = true where id = md5('v:n2')::uuid;
update public.locations set active = false where id = pg_temp.lid('N', 'W1');
select is(pg_temp.names('owner'), 'S1:N-RICE=-1', 'an inactive place is not listed');
update public.locations set active = true where id = pg_temp.lid('N', 'W1');

-- ---------------------------------------------------------------------------
-- read only, and not callable without signing in
-- ---------------------------------------------------------------------------
select is((select prosecdef from pg_proc where proname = 'negative_stock_list' and pronamespace = 'public'::regnamespace), false,
          'the report runs as the caller (security invoker)');
set local role anon;
select throws_ok($$ select * from public.negative_stock_list() $$, '42501', null, 'an anonymous caller is refused');
reset role;

select * from finish();
rollback;
