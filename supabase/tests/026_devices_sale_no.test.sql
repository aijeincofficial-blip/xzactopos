-- F-02 Server sale number and devices: register_device (create, idempotent, last seen, other tenant, limit, RLS per role),
-- sale_no (format, per store and tenant-timezone day, gap-free, replay, more than 9999), the device on a sale (known,
-- unknown = registered, another tenant's / garbage = ignored), the local-number rule per device (B1), void keeps the
-- number, the pull, rows from before F-02, and server-only pieces. Tenant A (Asia/Manila) has stores S01 and S02 and a
-- warehouse; tenant B is a solo store; tenant C has a device limit of 2.
begin;
select plan(72);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;
create function pg_temp.t(p text) returns uuid language sql immutable as $$ select md5('t:' || p)::uuid $$;
create function pg_temp.id(p text) returns uuid language sql immutable as $$ select md5('id:' || p)::uuid $$;
create function pg_temp.login(p_user text, p_tenant text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated', 'tenant_id', pg_temp.t(p_tenant))::text, true);
$$;
-- runs [sql]; 'ok', or the error's stable hint key (its SQLSTATE when it has none)
create function pg_temp.try(sql text) returns text language plpgsql as $$
declare
  h text;
begin
  execute sql;
  return 'ok';
exception when others then
  get stacked diagnostics h = pg_exception_hint;
  return case when h ~ '^[a-z_]+$' then h else sqlstate end; -- our hints are snake_case keys
end;
$$;
-- how many rows the data-changing statement [sql] touched
create function pg_temp.n(sql text) returns int language plpgsql as $$
declare
  v int;
begin
  execute format('with u as (%s returning 1) select count(*)::int from u', sql) into v;
  return v;
end;
$$;
create function pg_temp.reg(dev text, name text default null, platform text default null) returns jsonb language sql as $$
  select public.register_device(pg_temp.id('dev:' || dev), name, platform)
$$;
create function pg_temp.push1(k text, kind text, payload jsonb) returns jsonb language sql as $$
  select public.sync_push(jsonb_build_array(
    jsonb_build_object('op_id', pg_temp.id('op:' || k), 'kind', kind, 'payload', payload))) -> 0
$$;
-- one kape at 1000, cash. [no] = local number (default 'R-' || k); [dev] = device key, or a raw value with [raw_dev]
create function pg_temp.sale(k text, loc text, sold text, no text default null, dev text default null,
                             raw_dev text default null, variant text default 'kape')
returns jsonb language sql as $$
  select pg_temp.push1(k, 'record_sale', jsonb_strip_nulls(jsonb_build_object(
    'id', pg_temp.id('sale:' || k), 'local_no', coalesce(no, 'R-' || k), 'sold_at', sold,
    'location_id', case when loc is not null then pg_temp.id(loc) end,
    'device_id', coalesce(raw_dev, case when dev is not null then pg_temp.id('dev:' || dev)::text end),
    'items', jsonb_build_array(jsonb_build_object('variant_id', pg_temp.id('v:' || variant), 'qty', 1, 'unit_price', 1000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 1000)))))
$$;

insert into auth.users (id, email)
  select pg_temp.u(n), n || '@test.invalid'
  from unnest(array['owner', 'maria', 'juan', 'pedro', 'ana', 'ownerB', 'ownerC']) n;
insert into public.tenants (id, name, slug, base_currency, timezone) values
  (pg_temp.t('A'), 'A', 'tenant-a', 'PHP', 'Asia/Manila'), (pg_temp.t('B'), 'B', 'tenant-b', 'PHP', 'UTC'),
  (pg_temp.t('C'), 'C', 'tenant-c', 'PHP', 'UTC');
insert into public.tenant_modules (tenant_id, pos, warehouse) values
  (pg_temp.t('A'), true, true), (pg_temp.t('B'), true, false), (pg_temp.t('C'), true, false);
insert into public.tenant_limits (tenant_id, max_devices) values (pg_temp.t('A'), 50), (pg_temp.t('B'), 50), (pg_temp.t('C'), 2);
insert into public.profiles (user_id, tenant_id, username, role, active) values
  (pg_temp.u('owner'), pg_temp.t('A'), 'owner', 'superadmin', true),
  (pg_temp.u('maria'), pg_temp.t('A'), 'maria', 'admin', true),
  (pg_temp.u('juan'), pg_temp.t('A'), 'juan', 'cashier', true),
  (pg_temp.u('pedro'), pg_temp.t('A'), 'pedro', 'warehouse', true),
  (pg_temp.u('ana'), pg_temp.t('A'), 'ana', 'cashier', false),
  (pg_temp.u('ownerB'), pg_temp.t('B'), 'owner', 'superadmin', true),
  (pg_temp.u('ownerC'), pg_temp.t('C'), 'owner', 'superadmin', true);
insert into public.locations (id, tenant_id, type, code, name) values
  (pg_temp.id('S01'), pg_temp.t('A'), 'store', 'S01', 'A1'),
  (pg_temp.id('S02'), pg_temp.t('A'), 'store', 'S02', 'A2'),
  (pg_temp.id('W01'), pg_temp.t('A'), 'warehouse', 'W01', 'AW'),
  (pg_temp.id('SB'), pg_temp.t('B'), 'store', 'S01', 'B1');
insert into public.location_access (user_id, location_id, tenant_id, position) values
  (pg_temp.u('maria'), pg_temp.id('S01'), pg_temp.t('A'), 'manager'),
  (pg_temp.u('juan'), pg_temp.id('S01'), pg_temp.t('A'), null),
  (pg_temp.u('pedro'), pg_temp.id('W01'), pg_temp.t('A'), null),
  (pg_temp.u('ana'), pg_temp.id('S01'), pg_temp.t('A'), null);
insert into public.products (id, tenant_id, name, track_stock) values
  (pg_temp.id('p:kape'), pg_temp.t('A'), 'Kape', true), (pg_temp.id('p:b'), pg_temp.t('B'), 'B item', true);
insert into public.product_variants (id, tenant_id, product_id, sku, is_default, cost) values
  (pg_temp.id('v:kape'), pg_temp.t('A'), pg_temp.id('p:kape'), 'KAPE', true, 100),
  (pg_temp.id('v:b'), pg_temp.t('B'), pg_temp.id('p:b'), 'B1', true, 100);

-- ===== schema =====
select has_table('public', 'devices', 'devices exists');
select has_table('public', 'sale_counters', 'sale_counters exists');
select col_is_null('public', 'sales', 'device_id', 'a sale''s device may be empty (rows before F-02)');
select col_is_null('public', 'sales', 'sale_no', 'the server number may be empty (rows before F-02)');
select is((select count(*)::int from pg_constraint where conname = 'sales_local_no_per_tenant'), 0,
          'the old tenant-wide local-number constraint is gone (replaced by two partial unique indexes)');

-- ===== register_device =====
select pg_temp.login('juan', 'A');
set local role authenticated;
select is((select (r ->> 'id', r ->> 'name', r ->> 'platform', r ->> 'user_id')::text
           from pg_temp.reg('j1', '  Cashier phone ', 'android') r),
          (pg_temp.id('dev:j1'), 'Cashier phone', 'android', pg_temp.u('juan'))::text,
          'a cashier registers her phone (name trimmed, user = who registered it)');
reset role;
update public.devices set last_seen_at = '2026-01-01T00:00:00Z' where id = pg_temp.id('dev:j1');
select pg_temp.login('juan', 'A');
set local role authenticated;
select is((select (r ->> 'name', r ->> 'platform', (r ->> 'last_seen_at')::timestamptz > '2026-01-02')::text
           from pg_temp.reg('j1') r),
          '("Cashier phone",android,t)', 'registering again keeps name and platform and bumps last seen');
select is((select count(*)::int from public.devices), 1, 'still one row (idempotent)');
reset role;
select is((select (first_seen_at = created_at)::text from public.devices where id = pg_temp.id('dev:j1')), 'true',
          'first seen is kept');
select pg_temp.login('maria', 'A');
set local role authenticated;
select is((select r ->> 'user_id' from pg_temp.reg('j1', 'Front counter') r), pg_temp.u('juan')::text,
          'another user of the tenant on the same phone: renamed, the registering user stays');
select is(pg_temp.try($$ select pg_temp.reg('m1') $$), 'ok', 'an admin registers her own phone');
select pg_temp.login('pedro', 'A');
select is(pg_temp.try($$ select pg_temp.reg('p1', null, 'web') $$), 'ok', 'warehouse staff register too');
select pg_temp.login('owner', 'A');
select is(pg_temp.try($$ select pg_temp.reg('o1') $$), 'ok', 'the owner registers');
select is(pg_temp.try($$ select public.register_device(null) $$), 'id_required', 'a device needs an id');
select is(pg_temp.try($$ select pg_temp.reg('o2', repeat('x', 61)) $$), 'invalid_value', 'a name over 60 is refused');
select pg_temp.login('ana', 'A');
select is(pg_temp.try($$ select pg_temp.reg('a1') $$), '42501', 'an inactive user cannot register');
select pg_temp.login('ownerB', 'B');
select is(pg_temp.try($$ select pg_temp.reg('j1') $$), 'id_conflict', 'another tenant''s device id is refused');
reset role;
select is((select (tenant_id, name)::text from public.devices where id = pg_temp.id('dev:j1')),
          (pg_temp.t('A'), 'Front counter')::text, 'and that device is untouched');

-- ===== RLS on devices =====
select pg_temp.login('juan', 'A');
set local role authenticated;
select is((select array_agg(id) from public.devices), array[pg_temp.id('dev:j1')], 'a cashier reads only her own device');
select is(pg_temp.n($$ update public.devices set name = 'Mine' $$), 1,
          'and renames only her own');
select is(pg_temp.try(format($$ insert into public.devices (id, tenant_id, user_id, name) values (%L, %L, %L, 'x') $$,
                             pg_temp.id('dev:j2'), pg_temp.t('A'), pg_temp.u('juan'))), 'ok',
          'she may add her own device directly');
select is(pg_temp.try(format($$ insert into public.devices (id, tenant_id, user_id) values (%L, %L, %L) $$,
                             pg_temp.id('dev:j3'), pg_temp.t('A'), pg_temp.u('maria'))), '42501',
          'but not one in someone else''s name');
select is(pg_temp.try(format($$ update public.devices set user_id = %L $$, pg_temp.u('maria'))), '42501',
          'the owner of a device row cannot be changed by a client');
select is(pg_temp.try($$ delete from public.devices $$), '42501', 'devices are never hard-deleted');
select pg_temp.login('maria', 'A');
select is((select count(*)::int from public.devices), 5, 'an admin reads every device of the tenant');
select is(pg_temp.n($$ update public.devices set name = name $$), 1,
          'an admin updates only her own device');
select pg_temp.login('pedro', 'A');
select is((select count(*)::int from public.devices), 1, 'warehouse staff read only their own');
select pg_temp.login('ownerB', 'B');
select is((select count(*)::int from public.devices), 0, 'another tenant reads none');
select pg_temp.login('owner', 'A');
select is(pg_temp.n(format($$ update public.devices set deleted_at = now() where id = %L $$, pg_temp.id('dev:j2'))), 1,
          'the owner retires a device of the tenant');
reset role;

-- ===== the device limit (tenant C: 2) =====
select pg_temp.login('ownerC', 'C');
set local role authenticated;
select is(pg_temp.try($$ select pg_temp.reg('c1') $$) || ' ' || pg_temp.try($$ select pg_temp.reg('c2') $$), 'ok ok',
          'two devices fit');
select is(pg_temp.try($$ select pg_temp.reg('c3') $$), 'device_limit', 'a third is refused with a stable hint');
select is(pg_temp.try($$ select pg_temp.reg('c1') $$), 'ok', 'an existing device still registers at the limit');
select is(pg_temp.try(format($$ insert into public.devices (id, tenant_id, user_id) values (%L, %L, %L) $$,
                             pg_temp.id('dev:c4'), pg_temp.t('C'), pg_temp.u('ownerC'))), 'device_limit',
          'the limit holds for a direct insert too');
update public.devices set deleted_at = now() where id = pg_temp.id('dev:c1');
select is(pg_temp.try($$ select pg_temp.reg('c3') $$), 'ok', 'a retired device frees its place');
select is(pg_temp.try($$ select pg_temp.reg('c1') $$), 'device_limit', 'a retired device cannot come back over the limit');
reset role;

-- ===== sale_no: format, per store, per tenant-timezone day =====
select pg_temp.login('owner', 'A');
set local role authenticated;
-- Manila = UTC+8: 02:00Z is 10:00 on the 5th; 15:59Z is 23:59 on the 5th; 16:30Z is 00:30 on the 6th
select is(pg_temp.sale('x1', 'S01', '2026-11-05T02:00:00Z') -> 'result' ->> 'sale_no', 'S01-261105-0001',
          'the first sale of the day at S01 gets S01-YYMMDD-0001 (in the op result)');
select is(pg_temp.sale('x2', 'S01', '2026-11-05T03:00:00Z') -> 'result' ->> 'sale_no', 'S01-261105-0002',
          'the next one 0002');
select is(pg_temp.sale('x3', 'S02', '2026-11-05T03:00:00Z') -> 'result' ->> 'sale_no', 'S02-261105-0001',
          'another store the same day counts on its own');
select is(pg_temp.sale('x4', 'S01', '2026-11-05T16:30:00Z') -> 'result' ->> 'sale_no', 'S01-261106-0001',
          'after midnight in the tenant''s timezone it is the next business day (UTC is still the 5th)');
select is(pg_temp.sale('x5', 'S01', '2026-11-05T15:59:00Z') -> 'result' ->> 'sale_no', 'S01-261105-0003',
          'one minute before midnight Manila is still the 5th (synced late: it continues that day''s count)');
select is(pg_temp.sale('x1', 'S01', '2026-11-05T02:00:00Z') -> 'result' ->> 'sale_no', 'S01-261105-0001',
          'a replayed op returns the same number');
select is(pg_temp.sale('x6', 'S01', '2026-11-05T04:00:00Z') -> 'result' ->> 'sale_no', 'S01-261105-0004',
          'the replay did not take a number');
select is(pg_temp.sale('x7', 'S01', '2026-11-05T04:00:00Z', variant => 'nope') ->> 'hint', 'unknown_variant',
          'a sale refused after its number was taken (inside the insert block)...');
select is(pg_temp.sale('x8', 'S01', '2026-11-05T04:00:00Z', no => 'R-x1') ->> 'hint', 'duplicate_local_no',
          '...and a clash on the old (no device) receipt rule...');
select is(pg_temp.sale('x9', 'S01', '2026-11-05T05:00:00Z') -> 'result' ->> 'sale_no', 'S01-261105-0005',
          '...give their number back: no gap');
select pg_temp.login('juan', 'A');
select is(pg_temp.sale('x10', null, '2026-11-05T05:00:00Z') -> 'result' ->> 'sale_no', 'S01-261105-0006',
          'a cashier''s sale (store defaulted) continues the same store counter');
reset role;
select is((select array_agg(sale_no order by sale_no) from public.sales
           where location_id = pg_temp.id('S01') and sale_no like 'S01-261105-%'),
          array['S01-261105-0001', 'S01-261105-0002', 'S01-261105-0003', 'S01-261105-0004', 'S01-261105-0005',
                'S01-261105-0006'],
          'S01 on the 5th: 1..6, no gap, no duplicate');
select is((select array_agg((x.code, c.day, c.last_no)::text order by x.code, c.day)
           from public.sale_counters c join public.locations x on x.id = c.location_id where c.tenant_id = pg_temp.t('A')),
          array['(S01,2026-11-05,6)', '(S01,2026-11-06,1)', '(S02,2026-11-05,1)'], 'one counter per store and day');

-- ===== the device on a sale; local numbers per device (B1) =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.sale('d1', 'S02', '2026-11-05T06:00:00Z', no => 'NZD-261105-0001', dev => 'o1') ->> 'status', 'ok',
          'device o1 sells NZD-261105-0001');
select is(pg_temp.sale('d2', 'S02', '2026-11-05T06:00:00Z', no => 'NZD-261105-0001', dev => 'm1') ->> 'status', 'ok',
          'device m1 drew the same code and number: it syncs too (B1)');
select is(pg_temp.sale('d3', 'S02', '2026-11-05T06:00:00Z', no => 'NZD-261105-0001', dev => 'o1') ->> 'hint',
          'duplicate_local_no', 'the same device cannot use a local number twice');
select is((pg_temp.sale('d4', 'S02', '2026-11-05T06:00:00Z', dev => 'new1') -> 'result' ->> 'device_id'),
          pg_temp.id('dev:new1')::text, 'an unknown device id is registered on the spot (and named in the result)');
select is(pg_temp.sale('d5', 'S02', '2026-11-05T06:00:00Z', dev => 'c1') -> 'result' ->> 'device_id', null,
          'another tenant''s device id is ignored, the sale is accepted');
select is(pg_temp.sale('d6', 'S02', '2026-11-05T06:00:00Z', raw_dev => 'abc') ->> 'status', 'ok',
          'a device id that is not a uuid is ignored, the sale is accepted');
reset role;
select is((select array_agg((s.local_no, s.sale_no, s.device_id = pg_temp.id('dev:' || x.dev))::text order by x.k)
           from (values ('d1', 'o1'), ('d2', 'm1'), ('d4', 'new1')) x(k, dev)
           join public.sales s on s.id = pg_temp.id('sale:' || x.k)),
          array['(NZD-261105-0001,S02-261105-0002,t)', '(NZD-261105-0001,S02-261105-0003,t)', '(R-d4,S02-261105-0004,t)'],
          'the two same-numbered sales have different server numbers and keep their devices');
select is((select (tenant_id = pg_temp.t('A'), user_id = pg_temp.u('owner'), name is null)::text
           from public.devices where id = pg_temp.id('dev:new1')), '(t,t,t)',
          'the device registered by a sale belongs to the seller''s tenant and user');
select is((select array_agg(coalesce(device_id::text, '-') order by local_no) from public.sales
           where id in (pg_temp.id('sale:d5'), pg_temp.id('sale:d6'))), array['-', '-'],
          'ignored devices are stored as none');

-- ===== void keeps the number =====
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.push1('vx2', 'void_sale', jsonb_build_object('sale_id', pg_temp.id('sale:x2'))) ->> 'status', 'ok',
          'sale x2 is cancelled');
