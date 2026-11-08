-- ---------------------------------------------------------------------------
-- 030_offline_pins_and_approvals.test.sql
-- Card F-06: Offline PIN unlock & material delivery, offline supervisor overrides, and audit of refused ops
-- ---------------------------------------------------------------------------
begin;
select plan(24);

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

create function pg_temp.sale(k text, items jsonb, pays jsonb, extra jsonb default '{}') returns jsonb language sql immutable as $$
  select jsonb_build_object('id', pg_temp.id('sale:' || k), 'local_no', 'R-' || k, 'location_id', pg_temp.id('S01'),
                            'sold_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                            'items', items, 'payments', pays) || extra
$$;

-- Setup test users
insert into auth.users (id, email)
select pg_temp.u(n), n || '@test.invalid' from unnest(array['owner', 'maria', 'sara', 'juan', 'pedro', 'owner_b']) n;

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
  (pg_temp.u('owner'),   pg_temp.t('A'), 'owner',   'Owner Boss',      'superadmin', true),
  (pg_temp.u('maria'),   pg_temp.t('A'), 'maria',   'Maria Manager',   'admin',      true),
  (pg_temp.u('sara'),    pg_temp.t('A'), 'sara',    'Sara Supervisor', 'admin',      true),
  (pg_temp.u('juan'),    pg_temp.t('A'), 'juan',    'Juan Cashier',    'cashier',    true),
  (pg_temp.u('pedro'),   pg_temp.t('A'), 'pedro',   'Pedro Cashier',   'cashier',    true),
  (pg_temp.u('owner_b'), pg_temp.t('B'), 'owner_b', 'Owner B',         'superadmin', true);

insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('sara'),  pg_temp.id('S01'), pg_temp.t('A'), 'supervisor'),
  (pg_temp.u('juan'),  pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('S01'), pg_temp.t('A'), null);

-- Set PIN hashes
select pg_temp.login('owner', 'A');
select public.set_my_pin('1111');
select pg_temp.login('maria', 'A');
select public.set_my_pin('2222');
select pg_temp.login('sara', 'A');
select public.set_my_pin('3333');
select pg_temp.login('juan', 'A');
select public.set_my_pin('4444');
-- pedro has no PIN set

-- Product & Stock setup
select pg_temp.login('owner', 'A');
insert into public.products (id, tenant_id, name, track_stock) values
  (pg_temp.id('prod'), pg_temp.t('A'), 'Coke Can', true);
insert into public.product_variants (id, tenant_id, product_id, sku, cost) values
  (pg_temp.id('v:coke'), pg_temp.t('A'), pg_temp.id('prod'), 'COKE', 7000);
insert into public.variant_prices (tenant_id, variant_id, currency, price) values
  (pg_temp.t('A'), pg_temp.id('v:coke'), 'PHP', 10000);
insert into public.stock_levels (tenant_id, location_id, variant_id, qty_on_hand, avg_cost) values
  (pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('v:coke'), 1000, 7000);

-- ---------------------------------------------------------------------------
-- 1. Test pull_offline_pins
-- ---------------------------------------------------------------------------
select pg_temp.login('juan', 'A');

-- 1. Juan cannot pull pins for S02 (no access)
select is(
  pg_temp.hint(format('select * from public.pull_offline_pins(%L)', pg_temp.id('S02'))),
  'location_denied',
  '1. Juan cannot pull offline pins for store S02 where he has no assignment'
);

-- 2. Juan cannot pull pins for SB1 (cross-tenant)
select is(
  pg_temp.hint(format('select * from public.pull_offline_pins(%L)', pg_temp.id('SB1'))),
  'location_denied',
  '2. Juan cannot pull offline pins across tenants'
);

-- 3. Juan pulls offline pins for S01
select is(
  (select count(*) from public.pull_offline_pins(pg_temp.id('S01'))),
  4::bigint,
  '3. Pulls 4 active users with PINs for S01 (owner, maria, sara, juan; pedro excluded as he has no PIN)'
);

-- 4. Pedro without PIN is not in the list
select ok(
  not exists (select 1 from public.pull_offline_pins(pg_temp.id('S01')) where username = 'pedro'),
  '4. User without a PIN (pedro) is excluded from offline pins'
);

-- 5. Returned pin hashes are valid PBKDF2 formats
select ok(
  (select bool_and(pin_hash like 'pbkdf2_sha256$%') from public.pull_offline_pins(pg_temp.id('S01'))),
  '5. All returned pin hashes follow pbkdf2_sha256 format'
);

