-- 049_partial_returns.test.sql: Partial item returns, stock restoration, pro-rata cart discount refund, utang credit, and void guard
begin;
select plan(25);

create function pg_temp.tid(p text) returns uuid language sql immutable
  as $$ select md5('pr_tenant:' || p)::uuid $$;

create function pg_temp.uid(p_tenant text, p_user text) returns uuid language sql immutable
  as $$ select md5('pr_user:' || p_tenant || ':' || p_user)::uuid $$;

create function pg_temp.lid(p_tenant text, p_code text) returns uuid language sql immutable
  as $$ select md5('pr_loc:' || p_tenant || ':' || p_code)::uuid $$;

create function pg_temp.vid(p_tenant text, p_sku text) returns uuid language sql immutable
  as $$ select md5('pr_var:' || p_tenant || ':' || p_sku)::uuid $$;

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

-- Seed tenant, store, products, customer, and staff
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.tid('T'), 'Return Test Store', 'return-test-store', 'PHP', 'Asia/Manila');

insert into public.tenant_modules (tenant_id, pos, warehouse) values
  (pg_temp.tid('T'), true, false);

insert into public.tenant_settings (tenant_id, cashier_can_void_own, max_cashier_void_amount) values
  (pg_temp.tid('T'), true, 50000);

insert into public.locations (id, tenant_id, code, name, type) values
  (pg_temp.lid('T', 'S1'), pg_temp.tid('T'), 'S01', 'Main Branch', 'store');

insert into public.products (id, tenant_id, name, track_stock) values
  (md5('pr_prod:cola')::uuid, pg_temp.tid('T'), 'Cola 1.5L', true),
  (md5('pr_prod:bread')::uuid, pg_temp.tid('T'), 'Pandesal Pack', true);

insert into public.product_variants (id, tenant_id, product_id, sku, cost) values
  (pg_temp.vid('T', 'COLA'), pg_temp.tid('T'), md5('pr_prod:cola')::uuid, 'COLA-15', 4500),
  (pg_temp.vid('T', 'BREAD'), pg_temp.tid('T'), md5('pr_prod:bread')::uuid, 'BREAD-10', 2500);

insert into public.variant_prices (tenant_id, variant_id, currency, price) values
  (pg_temp.tid('T'), pg_temp.vid('T', 'COLA'), 'PHP', 7000),
  (pg_temp.tid('T'), pg_temp.vid('T', 'BREAD'), 'PHP', 5000);

insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid('T'), pg_temp.lid('T', 'S1'), pg_temp.vid('T', 'COLA'), 20, 'opening', 4500),
  (pg_temp.tid('T'), pg_temp.lid('T', 'S1'), pg_temp.vid('T', 'BREAD'), 20, 'opening', 2500);

insert into public.customers (id, tenant_id, name) values
  (md5('pr_cust:rosa')::uuid, pg_temp.tid('T'), 'Aling Rosa');

insert into auth.users (id, email) values
  (pg_temp.uid('T', 'owner'), 'owner@pr.test'),
  (pg_temp.uid('T', 'cashier1'), 'c1@pr.test'),
  (pg_temp.uid('T', 'cashier2'), 'c2@pr.test');

insert into public.profiles (user_id, tenant_id, role, username) values
  (pg_temp.uid('T', 'owner'), pg_temp.tid('T'), 'superadmin', 'owner'),
  (pg_temp.uid('T', 'cashier1'), pg_temp.tid('T'), 'cashier', 'cashier1'),
  (pg_temp.uid('T', 'cashier2'), pg_temp.tid('T'), 'cashier', 'cashier2');

insert into public.location_access (user_id, location_id, tenant_id) values
  (pg_temp.uid('T', 'cashier1'), pg_temp.lid('T', 'S1'), pg_temp.tid('T')),
  (pg_temp.uid('T', 'cashier2'), pg_temp.lid('T', 'S1'), pg_temp.tid('T'));

-- 1. Cashier1 sells 3x Cola (21,000) + 1x Bread (5,000) = 26,000 subtotal - 2,600 cart discount (10%) = 23,400 net cash
select pg_temp.login('T', 'cashier1', 'cashier', array[pg_temp.lid('T', 'S1')]);

