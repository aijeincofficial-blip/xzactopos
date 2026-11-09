-- F-13h H2 addendum: the answer to a receipt carries the SERVER's time of the receipt (`applied_at`).
--
-- The phone keeps a queued receipt's effect on screen (stock up, order remaining down) until its own copy of the data has
-- caught up with the server. "Caught up" is judged against the server's clock, never the phone's: a phone with a wrong clock
-- must not drop the effect too early (the number would dip) or too late (it would count twice). Every other queued op kind
-- answers with `applied_at` for the same reason. A replay answers with the original time (received_at never changes).
--
-- Re-creates grn_result from 20261109000400 with one extra key. Callers that read the other keys are unaffected.

create or replace function public.grn_result(p_grn_id uuid, p_replay boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('grn_id', g.id, 'grn_no', g.grn_no, 'po_status', po.status,
                            'has_discrepancy', g.has_discrepancy, 'without_po', g.without_po,
                            'applied_at', g.received_at)
         || case when p_replay then jsonb_build_object('replay', true) else '{}'::jsonb end
  from public.goods_receipts g
  left join public.purchase_orders po on po.id = g.po_id and po.tenant_id = g.tenant_id
  where g.id = p_grn_id
$$;

revoke execute on function public.grn_result(uuid, boolean) from public, anon, authenticated;
