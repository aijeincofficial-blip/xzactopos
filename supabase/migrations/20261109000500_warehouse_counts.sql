-- F-13e Warehouse stock counts: count a whole warehouse, or one bin, and apply the differences through the ledger.
--
--   stock_counts / stock_count_items   a count session and its lines. One OPEN count per warehouse at a time.
--   start_count   open a session (whole warehouse, or one bin when the warehouse uses bins)
--   record_count  save counted quantities; counting a product again replaces its line. NOTHING moves stock yet.
--   close_count   apply the differences as `count_correction` movements; optionally treat products it did not find as zero
--   cancel_count  drop an open session; stock is untouched
--
-- The key rule: each line remembers the system quantity AT THE MOMENT IT WAS COUNTED (qty_system). On close the correction is
-- qty_counted - qty_system, not counted - "whatever the system says now". A delivery or a sale that happens while the count is
-- open therefore survives: count 97, system was 100, 10 arrive later -> 107, not 97.
-- With bins, every line names a bin and the movement goes to that bin, so the bin invariant (sum of bins = warehouse) holds.
-- Corrections never change the average cost. Who: the owner, or warehouse staff in their own warehouse (same gate as purchasing).
-- Hints: not_allowed, location_denied, location_not_found, not_a_warehouse, count_in_progress, bins_not_enabled, bin_required,
-- bin_not_allowed, bin_not_found, bin_out_of_scope, not_found, invalid_state, items_required, qty_invalid, duplicate_item,
-- unknown_variant, nothing_counted, id_conflict.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.stock_counts (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  count_no      text not null check (length(count_no) between 1 and 40),
  warehouse_id  uuid not null,
  bin_id        uuid,                                              -- set: only this bin is counted
  status        text not null default 'open' check (status in ('open', 'closed', 'cancelled')),
  notes         text check (length(notes) <= 1000),
  started_by    uuid references auth.users (id) on delete set null,
  started_at    timestamptz not null default now(),
  closed_by     uuid references auth.users (id) on delete set null,
  closed_at     timestamptz,
  cancelled_by  uuid references auth.users (id) on delete set null,
  cancelled_at  timestamptz,
  cancel_reason text check (length(cancel_reason) <= 200),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint stock_counts_tenant_id unique (tenant_id, id),
  constraint stock_counts_no_per_tenant unique (tenant_id, count_no),
  constraint stock_counts_warehouse_fk foreign key (tenant_id, warehouse_id)
    references public.locations (tenant_id, id),
  constraint stock_counts_bin_fk foreign key (tenant_id, bin_id)
    references public.bins (tenant_id, id),
  constraint stock_counts_closed_fields check (status <> 'closed' or closed_at is not null),
  constraint stock_counts_cancelled_fields check (status <> 'cancelled' or cancelled_at is not null)
);

-- at most one open count per warehouse
create unique index stock_counts_one_open on public.stock_counts (tenant_id, warehouse_id) where status = 'open';
create index stock_counts_warehouse_idx on public.stock_counts (tenant_id, warehouse_id, started_at desc);

create table public.stock_count_items (
  id           uuid primary key default public.uuid_generate_v7(),
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  count_id     uuid not null,
  variant_id   uuid not null,
  bin_id       uuid,
  qty_system   numeric(12, 3) not null,                          -- system quantity when this line was counted (may be negative)
  qty_counted  numeric(12, 3) not null check (qty_counted >= 0),
  qty_variance numeric(12, 3),                                   -- counted - system, written at close
  auto_zero    boolean not null default false,                   -- not found during a full count: treated as zero
  counted_by   uuid references auth.users (id) on delete set null,
  counted_at   timestamptz not null default now(),
  constraint stock_count_items_tenant_id unique (tenant_id, id),
  constraint stock_count_items_count_fk foreign key (tenant_id, count_id)
    references public.stock_counts (tenant_id, id),
  constraint stock_count_items_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id),
  constraint stock_count_items_bin_fk foreign key (tenant_id, bin_id)
    references public.bins (tenant_id, id)
);

