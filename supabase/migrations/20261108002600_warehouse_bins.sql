-- F-09: Warehouse Bins, Zones, Put-away, and Pick Lists (Phase 5b)
--
-- 1. Tables:
--    - warehouse_zones(id, tenant_id, warehouse_id, code, name, type)
--    - bins(id, tenant_id, warehouse_id, zone_id, code, aisle, rack, shelf, position, type, max_qty, active)
--    - bin_stock_levels(tenant_id, bin_id, variant_id, qty_on_hand, updated_at)
--    - pick_lists(id, tenant_id, warehouse_id, transfer_id, pick_list_no, status, assigned_to)
--    - pick_list_items(id, tenant_id, pick_list_id, variant_id, bin_id, qty_requested, qty_picked, short_reason)
-- 2. stock_movements extensions:
--    - add column bin_id (nullable)
--    - add 'bin_move' to stock_movements_type_check
--    - trigger to set default bin on bins-enabled warehouses
--    - trigger to maintain bin_stock_levels
-- 3. Core RPCs:
--    - enable_warehouse_bins(p_warehouse_id)
--    - check_bin_stock_invariant(p_warehouse_id)
--    - upsert_warehouse_zone(...)
--    - upsert_warehouse_bin(...)
--    - list_warehouse_bins(...)
--    - list_bin_stock(...)
--    - move_bin_stock(...)
--    - execute_putaway(...)
--    - generate_pick_list(...)
--    - confirm_pick_item(...)

-- ---------------------------------------------------------------------------
-- 1. Tables: warehouse_zones, bins, bin_stock_levels
-- ---------------------------------------------------------------------------

create table public.warehouse_zones (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  warehouse_id  uuid not null,
  code          text not null check (code ~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,19}$'),
  name          text not null check (length(btrim(name)) between 1 and 120),
  type          text not null check (type in ('receiving', 'storage', 'picking', 'staging', 'quarantine', 'damaged')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  constraint warehouse_zones_tenant_id unique (tenant_id, id),
  constraint warehouse_zones_code_per_warehouse unique (tenant_id, warehouse_id, code),
  constraint warehouse_zones_location_fk foreign key (tenant_id, warehouse_id)
    references public.locations (tenant_id, id) on delete cascade
);

comment on table public.warehouse_zones is 'Functional zones within a warehouse (receiving, storage, picking, staging, etc.).';

create index warehouse_zones_warehouse_idx on public.warehouse_zones (warehouse_id);

create trigger warehouse_zones_tenant_immutable before update of tenant_id on public.warehouse_zones
  for each row execute function public.prevent_tenant_change();

create table public.bins (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  warehouse_id  uuid not null,
  zone_id       uuid,
  code          text not null check (code ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,29}$'),
  aisle         text check (aisle is null or length(aisle) <= 20),
  rack          text check (rack is null or length(rack) <= 20),
  shelf         text check (shelf is null or length(shelf) <= 20),
  position      text check (position is null or length(position) <= 20),
  type          text not null default 'shelf' check (type in ('pallet', 'shelf', 'floor', 'bin')),
  max_qty       numeric(12, 3) check (max_qty is null or max_qty > 0),
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  constraint bins_tenant_id unique (tenant_id, id),
  constraint bins_code_per_warehouse unique (tenant_id, warehouse_id, code),
  constraint bins_location_fk foreign key (tenant_id, warehouse_id)
    references public.locations (tenant_id, id) on delete cascade,
  constraint bins_zone_fk foreign key (tenant_id, zone_id)
    references public.warehouse_zones (tenant_id, id) on delete set null
);

comment on table public.bins is 'Physical bin or shelf locations in a warehouse. code is the scan label / barcode.';

create index bins_warehouse_idx on public.bins (warehouse_id);
create index bins_zone_idx      on public.bins (zone_id);

create trigger bins_tenant_immutable before update of tenant_id on public.bins
  for each row execute function public.prevent_tenant_change();

create table public.bin_stock_levels (
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  bin_id       uuid not null,
  variant_id   uuid not null,
  qty_on_hand  numeric(12, 3) not null default 0,
  updated_at   timestamptz not null default now(),
  primary key (bin_id, variant_id),
  constraint bin_stock_levels_bin_fk foreign key (tenant_id, bin_id)
    references public.bins (tenant_id, id) on delete cascade,
  constraint bin_stock_levels_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id) on delete cascade
);

comment on table public.bin_stock_levels is 'Stock quantity per bin and variant. Invariant: sum per warehouse = stock_levels.';

