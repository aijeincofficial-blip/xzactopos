-- F-13a Multi-warehouse hardening. Found by 035_multi_warehouse.test.sql (a tenant with two warehouses).
--
-- 1. bin_stock_levels and pick_list_items were readable across warehouses: their policies checked the role but not
--    which warehouse the user is assigned to. They have no warehouse column, so the scope comes from the parent
--    (bin -> warehouse, pick list -> warehouse). Superadmin still reads everything.
-- 2. A transfer shipped from a bins-enabled warehouse without a pick drove the STAGING bin negative (the movement is
--    routed to STAGING, which only holds what was picked). It now fails with hint `pick_required` until the units
--    are picked into STAGING. The warehouse total and the bin invariant were never wrong; the bin was.

-- ---------------------------------------------------------------------------
-- 1. Policies scoped by warehouse
-- ---------------------------------------------------------------------------

drop policy if exists bin_stock_levels_read on public.bin_stock_levels;
create policy bin_stock_levels_read on public.bin_stock_levels
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'admin', 'warehouse')
    and (
      (select public.is_superadmin())
      or exists (
        select 1 from public.bins b
        where b.id = bin_stock_levels.bin_id
          and b.tenant_id = bin_stock_levels.tenant_id
          and b.warehouse_id = any ((select public.auth_location_ids())::uuid[])
      )
    )
  );

drop policy if exists pick_list_items_read on public.pick_list_items;
create policy pick_list_items_read on public.pick_list_items
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.auth_role()) in ('superadmin', 'admin', 'warehouse')
    and (
      (select public.is_superadmin())
      or exists (
        select 1 from public.pick_lists pl
        where pl.id = pick_list_items.pick_list_id
          and pl.tenant_id = pick_list_items.tenant_id
          and pl.warehouse_id = any ((select public.auth_location_ids())::uuid[])
      )
    )
  );

-- ---------------------------------------------------------------------------
-- 2. A transfer out cannot take more from STAGING than was picked into it
--    (copy of the 20261108002600 definition plus the guard)
-- ---------------------------------------------------------------------------

create or replace function public.set_stock_movement_bin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bins_enabled boolean := false;
  v_target_bin   uuid := new.bin_id;
  v_staged       numeric;
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

        -- lock the staging row so two concurrent shipments cannot both spend the same picked units
        select coalesce((
          select s.qty_on_hand from public.bin_stock_levels s
          where s.bin_id = v_target_bin and s.variant_id = new.variant_id
          for update
        ), 0) into v_staged;

        if v_staged + new.qty_delta < 0 then
          raise exception 'only % picked into staging, % needed: pick the items before shipping',
            v_staged, -new.qty_delta
            using errcode = '55000', hint = 'pick_required';
        end if;
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
