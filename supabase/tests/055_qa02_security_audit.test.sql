-- ---------------------------------------------------------------------------
-- 055_qa02_security_audit.test.sql
-- Comprehensive QA-02 security regression & penetration proof suite:
--   1. All 55 public tables: RLS enabled, zero anon access, seeded cross-tenant isolation & write blocking
--   2. S04 Direct RPC role-matrix, module, location, and suspended-tenant device RLS checks
--   3. S01 Cryptographic HMAC-SHA256 offline supervisor approval proofs, v2 PIN verifiers & single-use replay protection
--   4. S02 Stock, catalog price / discount bypass, server unit_cost & money integrity + idempotency
-- ---------------------------------------------------------------------------
begin;
select plan(51);

create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('qa02t:' || p)::uuid $$;
create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('qa02u:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('qa02id:' || p)::uuid $$;

create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;

create function pg_temp.logout() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
$$;

create function pg_temp.hint(p_sql text) returns text language plpgsql as $$
declare h text; s text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics h = pg_exception_hint, s = returned_sqlstate;
  return coalesce(nullif(h, ''), s);
end;
$$;

create function pg_temp.op(k text, kind text, payload jsonb) returns jsonb language sql immutable as $$
  select jsonb_build_object('op_id', pg_temp.id('op:' || k), 'kind', kind, 'payload', payload)
$$;

create function pg_temp.push1(k text, kind text, payload jsonb) returns jsonb language sql as $$
  select public.sync_push(jsonb_build_array(pg_temp.op(k, kind, payload))) -> 0
$$;

create function pg_temp.offline_appr(
  p_tenant uuid,
  p_user text,
  p_action text,
  p_ref uuid
) returns jsonb language sql stable as $$
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
          lower(p_tenant::text) || '|' || lower(pg_temp.u(p_user)::text) || '|' || p_action
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

-- ===========================================================================
-- Setup Fixtures: Tenants A (active), B (isolation target), C (suspended/no-mod)
-- ===========================================================================
insert into auth.users (id, email)
select pg_temp.u(n), n || '@qa02.invalid'
from unnest(array[
  'owner_a', 'mgr_a', 'sup_a', 'wh_a', 'cash_a', 'dead_a',
  'owner_b', 'cash_b', 'owner_c'
]) n;

insert into public.tenants (id, name, slug, base_currency, timezone, status) values
  (pg_temp.t('A'), 'QA02 Alpha', 'qa02-alpha', 'PHP', 'Asia/Manila', 'active'),
  (pg_temp.t('B'), 'QA02 Beta',  'qa02-beta',  'PHP', 'Asia/Manila', 'active'),
  (pg_temp.t('C'), 'QA02 Gamma', 'qa02-gamma', 'PHP', 'Asia/Manila', 'suspended');

insert into public.tenant_modules (tenant_id, inventory, pos, warehouse, deleted_at) values
  (pg_temp.t('A'), true,  true,  true,  null),
  (pg_temp.t('B'), true,  true,  true,  null),
  (pg_temp.t('C'), true,  false, false, now());

insert into public.tenant_limits (tenant_id) values
  (pg_temp.t('A')), (pg_temp.t('B')), (pg_temp.t('C'));

insert into public.tenant_settings (tenant_id, max_cashier_discount_percent, max_cashier_void_amount, cashier_can_void_own) values
  (pg_temp.t('A'), 10, 50000, false),
  (pg_temp.t('B'), 10, 50000, false),
  (pg_temp.t('C'), 10, 50000, false);

insert into public.locations (id, tenant_id, type, code, name, bins_enabled) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store',     'S01', 'Store A1', false),
  (pg_temp.id('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'WH A1',    true),
  (pg_temp.id('SB1'), pg_temp.t('B'), 'store',     'SB1', 'Store B1', false),
  (pg_temp.id('WB1'), pg_temp.t('B'), 'warehouse', 'WB1', 'WH B1',    true),
  (pg_temp.id('SC1'), pg_temp.t('C'), 'store',     'SC1', 'Store C1', false);

insert into public.profiles (user_id, tenant_id, username, full_name, role, active) values
  (pg_temp.u('owner_a'), pg_temp.t('A'), 'owner_a', 'Owner A',     'superadmin', true),
  (pg_temp.u('mgr_a'),   pg_temp.t('A'), 'mgr_a',   'Manager A',   'admin',      true),
  (pg_temp.u('sup_a'),   pg_temp.t('A'), 'sup_a',   'Supervisor A','admin',      true),
  (pg_temp.u('wh_a'),    pg_temp.t('A'), 'wh_a',    'Warehouse A', 'warehouse',  true),
  (pg_temp.u('cash_a'),  pg_temp.t('A'), 'cash_a',  'Cashier A',   'cashier',    true),
  (pg_temp.u('dead_a'),  pg_temp.t('A'), 'dead_a',  'Inactive A',  'superadmin', false),
  (pg_temp.u('owner_b'), pg_temp.t('B'), 'owner_b', 'Owner B',     'superadmin', true),
  (pg_temp.u('cash_b'),  pg_temp.t('B'), 'cash_b',  'Cashier B',   'cashier',    true),
  (pg_temp.u('owner_c'), pg_temp.t('C'), 'owner_c', 'Owner C',     'superadmin', true);

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('mgr_a'),  pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sup_a'),  pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('wh_a'),   pg_temp.id('W01'), pg_temp.t('A'), null),
  (pg_temp.u('cash_a'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('cash_b'), pg_temp.id('SB1'), pg_temp.t('B'), null);

-- Catalog + Stock for Tenant A
insert into public.products (id, tenant_id, name, track_stock) values
  (pg_temp.id('p:beer'), pg_temp.t('A'), 'Pale Pilsen', true),
  (pg_temp.id('p:open'), pg_temp.t('A'), 'Open Item',   false);
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost) values
  (pg_temp.id('v:beer'), pg_temp.t('A'), pg_temp.id('p:beer'), 'BEER-1', true, 6000),
  (pg_temp.id('v:open'), pg_temp.t('A'), pg_temp.id('p:open'), 'OPEN-1', true, 0);
insert into public.variant_prices (tenant_id, variant_id, currency, price) values
  (pg_temp.t('A'), pg_temp.id('v:beer'), 'PHP', 10000),
  (pg_temp.t('A'), pg_temp.id('v:open'), 'PHP', 0);
insert into public.stock_levels (tenant_id, location_id, variant_id, qty_on_hand, avg_cost) values
  (pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('v:beer'), 20, 6500),
  (pg_temp.t('A'), pg_temp.id('W01'), pg_temp.id('v:beer'), 40, 6500);
insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type) values
  (pg_temp.id('z:a1'), pg_temp.t('A'), pg_temp.id('W01'), 'GEN', 'General', 'storage');
insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, type) values
  (pg_temp.id('b:a1'), pg_temp.t('A'), pg_temp.id('W01'), pg_temp.id('z:a1'), 'A-01-1', 'shelf'),
  (pg_temp.id('b:a2'), pg_temp.t('A'), pg_temp.id('W01'), pg_temp.id('z:a1'), 'A-01-2', 'shelf');
insert into public.bin_stock_levels (tenant_id, bin_id, variant_id, qty_on_hand) values
  (pg_temp.t('A'), pg_temp.id('b:a1'), pg_temp.id('v:beer'), 40);

-- Set PINs for Tenant A users
select pg_temp.login('owner_a', 'A');
select public.set_my_pin('1111');
select pg_temp.login('mgr_a', 'A');
select public.set_my_pin('2222');
select pg_temp.login('sup_a', 'A');
select public.set_my_pin('3333');
select pg_temp.login('wh_a', 'A');
select public.set_my_pin('4444');
select pg_temp.login('cash_a', 'A');
select public.set_my_pin('5555');

-- Seed non-empty rows for Tenant B across EVERY tenant/admin table so cross-tenant 0-row proofs are non-vacuous
insert into public.tenant_currencies (tenant_id, code, rate_to_base) values (pg_temp.t('B'), 'USD', 56.5);
insert into public.devices (id, tenant_id, user_id, name, platform) values (pg_temp.id('dev:b'), pg_temp.t('B'), pg_temp.u('owner_b'), 'B-POS', 'web');
insert into public.categories (id, tenant_id, name) values (pg_temp.id('cat:b'), pg_temp.t('B'), 'Beta Drinks');
insert into public.products (id, tenant_id, category_id, name, track_stock) values (pg_temp.id('p:b'), pg_temp.t('B'), pg_temp.id('cat:b'), 'Beta Cola', true);
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost) values (pg_temp.id('v:b'), pg_temp.t('B'), pg_temp.id('p:b'), 'BCOLA', true, 1200);
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost) values (pg_temp.id('v:b2'), pg_temp.t('B'), pg_temp.id('p:b'), 'BCOLA-P', false, 100);
insert into public.variant_prices (tenant_id, variant_id, currency, price) values (pg_temp.t('B'), pg_temp.id('v:b'), 'PHP', 2500);
insert into public.customers (id, tenant_id, name) values (pg_temp.id('cust:b'), pg_temp.t('B'), 'Beta Customer');
insert into public.suppliers (id, tenant_id, name) values (pg_temp.id('sup:b'), pg_temp.t('B'), 'Beta Supplier');
insert into public.sales (id, tenant_id, location_id, local_no, subtotal, discount, tax, total, customer_id, sold_at) values
  (pg_temp.id('sale:b'), pg_temp.t('B'), pg_temp.id('SB1'), 'RB-1', 2500, 0, 0, 2500, pg_temp.id('cust:b'), now());