create index bin_stock_levels_tenant_idx on public.bin_stock_levels (tenant_id, variant_id);

create trigger bin_stock_levels_tenant_immutable before update of tenant_id on public.bin_stock_levels
  for each row execute function public.prevent_tenant_change();

-- ---------------------------------------------------------------------------
-- 2. Pick Lists and Items
-- ---------------------------------------------------------------------------

create table public.pick_lists (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  warehouse_id  uuid not null,
  transfer_id   uuid references public.transfers (id) on delete set null,
  pick_list_no  text not null check (length(pick_list_no) between 3 and 40),
  status        text not null default 'pending' check (status in ('pending', 'in_progress', 'completed', 'cancelled')),
  assigned_to   uuid references auth.users (id) on delete set null,
  completed_at  timestamptz,
  completed_by  uuid references auth.users (id) on delete set null,
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint pick_lists_tenant_id unique (tenant_id, id),
  constraint pick_lists_no_per_tenant unique (tenant_id, pick_list_no),
  constraint pick_lists_warehouse_fk foreign key (tenant_id, warehouse_id)
    references public.locations (tenant_id, id) on delete cascade
);

comment on table public.pick_lists is 'Pick lists allocating transfer order items to bins in walking route order.';

create index pick_lists_warehouse_idx on public.pick_lists (warehouse_id, status);
create index pick_lists_transfer_idx  on public.pick_lists (transfer_id);

create trigger pick_lists_tenant_immutable before update of tenant_id on public.pick_lists
  for each row execute function public.prevent_tenant_change();

create table public.pick_list_items (
  id             uuid primary key default public.uuid_generate_v7(),
  tenant_id      uuid not null references public.tenants (id) on delete cascade,
  pick_list_id   uuid not null,
  variant_id     uuid not null,
  bin_id         uuid not null,
  qty_requested  numeric(12, 3) not null check (qty_requested > 0),
  qty_picked     numeric(12, 3) not null default 0 check (qty_picked >= 0),
  short_reason   text check (short_reason is null or length(short_reason) <= 200),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint pick_list_items_tenant_id unique (tenant_id, id),
  constraint pick_list_items_pick_list_fk foreign key (tenant_id, pick_list_id)
    references public.pick_lists (tenant_id, id) on delete cascade,
  constraint pick_list_items_bin_fk foreign key (tenant_id, bin_id)
    references public.bins (tenant_id, id) on delete cascade,
  constraint pick_list_items_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id) on delete cascade
);

comment on table public.pick_list_items is 'Item allocations per bin for a pick list.';

create index pick_list_items_pick_list_idx on public.pick_list_items (pick_list_id);

create trigger pick_list_items_tenant_immutable before update of tenant_id on public.pick_list_items
  for each row execute function public.prevent_tenant_change();

-- ---------------------------------------------------------------------------
-- 3. Stock Movements Extensions & Invariant Triggers
-- ---------------------------------------------------------------------------

alter table public.stock_movements drop constraint if exists stock_movements_type_check;
alter table public.stock_movements add constraint stock_movements_type_check
  check (type in ('opening', 'sale', 'sale_void', 'receipt', 'count_correction', 'damage',
                  'conversion_out', 'conversion_in', 'conversion_void',
                  'transfer_out', 'transfer_in', 'bin_move'));

alter table public.stock_movements add column if not exists bin_id uuid references public.bins (id) on delete set null;

alter table public.stock_movements add constraint stock_movements_bin_tenant_fk
  foreign key (tenant_id, bin_id) references public.bins (tenant_id, id);

create index if not exists stock_movements_bin_idx on public.stock_movements (tenant_id, bin_id) where bin_id is not null;

-- Before insert trigger: sets default bin (RECEIVING or STAGING) if warehouse has bins enabled and bin_id is null
create or replace function public.set_stock_movement_bin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bins_enabled boolean := false;
  v_target_bin   uuid := new.bin_id;
begin
  if v_target_bin is null then
    select l.bins_enabled into v_bins_enabled
    from public.locations l
    where l.id = new.location_id;

    if v_bins_enabled then
      if new.type = 'transfer_out' then
        select b.id into v_target_bin
        from public.bins b
        join public.warehouse_zones z on z.id = b.zone_id
        where b.warehouse_id = new.location_id and z.type = 'staging' and b.deleted_at is null
        order by b.code limit 1;
      else
        select b.id into v_target_bin
        from public.bins b
        join public.warehouse_zones z on z.id = b.zone_id
        where b.warehouse_id = new.location_id and z.type = 'receiving' and b.deleted_at is null
        order by b.code limit 1;
      end if;
      new.bin_id := v_target_bin;
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function public.set_stock_movement_bin() from public, anon, authenticated;

