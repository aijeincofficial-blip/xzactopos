-- F-13f Read-only views across warehouses: where is a product, what needs reordering, what is in transit.
--
-- All three run AS THE CALLER (security invoker) and write nothing. Row-level security does the scoping, so the answer is always limited
-- to what the user may already read: the owner sees every warehouse, a warehouse user only their own, a store admin or cashier none.
-- Names of locations the caller cannot see (for example the other end of a shipment) come back as null.
--
-- "Incoming" = units on shipped transfers that have not been received. "On order" = units still expected on ordered or partly received
-- purchase orders (ordered minus received, never below zero). Drafts, cancelled and finished documents are not counted.
-- Reorder uses the variant's own reorder_point (one number per product for every place it is stocked; 0 means "not managed").
-- Lists are keyset-paged, 1 to 500 rows per page, explicit columns.

-- ---------------------------------------------------------------------------
-- warehouse_stock_by_variant(variant): one row per visible warehouse, including warehouses that hold none
-- ---------------------------------------------------------------------------

create or replace function public.warehouse_stock_by_variant(p_variant_id uuid)
returns table (
  location_id  uuid,
  code         text,
  name         text,
  bins_enabled boolean,
  qty_on_hand  numeric,
  avg_cost     bigint,
  stock_value  bigint,
  incoming_qty numeric,
  on_order_qty numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  select l.id, l.code, l.name, l.bins_enabled,
         coalesce(s.qty_on_hand, 0),
         s.avg_cost,
         case when s.avg_cost is null then null else round(coalesce(s.qty_on_hand, 0) * s.avg_cost)::bigint end,
         coalesce((select sum(ti.qty_shipped)
                   from public.transfer_items ti
                   join public.transfers t on t.id = ti.transfer_id and t.tenant_id = ti.tenant_id
                   where t.status = 'shipped' and t.to_location_id = l.id and ti.variant_id = p_variant_id), 0),
         coalesce((select sum(greatest(i.qty_ordered - i.qty_received, 0))
                   from public.po_items i
                   join public.purchase_orders po on po.id = i.po_id and po.tenant_id = i.tenant_id
                   where po.status in ('ordered', 'partly_received') and po.warehouse_id = l.id and i.variant_id = p_variant_id), 0)
  from public.locations l
  left join public.stock_levels s on s.location_id = l.id and s.variant_id = p_variant_id
  where l.type = 'warehouse' and l.active and l.deleted_at is null
  order by l.code
$$;

-- ---------------------------------------------------------------------------
-- warehouse_reorder_list(warehouse?, limit, after_location, after_variant): lines at or below the reorder point
--   covered   = on hand + incoming + on order is above the reorder point (something is already on its way)
--   shortfall = how far the reorder point is above on hand + incoming + on order (0 when covered)
-- ---------------------------------------------------------------------------

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
  shortfall     numeric
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
         s.qty_on_hand, v.reorder_point,
         coalesce(inc.q, 0), coalesce(ord.q, 0),
         s.qty_on_hand + coalesce(inc.q, 0) + coalesce(ord.q, 0) > v.reorder_point,
         greatest(v.reorder_point - (s.qty_on_hand + coalesce(inc.q, 0) + coalesce(ord.q, 0)), 0)
  from public.stock_levels s
  join public.locations l on l.id = s.location_id and l.type = 'warehouse' and l.active and l.deleted_at is null
  join public.product_variants v on v.id = s.variant_id and v.active and v.deleted_at is null and v.reorder_point > 0
  join public.products p on p.id = v.product_id and p.tenant_id = v.tenant_id
  left join inc on inc.loc = s.location_id and inc.variant_id = s.variant_id
  left join ord on ord.loc = s.location_id and ord.variant_id = s.variant_id
  where s.qty_on_hand <= v.reorder_point
    and (p_warehouse_id is null or s.location_id = p_warehouse_id)
    and (p_after_location is null or (s.location_id, s.variant_id) > (p_after_location, p_after_variant))
  order by s.location_id, s.variant_id
  limit greatest(1, least(coalesce(p_limit, 200), 500))
$$;

-- ---------------------------------------------------------------------------
-- warehouse_transfers_in_transit(warehouse?, limit, after_shipped_at, after_id): shipped, not yet received, touching a warehouse
--   newest first. A shipment appears when a warehouse the caller can see is at either end.
-- ---------------------------------------------------------------------------

create or replace function public.warehouse_transfers_in_transit(
  p_warehouse_id     uuid default null,
  p_limit            integer default 100,
  p_after_shipped_at timestamptz default null,
  p_after_id         uuid default null
)
returns table (
  transfer_id     uuid,
  transfer_no     text,
  from_location_id uuid,
  from_code       text,
  to_location_id  uuid,
  to_code         text,
  shipped_at      timestamptz,
  hours_in_transit numeric,
  lines           integer,
  units           numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  select t.id, t.transfer_no, t.from_location_id, lf.code, t.to_location_id, lt.code, t.shipped_at,
         round(extract(epoch from (now() - t.shipped_at)) / 3600, 1),
         (select count(*)::int from public.transfer_items ti where ti.transfer_id = t.id and ti.tenant_id = t.tenant_id),
         (select coalesce(sum(ti.qty_shipped), 0) from public.transfer_items ti where ti.transfer_id = t.id and ti.tenant_id = t.tenant_id)
  from public.transfers t
  left join public.locations lf on lf.id = t.from_location_id
  left join public.locations lt on lt.id = t.to_location_id
  where t.status = 'shipped'
    and exists (select 1 from public.locations w
                where w.id in (t.from_location_id, t.to_location_id) and w.type = 'warehouse' and w.deleted_at is null)
    and (p_warehouse_id is null or t.from_location_id = p_warehouse_id or t.to_location_id = p_warehouse_id)
    and (p_after_id is null or (t.shipped_at, t.id) < (p_after_shipped_at, p_after_id))
  order by t.shipped_at desc, t.id desc
  limit greatest(1, least(coalesce(p_limit, 100), 500))
$$;

revoke execute on function public.warehouse_stock_by_variant(uuid) from public, anon;
revoke execute on function public.warehouse_reorder_list(uuid, integer, uuid, uuid) from public, anon;
revoke execute on function public.warehouse_transfers_in_transit(uuid, integer, timestamptz, uuid) from public, anon;
grant execute on function public.warehouse_stock_by_variant(uuid) to authenticated;
grant execute on function public.warehouse_reorder_list(uuid, integer, uuid, uuid) to authenticated;
grant execute on function public.warehouse_transfers_in_transit(uuid, integer, timestamptz, uuid) to authenticated;
