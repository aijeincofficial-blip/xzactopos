-- F-13c Suppliers and purchase orders (plan section 6 "Inventory and Warehouse", Phase 5).
--
--   suppliers        belong to the TENANT (shared by every warehouse). Names are unique per tenant, ignoring case and spacing.
--   purchase_orders  addressed to ONE warehouse. draft -> ordered -> partly_received -> received, or cancelled.
--   po_items         one line per product; qty_received is written only by the goods-receipt RPC (F-13d), never by clients.
--
-- Who (plan permission `purchasing.manage`): the owner anywhere; a warehouse user for the warehouses they are assigned to.
-- Store admins and cashiers neither see nor write any of it. Writes are RPCs only; the warehouse module must be on.
-- Errors carry a stable `hint` for i18n: not_allowed, location_denied, location_not_found, not_a_warehouse, supplier_not_found,
-- duplicate_supplier, supplier_in_use, name_required, items_required, qty_invalid, invalid_value, duplicate_item, unknown_variant,
-- id_conflict, invalid_state, po_has_receipts, not_found.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.suppliers (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  name          text not null check (length(btrim(name)) between 1 and 120),
  contact_name  text check (length(contact_name) <= 80),
  phone         text check (length(phone) <= 32),
  email         text check (length(email) <= 120),
  notes         text check (length(notes) <= 500),
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  constraint suppliers_tenant_id unique (tenant_id, id)
);

-- a live supplier name is unique per tenant, ignoring case and surrounding spaces
create unique index suppliers_name_per_tenant on public.suppliers (tenant_id, lower(btrim(name))) where deleted_at is null;
create index suppliers_tenant_updated_idx on public.suppliers (tenant_id, updated_at, id);

create table public.purchase_orders (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  po_no         text not null check (length(po_no) between 1 and 40),
  warehouse_id  uuid not null,
  supplier_id   uuid not null,
  status        text not null default 'draft'
                check (status in ('draft', 'ordered', 'partly_received', 'received', 'cancelled')),
  expected_at   date,
  notes         text check (length(notes) <= 1000),
  ordered_at    timestamptz,
  ordered_by    uuid references auth.users (id) on delete set null,
  cancelled_at  timestamptz,
  cancelled_by  uuid references auth.users (id) on delete set null,
  cancel_reason text check (length(cancel_reason) <= 200),
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint purchase_orders_tenant_id unique (tenant_id, id),
  constraint purchase_orders_no_per_tenant unique (tenant_id, po_no),
  constraint purchase_orders_warehouse_fk foreign key (tenant_id, warehouse_id)
    references public.locations (tenant_id, id),
  constraint purchase_orders_supplier_fk foreign key (tenant_id, supplier_id)
    references public.suppliers (tenant_id, id),
  constraint purchase_orders_ordered_fields check (status not in ('ordered', 'partly_received', 'received') or ordered_at is not null),
  constraint purchase_orders_cancelled_fields check (status <> 'cancelled' or cancelled_at is not null)
);

create index purchase_orders_warehouse_idx on public.purchase_orders (tenant_id, warehouse_id, created_at desc);
create index purchase_orders_status_idx    on public.purchase_orders (tenant_id, status);
create index purchase_orders_supplier_idx  on public.purchase_orders (tenant_id, supplier_id);

create table public.po_items (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  po_id         uuid not null,
  variant_id    uuid not null,
  qty_ordered   numeric(12, 3) not null check (qty_ordered > 0),
  -- over-receipt is allowed (the delivery was bigger than ordered); F-13d flags it
  qty_received  numeric(12, 3) not null default 0 check (qty_received >= 0),
  unit_cost     bigint check (unit_cost >= 0),               -- expected cost, base-currency minor units
  created_at    timestamptz not null default now(),
  constraint po_items_tenant_id unique (tenant_id, id),
  constraint po_items_one_per_variant unique (po_id, variant_id),
  constraint po_items_po_fk foreign key (tenant_id, po_id)
    references public.purchase_orders (tenant_id, id) on delete cascade,
  constraint po_items_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id)
);

create index po_items_po_idx      on public.po_items (tenant_id, po_id);
create index po_items_variant_idx on public.po_items (tenant_id, variant_id);

comment on table public.purchase_orders is 'F-13c. Addressed to one warehouse. Status moves only through RPCs.';
comment on column public.po_items.qty_received is 'Written only by the goods-receipt RPC (F-13d).';