select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:sale:1')::uuid,
      'kind', 'record_sale',
      'payload', jsonb_build_object(
        'id', md5('pr_sale:1')::uuid,
        'local_no', 'S01-RET-001',
        'location_id', pg_temp.lid('T', 'S1'),
        'sold_at', now(),
        'subtotal', 26000,
        'discount', 2600,
        'total', 23400,
        'items', jsonb_build_array(
          jsonb_build_object('variant_id', pg_temp.vid('T', 'COLA'), 'qty', 3, 'unit_price', 7000, 'line_total', 21000),
          jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 1, 'unit_price', 5000, 'line_total', 5000)
        ),
        'payments', jsonb_build_array(
          jsonb_build_object('method', 'cash', 'amount', 23400, 'tendered', 25000)
        )
      )
    ))),
    '0', 'status'
  ),
  'ok',
  '1. Cashier1 records discounted multi-item cash sale'
);

-- Stock after sale: Cola = 17, Bread = 19
select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('T', 'S1') and variant_id = pg_temp.vid('T', 'COLA')),
  17.000::numeric(12,3),
  '2. Cola stock reduced from 20 to 17 after sale'
);

-- 3. Cashier2 cannot return Cashier1's sale
select pg_temp.login('T', 'cashier2', 'cashier', array[pg_temp.lid('T', 'S1')]);

select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:ret:denied')::uuid,
      'kind', 'return_sale_items',
      'payload', jsonb_build_object(
        'sale_id', md5('pr_sale:1')::uuid,
        'refund_method', 'cash',
        'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'COLA'), 'qty', 1))
      )
    ))),
    '0', 'hint'
  ),
  'not_allowed',
  '3. Another cashier cannot return items from Cashier1 sale'
);

-- 4. Cashier1 returns 1x Cola -> pro-rata refund = 7000 - 700 (10% cart discount) = 6300
select pg_temp.login('T', 'cashier1', 'cashier', array[pg_temp.lid('T', 'S1')]);

select is(
  (public.sync_push(jsonb_build_array(jsonb_build_object(
    'op_id', md5('pr_op:ret:1')::uuid,
    'kind', 'return_sale_items',
    'payload', jsonb_build_object(
      'sale_id', md5('pr_sale:1')::uuid,
      'refund_method', 'cash',
      'reason', 'Customer changed mind on 1 bottle',
      'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'COLA'), 'qty', 1))
    )
  ))) -> 0 -> 'result' ->> 'refund_total')::bigint,
  6300::bigint,
  '4. Partial return of 1x Cola computes exact pro-rata refund (6,300 centavos)'
);

-- 5. Stock restored by +1 (17 -> 18)
select is(
  (select qty_on_hand from public.stock_levels where location_id = pg_temp.lid('T', 'S1') and variant_id = pg_temp.vid('T', 'COLA')),
  18.000::numeric(12,3),
  '5. Cola stock restored from 17 to 18 on partial return'
);

-- Fire deferred sale rollup trigger so daily_sales_summary reflects the sale before partial return check
set constraints all immediate;

-- 6. Daily sales summary net & cash adjusted (23,400 - 6,300 = 17,100) while txn_count stays 1
select is(
  (select net from public.daily_sales_summary where location_id = pg_temp.lid('T', 'S1') limit 1),
  17100::bigint,
  '6. daily_sales_summary.net reduced by 6,300 to 17,100'
);

select is(
  (select txn_count from public.daily_sales_summary where location_id = pg_temp.lid('T', 'S1') limit 1),
  1,
  '7. daily_sales_summary.txn_count remains 1 on partial return'
);

-- 8. Over-return guard: returning 3 more Colas (when only 2 remain) is rejected with return_exceeds_sold
select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:ret:over')::uuid,
      'kind', 'return_sale_items',
      'payload', jsonb_build_object(
        'sale_id', md5('pr_sale:1')::uuid,
        'refund_method', 'cash',
        'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'COLA'), 'qty', 3))
      )
    ))),
    '0', 'hint'
  ),
  'return_exceeds_sold',
  '8. Returning more than remaining sold quantity is rejected with return_exceeds_sold'
);

-- 9. Full void_sale is blocked once partial returns exist (has_partial_returns)
select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:void:blocked')::uuid,
      'kind', 'void_sale',
      'payload', jsonb_build_object('sale_id', md5('pr_sale:1')::uuid, 'reason', 'full cancel')
    ))),
    '0', 'hint'
  ),
  'has_partial_returns',
  '9. Full void_sale is blocked with has_partial_returns once partial returns exist'
);

