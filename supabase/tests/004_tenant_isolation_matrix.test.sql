-- P1-04 tenant isolation matrix (Phase 1 acceptance proof).
--
-- Two tenants with identical business keys (same usernames, store codes, currency).
-- For each tenant x role x table we measure, as that user:
--   own_rows         rows of their own tenant they can read        (-1 = table not readable at all)
--   own_updated      own-tenant rows a harmless UPDATE touches     (-1 = no update privilege)
--   foreign_rows     rows of the other tenant they can read        (must be 0, or -1)
--   foreign_updated  other-tenant rows an UPDATE touches           (must be 0, or -1)
--   delete           DELETE on the table                           (must be 'blocked')
-- Every value is compared with an explicit expectation, so any policy change shows up here.
begin;

-- ---------------------------------------------------------------------------
-- Expectations: identical for both tenants
-- ---------------------------------------------------------------------------
create temp table expected (who text, tbl text, own_rows bigint, own_updated bigint);

insert into expected (who, tbl, own_rows, own_updated) values
  -- superadmin (owner)
  ('superadmin', 'tenants',            1,  1),
  ('superadmin', 'tenant_modules',     1, -1),
  ('superadmin', 'tenant_settings',    1,  1),
  ('superadmin', 'tenant_limits',      1, -1),
  ('superadmin', 'tenant_currencies',  1,  1),
  ('superadmin', 'profiles',           6,  1),
  ('superadmin', 'locations',          3,  3),
  ('superadmin', 'location_access',    6, -1),
  ('superadmin', 'audit_log',          3, -1),
  ('superadmin', 'platform_admins',   -1, -1),
  -- admin maria: manager in S01, supervisor in S02
  ('admin', 'tenants',                 1,  0),
  ('admin', 'tenant_modules',          1, -1),
  ('admin', 'tenant_settings',         1,  0),
  ('admin', 'tenant_limits',           0, -1),
  ('admin', 'tenant_currencies',       1,  0),
  ('admin', 'profiles',                4,  1),  -- maria, juan, ana (S01), carla (S02)
  ('admin', 'locations',               2,  0),  -- S01, S02
  ('admin', 'location_access',         5, -1),  -- own 2 + juan, ana, carla
  ('admin', 'audit_log',               1, -1),  -- S01 only (manager)
  ('admin', 'platform_admins',        -1, -1),
  -- cashier juan: S01
  ('cashier', 'tenants',               1,  0),
  ('cashier', 'tenant_modules',        1, -1),
  ('cashier', 'tenant_settings',       1,  0),
  ('cashier', 'tenant_limits',         0, -1),
  ('cashier', 'tenant_currencies',     1,  0),
  ('cashier', 'profiles',              1,  1),
  ('cashier', 'locations',             1,  0),
  ('cashier', 'location_access',       1, -1),
  ('cashier', 'audit_log',             0, -1),
  ('cashier', 'platform_admins',      -1, -1),
  -- warehouse pedro: W01
  ('warehouse', 'tenants',             1,  0),
  ('warehouse', 'tenant_modules',      1, -1),
  ('warehouse', 'tenant_settings',     1,  0),
  ('warehouse', 'tenant_limits',       0, -1),
  ('warehouse', 'tenant_currencies',   1,  0),
  ('warehouse', 'profiles',            1,  1),
  ('warehouse', 'locations',           1,  0),
  ('warehouse', 'location_access',     1, -1),
  ('warehouse', 'audit_log',           0, -1),
  ('warehouse', 'platform_admins',    -1, -1),
  -- deactivated cashier ana: sees and changes nothing
  ('inactive', 'tenants',              0,  0),
  ('inactive', 'tenant_modules',       0, -1),
  ('inactive', 'tenant_settings',      0,  0),
  ('inactive', 'tenant_limits',        0, -1),
  ('inactive', 'tenant_currencies',    0,  0),
  ('inactive', 'profiles',             0,  0),
  ('inactive', 'locations',            0,  0),
  ('inactive', 'location_access',      0, -1),
  ('inactive', 'audit_log',            0, -1),
  ('inactive', 'platform_admins',     -1, -1);

-- P2-01 catalog: every active member reads all of it (1 category, 2 products, 2 variants, 2 prices); nobody writes directly
insert into expected (who, tbl, own_rows, own_updated)
select w.who, c.tbl, case when w.who = 'inactive' then 0 else c.n end, -1
from (values ('superadmin'), ('admin'), ('cashier'), ('warehouse'), ('inactive')) w(who)
cross join (values ('categories', 1), ('products', 2), ('product_variants', 2), ('variant_prices', 2)) c(tbl, n);