reset role;
select is((select (status, sale_no)::text from public.sales where id = pg_temp.id('sale:x2')), '(voided,S01-261105-0002)',
          'a cancelled sale keeps its number');
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.sale('x11', 'S01', '2026-11-05T07:00:00Z') -> 'result' ->> 'sale_no', 'S01-261105-0007',
          'and its number is not given again');
reset role;

-- ===== more than 9999 in a day =====
update public.sale_counters set last_no = 9999 where location_id = pg_temp.id('S02') and day = '2026-11-05';
select pg_temp.login('owner', 'A');
set local role authenticated;
select is(pg_temp.sale('big', 'S02', '2026-11-05T08:00:00Z') -> 'result' ->> 'sale_no', 'S02-261105-10000',
          'after 9999 the number simply grows (never cut to 4 digits)');
reset role;

-- ===== rows from before F-02 =====
insert into public.sales (id, tenant_id, location_id, local_no, subtotal, total, sold_at)
  values (pg_temp.id('sale:old'), pg_temp.t('A'), pg_temp.id('S01'), 'OLD-0001', 500, 500, '2026-11-04T02:00:00Z');
select is(pg_temp.try(format($$ insert into public.sales (id, tenant_id, location_id, local_no, subtotal, total, sold_at)
                                values (%L, %L, %L, 'OLD-0001', 500, 500, now()) $$,
                             pg_temp.id('sale:old2'), pg_temp.t('A'), pg_temp.id('S02'))), '23505',
          'rows without a device keep the tenant-wide local-number rule');
