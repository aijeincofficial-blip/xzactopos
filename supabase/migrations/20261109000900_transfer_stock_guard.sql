-- F-13i finding: a transfer could take a warehouse below zero.
-- Shipping 500 units out of a warehouse that held 19 was accepted and left it at -481. Negative stock is accepted by design for
-- offline sales (the sale already happened), but a transfer is entered online by a person: shipping stock that is not there is a
-- mistake, and the other warehouse would receive goods that were never sent.
--
-- One BEFORE INSERT guard on stock_movements for type 'transfer_out', so every way of shipping is covered at the same place:
-- ship_transfer, create_transfer(ship now), and anything added later. It locks the origin's stock level row, so two shipments
-- racing for the last units cannot both pass, and refuses with hint `insufficient_stock` when the origin holds less than is sent.
-- Sales, write-offs, count corrections, receipts and transfer_in are not touched.
--
-- It is named so that it fires before the bin trigger (stock_movements_set_bin): the clearer "not enough stock" message wins over
-- "pick the items first" when both apply. The refusal rolls the whole call back, so a shipment with one short line moves nothing.

create or replace function public.guard_transfer_out_stock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_have numeric;
begin
  if new.type <> 'transfer_out' then
    return new;
  end if;

  -- lock the level row: concurrent shipments of the same product from the same place queue up here
  select s.qty_on_hand into v_have
  from public.stock_levels s
  where s.tenant_id = new.tenant_id and s.location_id = new.location_id and s.variant_id = new.variant_id
  for update;

  if coalesce(v_have, 0) + new.qty_delta < 0 then
    raise exception 'only % in stock, % needed', trim_scale(coalesce(v_have, 0)), trim_scale(-new.qty_delta)
      using errcode = '55000', hint = 'insufficient_stock';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_transfer_out_stock() from public, anon, authenticated;

create trigger stock_movements_guard_transfer_out
  before insert on public.stock_movements
  for each row execute function public.guard_transfer_out_stock();