-- a PO can only be addressed to a warehouse
create or replace function public.check_po_warehouse()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.locations l where l.id = new.warehouse_id and l.tenant_id = new.tenant_id and l.type = 'warehouse'
  ) then
    raise exception 'a purchase order must be addressed to a warehouse' using errcode = '23514', hint = 'not_a_warehouse';
  end if;
  return new;
end;
$$;

revoke execute on function public.check_po_warehouse() from public, anon, authenticated;

create trigger purchase_orders_warehouse_only before insert or update of warehouse_id on public.purchase_orders
  for each row execute function public.check_po_warehouse();

do $$
declare
  t text;
begin
  foreach t in array array['suppliers', 'purchase_orders'] loop
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t);
  end loop;
  foreach t in array array['suppliers', 'purchase_orders', 'po_items'] loop
    execute format('create trigger %I before update of tenant_id on public.%I for each row execute function public.prevent_tenant_change()',
      t || '_tenant_immutable', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS: owner and warehouse staff only; PO data limited to the user's own warehouses
-- ---------------------------------------------------------------------------

alter table public.suppliers       enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.po_items        enable row level security;

create policy suppliers_read on public.suppliers
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'warehouse'));

create policy purchase_orders_read on public.purchase_orders
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'warehouse')
    and (
      (select public.is_superadmin())
      or warehouse_id = any ((select public.auth_location_ids())::uuid[])
    )
  );

create policy po_items_read on public.po_items
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'warehouse')
    and (
      (select public.is_superadmin())
      or exists (
        select 1 from public.purchase_orders po
        where po.id = po_items.po_id and po.tenant_id = po_items.tenant_id
          and po.warehouse_id = any ((select public.auth_location_ids())::uuid[])
      )
    )
  );

revoke all on public.suppliers, public.purchase_orders, public.po_items from anon;
revoke insert, update, delete, truncate on public.suppliers, public.purchase_orders, public.po_items from authenticated;
grant select on public.suppliers, public.purchase_orders, public.po_items to authenticated;

-- ---------------------------------------------------------------------------
-- PO numbers: PO-YYMMDD-NNNN per tenant and Manila day. Serialized per tenant (the unique key is the backstop).
-- ---------------------------------------------------------------------------

create or replace function public.next_po_no(p_tenant_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day text := to_char(now() at time zone 'Asia/Manila', 'YYMMDD');
  v_seq integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('po_no:' || p_tenant_id::text, 0));
  select coalesce(max(substring(po.po_no from '^PO-[0-9]{6}-([0-9]+)$')::int), 0) + 1
  into v_seq
  from public.purchase_orders po
  where po.tenant_id = p_tenant_id and po.po_no like 'PO-' || v_day || '-%';
  return 'PO-' || v_day || '-' || lpad(v_seq::text, 4, '0');
end;
$$;

revoke execute on function public.next_po_no(uuid) from public, anon, authenticated;

-- the common gate: active user, both modules, owner or warehouse role. Returns the tenant id.
create or replace function public.assert_buyer()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');
  if public.auth_role() not in ('superadmin', 'warehouse') then
    raise exception 'not allowed to manage purchasing' using errcode = '42501', hint = 'not_allowed';
  end if;
  return public.auth_tenant_id();
end;
$$;

revoke execute on function public.assert_buyer() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- upsert_supplier(p_id, name, contact, phone, email, notes): create or fully replace. p_id is client-made (UUIDv7); null = server makes one.
-- ---------------------------------------------------------------------------