select is(pg_temp.try(format($$ insert into public.sales (id, tenant_id, location_id, local_no, subtotal, total, sold_at,
                                                         device_id) values (%L, %L, %L, 'OLD-0001', 500, 500, now(), %L) $$,
                             pg_temp.id('sale:old3'), pg_temp.t('A'), pg_temp.id('S02'), pg_temp.id('dev:o1'))), 'ok',
          'a device row may reuse a number used by a row without a device');
select is(pg_temp.try(format($$ insert into public.sales (id, tenant_id, location_id, local_no, subtotal, total, sold_at,
                                                         sale_no) values (%L, %L, %L, 'DUP-1', 500, 500, now(), %L) $$,
                             pg_temp.id('sale:dup'), pg_temp.t('A'), pg_temp.id('S01'), 'S01-261105-0001')), '23505',
          'a server number can never exist twice at a store');
select is(pg_temp.try(format($$ insert into public.sales (id, tenant_id, location_id, local_no, subtotal, total, sold_at,
                                                         device_id) values (%L, %L, %L, 'X-1', 500, 500, now(), %L) $$,
                             pg_temp.id('sale:xt'), pg_temp.t('A'), pg_temp.id('S01'), pg_temp.id('dev:c2'))), '23503',
          'a sale cannot name another tenant''s device');