insert into public.sale_items (id, tenant_id, sale_id, location_id, variant_id, product_name, qty, unit_price, unit_cost, discount, tax, line_total) values
  (pg_temp.id('si:b'), pg_temp.t('B'), pg_temp.id('sale:b'), pg_temp.id('SB1'), pg_temp.id('v:b'), 'Beta Cola', 1, 2500, 1200, 0, 0, 2500);
insert into public.payments (id, tenant_id, sale_id, location_id, method, amount) values
  (pg_temp.id('pay:b'), pg_temp.t('B'), pg_temp.id('sale:b'), pg_temp.id('SB1'), 'cash', 2500);
insert into public.sale_returns (id, tenant_id, location_id, sale_id, client_op_id, refund_method, subtotal_refund, discount_refund, tax_refund, refund_total) values
  (pg_temp.id('ret:b'), pg_temp.t('B'), pg_temp.id('SB1'), pg_temp.id('sale:b'), pg_temp.id('op:retb'), 'cash', 2500, 0, 0, 2500);
insert into public.sale_return_items (id, tenant_id, return_id, sale_id, sale_item_id, location_id, variant_id, product_name, qty, unit_price, unit_cost, refund_amount, tax_refund) values
  (pg_temp.id('reti:b'), pg_temp.t('B'), pg_temp.id('ret:b'), pg_temp.id('sale:b'), pg_temp.id('si:b'), pg_temp.id('SB1'), pg_temp.id('v:b'), 'Beta Cola', 1, 2500, 1200, 2500, 0);