-- P2-02 processed_ops: server-only, no client privilege at all
insert into expected (who, tbl, own_rows, own_updated)
select w.who, 'processed_ops', -1, -1
from (values ('superadmin'), ('admin'), ('cashier'), ('warehouse'), ('inactive')) w(who);

-- P3-01 sales and ledger. Fixtures: movements, levels, sales, items, payments at S01 and S02; 1 customer with 1 ledger row.
-- Store-scoped tables: owner and maria see S01+S02 (2), juan only S01 (1), pedro (warehouse W01) none. No client writes anywhere.
insert into expected (who, tbl, own_rows, own_updated)
select w.who, t.tbl,
       case w.who when 'superadmin' then t.n_all when 'admin' then t.n_all when 'cashier' then t.n_s01 else 0 end, -1
from (values ('superadmin'), ('admin'), ('cashier'), ('warehouse'), ('inactive')) w(who)
cross join (values ('stock_movements', 2, 1), ('stock_levels', 2, 1), ('sales', 2, 1),
                   ('sale_items', 2, 1), ('payments', 2, 1)) t(tbl, n_all, n_s01);

-- customers and utang: owner, admin, cashier see the tenant's rows (1 each); warehouse and inactive none
insert into expected (who, tbl, own_rows, own_updated)
select w.who, t.tbl, case when w.who in ('warehouse', 'inactive') then 0 else 1 end, -1
from (values ('superadmin'), ('admin'), ('cashier'), ('warehouse'), ('inactive')) w(who)
cross join (values ('customers'), ('customer_ledger')) t(tbl);

-- P6-01 rollups: superadmin and admin read their stores' rows (2 each: S01 + S02); everyone else none; nobody writes
insert into expected (who, tbl, own_rows, own_updated)
select w.who, t.tbl, case when w.who in ('superadmin', 'admin') then 2 else 0 end, -1
from (values ('superadmin'), ('admin'), ('cashier'), ('warehouse'), ('inactive')) w(who)
cross join (values ('daily_sales_summary'), ('daily_item_sales')) t(tbl);

-- P8-02 expenses and their rollup: superadmin and admin read their stores' rows (2 each: S01 + S02); everyone else none;
-- nobody writes directly (the rollup rows come from the expense insert trigger)
insert into expected (who, tbl, own_rows, own_updated)
select w.who, t.tbl, case when w.who in ('superadmin', 'admin') then 2 else 0 end, -1
from (values ('superadmin'), ('admin'), ('cashier'), ('warehouse'), ('inactive')) w(who)
cross join (values ('expenses'), ('daily_expense_summary')) t(tbl);

-- P8-02b supervisor_approvals: server-only, no client privilege at all
insert into expected (who, tbl, own_rows, own_updated)
select w.who, 'supervisor_approvals', -1, -1
from (values ('superadmin'), ('admin'), ('cashier'), ('warehouse'), ('inactive')) w(who);

-- P8-02c day_closes: superadmin and admin read their stores' closes (2 each: S01 + S02); everyone else none; no client writes
insert into expected (who, tbl, own_rows, own_updated)
select w.who, 'day_closes', case when w.who in ('superadmin', 'admin') then 2 else 0 end, -1
from (values ('superadmin'), ('admin'), ('cashier'), ('warehouse'), ('inactive')) w(who);

-- 2 tenants x (who, table) pairs x 5 metrics, plus 8 targeted checks
select plan((select count(*)::int * 2 * 5 from expected) + 8);

-- ---------------------------------------------------------------------------
-- Fixtures: two tenants built by the same loop, so every business key collides on purpose
-- ---------------------------------------------------------------------------
create function pg_temp.tid(p_tenant text) returns uuid language sql immutable
  as $$ select md5('tenant:' || p_tenant)::uuid $$;
create function pg_temp.uid(p_tenant text, p_user text) returns uuid language sql immutable
  as $$ select md5('user:' || p_tenant || ':' || p_user)::uuid $$;
create function pg_temp.lid(p_tenant text, p_code text) returns uuid language sql immutable
  as $$ select md5('loc:' || p_tenant || ':' || p_code)::uuid $$;

do $$
declare
  t record;
  u record;
