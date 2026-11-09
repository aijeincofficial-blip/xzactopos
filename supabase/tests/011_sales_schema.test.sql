-- P3-01 sales and ledger schema: derived stock, append-only tables, per-tenant keys, cross-tenant FKs, no client writes.
begin;
select plan(26);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.l(p text) returns uuid language sql immutable as $$ select md5('l:' || p)::uuid $$;
create function pg_temp.v(p text) returns uuid language sql immutable as $$ select md5('v:' || p)::uuid $$;
create function pg_temp.s(p text) returns uuid language sql immutable as $$ select md5('s:' || p)::uuid $$;
create function pg_temp.c(p text) returns uuid language sql immutable as $$ select md5('c:' || p)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.t('A'), 'Tenant A', 'tenant-a', 'PHP'),
  (pg_temp.t('B'), 'Tenant B', 'tenant-b', 'PHP');
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.l('A'), pg_temp.t('A'), 'store', 'MAIN', 'A'),
  (pg_temp.l('B'), pg_temp.t('B'), 'store', 'MAIN', 'B');
insert into public.products (id, tenant_id, name) values
  (md5('p:A')::uuid, pg_temp.t('A'), 'Kape'), (md5('p:B')::uuid, pg_temp.t('B'), 'Kape');
insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (pg_temp.v('A'), pg_temp.t('A'), md5('p:A')::uuid, 'KAPE', true),
  (pg_temp.v('B'), pg_temp.t('B'), md5('p:B')::uuid, 'KAPE', true);

select has_table('public', t, 'table ' || t || ' exists')
from unnest(array['stock_movements', 'stock_levels', 'customers', 'customer_ledger', 'sales', 'sale_items', 'payments']) t;

-- stock levels follow movements
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
values (pg_temp.t('A'), pg_temp.l('A'), pg_temp.v('A'), 10, 'opening');
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
values (pg_temp.t('A'), pg_temp.l('A'), pg_temp.v('A'), -3.5, 'sale');
select is((select qty_on_hand from public.stock_levels where variant_id = pg_temp.v('A')), 6.5::numeric,
          'stock level is the sum of movements');

insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
values (pg_temp.t('A'), pg_temp.l('A'), pg_temp.v('A'), -20, 'sale');
select is((select qty_on_hand from public.stock_levels where variant_id = pg_temp.v('A')), -13.5::numeric,
          'stock may go below zero (an offline sale already happened)');
select is((select count(*)::int from public.stock_levels where tenant_id = pg_temp.t('A')), 1,
          'one level row per location and variant');

select throws_ok(
  $$ update public.stock_movements set qty_delta = 99 $$, '55000', null, 'a movement cannot be edited');
select throws_ok(
  $$ delete from public.stock_movements $$, '55000', null, 'a movement cannot be deleted');
select throws_ok(
  $$ insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
     values (md5('t:A')::uuid, md5('l:A')::uuid, md5('v:A')::uuid, 0, 'sale') $$,
  '23514', null, 'a zero movement is refused');
select throws_ok(
  $$ insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
     values (md5('t:A')::uuid, md5('l:B')::uuid, md5('v:A')::uuid, 1, 'opening') $$,
  '23503', null, 'a movement cannot use another tenant''s store');
select throws_ok(
  $$ insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
     values (md5('t:A')::uuid, md5('l:A')::uuid, md5('v:B')::uuid, 1, 'opening') $$,
  '23503', null, 'a movement cannot use another tenant''s variant');

-- sales: receipt number is unique per tenant, totals must add up
insert into public.sales (id, tenant_id, location_id, local_no, subtotal, discount, total, sold_at)
values (pg_temp.s('A1'), pg_temp.t('A'), pg_temp.l('A'), 'D1-261108-0001', 5000, 500, 4500, now()),
       (pg_temp.s('B1'), pg_temp.t('B'), pg_temp.l('B'), 'D1-261108-0001', 1000, 0, 1000, now());
select pass('the same receipt number can exist in two tenants');
select throws_ok(
  $$ insert into public.sales (tenant_id, location_id, local_no, subtotal, total, sold_at)
     values (md5('t:A')::uuid, md5('l:A')::uuid, 'D1-261108-0001', 100, 100, now()) $$,
  '23505', null, 'a receipt number is unique inside one tenant');
select throws_ok(
  $$ insert into public.sales (tenant_id, location_id, local_no, subtotal, discount, total, sold_at)
     values (md5('t:A')::uuid, md5('l:A')::uuid, 'D1-261108-0002', 100, 10, 100, now()) $$,
  '23514', null, 'total must equal subtotal minus discount');
select throws_ok(
  $$ insert into public.sales (tenant_id, location_id, local_no, subtotal, total, sold_at, customer_id)
     values (md5('t:A')::uuid, md5('l:A')::uuid, 'D1-261108-0003', 100, 100, now(), md5('c:B')::uuid) $$,
  '23503', null, 'a sale cannot point at another tenant''s customer');

insert into public.sale_items (tenant_id, sale_id, location_id, variant_id, product_name, qty, unit_price, line_total)
values (pg_temp.t('A'), pg_temp.s('A1'), pg_temp.l('A'), pg_temp.v('A'), 'Kape', 2, 2500, 5000);
select throws_ok(
  $$ insert into public.sale_items (tenant_id, sale_id, location_id, variant_id, product_name, qty, unit_price, line_total)
     values (md5('t:A')::uuid, md5('s:B1')::uuid, md5('l:B')::uuid, md5('v:A')::uuid, 'Kape', 1, 1, 1) $$,
  '23503', null, 'an item cannot hang on another tenant''s sale');
select throws_ok(
  $$ update public.sale_items set qty = 99 $$, '55000', null, 'sale lines cannot be edited');
select throws_ok(
  $$ insert into public.payments (tenant_id, sale_id, location_id, method, amount, tendered)
     values (md5('t:A')::uuid, md5('s:A1')::uuid, md5('l:A')::uuid, 'utang', 100, 100) $$,
  '23514', null, 'only cash records an amount tendered');

-- utang ledger: signs and balance
insert into public.customers (id, tenant_id, name) values
  (pg_temp.c('A'), pg_temp.t('A'), 'Aling Rosa'), (pg_temp.c('B'), pg_temp.t('B'), 'Aling Rosa');
insert into public.customer_ledger (tenant_id, customer_id, kind, amount, sale_id) values
  (pg_temp.t('A'), pg_temp.c('A'), 'charge', 15000, pg_temp.s('A1'));
insert into public.customer_ledger (tenant_id, customer_id, kind, amount) values
  (pg_temp.t('A'), pg_temp.c('A'), 'payment', -4000);
select is((select sum(amount)::int from public.customer_ledger where customer_id = pg_temp.c('A')), 11000,
          'balance is the sum of charges and payments');
select throws_ok(
  $$ insert into public.customer_ledger (tenant_id, customer_id, kind, amount)
     values (md5('t:A')::uuid, md5('c:A')::uuid, 'payment', 500) $$,
  '23514', null, 'a payment must be negative');
select throws_ok(
  $$ delete from public.customer_ledger $$, '55000', null, 'ledger rows cannot be deleted');

-- clients never write
set local role authenticated;
select throws_ok(
  $$ insert into public.customers (tenant_id, name) values (md5('t:A')::uuid, 'x') $$,
  '42501', null, 'clients cannot insert customers directly');
reset role;

select * from finish();
rollback;