insert into public.sale_counters (tenant_id, location_id, day, last_no) values (pg_temp.t('B'), pg_temp.id('SB1'), current_date, 1);
insert into public.customer_ledger (id, tenant_id, customer_id, kind, amount, method) values
  (pg_temp.id('cl:b'), pg_temp.t('B'), pg_temp.id('cust:b'), 'charge', 2500, 'cash');
insert into public.expenses (id, tenant_id, location_id, client_op_id, amount, currency, category, paid_from, spent_at) values
  (pg_temp.id('exp:b'), pg_temp.t('B'), pg_temp.id('SB1'), pg_temp.id('op:expb'), 500, 'PHP', 'other', 'cash', now());
insert into public.service_txns (id, tenant_id, location_id, client_op_id, kind, wallet, amount, fee, currency, txn_at) values
  (pg_temp.id('svc:b'), pg_temp.t('B'), pg_temp.id('SB1'), pg_temp.id('op:svcb'), 'cash_in', 'gcash', 10000, 200, 'PHP', now());
insert into public.wallet_float (tenant_id, location_id, wallet, balance, txn_count) values
  (pg_temp.t('B'), pg_temp.id('SB1'), 'gcash', 50000, 1)
  on conflict do nothing;
insert into public.day_closes (id, tenant_id, location_id, client_op_id, day, currency, expected_cash, counted_cash, difference, server_expected_cash, opening_cash, closed_at) values
  (pg_temp.id('dc:b'), pg_temp.t('B'), pg_temp.id('SB1'), pg_temp.id('op:dcb'), current_date, 'PHP', 2500, 2500, 0, 2500, 1000, now());
insert into public.shifts (id, tenant_id, location_id, open_op_id, currency, opening_cash, opened_at) values
  (pg_temp.id('sh:b'), pg_temp.t('B'), pg_temp.id('SB1'), pg_temp.id('op:shb'), 'PHP', 1000, now());
insert into public.daily_sales_summary (tenant_id, location_id, day, gross, discount, net, tax, cogs, txn_count, cash, ewallet, utang, card) values
  (pg_temp.t('B'), pg_temp.id('SB1'), current_date, 2500, 0, 2500, 0, 1200, 1, 2500, 0, 0, 0)
  on conflict do nothing;
insert into public.daily_item_sales (tenant_id, location_id, day, variant_id, product_name, qty, revenue, cogs) values
  (pg_temp.t('B'), pg_temp.id('SB1'), current_date, pg_temp.id('v:b'), 'Beta Cola', 1, 2500, 1200)
  on conflict do nothing;
insert into public.daily_expense_summary (tenant_id, location_id, day, category, amount, entry_count, cash, ewallet) values
  (pg_temp.t('B'), pg_temp.id('SB1'), current_date, 'other', 500, 1, 500, 0)
  on conflict do nothing;
insert into public.daily_service_summary (tenant_id, location_id, day, kind, txn_count, amount, fee, cash, float_change) values
  (pg_temp.t('B'), pg_temp.id('SB1'), current_date, 'cash_in', 1, 10000, 200, 10200, -10000)
  on conflict do nothing;
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type) values
  (pg_temp.t('B'), pg_temp.id('WB1'), pg_temp.id('v:b'), 50, 'receipt');
insert into public.stock_levels (tenant_id, location_id, variant_id, qty_on_hand) values
  (pg_temp.t('B'), pg_temp.id('WB1'), pg_temp.id('v:b'), 50)
  on conflict do nothing;
insert into public.stock_snapshots_daily (tenant_id, location_id, day, variant_id, qty_on_hand, unit_cost, total_value) values
  (pg_temp.t('B'), pg_temp.id('WB1'), current_date, pg_temp.id('v:b'), 50, 1200, 60000)
  on conflict do nothing;
insert into public.stock_expiry (tenant_id, location_id, variant_id, expires_on) values
  (pg_temp.t('B'), pg_temp.id('WB1'), pg_temp.id('v:b'), current_date + 30);
insert into public.location_reorder_points (tenant_id, location_id, variant_id, reorder_point) values
  (pg_temp.t('B'), pg_temp.id('SB1'), pg_temp.id('v:b'), 5);
