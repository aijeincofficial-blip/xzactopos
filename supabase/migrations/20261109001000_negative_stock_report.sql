-- Negative stock exceptions (plan report 11): where is stock below zero, and since when.
-- Negative stock is accepted by design when an offline sale (or a bin pick) already happened; this report is where someone sees it
-- and reconciles it. A transfer can no longer cause it (20261109000900).
--
-- Reconciling needs no state of its own: the stock is corrected (a receipt, a count, a transfer in) and the row leaves the list by
-- itself once the level is back at zero or above. If it drops again it is listed again.
--
-- Runs AS THE CALLER (security invoker) and writes nothing, so row-level security scopes it like the stock screens: the owner sees
-- every place, a warehouse clerk or a cashier only the places they are assigned to. Archived products and inactive or deleted
-- places are not listed. Keyset-paged, 1 to 500 rows per page, explicit columns.

create or replace function public.negative_stock_list(
  p_location_id    uuid default null,
  p_limit          integer default 200,
  p_after_location uuid default null,
  p_after_variant  uuid default null
)
returns table (
  location_id      uuid,
  location_code    text,
  location_type    text,
  variant_id       uuid,
  sku              text,
  product_name     text,
  qty_on_hand      numeric,
  avg_cost         bigint,
  stock_value      bigint,
  last_movement_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select s.location_id, l.code, l.type, s.variant_id, v.sku, p.name,
         s.qty_on_hand,
         s.avg_cost,
         case when s.avg_cost is null then null else round(s.qty_on_hand * s.avg_cost)::bigint end,
         (select max(m.created_at) from public.stock_movements m
          where m.tenant_id = s.tenant_id and m.location_id = s.location_id and m.variant_id = s.variant_id)
  from public.stock_levels s
  join public.locations l on l.id = s.location_id and l.active and l.deleted_at is null
  join public.product_variants v on v.id = s.variant_id and v.active and v.deleted_at is null
  join public.products p on p.id = v.product_id and p.tenant_id = v.tenant_id
  where s.qty_on_hand < 0
    and (p_location_id is null or s.location_id = p_location_id)
    and (p_after_location is null or (s.location_id, s.variant_id) > (p_after_location, p_after_variant))
  order by s.location_id, s.variant_id
  limit greatest(1, least(coalesce(p_limit, 200), 500))
$$;

revoke execute on function public.negative_stock_list(uuid, integer, uuid, uuid) from public, anon;
grant execute on function public.negative_stock_list(uuid, integer, uuid, uuid) to authenticated;
