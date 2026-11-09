-- P3-02 sync_push (record_sale, void_sale, upsert_customer, record_utang_payment, post_opening_stock) and sync_pull_pos
begin;
select plan(73);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('id:' || p)::uuid $$;

create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;

-- one op and the result of pushing it alone
create function pg_temp.op(k text, kind text, payload jsonb) returns jsonb language sql immutable as $$
  select jsonb_build_object('op_id', pg_temp.id('op:' || k), 'kind', kind, 'payload', payload)
$$;
create function pg_temp.push1(k text, kind text, payload jsonb) returns jsonb language sql as $$
  select public.sync_push(jsonb_build_array(pg_temp.op(k, kind, payload))) -> 0
$$;
-- hint of the error a statement raises (null if it succeeds)
create function pg_temp.hint(p_sql text) returns text language plpgsql as $$
declare h text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics h = pg_exception_hint;
  return coalesce(nullif(h, ''), sqlstate);
end;
$$;

-- payload builders (money in centavos)
create function pg_temp.item(v text, qty numeric, price bigint) returns jsonb language sql immutable as $$
  select jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'qty', qty, 'unit_price', price)
$$;
create function pg_temp.pay(method text, amount bigint, tendered bigint default null) returns jsonb language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object('method', method, 'amount', amount, 'tendered', tendered))
$$;
create function pg_temp.sale(k text, items jsonb, pays jsonb, extra jsonb default '{}') returns jsonb language sql immutable as $$
  select jsonb_build_object('id', pg_temp.id('sale:' || k), 'local_no', 'R-' || k, 'sold_at', '2026-11-08T02:00:00Z',
                            'items', items, 'payments', pays) || extra
$$;

insert into auth.users (id, email)
select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'juan', 'pedro', 'ana', 'ownerB']) n;
insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.t('A'), 'Tenant A', 'tenant-a', 'PHP'), (pg_temp.t('B'), 'Tenant B', 'tenant-b', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.t('A'), true, true), (pg_temp.t('B'), true, false);
insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B'));
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'),  pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'),  pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('juan'),   pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('pedro'),  pg_temp.t('A'), 'pedro', 'warehouse', true),
  (pg_temp.u('ana'),    pg_temp.t('A'), 'ana', 'cashier', false),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'Store 1'),
  (pg_temp.id('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'Warehouse'),
  (pg_temp.id('SB'),  pg_temp.t('B'), 'store', 'MAIN', 'B store');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null),
  (pg_temp.u('juan'),  pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('ana'),   pg_temp.id('S01'), pg_temp.t('A'), null);

-- products: kape (tracked, cost 1500), asin (not tracked), and one in tenant B
insert into public.products (id, tenant_id, name, track_stock) values
  (pg_temp.id('p:kape'), pg_temp.t('A'), 'Kape', true),
  (pg_temp.id('p:asin'), pg_temp.t('A'), 'Asin', false),
  (pg_temp.id('p:b'),    pg_temp.t('B'), 'B item', true);
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost) values
  (pg_temp.id('v:kape'), pg_temp.t('A'), pg_temp.id('p:kape'), 'KAPE', true, 1500),
  (pg_temp.id('v:asin'), pg_temp.t('A'), pg_temp.id('p:asin'), 'ASIN', true, 300),
  (pg_temp.id('v:b'),    pg_temp.t('B'), pg_temp.id('p:b'), 'B1', true, 100);

-- ===========================================================================
-- Owner: opening stock, cash sale
-- ===========================================================================
select pg_temp.login('owner', 'A');
set local role authenticated;

select is(pg_temp.push1('open1', 'post_opening_stock', jsonb_build_object('variant_id', pg_temp.id('v:kape'), 'qty', 10)) ->> 'status',
          'ok', 'opening stock is accepted');
select is((select qty_on_hand from public.stock_levels where variant_id = pg_temp.id('v:kape')), 10::numeric,
          'opening stock raises the level');
select is(pg_temp.push1('open1', 'post_opening_stock', jsonb_build_object('variant_id', pg_temp.id('v:kape'), 'qty', 10)) -> 'result' ->> 'replay',
          'true', 'the same opening op is a replay');
select is((select qty_on_hand from public.stock_levels where variant_id = pg_temp.id('v:kape')), 10::numeric,
          'a replayed opening op adds nothing');