insert into public.conversions (id, tenant_id, location_id, client_op_id, pack_variant_id, piece_variant_id, packs, ratio, pieces, converted_at) values
  (pg_temp.id('conv:b'), pg_temp.t('B'), pg_temp.id('SB1'), pg_temp.id('op:convb'), pg_temp.id('v:b'), pg_temp.id('v:b2'), 1, 10, 10, now());
insert into public.purchase_orders (id, tenant_id, po_no, warehouse_id, supplier_id, status) values
  (pg_temp.id('po:b'), pg_temp.t('B'), 'PO-B-1', pg_temp.id('WB1'), pg_temp.id('sup:b'), 'draft');
insert into public.po_items (id, tenant_id, po_id, variant_id, qty_ordered, qty_received) values
  (pg_temp.id('poi:b'), pg_temp.t('B'), pg_temp.id('po:b'), pg_temp.id('v:b'), 10, 0);
insert into public.goods_receipts (id, tenant_id, grn_no, warehouse_id, without_po) values
  (pg_temp.id('grn:b'), pg_temp.t('B'), 'GRN-B-1', pg_temp.id('WB1'), true);
insert into public.goods_receipt_items (id, tenant_id, grn_id, variant_id, qty) values
  (pg_temp.id('grni:b'), pg_temp.t('B'), pg_temp.id('grn:b'), pg_temp.id('v:b'), 10);
insert into public.transfers (id, tenant_id, transfer_no, from_location_id, to_location_id, status) values
  (pg_temp.id('trf:b'), pg_temp.t('B'), 'TRF-B-1', pg_temp.id('WB1'), pg_temp.id('SB1'), 'draft');
insert into public.transfer_items (id, tenant_id, transfer_id, variant_id, qty_shipped) values
  (pg_temp.id('trfi:b'), pg_temp.t('B'), pg_temp.id('trf:b'), pg_temp.id('v:b'), 5);
insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type) values
  (pg_temp.id('z:b'), pg_temp.t('B'), pg_temp.id('WB1'), 'GEN', 'Beta Zone', 'storage');
insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, type) values
  (pg_temp.id('b:b'), pg_temp.t('B'), pg_temp.id('WB1'), pg_temp.id('z:b'), 'B-01-1', 'shelf');
insert into public.bin_stock_levels (tenant_id, bin_id, variant_id, qty_on_hand) values
  (pg_temp.t('B'), pg_temp.id('b:b'), pg_temp.id('v:b'), 50);
insert into public.stock_counts (id, tenant_id, count_no, warehouse_id, status) values
  (pg_temp.id('sc:b'), pg_temp.t('B'), 'CNT-B-1', pg_temp.id('WB1'), 'open');
insert into public.stock_count_items (id, tenant_id, count_id, variant_id, qty_system, qty_counted) values
  (pg_temp.id('sci:b'), pg_temp.t('B'), pg_temp.id('sc:b'), pg_temp.id('v:b'), 50, 50);
insert into public.pick_lists (id, tenant_id, warehouse_id, transfer_id, pick_list_no, status) values
  (pg_temp.id('pl:b'), pg_temp.t('B'), pg_temp.id('WB1'), pg_temp.id('trf:b'), 'PL-B-1', 'pending');
insert into public.pick_list_items (id, tenant_id, pick_list_id, variant_id, bin_id, qty_requested, qty_picked) values
  (pg_temp.id('pli:b'), pg_temp.t('B'), pg_temp.id('pl:b'), pg_temp.id('v:b'), pg_temp.id('b:b'), 5, 0);
insert into public.processed_ops (tenant_id, client_op_id, kind) values
  (pg_temp.t('B'), pg_temp.id('op:procb'), 'record_sale');
insert into public.supervisor_approvals (id, tenant_id, location_id, action, ref_id, requested_by, approved_by, expires_at) values
  (pg_temp.id('sa:b'), pg_temp.t('B'), pg_temp.id('SB1'), 'void_sale', pg_temp.id('sale:b'), pg_temp.u('cash_b'), pg_temp.u('owner_b'), now() + interval '1 hour');
insert into public.audit_log (tenant_id, action, entity, meta) values
  (pg_temp.t('B'), 'test.seed', 'tenant', '{}'::jsonb);
insert into public.platform_admins (user_id) values
  (pg_temp.u('owner_b')) on conflict do nothing;

-- ===========================================================================
-- 1. All 55 Public Tables: RLS + Zero Anon + Seeded Cross-Tenant Isolation
-- ===========================================================================

