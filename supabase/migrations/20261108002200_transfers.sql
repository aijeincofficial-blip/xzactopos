-- F-08: Warehouse & Inter-Store Stock Transfers
--
-- Enables two-step stock transfers between locations (warehouses and stores).
--   transfers       header with status: draft -> shipped (in transit) -> received | cancelled.
--   transfer_items  line items with qty_shipped and qty_received. Discrepancy logged if qty_received <> qty_shipped.
--   stock_movements gain 'transfer_out' (deducts origin) and 'transfer_in' (adds destination, blends avg_cost).
--
-- Security:
--   RLS: superadmin sees all transfers; admin/warehouse staff see transfers involving their assigned locations.
--   Writes strictly via SECURITY DEFINER RPCs: create_transfer, ship_transfer, receive_transfer, cancel_transfer.

-- ---------------------------------------------------------------------------
-- 1. Stock Movements: add transfer_out and transfer_in types
-- ---------------------------------------------------------------------------

alter table public.stock_movements drop constraint stock_movements_type_check;
alter table public.stock_movements add constraint stock_movements_type_check
  check (type in ('opening', 'sale', 'sale_void', 'receipt', 'count_correction', 'damage',
                  'conversion_out', 'conversion_in', 'conversion_void',
                  'transfer_out', 'transfer_in'));

-- Update level trigger: transfer_in counts as counted and blends cost if unit_cost is present
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

-- ---------------------------------------------------------------------------
-- 2. Transfers table
-- ---------------------------------------------------------------------------

create table public.transfers (
  id                uuid primary key default public.uuid_generate_v7(),
  tenant_id         uuid not null references public.tenants (id) on delete cascade,
  transfer_no       text not null,
  from_location_id  uuid not null,
  to_location_id    uuid not null,
  status            text not null check (status in ('draft', 'shipped', 'received', 'cancelled')),
  notes             text check (notes is null or length(notes) <= 1000),
  shipped_at        timestamptz,
  shipped_by        uuid references auth.users (id) on delete set null,
  received_at       timestamptz,
  received_by       uuid references auth.users (id) on delete set null,
  cancelled_at      timestamptz,
  cancelled_by      uuid references auth.users (id) on delete set null,
  has_discrepancy   boolean not null default false,
  created_by        uuid references auth.users (id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint transfers_tenant_id unique (tenant_id, id),
  constraint transfers_different_locations check (from_location_id <> to_location_id),
  constraint transfers_from_location_fk foreign key (tenant_id, from_location_id)
    references public.locations (tenant_id, id),
  constraint transfers_to_location_fk foreign key (tenant_id, to_location_id)
    references public.locations (tenant_id, id),
  constraint transfers_shipped_fields check (status not in ('shipped', 'received') or shipped_at is not null),
  constraint transfers_received_fields check (status <> 'received' or received_at is not null)
);

comment on table public.transfers is 'Inter-store and warehouse stock transfers (F-08). Status: draft -> shipped -> received or cancelled.';

create index transfers_tenant_from_idx   on public.transfers (tenant_id, from_location_id, created_at desc);
create index transfers_tenant_to_idx     on public.transfers (tenant_id, to_location_id, created_at desc);
create index transfers_tenant_status_idx on public.transfers (tenant_id, status);

create trigger transfers_set_updated_at before update on public.transfers
  for each row execute function public.set_updated_at();
create trigger transfers_tenant_immutable before update of tenant_id on public.transfers
  for each row execute function public.prevent_tenant_change();

-- ---------------------------------------------------------------------------
-- 3. Transfer Items table
-- ---------------------------------------------------------------------------

create table public.transfer_items (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  transfer_id   uuid not null,
  variant_id    uuid not null,
  qty_shipped   numeric(12, 3) not null check (qty_shipped > 0),
  qty_received  numeric(12, 3) check (qty_received is null or qty_received >= 0),
  created_at    timestamptz not null default now(),
  constraint transfer_items_tenant_id unique (tenant_id, id),
  constraint transfer_items_transfer_fk foreign key (tenant_id, transfer_id)
    references public.transfers (tenant_id, id) on delete cascade,
  constraint transfer_items_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id),
  constraint transfer_items_variant_unique unique (transfer_id, variant_id)
);

