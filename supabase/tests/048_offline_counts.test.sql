-- 048_offline_counts.test.sql: F-13h H7 Phone offline counting.
-- Tests:
-- 1. sync_push accepts start_count, record_count (with device snapshot), close_count, cancel_count
-- 2. Device snapshot validation against ledger and reconciliation of intervening movements
-- 3. Implausible snapshot rejection (implausible_snapshot)
-- 4. Idempotency and replay of count ops
-- 5. Role and warehouse permission boundaries

begin;
select plan(22);

-- ---------------------------------------------------------------------------
-- Fixtures: Tenant X with warehouses W1, W2; users owner, wh1, wh2, cashier
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p text) returns uuid language sql immutable as $$ select md5('tenant:OC:' || p)::uuid $$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$ select md5('user:OC:' || p)::uuid $$;
create function pg_temp.lid(p text) returns uuid language sql immutable as $$ select md5('loc:OC:' || p)::uuid $$;
create function pg_temp.vid(p text) returns uuid language sql immutable as $$ select md5('var:OC:' || p)::uuid $$;
create function pg_temp.oid(p text) returns uuid language sql immutable as $$ select md5('obj:OC:' || p)::uuid $$;

insert into public.tenants (id, name, slug, base_currency) values
  (pg_temp.tid('X'), 'Offline Count Tenant', 'oc-x', 'PHP');
insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid('X'), true, true);
insert into public.tenant_settings (tenant_id) values (pg_temp.tid('X'));

insert into auth.users (id, email) select pg_temp.uid(n), n || '@oc.invalid'
from unnest(array['owner', 'wh1', 'wh2', 'cashier']) n;

insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.uid('owner'),   pg_temp.tid('X'), 'owner',   'superadmin', true),
  (pg_temp.uid('wh1'),     pg_temp.tid('X'), 'wh1',     'warehouse',  true),
  (pg_temp.uid('wh2'),     pg_temp.tid('X'), 'wh2',     'warehouse',  true),
  (pg_temp.uid('cashier'), pg_temp.tid('X'), 'cashier', 'cashier',    true);

insert into public.locations (id, tenant_id, type, code, name, bins_enabled) values
  (pg_temp.lid('W1'), pg_temp.tid('X'), 'warehouse', 'W1', 'Warehouse One', false),
  (pg_temp.lid('W2'), pg_temp.tid('X'), 'warehouse', 'W2', 'Warehouse Two', false),
  (pg_temp.lid('S1'), pg_temp.tid('X'), 'store',     'S1', 'Store One',     false);

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.uid('wh1'),     pg_temp.lid('W1'), pg_temp.tid('X'), null),
  (pg_temp.uid('wh2'),     pg_temp.lid('W2'), pg_temp.tid('X'), null),
  (pg_temp.uid('cashier'), pg_temp.lid('S1'), pg_temp.tid('X'), null);

insert into public.products (id, tenant_id, name) values
  (md5('p:OC:1')::uuid, pg_temp.tid('X'), 'Rice 25kg'),
  (md5('p:OC:2')::uuid, pg_temp.tid('X'), 'Cooking oil 1L'),
  (md5('p:OC:3')::uuid, pg_temp.tid('X'), 'Flour 1kg');

insert into public.product_variants (id, tenant_id, product_id, sku, is_default) values
  (pg_temp.vid('rice'),  pg_temp.tid('X'), md5('p:OC:1')::uuid, 'RICE25', true),
  (pg_temp.vid('oil'),   pg_temp.tid('X'), md5('p:OC:2')::uuid, 'OIL1L',  true),
  (pg_temp.vid('flour'), pg_temp.tid('X'), md5('p:OC:3')::uuid, 'FLOUR1', true);

-- Opening stock in W1: rice 50, oil 20
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost) values
  (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('rice'), 50, 'receipt', 1000),
  (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('oil'),  20, 'receipt', 2500);

create function pg_temp.login(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims', jsonb_build_object(
    'sub', pg_temp.uid(p_user),
    'role', 'authenticated',
    'tenant_id', pg_temp.tid('X')
  )::text, true);
$$;

set local role authenticated;

-- ---------------------------------------------------------------------------
-- 1. start_count via sync_push
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');

select is(
  (select (res -> 0 ->> 'status') from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('c1'),
      'kind', 'start_count',
      'payload', jsonb_build_object(
        'warehouse_id', pg_temp.lid('W1'),
        'notes', 'Monthly inventory'
      )
    )
  )) as res),
  'ok',
  'wh1 starts count in W1 via sync_push'
);

