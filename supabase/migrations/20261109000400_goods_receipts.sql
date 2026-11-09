-- F-13d Goods receipts: a delivery against a purchase order (partial, complete or over), a delivery with no PO, and short-closing.
--
--   goods_receipts / goods_receipt_items   the delivery documents. Append-only: a receipt is never edited or deleted.
--   receive_po(...)           lines of ONE delivery against an ordered PO. All-or-nothing. Writes one `receipt` movement per line
--                             (ref_type goods_receipt), adds to po_items.qty_received and moves the PO to partly_received / received.
--   receive_without_po(...)   a delivery with no PO (walk-in). Flagged (without_po) and audited as grn.receive_no_po.
--   close_po(...)             short-close: the supplier will not deliver the rest; the PO becomes received, marked short-closed.
--
-- Stock math rides on the existing ledger triggers: RECEIVING bin when the warehouse has bins, the bin invariant, and the weighted
-- average cost (line cost = the cost given on the delivery, else the PO line's expected cost, else the average is left alone).
-- Over-delivery is accepted and flagged (has_discrepancy, over_received, qty_remaining_before); a short delivery is simply a partly received PO.
-- Who: the owner, or a warehouse user in the warehouse the PO is addressed to (same gate as F-13c). Hints: not_allowed, location_denied,
-- location_not_found, not_a_warehouse, not_found, invalid_state, not_on_po, items_required, qty_invalid, invalid_value, duplicate_item,
-- unknown_variant, supplier_not_found, id_conflict, nothing_received.

-- ---------------------------------------------------------------------------
-- Short-close columns on purchase orders
-- ---------------------------------------------------------------------------

alter table public.purchase_orders
  add column short_closed_at timestamptz,
  add column short_closed_by uuid references auth.users (id) on delete set null,
  add column close_reason    text check (length(close_reason) <= 200);

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.goods_receipts (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  grn_no        text not null check (length(grn_no) between 1 and 40),
  warehouse_id  uuid not null,
  po_id         uuid,
  supplier_id   uuid,
  without_po    boolean not null,
  delivery_ref  text check (length(delivery_ref) <= 64),           -- the supplier's delivery receipt / invoice number
  notes         text check (length(notes) <= 1000),
  has_discrepancy boolean not null default false,                   -- something arrived beyond what the PO still expected
  received_by   uuid references auth.users (id) on delete set null,
  received_at   timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  constraint goods_receipts_tenant_id unique (tenant_id, id),
  constraint goods_receipts_no_per_tenant unique (tenant_id, grn_no),
  constraint goods_receipts_warehouse_fk foreign key (tenant_id, warehouse_id)
    references public.locations (tenant_id, id),
  constraint goods_receipts_po_fk foreign key (tenant_id, po_id)
    references public.purchase_orders (tenant_id, id),
  constraint goods_receipts_supplier_fk foreign key (tenant_id, supplier_id)
    references public.suppliers (tenant_id, id),
  constraint goods_receipts_without_po_agrees check (without_po = (po_id is null))
);

create index goods_receipts_warehouse_idx on public.goods_receipts (tenant_id, warehouse_id, received_at desc);
create index goods_receipts_po_idx        on public.goods_receipts (tenant_id, po_id) where po_id is not null;

create table public.goods_receipt_items (
  id                   uuid primary key default public.uuid_generate_v7(),
  tenant_id            uuid not null references public.tenants (id) on delete cascade,
  grn_id               uuid not null,
  po_item_id           uuid,
  variant_id           uuid not null,
  qty                  numeric(12, 3) not null check (qty > 0),
  unit_cost            bigint check (unit_cost >= 0),
  qty_remaining_before numeric(12, 3) check (qty_remaining_before >= 0),   -- what the PO still expected before this delivery
  over_received        boolean not null default false,
  created_at           timestamptz not null default now(),
  constraint goods_receipt_items_tenant_id unique (tenant_id, id),
  constraint goods_receipt_items_one_per_variant unique (grn_id, variant_id),
  constraint goods_receipt_items_grn_fk foreign key (tenant_id, grn_id)
    references public.goods_receipts (tenant_id, id),
  constraint goods_receipt_items_po_item_fk foreign key (tenant_id, po_item_id)
    references public.po_items (tenant_id, id),
  constraint goods_receipt_items_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id)
);

create index goods_receipt_items_grn_idx     on public.goods_receipt_items (tenant_id, grn_id);
create index goods_receipt_items_variant_idx on public.goods_receipt_items (tenant_id, variant_id);

