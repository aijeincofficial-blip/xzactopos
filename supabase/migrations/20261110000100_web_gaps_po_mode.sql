-- 20261110000100_web_gaps_po_mode.sql: Web Solo/Full gaps:
-- 1. Stored mode flag in tenant_settings, exposed in get_my_access() and updated on warehouse enablement.
-- 2. update_po RPC for editing draft purchase orders.
-- 3. Helpers for put-away and pick-lists (list_receiving_stock, get_pick_list_for_transfer).

-- ---------------------------------------------------------------------------
-- 1. Stored mode flag in tenant_settings
-- ---------------------------------------------------------------------------

alter table public.tenant_settings
  add column if not exists mode text not null default 'solo' check (mode in ('solo', 'full'));

grant update (mode) on public.tenant_settings to authenticated;

create or replace function public.set_tenant_mode(p_mode text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
begin
  perform public.assert_superadmin();
  if p_mode not in ('solo', 'full') then
    raise exception 'invalid mode %', p_mode using errcode = '22023', hint = 'invalid_mode';
  end if;
  v_tenant := public.auth_tenant_id();
  update public.tenant_settings
    set mode = p_mode
    where tenant_id = v_tenant;
end;
$$;

revoke execute on function public.set_tenant_mode(text) from public, anon;
grant execute on function public.set_tenant_mode(text) to authenticated;

-- Update set_modules: when warehouse is turned on, set mode to 'full'
create or replace function public.set_modules(p_pos boolean, p_warehouse boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_before public.tenant_modules;
begin
  perform public.assert_superadmin();
  v_tenant := public.auth_tenant_id();

  select * into v_before from public.tenant_modules m where m.tenant_id = v_tenant for update;
  if not found then
    insert into public.tenant_modules (tenant_id, pos, warehouse) values (v_tenant, p_pos, p_warehouse);
  else
    -- turning a module off hides it and blocks writes; it never deletes data
    update public.tenant_modules
      set inventory = true, pos = p_pos, warehouse = p_warehouse
      where tenant_id = v_tenant;
  end if;

  if p_warehouse then
    update public.tenant_settings
      set mode = 'full'
      where tenant_id = v_tenant and mode <> 'full';
  end if;

  perform public.write_audit('modules.set', 'tenant', v_tenant, null, jsonb_build_object(
    'before', jsonb_build_object('pos', v_before.pos, 'warehouse', v_before.warehouse),
    'after',  jsonb_build_object('pos', p_pos, 'warehouse', p_warehouse)));
end;
$$;

-- Expose mode in get_my_access()
create or replace function public.get_my_access()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_result jsonb;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;

  select jsonb_build_object(
    'user_id', p.user_id,
    'username', p.username,
    'full_name', p.full_name,
    'role', p.role,
    'locale', coalesce(p.locale, s.default_locale, 'en'),
    'is_platform_admin', public.is_platform_admin(),
    'tenant', jsonb_build_object(
      'id', t.id, 'name', t.name, 'slug', t.slug, 'status', t.status,
      'base_currency', t.base_currency, 'timezone', t.timezone,
      'setup_completed', t.setup_completed_at is not null,
      'mode', coalesce(s.mode, 'solo')),
    'modules', jsonb_build_object(
      'inventory', coalesce(m.inventory, false),
      'pos', coalesce(m.pos, false),
      'warehouse', coalesce(m.warehouse, false)),
    'locations', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id, 'type', l.type, 'code', l.code, 'name', l.name,
               'position', la.position) order by l.code)
      from public.locations l
      left join public.location_access la
        on la.location_id = l.id and la.user_id = p.user_id and la.deleted_at is null
      where l.tenant_id = v_tenant
        and l.deleted_at is null
        and (p.role = 'superadmin' or la.user_id is not null)
    ), '[]'::jsonb)
  )
  into v_result
  from public.profiles p
  join public.tenants t on t.id = p.tenant_id
  left join public.tenant_modules m on m.tenant_id = t.id
  left join public.tenant_settings s on s.tenant_id = t.id
  where p.user_id = auth.uid();

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. update_po: edit a draft purchase order
-- ---------------------------------------------------------------------------