comment on table public.transfer_items is 'Line items for stock transfers (F-08).';

create index transfer_items_transfer_idx       on public.transfer_items (transfer_id);
create index transfer_items_tenant_variant_idx on public.transfer_items (tenant_id, variant_id);

create trigger transfer_items_tenant_immutable before update of tenant_id on public.transfer_items
  for each row execute function public.prevent_tenant_change();

-- ---------------------------------------------------------------------------
-- 4. RLS Policies
-- ---------------------------------------------------------------------------

alter table public.transfers enable row level security;
alter table public.transfer_items enable row level security;

create policy transfers_read on public.transfers
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'admin', 'warehouse')
    and (
      (select public.is_superadmin())
      or from_location_id = any ((select public.auth_location_ids())::uuid[])
      or to_location_id = any ((select public.auth_location_ids())::uuid[])
    )
  );

create policy transfer_items_read on public.transfer_items
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'admin', 'warehouse')
    and exists (
      select 1 from public.transfers t
      where t.id = transfer_items.transfer_id
        and (
          (select public.is_superadmin())
          or t.from_location_id = any ((select public.auth_location_ids())::uuid[])
          or t.to_location_id = any ((select public.auth_location_ids())::uuid[])
        )
    )
  );

revoke all on public.transfers, public.transfer_items from anon;
revoke insert, update, delete, truncate on public.transfers, public.transfer_items from authenticated;

-- ---------------------------------------------------------------------------
-- 5. Helper: Next Transfer Number
-- ---------------------------------------------------------------------------