begin
  for t in select * from (values ('A', 'tenant-a', 'PHP'), ('B', 'tenant-b', 'USD')) v(label, slug, ccy) loop
    insert into public.tenants (id, name, slug, base_currency)
      values (pg_temp.tid(t.label), 'Tenant ' || t.label, t.slug, t.ccy);
    insert into public.tenant_modules (tenant_id, pos, warehouse) values (pg_temp.tid(t.label), true, true);
    insert into public.tenant_settings (tenant_id) values (pg_temp.tid(t.label));
    insert into public.tenant_limits (tenant_id) values (pg_temp.tid(t.label));
    insert into public.tenant_currencies (tenant_id, code, rate_to_base) values (pg_temp.tid(t.label), 'EUR', 1.1);

    for u in select * from (values
      ('owner', 'superadmin', true),
      ('maria', 'admin', true),
      ('juan', 'cashier', true),
      ('carla', 'cashier', true),
      ('pedro', 'warehouse', true),
      ('ana', 'cashier', false)
    ) v(name, role, active) loop
      insert into auth.users (id, email)
        values (pg_temp.uid(t.label, u.name), u.name || '.' || t.slug || '@pos.invalid');
      insert into public.profiles (user_id, tenant_id, username, role, active, pin_hash)
        values (pg_temp.uid(t.label, u.name), pg_temp.tid(t.label), u.name, u.role, u.active, 'hash');
    end loop;

    insert into public.locations (id, tenant_id, type, code, name) values
      (pg_temp.lid(t.label, 'S01'), pg_temp.tid(t.label), 'store', 'S01', 'Store 1'),
      (pg_temp.lid(t.label, 'S02'), pg_temp.tid(t.label), 'store', 'S02', 'Store 2'),
      (pg_temp.lid(t.label, 'W01'), pg_temp.tid(t.label), 'warehouse', 'W01', 'Warehouse 1');

    insert into public.location_access (user_id, location_id, tenant_id, position) values
      (pg_temp.uid(t.label, 'maria'), pg_temp.lid(t.label, 'S01'), pg_temp.tid(t.label), 'manager'),
      (pg_temp.uid(t.label, 'maria'), pg_temp.lid(t.label, 'S02'), pg_temp.tid(t.label), 'supervisor'),
      (pg_temp.uid(t.label, 'juan'),  pg_temp.lid(t.label, 'S01'), pg_temp.tid(t.label), null),
      (pg_temp.uid(t.label, 'carla'), pg_temp.lid(t.label, 'S02'), pg_temp.tid(t.label), null),
      (pg_temp.uid(t.label, 'pedro'), pg_temp.lid(t.label, 'W01'), pg_temp.tid(t.label), null),
      (pg_temp.uid(t.label, 'ana'),   pg_temp.lid(t.label, 'S01'), pg_temp.tid(t.label), null);

    insert into public.audit_log (tenant_id, action, entity, location_id) values
      (pg_temp.tid(t.label), 'price.change', 'variant', pg_temp.lid(t.label, 'S01')),
      (pg_temp.tid(t.label), 'price.change', 'variant', pg_temp.lid(t.label, 'S02')),
      (pg_temp.tid(t.label), 'role.change', 'profile', null);

    -- catalog with colliding SKUs and barcodes across tenants
    insert into public.categories (id, tenant_id, name)
      values (md5('cat:' || t.label)::uuid, pg_temp.tid(t.label), 'Drinks');
    insert into public.products (id, tenant_id, category_id, name) values
      (md5('prod:' || t.label || ':1')::uuid, pg_temp.tid(t.label), md5('cat:' || t.label)::uuid, 'Cola'),
      (md5('prod:' || t.label || ':2')::uuid, pg_temp.tid(t.label), null, 'Rice');
    insert into public.product_variants (id, tenant_id, product_id, sku, barcode, is_default) values
      (md5('var:' || t.label || ':1')::uuid, pg_temp.tid(t.label), md5('prod:' || t.label || ':1')::uuid, 'COLA', '4800000000011', true),
      (md5('var:' || t.label || ':2')::uuid, pg_temp.tid(t.label), md5('prod:' || t.label || ':2')::uuid, 'RICE', null, true);
    insert into public.variant_prices (tenant_id, variant_id, currency, price) values
      (pg_temp.tid(t.label), md5('var:' || t.label || ':1')::uuid, t.ccy, 2500),
      (pg_temp.tid(t.label), md5('var:' || t.label || ':2')::uuid, t.ccy, 5200);

    -- sales: one at each store, with a movement/level, item and payment; one customer with one ledger row
    insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type) values
      (pg_temp.tid(t.label), pg_temp.lid(t.label, 'S01'), md5('var:' || t.label || ':1')::uuid, 10, 'opening'),
      (pg_temp.tid(t.label), pg_temp.lid(t.label, 'S02'), md5('var:' || t.label || ':1')::uuid, 4, 'opening');
    insert into public.customers (id, tenant_id, name)
      values (md5('cus:' || t.label)::uuid, pg_temp.tid(t.label), 'Aling Rosa');
    insert into public.sales (id, tenant_id, location_id, local_no, subtotal, total, sold_at) values
      (md5('sale:' || t.label || ':1')::uuid, pg_temp.tid(t.label), pg_temp.lid(t.label, 'S01'), 'D1-0001', 2500, 2500, now()),
      (md5('sale:' || t.label || ':2')::uuid, pg_temp.tid(t.label), pg_temp.lid(t.label, 'S02'), 'D1-0002', 2500, 2500, now());
    insert into public.sale_items (tenant_id, sale_id, location_id, variant_id, product_name, qty, unit_price, line_total) values
      (pg_temp.tid(t.label), md5('sale:' || t.label || ':1')::uuid, pg_temp.lid(t.label, 'S01'), md5('var:' || t.label || ':1')::uuid, 'Cola', 1, 2500, 2500),
      (pg_temp.tid(t.label), md5('sale:' || t.label || ':2')::uuid, pg_temp.lid(t.label, 'S02'), md5('var:' || t.label || ':1')::uuid, 'Cola', 1, 2500, 2500);
    insert into public.payments (tenant_id, sale_id, location_id, method, amount) values
      (pg_temp.tid(t.label), md5('sale:' || t.label || ':1')::uuid, pg_temp.lid(t.label, 'S01'), 'cash', 2500),
      (pg_temp.tid(t.label), md5('sale:' || t.label || ':2')::uuid, pg_temp.lid(t.label, 'S02'), 'utang', 2500);
    insert into public.customer_ledger (tenant_id, customer_id, kind, amount, sale_id)
      values (pg_temp.tid(t.label), md5('cus:' || t.label)::uuid, 'charge', 2500, md5('sale:' || t.label || ':2')::uuid);
    insert into public.daily_sales_summary (tenant_id, location_id, day, net, txn_count) values
      (pg_temp.tid(t.label), pg_temp.lid(t.label, 'S01'), '2026-11-08', 2500, 1),
      (pg_temp.tid(t.label), pg_temp.lid(t.label, 'S02'), '2026-11-08', 2500, 1);
    insert into public.daily_item_sales (tenant_id, location_id, day, variant_id, product_name, qty, revenue) values
      (pg_temp.tid(t.label), pg_temp.lid(t.label, 'S01'), '2026-11-08', md5('var:' || t.label || ':1')::uuid, 'Cola', 1, 2500),
      (pg_temp.tid(t.label), pg_temp.lid(t.label, 'S02'), '2026-11-08', md5('var:' || t.label || ':1')::uuid, 'Cola', 1, 2500);
    -- expenses: one at each store with colliding client op ids across tenants; the trigger writes one rollup row per store
    insert into public.expenses (id, tenant_id, location_id, client_op_id, amount, currency, category, paid_from, spent_at) values
      (md5('exp:' || t.label || ':1')::uuid, pg_temp.tid(t.label), pg_temp.lid(t.label, 'S01'), md5('expop:1')::uuid, 15000, t.ccy, 'utilities', 'cash', '2026-11-08T02:00:00Z'),
      (md5('exp:' || t.label || ':2')::uuid, pg_temp.tid(t.label), pg_temp.lid(t.label, 'S02'), md5('expop:2')::uuid, 4000, t.ccy, 'transport', 'ewallet', '2026-11-08T02:00:00Z');
    insert into public.supervisor_approvals (tenant_id, location_id, action, ref_id, requested_by, approved_by, expires_at)
      values (pg_temp.tid(t.label), pg_temp.lid(t.label, 'S02'), 'void_expense', md5('exp:' || t.label || ':2')::uuid,
              pg_temp.uid(t.label, 'maria'), pg_temp.uid(t.label, 'maria'), now() + interval '1 hour');
    -- day closes: one at each store, colliding client op ids across tenants
    insert into public.day_closes (id, tenant_id, location_id, client_op_id, day, currency, expected_cash, counted_cash,
                                   difference, server_expected_cash, closed_at) values
      (md5('dc:' || t.label || ':1')::uuid, pg_temp.tid(t.label), pg_temp.lid(t.label, 'S01'), md5('dcop:1')::uuid, '2026-11-08', t.ccy, 2500, 2400, -100, 2500, now()),
      (md5('dc:' || t.label || ':2')::uuid, pg_temp.tid(t.label), pg_temp.lid(t.label, 'S02'), md5('dcop:2')::uuid, '2026-11-08', t.ccy, 0, 0, 0, 0, now());
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Probe: run every measurement as the given user, collect results as postgres
-- ---------------------------------------------------------------------------
create temp table matrix (
  tenant text, who text, tbl text,
  own_rows bigint, own_updated bigint, foreign_rows bigint, foreign_updated bigint, del text
);

