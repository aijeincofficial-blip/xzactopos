-- F-10 Per-branch report filtering for public.report_summary.
-- Adds optional p_location_id uuid default null parameter (matching report_multi_store)
-- while keeping 2-argument callers and default JSON keys backwards-compatible.

drop function if exists public.report_summary(date, date);

create or replace function public.report_summary(
  p_from        date,
  p_to          date,
  p_location_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_days   jsonb;
  v_totals jsonb;
  v_top    jsonb;
  v_utang  jsonb;
  v_exp    jsonb;
  v_svc    jsonb;
  v_kinds  text[] := array['cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust'];
  v_wals   text[] := array['gcash', 'maya', 'load', 'other'];
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then
    raise exception 'date range is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;

  if p_location_id is not null then
    if not (
      (select public.is_superadmin())
      or p_location_id = any ((select public.auth_location_ids())::uuid[])
    ) then
      raise exception 'access denied for location' using errcode = '42501', hint = 'forbidden';
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.day), '[]'::jsonb) into v_days from (
    select d.day, sum(d.net)::bigint as net, sum(d.gross)::bigint as gross, sum(d.discount)::bigint as discount,
           sum(d.cogs)::bigint as cogs, sum(d.txn_count)::int as txns,
           sum(d.cash)::bigint as cash, sum(d.ewallet)::bigint as ewallet, sum(d.card)::bigint as card, sum(d.utang)::bigint as utang
    from public.daily_sales_summary d
    where d.tenant_id = v_tenant
      and d.day between p_from and p_to
      and (p_location_id is null or d.location_id = p_location_id)
    group by d.day
  ) x;

  select jsonb_build_object(
    'net', coalesce(sum(d.net), 0), 'gross', coalesce(sum(d.gross), 0), 'discount', coalesce(sum(d.discount), 0),
    'cogs', coalesce(sum(d.cogs), 0), 'txns', coalesce(sum(d.txn_count), 0),
    'cash', coalesce(sum(d.cash), 0), 'ewallet', coalesce(sum(d.ewallet), 0), 'card', coalesce(sum(d.card), 0), 'utang', coalesce(sum(d.utang), 0))
  into v_totals
  from public.daily_sales_summary d
  where d.tenant_id = v_tenant
    and d.day between p_from and p_to
    and (p_location_id is null or d.location_id = p_location_id);

  select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc, x.name), '[]'::jsonb) into v_top from (
    select i.variant_id, max(i.product_name) as name, sum(i.qty) as qty, sum(i.revenue)::bigint as revenue
    from public.daily_item_sales i
    where i.tenant_id = v_tenant
      and i.day between p_from and p_to
      and (p_location_id is null or i.location_id = p_location_id)
    group by i.variant_id
    having sum(i.qty) > 0
    order by sum(i.revenue) desc, max(i.product_name)
    limit 10
  ) x;

  select jsonb_build_object(
    'owed', coalesce(sum(b.balance) filter (where b.balance > 0), 0),
    'customers', coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name, 'balance', b.balance)
                          order by b.balance desc) filter (where b.balance > 0), '[]'::jsonb))
  into v_utang
  from (
    select c.id, c.name, sum(l.amount)::bigint as balance
    from public.customers c
    join public.customer_ledger l on l.customer_id = c.id and l.tenant_id = c.tenant_id
    where c.tenant_id = v_tenant
      and c.deleted_at is null
      and (p_location_id is null or l.location_id = p_location_id)
    group by c.id, c.name
  ) b;

  select jsonb_build_object(
    'total', coalesce(sum(e.amount), 0), 'cash', coalesce(sum(e.cash), 0), 'ewallet', coalesce(sum(e.ewallet), 0),
    'count', coalesce(sum(e.entry_count), 0),
    'by_category', coalesce((
      select jsonb_agg(jsonb_build_object('category', c.category, 'amount', c.amount, 'count', c.n)
                       order by c.amount desc, c.category)
      from (select e2.category, sum(e2.amount)::bigint as amount, sum(e2.entry_count)::int as n
            from public.daily_expense_summary e2
            where e2.tenant_id = v_tenant
              and e2.day between p_from and p_to
              and (p_location_id is null or e2.location_id = p_location_id)
            group by e2.category
            having sum(e2.entry_count) > 0) c), '[]'::jsonb),
    'days', coalesce((
      select jsonb_agg(jsonb_build_object('day', dd.day, 'amount', dd.amount) order by dd.day)
      from (select e3.day, sum(e3.amount)::bigint as amount
            from public.daily_expense_summary e3
            where e3.tenant_id = v_tenant
              and e3.day between p_from and p_to
              and (p_location_id is null or e3.location_id = p_location_id)
            group by e3.day
            having sum(e3.entry_count) > 0) dd), '[]'::jsonb))
  into v_exp
  from public.daily_expense_summary e
  where e.tenant_id = v_tenant
    and e.day between p_from and p_to
    and (p_location_id is null or e.location_id = p_location_id);

  select jsonb_build_object(
    'count', coalesce(sum(s.txn_count) filter (where s.kind in ('cash_in', 'cash_out', 'load')), 0),
    'fee_total', coalesce(sum(s.fee), 0),
    'by_kind', coalesce((
      select jsonb_agg(jsonb_build_object('kind', k.kind, 'count', k.n, 'amount', k.amount, 'fee', k.fee)
                       order by array_position(v_kinds, k.kind))
      from (select s2.kind, sum(s2.txn_count)::int as n, sum(s2.amount)::bigint as amount, sum(s2.fee)::bigint as fee
            from public.daily_service_summary s2
            where s2.tenant_id = v_tenant
              and s2.day between p_from and p_to
              and (p_location_id is null or s2.location_id = p_location_id)
            group by s2.kind
            having sum(s2.txn_count) > 0) k), '[]'::jsonb),
    'float', coalesce((
      select jsonb_agg(jsonb_build_object('wallet', f.wallet, 'balance', f.balance) order by array_position(v_wals, f.wallet))
      from (select w.wallet, sum(w.balance)::bigint as balance
            from public.wallet_float w
            where w.tenant_id = v_tenant
              and (p_location_id is null or w.location_id = p_location_id)
            group by w.wallet) f), '[]'::jsonb))
  into v_svc
  from public.daily_service_summary s
  where s.tenant_id = v_tenant
    and s.day between p_from and p_to
    and (p_location_id is null or s.location_id = p_location_id);

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'totals', v_totals,
    'days', v_days,
    'top_items', v_top,
    'utang', v_utang,
    'expenses', v_exp,
    'services', v_svc,
    'server_time', now()
  ) || case
    when p_location_id is not null then jsonb_build_object('location_id', p_location_id)
    else '{}'::jsonb
  end;
end;
$$;

revoke execute on function public.report_summary(date, date, uuid) from public, anon;
grant execute on function public.report_summary(date, date, uuid) to authenticated;