-- 10. Returning all remaining items (2x Cola + 1x Bread) reconciles exact remainder (23,400 - 6,300 = 17,100)
select is(
  (public.sync_push(jsonb_build_array(jsonb_build_object(
    'op_id', md5('pr_op:ret:rest')::uuid,
    'kind', 'return_sale_items',
    'payload', jsonb_build_object(
      'sale_id', md5('pr_sale:1')::uuid,
      'refund_method', 'cash',
      'items', jsonb_build_array(
        jsonb_build_object('variant_id', pg_temp.vid('T', 'COLA'), 'qty', 2),
        jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 1)
      )
    )
  ))) -> 0 -> 'result' ->> 'refund_total')::bigint,
  17100::bigint,
  '10. Returning remaining items reconciles exact remaining sale total (17,100) with zero drift'
);

-- 11. Utang sale + partial utang return credits customer_ledger
select pg_temp.login('T', 'owner', 'superadmin', array[pg_temp.lid('T', 'S1')]);

select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:sale:utang')::uuid,
      'kind', 'record_sale',
      'payload', jsonb_build_object(
        'id', md5('pr_sale:2')::uuid,
        'local_no', 'S01-RET-002',
        'location_id', pg_temp.lid('T', 'S1'),
        'customer_id', md5('pr_cust:rosa')::uuid,
        'sold_at', now(),
        'subtotal', 10000,
        'discount', 0,
        'total', 10000,
        'items', jsonb_build_array(
          jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 2, 'unit_price', 5000, 'line_total', 10000)
        ),
        'payments', jsonb_build_array(
          jsonb_build_object('method', 'utang', 'amount', 10000)
        )
      )
    ))),
    '0', 'status'
  ),
  'ok',
  '11. Owner records 2x Bread utang sale for Aling Rosa (10,000)'
);

select is(
  (public.sync_push(jsonb_build_array(jsonb_build_object(
    'op_id', md5('pr_op:ret:utang')::uuid,
    'kind', 'return_sale_items',
    'payload', jsonb_build_object(
      'sale_id', md5('pr_sale:2')::uuid,
      'refund_method', 'utang',
      'reason', '1 pack stale',
      'items', jsonb_build_array(
        jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 1)
      )
    )
  ))) -> 0 -> 'result' ->> 'refund_total')::bigint,
  5000::bigint,
  '12. Returning 1x Bread on utang refunds 5,000'
);

select is(
  (select coalesce(sum(amount), 0)::bigint from public.customer_ledger where customer_id = md5('pr_cust:rosa')::uuid),
  5000::bigint,
  '13. Aling Rosa utang balance reduced from 10,000 to 5,000'
);

-- 14. Append-only ledger guard prevents updating or deleting sale_returns
select throws_ok(
  $$ delete from public.sale_returns where tenant_id = pg_temp.tid('T') $$,
  '55000',
  null,
  '14. sale_returns is append-only (rejects delete)'
);

-- ---------------------------------------------------------------------------
-- S07 Return tender validation (paid vs utang)
-- ---------------------------------------------------------------------------

-- 15-17. Unpaid utang sale (pr_sale:2 has 5,000 remaining utang, 0 paid): reject cash, ewallet, card refunds
select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:ret:utang_as_cash')::uuid,
      'kind', 'return_sale_items',
      'payload', jsonb_build_object(
        'sale_id', md5('pr_sale:2')::uuid,
        'refund_method', 'cash',
        'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 1))
      )
    ))),
    '0', 'hint'
  ),
  'return_paid_exceeds',
  '15. Returning pure utang sale as cash is rejected with return_paid_exceeds'
);

select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:ret:utang_as_ewallet')::uuid,
      'kind', 'return_sale_items',
      'payload', jsonb_build_object(
        'sale_id', md5('pr_sale:2')::uuid,
        'refund_method', 'ewallet',
        'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 1))
      )
    ))),
    '0', 'hint'
  ),
  'return_paid_exceeds',
  '16. Returning pure utang sale as ewallet is rejected with return_paid_exceeds'
);

select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:ret:utang_as_card')::uuid,
      'kind', 'return_sale_items',
      'payload', jsonb_build_object(
        'sale_id', md5('pr_sale:2')::uuid,
        'refund_method', 'card',
        'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 1))
      )
    ))),
    '0', 'hint'
  ),
  'return_paid_exceeds',
  '17. Returning pure utang sale as card is rejected with return_paid_exceeds'
);