-- [1] All 55 public tables exist and enable RLS
select is(
  (select count(*)::int from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity = true),
  (select count(*)::int from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'),
  '1. All 55 public tables have row-level security enabled'
);

-- [2] Anon has zero table privileges across all 55 public tables
select is(
  (select count(*)::int from information_schema.role_table_grants
   where grantee = 'anon' and table_schema = 'public'),
  0,
  '2. Anon role holds zero privileges on any public table'
);

-- [3] Seeded cross-tenant isolation across ALL 54 tenant/admin tables under authenticated owner_a
create function pg_temp.verify_cross_tenant_reads() returns text language plpgsql as $$
declare
  r record;
  v_cnt int;
  v_checked int := 0;
begin
  for r in
    select c.relname as tbl,
           exists (select 1 from pg_attribute a where a.attrelid = c.oid and a.attname = 'tenant_id' and not a.attisdropped) as has_tid
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
    order by c.relname
  loop
    if r.tbl = 'currencies' then
      continue;
    end if;
    begin
      if r.has_tid then
        execute format('select count(*)::int from public.%I where tenant_id = %L', r.tbl, pg_temp.t('B')) into v_cnt;
      elsif r.tbl = 'tenants' then
        execute format('select count(*)::int from public.tenants where id = %L', pg_temp.t('B')) into v_cnt;
      elsif r.tbl = 'platform_admins' then
        execute format('select count(*)::int from public.platform_admins where user_id = %L', pg_temp.u('owner_b')) into v_cnt;
      else
        return 'unexpected non-tenant table: ' || r.tbl;
      end if;
    exception when insufficient_privilege then
      v_cnt := 0;
    end;
    if v_cnt <> 0 then
      return 'cross-tenant leak in ' || r.tbl || ': ' || v_cnt;
    end if;
    v_checked := v_checked + 1;
  end loop;
  return 'ok:' || v_checked::text;
end;
$$;

select pg_temp.login('owner_a', 'A');
set local role authenticated;
select is(
  pg_temp.verify_cross_tenant_reads(),
  'ok:54',
  '3. Authenticated owner_a reads 0 Beta rows across all 54 tenant & admin tables'
);
reset role;

-- [4] Anon cannot SELECT from any of the 55 public tables dynamically
create function pg_temp.verify_anon_blocked_all() returns text language plpgsql as $$
declare
  r record;
  v_blocked int := 0;
begin
  for r in
    select c.relname as tbl
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
    order by c.relname
  loop
    begin
      execute format('select 1 from public.%I limit 1', r.tbl);
      return 'anon read allowed on ' || r.tbl;
    exception when insufficient_privilege then
      v_blocked := v_blocked + 1;
    end;
  end loop;
  return 'ok:' || v_blocked::text;
end;
$$;

select pg_temp.logout();
set local role anon;
select is(
  pg_temp.verify_anon_blocked_all(),
  'ok:55',
  '4. Anon SELECT fails with 42501 on all 55 public tables'
);
reset role;

-- [5]-[9] Cross-tenant INSERT / UPDATE / DELETE & direct ledger writes blocked
select pg_temp.login('owner_a', 'A');
set local role authenticated;

select throws_ok(
  $$ insert into public.products (id, tenant_id, name) values (pg_temp.id('xprod'), pg_temp.t('B'), 'X') $$,
  '42501', null,
  '5. Cross-tenant INSERT into products fails with 42501'
);

select throws_ok(
  $$ update public.products set name = 'Hacked' where id = pg_temp.id('p:b') $$,
  '42501', null,
  '6. Authenticated user cannot UPDATE Beta product directly'
);

select throws_ok(
  $$ insert into public.transfers (id, tenant_id, transfer_no, from_location_id, to_location_id, status)
     values (pg_temp.id('xtrf'), pg_temp.t('B'), 'X-1', pg_temp.id('WB1'), pg_temp.id('SB1'), 'draft') $$,
  '42501', null,
  '7. Cross-tenant INSERT into transfers fails with 42501'
);

select throws_ok(
  $$ insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type)
     values (pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('v:beer'), 100, 'receipt') $$,
  '42501', null,
  '8. Authenticated user cannot write directly to stock_movements ledger'
);

select throws_ok(
  $$ insert into public.sale_items (id, tenant_id, sale_id, location_id, variant_id, product_name, qty, unit_price, unit_cost, discount, tax, line_total)
     values (pg_temp.id('xsi'), pg_temp.t('A'), pg_temp.id('sale:b'), pg_temp.id('S01'), pg_temp.id('v:beer'), 'X', 1, 1, 0, 0, 0, 1) $$,
  '42501', null,
  '9. Authenticated user cannot insert directly into append-only sale_items'
);
reset role;

-- [10] Superadmin verify Beta product untouched after cross-tenant UPDATE attempt
select is(
  (select name from public.products where id = pg_temp.id('p:b')),
  'Beta Cola',
  '10. Beta product name remains intact after cross-tenant mutation attempt'
);

-- ===========================================================================
-- 2. S04 Direct RPC Role Matrix, Module, Location & Devices RLS
-- ===========================================================================

-- [11] Anon cannot call any public SECURITY DEFINER function
select is(
  (select count(*)::int
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef = true and has_function_privilege('anon', p.oid, 'execute')),
  0,
  '11. Zero public SECURITY DEFINER functions grant EXECUTE to anon'
);

-- [12]-[14] snapshot_daily_stock, report_multi_store, get_storage_metrics reject cashiers/admins cleanly
select pg_temp.login('cash_a', 'A');
set local role authenticated;
select is(pg_temp.hint('select public.snapshot_daily_stock(current_date)'), 'not_allowed', '12. Cashier blocked from snapshot_daily_stock');
select is(pg_temp.hint('select public.report_multi_store(current_date, current_date, null)'), 'not_allowed', '13. Cashier blocked from report_multi_store');
select is(pg_temp.hint('select public.get_storage_metrics()'), 'not_allowed', '14. Cashier blocked from get_storage_metrics');
reset role;

