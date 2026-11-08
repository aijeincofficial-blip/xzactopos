-- F-02 Server sale number and devices (gap B1). Full mode: several phones per store.
--
--   devices          one row per phone / browser that syncs. id = a UUIDv7 the app makes once and keeps (never changes);
--                    it is globally unique (primary key), so an id already used by another tenant is refused (id_conflict).
--                    RLS: superadmin and admins read the tenant's devices; every user reads / registers / updates their own;
--                    the owner (superadmin) may also update any device of the tenant (retire a lost phone: deleted_at).
--                    No hard delete. Limit: tenant_limits.max_devices (200 when the tenant has no limits row) devices that
--                    are not retired, checked by a trigger on insert (and on un-retire), hint `device_limit`.
--   register_device(p_id, p_name, p_platform)   idempotent upsert, called by the app once per sign-in session. Sets user_id
--                    (who registered it) on insert only, bumps last_seen_at, keeps name / platform when given null,
--                    un-retires a retired device. Returns the row.
--   sale_counters    (location_id, day) -> last_no. Server-only (no client privilege at all, like processed_ops).
--   sales.device_id  nullable fk (same tenant) to devices; null for rows before F-02 and for sales whose device is unknown.
--   sales.sale_no    the server number `<store code>-<YYMMDD>-<NNNN>`: day = the tenant-timezone business day of sold_at
--                    (same convention as daily_sales_summary); NNNN = per (store, day) counter from 1 (more digits after
--                    9999). Assigned by op_record_sale in the same transaction as the sale insert (atomic upsert on
--                    sale_counters), so it is gap-free per store and day: a refused or rolled-back sale gives its number back,
--                    a replayed op returns the stored result (same sale_no, no second number), a void keeps the number.
--                    Concurrency: the upsert takes the row lock of the (store, day) counter; a second concurrent push waits
--                    for the first to commit and then increments the committed value (READ COMMITTED re-check of ON CONFLICT
--                    DO UPDATE), so two pushes can never take the same number. A unique index guards it anyway.
--                    Rows before F-02 keep sale_no null (no row is rewritten); the app then shows local_no.
--   Local number uniqueness (the B1 clash): the constraint `sales_local_no_per_tenant unique (tenant_id, local_no)` is
--                    replaced by two partial unique indexes: (tenant_id, device_id, local_no) where device_id is not null,
--                    and (tenant_id, local_no) where device_id is null (the old rule, kept for rows / older apps without a
--                    device). Two devices that drew the same random 3-letter code now both sync. Existing rows all have no
--                    device and were unique per tenant, so the index builds without touching them.
--   op_record_sale   re-created (from 20261108002000, the newest definition). p gains optional device_id:
--                      registered in this tenant -> stored; unknown -> registered on the spot for the caller (best effort);
--                      another tenant's id, the device limit reached, or not a uuid -> IGNORED (stored as null; the sale is
--                      never refused because of its device, it then falls under the old tenant-wide local_no rule).
--                    Result gains sale_no (and device_id). Every other check, the audit row and the hints are unchanged.
--   sync_pull_sales  re-created (from 20261108002000): rows carry sale_no and device_id (additive).
--   Unchanged: sync_push (no new op kind), op_void_sale (the number stays), RLS on sales, report_summary, audit rows.

-- ---------------------------------------------------------------------------
-- devices
-- ---------------------------------------------------------------------------

create table public.devices (
  id             uuid primary key,
  tenant_id      uuid not null references public.tenants (id) on delete cascade,
  user_id        uuid references auth.users (id) on delete set null,
  name           text check (name is null or length(btrim(name)) between 1 and 60),
  platform       text check (platform is null or length(btrim(platform)) between 1 and 20),
  first_seen_at  timestamptz not null default now(),
  last_seen_at   timestamptz not null default now(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint devices_tenant_id unique (tenant_id, id)
);

comment on table public.devices is
  'Phones / browsers that sync (F-02). id is made by the app once and never changes. Soft delete (retire) only.';

create index devices_tenant_user_idx on public.devices (tenant_id, user_id);

create trigger devices_set_updated_at before update on public.devices
  for each row execute function public.set_updated_at();
create trigger devices_tenant_immutable before update of tenant_id on public.devices
  for each row execute function public.prevent_tenant_change();

-- The device limit: devices that are not retired, per tenant. Serialised per tenant so two inserts cannot both pass.
create or replace function public.devices_enforce_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max integer;
  v_n   integer;
begin
  if tg_op = 'UPDATE' and not (old.deleted_at is not null and new.deleted_at is null) then
    return new;
  end if;
  if new.deleted_at is not null then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('devices:' || new.tenant_id::text, 0));
  select coalesce((select l.max_devices from public.tenant_limits l where l.tenant_id = new.tenant_id), 200) into v_max;
  select count(*) into v_n from public.devices d
  where d.tenant_id = new.tenant_id and d.deleted_at is null and d.id <> new.id;
  if v_n >= v_max then
    raise exception 'too many devices' using errcode = 'P0001', hint = 'device_limit';
  end if;
  return new;
