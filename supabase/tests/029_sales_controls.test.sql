-- ---------------------------------------------------------------------------
-- 029_sales_controls.test.sql
-- Card F-07: Sales controls, cashier discount and void thresholds, supervisor PIN escalation
-- ---------------------------------------------------------------------------
begin;
select plan(28);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('id:' || p)::uuid $$;

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

create function pg_temp.item(v text, qty numeric, price bigint, disc bigint default 0) returns jsonb language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object('variant_id', pg_temp.id('v:' || v), 'qty', qty, 'unit_price', price, 'discount', nullif(disc, 0)))
$$;

create function pg_temp.pay(method text, amount bigint, tendered bigint default null) returns jsonb language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object('method', method, 'amount', amount, 'tendered', tendered))
$$;

create temp table ap (k text primary key, id uuid, res jsonb);
grant all on ap to authenticated;

create function pg_temp.approve(p_k text, action text, ref_id uuid, pin text, loc uuid default null, approver uuid default null)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := public.approve_supervisor_action(action, ref_id, pin, loc, approver);
  if (r ->> 'ok')::boolean then
    insert into pg_temp.ap (k, id, res) values (p_k, (r ->> 'approval_id')::uuid, r)
    on conflict (k) do update set id = excluded.id, res = excluded.res;
  end if;
  return r;
end;
$$;
create function pg_temp.ap(k text) returns uuid language sql as $$ select id from pg_temp.ap where ap.k = $1 $$;

create function pg_temp.sale(k text, items jsonb, pays jsonb, extra jsonb default '{}') returns jsonb language sql immutable as $$
  select jsonb_build_object('id', pg_temp.id('sale:' || k), 'local_no', 'R-' || k, 'location_id', pg_temp.id('S01'),
                            'sold_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                            'items', items, 'payments', pays) || extra
$$;

-- Setup tenant and users
insert into auth.users (id, email)
select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'sara', 'juan', 'pedro', 'ownerB']) n;

insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'Tenant A', 'tenant-a', 'PHP', 'Asia/Manila'),
  (pg_temp.t('B'), 'Tenant B', 'tenant-b', 'PHP', 'Asia/Manila');

insert into public.tenant_modules (tenant_id, pos, inventory) values
  (pg_temp.t('A'), true, true),
  (pg_temp.t('B'), true, true);

insert into public.tenant_limits (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B'));
insert into public.tenant_settings (tenant_id) values (pg_temp.t('A')), (pg_temp.t('B'));

insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'Store 1'),
  (pg_temp.id('S02'), pg_temp.t('A'), 'store', 'S02', 'Store 2'),
  (pg_temp.id('SB1'), pg_temp.t('B'), 'store', 'SB1', 'Store B');

insert into public.profiles (user_id, tenant_id, username, full_name, role, active) values
  (pg_temp.u('owner'),  pg_temp.t('A'), 'owner', 'Owner Boss', 'superadmin', true),
  (pg_temp.u('maria'),  pg_temp.t('A'), 'maria', 'Maria Manager', 'admin', true),
  (pg_temp.u('sara'),   pg_temp.t('A'), 'sara',  'Sara Supervisor', 'admin', true),
  (pg_temp.u('juan'),   pg_temp.t('A'), 'juan',    'Juan Cashier', 'cashier', true),
  (pg_temp.u('pedro'),  pg_temp.t('A'), 'pedro',   'Pedro Cashier', 'cashier', true),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner_b', 'Owner B', 'superadmin', true);

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sara'),  pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'),  pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('S01'), pg_temp.t('A'), null);

-- Products & variants
insert into public.products (id, tenant_id, name, unit, track_stock) values
  (pg_temp.id('p:kape'), pg_temp.t('A'), 'Kape', 'pc', true),
  (pg_temp.id('p:gatas'), pg_temp.t('A'), 'Gatas', 'pc', true);

insert into public.product_variants (id, tenant_id, product_id, sku, cost) values
  (pg_temp.id('v:kape'),  pg_temp.t('A'), pg_temp.id('p:kape'),  'SKU-KAPE',  1000),
  (pg_temp.id('v:gatas'), pg_temp.t('A'), pg_temp.id('p:gatas'), 'SKU-GATAS', 5000);

insert into public.variant_prices (tenant_id, variant_id, currency, price) values
  (pg_temp.t('A'), pg_temp.id('v:kape'),  'PHP', 2500),
  (pg_temp.t('A'), pg_temp.id('v:gatas'), 'PHP', 10000);

-- Initial stock
insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id, unit_cost, occurred_at) values
  (pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('v:kape'),  100, 'opening', 'system', gen_random_uuid(), 1000, now()),
  (pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('v:gatas'), 100, 'opening', 'system', gen_random_uuid(), 5000, now());

-- Set PINs
select pg_temp.login('maria', 'A'); set local role authenticated;
select public.set_my_pin('7734');
select pg_temp.login('sara', 'A'); set local role authenticated;
select public.set_my_pin('4821');
select pg_temp.login('juan', 'A'); set local role authenticated;
select public.set_my_pin('1234');
reset role;

