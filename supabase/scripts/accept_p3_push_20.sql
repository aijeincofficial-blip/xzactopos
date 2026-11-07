-- P3-08 server-side acceptance: push 20 sales (one deliberately bad) twice through sync_push and count what the server holds.
-- Runs inside a transaction that is rolled back, so the dev data is untouched.
--   docker exec -i supabase_db_xzactopos psql -U postgres -d postgres < supabase/scripts/accept_p3_push_20.sql
begin;

create temp table ctx as
select p.user_id, p.tenant_id,
       (select v.id from public.product_variants v where v.tenant_id = p.tenant_id and v.deleted_at is null order by v.created_at limit 1) as variant_id
from public.profiles p
where p.role = 'superadmin' and p.tenant_id is not null
  and exists (select 1 from public.product_variants v where v.tenant_id = p.tenant_id and v.deleted_at is null)
  and exists (select 1 from public.locations l where l.tenant_id = p.tenant_id and l.type = 'store')
order by p.created_at desc limit 1;
grant select on ctx to authenticated;

select set_config('request.jwt.claims',
  jsonb_build_object('sub', user_id, 'role', 'authenticated', 'tenant_id', tenant_id)::text, true) from ctx;
set local role authenticated;

create temp table before_counts as
select (select count(*) from public.sales) as sales, (select count(*) from public.stock_movements) as moves;
grant all on before_counts to authenticated;

-- 20 cash sales of 2 x 12.00 (24.00 each); op 13 is bad (quantity 0) and must be refused without stopping the rest
create temp table ops as
select jsonb_agg(jsonb_build_object(
  'op_id', md5('acceptance-op-' || n)::uuid,
  'kind', 'record_sale',
  'payload', jsonb_build_object(
    'id', md5('acceptance-sale-' || n)::uuid,
    'local_no', 'ACC-' || lpad(n::text, 4, '0'),
    'sold_at', now(),
    'items', jsonb_build_array(jsonb_build_object(
      'variant_id', (select variant_id from ctx), 'qty', case when n = 13 then 0 else 2 end, 'unit_price', 1200)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 2400, 'tendered', 5000))
  )) order by n) as batch
from generate_series(1, 20) n;
grant select on ops to authenticated;

create temp table r1 as select public.sync_push((select batch from ops)) as r;
create temp table r2 as select public.sync_push((select batch from ops)) as r;
grant select on r1, r2 to authenticated;

select 'first push statuses' as what,
       (select count(*) from r1, jsonb_array_elements(r) x where x ->> 'status' = 'ok') as ok,
       (select count(*) from r1, jsonb_array_elements(r) x where x ->> 'status' = 'rejected') as rejected;
select 'second push (retry) replays' as what,
       (select count(*) from r2, jsonb_array_elements(r) x where x -> 'result' ->> 'replay' = 'true') as replays,
       (select count(*) from r2, jsonb_array_elements(r) x where x ->> 'status' = 'rejected') as rejected;
select 'new sales' as what, (select count(*) from public.sales) - sales as n, 'expected 19' as note from before_counts;
select 'new sale movements' as what, (select count(*) from public.stock_movements) - moves as n, 'expected 19' as note from before_counts;
select 'total of the new sales' as what, sum(total) as centavos, 'expected 45600 (19 x 2400)' as note from public.sales where local_no like 'ACC-%';
select 'stock taken' as what, -sum(qty_delta) as qty, 'expected 38 (19 x 2)' as note from public.stock_movements where ref_type = 'sale' and ref_id in (select id from public.sales where local_no like 'ACC-%');

reset role;
rollback;
