-- ---------------------------------------------------------------------------
-- 051_offline_supervisor_pin_complete.test.sql
-- Card F-06: Complete offline supervisor PIN override parity across close_day,
--            service float moves/voids, partial returns, and action/ref_id binding.
-- ---------------------------------------------------------------------------
begin;
select plan(12);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u051:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t051:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('id051:' || p)::uuid $$;

create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;

create function pg_temp.op(k text, kind text, payload jsonb) returns jsonb language sql immutable as $$
  select jsonb_build_object('op_id', pg_temp.id('op:' || k), 'kind', kind, 'payload', payload)
$$;

create function pg_temp.push1(k text, kind text, payload jsonb) returns jsonb language sql as $$
  select public.sync_push(jsonb_build_array(pg_temp.op(k, kind, payload))) -> 0
$$;

create function pg_temp.offline_appr(p_user text, p_action text, p_ref uuid) returns jsonb language sql stable as $$
  with info as (
    select p.pin_hash, to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') as approved_at
    from public.profiles p where p.user_id = pg_temp.u(p_user)
  )
  select jsonb_build_object(
    'approver_id', pg_temp.u(p_user),
    'approved_at', info.approved_at,
    'action', p_action,
    'ref_id', p_ref,
    'proof', encode(
      extensions.hmac(
        convert_to(
          lower(pg_temp.t('A')::text) || '|' || lower(pg_temp.u(p_user)::text) || '|' || p_action
            || '|' || coalesce(lower(p_ref::text), '') || '|' || info.approved_at,
          'UTF8'
        ),
        decode((string_to_array(info.pin_hash, '$'))[4], 'base64'),
        'sha256'
      ),
      'hex'
    )
  ) from info;
$$;

-- Setup tenant & users
insert into auth.users (id, email)
select pg_temp.u(n), n || '@test051.invalid' from unnest(array['owner', 'maria', 'sara', 'juan']) n;

insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'Tenant 051', 'tenant-051', 'PHP', 'Asia/Manila');

insert into public.tenant_modules (tenant_id, pos, inventory) values
  (pg_temp.t('A'), true, true);

insert into public.tenant_limits (tenant_id) values (pg_temp.t('A'));
insert into public.tenant_settings (tenant_id) values (pg_temp.t('A'));

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'Store 051');

insert into public.profiles (user_id, tenant_id, username, full_name, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'Owner Boss',      'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'Maria Manager',   'admin',      true),
  (pg_temp.u('sara'),  pg_temp.t('A'), 'sara',  'Sara Supervisor', 'admin',      true),
  (pg_temp.u('juan'),  pg_temp.t('A'), 'juan',  'Juan Cashier',    'cashier',    true);

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sara'),  pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'),  pg_temp.id('S01'), pg_temp.t('A'), null);

select pg_temp.login('owner', 'A');
select public.set_my_pin('1111');
select pg_temp.login('maria', 'A');
select public.set_my_pin('2222');
select pg_temp.login('sara', 'A');
select public.set_my_pin('3333');
select pg_temp.login('juan', 'A');
select public.set_my_pin('4444');

select pg_temp.login('owner', 'A');
insert into public.products (id, tenant_id, name, track_stock) values
  (pg_temp.id('prod'), pg_temp.t('A'), 'Rice 5kg', true);
insert into public.product_variants (id, tenant_id, product_id, sku, cost) values
  (pg_temp.id('v:rice'), pg_temp.t('A'), pg_temp.id('prod'), 'RICE5', 20000);
insert into public.variant_prices (tenant_id, variant_id, currency, price) values
  (pg_temp.t('A'), pg_temp.id('v:rice'), 'PHP', 25000);
insert into public.stock_levels (tenant_id, location_id, variant_id, qty_on_hand, avg_cost) values
  (pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('v:rice'), 50, 20000);

-- ---------------------------------------------------------------------------
-- 1. Supervisor offline approval on close_day
-- ---------------------------------------------------------------------------
select pg_temp.login('sara', 'A');

-- 1. Supervisor day close without approval is rejected
select is(
  (pg_temp.push1('dc_no_appr', 'close_day', jsonb_build_object(
    'id', pg_temp.id('dc:1'),
    'location_id', pg_temp.id('S01'),
    'day', to_char(now() at time zone 'Asia/Manila', 'YYYY-MM-DD'),
    'expected_cash', 100000,
    'counted_cash', 100000,
    'opening_cash', 50000
  )) ->> 'hint'),
  'approval_required',
  '1. Supervisor close_day without approval is refused with approval_required'
);

-- 2. Supervisor day close with valid offline approval succeeds
select is(
  (pg_temp.push1('dc_off_appr', 'close_day', jsonb_build_object(
    'id', pg_temp.id('dc:1'),
    'location_id', pg_temp.id('S01'),
    'day', to_char(now() at time zone 'Asia/Manila', 'YYYY-MM-DD'),
    'expected_cash', 100000,
    'counted_cash', 100000,
    'opening_cash', 50000,
    'offline_approval', pg_temp.offline_appr('maria', 'close_day', pg_temp.id('dc:1'))
  )) ->> 'status'),
  'ok',
  '2. Supervisor close_day with offline approval succeeds'
);