-- ---------------------------------------------------------------------------
-- 1. Check default settings
-- ---------------------------------------------------------------------------
select is(max_cashier_discount_percent, 10::smallint, 'default max_cashier_discount_percent is 10%')
  from public.tenant_settings where tenant_id = pg_temp.t('A');

select is(max_cashier_void_amount, 50000::bigint, 'default max_cashier_void_amount is 50000 (P500)')
  from public.tenant_settings where tenant_id = pg_temp.t('A');

select is(cashier_can_void_own, false, 'default cashier_can_void_own is false')
  from public.tenant_settings where tenant_id = pg_temp.t('A');

-- ---------------------------------------------------------------------------
-- 2. Store approvers listing
-- ---------------------------------------------------------------------------
select pg_temp.login('juan', 'A'); set local role authenticated;
select is(count(*)::int, 3, 'list_store_approvers returns owner, manager and supervisor')
  from public.list_store_approvers(pg_temp.id('S01'));

select is(exists(select 1 from public.list_store_approvers(pg_temp.id('S01')) where user_id = pg_temp.u('juan')), false,
  'list_store_approvers excludes cashiers');

-- ---------------------------------------------------------------------------
-- 3. Discount threshold controls
-- ---------------------------------------------------------------------------
-- Juan rings up 2 kape (gross 5000) with 500 discount (10% exactly) -> allowed without approval
select is(pg_temp.push1('j1', 'record_sale', pg_temp.sale('j1',
  jsonb_build_array(pg_temp.item('kape', 2, 2500)),
  jsonb_build_array(pg_temp.pay('cash', 4500)),
  jsonb_build_object('discount', 500, 'subtotal', 5000, 'total', 4500)
)) ->> 'status', 'ok', 'cashier can give 10% discount without approval');

-- Juan rings up 2 kape (gross 5000) with 600 discount (12%) without approval -> rejected
select is(pg_temp.push1('j2', 'record_sale', pg_temp.sale('j2',
  jsonb_build_array(pg_temp.item('kape', 2, 2500)),
  jsonb_build_array(pg_temp.pay('cash', 4400)),
  jsonb_build_object('discount', 600, 'subtotal', 5000, 'total', 4400)
)) ->> 'hint', 'approval_required', 'cashier giving >10% discount without approval is refused');

-- Juan asks for approval with wrong PIN -> pin_wrong
select is(public.approve_supervisor_action('sale_discount', pg_temp.id('sale:j2'), '0000', pg_temp.id('S01'), pg_temp.u('sara')) ->> 'hint',
  'pin_wrong', 'wrong supervisor PIN is rejected');

-- Juan asks for approval targeting cashier pedro -> throws approver_invalid
select throws_ok(
  $$ select public.approve_supervisor_action('sale_discount', pg_temp.id('sale:j2'), '1234', pg_temp.id('S01'), pg_temp.u('pedro')) $$,
  '42501', 'this person cannot approve here', 'cannot use another cashier as approver'
);

-- Juan gets valid approval from supervisor sara with PIN 4821
select is(pg_temp.approve('appr_disc', 'sale_discount', pg_temp.id('sale:j2'), '4821', pg_temp.id('S01'), pg_temp.u('sara')) ->> 'ok',
  'true', 'supervisor PIN approval granted');

-- Juan rings up sale j2 with approval_id -> ok
select is(pg_temp.push1('j2', 'record_sale', pg_temp.sale('j2',
  jsonb_build_array(pg_temp.item('kape', 2, 2500)),
  jsonb_build_array(pg_temp.pay('cash', 4400)),
  jsonb_build_object('discount', 600, 'subtotal', 5000, 'total', 4400, 'approval_id', pg_temp.ap('appr_disc'))
)) ->> 'status', 'ok', 'cashier giving >10% discount with supervisor approval succeeds');

-- Juan tries to reuse same approval for sale j3 -> approval_invalid (ref_id mismatch) or approval_used
select is(pg_temp.push1('j3', 'record_sale', pg_temp.sale('j3',
  jsonb_build_array(pg_temp.item('kape', 2, 2500)),
  jsonb_build_array(pg_temp.pay('cash', 4400)),
  jsonb_build_object('discount', 600, 'subtotal', 5000, 'total', 4400, 'approval_id', pg_temp.ap('appr_disc'))
)) ->> 'hint', 'approval_invalid', 'reusing approval for a different sale is invalid');

-- Manager maria rings up 25% discount without approval -> ok
select pg_temp.login('maria', 'A'); set local role authenticated;
select is(pg_temp.push1('m1', 'record_sale', pg_temp.sale('m1',
  jsonb_build_array(pg_temp.item('kape', 2, 2500)),
  jsonb_build_array(pg_temp.pay('cash', 3750)),
  jsonb_build_object('discount', 1250, 'subtotal', 5000, 'total', 3750)
)) ->> 'status', 'ok', 'manager can give 25% discount without approval');