-- 6. Manager and supervisor have correct positions returned
select is(
  (select "position" from public.pull_offline_pins(pg_temp.id('S01')) where username = 'maria'),
  'manager',
  '6. Position is correctly returned for store manager'
);

-- ---------------------------------------------------------------------------
-- 2. Test Offline Approval on Cashier Sale Discount (> 10% default threshold)
-- ---------------------------------------------------------------------------

-- 7. Cashier sale with 20% discount without approval is rejected
select is(
  (pg_temp.push1('s_no_appr', 'record_sale',
    pg_temp.sale('s_no_appr',
      jsonb_build_array(pg_temp.item('coke', 1, 10000, 2000)),
      jsonb_build_array(pg_temp.pay('cash', 8000))
    )
  ) ->> 'status'),
  'rejected',
  '7. 20% discount without approval is rejected by cashier'
);

-- 8. Refused op is written to audit_log with action 'op.refused'
select ok(
  exists (
    select 1 from public.audit_log
     where tenant_id = pg_temp.t('A')
       and action = 'op.refused'
       and entity = 'record_sale'
       and entity_id = pg_temp.id('op:s_no_appr')
       and meta ->> 'hint' = 'approval_required'
  ),
  '8. Refused sale op is recorded in audit_log with hint approval_required'
);