create unique index stock_count_items_one_per_spot
  on public.stock_count_items (count_id, variant_id, coalesce(bin_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index stock_count_items_count_idx on public.stock_count_items (tenant_id, count_id);

comment on column public.stock_count_items.qty_system is 'System quantity at the moment the line was counted. The correction is counted minus this, so later movements survive.';

-- a count is addressed to a warehouse
create or replace function public.check_count_warehouse()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.locations l where l.id = new.warehouse_id and l.tenant_id = new.tenant_id and l.type = 'warehouse'
  ) then
    raise exception 'a stock count must be addressed to a warehouse' using errcode = '23514', hint = 'not_a_warehouse';
  end if;
  return new;
end;
$$;

revoke execute on function public.check_count_warehouse() from public, anon, authenticated;

create trigger stock_counts_warehouse_only before insert on public.stock_counts
  for each row execute function public.check_count_warehouse();

-- a closed or cancelled count is history: nothing about it changes; rows vanish only with their tenant
create or replace function public.guard_count_history()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_status text;
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.tenants t where t.id = old.tenant_id) then
    return old;
  end if;
  if tg_table_name = 'stock_counts' then
    v_status := old.status;
  else
    select c.status into v_status from public.stock_counts c where c.id = old.count_id and c.tenant_id = old.tenant_id;
  end if;
  if tg_op = 'DELETE' or v_status is distinct from 'open' then
    raise exception '% of a finished count cannot change', tg_table_name using errcode = 'P0001', hint = 'append_only';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_count_history() from public, anon, authenticated;

create trigger stock_counts_history before update or delete on public.stock_counts
  for each row execute function public.guard_count_history();
create trigger stock_count_items_history before update or delete on public.stock_count_items
  for each row execute function public.guard_count_history();

create trigger stock_counts_set_updated_at before update on public.stock_counts
  for each row execute function public.set_updated_at();
create trigger stock_counts_tenant_immutable before update of tenant_id on public.stock_counts
  for each row execute function public.prevent_tenant_change();
create trigger stock_count_items_tenant_immutable before update of tenant_id on public.stock_count_items
  for each row execute function public.prevent_tenant_change();

-- ---------------------------------------------------------------------------
-- RLS: owner and warehouse staff, own warehouses only, no client writes
-- ---------------------------------------------------------------------------

alter table public.stock_counts      enable row level security;
alter table public.stock_count_items enable row level security;

create policy stock_counts_read on public.stock_counts
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'warehouse')
    and (
      (select public.is_superadmin())
      or warehouse_id = any ((select public.auth_location_ids())::uuid[])
    )
  );

create policy stock_count_items_read on public.stock_count_items
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'warehouse')
    and (
      (select public.is_superadmin())
      or exists (
        select 1 from public.stock_counts c
        where c.id = stock_count_items.count_id and c.tenant_id = stock_count_items.tenant_id
          and c.warehouse_id = any ((select public.auth_location_ids())::uuid[])
      )
    )
  );

revoke all on public.stock_counts, public.stock_count_items from anon;
revoke insert, update, delete, truncate on public.stock_counts, public.stock_count_items from authenticated;
grant select on public.stock_counts, public.stock_count_items to authenticated;

-- ---------------------------------------------------------------------------
-- CNT-YYMMDD-NNNN per tenant and Manila day, serialized per tenant
-- ---------------------------------------------------------------------------

create or replace function public.next_count_no(p_tenant_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day text := to_char(now() at time zone 'Asia/Manila', 'YYMMDD');
  v_seq integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('count_no:' || p_tenant_id::text, 0));
  select coalesce(max(substring(c.count_no from '^CNT-[0-9]{6}-([0-9]+)$')::int), 0) + 1
  into v_seq
  from public.stock_counts c
  where c.tenant_id = p_tenant_id and c.count_no like 'CNT-' || v_day || '-%';
  return 'CNT-' || v_day || '-' || lpad(v_seq::text, 4, '0');
end;
$$;

revoke execute on function public.next_count_no(uuid) from public, anon, authenticated;

-- the system quantity of a product in a place: in a bin, or in the warehouse as a whole
create or replace function public.count_system_qty(p_tenant uuid, p_warehouse uuid, p_bin uuid, p_variant uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    case when p_bin is not null then
      (select s.qty_on_hand from public.bin_stock_levels s where s.tenant_id = p_tenant and s.bin_id = p_bin and s.variant_id = p_variant)
    else
      (select s.qty_on_hand from public.stock_levels s where s.tenant_id = p_tenant and s.location_id = p_warehouse and s.variant_id = p_variant)
    end, 0)