-- [15] Branch supervisor/admin blocked from get_storage_metrics
select pg_temp.login('sup_a', 'A');
set local role authenticated;
select is(pg_temp.hint('select public.get_storage_metrics()'), 'not_allowed', '15. Branch admin blocked from get_storage_metrics');
reset role;

-- [16]-[17] Non-platform superadmin gets strictly tenant-scoped metrics (no global bytes/tables)
select pg_temp.login('owner_a', 'A');
set local role authenticated;
select is(public.get_storage_metrics() ->> 'scope', 'tenant', '16. Non-platform owner receives tenant scope in get_storage_metrics');
select is(public.get_storage_metrics() -> 'total_bytes', 'null'::jsonb, '17. Non-platform owner gets null global total_bytes');
reset role;

-- [18]-[20] health_ping requires active user & omits database name
select pg_temp.logout();
set local role anon;
select throws_ok($$ select public.health_ping() $$, '42501', null, '18. Anon blocked from health_ping');
reset role;

select pg_temp.login('dead_a', 'A');
set local role authenticated;
select throws_ok($$ select public.health_ping() $$, '42501', null, '19. Deactivated user blocked from health_ping');
reset role;

select pg_temp.login('cash_a', 'A');
set local role authenticated;
select is((public.health_ping() ? 'database'), false, '20. health_ping response omits internal database name');
reset role;

-- [21]-[22] sync_pull_catalog & sync_pull_conversions enforce module checks on suspended/disabled tenant C
select pg_temp.login('owner_c', 'C');
set local role authenticated;
select is(pg_temp.hint($$ select public.sync_pull_catalog('{}'::jsonb, 10) $$), 'module_disabled', '21. sync_pull_catalog rejects caller when all modules disabled');
select is(pg_temp.hint($$ select public.sync_pull_conversions(null, 10) $$), 'module_disabled', '22. sync_pull_conversions rejects caller when inventory disabled');
reset role;

-- [23]-[27] Supervisor admin blocked from warehouse bin & transfer management; location scoping enforced
select pg_temp.login('sup_a', 'A');
set local role authenticated;
select is(pg_temp.hint(format('select public.enable_warehouse_bins(%L)', pg_temp.id('W01'))), 'location_denied', '23. Supervisor blocked from enable_warehouse_bins on unassigned warehouse');
select is(pg_temp.hint(format('select public.move_bin_stock(%L, %L, %L, %L, 1)', pg_temp.id('W01'), pg_temp.id('b:a1'), pg_temp.id('b:a2'), pg_temp.id('v:beer'))), 'location_denied', '24. Supervisor blocked from move_bin_stock on unassigned warehouse');
select is(pg_temp.hint(format('select public.create_transfer(%L, %L, null, %L::jsonb, false)', pg_temp.id('S01'), pg_temp.id('W01'), '[]')), 'not_allowed', '25. Supervisor blocked from create_transfer even from assigned store S01');
reset role;

select pg_temp.login('wh_a', 'A');
set local role authenticated;
select is(pg_temp.hint(format('select public.move_bin_stock(%L, %L, %L, %L, 1)', pg_temp.id('WB1'), pg_temp.id('b:b'), pg_temp.id('b:b'), pg_temp.id('v:b'))), 'location_denied', '26. Warehouse clerk blocked from cross-tenant warehouse bin move');
select is(pg_temp.hint(format('select public.move_bin_stock(%L, %L, %L, %L, 1)', pg_temp.id('W01'), pg_temp.id('b:a1'), pg_temp.id('b:a2'), pg_temp.id('v:beer'))), null, '27. Assigned warehouse clerk succeeds moving bin stock within W01');
reset role;

-- [28]-[29] receive_transfer allows POS store cashier at destination S01, refuses warehouse destination for cashier
insert into public.transfers (id, tenant_id, transfer_no, from_location_id, to_location_id, status, shipped_at) values
  (pg_temp.id('trf:to_s'), pg_temp.t('A'), 'TRF-A1', pg_temp.id('W01'), pg_temp.id('S01'), 'shipped', now()),
  (pg_temp.id('trf:to_w'), pg_temp.t('A'), 'TRF-A2', pg_temp.id('S01'), pg_temp.id('W01'), 'shipped', now());
insert into public.transfer_items (id, tenant_id, transfer_id, variant_id, qty_shipped) values
  (pg_temp.id('trfi:to_s'), pg_temp.t('A'), pg_temp.id('trf:to_s'), pg_temp.id('v:beer'), 2),
  (pg_temp.id('trfi:to_w'), pg_temp.t('A'), pg_temp.id('trf:to_w'), pg_temp.id('v:beer'), 1);

