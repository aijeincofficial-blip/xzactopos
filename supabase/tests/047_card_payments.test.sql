-- 047_card_payments.test.sql: Card tender support in payments, sales RPCs, rollups, and reports
begin;
select plan(14);

-- Fixture helpers
create function pg_temp.tid(p text) returns uuid language sql immutable
  as $$ select md5('tenant:' || p)::uuid $$;

create function pg_temp.uid(p_tenant text, p_user text) returns uuid language sql immutable
  as $$ select md5('user:' || p_tenant || ':' || p_user)::uuid $$;

create function pg_temp.lid(p_tenant text, p_code text) returns uuid language sql immutable
  as $$ select md5('loc:' || p_tenant || ':' || p_code)::uuid $$;

create function pg_temp.vid(p_tenant text, p_sku text) returns uuid language sql immutable
  as $$ select md5('var:' || p_tenant || ':' || p_sku)::uuid $$;

create function pg_temp.login(p_tenant text, p_user text, p_role text, p_locations uuid[] default '{}') returns void language plpgsql as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', pg_temp.uid(p_tenant, p_user),
      'role', 'authenticated',
      'tenant_id', pg_temp.tid(p_tenant),
      'user_role', p_role,
      'location_ids', to_jsonb(p_locations)
    )::text,
    true
  );
end;
$$;

-- Setup tenant, location, and product
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.tid('T0'), 'Constraint Tenant', 'constraint-tenant', 'PHP', 'Asia/Manila'),
  (pg_temp.tid('T'), 'Card Store Co', 'card-store', 'PHP', 'Asia/Manila');

insert into public.tenant_modules (tenant_id, pos, inventory) values
  (pg_temp.tid('T'), true, true);

insert into public.locations (id, tenant_id, code, name, type) values
  (pg_temp.lid('T0', 'S0'), pg_temp.tid('T0'), 'S0', 'Dummy Store', 'store'),
  (pg_temp.lid('T', 'S1'), pg_temp.tid('T'), 'S1', 'Main Store', 'store');

insert into public.products (id, tenant_id, name, track_stock) values
  (md5('p:T:shirt')::uuid, pg_temp.tid('T'), 'Graphic T-Shirt', true);

insert into public.product_variants (id, tenant_id, product_id, sku, cost) values
  (pg_temp.vid('T', 'TSHIRT-L'), pg_temp.tid('T'), md5('p:T:shirt')::uuid, 'TSHIRT-L', 6000);

insert into public.variant_prices (tenant_id, variant_id, currency, price) values
  (pg_temp.tid('T'), pg_temp.vid('T', 'TSHIRT-L'), 'PHP', 10000);

insert into public.stock_levels (tenant_id, location_id, variant_id, qty_on_hand) values
  (pg_temp.tid('T'), pg_temp.lid('T', 'S1'), pg_temp.vid('T', 'TSHIRT-L'), 100);

-- Users & profiles
insert into auth.users (id, email) values
  (pg_temp.uid('T', 'cashier1'), 'cashier1@test.invalid'),
  (pg_temp.uid('T', 'owner'), 'owner@test.invalid');

insert into public.profiles (user_id, tenant_id, role, username) values
  (pg_temp.uid('T', 'cashier1'), pg_temp.tid('T'), 'cashier', 'cashier_one'),
  (pg_temp.uid('T', 'owner'), pg_temp.tid('T'), 'superadmin', 'owner_t');

insert into public.location_access (user_id, location_id, tenant_id) values
  (pg_temp.uid('T', 'cashier1'), pg_temp.lid('T', 'S1'), pg_temp.tid('T'));

-- 1. Constraint check: direct insert with method 'card' succeeds
insert into public.sales (id, tenant_id, location_id, local_no, subtotal, discount, tax, total, sold_at)
values (md5('dummy:sale')::uuid, pg_temp.tid('T0'), pg_temp.lid('T0', 'S0'), 'DUM-001', 10000, 0, 0, 10000, now());

select lives_ok(
  $$ insert into public.payments (tenant_id, sale_id, location_id, method, amount, reference)
     values (pg_temp.tid('T0'), md5('dummy:sale')::uuid, pg_temp.lid('T0', 'S0'), 'card', 10000, 'REF-123') $$,
  '1. Payments table allows method = card'
);