drop trigger if exists stock_movements_set_bin on public.stock_movements;
create trigger stock_movements_set_bin
  before insert on public.stock_movements
  for each row execute function public.set_stock_movement_bin();

-- Update apply_stock_movement to also update bin_stock_levels when bin_id is present
create or replace function public.apply_stock_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_qty  numeric;
  v_old_cost bigint;
  v_cost     bigint;
  v_counted  boolean := new.type in ('opening', 'receipt', 'count_correction', 'damage', 'conversion_in', 'transfer_in');
begin
  -- 1. Maintain bin_stock_levels if bin_id is present
  if new.bin_id is not null then
    insert into public.bin_stock_levels as bsl (tenant_id, bin_id, variant_id, qty_on_hand, updated_at)
    values (new.tenant_id, new.bin_id, new.variant_id, new.qty_delta, now())
    on conflict (bin_id, variant_id)
    do update set qty_on_hand = bsl.qty_on_hand + excluded.qty_on_hand,
                  updated_at = now();
  end if;

  -- 2. Maintain stock_levels (bin_move is purely internal to warehouse bins, net stock is unchanged)
  if new.type = 'bin_move' then
    return new;
  end if;

  select l.qty_on_hand, l.avg_cost into v_old_qty, v_old_cost
  from public.stock_levels l
  where l.location_id = new.location_id and l.variant_id = new.variant_id
  for update;

  v_cost := v_old_cost;
  if (new.type = 'receipt' or new.type = 'transfer_in') and new.unit_cost is not null then
    v_cost := public.stock_blend_cost(v_old_qty, v_old_cost, new.qty_delta, new.qty_delta * new.unit_cost);
  elsif new.type = 'conversion_in' and new.total_cost is not null then
    v_cost := public.stock_blend_cost(v_old_qty, v_old_cost, new.qty_delta, new.total_cost);
  end if;

  insert into public.stock_levels as sl (tenant_id, location_id, variant_id, qty_on_hand, avg_cost, counted, updated_at)
  values (new.tenant_id, new.location_id, new.variant_id, new.qty_delta, v_cost, v_counted, now())
  on conflict (location_id, variant_id)
  do update set qty_on_hand = sl.qty_on_hand + excluded.qty_on_hand,
                avg_cost = excluded.avg_cost,
                counted = sl.counted or excluded.counted,
                updated_at = now();
  return new;
end;
$$;

revoke execute on function public.apply_stock_movement() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. RLS Policies
-- ---------------------------------------------------------------------------

alter table public.warehouse_zones enable row level security;
alter table public.bins            enable row level security;
alter table public.bin_stock_levels enable row level security;
alter table public.pick_lists      enable row level security;
alter table public.pick_list_items enable row level security;

create policy warehouse_zones_read on public.warehouse_zones
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'admin', 'warehouse')
    and (
      (select public.is_superadmin())
      or warehouse_id = any ((select public.auth_location_ids())::uuid[])
    )
  );

create policy bins_read on public.bins
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'admin', 'warehouse')
    and (
      (select public.is_superadmin())
      or warehouse_id = any ((select public.auth_location_ids())::uuid[])
    )
  );

create policy bin_stock_levels_read on public.bin_stock_levels
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'admin', 'warehouse')
  );

create policy pick_lists_read on public.pick_lists
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'admin', 'warehouse')
    and (
      (select public.is_superadmin())
      or warehouse_id = any ((select public.auth_location_ids())::uuid[])
    )
  );

create policy pick_list_items_read on public.pick_list_items
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'admin', 'warehouse')
  );

revoke all on public.warehouse_zones, public.bins, public.bin_stock_levels, public.pick_lists, public.pick_list_items from anon;
revoke insert, update, delete, truncate on public.warehouse_zones, public.bins, public.bin_stock_levels, public.pick_lists, public.pick_list_items from authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPCs: enable_warehouse_bins & check_bin_stock_invariant
-- ---------------------------------------------------------------------------