select is(pg_temp.push1('s1', 'record_sale', pg_temp.sale('s1',
            jsonb_build_array(pg_temp.item('kape', 2, 2500)),
            jsonb_build_array(pg_temp.pay('cash', 4500, 5000)),
            '{"discount": 500}')) ->> 'status',
          'ok', 'a cash sale with a discount is accepted');
select is((select total from public.sales where local_no = 'R-s1'), 4500::bigint, 'server total = subtotal - discount');
select is((select tendered from public.payments p join public.sales s on s.id = p.sale_id where s.local_no = 'R-s1'),
          5000::bigint, 'cash tendered is kept (change = 500)');
select is((select qty_on_hand from public.stock_levels where variant_id = pg_temp.id('v:kape')), 8::numeric,
          'the sale took 2 from stock');
select is((select unit_cost from public.sale_items i join public.sales s on s.id = i.sale_id where s.local_no = 'R-s1'),
          1500::bigint, 'cost is snapshotted on the line');

-- retry of the same op: same result flagged replay, nothing added
select is(pg_temp.push1('s1', 'record_sale', pg_temp.sale('s1',
            jsonb_build_array(pg_temp.item('kape', 2, 2500)),
            jsonb_build_array(pg_temp.pay('cash', 4500, 5000)),
            '{"discount": 500}')) -> 'result' ->> 'replay',
          'true', 'a retried sale returns the stored result');
select is((select count(*)::int from public.sales where tenant_id = pg_temp.t('A')), 1, 'a retried sale adds no second sale');
select is((select count(*)::int from public.stock_movements where ref_type = 'sale'), 1, 'a retried sale adds no second movement');
select is((select qty_on_hand from public.stock_levels where variant_id = pg_temp.id('v:kape')), 8::numeric,
          'a retried sale does not take stock twice');

-- untracked product: sale without a movement
select is(pg_temp.push1('s2', 'record_sale', pg_temp.sale('s2',
            jsonb_build_array(pg_temp.item('asin', 1, 1000)),
            jsonb_build_array(pg_temp.pay('ewallet', 1000)))) ->> 'status', 'ok', 'an e-wallet sale is accepted');
select is((select count(*)::int from public.stock_movements where variant_id = pg_temp.id('v:asin')), 0,
          'a product that does not track stock writes no movement');

-- negative stock is accepted
select is(pg_temp.push1('s3', 'record_sale', pg_temp.sale('s3',
            jsonb_build_array(pg_temp.item('kape', 20, 2500)),
            jsonb_build_array(pg_temp.pay('cash', 50000)))) ->> 'status', 'ok', 'selling more than the stock is accepted');
select is((select qty_on_hand from public.stock_levels where variant_id = pg_temp.id('v:kape')), -12::numeric,
          'stock goes negative instead of refusing a sale that already happened');

-- ===========================================================================
-- Refusals (each leaves no rows behind)
-- ===========================================================================
select is(pg_temp.push1('bad1', 'record_sale', pg_temp.sale('bad1',
            jsonb_build_array(pg_temp.item('kape', 1, 2500)), jsonb_build_array(pg_temp.pay('cash', 2400)))) ->> 'hint',
          'payments_mismatch', 'payments that do not cover the total are refused');
select is(pg_temp.push1('bad2', 'record_sale', pg_temp.sale('bad2',
            jsonb_build_array(pg_temp.item('kape', 1, 2500)), jsonb_build_array(pg_temp.pay('cash', 2500)), '{"total": 2000}')) ->> 'hint',
          'totals_mismatch', 'a client total that disagrees is refused');
select is(pg_temp.push1('bad3', 'record_sale', pg_temp.sale('bad3',
            jsonb_build_array(pg_temp.item('kape', 1, 2500)), jsonb_build_array(pg_temp.pay('utang', 2500)))) ->> 'hint',
          'customer_required', 'utang without a customer is refused');
select is(pg_temp.push1('bad4', 'record_sale', pg_temp.sale('bad4',
            jsonb_build_array(pg_temp.item('kape', 1, 2500)), jsonb_build_array(pg_temp.pay('utang', 2500)),
            jsonb_build_object('customer_id', pg_temp.id('nobody')))) ->> 'hint',
          'unknown_customer', 'utang for an unknown customer is refused');