-- 2. Constraint check: invalid method is rejected
select throws_ok(
  $$ insert into public.payments (tenant_id, sale_id, location_id, method, amount)
     values (pg_temp.tid('T0'), md5('dummy:sale')::uuid, pg_temp.lid('T0', 'S0'), 'crypto', 10000) $$,
  '23514',
  NULL,
  '2. Payments table rejects invalid payment method (e.g. crypto)'
);

-- 3. Constraint check: tendered is only allowed for cash
select throws_ok(
  $$ insert into public.payments (tenant_id, sale_id, location_id, method, amount, tendered)
     values (pg_temp.tid('T0'), md5('dummy:sale')::uuid, pg_temp.lid('T0', 'S0'), 'card', 10000, 10000) $$,
  '23514',
  NULL,
  '3. Payments table rejects tendered amount for non-cash method (card)'
);

-- (No manual deletion needed; rollback handles cleanup)

-- Login as cashier at S1
select pg_temp.login('T', 'cashier1', 'cashier', array[pg_temp.lid('T', 'S1')]);

-- 4. Record 100% card sale via sync_push
select results_eq(
  $$ select jsonb_extract_path_text(
       public.sync_push(jsonb_build_array(
         jsonb_build_object(
           'op_id', md5('op:sale:card:1')::uuid,
           'kind', 'record_sale',
           'payload', jsonb_build_object(
             'id', md5('sale:card:1')::uuid,
             'local_no', 'RCPT-CARD-001',
             'location_id', pg_temp.lid('T', 'S1'),
             'sold_at', now(),
             'items', jsonb_build_array(
               jsonb_build_object(
                 'variant_id', pg_temp.vid('T', 'TSHIRT-L'),
                 'qty', 1,
                 'unit_price', 10000,
                 'line_total', 10000
               )
             ),
             'payments', jsonb_build_array(
               jsonb_build_object(
                 'method', 'card',
                 'amount', 10000,
                 'reference', 'TRACE-998877'
               )
             )
           )
         )
       )),
       '0', 'status'
     ) $$,
  $$ values ('ok') $$,
  '4. sync_push record_sale succeeds with 100% card payment'
);

-- Force deferred rollup triggers to execute
set constraints all immediate;
set constraints all deferred;

-- 5. Payments row verification
select results_eq(
  $$ select method, amount, reference
     from public.payments
     where sale_id = md5('sale:card:1')::uuid $$,
  $$ values ('card'::text, 10000::bigint, 'TRACE-998877'::text) $$,
  '5. Payments row recorded card method, exact amount, and trace reference'
);

-- 6. daily_sales_summary accumulated card sales (superadmin view)
select pg_temp.login('T', 'owner', 'superadmin', array[pg_temp.lid('T', 'S1')]);

select results_eq(
  $$ select cash, ewallet, card
     from public.daily_sales_summary
     where tenant_id = pg_temp.tid('T') and location_id = pg_temp.lid('T', 'S1') $$,
  $$ values (0::bigint, 0::bigint, 10000::bigint) $$,
  '6. daily_sales_summary tracks card sales (10000) and zero cash/ewallet'
);

-- 7. shift_server_expected is 0 (card does not affect cash drawer)
select pg_temp.login('T', 'cashier1', 'cashier', array[pg_temp.lid('T', 'S1')]);

select results_eq(
  $$ select public.shift_server_expected(
       pg_temp.tid('T'),
       pg_temp.lid('T', 'S1'),
       pg_temp.uid('T', 'cashier1'),
       now() - interval '1 hour',
       now() + interval '1 hour',
       0::bigint
     ) $$,
  $$ values (0::bigint) $$,
  '7. shift_server_expected remains 0 (card payment does not affect physical drawer)'
);

-- 8. Split sale: cash 5000 + ewallet 3000 + card 2000
select results_eq(
  $$ select jsonb_extract_path_text(
       public.sync_push(jsonb_build_array(
         jsonb_build_object(
           'op_id', md5('op:sale:split:2')::uuid,
           'kind', 'record_sale',
           'payload', jsonb_build_object(
             'id', md5('sale:split:2')::uuid,
             'local_no', 'RCPT-SPLIT-002',
             'location_id', pg_temp.lid('T', 'S1'),
             'sold_at', now(),
             'items', jsonb_build_array(
               jsonb_build_object(
                 'variant_id', pg_temp.vid('T', 'TSHIRT-L'),
                 'qty', 1,
                 'unit_price', 10000,
                 'line_total', 10000
               )
             ),
             'payments', jsonb_build_array(
               jsonb_build_object('method', 'cash', 'amount', 5000, 'tendered', 5000),
               jsonb_build_object('method', 'ewallet', 'amount', 3000, 'wallet', 'gcash'),
               jsonb_build_object('method', 'card', 'amount', 2000, 'reference', 'AUTH-4433')
             )
           )
         )
       )),
       '0', 'status'
     ) $$,
  $$ values ('ok') $$,
  '8. sync_push record_sale succeeds with split tender (cash + ewallet + card)'
);