select is(
  (select count(*)::int from public.stock_counts where id = pg_temp.oid('c1') and status = 'open'),
  1,
  'stock_counts row exists with status open'
);

-- Replay of start_count is idempotent
select is(
  (select (res -> 0 ->> 'status') from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('c1'),
      'kind', 'start_count',
      'payload', jsonb_build_object('warehouse_id', pg_temp.lid('W1'))
    )
  )) as res),
  'ok',
  'replay of start_count succeeds idempotently'
);

-- Denied location
select is(
  (select (res -> 0 ->> 'status') from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('c_bad_loc'),
      'kind', 'start_count',
      'payload', jsonb_build_object('warehouse_id', pg_temp.lid('W2'))
    )
  )) as res),
  'rejected',
  'wh1 cannot start count in W2'
);

-- Cashier denied
select pg_temp.login('cashier');
select is(
  (select (res -> 0 ->> 'status') from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('c_cashier'),
      'kind', 'start_count',
      'payload', jsonb_build_object('warehouse_id', pg_temp.lid('W1'))
    )
  )) as res),
  'rejected',
  'cashier cannot start warehouse count'
);

-- ---------------------------------------------------------------------------
-- 2. record_count with matching device snapshot
-- ---------------------------------------------------------------------------
select pg_temp.login('wh1');

select is(
  (select (res -> 0 ->> 'status') from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('rec1'),
      'kind', 'record_count',
      'payload', jsonb_build_object(
        'count_id', pg_temp.oid('c1'),
        'items', jsonb_build_array(
          jsonb_build_object(
            'variant_id', pg_temp.vid('rice'),
            'qty_counted', 48,
            'qty_system', 50
          )
        )
      )
    )
  )) as res),
  'ok',
  'record_count accepts matching device snapshot (50)'
);

select is(
  (select (i.qty_system, i.qty_counted)::text from public.stock_count_items i
   where i.count_id = pg_temp.oid('c1') and i.variant_id = pg_temp.vid('rice')),
  '(50.000,48.000)',
  'stock_count_items holds qty_system 50 and qty_counted 48'
);

-- ---------------------------------------------------------------------------
-- 3. Intervening movements: goods receipt arrives on server between count and sync
-- ---------------------------------------------------------------------------
-- Simulating server receipt: +30 oil arrives on server
set local role postgres;
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, unit_cost)
values (pg_temp.tid('X'), pg_temp.lid('W1'), pg_temp.vid('oil'), 30, 'receipt', 2500);
set local role authenticated;

-- Current server stock of oil is now 20 + 30 = 50.
select is(
  (select s.qty_on_hand::int from public.stock_levels s
   where s.location_id = pg_temp.lid('W1') and s.variant_id = pg_temp.vid('oil')),
  50,
  'server stock of oil is 50 after delivery'
);

-- Device had counted offline when system was 20 (counted 19).
-- Device sends snapshot qty_system = 20.
select is(
  (select (res -> 0 ->> 'status') from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('rec2'),
      'kind', 'record_count',
      'payload', jsonb_build_object(
        'count_id', pg_temp.oid('c1'),
        'items', jsonb_build_array(
          jsonb_build_object(
            'variant_id', pg_temp.vid('oil'),
            'qty_counted', 19,
            'qty_system', 20
          )
        )
      )
    )
  )) as res),
  'ok',
  'record_count reconciles device snapshot (20) with intervening delivery (+30)'
);

select is(
  (select (i.qty_system, i.qty_counted)::text from public.stock_count_items i
   where i.count_id = pg_temp.oid('c1') and i.variant_id = pg_temp.vid('oil')),
  '(20.000,19.000)',
  'oil count item stores snapshot 20 and counted 19'
);

-- ---------------------------------------------------------------------------
-- 4. Implausible snapshot rejection
-- ---------------------------------------------------------------------------
-- Flour has 0 movements and 0 stock. Device claiming system had 500 without ledger history is rejected.
select is(
  (select (res -> 0 ->> 'status', res -> 0 ->> 'hint')::text from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('rec_bad'),
      'kind', 'record_count',
      'payload', jsonb_build_object(
        'count_id', pg_temp.oid('c1'),
        'items', jsonb_build_array(
          jsonb_build_object(
            'variant_id', pg_temp.vid('flour'),
            'qty_counted', 10,
            'qty_system', 500
          )
        )
      )
    )
  )) as res),
  '(rejected,implausible_snapshot)',
  'implausible snapshot with no ledger movements is rejected'
);