-- 3. day_closes records approved_by = Maria
select is(
  (select approved_by from public.day_closes where id = pg_temp.id('dc:1')),
  pg_temp.u('maria'),
  '3. day_closes stores offline approver Maria'
);

-- ---------------------------------------------------------------------------
-- 2. Supervisor offline approval on service float_topup & void_service_txn
-- ---------------------------------------------------------------------------

-- 4. Supervisor float_topup without approval is rejected
select is(
  (pg_temp.push1('svc_no_appr', 'record_service_txn', jsonb_build_object(
    'id', pg_temp.id('svc:1'),
    'location_id', pg_temp.id('S01'),
    'kind', 'float_topup',
    'wallet', 'gcash',
    'amount', 500000
  )) ->> 'hint'),
  'approval_required',
  '4. Supervisor float_topup without approval is refused with approval_required'
);

-- 5. Supervisor float_topup with offline approval succeeds
select is(
  (pg_temp.push1('svc_off_appr', 'record_service_txn', jsonb_build_object(
    'id', pg_temp.id('svc:1'),
    'location_id', pg_temp.id('S01'),
    'kind', 'float_topup',
    'wallet', 'gcash',
    'amount', 500000,
    'offline_approval', pg_temp.offline_appr('sara', 'record_service_txn', pg_temp.id('svc:1'))
  )) ->> 'status'),
  'ok',
  '5. Supervisor float_topup with offline approval succeeds'
);

-- 6. Supervisor void_service_txn with offline approval succeeds
select is(
  (pg_temp.push1('svc_void_off', 'void_service_txn', jsonb_build_object(
    'txn_id', pg_temp.id('svc:1'),
    'reason', 'Wrong wallet selected',
    'offline_approval', pg_temp.offline_appr('maria', 'void_service_txn', pg_temp.id('svc:1'))
  )) ->> 'status'),
  'ok',
  '6. Supervisor void_service_txn with offline approval succeeds'
);

-- 7. service_txns records void_approved_by = Maria
select is(
  (select void_approved_by from public.service_txns where id = pg_temp.id('svc:1')),
  pg_temp.u('maria'),
  '7. service_txns stores void_approved_by = Maria'
);

-- ---------------------------------------------------------------------------
-- 3. Cashier offline approval on partial return (return_sale_items) & binding checks
-- ---------------------------------------------------------------------------
select pg_temp.login('juan', 'A');

-- Record a normal sale first
select is(
  (pg_temp.push1('sale_base', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:1'),
    'local_no', 'R-051-1',
    'location_id', pg_temp.id('S01'),
    'sold_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:rice'), 'qty', 2, 'unit_price', 25000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 50000))
  )) ->> 'status'),
  'ok',
  '8. Cashier records base sale for partial return'
);

-- 9. Cashier self-approval on return_sale_items is rejected (approval_invalid)
select is(
  (pg_temp.push1('ret_self', 'return_sale_items', jsonb_build_object(
    'sale_id', pg_temp.id('sale:1'),
    'refund_method', 'cash',
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:rice'), 'qty', 1)),
    'offline_approval', jsonb_build_object(
      'approver_id', pg_temp.u('juan'),
      'approved_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'action', 'void_sale',
      'ref_id', pg_temp.id('sale:1')
    )
  )) ->> 'hint'),
  'approval_invalid',
  '9. Cashier cannot self-approve return_sale_items offline'
);

-- 10. Cross-action replay (sale_discount approval replayed on void_sale/return) is rejected
select is(
  (pg_temp.push1('ret_wrong_action', 'return_sale_items', jsonb_build_object(
    'sale_id', pg_temp.id('sale:1'),
    'refund_method', 'cash',
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:rice'), 'qty', 1)),
    'offline_approval', pg_temp.offline_appr('sara', 'sale_discount', pg_temp.id('sale:1'))
  )) ->> 'hint'),
  'approval_invalid',
  '10. Offline approval bound to wrong action is rejected'
);

-- 11. Cross-entity replay (approval for different ref_id) is rejected
select is(
  (pg_temp.push1('ret_wrong_ref', 'return_sale_items', jsonb_build_object(
    'sale_id', pg_temp.id('sale:1'),
    'refund_method', 'cash',
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:rice'), 'qty', 1)),
    'offline_approval', pg_temp.offline_appr('sara', 'void_sale', pg_temp.id('sale:other'))
  )) ->> 'hint'),
  'approval_invalid',
  '11. Offline approval bound to wrong ref_id is rejected'
);

-- 12. Valid offline supervisor approval on return_sale_items succeeds
select is(
  (pg_temp.push1('ret_ok', 'return_sale_items', jsonb_build_object(
    'sale_id', pg_temp.id('sale:1'),
    'refund_method', 'cash',
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:rice'), 'qty', 1)),
    'offline_approval', pg_temp.offline_appr('sara', 'void_sale', pg_temp.id('sale:1'))
  )) ->> 'status'),
  'ok',
  '12. Cashier return_sale_items with valid offline supervisor approval succeeds'
);

select * from finish();
rollback;