create function pg_temp.probe(p_tenant text, p_who text, p_user uuid)
returns void
language plpgsql
as $$
declare
  v_tenant  uuid := pg_temp.tid(p_tenant);
  r         record;
  v_own     bigint;
  v_foreign bigint;
  v_own_u   bigint;
  v_for_u   bigint;
  v_del     text;
  v_rows    jsonb := '[]'::jsonb;
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user, 'role', 'authenticated', 'tenant_id', v_tenant)::text,
    true
  );
  execute 'set local role authenticated';

  for r in select * from (values
    ('tenants',           'id',        'name = name'),
    ('tenant_modules',    'tenant_id', 'pos = pos'),
    ('tenant_settings',   'tenant_id', 'receipt_footer = receipt_footer'),
    ('tenant_limits',     'tenant_id', 'max_users = max_users'),
    ('tenant_currencies', 'tenant_id', 'active = active'),
    ('profiles',          'tenant_id', 'full_name = full_name'),
    ('locations',         'tenant_id', 'name = name'),
    ('location_access',   'tenant_id', 'position = position'),
    ('audit_log',         'tenant_id', 'action = action'),
    ('platform_admins',   'user_id',   'created_at = created_at'),
    ('categories',        'tenant_id', 'name = name'),
    ('products',          'tenant_id', 'name = name'),
    ('product_variants',  'tenant_id', 'sku = sku'),
    ('variant_prices',    'tenant_id', 'price = price'),
    ('processed_ops',     'tenant_id', 'kind = kind'),
    ('stock_movements',   'tenant_id', 'qty_delta = qty_delta'),
    ('stock_levels',      'tenant_id', 'qty_on_hand = qty_on_hand'),
    ('sales',             'tenant_id', 'total = total'),
    ('sale_items',        'tenant_id', 'qty = qty'),
    ('payments',          'tenant_id', 'amount = amount'),
    ('customers',         'tenant_id', 'name = name'),
    ('customer_ledger',   'tenant_id', 'amount = amount'),
    ('daily_sales_summary', 'tenant_id', 'net = net'),
    ('daily_item_sales',  'tenant_id', 'qty = qty'),
    ('expenses',          'tenant_id', 'note = note'),
    ('daily_expense_summary', 'tenant_id', 'amount = amount'),
    ('supervisor_approvals', 'tenant_id', 'used_at = used_at'),
    ('day_closes',        'tenant_id', 'note = note')
  ) v(tbl, tcol, upd) loop
    begin
      execute format(
        'select count(*) filter (where %1$I = $1), count(*) filter (where %1$I <> $1) from public.%2$I',
        r.tcol, r.tbl)
        into v_own, v_foreign using v_tenant;
    exception when insufficient_privilege then
      v_own := -1; v_foreign := -1;
    end;

    begin
      execute format('with u as (update public.%I set %s where %I = $1 returning 1) select count(*) from u',
        r.tbl, r.upd, r.tcol)
        into v_own_u using v_tenant;
    exception when insufficient_privilege then
      v_own_u := -1;
    end;

    begin
      execute format('with u as (update public.%I set %s where %I <> $1 returning 1) select count(*) from u',
        r.tbl, r.upd, r.tcol)
        into v_for_u using v_tenant;
    exception when insufficient_privilege then
      v_for_u := -1;
    end;

    begin
      execute format('with d as (delete from public.%I returning 1) select ''deleted '' || count(*) from d', r.tbl)
        into v_del;
    exception when insufficient_privilege then
      v_del := 'blocked';
    end;

    v_rows := v_rows || jsonb_build_object(
      'tbl', r.tbl, 'own', v_own, 'foreign', v_foreign, 'own_u', v_own_u, 'for_u', v_for_u, 'del', v_del);
  end loop;

  execute 'reset role';

  insert into matrix
  select p_tenant, p_who, x ->> 'tbl', (x ->> 'own')::bigint, (x ->> 'own_u')::bigint,
         (x ->> 'foreign')::bigint, (x ->> 'for_u')::bigint, x ->> 'del'
  from jsonb_array_elements(v_rows) x;
