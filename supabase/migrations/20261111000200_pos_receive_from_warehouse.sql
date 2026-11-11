-- ============================================================================
-- Migration: 20261111000200_pos_receive_from_warehouse.sql
-- Purpose  : Allow POS store staff (cashiers, supervisors, managers, owners)
--            assigned to a store to list incoming warehouse shipments destined
--            for their store (without exposing unit costs) so POS terminals can
--            receive stock dispatched from the Warehouse portal.
-- ============================================================================

create or replace function public.list_store_incoming_transfers(
  p_store_id         uuid,
  p_include_received boolean default true
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_loc_type text;
  v_result   jsonb;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  select l.type into v_loc_type
  from public.locations l
  where l.id = p_store_id
    and l.tenant_id = v_tenant
    and l.deleted_at is null;

  if v_loc_type is null then
    raise exception 'store not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_loc_type <> 'store' then
    raise exception 'destination must be a store' using errcode = '22023', hint = 'invalid_location_type';
  end if;

  perform public.assert_location_access(p_store_id);

  select coalesce(jsonb_agg(row_json), '[]'::jsonb)
  into v_result
  from (
    select jsonb_build_object(
      'id', t.id,
      'transfer_no', t.transfer_no,
      'from_location_id', t.from_location_id,
      'to_location_id', t.to_location_id,
      'status', t.status,
      'notes', t.notes,
      'shipped_at', t.shipped_at,
      'received_at', t.received_at,
      'has_discrepancy', t.has_discrepancy,
      'created_at', t.created_at,
      'from_location', jsonb_build_object(
        'id', fl.id,
        'code', fl.code,
        'name', fl.name,
        'type', fl.type
      ),
      'to_location', jsonb_build_object(
        'id', tl.id,
        'code', tl.code,
        'name', tl.name,
        'type', tl.type
      ),
      'transfer_items', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', ti.id,
            'transfer_id', ti.transfer_id,
            'variant_id', ti.variant_id,
            'qty_shipped', ti.qty_shipped,
            'qty_received', ti.qty_received,
            'sku', pv.sku,
            'barcode', pv.barcode,
            'product_name', p.name,
            'unit', p.unit
          )
          order by p.name asc, pv.sku asc
        )
        from public.transfer_items ti
        join public.product_variants pv
          on pv.tenant_id = ti.tenant_id and pv.id = ti.variant_id
        join public.products p
          on p.tenant_id = pv.tenant_id and p.id = pv.product_id
        where ti.tenant_id = v_tenant
          and ti.transfer_id = t.id
      ), '[]'::jsonb)
    ) as row_json
    from public.transfers t
    join public.locations fl
      on fl.tenant_id = t.tenant_id and fl.id = t.from_location_id
    join public.locations tl
      on tl.tenant_id = t.tenant_id and tl.id = t.to_location_id
    where t.tenant_id = v_tenant
      and t.to_location_id = p_store_id
      and (
        t.status = 'shipped'
        or (p_include_received and t.status = 'received')
      )
    order by
      case when t.status = 'shipped' then 0 else 1 end asc,
      coalesce(t.shipped_at, t.created_at) desc
    limit 50
  ) sub;

  return v_result;
end;
$$;

revoke execute on function public.list_store_incoming_transfers(uuid, boolean) from public, anon;
grant execute on function public.list_store_incoming_transfers(uuid, boolean) to authenticated;