comment on table public.goods_receipts is 'F-13d. Append-only delivery documents. Stock effect is in stock_movements (ref_type goods_receipt).';

-- a receipt is addressed to a warehouse
create or replace function public.check_grn_warehouse()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.locations l where l.id = new.warehouse_id and l.tenant_id = new.tenant_id and l.type = 'warehouse'
  ) then
    raise exception 'a goods receipt must be addressed to a warehouse' using errcode = '23514', hint = 'not_a_warehouse';
  end if;
  return new;
end;
$$;

revoke execute on function public.check_grn_warehouse() from public, anon, authenticated;

create trigger goods_receipts_warehouse_only before insert on public.goods_receipts
  for each row execute function public.check_grn_warehouse();

-- receipts are never edited or deleted (rows only vanish together with their tenant)
create or replace function public.refuse_receipt_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.tenants t where t.id = old.tenant_id) then
    return old;
  end if;
  raise exception '% is append-only', tg_table_name using errcode = 'P0001', hint = 'append_only';
end;
$$;

revoke execute on function public.refuse_receipt_change() from public, anon, authenticated;

create trigger goods_receipts_append_only before update or delete on public.goods_receipts
  for each row execute function public.refuse_receipt_change();
create trigger goods_receipt_items_append_only before update or delete on public.goods_receipt_items
  for each row execute function public.refuse_receipt_change();

-- ---------------------------------------------------------------------------
-- RLS: owner and warehouse staff, limited to the user's own warehouses; no client writes
-- ---------------------------------------------------------------------------

alter table public.goods_receipts      enable row level security;
alter table public.goods_receipt_items enable row level security;

create policy goods_receipts_read on public.goods_receipts
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'warehouse')
    and (
      (select public.is_superadmin())
      or warehouse_id = any ((select public.auth_location_ids())::uuid[])
    )
  );

create policy goods_receipt_items_read on public.goods_receipt_items
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'warehouse')
    and (
      (select public.is_superadmin())
      or exists (
        select 1 from public.goods_receipts g
        where g.id = goods_receipt_items.grn_id and g.tenant_id = goods_receipt_items.tenant_id
          and g.warehouse_id = any ((select public.auth_location_ids())::uuid[])
      )
    )
  );

revoke all on public.goods_receipts, public.goods_receipt_items from anon;
revoke insert, update, delete, truncate on public.goods_receipts, public.goods_receipt_items from authenticated;
grant select on public.goods_receipts, public.goods_receipt_items to authenticated;

-- ---------------------------------------------------------------------------
-- GRN numbers: GRN-YYMMDD-NNNN per tenant and Manila day, serialized per tenant (the unique key is the backstop)
-- ---------------------------------------------------------------------------

create or replace function public.next_grn_no(p_tenant_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day text := to_char(now() at time zone 'Asia/Manila', 'YYMMDD');
  v_seq integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('grn_no:' || p_tenant_id::text, 0));
  select coalesce(max(substring(g.grn_no from '^GRN-[0-9]{6}-([0-9]+)$')::int), 0) + 1
  into v_seq
  from public.goods_receipts g
  where g.tenant_id = p_tenant_id and g.grn_no like 'GRN-' || v_day || '-%';
  return 'GRN-' || v_day || '-' || lpad(v_seq::text, 4, '0');
end;
$$;

revoke execute on function public.next_grn_no(uuid) from public, anon, authenticated;