create or replace function public.update_po(
  p_po_id        uuid,
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
  v_po      record;
  v_item    jsonb;
  v_vid     uuid;
  v_qty     numeric;
  v_cost    bigint;
  v_seen    uuid[] := '{}';
begin
  select po.* into v_po
  from public.purchase_orders po
  where po.id = p_po_id and po.tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'purchase order not found' using errcode = '22023', hint = 'not_found';
  end if;

  perform public.assert_location_access(v_po.warehouse_id);

  if v_po.status <> 'draft' then
    raise exception 'purchase order is %', v_po.status using errcode = 'P0001', hint = 'po_not_draft';
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

  update public.purchase_orders
    set supplier_id = p_supplier_id,
        expected_at = p_expected_at,
        notes = p_notes,
        updated_at = clock_timestamp()
    where id = p_po_id;

  delete from public.po_items where po_id = p_po_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    insert into public.po_items (tenant_id, po_id, variant_id, qty_ordered, unit_cost)
    values (v_tenant, p_po_id, (v_item ->> 'variant_id')::uuid, (v_item ->> 'qty')::numeric, (v_item ->> 'unit_cost')::bigint);
  end loop;

  perform public.write_audit('po.update', 'purchase_order', p_po_id, v_po.warehouse_id,
    jsonb_build_object('po_no', v_po.po_no, 'lines', jsonb_array_length(p_items)));

  return p_po_id;
end;
$$;

revoke execute on function public.update_po(uuid, uuid, date, text, jsonb) from public, anon;
grant execute on function public.update_po(uuid, uuid, date, text, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Put-away helper: list stock currently sitting in receiving bins
-- ---------------------------------------------------------------------------

create or replace function public.list_receiving_stock(p_warehouse_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_result jsonb;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  perform public.assert_location_access(p_warehouse_id);

  select coalesce(jsonb_agg(jsonb_build_object(
    'bin_id', b.id,
    'bin_code', b.code,
    'variant_id', bsl.variant_id,
    'sku', pv.sku,
    'product_name', p.name,
    'qty_on_hand', bsl.qty_on_hand,
    'updated_at', bsl.updated_at
  ) order by b.code, p.name, pv.sku), '[]'::jsonb)
  into v_result
  from public.bin_stock_levels bsl
  join public.bins b on b.id = bsl.bin_id
  join public.warehouse_zones z on z.id = b.zone_id
  join public.product_variants pv on pv.id = bsl.variant_id
  join public.products p on p.id = pv.product_id
  where b.warehouse_id = p_warehouse_id
    and b.tenant_id = v_tenant
    and b.deleted_at is null
    and z.type = 'receiving'
    and bsl.qty_on_hand > 0;

  return v_result;
end;
$$;

revoke execute on function public.list_receiving_stock(uuid) from public, anon;
grant execute on function public.list_receiving_stock(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Pick list helper: get pick list details with ordered items for a transfer
-- ---------------------------------------------------------------------------

create or replace function public.get_pick_list_for_transfer(p_transfer_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_result jsonb;
begin
  perform public.assert_active_user();
  v_tenant := public.auth_tenant_id();

  select jsonb_build_object(
    'id', pl.id,
    'warehouse_id', pl.warehouse_id,
    'transfer_id', pl.transfer_id,
    'pick_list_no', pl.pick_list_no,
    'status', pl.status,
    'created_at', pl.created_at,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pli.id,
        'pick_list_id', pli.pick_list_id,
        'variant_id', pli.variant_id,
        'sku', pv.sku,
        'product_name', p.name,
        'bin_id', pli.bin_id,
        'bin_code', b.code,
        'location_info', concat_ws('-', b.aisle, b.rack, b.shelf, b."position"),
        'qty_requested', pli.qty_requested,
        'qty_picked', pli.qty_picked,
        'short_reason', pli.short_reason
      ) order by coalesce(b.aisle, ''), coalesce(b.rack, ''), coalesce(b.shelf, ''), coalesce(b."position", ''), b.code)
      from public.pick_list_items pli
      join public.product_variants pv on pv.id = pli.variant_id
      join public.products p on p.id = pv.product_id
      join public.bins b on b.id = pli.bin_id
      where pli.pick_list_id = pl.id and pli.tenant_id = v_tenant
    ), '[]'::jsonb)
  )
  into v_result
  from public.pick_lists pl
  where pl.transfer_id = p_transfer_id and pl.tenant_id = v_tenant
  order by pl.created_at desc
  limit 1;

  return v_result;
end;
$$;

revoke execute on function public.get_pick_list_for_transfer(uuid) from public, anon;
grant execute on function public.get_pick_list_for_transfer(uuid) to authenticated;