create or replace function public.upsert_supplier(
  p_id           uuid,
  p_name         text,
  p_contact_name text default null,
  p_phone        text default null,
  p_email        text default null,
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
  v_name   text := btrim(coalesce(p_name, ''));
  v_owner  uuid;
  v_gone   timestamptz;
begin
  if v_name = '' then
    raise exception 'supplier name is required' using errcode = '22023', hint = 'name_required';
  end if;

  select s.tenant_id, s.deleted_at into v_owner, v_gone from public.suppliers s where s.id = v_id;
  if found and v_owner <> v_tenant then
    raise exception 'id already used' using errcode = 'P0001', hint = 'id_conflict';
  end if;

  if exists (
    select 1 from public.suppliers s
    where s.tenant_id = v_tenant and s.deleted_at is null and s.id <> v_id and lower(btrim(s.name)) = lower(v_name)
  ) then
    raise exception 'a supplier with this name exists' using errcode = 'P0001', hint = 'duplicate_supplier';
  end if;

  if v_owner is null then
    insert into public.suppliers (id, tenant_id, name, contact_name, phone, email, notes, created_by)
    values (v_id, v_tenant, v_name, p_contact_name, p_phone, p_email, p_notes, auth.uid());
  else
    update public.suppliers
    set name = v_name, contact_name = p_contact_name, phone = p_phone, email = p_email, notes = p_notes, deleted_at = null
    where id = v_id and tenant_id = v_tenant;
  end if;

  perform public.write_audit('supplier.save', 'supplier', v_id, null, jsonb_build_object('name', v_name));
  return v_id;
exception when unique_violation then
  raise exception 'a supplier with this name exists' using errcode = 'P0001', hint = 'duplicate_supplier';
end;
$$;

-- ---------------------------------------------------------------------------
-- archive_supplier: soft delete; refused while a PO that is still open points at it
-- ---------------------------------------------------------------------------

create or replace function public.archive_supplier(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.assert_buyer();
  v_gone   timestamptz;
begin
  select s.deleted_at into v_gone from public.suppliers s where s.id = p_id and s.tenant_id = v_tenant;
  if not found then
    raise exception 'supplier not found' using errcode = '22023', hint = 'not_found';
  end if;
  if v_gone is not null then
    return p_id;
  end if;
  if exists (
    select 1 from public.purchase_orders po
    where po.tenant_id = v_tenant and po.supplier_id = p_id and po.status in ('draft', 'ordered', 'partly_received')
  ) then
    raise exception 'supplier has open purchase orders' using errcode = 'P0001', hint = 'supplier_in_use';
  end if;
  update public.suppliers set deleted_at = now() where id = p_id and tenant_id = v_tenant;
  perform public.write_audit('supplier.archive', 'supplier', p_id, null, '{}'::jsonb);
  return p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- create_po: a draft for one warehouse. p_id is client-made; the same id with the same warehouse and supplier is a replay.
-- p_items = [ { variant_id, qty, unit_cost? } ], 1 to 200 lines, one per product.
-- ---------------------------------------------------------------------------

create or replace function public.create_po(
  p_id           uuid,
  p_warehouse_id uuid,
  p_supplier_id  uuid,
  p_expected_at  date default null,
  p_notes        text default null,
  p_items        jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant  uuid := public.assert_buyer();
  v_id      uuid := coalesce(p_id, public.uuid_generate_v7());
  v_type    text;
  v_exist   record;
  v_no      text;
  v_item    jsonb;
  v_vid     uuid;
  v_qty     numeric;
  v_cost    bigint;
  v_seen    uuid[] := '{}';
begin
  select l.type into v_type
  from public.locations l
  where l.id = p_warehouse_id and l.tenant_id = v_tenant and l.active and l.deleted_at is null;
  if not found then
    raise exception 'warehouse not found' using errcode = '22023', hint = 'location_not_found';
  end if;
  perform public.assert_location_access(p_warehouse_id);
  if v_type <> 'warehouse' then
    raise exception 'purchase orders go to a warehouse' using errcode = '22023', hint = 'not_a_warehouse';
  end if;

  -- replay: the same id, warehouse and supplier is the same order
  select po.tenant_id, po.warehouse_id, po.supplier_id into v_exist from public.purchase_orders po where po.id = v_id;
  if found then
    if v_exist.tenant_id = v_tenant and v_exist.warehouse_id = p_warehouse_id and v_exist.supplier_id = p_supplier_id then
      return v_id;
    end if;
    raise exception 'id already used' using errcode = 'P0001', hint = 'id_conflict';
  end if;

  if not exists (
    select 1 from public.suppliers s where s.id = p_supplier_id and s.tenant_id = v_tenant and s.deleted_at is null
  ) then
    raise exception 'supplier not found' using errcode = '22023', hint = 'supplier_not_found';
  end if;

  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 200 then
    raise exception 'a purchase order needs 1 to 200 lines' using errcode = '22023', hint = 'items_required';
  end if;

  -- validate every line before writing anything
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_qty := (v_item ->> 'qty')::numeric;
    v_cost := (v_item ->> 'unit_cost')::bigint;
    if v_qty is null or v_qty <= 0 or v_qty >= 1000000000 then
      raise exception 'quantity must be above zero' using errcode = '22023', hint = 'qty_invalid';
    end if;
    if v_cost is not null and v_cost < 0 then
      raise exception 'cost is invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    if v_vid = any (v_seen) then
      raise exception 'a product can only appear once' using errcode = '22023', hint = 'duplicate_item';
    end if;
    v_seen := v_seen || v_vid;
    if not exists (
      select 1 from public.product_variants v where v.id = v_vid and v.tenant_id = v_tenant and v.active and v.deleted_at is null
    ) then
      raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
    end if;
  end loop;

  v_no := public.next_po_no(v_tenant);
  insert into public.purchase_orders (id, tenant_id, po_no, warehouse_id, supplier_id, status, expected_at, notes, created_by)
  values (v_id, v_tenant, v_no, p_warehouse_id, p_supplier_id, 'draft', p_expected_at, p_notes, auth.uid());

  for v_item in select * from jsonb_array_elements(p_items) loop
    insert into public.po_items (tenant_id, po_id, variant_id, qty_ordered, unit_cost)
    values (v_tenant, v_id, (v_item ->> 'variant_id')::uuid, (v_item ->> 'qty')::numeric, (v_item ->> 'unit_cost')::bigint);
  end loop;

  perform public.write_audit('po.create', 'purchase_order', v_id, p_warehouse_id,
    jsonb_build_object('po_no', v_no, 'lines', jsonb_array_length(p_items)));
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- submit_po: draft -> ordered. Submitting an order that is already ordered (or further along) is harmless.
-- ---------------------------------------------------------------------------

create or replace function public.submit_po(p_po_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.assert_buyer();
  v_po     record;
begin
  select po.* into v_po from public.purchase_orders po where po.id = p_po_id and po.tenant_id = v_tenant for update;
  if not found then
    raise exception 'purchase order not found' using errcode = '22023', hint = 'not_found';
  end if;
  perform public.assert_location_access(v_po.warehouse_id);

  if v_po.status in ('ordered', 'partly_received', 'received') then
    return p_po_id;
  end if;
  if v_po.status <> 'draft' then
    raise exception 'purchase order is %', v_po.status using errcode = 'P0001', hint = 'invalid_state';
  end if;
  if not exists (select 1 from public.po_items i where i.po_id = p_po_id) then
    raise exception 'a purchase order needs lines' using errcode = '22023', hint = 'items_required';
  end if;

  update public.purchase_orders set status = 'ordered', ordered_at = now(), ordered_by = auth.uid() where id = p_po_id;
  perform public.write_audit('po.submit', 'purchase_order', p_po_id, v_po.warehouse_id, jsonb_build_object('po_no', v_po.po_no));
  return p_po_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- cancel_po: draft or ordered with nothing received. Already cancelled is harmless.
-- ---------------------------------------------------------------------------

create or replace function public.cancel_po(p_po_id uuid, p_reason text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.assert_buyer();
  v_po     record;
begin
  select po.* into v_po from public.purchase_orders po where po.id = p_po_id and po.tenant_id = v_tenant for update;
  if not found then
    raise exception 'purchase order not found' using errcode = '22023', hint = 'not_found';
  end if;
  perform public.assert_location_access(v_po.warehouse_id);

  if v_po.status = 'cancelled' then
    return p_po_id;
  end if;
  if v_po.status = 'received' then
    raise exception 'purchase order is received' using errcode = 'P0001', hint = 'invalid_state';
  end if;
  if v_po.status = 'partly_received'
     or exists (select 1 from public.po_items i where i.po_id = p_po_id and i.qty_received > 0) then
    raise exception 'goods were already received' using errcode = 'P0001', hint = 'po_has_receipts';
  end if;

  update public.purchase_orders
  set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid(), cancel_reason = left(p_reason, 200)
  where id = p_po_id;
  perform public.write_audit('po.cancel', 'purchase_order', p_po_id, v_po.warehouse_id,
    jsonb_build_object('po_no', v_po.po_no, 'reason', left(p_reason, 200)));
  return p_po_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: signed-in users only (Supabase grants EXECUTE to anon by default)
-- ---------------------------------------------------------------------------

revoke execute on function public.upsert_supplier(uuid, text, text, text, text, text) from public, anon;
revoke execute on function public.archive_supplier(uuid) from public, anon;
revoke execute on function public.create_po(uuid, uuid, uuid, date, text, jsonb) from public, anon;
revoke execute on function public.submit_po(uuid) from public, anon;
revoke execute on function public.cancel_po(uuid, text) from public, anon;
grant execute on function public.upsert_supplier(uuid, text, text, text, text, text) to authenticated;
grant execute on function public.archive_supplier(uuid) to authenticated;
grant execute on function public.create_po(uuid, uuid, uuid, date, text, jsonb) to authenticated;
grant execute on function public.submit_po(uuid) to authenticated;
grant execute on function public.cancel_po(uuid, text) to authenticated;