-- the answer both receive RPCs give (and a replay gives again)
create or replace function public.grn_result(p_grn_id uuid, p_replay boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('grn_id', g.id, 'grn_no', g.grn_no, 'po_status', po.status,
                            'has_discrepancy', g.has_discrepancy, 'without_po', g.without_po)
         || case when p_replay then jsonb_build_object('replay', true) else '{}'::jsonb end
  from public.goods_receipts g
  left join public.purchase_orders po on po.id = g.po_id and po.tenant_id = g.tenant_id
  where g.id = p_grn_id
$$;

revoke execute on function public.grn_result(uuid, boolean) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- receive_po(p_id, p_po_id, p_items, p_notes, p_delivery_ref)
--   p_items = [ { variant_id, qty (> 0), unit_cost? } ]  the lines of THIS delivery; products not delivered are simply left out.
-- ---------------------------------------------------------------------------

create or replace function public.receive_po(
  p_id           uuid,
  p_po_id        uuid,
  p_items        jsonb,
  p_notes        text default null,
  p_delivery_ref text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.assert_buyer();
  v_id     uuid := coalesce(p_id, public.uuid_generate_v7());
  v_po     record;
  v_exist  record;
  v_no     text;
  v_item   jsonb;
  v_vid    uuid;
  v_qty    numeric;
  v_cost   bigint;
  v_line   record;
  v_seen   uuid[] := '{}';
  v_disc   boolean := false;
  v_remain numeric;
  v_status text;
begin
  select po.* into v_po from public.purchase_orders po where po.id = p_po_id and po.tenant_id = v_tenant for update;
  if not found then
    raise exception 'purchase order not found' using errcode = '22023', hint = 'not_found';
  end if;
  perform public.assert_location_access(v_po.warehouse_id);

  -- replay: the same receipt id for the same PO
  select g.tenant_id, g.po_id into v_exist from public.goods_receipts g where g.id = v_id;
  if found then
    if v_exist.tenant_id = v_tenant and v_exist.po_id = p_po_id then
      return public.grn_result(v_id, true);
    end if;
    raise exception 'id already used' using errcode = 'P0001', hint = 'id_conflict';
  end if;

  if v_po.status not in ('ordered', 'partly_received') then
    raise exception 'purchase order is %', v_po.status using errcode = 'P0001', hint = 'invalid_state';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 200 then
    raise exception 'a delivery needs 1 to 200 lines' using errcode = '22023', hint = 'items_required';
  end if;

  -- pass 1: validate every line and find out whether anything is over-delivered; nothing is written yet
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
    select i.qty_ordered, i.qty_received into v_line from public.po_items i where i.po_id = p_po_id and i.variant_id = v_vid for update;
    if not found then
      raise exception 'product is not on this purchase order' using errcode = 'P0001', hint = 'not_on_po';
    end if;
    if v_qty > greatest(v_line.qty_ordered - v_line.qty_received, 0) then
      v_disc := true;
    end if;
  end loop;

  v_no := public.next_grn_no(v_tenant);
  insert into public.goods_receipts (id, tenant_id, grn_no, warehouse_id, po_id, supplier_id, without_po, delivery_ref, notes,
                                     has_discrepancy, received_by)
  values (v_id, v_tenant, v_no, v_po.warehouse_id, p_po_id, v_po.supplier_id, false, p_delivery_ref, p_notes, v_disc, auth.uid());

  -- pass 2: write the lines, the stock and the PO
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_qty := (v_item ->> 'qty')::numeric;
    select i.id, i.qty_ordered, i.qty_received, i.unit_cost as po_cost into v_line
    from public.po_items i where i.po_id = p_po_id and i.variant_id = v_vid;
    v_remain := greatest(v_line.qty_ordered - v_line.qty_received, 0);
    v_cost := coalesce((v_item ->> 'unit_cost')::bigint, v_line.po_cost);

    insert into public.goods_receipt_items (tenant_id, grn_id, po_item_id, variant_id, qty, unit_cost, qty_remaining_before, over_received)
    values (v_tenant, v_id, v_line.id, v_vid, v_qty, v_cost, v_remain, v_qty > v_remain);

    insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id, unit_cost, created_by)
    values (v_tenant, v_po.warehouse_id, v_vid, v_qty, 'receipt', 'goods_receipt', v_id, v_cost, auth.uid());

    update public.po_items set qty_received = qty_received + v_qty where id = v_line.id;
  end loop;

  v_status := case
    when exists (select 1 from public.po_items i where i.po_id = p_po_id and i.qty_received < i.qty_ordered) then 'partly_received'
    else 'received'
  end;
  update public.purchase_orders set status = v_status where id = p_po_id;

  perform public.write_audit('grn.receive', 'goods_receipt', v_id, v_po.warehouse_id, jsonb_build_object(
    'grn_no', v_no, 'po_no', v_po.po_no, 'lines', jsonb_array_length(p_items), 'discrepancy', v_disc, 'po_status', v_status));
  return public.grn_result(v_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- receive_without_po(p_id, p_warehouse_id, p_supplier_id, p_items, p_notes, p_delivery_ref): a walk-in delivery, flagged
-- ---------------------------------------------------------------------------

create or replace function public.receive_without_po(
  p_id           uuid,
  p_warehouse_id uuid,
  p_supplier_id  uuid,
  p_items        jsonb,
  p_notes        text default null,
  p_delivery_ref text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.assert_buyer();
  v_id     uuid := coalesce(p_id, public.uuid_generate_v7());
  v_type   text;
  v_exist  record;
  v_no     text;
  v_item   jsonb;
  v_vid    uuid;
  v_qty    numeric;
  v_cost   bigint;
  v_seen   uuid[] := '{}';
begin
  select l.type into v_type
  from public.locations l
  where l.id = p_warehouse_id and l.tenant_id = v_tenant and l.active and l.deleted_at is null;
  if not found then
    raise exception 'warehouse not found' using errcode = '22023', hint = 'location_not_found';
  end if;
  perform public.assert_location_access(p_warehouse_id);
  if v_type <> 'warehouse' then
    raise exception 'goods are received into a warehouse' using errcode = '22023', hint = 'not_a_warehouse';
  end if;

  select g.tenant_id, g.warehouse_id, g.po_id into v_exist from public.goods_receipts g where g.id = v_id;
  if found then
    if v_exist.tenant_id = v_tenant and v_exist.warehouse_id = p_warehouse_id and v_exist.po_id is null then
      return public.grn_result(v_id, true);
    end if;
    raise exception 'id already used' using errcode = 'P0001', hint = 'id_conflict';
  end if;

  if p_supplier_id is not null and not exists (
    select 1 from public.suppliers s where s.id = p_supplier_id and s.tenant_id = v_tenant and s.deleted_at is null
  ) then
    raise exception 'supplier not found' using errcode = '22023', hint = 'supplier_not_found';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 200 then
    raise exception 'a delivery needs 1 to 200 lines' using errcode = '22023', hint = 'items_required';
  end if;

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

  v_no := public.next_grn_no(v_tenant);
  insert into public.goods_receipts (id, tenant_id, grn_no, warehouse_id, po_id, supplier_id, without_po, delivery_ref, notes, received_by)
  values (v_id, v_tenant, v_no, p_warehouse_id, null, p_supplier_id, true, p_delivery_ref, p_notes, auth.uid());

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_qty := (v_item ->> 'qty')::numeric;
    v_cost := (v_item ->> 'unit_cost')::bigint;
    insert into public.goods_receipt_items (tenant_id, grn_id, variant_id, qty, unit_cost)
    values (v_tenant, v_id, v_vid, v_qty, v_cost);
    insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id, unit_cost, created_by)
    values (v_tenant, p_warehouse_id, v_vid, v_qty, 'receipt', 'goods_receipt', v_id, v_cost, auth.uid());
  end loop;

  perform public.write_audit('grn.receive_no_po', 'goods_receipt', v_id, p_warehouse_id, jsonb_build_object(
    'grn_no', v_no, 'lines', jsonb_array_length(p_items), 'supplier', p_supplier_id));
  return public.grn_result(v_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- close_po(p_po_id, p_reason): short-close a PO that received something but will not receive the rest
-- ---------------------------------------------------------------------------

create or replace function public.close_po(p_po_id uuid, p_reason text default null)
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

  if v_po.status = 'received' then
    return p_po_id;
  end if;
  if v_po.status not in ('ordered', 'partly_received') then
    raise exception 'purchase order is %', v_po.status using errcode = 'P0001', hint = 'invalid_state';
  end if;
  if not exists (select 1 from public.po_items i where i.po_id = p_po_id and i.qty_received > 0) then
    raise exception 'nothing was received: cancel the purchase order instead' using errcode = 'P0001', hint = 'nothing_received';
  end if;

  update public.purchase_orders
  set status = 'received', short_closed_at = now(), short_closed_by = auth.uid(), close_reason = left(p_reason, 200)
  where id = p_po_id;
  perform public.write_audit('po.close', 'purchase_order', p_po_id, v_po.warehouse_id,
    jsonb_build_object('po_no', v_po.po_no, 'reason', left(p_reason, 200)));
  return p_po_id;
end;
$$;

revoke execute on function public.receive_po(uuid, uuid, jsonb, text, text) from public, anon;
revoke execute on function public.receive_without_po(uuid, uuid, uuid, jsonb, text, text) from public, anon;
revoke execute on function public.close_po(uuid, text) from public, anon;
grant execute on function public.receive_po(uuid, uuid, jsonb, text, text) to authenticated;
grant execute on function public.receive_without_po(uuid, uuid, uuid, jsonb, text, text) to authenticated;
grant execute on function public.close_po(uuid, text) to authenticated;