end;
$$;

revoke execute on function public.devices_enforce_limit() from public, anon, authenticated;

create trigger devices_limit before insert or update of deleted_at on public.devices
  for each row execute function public.devices_enforce_limit();

alter table public.devices enable row level security;

create policy devices_read on public.devices
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and ((select public.auth_role()) in ('superadmin', 'admin') or user_id = (select auth.uid())));
create policy devices_insert_own on public.devices
  for insert to authenticated
  with check (tenant_id = (select public.auth_tenant_id()) and user_id = (select auth.uid()));
create policy devices_update on public.devices
  for update to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (user_id = (select auth.uid()) or (select public.auth_role()) = 'superadmin'))
  with check (tenant_id = (select public.auth_tenant_id()));

revoke all on public.devices from anon;
revoke all on public.devices from authenticated;
grant select on public.devices to authenticated;
grant insert (id, tenant_id, user_id, name, platform) on public.devices to authenticated;
grant update (name, platform, last_seen_at, deleted_at) on public.devices to authenticated;

-- ---------------------------------------------------------------------------
-- register_device
-- ---------------------------------------------------------------------------

create or replace function public.register_device(p_id uuid, p_name text default null, p_platform text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_row    public.devices;
  v_name   text := nullif(btrim(p_name), '');
  v_plat   text := nullif(btrim(p_platform), '');
begin
  perform public.assert_active_user();
  v_tenant := public.auth_tenant_id();
  if p_id is null then
    raise exception 'device id is required' using errcode = '22023', hint = 'id_required';
  end if;
  if length(v_name) > 60 or length(v_plat) > 20 then
    raise exception 'device name or platform is too long' using errcode = '22023', hint = 'invalid_value';
  end if;

  insert into public.devices as d (id, tenant_id, user_id, name, platform)
  values (p_id, v_tenant, auth.uid(), v_name, v_plat)
  on conflict (id) do update
    set last_seen_at = now(),
        name = coalesce(excluded.name, d.name),
        platform = coalesce(excluded.platform, d.platform),
        deleted_at = null
    where d.tenant_id = excluded.tenant_id
  returning * into v_row;

  if v_row.id is null then
    -- the conflict row belongs to another tenant (the WHERE above skipped the update)
    raise exception 'device id already in use' using errcode = '22023', hint = 'id_conflict';
  end if;

  return jsonb_build_object(
    'id', v_row.id, 'name', v_row.name, 'platform', v_row.platform, 'user_id', v_row.user_id,
    'first_seen_at', v_row.first_seen_at, 'last_seen_at', v_row.last_seen_at);
end;
$$;

revoke execute on function public.register_device(uuid, text, text) from public, anon;
grant execute on function public.register_device(uuid, text, text) to authenticated;

-- The device a sale names, as stored on the sale: this tenant's device, or an unknown id registered on the spot for the
-- caller; null for anything else (no id, not a uuid, another tenant's id, the limit reached). Never raises. Internal.
create or replace function public.sale_device(p_raw text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_id     uuid;
  v_owner  uuid;
begin
  if p_raw is null or p_raw !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return null;
  end if;
  v_id := p_raw::uuid;
  select d.tenant_id into v_owner from public.devices d where d.id = v_id;
  if found then
    return case when v_owner = v_tenant then v_id end;
  end if;
  begin
    insert into public.devices (id, tenant_id, user_id) values (v_id, v_tenant, auth.uid())
    on conflict (id) do nothing;
  exception when others then
    return null; -- device_limit (or anything else): the sale goes on without a device
  end;
  select d.tenant_id into v_owner from public.devices d where d.id = v_id;
  return case when v_owner = v_tenant then v_id end;
end;
$$;

revoke execute on function public.sale_device(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sale_counters and the number
-- ---------------------------------------------------------------------------

create table public.sale_counters (
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  location_id  uuid not null,
  day          date not null,
  last_no      integer not null check (last_no >= 1),
  updated_at   timestamptz not null default now(),
  primary key (location_id, day),
  constraint sale_counters_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id)
);

comment on table public.sale_counters is
  'Last sale_no per store and business day (F-02). Written only by op_record_sale in the sale''s transaction. Server-only.';

create index sale_counters_tenant_idx on public.sale_counters (tenant_id, day);

alter table public.sale_counters enable row level security;
revoke all on public.sale_counters from anon, authenticated;

-- Takes the next number of (store, business day of p_sold) and returns `<code>-<YYMMDD>-<NNNN>`. Must run in the same
-- transaction (and subtransaction) as the sale insert, so a refused sale gives the number back. Internal.
create or replace function public.next_sale_no(p_tenant uuid, p_location_id uuid, p_sold timestamptz)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz   text;
  v_day  date;
  v_n    integer;
  v_code text;
begin
  select coalesce(t.timezone, 'UTC') into v_tz from public.tenants t where t.id = p_tenant;
  v_day := (p_sold at time zone coalesce(v_tz, 'UTC'))::date;

  insert into public.sale_counters as c (tenant_id, location_id, day, last_no)
  values (p_tenant, p_location_id, v_day, 1)
  on conflict (location_id, day) do update set last_no = c.last_no + 1, updated_at = now()
  returning c.last_no into v_n;

  select l.code into v_code from public.locations l where l.id = p_location_id and l.tenant_id = p_tenant;
  return v_code || '-' || to_char(v_day, 'YYMMDD') || '-' || lpad(v_n::text, greatest(4, length(v_n::text)), '0');
end;
$$;

revoke execute on function public.next_sale_no(uuid, uuid, timestamptz) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sales: device, server number, local number per device
-- ---------------------------------------------------------------------------

alter table public.sales
  add column device_id uuid,
  add column sale_no text check (sale_no is null or length(sale_no) between 3 and 40),
  add constraint sales_device_fk foreign key (tenant_id, device_id) references public.devices (tenant_id, id);

comment on column public.sales.device_id is 'The device that rang the sale up (F-02); null before F-02 or when unknown.';
comment on column public.sales.sale_no is
  'Server number <store code>-<YYMMDD>-<NNNN>, per store and tenant-timezone day, gap-free (F-02). Null before F-02.';

alter table public.sales drop constraint sales_local_no_per_tenant;
create unique index sales_local_no_per_tenant on public.sales (tenant_id, local_no) where device_id is null;
create unique index sales_local_no_per_device on public.sales (tenant_id, device_id, local_no) where device_id is not null;
create unique index sales_sale_no_per_store on public.sales (location_id, sale_no) where sale_no is not null;

-- ---------------------------------------------------------------------------
-- op_record_sale re-created (from 20261108002000, the newest definition). Changes: optional p.device_id (sale_device), the
-- server number (next_sale_no, inside the same block as the insert), the local-number clash hint covers both indexes, and
-- the result carries sale_no and device_id.
-- ---------------------------------------------------------------------------

create or replace function public.op_record_sale(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant  uuid;
  v_replay  jsonb;
  v_loc     uuid;
  v_sale    uuid;
  v_no      text;
  v_sold    timestamptz;
  v_cust    uuid;
  v_disc    bigint;
  v_sub     bigint := 0;
  v_total   bigint;
  v_tax     bigint := 0;
  v_paid    bigint := 0;
  v_utang   bigint := 0;
  it        jsonb;
  pay       jsonb;
  v_vid     uuid;
  v_qty     numeric;
  v_price   bigint;
  v_idisc   bigint;
  v_itax    bigint;
  v_line    bigint;
  v_cost    bigint;
  v_track   boolean;
  v_pname   text;
  v_method  text;
  v_amt     bigint;
  v_tend    bigint;
  v_wallet  text;
  v_con     text;
  v_device  uuid;
  v_sale_no text;
begin
  perform public.assert_seller();
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object'
     or jsonb_typeof(p -> 'items') is distinct from 'array'
     or jsonb_typeof(coalesce(p -> 'payments', '[]'::jsonb)) is distinct from 'array' then
    raise exception 'sale must be an object with items' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'record_sale');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);
  v_sale := (p ->> 'id')::uuid;
  v_no := btrim(p ->> 'local_no');
  v_sold := coalesce((p ->> 'sold_at')::timestamptz, now());
  v_cust := (p ->> 'customer_id')::uuid;
  v_disc := coalesce((p ->> 'discount')::bigint, 0);
  if v_sale is null then
    raise exception 'sale id is required' using errcode = '22023', hint = 'id_required';
  end if;
  if v_no is null or length(v_no) not between 3 and 40 then
    raise exception 'receipt number is required' using errcode = '22023', hint = 'invalid_value';
  end if;
  if jsonb_array_length(p -> 'items') not between 1 and 200 then
    raise exception 'a sale needs 1 to 200 items' using errcode = '22023', hint = 'items_required';
  end if;

  -- pass 1: validate lines and add up
  for it in select * from jsonb_array_elements(p -> 'items') loop
    v_qty := (it ->> 'qty')::numeric;
    v_price := (it ->> 'unit_price')::bigint;
    v_idisc := coalesce((it ->> 'discount')::bigint, 0);
    v_itax := coalesce((it ->> 'tax')::bigint, 0);
    if v_qty is null or v_qty <= 0 or v_qty >= 1000000000 then
      raise exception 'quantity must be above zero' using errcode = '22023', hint = 'qty_invalid';
    end if;
    if v_price is null or v_price < 0 then
      raise exception 'price is invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    v_line := round(v_qty * v_price)::bigint - v_idisc;
    if v_line < 0 or v_idisc < 0 or v_itax < 0 or v_itax > v_line then
      raise exception 'line amounts are invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    if it ? 'line_total' and (it ->> 'line_total')::bigint <> v_line then
      raise exception 'line total does not match' using errcode = '22023', hint = 'totals_mismatch';
    end if;
    v_sub := v_sub + v_line;
    v_tax := v_tax + v_itax;
  end loop;

  v_total := v_sub - v_disc;
  if v_disc < 0 or v_disc > v_sub then
    raise exception 'discount is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;
  if (p ? 'subtotal' and (p ->> 'subtotal')::bigint <> v_sub)
     or (p ? 'total' and (p ->> 'total')::bigint <> v_total) then
    raise exception 'totals do not match' using errcode = '22023', hint = 'totals_mismatch';
  end if;

  -- payments must cover the total exactly (change is not a payment); a wallet only on an ewallet payment
  for pay in select * from jsonb_array_elements(coalesce(p -> 'payments', '[]'::jsonb)) loop
    v_method := pay ->> 'method';
    v_amt := (pay ->> 'amount')::bigint;
    if v_method not in ('cash', 'utang', 'ewallet') or v_amt is null or v_amt <= 0 then
      raise exception 'payment is invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    v_wallet := nullif(btrim(pay ->> 'wallet'), '');
    if v_wallet is not null and (v_method <> 'ewallet' or v_wallet not in ('gcash', 'maya', 'other')) then
      raise exception 'payment wallet is invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    v_paid := v_paid + v_amt;
    if v_method = 'utang' then
      v_utang := v_utang + v_amt;
    end if;
  end loop;
  if v_paid <> v_total then
    raise exception 'payments do not cover the total' using errcode = '22023', hint = 'payments_mismatch';
  end if;
  if v_utang > 0 then
    if v_cust is null then
      raise exception 'utang needs a customer' using errcode = '22023', hint = 'customer_required';
    end if;
    if not exists (select 1 from public.customers c where c.id = v_cust and c.tenant_id = v_tenant) then
      raise exception 'unknown customer' using errcode = '22023', hint = 'unknown_customer';
    end if;
  end if;

  -- F-02: the device (never refuses the sale)
  v_device := public.sale_device(p ->> 'device_id');

  begin
    -- F-02: the server number, in the same block as the insert so a refused sale gives it back
    v_sale_no := public.next_sale_no(v_tenant, v_loc, v_sold);

    insert into public.sales (id, tenant_id, location_id, local_no, subtotal, discount, tax, total,
                              customer_id, sold_at, created_by, device_id, sale_no)
    values (v_sale, v_tenant, v_loc, v_no, v_sub, v_disc, v_tax, v_total, v_cust, v_sold, auth.uid(), v_device, v_sale_no);

    for it in select * from jsonb_array_elements(p -> 'items') loop
      v_vid := (it ->> 'variant_id')::uuid;
      v_qty := (it ->> 'qty')::numeric;
      v_price := (it ->> 'unit_price')::bigint;
      v_idisc := coalesce((it ->> 'discount')::bigint, 0);
      v_itax := coalesce((it ->> 'tax')::bigint, 0);
      v_line := round(v_qty * v_price)::bigint - v_idisc;

      select v.cost, pr.track_stock, pr.name into v_cost, v_track, v_pname
      from public.product_variants v
      join public.products pr on pr.tenant_id = v.tenant_id and pr.id = v.product_id
      where v.id = v_vid and v.tenant_id = v_tenant;
      if not found then
        raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
      end if;
      v_cost := coalesce((it ->> 'unit_cost')::bigint, v_cost);

      insert into public.sale_items (tenant_id, sale_id, location_id, variant_id, product_name, qty,
                                     unit_price, unit_cost, discount, tax, line_total)
      values (v_tenant, v_sale, v_loc, v_vid, left(coalesce(nullif(btrim(it ->> 'name'), ''), v_pname), 120), v_qty,
              v_price, v_cost, v_idisc, v_itax, v_line);

      if v_track then
        insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id,
                                            unit_cost, occurred_at, created_by)
        values (v_tenant, v_loc, v_vid, -v_qty, 'sale', 'sale', v_sale, v_cost, v_sold, auth.uid());
      end if;
    end loop;

    for pay in select * from jsonb_array_elements(coalesce(p -> 'payments', '[]'::jsonb)) loop
      v_method := pay ->> 'method';
      v_amt := (pay ->> 'amount')::bigint;
      v_tend := case when v_method = 'cash' then coalesce((pay ->> 'tendered')::bigint, v_amt) end;
      v_wallet := nullif(btrim(pay ->> 'wallet'), '');
      -- the payments_wallet_float trigger moves the float of a named wallet
      insert into public.payments (tenant_id, sale_id, location_id, method, amount, tendered, reference, wallet)
      values (v_tenant, v_sale, v_loc, v_method, v_amt, v_tend, left(nullif(btrim(pay ->> 'reference'), ''), 64), v_wallet);
    end loop;

    if v_utang > 0 then
      -- F-01: the charge belongs to the sale's store
      insert into public.customer_ledger (tenant_id, customer_id, kind, amount, sale_id, occurred_at, created_by, location_id)
      values (v_tenant, v_cust, 'charge', v_utang, v_sale, v_sold, auth.uid(), v_loc);
    end if;
  exception
    when unique_violation then
      get stacked diagnostics v_con = constraint_name;
      if v_con in ('sales_local_no_per_tenant', 'sales_local_no_per_device') then
        raise exception 'receipt number already used' using errcode = '23505', hint = 'duplicate_local_no';
      end if;
      raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  perform public.write_audit('sale.create', 'sale', v_sale, v_loc,
    jsonb_build_object('no', v_no, 'total', v_total, 'utang', v_utang));

  return public.finish_op(p_op_id, jsonb_build_object(
    'sale_id', v_sale, 'local_no', v_no, 'sale_no', v_sale_no, 'device_id', v_device, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_record_sale(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_sales re-created (from 20261108002000, the newest definition). The one change: each sale row carries sale_no
-- and device_id (additive).
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_sales(p_cursor jsonb default null, p_limit int default 100)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_upto   timestamptz := now() - interval '5 seconds';
  v_ts     timestamptz := nullif(p_cursor ->> 'ts', '')::timestamptz;
  v_k      text := p_cursor ->> 'k';
  v_rows   jsonb;
  v_last   jsonb;
  v_more   boolean;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.*
    from public.sales x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and (v_ts is null and x.sold_at >= now() - interval '30 days'
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'local_no', g.local_no, 'sale_no', g.sale_no, 'device_id', g.device_id,
        'status', g.status, 'subtotal', g.subtotal,
        'discount', g.discount, 'tax', g.tax, 'total', g.total, 'customer_id', g.customer_id, 'sold_at', g.sold_at,
        'voided_at', g.voided_at, 'void_reason', g.void_reason, 'updated_at', g.updated_at,
        'items', coalesce((select jsonb_agg(jsonb_build_object(
                    'variant_id', i.variant_id, 'name', i.product_name, 'qty', i.qty, 'unit_price', i.unit_price,
                    'unit_cost', i.unit_cost, 'discount', i.discount, 'tax', i.tax, 'line_total', i.line_total,
                    'tracked', coalesce(pr.track_stock, true)) order by i.created_at, i.id)
                  from public.sale_items i
                  left join public.product_variants v on v.id = i.variant_id and v.tenant_id = i.tenant_id
                  left join public.products pr on pr.id = v.product_id and pr.tenant_id = v.tenant_id
                  where i.sale_id = g.id), '[]'::jsonb),
        'payments', coalesce((select jsonb_agg(jsonb_build_object(
                    'method', p.method, 'amount', p.amount, 'tendered', p.tendered, 'reference', p.reference,
                    'wallet', p.wallet)
                    order by p.created_at, p.id)
                  from public.payments p where p.sale_id = g.id), '[]'::jsonb)
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$$;

revoke execute on function public.sync_pull_sales(jsonb, int) from public, anon;
grant execute on function public.sync_pull_sales(jsonb, int) to authenticated;