end;
$$;

do $$
declare
  t text;
  u record;
begin
  foreach t in array array['A', 'B'] loop
    for u in select * from (values
      ('superadmin', 'owner'), ('admin', 'maria'), ('cashier', 'juan'), ('warehouse', 'pedro'), ('inactive', 'ana')
    ) v(who, name) loop
      perform pg_temp.probe(t, u.who, pg_temp.uid(t, u.name));
    end loop;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- The matrix: 5 assertions per (tenant, who, table)
-- ---------------------------------------------------------------------------
select is(m.own_rows, e.own_rows,
          format('[%s] %s reads expected own-tenant rows of %s', m.tenant, m.who, m.tbl))
from matrix m join expected e using (who, tbl) order by m.tenant, m.who, m.tbl;

select is(m.own_updated, e.own_updated,
          format('[%s] %s updates expected own-tenant rows of %s', m.tenant, m.who, m.tbl))
from matrix m join expected e using (who, tbl) order by m.tenant, m.who, m.tbl;

select is(m.foreign_rows, case when e.own_rows = -1 then -1 else 0 end::bigint,
          format('[%s] %s reads zero rows of the other tenant in %s', m.tenant, m.who, m.tbl))
from matrix m join expected e using (who, tbl) order by m.tenant, m.who, m.tbl;