-- ===== the pull =====
set local session_replication_role = replica;
update public.sales set updated_at = now() - interval '1 minute';
set local session_replication_role = origin;
select pg_temp.login('juan', 'A');
set local role authenticated;
select is((select (count(*), count(*) filter (where r ? 'sale_no' and r ? 'device_id'))::text
           from jsonb_array_elements(public.sync_pull_sales(null, 200) -> 'rows') r),
          '(9,9)', 'every pulled row carries sale_no and device_id (S01 rows for a one-store cashier)');
select is((select (r ->> 'sale_no', r ->> 'status')::text
           from jsonb_array_elements(public.sync_pull_sales(null, 200) -> 'rows') r where r ->> 'local_no' = 'R-x2'),
          '(S01-261105-0002,voided)', 'the pulled cancelled sale keeps its number');
select is((select coalesce(r ->> 'sale_no', 'null') from jsonb_array_elements(public.sync_pull_sales(null, 200) -> 'rows') r
           where r ->> 'local_no' = 'OLD-0001'), 'null', 'a row from before F-02 comes with no server number');
select pg_temp.login('owner', 'A');
select is((select r ->> 'device_id' from jsonb_array_elements(public.sync_pull_sales(null, 200) -> 'rows') r
           where r ->> 'id' = pg_temp.id('sale:d2')::text), pg_temp.id('dev:m1')::text, 'the pull names the sale''s device');

-- ===== server-only =====
select is(pg_temp.try($$ select count(*) from public.sale_counters $$), '42501', 'clients cannot read sale_counters');
select is(pg_temp.try(format($$ select public.next_sale_no(%L, %L, now()) $$, pg_temp.t('A'), pg_temp.id('S01'))), '42501',
          'clients cannot take a number');
select is(pg_temp.try($$ select public.sale_device('x') $$), '42501', 'clients cannot call the sale device helper');
reset role;

select * from finish();
rollback;