$$;

revoke execute on function public.count_system_qty(uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- start_count(p_id, p_warehouse_id, p_bin_id, p_notes)
-- ---------------------------------------------------------------------------

create or replace function public.start_count(
  p_id           uuid,
  p_warehouse_id uuid,
  p_bin_id       uuid default null,
  p_notes        text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.assert_buyer();
  v_id     uuid := coalesce(p_id, public.uuid_generate_v7());
  v_loc    record;
  v_exist  record;
  v_no     text;
begin
  select l.type, l.bins_enabled into v_loc
  from public.locations l
  where l.id = p_warehouse_id and l.tenant_id = v_tenant and l.active and l.deleted_at is null;
  if not found then
    raise exception 'warehouse not found' using errcode = '22023', hint = 'location_not_found';
  end if;
  perform public.assert_location_access(p_warehouse_id);
  if v_loc.type <> 'warehouse' then
    raise exception 'only a warehouse can be counted here' using errcode = '22023', hint = 'not_a_warehouse';
  end if;

  select c.tenant_id, c.warehouse_id into v_exist from public.stock_counts c where c.id = v_id;
  if found then
    if v_exist.tenant_id = v_tenant and v_exist.warehouse_id = p_warehouse_id then
      return v_id;
    end if;
    raise exception 'id already used' using errcode = 'P0001', hint = 'id_conflict';
  end if;

  if p_bin_id is not null then
    if not v_loc.bins_enabled then
      raise exception 'this warehouse does not use bins' using errcode = '22023', hint = 'bins_not_enabled';
    end if;
    if not exists (select 1 from public.bins b where b.id = p_bin_id and b.tenant_id = v_tenant and b.warehouse_id = p_warehouse_id and b.deleted_at is null) then
      raise exception 'bin not found' using errcode = '22023', hint = 'bin_not_found';
    end if;
  end if;

  if exists (select 1 from public.stock_counts c where c.tenant_id = v_tenant and c.warehouse_id = p_warehouse_id and c.status = 'open') then
    raise exception 'a count is already open in this warehouse' using errcode = 'P0001', hint = 'count_in_progress';
  end if;

  v_no := public.next_count_no(v_tenant);
  insert into public.stock_counts (id, tenant_id, count_no, warehouse_id, bin_id, status, notes, started_by)
  values (v_id, v_tenant, v_no, p_warehouse_id, p_bin_id, 'open', p_notes, auth.uid());

  perform public.write_audit('count.start', 'stock_count', v_id, p_warehouse_id,
    jsonb_build_object('count_no', v_no, 'bin', p_bin_id));
  return v_id;
exception when unique_violation then
  raise exception 'a count is already open in this warehouse' using errcode = 'P0001', hint = 'count_in_progress';
end;
$$;

-- ---------------------------------------------------------------------------
-- record_count(p_count_id, p_items): p_items = [ { variant_id, qty_counted (>= 0), bin_id? } ], 1 to 500 lines, all-or-nothing
-- ---------------------------------------------------------------------------

create or replace function public.record_count(p_count_id uuid, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.assert_buyer();
  v_count  record;
  v_bins   boolean;
  v_item   jsonb;
  v_vid    uuid;
  v_bin    uuid;
  v_qty    numeric;
  v_seen   text[] := '{}';
  v_key    text;
  v_sys    numeric;
  v_n      integer := 0;
begin
  select c.* into v_count from public.stock_counts c where c.id = p_count_id and c.tenant_id = v_tenant for update;
  if not found then
    raise exception 'count not found' using errcode = '22023', hint = 'not_found';
  end if;
  perform public.assert_location_access(v_count.warehouse_id);
  if v_count.status <> 'open' then
    raise exception 'count is %', v_count.status using errcode = 'P0001', hint = 'invalid_state';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 500 then
    raise exception 'send 1 to 500 counted lines' using errcode = '22023', hint = 'items_required';
  end if;
  select l.bins_enabled into v_bins from public.locations l where l.id = v_count.warehouse_id;

  -- pass 1: validate everything, write nothing
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_bin := nullif(v_item ->> 'bin_id', '')::uuid;
    v_qty := (v_item ->> 'qty_counted')::numeric;
    if v_qty is null or v_qty < 0 or v_qty >= 1000000000 then
      raise exception 'counted quantity is invalid' using errcode = '22023', hint = 'qty_invalid';
    end if;
    v_key := v_vid::text || ':' || coalesce(v_bin::text, '-');
    if v_key = any (v_seen) then
      raise exception 'a product can only appear once per place' using errcode = '22023', hint = 'duplicate_item';
    end if;
    v_seen := v_seen || v_key;
    if not exists (select 1 from public.product_variants v where v.id = v_vid and v.tenant_id = v_tenant and v.active and v.deleted_at is null) then
      raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
    end if;
    if v_bins then
      if v_bin is null then
        raise exception 'name the bin for every line' using errcode = '22023', hint = 'bin_required';
      end if;
      if not exists (select 1 from public.bins b where b.id = v_bin and b.tenant_id = v_tenant and b.warehouse_id = v_count.warehouse_id and b.deleted_at is null) then
        raise exception 'bin not found' using errcode = '22023', hint = 'bin_not_found';
      end if;
      if v_count.bin_id is not null and v_bin <> v_count.bin_id then
        raise exception 'this count covers one bin only' using errcode = '22023', hint = 'bin_out_of_scope';
      end if;
    elsif v_bin is not null then
      raise exception 'this warehouse does not use bins' using errcode = '22023', hint = 'bin_not_allowed';
    end if;
  end loop;

  -- pass 2: save the lines with the system quantity as it is right now
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_bin := nullif(v_item ->> 'bin_id', '')::uuid;
    v_qty := (v_item ->> 'qty_counted')::numeric;
    v_sys := public.count_system_qty(v_tenant, v_count.warehouse_id, v_bin, v_vid);

    update public.stock_count_items
    set qty_system = v_sys, qty_counted = v_qty, qty_variance = null, auto_zero = false, counted_by = auth.uid(), counted_at = now()
    where count_id = p_count_id and variant_id = v_vid and bin_id is not distinct from v_bin;
    if not found then
      insert into public.stock_count_items (tenant_id, count_id, variant_id, bin_id, qty_system, qty_counted, counted_by)
      values (v_tenant, p_count_id, v_vid, v_bin, v_sys, v_qty, auth.uid());
    end if;
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('count_id', p_count_id, 'recorded', v_n);
end;
$$;

-- ---------------------------------------------------------------------------
-- close_count(p_count_id, p_zero_uncounted): apply the differences. With p_zero_uncounted, stock inside the count's scope
-- that has no line is treated as counted zero (a full count). Closing again is harmless.
-- ---------------------------------------------------------------------------

create or replace function public.close_count(p_count_id uuid, p_zero_uncounted boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.assert_buyer();
  v_count  record;
  v_bins   boolean;
  v_line   record;
  v_var    numeric;
  v_corr   integer := 0;
  v_net    numeric := 0;
  v_zeroed integer := 0;
  v_lines  integer;
begin
  select c.* into v_count from public.stock_counts c where c.id = p_count_id and c.tenant_id = v_tenant for update;
  if not found then
    raise exception 'count not found' using errcode = '22023', hint = 'not_found';
  end if;
  perform public.assert_location_access(v_count.warehouse_id);

  if v_count.status = 'closed' then
    return (select jsonb_build_object('count_id', p_count_id, 'status', 'closed', 'replay', true,
              'lines', count(*), 'corrections', count(*) filter (where coalesce(i.qty_variance, 0) <> 0),
              'net_variance', trim_scale(coalesce(sum(i.qty_variance), 0)), 'zeroed', count(*) filter (where i.auto_zero))
            from public.stock_count_items i where i.count_id = p_count_id);
  end if;
  if v_count.status <> 'open' then
    raise exception 'count is %', v_count.status using errcode = 'P0001', hint = 'invalid_state';
  end if;
  select l.bins_enabled into v_bins from public.locations l where l.id = v_count.warehouse_id;

  if p_zero_uncounted then
    if v_bins then
      insert into public.stock_count_items (tenant_id, count_id, variant_id, bin_id, qty_system, qty_counted, auto_zero, counted_by)
      select v_tenant, p_count_id, s.variant_id, s.bin_id, s.qty_on_hand, 0, true, auth.uid()
      from public.bin_stock_levels s
      join public.bins b on b.id = s.bin_id and b.tenant_id = s.tenant_id
      where s.tenant_id = v_tenant and b.warehouse_id = v_count.warehouse_id and s.qty_on_hand <> 0
        and (v_count.bin_id is null or s.bin_id = v_count.bin_id)
        and not exists (select 1 from public.stock_count_items i
                        where i.count_id = p_count_id and i.variant_id = s.variant_id and i.bin_id is not distinct from s.bin_id);
    else
      insert into public.stock_count_items (tenant_id, count_id, variant_id, bin_id, qty_system, qty_counted, auto_zero, counted_by)
      select v_tenant, p_count_id, s.variant_id, null, s.qty_on_hand, 0, true, auth.uid()
      from public.stock_levels s
      where s.tenant_id = v_tenant and s.location_id = v_count.warehouse_id and s.qty_on_hand <> 0
        and not exists (select 1 from public.stock_count_items i
                        where i.count_id = p_count_id and i.variant_id = s.variant_id and i.bin_id is null);
    end if;
  end if;

  select count(*) into v_lines from public.stock_count_items i where i.count_id = p_count_id;
  if v_lines = 0 then
    raise exception 'nothing was counted' using errcode = '22023', hint = 'nothing_counted';
  end if;

  for v_line in select * from public.stock_count_items i where i.count_id = p_count_id order by i.variant_id, i.bin_id loop
    v_var := v_line.qty_counted - v_line.qty_system;
    update public.stock_count_items set qty_variance = v_var where id = v_line.id;
    if v_line.auto_zero then
      v_zeroed := v_zeroed + 1;
    end if;
    if v_var <> 0 then
      insert into public.stock_movements (tenant_id, location_id, bin_id, variant_id, qty_delta, type, ref_type, ref_id, created_by)
      values (v_tenant, v_count.warehouse_id, v_line.bin_id, v_line.variant_id, v_var, 'count_correction', 'stock_count', p_count_id, auth.uid());
      v_corr := v_corr + 1;
      v_net := v_net + v_var;
    end if;
  end loop;

  update public.stock_counts set status = 'closed', closed_at = now(), closed_by = auth.uid() where id = p_count_id;
  perform public.write_audit('count.close', 'stock_count', p_count_id, v_count.warehouse_id, jsonb_build_object(
    'count_no', v_count.count_no, 'lines', v_lines, 'corrections', v_corr, 'net_variance', trim_scale(v_net), 'zeroed', v_zeroed));
  return jsonb_build_object('count_id', p_count_id, 'status', 'closed', 'lines', v_lines, 'corrections', v_corr,
                            'net_variance', trim_scale(v_net), 'zeroed', v_zeroed);
end;
$$;

-- ---------------------------------------------------------------------------
-- cancel_count(p_count_id, p_reason)
-- ---------------------------------------------------------------------------

create or replace function public.cancel_count(p_count_id uuid, p_reason text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.assert_buyer();
  v_count  record;
begin
  select c.* into v_count from public.stock_counts c where c.id = p_count_id and c.tenant_id = v_tenant for update;
  if not found then
    raise exception 'count not found' using errcode = '22023', hint = 'not_found';
  end if;
  perform public.assert_location_access(v_count.warehouse_id);
  if v_count.status = 'cancelled' then
    return p_count_id;
  end if;
  if v_count.status <> 'open' then
    raise exception 'count is %', v_count.status using errcode = 'P0001', hint = 'invalid_state';
  end if;
  update public.stock_counts
  set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid(), cancel_reason = left(p_reason, 200)
  where id = p_count_id;
  perform public.write_audit('count.cancel', 'stock_count', p_count_id, v_count.warehouse_id,
    jsonb_build_object('count_no', v_count.count_no, 'reason', left(p_reason, 200)));
  return p_count_id;
end;
$$;

revoke execute on function public.start_count(uuid, uuid, uuid, text) from public, anon;
revoke execute on function public.record_count(uuid, jsonb) from public, anon;
revoke execute on function public.close_count(uuid, boolean) from public, anon;
revoke execute on function public.cancel_count(uuid, text) from public, anon;
grant execute on function public.start_count(uuid, uuid, uuid, text) to authenticated;
grant execute on function public.record_count(uuid, jsonb) to authenticated;
grant execute on function public.close_count(uuid, boolean) to authenticated;
grant execute on function public.cancel_count(uuid, text) to authenticated;