select is(m.foreign_updated, case when e.own_updated = -1 then -1 else 0 end::bigint,
          format('[%s] %s updates zero rows of the other tenant in %s', m.tenant, m.who, m.tbl))
from matrix m join expected e using (who, tbl) order by m.tenant, m.who, m.tbl;

select is(m.del, 'blocked',
          format('[%s] %s cannot delete from %s', m.tenant, m.who, m.tbl))
from matrix m join expected e using (who, tbl) order by m.tenant, m.who, m.tbl;

-- ---------------------------------------------------------------------------
-- Targeted checks
-- ---------------------------------------------------------------------------

-- Coverage: a new tenant table must be added to this matrix.
select is_empty(
  $$ select c.relname
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p')
       and c.relname not in ('currencies')
       and c.relname not in (select distinct tbl from matrix) $$,
  'every public table is covered by the isolation matrix'
);

-- Business keys really collide across the two tenants.
select is(
  (select count(*)::int from public.locations where code = 'S01'),
  2,
  'both tenants own a store coded S01'
);

-- Admin with different positions per store, in both tenants.
create function pg_temp.login(p_tenant text, p_user text) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', pg_temp.uid(p_tenant, p_user), 'role', 'authenticated', 'tenant_id', pg_temp.tid(p_tenant))::text,
    true);
$$;

select pg_temp.login('A', 'maria');
set local role authenticated;
select ok(public.has_location_access(pg_temp.lid('A', 'S01'), 'manager'), '[A] admin is manager in S01');
select ok(not public.has_location_access(pg_temp.lid('A', 'S02'), 'manager'), '[A] admin is not manager in S02');
select ok(public.has_location_access(pg_temp.lid('A', 'S02'), 'supervisor'), '[A] admin is supervisor in S02');
select ok(not public.has_location_access(pg_temp.lid('B', 'S01')), '[A] admin has no access to tenant B''s S01');
reset role;

select pg_temp.login('B', 'maria');
set local role authenticated;
select ok(
  public.has_location_access(pg_temp.lid('B', 'S01'), 'manager')
    and not public.has_location_access(pg_temp.lid('B', 'S02'), 'manager')
    and public.has_location_access(pg_temp.lid('B', 'S02'), 'supervisor'),
  '[B] same-named admin has the same per-store positions in tenant B'
);
reset role;

-- A superadmin cannot plant rows in another tenant.
select pg_temp.login('A', 'owner');
set local role authenticated;
select throws_ok(
  format($$ insert into public.tenant_currencies (tenant_id, code, rate_to_base) values (%L, 'JPY', 1) $$, pg_temp.tid('B')),
  '42501', null,
  '[A] superadmin cannot insert into tenant B'
);
reset role;

select * from finish();
rollback;