select is(pg_temp.push1('bad5', 'record_sale', pg_temp.sale('bad5',
            jsonb_build_array(pg_temp.item('b', 1, 100)), jsonb_build_array(pg_temp.pay('cash', 100)))) ->> 'hint',
          'unknown_variant', 'another tenant''s product cannot be sold');
select is(pg_temp.push1('bad6', 'record_sale', pg_temp.sale('bad6',
            jsonb_build_array(pg_temp.item('kape', 0, 100)), jsonb_build_array(pg_temp.pay('cash', 100)))) ->> 'hint',
          'qty_invalid', 'a zero quantity is refused');
select is(pg_temp.push1('bad7', 'record_sale', pg_temp.sale('bad7', '[]', '[]')) ->> 'hint',
          'items_required', 'a sale with no items is refused');
select is(pg_temp.push1('bad8', 'record_sale', pg_temp.sale('dup',
            jsonb_build_array(pg_temp.item('kape', 1, 2500)), jsonb_build_array(pg_temp.pay('cash', 2500)), '{"local_no": "R-s1"}')) ->> 'hint',
          'duplicate_local_no', 'a receipt number used twice is refused');
select is(pg_temp.push1('bad9', 'launch_missiles', '{}') ->> 'hint', 'unknown_kind', 'an unknown op kind is refused');
select is((select count(*)::int from public.sales where local_no like 'R-bad%'), 0, 'refused sales leave no rows');
select is(pg_temp.push1('bad1', 'record_sale', pg_temp.sale('bad1',
            jsonb_build_array(pg_temp.item('kape', 1, 2500)), jsonb_build_array(pg_temp.pay('cash', 2400)))) ->> 'status', 'rejected',
          'a refused op is refused again on retry (its claim was rolled back)');

select is(pg_temp.hint($$ select public.sync_push('[]'::jsonb) $$), 'batch_invalid', 'an empty batch is refused');
select is(pg_temp.hint($$ select public.sync_push((select jsonb_agg('{}'::jsonb) from generate_series(1, 51))) $$),
          'batch_invalid', 'a batch over 50 ops is refused');

-- ===========================================================================
-- Mixed batch: one failure in the middle does not stop the others
-- ===========================================================================
create temp table batch_result as
select public.sync_push(jsonb_build_array(
  pg_temp.op('b1', 'record_sale', pg_temp.sale('b1', jsonb_build_array(pg_temp.item('kape', 1, 2500)), jsonb_build_array(pg_temp.pay('cash', 2500)))),
  pg_temp.op('b2', 'record_sale', pg_temp.sale('b2', jsonb_build_array(pg_temp.item('kape', 1, 2500)), jsonb_build_array(pg_temp.pay('cash', 1)))),
  pg_temp.op('b3', 'record_sale', pg_temp.sale('b3', jsonb_build_array(pg_temp.item('kape', 1, 2500)), jsonb_build_array(pg_temp.pay('cash', 2500))))
)) as r;
grant all on batch_result to authenticated;

select is((select array_agg(x ->> 'status' order by ord) from batch_result, jsonb_array_elements(r) with ordinality a(x, ord)),
          array['ok', 'rejected', 'ok'], 'a bad op in the middle of a batch does not block the others');
select is((select count(*)::int from public.sales where local_no in ('R-b1', 'R-b2', 'R-b3')), 2, 'only the good ops were applied');

-- ===========================================================================
-- Utang: customer, charge, payment
-- ===========================================================================
select is(pg_temp.push1('c1', 'upsert_customer', jsonb_build_object('id', pg_temp.id('cus1'), 'name', 'Aling Rosa', 'phone', '0917')) ->> 'status',
          'ok', 'a customer is created');
select is(pg_temp.push1('c1b', 'upsert_customer', jsonb_build_object('id', pg_temp.id('cus1'), 'name', 'Aling Rosa Santos')) ->> 'status',
          'ok', 'the same customer id updates the name');
select is((select name from public.customers where id = pg_temp.id('cus1')), 'Aling Rosa Santos', 'name was updated');
select is(pg_temp.push1('c2', 'upsert_customer', jsonb_build_object('id', pg_temp.id('cus2'), 'name', '  ')) ->> 'hint',
          'name_required', 'a blank customer name is refused');