select pg_temp.login('cash_a', 'A');
set local role authenticated;
select is(
  pg_temp.hint(format('select public.receive_transfer(%L, %L::jsonb)', pg_temp.id('trf:to_w'), jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty_received', 1))::text)),
  'location_denied',
  '28. Cashier cannot receive transfer into a warehouse destination'
);
select lives_ok(
  format('select public.receive_transfer(%L, %L::jsonb)', pg_temp.id('trf:to_s'), jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty_received', 2))::text),
  '29. Store cashier can receive inbound stock into assigned store S01'
);
reset role;

-- [30]-[31] Suspended tenant caller blocked from writing/updating devices RLS
insert into public.devices (id, tenant_id, user_id, name, platform)
  values (pg_temp.id('dev:c_old'), pg_temp.t('C'), pg_temp.u('owner_c'), 'Old C Dev', 'web');

select pg_temp.login('owner_c', 'C');
set local role authenticated;
select throws_ok(
  $$ insert into public.devices (id, tenant_id, user_id, name) values (pg_temp.id('dev:c_new'), pg_temp.t('C'), pg_temp.u('owner_c'), 'New') $$,
  '42501', null,
  '30. Suspended tenant user blocked from inserting device via RLS'
);
update public.devices set name = 'Renamed' where id = pg_temp.id('dev:c_old');
reset role;
select is(
  (select name from public.devices where id = pg_temp.id('dev:c_old')),
  'Old C Dev',
  '31. Suspended tenant user cannot update existing device via RLS'
);

-- ===========================================================================
-- 3. S01 Offline PIN HMAC Proof, v2 Verifiers & Single-Use Replay Protection
-- ===========================================================================
select pg_temp.login('cash_a', 'A');
set local role authenticated;

-- [32]-[34] pull_offline_pins returns ONLY store approvers with v2 verifiers (never raw dk or cashier/warehouse)
select is(
  (select count(*)::int from public.pull_offline_pins(pg_temp.id('S01'))),
  3,
  '32. pull_offline_pins excludes cashier & warehouse and returns only 3 store approvers'
);
select ok(
  (select bool_and(pin_hash ~ '^pbkdf2_sha256\$[0-9]+\$[^$]+\$v2:[A-Za-z0-9+/=]+$') from public.pull_offline_pins(pg_temp.id('S01'))),
  '33. pull_offline_pins emits v2 SHA-256 verifiers without raw derived key dk'
);
select jsonb_agg(row_to_json(x)) as pulled_pins
from public.pull_offline_pins(pg_temp.id('S01')) x
\gset
reset role;
select ok(
  not exists (
    select 1 from jsonb_to_recordset(:'pulled_pins'::jsonb) as pop(user_id uuid, pin_hash text)
    join public.profiles pr on pr.user_id = pop.user_id
    where pop.pin_hash = pr.pin_hash
  ),
  '34. pull_offline_pins never equals stored profiles.pin_hash'
);

-- [35]-[41] Offline approval forgery, cashier signer, wrong proof, cross-action replay & single-use checks
select pg_temp.login('cash_a', 'A');

-- [35] Missing proof rejected
select is(
  (pg_temp.push1('s_noproof', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:np'), 'local_no', 'R-NP', 'location_id', pg_temp.id('S01'),
    'discount', 3000,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 10000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 7000)),
    'offline_approval', jsonb_build_object('approver_id', pg_temp.u('sup_a'), 'approved_at', to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
  )) ->> 'hint'),
  'approval_invalid',
  '35. Unsigned offline_approval without proof is rejected'
);

-- [36] Forged random 64-hex proof rejected
select is(
  (pg_temp.push1('s_badproof', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:bp'), 'local_no', 'R-BP', 'location_id', pg_temp.id('S01'),
    'discount', 3000,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 10000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 7000)),
    'offline_approval', jsonb_build_object(
      'approver_id', pg_temp.u('sup_a'),
      'approved_at', to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'action', 'sale_discount',
      'ref_id', pg_temp.id('sale:bp'),
      'proof', repeat('a', 64)
    )
  )) ->> 'hint'),
  'approval_invalid',
  '36. Forged HMAC proof is rejected with approval_invalid'
);

-- [37] Cashier cannot sign offline proof even with their own real dk
select is(
  (pg_temp.push1('s_cashsig', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:cs'), 'local_no', 'R-CS', 'location_id', pg_temp.id('S01'),
    'discount', 3000,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 10000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 7000)),
    'offline_approval', pg_temp.offline_appr(pg_temp.t('A'), 'cash_a', 'sale_discount', pg_temp.id('sale:cs'))
  )) ->> 'hint'),
  'approval_invalid',
  '37. Offline HMAC proof signed by cashier is rejected'
);

-- [38] Valid HMAC proof succeeds for sale_discount
select pg_temp.offline_appr(pg_temp.t('A'), 'sup_a', 'sale_discount', pg_temp.id('sale:ok1')) as valid_off
\gset

select is(
  (pg_temp.push1('s_ok1', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:ok1'), 'local_no', 'R-OK1', 'location_id', pg_temp.id('S01'),
    'discount', 3000,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 10000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 7000)),
    'offline_approval', :'valid_off'::jsonb
  )) ->> 'status'),
  'ok',
  '38. Valid HMAC-SHA256 offline proof by supervisor succeeds'
);

-- [39] Replaying the EXACT same offline proof under a DIFFERENT op_id is blocked (approval_used)
select is(
  (pg_temp.push1('s_replay_newop', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:ok1'), 'local_no', 'R-OK2', 'location_id', pg_temp.id('S01'),
    'discount', 3000,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 10000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 7000)),
    'offline_approval', :'valid_off'::jsonb
  )) ->> 'hint'),
  'approval_used',
  '39. Replaying the same offline proof under a distinct op_id is rejected as approval_used'
);