create or replace function public.enable_warehouse_bins(p_warehouse_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant         uuid;
  v_role           text;
  v_type           text;
  v_rcv_zone       uuid;
  v_stg_zone       uuid;
  v_gen_zone       uuid;
  v_rcv_bin        uuid;
  v_stg_bin        uuid;
  v_gen_bin        uuid;
  v_migrated_count int := 0;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot manage warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  select type into v_type
  from public.locations
  where id = p_warehouse_id and tenant_id = v_tenant and active and deleted_at is null;

  if not found then
    raise exception 'location not found' using errcode = '22023', hint = 'location_not_found';
  end if;

  if v_type <> 'warehouse' then
    raise exception 'only warehouses can enable bins' using errcode = '22023', hint = 'not_a_warehouse';
  end if;

  -- 1. Enable bins on location
  update public.locations
  set bins_enabled = true, updated_at = now()
  where id = p_warehouse_id and tenant_id = v_tenant;

  -- 2. Create default zones if not exist
  select id into v_rcv_zone from public.warehouse_zones
  where warehouse_id = p_warehouse_id and code = 'RCV' and tenant_id = v_tenant;

  if v_rcv_zone is null then
    v_rcv_zone := public.uuid_generate_v7();
    insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type)
    values (v_rcv_zone, v_tenant, p_warehouse_id, 'RCV', 'Receiving', 'receiving');
  end if;

  select id into v_stg_zone from public.warehouse_zones
  where warehouse_id = p_warehouse_id and code = 'STG' and tenant_id = v_tenant;

  if v_stg_zone is null then
    v_stg_zone := public.uuid_generate_v7();
    insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type)
    values (v_stg_zone, v_tenant, p_warehouse_id, 'STG', 'Staging', 'staging');
  end if;

  select id into v_gen_zone from public.warehouse_zones
  where warehouse_id = p_warehouse_id and code = 'GEN' and tenant_id = v_tenant;

  if v_gen_zone is null then
    v_gen_zone := public.uuid_generate_v7();
    insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type)
    values (v_gen_zone, v_tenant, p_warehouse_id, 'GEN', 'General Storage', 'storage');
  end if;

  -- 3. Create default bins if not exist
  select id into v_rcv_bin from public.bins
  where warehouse_id = p_warehouse_id and code = 'RECEIVING' and tenant_id = v_tenant;

  if v_rcv_bin is null then
    v_rcv_bin := public.uuid_generate_v7();
    insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, type, active)
    values (v_rcv_bin, v_tenant, p_warehouse_id, v_rcv_zone, 'RECEIVING', 'floor', true);
  end if;

  select id into v_stg_bin from public.bins
  where warehouse_id = p_warehouse_id and code = 'STAGING' and tenant_id = v_tenant;

  if v_stg_bin is null then
    v_stg_bin := public.uuid_generate_v7();
    insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, type, active)
    values (v_stg_bin, v_tenant, p_warehouse_id, v_stg_zone, 'STAGING', 'floor', true);
  end if;

  select id into v_gen_bin from public.bins
  where warehouse_id = p_warehouse_id and code = 'A-01-1' and tenant_id = v_tenant;

  if v_gen_bin is null then
    v_gen_bin := public.uuid_generate_v7();
    insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, aisle, rack, shelf, position, type, active)
    values (v_gen_bin, v_tenant, p_warehouse_id, v_gen_zone, 'A-01-1', 'A', '01', '1', '1', 'shelf', true);
  end if;

  -- 4. Seed bin_stock_levels from stock_levels so invariant is immediately true
  insert into public.bin_stock_levels (tenant_id, bin_id, variant_id, qty_on_hand, updated_at)
  select sl.tenant_id, v_rcv_bin, sl.variant_id, sl.qty_on_hand, now()
  from public.stock_levels sl
  where sl.location_id = p_warehouse_id and sl.tenant_id = v_tenant and sl.qty_on_hand <> 0
  on conflict (bin_id, variant_id)
  do update set qty_on_hand = excluded.qty_on_hand, updated_at = now();

  get diagnostics v_migrated_count = row_count;

  perform public.write_audit('warehouse.bins_enabled', 'location', p_warehouse_id, p_warehouse_id,
    jsonb_build_object('migrated_stock_count', v_migrated_count));

  return jsonb_build_object(
    'ok', true,
    'warehouse_id', p_warehouse_id,
    'receiving_bin_id', v_rcv_bin,
    'staging_bin_id', v_stg_bin,
    'migrated_count', v_migrated_count
  );
end;
$$;

revoke execute on function public.enable_warehouse_bins(uuid) from public, anon;
grant execute on function public.enable_warehouse_bins(uuid) to authenticated;