create or replace function public.next_transfer_no(p_tenant_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day text := to_char(now() at time zone 'Asia/Manila', 'YYMMDD');
  v_seq integer;
begin
  select coalesce(max(substring(transfer_no from 'TRF-[0-9]{6}-([0-9]+)')::int), 0) + 1
  into v_seq
  from public.transfers
  where tenant_id = p_tenant_id and transfer_no like 'TRF-' || v_day || '-%';

  return 'TRF-' || v_day || '-' || lpad(v_seq::text, 4, '0');
end;
$$;

revoke execute on function public.next_transfer_no(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. RPC: create_transfer
-- ---------------------------------------------------------------------------

create or replace function public.create_transfer(
  p_from_location_id uuid,
  p_to_location_id   uuid,
  p_notes            text default null,
  p_items            jsonb default '[]'::jsonb,
  p_ship_now         boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant       uuid;
  v_role         text;
  v_transfer_id  uuid;
  v_transfer_no  text;
  v_status       text;
  v_item         jsonb;
  v_variant_id   uuid;
  v_qty          numeric;
  v_unit_cost    bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role = 'cashier' then
    raise exception 'cashiers cannot create transfers' using errcode = '42501', hint = 'not_allowed';
  end if;

  if p_from_location_id = p_to_location_id then
    raise exception 'from and to locations must be different' using errcode = '22023', hint = 'invalid_argument';
  end if;

  -- Caller must have access to the origin location
  perform public.assert_location_access(p_from_location_id);

  -- Destination location must exist and belong to the same tenant
  if not exists (
    select 1 from public.locations
    where id = p_to_location_id and tenant_id = v_tenant and active and deleted_at is null
  ) then
    raise exception 'destination location not found' using errcode = '22023', hint = 'location_not_found';
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'transfer must have at least one item' using errcode = '22023', hint = 'items_required';
  end if;

  v_transfer_id := public.uuid_generate_v7();
  v_transfer_no := public.next_transfer_no(v_tenant);
  v_status := case when p_ship_now then 'shipped' else 'draft' end;

  insert into public.transfers (
    id, tenant_id, transfer_no, from_location_id, to_location_id,
    status, notes, shipped_at, shipped_by, created_by
  ) values (
    v_transfer_id, v_tenant, v_transfer_no, p_from_location_id, p_to_location_id,
    v_status, p_notes, case when p_ship_now then now() else null end,
    case when p_ship_now then auth.uid() else null end, auth.uid()
  );

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_variant_id := (v_item ->> 'variant_id')::uuid;
    v_qty := (v_item ->> 'qty')::numeric;

    if v_qty is null or v_qty <= 0 then
      raise exception 'quantity must be greater than zero' using errcode = '22023', hint = 'qty_invalid';
    end if;

    if not exists (
      select 1 from public.product_variants
      where id = v_variant_id and tenant_id = v_tenant and active and deleted_at is null
    ) then
      raise exception 'product variant not found' using errcode = '22023', hint = 'unknown_variant';
    end if;

    insert into public.transfer_items (
      tenant_id, transfer_id, variant_id, qty_shipped
    ) values (
      v_tenant, v_transfer_id, v_variant_id, v_qty
    );

    if p_ship_now then
      select avg_cost into v_unit_cost
      from public.stock_levels
      where location_id = p_from_location_id and variant_id = v_variant_id;

      insert into public.stock_movements (
        tenant_id, location_id, variant_id, qty_delta, type,
        ref_type, ref_id, unit_cost, created_by
      ) values (
        v_tenant, p_from_location_id, v_variant_id, -v_qty, 'transfer_out',
        'transfer', v_transfer_id, v_unit_cost, auth.uid()
      );
    end if;
  end loop;

  if p_ship_now then
    perform public.write_audit('transfer.ship', 'transfer', v_transfer_id, p_from_location_id,
      jsonb_build_object('transfer_no', v_transfer_no, 'items_count', jsonb_array_length(p_items)));
  else
    perform public.write_audit('transfer.create', 'transfer', v_transfer_id, p_from_location_id,
      jsonb_build_object('transfer_no', v_transfer_no, 'items_count', jsonb_array_length(p_items)));
  end if;

  return v_transfer_id;
end;
$$;

revoke execute on function public.create_transfer from public, anon;
grant execute on function public.create_transfer to authenticated;

-- ---------------------------------------------------------------------------
-- 7. RPC: ship_transfer
-- ---------------------------------------------------------------------------

create or replace function public.ship_transfer(p_transfer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_transfer record;
  v_item     record;
  v_unit_cost bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_transfer.status <> 'draft' then
    raise exception 'transfer is not in draft status' using errcode = '22023', hint = 'invalid_argument';
  end if;

  perform public.assert_location_access(v_transfer.from_location_id);

  update public.transfers
  set status = 'shipped', shipped_at = now(), shipped_by = auth.uid(), updated_at = now()
  where id = p_transfer_id;

  for v_item in
    select variant_id, qty_shipped
    from public.transfer_items
    where transfer_id = p_transfer_id
  loop
    select avg_cost into v_unit_cost
    from public.stock_levels
    where location_id = v_transfer.from_location_id and variant_id = v_item.variant_id;

    insert into public.stock_movements (
      tenant_id, location_id, variant_id, qty_delta, type,
      ref_type, ref_id, unit_cost, created_by
    ) values (
      v_tenant, v_transfer.from_location_id, v_item.variant_id, -v_item.qty_shipped, 'transfer_out',
      'transfer', p_transfer_id, v_unit_cost, auth.uid()
    );
  end loop;

  perform public.write_audit('transfer.ship', 'transfer', p_transfer_id, v_transfer.from_location_id,
    jsonb_build_object('transfer_no', v_transfer.transfer_no));

  return p_transfer_id;
end;
$$;

revoke execute on function public.ship_transfer from public, anon;
grant execute on function public.ship_transfer to authenticated;

-- ---------------------------------------------------------------------------
-- 8. RPC: receive_transfer
-- ---------------------------------------------------------------------------

create or replace function public.receive_transfer(
  p_transfer_id uuid,
  p_items       jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant          uuid;
  v_transfer        record;
  v_item            jsonb;
  v_variant_id      uuid;
  v_qty_received    numeric;
  v_qty_shipped     numeric;
  v_has_discrepancy boolean := false;
  v_unit_cost       bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_transfer.status <> 'shipped' then
    raise exception 'transfer is not in shipped status' using errcode = '22023', hint = 'invalid_argument';
  end if;

  -- Caller must have access to the destination location
  perform public.assert_location_access(v_transfer.to_location_id);

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'received items list required' using errcode = '22023', hint = 'items_required';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_variant_id := (v_item ->> 'variant_id')::uuid;
    v_qty_received := (v_item ->> 'qty_received')::numeric;

    if v_qty_received is null or v_qty_received < 0 then
      raise exception 'received quantity cannot be negative' using errcode = '22023', hint = 'qty_invalid';
    end if;

    select qty_shipped into v_qty_shipped
    from public.transfer_items
    where transfer_id = p_transfer_id and variant_id = v_variant_id;

    if not found then
      raise exception 'item not part of this transfer' using errcode = '22023', hint = 'unknown_variant';
    end if;

    if v_qty_received <> v_qty_shipped then
      v_has_discrepancy := true;
    end if;

    update public.transfer_items
    set qty_received = v_qty_received
    where transfer_id = p_transfer_id and variant_id = v_variant_id;

    if v_qty_received > 0 then
      -- Propagate origin unit_cost from the transfer_out movement
      select unit_cost into v_unit_cost
      from public.stock_movements
      where tenant_id = v_tenant and ref_type = 'transfer' and ref_id = p_transfer_id
        and location_id = v_transfer.from_location_id and variant_id = v_variant_id
        and type = 'transfer_out'
      order by occurred_at desc
      limit 1;

      insert into public.stock_movements (
        tenant_id, location_id, variant_id, qty_delta, type,
        ref_type, ref_id, unit_cost, created_by
      ) values (
        v_tenant, v_transfer.to_location_id, v_variant_id, v_qty_received, 'transfer_in',
        'transfer', p_transfer_id, v_unit_cost, auth.uid()
      );
    end if;
  end loop;

  update public.transfers
  set status = 'received', received_at = now(), received_by = auth.uid(),
      has_discrepancy = v_has_discrepancy, updated_at = now()
  where id = p_transfer_id;

  perform public.write_audit('transfer.receive', 'transfer', p_transfer_id, v_transfer.to_location_id,
    jsonb_build_object(
      'transfer_no', v_transfer.transfer_no,
      'has_discrepancy', v_has_discrepancy
    ));

  return p_transfer_id;
end;
$$;

revoke execute on function public.receive_transfer from public, anon;
grant execute on function public.receive_transfer to authenticated;

-- ---------------------------------------------------------------------------
-- 9. RPC: cancel_transfer
-- ---------------------------------------------------------------------------

create or replace function public.cancel_transfer(
  p_transfer_id uuid,
  p_reason      text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_transfer record;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_transfer.status <> 'draft' then
    raise exception 'can only cancel draft transfers' using errcode = '22023', hint = 'invalid_argument';
  end if;

  perform public.assert_location_access(v_transfer.from_location_id);

  update public.transfers
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = auth.uid(),
      notes = case
        when p_reason is not null and btrim(p_reason) <> '' then
          coalesce(notes || E'\nCancellation reason: ' || p_reason, 'Cancellation reason: ' || p_reason)
        else notes
      end,
      updated_at = now()
  where id = p_transfer_id;

  perform public.write_audit('transfer.cancel', 'transfer', p_transfer_id, v_transfer.from_location_id,
    jsonb_build_object('transfer_no', v_transfer.transfer_no, 'reason', p_reason));

  return p_transfer_id;
end;
$$;

revoke execute on function public.cancel_transfer from public, anon;
grant execute on function public.cancel_transfer to authenticated;