-- [40] Replaying the SAME client_op_id is idempotent and returns ok without double-deducting stock
select is(
  (pg_temp.push1('s_ok1', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:ok1'), 'local_no', 'R-OK1', 'location_id', pg_temp.id('S01'),
    'discount', 3000,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 10000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 7000)),
    'offline_approval', :'valid_off'::jsonb
  )) ->> 'status'),
  'ok',
  '40. Replaying the identical op_id returns idempotent ok'
);

-- [41] audit_log logs proof_digest and never the raw proof
select ok(
  exists (
    select 1 from public.audit_log
    where tenant_id = pg_temp.t('A')
      and action = 'approval.offline'
      and entity_id = pg_temp.u('sup_a')
      and meta ? 'proof_digest'
      and not (meta::text like '%' || (:'valid_off'::jsonb ->> 'proof') || '%')
  ),
  '41. audit_log stores SHA-256 proof_digest without logging raw HMAC proof'
);

-- ===========================================================================
-- 4. S02 Catalog Price Bypass, Server COGS, Negative Value & Cash Checks
-- ===========================================================================

-- [42] Cashier lowering unit_price below catalog price without supervisor approval is blocked
select is(
  (pg_temp.push1('s_underprice', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:up'), 'local_no', 'R-UP', 'location_id', pg_temp.id('S01'),
    'discount', 0,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 100)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 100))
  )) ->> 'hint'),
  'approval_required',
  '42. Cashier downward unit_price override below catalog price requires supervisor approval'
);

-- [43] Open-amount product (catalog price = 0) remains sellable by cashier without supervisor approval
select is(
  (pg_temp.push1('s_open_ok', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:open'), 'local_no', 'R-OPEN', 'location_id', pg_temp.id('S01'),
    'discount', 0,
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:open'), 'qty', 1, 'unit_price', 1500)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 1500))
  )) ->> 'status'),
  'ok',
  '43. Open-amount product (catalog price 0) works cleanly without blocking cashier'
);

-- [44] Negative client unit_cost is rejected
select is(
  (pg_temp.push1('s_negcost', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:nc'), 'local_no', 'R-NC', 'location_id', pg_temp.id('S01'),
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 10000, 'unit_cost', -500)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 10000))
  )) ->> 'hint'),
  'invalid_value',
  '44. Negative unit_cost payload is rejected'
);

-- [45]-[46] Client supplying forged unit_cost = 0 cannot overwrite server avg_cost (6500)
select is(
  (pg_temp.push1('s_zerocost', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:zc'), 'local_no', 'R-ZC', 'location_id', pg_temp.id('S01'),
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 10000, 'unit_cost', 0)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 10000))
  )) ->> 'status'),
  'ok',
  '45. Normal sale at catalog price succeeds even if client submits unit_cost = 0'
);

select is(
  (select unit_cost from public.sale_items where sale_id = pg_temp.id('sale:zc')),
  6500::bigint,
  '46. Server enforces authoritative stock_levels.avg_cost (6500) instead of client unit_cost (0)'
);

-- [47]-[50] Negative qty, negative payment, cash tendered < amount, foreign variant rejected
select is(
  (pg_temp.push1('s_negqty', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:nq'), 'local_no', 'R-NQ', 'location_id', pg_temp.id('S01'),
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', -2, 'unit_price', 10000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 10000))
  )) ->> 'hint'),
  'qty_invalid',
  '47. Negative item quantity rejected'
);

select is(
  (pg_temp.push1('s_shortcash', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:sc'), 'local_no', 'R-SC', 'location_id', pg_temp.id('S01'),
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 10000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 10000, 'tendered', 5000))
  )) ->> 'hint'),
  'invalid_value',
  '48. Cash tendered less than payment amount rejected'
);

select is(
  (pg_temp.push1('s_xvar', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:xv'), 'local_no', 'R-XV', 'location_id', pg_temp.id('S01'),
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:b'), 'qty', 1, 'unit_price', 2500)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 2500))
  )) ->> 'hint'),
  'unknown_variant',
  '49. Cross-tenant variant_id in record_sale rejected as unknown_variant'
);

select is(
  (pg_temp.push1('s_negpay', 'record_sale', jsonb_build_object(
    'id', pg_temp.id('sale:np2'), 'local_no', 'R-NP2', 'location_id', pg_temp.id('S01'),
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:beer'), 'qty', 1, 'unit_price', 10000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', -10000))
  )) ->> 'hint'),
  'invalid_value',
  '50. Negative payment amount rejected'
);

-- [51] Stock math integrity: initial 20 + 2 received transfer (test 29) - 1 (test 38, replayed in 40) - 1 (test 45) = 20
select is(
  (select qty_on_hand from public.stock_levels
   where tenant_id = pg_temp.t('A') and location_id = pg_temp.id('S01') and variant_id = pg_temp.id('v:beer')),
  20.000::numeric,
  '51. S01 stock balance preserves exact quantity (20 + 2 received - 1 replay-safe sale - 1 zero-cost sale = 20)'
);

select * from finish();
rollback;