-- Superadmin owner rings up 50% discount without approval -> ok
select pg_temp.login('owner', 'A'); set local role authenticated;
select is(pg_temp.push1('o1', 'record_sale', pg_temp.sale('o1',
  jsonb_build_array(pg_temp.item('kape', 2, 2500)),
  jsonb_build_array(pg_temp.pay('cash', 2500)),
  jsonb_build_object('discount', 2500, 'subtotal', 5000, 'total', 2500)
)) ->> 'status', 'ok', 'owner can give 50% discount without approval');

-- ---------------------------------------------------------------------------
-- 4. Void controls
-- ---------------------------------------------------------------------------
-- Default settings: cashier_can_void_own = false. Juan tries to void own small sale j1 -> not_allowed
select pg_temp.login('juan', 'A'); set local role authenticated;
select is(pg_temp.push1('vj1', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:j1'))) ->> 'hint',
  'not_allowed', 'cashier cannot void own sale without approval under default settings');

-- Juan gets supervisor approval to void sale j1
select is(pg_temp.approve('appr_void1', 'void_sale', pg_temp.id('sale:j1'), '4821', pg_temp.id('S01'), pg_temp.u('sara')) ->> 'ok',
  'true', 'supervisor approves void of sale j1');

-- Juan voids sale j1 with approval -> ok
select is(pg_temp.push1('vj1', 'void_sale', jsonb_build_object(
  'sale_id', pg_temp.id('sale:j1'),
  'approval_id', pg_temp.ap('appr_void1')
)) ->> 'status', 'ok', 'cashier can void sale with supervisor approval');

-- Owner changes settings: cashier_can_void_own = true, max_cashier_void_amount = 50000 (P500)
select pg_temp.login('owner', 'A'); set local role authenticated;
update public.tenant_settings
   set cashier_can_void_own = true,
       max_cashier_void_amount = 50000
 where tenant_id = pg_temp.t('A');

-- Juan sells small sale j4 (total 2500 = P25)
select pg_temp.login('juan', 'A'); set local role authenticated;
select is(pg_temp.push1('j4', 'record_sale', pg_temp.sale('j4',
  jsonb_build_array(pg_temp.item('kape', 1, 2500)),
  jsonb_build_array(pg_temp.pay('cash', 2500))
)) ->> 'status', 'ok', 'cashier rings up small sale');

-- Juan voids own small sale j4 directly without approval -> ok
select is(pg_temp.push1('vj4', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:j4'))) ->> 'status',
  'ok', 'cashier can void own small sale (<P500) without approval when enabled');

-- Juan sells large sale j5 (6 gatas = 60000 = P600)
select is(pg_temp.push1('j5', 'record_sale', pg_temp.sale('j5',
  jsonb_build_array(pg_temp.item('gatas', 6, 10000)),
  jsonb_build_array(pg_temp.pay('cash', 60000))
)) ->> 'status', 'ok', 'cashier rings up large sale');

-- Juan tries to void large sale j5 without approval -> approval_required
select is(pg_temp.push1('vj5', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:j5'))) ->> 'hint',
  'approval_required', 'cashier voiding large sale (>P500) without approval is refused');

-- Juan gets supervisor approval to void large sale j5
select is(pg_temp.approve('appr_void5', 'void_sale', pg_temp.id('sale:j5'), '4821', pg_temp.id('S01'), pg_temp.u('sara')) ->> 'ok',
  'true', 'supervisor approves void of large sale');

-- Juan voids large sale with approval -> ok
select is(pg_temp.push1('vj5', 'void_sale', jsonb_build_object(
  'sale_id', pg_temp.id('sale:j5'),
  'approval_id', pg_temp.ap('appr_void5')
)) ->> 'status', 'ok', 'cashier voids large sale with supervisor approval');

-- Pedro rings up sale p1
select pg_temp.login('pedro', 'A'); set local role authenticated;
select is(pg_temp.push1('p1', 'record_sale', pg_temp.sale('p1',
  jsonb_build_array(pg_temp.item('kape', 1, 2500)),
  jsonb_build_array(pg_temp.pay('cash', 2500))
)) ->> 'status', 'ok', 'pedro rings up sale p1');

-- Juan tries to void Pedro''s sale p1 -> not_allowed
select pg_temp.login('juan', 'A'); set local role authenticated;
select is(pg_temp.push1('vp1', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:p1'))) ->> 'hint',
  'not_allowed', 'cashier cannot void another cashier''s sale');

-- Cashier cannot call approve_supervisor_action for non-sale action (e.g. record_expense)
select throws_ok(
  $$ select public.approve_supervisor_action('record_expense', gen_random_uuid(), '4821', pg_temp.id('S01'), pg_temp.u('sara')) $$,
  '42501', 'not allowed to ask for approvals', 'cashier cannot request expense approvals'
);

-- Manager maria can void Pedro''s sale directly without approval -> ok
select pg_temp.login('maria', 'A'); set local role authenticated;
select is(pg_temp.push1('vmp1', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:p1'))) ->> 'status',
  'ok', 'manager can void any cashier''s sale directly');

-- Audit log has recorded approved actions
reset role;
select is((select count(*)::int from public.audit_log where action = 'approval.grant' and tenant_id = pg_temp.t('A')),
  3, 'audit log recorded all 3 granted supervisor approvals');

rollback;
