-- Location-specific reorder points (overriding variant-level defaults per warehouse/store).
-- Part of Priority 8 (per-warehouse reorder points).

create table if not exists public.location_reorder_points (
  tenant_id     uuid not null references public.tenants(id) on delete cascade,
  location_id   uuid not null references public.locations(id) on delete cascade,
  variant_id    uuid not null references public.product_variants(id) on delete cascade,
  reorder_point numeric(12, 4) not null check (reorder_point >= 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  primary key (tenant_id, location_id, variant_id)
);

create index if not exists idx_loc_reorder_points_variant
  on public.location_reorder_points(tenant_id, variant_id);

alter table public.location_reorder_points enable row level security;

create policy location_reorder_points_read on public.location_reorder_points
  for select to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (
      (select public.is_superadmin())
      or location_id = any ((select public.auth_location_ids())::uuid[])
    )
  );

grant select on public.location_reorder_points to authenticated;
revoke insert, update, delete, truncate on public.location_reorder_points from authenticated;

-- ---------------------------------------------------------------------------
-- warehouse_reorder_list: re-created with per-location reorder point support & is_override flag
-- ---------------------------------------------------------------------------

drop function if exists public.warehouse_reorder_list(uuid, integer, uuid, uuid);

create or replace function public.warehouse_reorder_list(
  p_warehouse_id   uuid default null,
  p_limit          integer default 200,
  p_after_location uuid default null,
  p_after_variant  uuid default null
)
returns table (
  location_id   uuid,
  location_code text,
  variant_id    uuid,
  sku           text,
  product_name  text,
  qty_on_hand   numeric,
  reorder_point numeric,
  incoming_qty  numeric,
  on_order_qty  numeric,
  covered       boolean,
  shortfall     numeric,
  is_override   boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  with inc as (
    select t.to_location_id as loc, ti.variant_id, sum(ti.qty_shipped) as q
    from public.transfer_items ti
    join public.transfers t on t.id = ti.transfer_id and t.tenant_id = ti.tenant_id
    where t.status = 'shipped'
    group by t.to_location_id, ti.variant_id
  ), ord as (
    select po.warehouse_id as loc, i.variant_id, sum(greatest(i.qty_ordered - i.qty_received, 0)) as q
    from public.po_items i
    join public.purchase_orders po on po.id = i.po_id and po.tenant_id = i.tenant_id
    where po.status in ('ordered', 'partly_received')
    group by po.warehouse_id, i.variant_id
  )
  select s.location_id, l.code, s.variant_id, v.sku, p.name,
         s.qty_on_hand, coalesce(lrp.reorder_point, v.reorder_point),
         coalesce(inc.q, 0), coalesce(ord.q, 0),
         s.qty_on_hand + coalesce(inc.q, 0) + coalesce(ord.q, 0) > coalesce(lrp.reorder_point, v.reorder_point),
         greatest(coalesce(lrp.reorder_point, v.reorder_point) - (s.qty_on_hand + coalesce(inc.q, 0) + coalesce(ord.q, 0)), 0),
         lrp.reorder_point is not null as is_override
  from public.stock_levels s
  join public.locations l on l.id = s.location_id and l.type = 'warehouse' and l.active and l.deleted_at is null
  join public.product_variants v on v.id = s.variant_id and v.active and v.deleted_at is null
  join public.products p on p.id = v.product_id and p.tenant_id = v.tenant_id
  left join public.location_reorder_points lrp
    on lrp.tenant_id = s.tenant_id and lrp.location_id = s.location_id and lrp.variant_id = s.variant_id
  left join inc on inc.loc = s.location_id and inc.variant_id = s.variant_id
  left join ord on ord.loc = s.location_id and ord.variant_id = s.variant_id
  where coalesce(lrp.reorder_point, v.reorder_point) > 0
    and s.qty_on_hand <= coalesce(lrp.reorder_point, v.reorder_point)
    and (p_warehouse_id is null or s.location_id = p_warehouse_id)
    and (p_after_location is null or (s.location_id, s.variant_id) > (p_after_location, p_after_variant))
  order by s.location_id, s.variant_id
  limit greatest(1, least(coalesce(p_limit, 200), 500))
$$;

revoke execute on function public.warehouse_reorder_list(uuid, integer, uuid, uuid) from public, anon;
grant execute on function public.warehouse_reorder_list(uuid, integer, uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- set_location_reorder_point: upsert or clear location-specific threshold
-- ---------------------------------------------------------------------------

create or replace function public.set_location_reorder_point(
  p_location_id   uuid,
  p_variant_id    uuid,
  p_reorder_point numeric default null
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant    uuid;
  v_effective numeric;
begin
  perform public.assert_active_user();
  v_tenant := public.auth_tenant_id();

  -- Permission: superadmin, store manager of that location, or warehouse staff of that location
  if not (
    public.is_superadmin()
    or public.has_location_access(p_location_id, 'manager')
    or (public.auth_role() = 'warehouse' and p_location_id = any ((public.auth_location_ids())::uuid[]))
  ) then
    raise exception 'not allowed' using errcode = '42501', hint = 'not_allowed';
  end if;

  if not exists (select 1 from public.locations where id = p_location_id and tenant_id = v_tenant and deleted_at is null) then
    raise exception 'location not found' using errcode = '22023', hint = 'location_not_found';
  end if;

  if not exists (select 1 from public.product_variants where id = p_variant_id and tenant_id = v_tenant and deleted_at is null) then
    raise exception 'variant not found' using errcode = '22023', hint = 'variant_not_found';
  end if;

  if p_reorder_point is null or p_reorder_point < 0 then
    delete from public.location_reorder_points
    where tenant_id = v_tenant and location_id = p_location_id and variant_id = p_variant_id;
  else
    insert into public.location_reorder_points (tenant_id, location_id, variant_id, reorder_point, updated_at)
    values (v_tenant, p_location_id, p_variant_id, p_reorder_point, now())
    on conflict (tenant_id, location_id, variant_id) do update
    set reorder_point = excluded.reorder_point, updated_at = now();
  end if;

  perform public.write_audit(
    'location.set_reorder_point',
    'location',
    p_location_id,
    null,
    jsonb_build_object('variant_id', p_variant_id, 'reorder_point', p_reorder_point)
  );

  select coalesce(lrp.reorder_point, v.reorder_point)
  from public.product_variants v
  left join public.location_reorder_points lrp
    on lrp.tenant_id = v_tenant and lrp.location_id = p_location_id and lrp.variant_id = v.id
  where v.id = p_variant_id
  into v_effective;

  return v_effective;
end;
$$;

revoke execute on function public.set_location_reorder_point(uuid, uuid, numeric) from public, anon;
grant execute on function public.set_location_reorder_point(uuid, uuid, numeric) to authenticated;