create or replace function public.check_bin_stock_invariant(p_warehouse_id uuid)
returns table (
  variant_id    uuid,
  sku           text,
  warehouse_qty numeric,
  bins_qty      numeric,
  diff          numeric,
  is_valid      boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
begin
  return query
  with b_sum as (
    select bsl.variant_id, coalesce(sum(bsl.qty_on_hand), 0) as total_bins_qty
    from public.bin_stock_levels bsl
    join public.bins b on b.id = bsl.bin_id
    where b.warehouse_id = p_warehouse_id and b.tenant_id = v_tenant and bsl.tenant_id = v_tenant
    group by bsl.variant_id
  ),
  all_vars as (
    select sl.variant_id
    from public.stock_levels sl
    where sl.location_id = p_warehouse_id and sl.tenant_id = v_tenant
    union
    select bs.variant_id
    from b_sum bs
  )
  select
    av.variant_id,
    pv.sku,
    coalesce(sl.qty_on_hand, 0) as warehouse_qty,
    coalesce(bs.total_bins_qty, 0) as bins_qty,
    (coalesce(sl.qty_on_hand, 0) - coalesce(bs.total_bins_qty, 0)) as diff,
    (coalesce(sl.qty_on_hand, 0) = coalesce(bs.total_bins_qty, 0)) as is_valid
  from all_vars av
  join public.product_variants pv on pv.id = av.variant_id and pv.tenant_id = v_tenant
  left join public.stock_levels sl on sl.location_id = p_warehouse_id and sl.variant_id = av.variant_id and sl.tenant_id = v_tenant
  left join b_sum bs on bs.variant_id = av.variant_id
  order by pv.sku;
end;
$$;

revoke execute on function public.check_bin_stock_invariant(uuid) from public, anon;
grant execute on function public.check_bin_stock_invariant(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. RPCs: Zones & Bins CRUD
-- ---------------------------------------------------------------------------

create or replace function public.upsert_warehouse_zone(
  p_warehouse_id uuid,
  p_code         text,
  p_name         text,
  p_type         text,
  p_id           uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_role   text;
  v_id     uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot manage warehouse zones' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if p_code !~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,19}$' then
    raise exception 'invalid zone code' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if length(btrim(p_name)) < 1 or length(p_name) > 120 then
    raise exception 'invalid zone name' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if p_type not in ('receiving', 'storage', 'picking', 'staging', 'quarantine', 'damaged') then
    raise exception 'invalid zone type' using errcode = '22023', hint = 'invalid_argument';
  end if;

  v_id := coalesce(p_id, public.uuid_generate_v7());

  insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type)
  values (v_id, v_tenant, p_warehouse_id, upper(p_code), btrim(p_name), p_type)
  on conflict (tenant_id, id)
  do update set
    code = excluded.code,
    name = excluded.name,
    type = excluded.type,
    updated_at = now();

  return v_id;
end;
$$;

revoke execute on function public.upsert_warehouse_zone(uuid, text, text, text, uuid) from public, anon;
grant execute on function public.upsert_warehouse_zone(uuid, text, text, text, uuid) to authenticated;

create or replace function public.upsert_warehouse_bin(
  p_warehouse_id uuid,
  p_code         text,
  p_zone_id      uuid default null,
  p_aisle        text default null,
  p_rack         text default null,
  p_shelf        text default null,
  p_position     text default null,
  p_type         text default 'shelf',
  p_max_qty      numeric default null,
  p_id           uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_role   text;
  v_id     uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot manage warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if p_code !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,29}$' then
    raise exception 'invalid bin code' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if p_type not in ('pallet', 'shelf', 'floor', 'bin') then
    raise exception 'invalid bin type' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if p_max_qty is not null and p_max_qty <= 0 then
    raise exception 'max qty must be positive' using errcode = '22023', hint = 'positive_qty';
  end if;

  if p_zone_id is not null and not exists (
    select 1 from public.warehouse_zones
    where id = p_zone_id and warehouse_id = p_warehouse_id and tenant_id = v_tenant and deleted_at is null
  ) then
    raise exception 'zone not found' using errcode = '22023', hint = 'not_found';
  end if;

  v_id := coalesce(p_id, public.uuid_generate_v7());

  insert into public.bins (
    id, tenant_id, warehouse_id, zone_id, code,
    aisle, rack, shelf, position, type, max_qty, active
  ) values (
    v_id, v_tenant, p_warehouse_id, p_zone_id, upper(p_code),
    p_aisle, p_rack, p_shelf, p_position, p_type, p_max_qty, true
  )
  on conflict (tenant_id, id)
  do update set
    zone_id = excluded.zone_id,
    code = excluded.code,
    aisle = excluded.aisle,
    rack = excluded.rack,
    shelf = excluded.shelf,
    position = excluded.position,
    type = excluded.type,
    max_qty = excluded.max_qty,
    updated_at = now();

  return v_id;
end;
$$;

revoke execute on function public.upsert_warehouse_bin(uuid, text, uuid, text, text, text, text, text, numeric, uuid) from public, anon;
grant execute on function public.upsert_warehouse_bin(uuid, text, uuid, text, text, text, text, text, numeric, uuid) to authenticated;

create or replace function public.list_warehouse_bins(
  p_warehouse_id uuid,
  p_zone_id      uuid default null
)
returns table (
  id           uuid,
  code         text,
  zone_id      uuid,
  zone_code    text,
  zone_name    text,
  zone_type    text,
  aisle        text,
  rack         text,
  shelf        text,
  "position"   text,
  type         text,
  max_qty      numeric,
  active       boolean,
  item_count   bigint,
  total_qty    numeric
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
begin
  return query
  select
    b.id,
    b.code,
    b.zone_id,
    z.code as zone_code,
    z.name as zone_name,
    z.type as zone_type,
    b.aisle,
    b.rack,
    b.shelf,
    b."position",
    b.type,
    b.max_qty,
    b.active,
    coalesce(count(distinct case when bsl.qty_on_hand <> 0 then bsl.variant_id end), 0) as item_count,
    coalesce(sum(case when bsl.qty_on_hand <> 0 then bsl.qty_on_hand else 0 end), 0) as total_qty
  from public.bins b
  left join public.warehouse_zones z on z.id = b.zone_id
  left join public.bin_stock_levels bsl on bsl.bin_id = b.id
  where b.warehouse_id = p_warehouse_id
    and b.tenant_id = v_tenant
    and b.deleted_at is null
    and (p_zone_id is null or b.zone_id = p_zone_id)
  group by b.id, b.code, b.zone_id, z.code, z.name, z.type, b.aisle, b.rack, b.shelf, b."position", b.type, b.max_qty, b.active
  order by
    coalesce(b.aisle, ''),
    coalesce(b.rack, ''),
    coalesce(b.shelf, ''),
    coalesce(b."position", ''),
    b.code;
end;
$$;

revoke execute on function public.list_warehouse_bins(uuid, uuid) from public, anon;
grant execute on function public.list_warehouse_bins(uuid, uuid) to authenticated;

create or replace function public.list_bin_stock(p_bin_id uuid)
returns table (
  variant_id   uuid,
  sku          text,
  product_name text,
  qty_on_hand  numeric,
  updated_at   timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
begin
  return query
  select
    bsl.variant_id,
    pv.sku,
    p.name as product_name,
    bsl.qty_on_hand,
    bsl.updated_at
  from public.bin_stock_levels bsl
  join public.product_variants pv on pv.id = bsl.variant_id
  join public.products p on p.id = pv.product_id
  where bsl.bin_id = p_bin_id
    and bsl.tenant_id = v_tenant
    and bsl.qty_on_hand <> 0
  order by p.name, pv.sku;
end;
$$;

revoke execute on function public.list_bin_stock(uuid) from public, anon;
grant execute on function public.list_bin_stock(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. RPCs: Bin Movements & Put-away
-- ---------------------------------------------------------------------------

create or replace function public.move_bin_stock(
  p_warehouse_id uuid,
  p_from_bin_id  uuid,
  p_to_bin_id    uuid,
  p_variant_id   uuid,
  p_qty          numeric,
  p_reason       text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_role   text;
  v_avail  numeric := 0;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot move bin stock' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if p_from_bin_id = p_to_bin_id then
    raise exception 'source and destination bins must be different' using errcode = '22023', hint = 'same_bin';
  end if;

  if p_qty <= 0 then
    raise exception 'quantity must be positive' using errcode = '22023', hint = 'positive_qty';
  end if;

  -- Validate both bins belong to this warehouse and tenant
  if not exists (
    select 1 from public.bins where id = p_from_bin_id and warehouse_id = p_warehouse_id and tenant_id = v_tenant and deleted_at is null
  ) or not exists (
    select 1 from public.bins where id = p_to_bin_id and warehouse_id = p_warehouse_id and tenant_id = v_tenant and deleted_at is null
  ) then
    raise exception 'bin not found' using errcode = '22023', hint = 'not_found';
  end if;

  -- Check available quantity in source bin
  select coalesce(qty_on_hand, 0) into v_avail
  from public.bin_stock_levels
  where bin_id = p_from_bin_id and variant_id = p_variant_id;

  if v_avail < p_qty then
    raise exception 'insufficient stock in source bin' using errcode = '55000', hint = 'insufficient_bin_stock';
  end if;

  -- Deduct from source bin
  insert into public.stock_movements (
    tenant_id, location_id, bin_id, variant_id, qty_delta, type, ref_type, created_by
  ) values (
    v_tenant, p_warehouse_id, p_from_bin_id, p_variant_id, -p_qty, 'bin_move', p_reason, auth.uid()
  );

  -- Add to target bin
  insert into public.stock_movements (
    tenant_id, location_id, bin_id, variant_id, qty_delta, type, ref_type, created_by
  ) values (
    v_tenant, p_warehouse_id, p_to_bin_id, p_variant_id, p_qty, 'bin_move', p_reason, auth.uid()
  );
end;
$$;

revoke execute on function public.move_bin_stock(uuid, uuid, uuid, uuid, numeric, text) from public, anon;
grant execute on function public.move_bin_stock(uuid, uuid, uuid, uuid, numeric, text) to authenticated;

create or replace function public.execute_putaway(
  p_warehouse_id uuid,
  p_from_bin_id  uuid,
  p_to_bin_id    uuid,
  p_variant_id   uuid,
  p_qty          numeric
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.move_bin_stock(p_warehouse_id, p_from_bin_id, p_to_bin_id, p_variant_id, p_qty, 'putaway');
end;
$$;

revoke execute on function public.execute_putaway(uuid, uuid, uuid, uuid, numeric) from public, anon;
grant execute on function public.execute_putaway(uuid, uuid, uuid, uuid, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. RPCs: Pick Lists & Item Confirmations
-- ---------------------------------------------------------------------------

create or replace function public.generate_pick_list(p_transfer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant       uuid;
  v_role         text;
  v_transfer     record;
  v_pick_list_id uuid;
  v_pick_no      text;
  v_item         record;
  v_bin_rec      record;
  v_needed       numeric;
  v_take         numeric;
  v_day          text := to_char(now() at time zone 'Asia/Manila', 'YYMMDD');
  v_seq          integer;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot generate pick lists' using errcode = '42501', hint = 'not_allowed';
  end if;

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_transfer.status <> 'draft' then
    raise exception 'pick lists can only be generated for draft transfers' using errcode = '42501', hint = 'transfer_not_draft';
  end if;

  perform public.assert_location_access(v_transfer.from_location_id);

  -- Check if an active pick list already exists
  select id into v_pick_list_id
  from public.pick_lists
  where transfer_id = p_transfer_id and tenant_id = v_tenant and status <> 'cancelled';

  if v_pick_list_id is not null then
    return v_pick_list_id;
  end if;

  -- Generate pick list number: PCK-YYMMDD-NNNN
  select coalesce(max(substring(pick_list_no from 'PCK-[0-9]{6}-([0-9]+)')::int), 0) + 1
  into v_seq
  from public.pick_lists
  where tenant_id = v_tenant and pick_list_no like 'PCK-' || v_day || '-%';

  v_pick_no := 'PCK-' || v_day || '-' || lpad(v_seq::text, 4, '0');
  v_pick_list_id := public.uuid_generate_v7();

  insert into public.pick_lists (
    id, tenant_id, warehouse_id, transfer_id, pick_list_no, status, created_by
  ) values (
    v_pick_list_id, v_tenant, v_transfer.from_location_id, p_transfer_id, v_pick_no, 'pending', auth.uid()
  );

  -- For each transfer line item, allocate bins in walking route order
  for v_item in (
    select ti.variant_id, ti.qty_shipped
    from public.transfer_items ti
    where ti.transfer_id = p_transfer_id and ti.tenant_id = v_tenant
  ) loop
    v_needed := v_item.qty_shipped;

    for v_bin_rec in (
      select bsl.bin_id, bsl.qty_on_hand, b.aisle, b.rack, b.shelf, b."position", b.code
      from public.bin_stock_levels bsl
      join public.bins b on b.id = bsl.bin_id
      left join public.warehouse_zones z on z.id = b.zone_id
      where b.warehouse_id = v_transfer.from_location_id
        and bsl.variant_id = v_item.variant_id
        and bsl.qty_on_hand > 0
        and b.active
        and b.deleted_at is null
      order by
        case when z.type in ('picking', 'storage') then 0 else 1 end,
        coalesce(b.aisle, ''),
        coalesce(b.rack, ''),
        coalesce(b.shelf, ''),
        coalesce(b."position", ''),
        b.code
    ) loop
      exit when v_needed <= 0;

      v_take := least(v_needed, v_bin_rec.qty_on_hand);
      insert into public.pick_list_items (
        id, tenant_id, pick_list_id, variant_id, bin_id, qty_requested, qty_picked
      ) values (
        public.uuid_generate_v7(), v_tenant, v_pick_list_id, v_item.variant_id, v_bin_rec.bin_id, v_take, 0
      );

      v_needed := v_needed - v_take;
    end loop;

    -- If no bins with stock found, fallback to first available bin so item is on the pick list
    if v_needed > 0 then
      select b.id into v_bin_rec.bin_id
      from public.bins b
      where b.warehouse_id = v_transfer.from_location_id and b.deleted_at is null
      order by b.code limit 1;

      if v_bin_rec.bin_id is not null then
        insert into public.pick_list_items (
          id, tenant_id, pick_list_id, variant_id, bin_id, qty_requested, qty_picked
        ) values (
          public.uuid_generate_v7(), v_tenant, v_pick_list_id, v_item.variant_id, v_bin_rec.bin_id, v_needed, 0
        );
      end if;
    end if;
  end loop;

  perform public.write_audit('warehouse.pick_list_generated', 'pick_list', v_pick_list_id, v_transfer.from_location_id,
    jsonb_build_object('pick_list_no', v_pick_no, 'transfer_id', p_transfer_id));

  return v_pick_list_id;
end;
$$;

revoke execute on function public.generate_pick_list(uuid) from public, anon;
grant execute on function public.generate_pick_list(uuid) to authenticated;

create or replace function public.confirm_pick_item(
  p_pick_list_id  uuid,
  p_item_id       uuid,
  p_qty_picked    numeric,
  p_short_reason  text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant        uuid;
  v_pick_list     record;
  v_item          record;
  v_stg_bin       uuid;
  v_unpicked_cnt  integer;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  select * into v_pick_list
  from public.pick_lists
  where id = p_pick_list_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'pick list not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_pick_list.status = 'completed' or v_pick_list.status = 'cancelled' then
    raise exception 'pick list is already completed or cancelled' using errcode = '42501', hint = 'invalid_state';
  end if;

  perform public.assert_location_access(v_pick_list.warehouse_id);

  select * into v_item
  from public.pick_list_items
  where id = p_item_id and pick_list_id = p_pick_list_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'pick item not found' using errcode = '22023', hint = 'not_found';
  end if;

  if p_qty_picked < 0 then
    raise exception 'picked quantity cannot be negative' using errcode = '22023', hint = 'non_negative_qty';
  end if;

  -- Find warehouse STAGING bin
  select b.id into v_stg_bin
  from public.bins b
  join public.warehouse_zones z on z.id = b.zone_id
  where b.warehouse_id = v_pick_list.warehouse_id and z.type = 'staging' and b.deleted_at is null
  order by b.code limit 1;

  if v_stg_bin is null then
    select b.id into v_stg_bin
    from public.bins b
    where b.warehouse_id = v_pick_list.warehouse_id and b.deleted_at is null
    order by b.code limit 1;
  end if;

  -- If picked > 0, move from storage bin to STAGING bin
  if p_qty_picked > 0 and v_item.bin_id <> v_stg_bin then
    perform public.move_bin_stock(
      v_pick_list.warehouse_id,
      v_item.bin_id,
      v_stg_bin,
      v_item.variant_id,
      p_qty_picked,
      'pick'
    );
  end if;

  update public.pick_list_items
  set qty_picked = p_qty_picked,
      short_reason = case when p_qty_picked < qty_requested then p_short_reason else null end,
      updated_at = now()
  where id = p_item_id and tenant_id = v_tenant;

  -- Advance status to in_progress
  update public.pick_lists
  set status = 'in_progress', updated_at = now()
  where id = p_pick_list_id and status = 'pending';

  -- Check if all items are picked
  select count(*) into v_unpicked_cnt
  from public.pick_list_items
  where pick_list_id = p_pick_list_id and tenant_id = v_tenant and qty_picked = 0;

  if v_unpicked_cnt = 0 then
    update public.pick_lists
    set status = 'completed',
        completed_at = now(),
        completed_by = auth.uid(),
        updated_at = now()
    where id = p_pick_list_id;
  end if;
end;
$$;

revoke execute on function public.confirm_pick_item(uuid, uuid, numeric, text) from public, anon;
grant execute on function public.confirm_pick_item(uuid, uuid, numeric, text) to authenticated;