-- Force deferred rollup triggers to execute
set constraints all immediate;
set constraints all deferred;

-- 9. daily_sales_summary accumulated all tenders
select pg_temp.login('T', 'owner', 'superadmin', array[pg_temp.lid('T', 'S1')]);

select results_eq(
  $$ select cash, ewallet, card
     from public.daily_sales_summary
     where tenant_id = pg_temp.tid('T') and location_id = pg_temp.lid('T', 'S1') $$,
  $$ values (5000::bigint, 3000::bigint, 12000::bigint) $$,
  '9. daily_sales_summary reflects cash=5000, ewallet=3000, card=12000'
);

-- 10. report_summary totals include card
select results_eq(
  $$ select (public.report_summary((now() at time zone 'Asia/Manila')::date, (now() at time zone 'Asia/Manila')::date) -> 'totals' ->> 'card')::bigint,
            (public.report_summary((now() at time zone 'Asia/Manila')::date, (now() at time zone 'Asia/Manila')::date) -> 'totals' ->> 'cash')::bigint,
            (public.report_summary((now() at time zone 'Asia/Manila')::date, (now() at time zone 'Asia/Manila')::date) -> 'totals' ->> 'ewallet')::bigint $$,
  $$ values (12000::bigint, 5000::bigint, 3000::bigint) $$,
  '10. report_summary totals include card (12000), cash (5000), and ewallet (3000)'
);

-- 11. report_summary days array includes card
select results_eq(
  $$ select (public.report_summary((now() at time zone 'Asia/Manila')::date, (now() at time zone 'Asia/Manila')::date) -> 'days' -> 0 ->> 'card')::bigint $$,
  $$ values (12000::bigint) $$,
  '11. report_summary days[0] includes card sales'
);

-- 12. report_multi_store totals include card
select results_eq(
  $$ select (public.report_multi_store((now() at time zone 'Asia/Manila')::date, (now() at time zone 'Asia/Manila')::date) -> 'totals' ->> 'card')::bigint,
            (public.report_multi_store((now() at time zone 'Asia/Manila')::date, (now() at time zone 'Asia/Manila')::date) -> 'totals' ->> 'cash')::bigint,
            (public.report_multi_store((now() at time zone 'Asia/Manila')::date, (now() at time zone 'Asia/Manila')::date) -> 'totals' ->> 'ewallet')::bigint $$,
  $$ values (12000::bigint, 5000::bigint, 3000::bigint) $$,
  '12. report_multi_store totals include card sales'
);

-- 13. report_multi_store days array includes card
select results_eq(
  $$ select (public.report_multi_store((now() at time zone 'Asia/Manila')::date, (now() at time zone 'Asia/Manila')::date) -> 'days' -> 0 ->> 'card')::bigint $$,
  $$ values (12000::bigint) $$,
  '13. report_multi_store days[0] includes card sales'
);

-- 14. Unknown method rejected in op_record_sale
select results_eq(
  $$ select jsonb_extract_path_text(
       public.sync_push(jsonb_build_array(
         jsonb_build_object(
           'op_id', md5('op:sale:fail:3')::uuid,
           'kind', 'record_sale',
           'payload', jsonb_build_object(
             'id', md5('sale:fail:3')::uuid,
             'local_no', 'RCPT-BAD-003',
             'location_id', pg_temp.lid('T', 'S1'),
             'sold_at', now(),
             'items', jsonb_build_array(
               jsonb_build_object('variant_id', pg_temp.vid('T', 'TSHIRT-L'), 'qty', 1, 'unit_price', 10000, 'line_total', 10000)
             ),
             'payments', jsonb_build_array(
               jsonb_build_object('method', 'bitcoin', 'amount', 10000)
             )
           )
         )
       )),
       '0', 'hint'
     ) $$,
  $$ values ('invalid_value') $$,
  '14. record_sale with unsupported payment method is rejected with invalid_value'
);

rollback;