select is(pg_temp.push1('u1', 'record_sale', pg_temp.sale('u1',
            jsonb_build_array(pg_temp.item('kape', 2, 2500)),
            jsonb_build_array(pg_temp.pay('cash', 4000, 4000), pg_temp.pay('utang', 1000)),
            jsonb_build_object('customer_id', pg_temp.id('cus1')))) ->> 'status',
          'ok', 'a sale split between cash and utang is accepted');
select is((select sum(amount)::int from public.customer_ledger where customer_id = pg_temp.id('cus1')), 1000,
          'the utang part is on the customer''s balance');

select is(pg_temp.push1('up1', 'record_utang_payment', jsonb_build_object('customer_id', pg_temp.id('cus1'), 'amount', 400, 'note', 'bayad')) ->> 'status',
          'ok', 'a utang payment is accepted');
select is((select sum(amount)::int from public.customer_ledger where customer_id = pg_temp.id('cus1')), 600, 'the payment lowers the balance');
select is(pg_temp.push1('up1', 'record_utang_payment', jsonb_build_object('customer_id', pg_temp.id('cus1'), 'amount', 400)) -> 'result' ->> 'replay',
          'true', 'a retried utang payment is a replay');
select is((select sum(amount)::int from public.customer_ledger where customer_id = pg_temp.id('cus1')), 600, 'a retried payment does not count twice');
select is(pg_temp.push1('up2', 'record_utang_payment', jsonb_build_object('customer_id', pg_temp.id('cus1'), 'amount', 0)) ->> 'hint',
          'amount_invalid', 'a zero payment is refused');