-- 18-19. Named-customer pure cash sale rejects utang refund
select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:sale:cash_cust')::uuid,
      'kind', 'record_sale',
      'payload', jsonb_build_object(
        'id', md5('pr_sale:3')::uuid,
        'local_no', 'S01-RET-003',
        'location_id', pg_temp.lid('T', 'S1'),
        'customer_id', md5('pr_cust:rosa')::uuid,
        'sold_at', now(),
        'subtotal', 10000,
        'discount', 0,
        'total', 10000,
        'items', jsonb_build_array(
          jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 2, 'unit_price', 5000, 'line_total', 10000)
        ),
        'payments', jsonb_build_array(
          jsonb_build_object('method', 'cash', 'amount', 10000, 'tendered', 10000)
        )
      )
    ))),
    '0', 'status'
  ),
  'ok',
  '18. Owner records named-customer pure cash sale (10,000)'
);

select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:ret:cash_as_utang')::uuid,
      'kind', 'return_sale_items',
      'payload', jsonb_build_object(
        'sale_id', md5('pr_sale:3')::uuid,
        'refund_method', 'utang',
        'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 1))
      )
    ))),
    '0', 'hint'
  ),
  'return_utang_exceeds',
  '19. Returning pure cash sale as utang (even with customer attached) is rejected with return_utang_exceeds'
);

-- 20-25. Split-tender sale (5,000 cash + 10,000 utang = 15,000): enforce per-pool remaining allowances
select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:sale:split')::uuid,
      'kind', 'record_sale',
      'payload', jsonb_build_object(
        'id', md5('pr_sale:4')::uuid,
        'local_no', 'S01-RET-004',
        'location_id', pg_temp.lid('T', 'S1'),
        'customer_id', md5('pr_cust:rosa')::uuid,
        'sold_at', now(),
        'subtotal', 15000,
        'discount', 0,
        'total', 15000,
        'items', jsonb_build_array(
          jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 3, 'unit_price', 5000, 'line_total', 15000)
        ),
        'payments', jsonb_build_array(
          jsonb_build_object('method', 'cash', 'amount', 5000, 'tendered', 5000),
          jsonb_build_object('method', 'utang', 'amount', 10000)
        )
      )
    ))),
    '0', 'status'
  ),
  'ok',
  '20. Owner records split-tender sale (5,000 cash + 10,000 utang)'
);

select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:ret:split_over_cash')::uuid,
      'kind', 'return_sale_items',
      'payload', jsonb_build_object(
        'sale_id', md5('pr_sale:4')::uuid,
        'refund_method', 'cash',
        'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 2))
      )
    ))),
    '0', 'hint'
  ),
  'return_paid_exceeds',
  '21. Split-tender sale rejects cash refund exceeding settled cash portion (10,000 > 5,000)'
);

select is(
  (public.sync_push(jsonb_build_array(jsonb_build_object(
    'op_id', md5('pr_op:ret:split_ok_cash')::uuid,
    'kind', 'return_sale_items',
    'payload', jsonb_build_object(
      'sale_id', md5('pr_sale:4')::uuid,
      'refund_method', 'cash',
      'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 1))
    )
  ))) -> 0 -> 'result' ->> 'refund_total')::bigint,
  5000::bigint,
  '22. Split-tender sale allows cash refund up to settled cash portion (5,000)'
);

select is(
  jsonb_extract_path_text(
    public.sync_push(jsonb_build_array(jsonb_build_object(
      'op_id', md5('pr_op:ret:split_exhausted_cash')::uuid,
      'kind', 'return_sale_items',
      'payload', jsonb_build_object(
        'sale_id', md5('pr_sale:4')::uuid,
        'refund_method', 'cash',
        'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 1))
      )
    ))),
    '0', 'hint'
  ),
  'return_paid_exceeds',
  '23. Second cash return after settled portion exhausted is rejected with return_paid_exceeds'
);

select is(
  (public.sync_push(jsonb_build_array(jsonb_build_object(
    'op_id', md5('pr_op:ret:split_ok_utang')::uuid,
    'kind', 'return_sale_items',
    'payload', jsonb_build_object(
      'sale_id', md5('pr_sale:4')::uuid,
      'refund_method', 'utang',
      'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.vid('T', 'BREAD'), 'qty', 2))
    )
  ))) -> 0 -> 'result' ->> 'refund_total')::bigint,
  10000::bigint,
  '24. Split-tender sale allows returning remaining 10,000 to utang'
);

select is(
  (select coalesce(sum(amount), 0)::bigint from public.customer_ledger where customer_id = md5('pr_cust:rosa')::uuid),
  5000::bigint,
  '25. Aling Rosa net utang balance remains 5,000 after full split-sale utang credit'
);

select * from finish();
rollback;