-- ---------------------------------------------------------------------------
-- 5. close_count via sync_push
-- ---------------------------------------------------------------------------
select is(
  (select (res -> 0 ->> 'status') from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('close1'),
      'kind', 'close_count',
      'payload', jsonb_build_object(
        'count_id', pg_temp.oid('c1'),
        'zero_uncounted', false
      )
    )
  )) as res),
  'ok',
  'close_count closes count via sync_push'
);

select is(
  (select status from public.stock_counts where id = pg_temp.oid('c1')),
  'closed',
  'stock count status is closed'
);

-- Check that intervening delivery was preserved:
-- Oil: was 20 originally, delivery was +30 (total 50).
-- Count was 19 against snapshot 20 -> correction = 19 - 20 = -1.
-- Final stock should be 50 - 1 = 49! (Physically: 19 counted + 30 delivered = 49).
select is(
  (select s.qty_on_hand::int from public.stock_levels s
   where s.location_id = pg_temp.lid('W1') and s.variant_id = pg_temp.vid('oil')),
  49,
  'oil stock correctly reflects counted 19 + intervening delivery 30 = 49'
);

-- Rice: was 50 originally. Count was 48 against snapshot 50 -> correction = -2.
-- Final stock should be 48.
select is(
  (select s.qty_on_hand::int from public.stock_levels s
   where s.location_id = pg_temp.lid('W1') and s.variant_id = pg_temp.vid('rice')),
  48,
  'rice stock correctly reflects counted 48'
);

-- Replay of close_count
select is(
  (select (res -> 0 ->> 'status') from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('close1_replay'),
      'kind', 'close_count',
      'payload', jsonb_build_object('count_id', pg_temp.oid('c1'))
    )
  )) as res),
  'ok',
  'replay of close_count succeeds'
);

-- ---------------------------------------------------------------------------
-- 6. cancel_count via sync_push
-- ---------------------------------------------------------------------------
-- Start new count in W1 now that previous is closed
select is(
  (select (res -> 0 ->> 'status') from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('c2'),
      'kind', 'start_count',
      'payload', jsonb_build_object('warehouse_id', pg_temp.lid('W1'))
    )
  )) as res),
  'ok',
  'start second count in W1'
);

select is(
  (select (res -> 0 ->> 'status') from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('cancel2'),
      'kind', 'cancel_count',
      'payload', jsonb_build_object('count_id', pg_temp.oid('c2'), 'reason', 'mistake')
    )
  )) as res),
  'ok',
  'cancel_count cancels count via sync_push'
);

select is(
  (select (status, cancel_reason)::text from public.stock_counts where id = pg_temp.oid('c2')),
  '(cancelled,mistake)',
  'count is marked cancelled with reason'
);

-- Recording on cancelled count is refused
select is(
  (select (res -> 0 ->> 'status', res -> 0 ->> 'hint')::text from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('rec_cancelled'),
      'kind', 'record_count',
      'payload', jsonb_build_object(
        'count_id', pg_temp.oid('c2'),
        'items', jsonb_build_array(
          jsonb_build_object('variant_id', pg_temp.vid('rice'), 'qty_counted', 10)
        )
      )
    )
  )) as res),
  '(rejected,invalid_state)',
  'record on cancelled count is rejected'
);

-- ---------------------------------------------------------------------------
-- 7. Full batch: start, record, and close all in one sync_push batch
-- ---------------------------------------------------------------------------
select is(
  (select (
    res -> 0 ->> 'status',
    res -> 1 ->> 'status',
    res -> 2 ->> 'status'
  )::text from public.sync_push(jsonb_build_array(
    jsonb_build_object(
      'op_id', pg_temp.oid('c3'),
      'kind', 'start_count',
      'payload', jsonb_build_object('warehouse_id', pg_temp.lid('W1'), 'notes', 'Full batch count')
    ),
    jsonb_build_object(
      'op_id', pg_temp.oid('rec3'),
      'kind', 'record_count',
      'payload', jsonb_build_object(
        'count_id', pg_temp.oid('c3'),
        'items', jsonb_build_array(
          jsonb_build_object('variant_id', pg_temp.vid('flour'), 'qty_counted', 12, 'qty_system', 0)
        )
      )
    ),
    jsonb_build_object(
      'op_id', pg_temp.oid('close3'),
      'kind', 'close_count',
      'payload', jsonb_build_object('count_id', pg_temp.oid('c3'))
    )
  )) as res),
  '(ok,ok,ok)',
  'single sync_push batch executes start, record, close seamlessly'
);

select is(
  (select s.qty_on_hand::int from public.stock_levels s
   where s.location_id = pg_temp.lid('W1') and s.variant_id = pg_temp.vid('flour')),
  12,
  'flour stock is 12 after full batch count'
);

-- Close test plan
select * from finish();
rollback;