-- 9. Cashier sale with 20% discount with valid offline approval by supervisor Sara
select is(
  (pg_temp.push1('s_off_appr', 'record_sale',
    pg_temp.sale('s_off_appr',
      jsonb_build_array(pg_temp.item('coke', 1, 10000, 2000)),
      jsonb_build_array(pg_temp.pay('cash', 8000)),
      jsonb_build_object(
        'offline_approval', jsonb_build_object(
          'approver_id', pg_temp.u('sara'),
          'approved_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        )
      )
    )
  ) ->> 'status'),
  'ok',
  '9. 20% discount with valid supervisor offline approval succeeds'
);

-- 10. Audit log records 'approval.offline'
select ok(
  exists (
    select 1 from public.audit_log
     where tenant_id = pg_temp.t('A')
       and action = 'approval.offline'
       and entity = 'supervisor_approval'
       and entity_id = pg_temp.u('sara')
       and meta ->> 'action' = 'sale_discount'
  ),
  '10. Audit log contains approval.offline record for supervisor Sara'
);

-- 11. Audit log records 'sale.create' with approved_by = Sara
select is(
  (select meta ->> 'approved_by'
     from public.audit_log
    where tenant_id = pg_temp.t('A')
      and action = 'sale.create'
      and entity_id = pg_temp.id('sale:s_off_appr')),
  pg_temp.u('sara')::text,
  '11. sale.create audit log records approved_by = Sara'
);

-- 12. Invalid offline approver (cashier Pedro) is rejected
select is(
  (pg_temp.push1('s_bad_appr', 'record_sale',
    pg_temp.sale('s_bad_appr',
      jsonb_build_array(pg_temp.item('coke', 1, 10000, 2000)),
      jsonb_build_array(pg_temp.pay('cash', 8000)),
      jsonb_build_object(
        'offline_approval', jsonb_build_object(
          'approver_id', pg_temp.u('pedro'),
          'approved_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        )
      )
    )
  ) ->> 'hint'),
  'approval_invalid',
  '12. Offline approval by non-approver cashier is rejected with approval_invalid'
);

-- 13. Audit log records op.refused for the invalid offline approval
select ok(
  exists (
    select 1 from public.audit_log
     where tenant_id = pg_temp.t('A')
       and action = 'op.refused'
       and entity_id = pg_temp.id('op:s_bad_appr')
       and meta ->> 'hint' = 'approval_invalid'
  ),
  '13. op.refused recorded in audit_log for invalid offline approval'
);

-- ---------------------------------------------------------------------------
-- 3. Test Offline Approval on Cashier Sale Void
-- ---------------------------------------------------------------------------

-- 14. Voiding own sale with valid offline approval by Manager Maria succeeds
select is(
  (pg_temp.push1('v_off_appr', 'void_sale',
    jsonb_build_object(
      'sale_id', pg_temp.id('sale:s_off_appr'),
      'reason', 'Customer return with manager override',
      'offline_approval', jsonb_build_object(
        'approver_id', pg_temp.u('maria'),
        'approved_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
      )
    )
  ) ->> 'status'),
  'ok',
  '14. Cashier void with valid offline manager approval succeeds'
);

-- 15. Sale is marked voided
select is(
  (select status from public.sales where id = pg_temp.id('sale:s_off_appr')),
  'voided',
  '15. Sale status changed to voided'
);

-- 16. Audit log records approval.offline for Maria
select ok(
  exists (
    select 1 from public.audit_log
     where tenant_id = pg_temp.t('A')
       and action = 'approval.offline'
       and entity_id = pg_temp.u('maria')
       and meta ->> 'action' = 'void_sale'
  ),
  '16. Audit log contains approval.offline for void_sale'
);

-- 17. Audit log records sale.void with approved_by = Maria
select is(
  (select meta ->> 'approved_by'
     from public.audit_log
    where tenant_id = pg_temp.t('A')
      and action = 'sale.void'
      and entity_id = pg_temp.id('sale:s_off_appr')),
  pg_temp.u('maria')::text,
  '17. sale.void audit log records approved_by = Maria'
);

-- ---------------------------------------------------------------------------
-- 4. Test Offline Approval on Expenses
-- ---------------------------------------------------------------------------
select pg_temp.login('sara', 'A');

-- 18. Supervisor records expense with offline approval by Owner
select is(
  (pg_temp.push1('e_off_appr', 'record_expense',
    jsonb_build_object(
      'id', pg_temp.id('exp:1'),
      'amount', 25000,
      'category', 'utilities',
      'location_id', pg_temp.id('S01'),
      'offline_approval', jsonb_build_object(
        'approver_id', pg_temp.u('owner'),
        'approved_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
      )
    )
  ) ->> 'status'),
  'ok',
  '18. Supervisor records expense with valid offline approval by owner'
);

-- 19. Expense approved_by column matches Owner
select is(
  (select approved_by from public.expenses where id = pg_temp.id('exp:1')),
  pg_temp.u('owner'),
  '19. Expense approved_by is set to Owner'
);

-- ---------------------------------------------------------------------------
-- 5. Lockout Check on Offline Approval
-- ---------------------------------------------------------------------------
-- Simulate 5 recent PIN failures for Sara
insert into public.audit_log (tenant_id, user_id, action, entity, entity_id, location_id, meta, created_at)
select pg_temp.t('A'), pg_temp.u('juan'), 'pin.failed', 'profile', pg_temp.u('sara'), pg_temp.id('S01'), '{}'::jsonb, now() - interval '2 minutes'
from generate_series(1, 5);

select pg_temp.login('juan', 'A');

-- 20. Offline approval by locked approver is rejected
select is(
  (pg_temp.push1('s_locked', 'record_sale',
    pg_temp.sale('s_locked',
      jsonb_build_array(pg_temp.item('coke', 1, 10000, 2000)),
      jsonb_build_array(pg_temp.pay('cash', 8000)),
      jsonb_build_object(
        'offline_approval', jsonb_build_object(
          'approver_id', pg_temp.u('sara'),
          'approved_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        )
      )
    )
  ) ->> 'hint'),
  'pin_locked',
  '20. Offline approval by locked approver is rejected with pin_locked'
);

-- 21. Op is audited as op.refused with hint pin_locked
select ok(
  exists (
    select 1 from public.audit_log
     where tenant_id = pg_temp.t('A')
       and action = 'op.refused'
       and entity_id = pg_temp.id('op:s_locked')
       and meta ->> 'hint' = 'pin_locked'
  ),
  '21. Audit log records op.refused with hint pin_locked'
);

-- ---------------------------------------------------------------------------
-- 6. Audit of General Refused Ops (missing items, etc.)
-- ---------------------------------------------------------------------------

-- 22. Op with 0 items is rejected
select is(
  (pg_temp.push1('s_empty', 'record_sale',
    jsonb_build_object(
      'id', pg_temp.id('sale:s_empty'),
      'local_no', 'R-EMPTY',
      'location_id', pg_temp.id('S01'),
      'items', '[]'::jsonb,
      'payments', '[]'::jsonb
    )
  ) ->> 'hint'),
  'items_required',
  '22. Sale with 0 items is rejected with items_required'
);

-- 23. Audit log records op.refused with hint items_required
select ok(
  exists (
    select 1 from public.audit_log
     where tenant_id = pg_temp.t('A')
       and action = 'op.refused'
       and entity_id = pg_temp.id('op:s_empty')
       and meta ->> 'hint' = 'items_required'
  ),
  '23. General refused op is recorded in audit_log'
);

-- 24. Audit log records location_id for the refused op
select is(
  (select location_id from public.audit_log
    where tenant_id = pg_temp.t('A')
      and action = 'op.refused'
      and entity_id = pg_temp.id('op:s_empty')),
  pg_temp.id('S01'),
  '24. Refused op audit log captures location_id'
);

rollback;