-- ===========================================================================
-- Void
-- ===========================================================================
select is(pg_temp.push1('v1', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:u1'), 'reason', 'mali')) ->> 'status',
          'ok', 'a sale can be cancelled');
select is((select status from public.sales where local_no = 'R-u1'), 'voided', 'the sale is marked voided');
select is((select sum(amount)::int from public.customer_ledger where customer_id = pg_temp.id('cus1')), -400,
          'cancelling reverses the utang charge (only the 400 payment is left)');
select is((select count(*)::int from public.stock_movements where ref_id = pg_temp.id('sale:u1')), 2, 'cancelling adds one reversing movement');
select is(pg_temp.push1('v2', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:u1'))) -> 'result' ->> 'already',
          'true', 'cancelling twice is a no-op');
select is((select count(*)::int from public.stock_movements where ref_id = pg_temp.id('sale:u1')), 2, 'cancelling twice adds no movements');
select is(pg_temp.push1('v3', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:nope'))) ->> 'hint',
          'sale_not_found', 'cancelling an unknown sale is refused');

-- stock = sum of movements, for every level
select is((select count(*)::int from public.stock_levels l
           where l.qty_on_hand <> (select coalesce(sum(m.qty_delta), 0) from public.stock_movements m
                                   where m.location_id = l.location_id and m.variant_id = l.variant_id)),
          0, 'every stock level equals the sum of its movements');

-- ===========================================================================
-- Other people
-- ===========================================================================
select pg_temp.login('juan', 'A');
select is(pg_temp.push1('j1', 'record_sale', pg_temp.sale('j1', jsonb_build_array(pg_temp.item('kape', 1, 2500)),
            jsonb_build_array(pg_temp.pay('cash', 2500)))) ->> 'status', 'ok', 'a cashier can sell in their store');
select is(pg_temp.push1('j2', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:j1'))) ->> 'hint',
          'not_allowed', 'a cashier cannot cancel a sale');
select is(pg_temp.push1('j3', 'post_opening_stock', jsonb_build_object('variant_id', pg_temp.id('v:kape'), 'qty', 5)) ->> 'hint',
          'not_allowed', 'a cashier cannot set opening stock');

select pg_temp.login('maria', 'A');
select is(pg_temp.push1('m1', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:j1'))) ->> 'status',
          'ok', 'the store manager can cancel a sale');

select pg_temp.login('pedro', 'A');
select is(pg_temp.push1('p1', 'record_sale', pg_temp.sale('p1', jsonb_build_array(pg_temp.item('kape', 1, 2500)),
            jsonb_build_array(pg_temp.pay('cash', 2500)))) ->> 'hint', 'not_allowed', 'warehouse staff cannot sell');

select pg_temp.login('ana', 'A');
select is(pg_temp.hint($$ select public.sync_push(jsonb_build_array(pg_temp.op('a1', 'record_sale', '{}'))) $$),
          '42501', 'a deactivated user cannot push');

select pg_temp.login('ownerB', 'B');
select is(pg_temp.push1('x1', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:s1'))) ->> 'hint',
          'sale_not_found', 'another tenant cannot cancel our sale');
select is(pg_temp.push1('x2', 'upsert_customer', jsonb_build_object('id', pg_temp.id('cus1'), 'name', 'Hijack')) ->> 'hint',
          'id_conflict', 'another tenant cannot take over our customer id');
select is((select name from public.customers where id = pg_temp.id('cus1')), null, 'and cannot even see our customer');
select is(pg_temp.push1('s1', 'record_sale', pg_temp.sale('bs1', jsonb_build_array(pg_temp.item('b', 1, 100)),
            jsonb_build_array(pg_temp.pay('cash', 100)), '{"local_no": "R-s1"}')) ->> 'status', 'ok',
          'the same op id and receipt number in another tenant is a different op');

reset role;

-- ===========================================================================
-- sync_pull_pos
-- ===========================================================================
-- rows are held back for 5 s; age the fixtures (triggers off so the append-only guards stay out of the way)
set local session_replication_role = replica;
update public.stock_levels set updated_at = now() - interval '1 minute';
update public.customers set updated_at = now() - interval '1 minute';
update public.customer_ledger set created_at = now() - interval '1 minute';
set local session_replication_role = origin;

select pg_temp.login('owner', 'A');
set local role authenticated;

select is((public.sync_pull_pos('{}', 100) -> 'stock_levels' -> 'rows' -> 0 ->> 'qty_on_hand')::numeric, -14::numeric,
          'pull returns the stock level');
select is(jsonb_array_length(public.sync_pull_pos('{}', 100) -> 'customers' -> 'rows'), 1, 'pull returns the customer');
select is(jsonb_array_length(public.sync_pull_pos('{}', 100) -> 'customer_ledger' -> 'rows'), 3,
          'pull returns the ledger (charge, payment, reversal)');

create temp table page1 as select public.sync_pull_pos('{}', 2) as r;
grant all on page1 to authenticated;
select is((select r -> 'customer_ledger' ->> 'has_more' from page1), 'true', 'a page smaller than the ledger says there is more');
select is(jsonb_array_length(public.sync_pull_pos(
            jsonb_build_object('customer_ledger', (select r -> 'customer_ledger' -> 'cursor' from page1)), 2) -> 'customer_ledger' -> 'rows'),
          1, 'the next page continues after the cursor');
select is(jsonb_array_length(public.sync_pull_pos(
            jsonb_build_object('customer_ledger', (select r -> 'customer_ledger' -> 'cursor' from page1)), 2) -> 'customer_ledger' -> 'rows') +
          jsonb_array_length((select r -> 'customer_ledger' -> 'rows' from page1)), 3, 'two pages cover every row once');

select pg_temp.login('ownerB', 'B');
select is(jsonb_array_length(public.sync_pull_pos('{}', 100) -> 'customers' -> 'rows'), 0, 'another tenant pulls none of our customers');

select pg_temp.login('pedro', 'A');
select is(jsonb_array_length(public.sync_pull_pos('{}', 100) -> 'customers' -> 'rows'), 0, 'warehouse staff pull no customers');
select is(jsonb_array_length(public.sync_pull_pos('{}', 100) -> 'stock_levels' -> 'rows'), 0, 'warehouse staff pull no store stock');

select pg_temp.login('juan', 'A');
select is(jsonb_array_length(public.sync_pull_pos('{}', 100) -> 'stock_levels' -> 'rows'), 1, 'a cashier pulls their store''s stock');
select is(pg_temp.hint($$ select public.sync_pull_pos('{}', 0) $$), 'invalid_value', 'a bad page size is refused');

reset role;
set local role anon;
select throws_ok($$ select public.sync_push('[]') $$, '42501', null, 'anon cannot call sync_push');
reset role;

select * from finish();
rollback;
