-- Card payment tender type support:
-- 1. payments.method check constraint widened to ('cash', 'utang', 'ewallet', 'card')
-- 2. daily_sales_summary adds `card` column
-- 3. rollup_sale tracks card payments into daily_sales_summary.card
-- 4. op_record_sale accepts 'card' payment method
-- 5. report_summary and report_multi_store return card sales in totals and days

-- 1. Check constraint on payments table
alter table public.payments drop constraint payments_method_check;
alter table public.payments add constraint payments_method_check check (method in ('cash', 'utang', 'ewallet', 'card'));

-- 2. Add card column to daily_sales_summary
alter table public.daily_sales_summary add column if not exists card bigint not null default 0;

-- 3. Update rollup_sale to accumulate card payments
create or replace function public.rollup_sale(p_sale uuid, p_sign int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s    public.sales;
  v_tz text;
  v_day date;
begin
  select * into s from public.sales where id = p_sale;
  if not found then
    return;
  end if;
  select coalesce(t.timezone, 'UTC') into v_tz from public.tenants t where t.id = s.tenant_id;
  v_day := (s.sold_at at time zone v_tz)::date;

  insert into public.daily_sales_summary as d
    (tenant_id, location_id, day, gross, discount, net, tax, cogs, txn_count, cash, ewallet, card, utang, updated_at)
  select s.tenant_id, s.location_id, v_day,
         p_sign * s.subtotal, p_sign * s.discount, p_sign * s.total, p_sign * s.tax,
         p_sign * coalesce((select sum(round(i.unit_cost * i.qty)) from public.sale_items i where i.sale_id = s.id), 0)::bigint,
         p_sign,
         p_sign * coalesce((select sum(p.amount) from public.payments p where p.sale_id = s.id and p.method = 'cash'), 0)::bigint,
         p_sign * coalesce((select sum(p.amount) from public.payments p where p.sale_id = s.id and p.method = 'ewallet'), 0)::bigint,
         p_sign * coalesce((select sum(p.amount) from public.payments p where p.sale_id = s.id and p.method = 'card'), 0)::bigint,
         p_sign * coalesce((select sum(p.amount) from public.payments p where p.sale_id = s.id and p.method = 'utang'), 0)::bigint,
         now()
  on conflict (location_id, day) do update set
    gross = d.gross + excluded.gross, discount = d.discount + excluded.discount, net = d.net + excluded.net,
    tax = d.tax + excluded.tax, cogs = d.cogs + excluded.cogs, txn_count = d.txn_count + excluded.txn_count,
    cash = d.cash + excluded.cash, ewallet = d.ewallet + excluded.ewallet, card = d.card + excluded.card, utang = d.utang + excluded.utang,
    updated_at = now();

  insert into public.daily_item_sales as d (tenant_id, location_id, day, variant_id, product_name, qty, revenue, cogs)
  select s.tenant_id, s.location_id, v_day, i.variant_id, max(i.product_name),
         p_sign * sum(i.qty), p_sign * sum(i.line_total)::bigint, p_sign * sum(round(i.unit_cost * i.qty))::bigint
  from public.sale_items i
  where i.sale_id = s.id
  group by i.variant_id
  on conflict (location_id, day, variant_id) do update set
    qty = d.qty + excluded.qty, revenue = d.revenue + excluded.revenue, cogs = d.cogs + excluded.cogs,
    product_name = excluded.product_name;
end;
$$;

revoke execute on function public.rollup_sale(uuid, int) from public, anon, authenticated;

-- 4. Update op_record_sale to accept 'card' tender
create or replace function public.op_record_sale(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant       uuid;
  v_replay       jsonb;
  v_loc          uuid;
  v_sale         uuid;
  v_no           text;
  v_sold         timestamptz;
  v_cust         uuid;
  v_disc         bigint;
  v_gross        bigint := 0;
  v_sub          bigint := 0;
  v_total        bigint;
  v_total_disc   bigint := 0;
  v_max_disc_pct smallint;
  v_tax          bigint := 0;
  v_paid         bigint := 0;
  v_utang        bigint := 0;
  it             jsonb;
  pay            jsonb;
  v_vid          uuid;
  v_qty          numeric;
  v_price        bigint;
  v_idisc        bigint;
  v_itax         bigint;
  v_line         bigint;
  v_cost         bigint;
  v_track        boolean;
  v_pname        text;
  v_method       text;
  v_amt          bigint;
  v_tend         bigint;
  v_wallet       text;
  v_con          text;
  v_device       uuid;
  v_sale_no      text;
  v_appr         uuid := null;
begin
  perform public.assert_seller();
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object'
     or jsonb_typeof(p -> 'items') is distinct from 'array'
     or jsonb_typeof(coalesce(p -> 'payments', '[]'::jsonb)) is distinct from 'array' then
    raise exception 'sale must be an object with items' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'record_sale');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);
  v_sale := (p ->> 'id')::uuid;
  v_no := btrim(p ->> 'local_no');
  v_sold := coalesce((p ->> 'sold_at')::timestamptz, now());
  v_cust := (p ->> 'customer_id')::uuid;
  v_disc := coalesce((p ->> 'discount')::bigint, 0);
  if v_sale is null then
    raise exception 'sale id is required' using errcode = '22023', hint = 'id_required';
  end if;
  if v_no is null or length(v_no) not between 3 and 40 then
    raise exception 'receipt number is required' using errcode = '22023', hint = 'invalid_value';
  end if;
  if jsonb_array_length(p -> 'items') not between 1 and 200 then
    raise exception 'a sale needs 1 to 200 items' using errcode = '22023', hint = 'items_required';
  end if;

  -- pass 1: validate lines and add up
  for it in select * from jsonb_array_elements(p -> 'items') loop
    v_qty := (it ->> 'qty')::numeric;
    v_price := (it ->> 'unit_price')::bigint;
    v_idisc := coalesce((it ->> 'discount')::bigint, 0);
    v_itax := coalesce((it ->> 'tax')::bigint, 0);
    if v_qty is null or v_qty <= 0 or v_qty >= 1000000000 then
      raise exception 'quantity must be above zero' using errcode = '22023', hint = 'qty_invalid';
    end if;
    if v_price is null or v_price < 0 then
      raise exception 'price is invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    v_line := round(v_qty * v_price)::bigint - v_idisc;
    if v_line < 0 or v_idisc < 0 or v_itax < 0 or v_itax > v_line then
      raise exception 'line amounts are invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    if it ? 'line_total' and (it ->> 'line_total')::bigint <> v_line then
      raise exception 'line total does not match' using errcode = '22023', hint = 'totals_mismatch';
    end if;
    v_gross := v_gross + round(v_qty * v_price)::bigint;
    v_sub := v_sub + v_line;
    v_tax := v_tax + v_itax;
  end loop;

  v_total := v_sub - v_disc;
  if v_disc < 0 or v_disc > v_sub then
    raise exception 'discount is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;
  if (p ? 'subtotal' and (p ->> 'subtotal')::bigint <> v_sub)
     or (p ? 'total' and (p ->> 'total')::bigint <> v_total) then
    raise exception 'totals do not match' using errcode = '22023', hint = 'totals_mismatch';
  end if;

  -- Cashier discount threshold check
  v_total_disc := v_gross - v_total;
  select max_cashier_discount_percent
    into v_max_disc_pct
    from public.tenant_settings
   where tenant_id = v_tenant;
  v_max_disc_pct := coalesce(v_max_disc_pct, 10);

  if public.auth_role() = 'cashier' and v_gross > 0 and (v_total_disc * 100 > v_gross * v_max_disc_pct) then
    v_appr := public.consume_supervisor_approval(v_loc, 'sale_discount', v_sale, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval');
  elsif (p ->> 'approval_id') is not null or (p -> 'offline_approval') is not null then
    v_appr := public.consume_supervisor_approval(v_loc, 'sale_discount', v_sale, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval');
  end if;

  -- payments must cover the total exactly (change is not a payment); a wallet only on an ewallet payment
  for pay in select * from jsonb_array_elements(coalesce(p -> 'payments', '[]'::jsonb)) loop
    v_method := pay ->> 'method';
    v_amt := (pay ->> 'amount')::bigint;
    if v_method not in ('cash', 'utang', 'ewallet', 'card') or v_amt is null or v_amt <= 0 then
      raise exception 'payment is invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    v_wallet := nullif(btrim(pay ->> 'wallet'), '');
    if v_wallet is not null and (v_method <> 'ewallet' or v_wallet not in ('gcash', 'maya', 'other')) then
      raise exception 'payment wallet is invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    v_paid := v_paid + v_amt;
    if v_method = 'utang' then
      v_utang := v_utang + v_amt;
    end if;
  end loop;
  if v_paid <> v_total then
    raise exception 'payments do not cover the total' using errcode = '22023', hint = 'payments_mismatch';
  end if;
  if v_utang > 0 then
    if v_cust is null then
      raise exception 'utang needs a customer' using errcode = '22023', hint = 'customer_required';
    end if;
    if not exists (select 1 from public.customers c where c.id = v_cust and c.tenant_id = v_tenant) then
      raise exception 'unknown customer' using errcode = '22023', hint = 'unknown_customer';
    end if;
  end if;

  -- F-02: the device (never refuses the sale)
  v_device := public.sale_device(p ->> 'device_id');

  begin
    -- F-02: the server number, in the same block as the insert so a refused sale gives it back
    v_sale_no := public.next_sale_no(v_tenant, v_loc, v_sold);

    insert into public.sales (id, tenant_id, location_id, local_no, subtotal, discount, tax, total,
                              customer_id, sold_at, created_by, device_id, sale_no)
    values (v_sale, v_tenant, v_loc, v_no, v_sub, v_disc, v_tax, v_total, v_cust, v_sold, auth.uid(), v_device, v_sale_no);

    for it in select * from jsonb_array_elements(p -> 'items') loop
      v_vid := (it ->> 'variant_id')::uuid;
      v_qty := (it ->> 'qty')::numeric;
      v_price := (it ->> 'unit_price')::bigint;
      v_idisc := coalesce((it ->> 'discount')::bigint, 0);
      v_itax := coalesce((it ->> 'tax')::bigint, 0);
      v_line := round(v_qty * v_price)::bigint - v_idisc;

      select v.cost, pr.track_stock, pr.name into v_cost, v_track, v_pname
      from public.product_variants v
      join public.products pr on pr.tenant_id = v.tenant_id and pr.id = v.product_id
      where v.id = v_vid and v.tenant_id = v_tenant;
      if not found then
        raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
      end if;
      v_cost := coalesce((it ->> 'unit_cost')::bigint, v_cost);

      insert into public.sale_items (tenant_id, sale_id, location_id, variant_id, product_name, qty,
                                     unit_price, unit_cost, discount, tax, line_total)
      values (v_tenant, v_sale, v_loc, v_vid, left(coalesce(nullif(btrim(it ->> 'name'), ''), v_pname), 120), v_qty,
              v_price, v_cost, v_idisc, v_itax, v_line);

      if v_track then
        insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id,
                                            unit_cost, occurred_at, created_by)
        values (v_tenant, v_loc, v_vid, -v_qty, 'sale', 'sale', v_sale, v_cost, v_sold, auth.uid());
      end if;
    end loop;

    for pay in select * from jsonb_array_elements(coalesce(p -> 'payments', '[]'::jsonb)) loop
      v_method := pay ->> 'method';
      v_amt := (pay ->> 'amount')::bigint;
      v_tend := case when v_method = 'cash' then coalesce((pay ->> 'tendered')::bigint, v_amt) end;
      v_wallet := nullif(btrim(pay ->> 'wallet'), '');
      -- the payments_wallet_float trigger moves the float of a named wallet
      insert into public.payments (tenant_id, sale_id, location_id, method, amount, tendered, reference, wallet)
      values (v_tenant, v_sale, v_loc, v_method, v_amt, v_tend, left(nullif(btrim(pay ->> 'reference'), ''), 64), v_wallet);
    end loop;

    if v_utang > 0 then
      -- F-01: the charge belongs to the sale's store
      insert into public.customer_ledger (tenant_id, customer_id, kind, amount, sale_id, occurred_at, created_by, location_id)
      values (v_tenant, v_cust, 'charge', v_utang, v_sale, v_sold, auth.uid(), v_loc);
    end if;
  exception
    when unique_violation then
      get stacked diagnostics v_con = constraint_name;
      if v_con in ('sales_local_no_per_tenant', 'sales_local_no_per_device') then
        raise exception 'receipt number already used' using errcode = '23505', hint = 'duplicate_local_no';
      end if;
      raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  perform public.write_audit('sale.create', 'sale', v_sale, v_loc,
    jsonb_strip_nulls(jsonb_build_object('no', v_no, 'total', v_total, 'utang', v_utang, 'approved_by', v_appr)));

  return public.finish_op(p_op_id, jsonb_build_object(
    'sale_id', v_sale, 'local_no', v_no, 'sale_no', v_sale_no, 'device_id', v_device, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_record_sale(uuid, jsonb) from public, anon, authenticated;

-- 5. Update report_summary to include card totals and daily card sales
create or replace function public.report_summary(p_from date, p_to date)
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

  select coalesce(jsonb_agg(to_jsonb(x) order by x.day), '[]'::jsonb) into v_days from (
    select d.day, sum(d.net)::bigint as net, sum(d.gross)::bigint as gross, sum(d.discount)::bigint as discount,
           sum(d.cogs)::bigint as cogs, sum(d.txn_count)::int as txns,
           sum(d.cash)::bigint as cash, sum(d.ewallet)::bigint as ewallet, sum(d.card)::bigint as card, sum(d.utang)::bigint as utang
    from public.daily_sales_summary d
    where d.tenant_id = v_tenant and d.day between p_from and p_to
    group by d.day
  ) x;

  select jsonb_build_object(
    'net', coalesce(sum(d.net), 0), 'gross', coalesce(sum(d.gross), 0), 'discount', coalesce(sum(d.discount), 0),
    'cogs', coalesce(sum(d.cogs), 0), 'txns', coalesce(sum(d.txn_count), 0),
    'cash', coalesce(sum(d.cash), 0), 'ewallet', coalesce(sum(d.ewallet), 0), 'card', coalesce(sum(d.card), 0), 'utang', coalesce(sum(d.utang), 0))
  into v_totals
  from public.daily_sales_summary d
  where d.tenant_id = v_tenant and d.day between p_from and p_to;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc, x.name), '[]'::jsonb) into v_top from (
    select i.variant_id, max(i.product_name) as name, sum(i.qty) as qty, sum(i.revenue)::bigint as revenue
    from public.daily_item_sales i
    where i.tenant_id = v_tenant and i.day between p_from and p_to
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
    where c.tenant_id = v_tenant and c.deleted_at is null
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
            where e2.tenant_id = v_tenant and e2.day between p_from and p_to
            group by e2.category
            having sum(e2.entry_count) > 0) c), '[]'::jsonb),
    'days', coalesce((
      select jsonb_agg(jsonb_build_object('day', dd.day, 'amount', dd.amount) order by dd.day)
      from (select e3.day, sum(e3.amount)::bigint as amount
            from public.daily_expense_summary e3
            where e3.tenant_id = v_tenant and e3.day between p_from and p_to
            group by e3.day
            having sum(e3.entry_count) > 0) dd), '[]'::jsonb))
  into v_exp
  from public.daily_expense_summary e
  where e.tenant_id = v_tenant and e.day between p_from and p_to;

  select jsonb_build_object(
    'count', coalesce(sum(s.txn_count) filter (where s.kind in ('cash_in', 'cash_out', 'load')), 0),
    'fee_total', coalesce(sum(s.fee), 0),
    'by_kind', coalesce((
      select jsonb_agg(jsonb_build_object('kind', k.kind, 'count', k.n, 'amount', k.amount, 'fee', k.fee)
                       order by array_position(v_kinds, k.kind))
      from (select s2.kind, sum(s2.txn_count)::int as n, sum(s2.amount)::bigint as amount, sum(s2.fee)::bigint as fee
            from public.daily_service_summary s2
            where s2.tenant_id = v_tenant and s2.day between p_from and p_to
            group by s2.kind
            having sum(s2.txn_count) > 0) k), '[]'::jsonb),
    'float', coalesce((
      select jsonb_agg(jsonb_build_object('wallet', f.wallet, 'balance', f.balance) order by array_position(v_wals, f.wallet))
      from (select w.wallet, sum(w.balance)::bigint as balance
            from public.wallet_float w
            where w.tenant_id = v_tenant
            group by w.wallet) f), '[]'::jsonb))
  into v_svc
  from public.daily_service_summary s
  where s.tenant_id = v_tenant and s.day between p_from and p_to;

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
  );
end;
$$;

revoke execute on function public.report_summary(date, date) from public, anon;
grant execute on function public.report_summary(date, date) to authenticated;

-- 6. Update report_multi_store to include card sales in totals and days
create or replace function public.report_multi_store(
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
  v_tenant          uuid := public.auth_tenant_id();
  v_days            jsonb;
  v_totals          jsonb;
  v_top             jsonb;
  v_stores          jsonb;
  v_stock_valuation jsonb;
  v_transfers       jsonb;
  v_exp             jsonb;
  v_svc             jsonb;
  v_utang           jsonb;
  v_kinds           text[] := array['cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust'];
  v_wals            text[] := array['gcash', 'maya', 'load', 'other'];
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

  -- 1. Daily breakdown
  select coalesce(jsonb_agg(to_jsonb(x) order by x.day), '[]'::jsonb) into v_days from (
    select d.day,
           sum(d.net)::bigint as net,
           sum(d.gross)::bigint as gross,
           sum(d.discount)::bigint as discount,
           sum(d.tax)::bigint as tax,
           sum(d.cogs)::bigint as cogs,
           sum(d.txn_count)::int as txns,
           sum(d.cash)::bigint as cash,
           sum(d.ewallet)::bigint as ewallet,
           sum(d.card)::bigint as card,
           sum(d.utang)::bigint as utang,
           sum(d.net - d.cogs)::bigint as profit
    from public.daily_sales_summary d
    where d.tenant_id = v_tenant
      and d.day between p_from and p_to
      and (p_location_id is null or d.location_id = p_location_id)
    group by d.day
  ) x;

  -- 2. Period totals
  select jsonb_build_object(
    'net', coalesce(sum(d.net), 0),
    'gross', coalesce(sum(d.gross), 0),
    'discount', coalesce(sum(d.discount), 0),
    'tax', coalesce(sum(d.tax), 0),
    'cogs', coalesce(sum(d.cogs), 0),
    'txns', coalesce(sum(d.txn_count), 0),
    'cash', coalesce(sum(d.cash), 0),
    'ewallet', coalesce(sum(d.ewallet), 0),
    'card', coalesce(sum(d.card), 0),
    'utang', coalesce(sum(d.utang), 0),
    'profit', coalesce(sum(d.net - d.cogs), 0),
    'margin_percent', case when coalesce(sum(d.net), 0) > 0
      then round(((sum(d.net) - sum(d.cogs))::numeric / sum(d.net)::numeric) * 100, 2)
      else 0 end
  )
  into v_totals
  from public.daily_sales_summary d
  where d.tenant_id = v_tenant
    and d.day between p_from and p_to
    and (p_location_id is null or d.location_id = p_location_id);

  -- 3. Top selling items
  select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc, x.name), '[]'::jsonb) into v_top from (
    select i.variant_id,
           max(i.product_name) as name,
           coalesce(pv.sku, '') as sku,
           sum(i.qty) as qty,
           sum(i.revenue)::bigint as revenue,
           sum(i.cogs)::bigint as cogs,
           sum(i.revenue - i.cogs)::bigint as profit
    from public.daily_item_sales i
    left join public.product_variants pv on pv.id = i.variant_id and pv.tenant_id = v_tenant
    where i.tenant_id = v_tenant
      and i.day between p_from and p_to
      and (p_location_id is null or i.location_id = p_location_id)
    group by i.variant_id, pv.sku
    having sum(i.qty) > 0
    order by sum(i.revenue) desc, max(i.product_name)
    limit 20
  ) x;

  -- 4. Per-store comparison breakdown
  select coalesce(jsonb_agg(to_jsonb(x) order by x.code), '[]'::jsonb) into v_stores from (
    select l.id as location_id,
           l.code,
           l.name,
           l.type,
           coalesce(sum(d.net), 0)::bigint as net,
           coalesce(sum(d.gross), 0)::bigint as gross,
           coalesce(sum(d.cogs), 0)::bigint as cogs,
           coalesce(sum(d.txn_count), 0)::int as txns,
           coalesce(sum(d.net - d.cogs), 0)::bigint as profit,
           coalesce((
             select sum(round(sl.qty_on_hand * sl.avg_cost))::bigint
             from public.stock_levels sl
             where sl.location_id = l.id and sl.tenant_id = v_tenant
           ), 0)::bigint as stock_value,
           coalesce((
             select sum(sl.qty_on_hand)::numeric(14, 3)
             from public.stock_levels sl
             where sl.location_id = l.id and sl.tenant_id = v_tenant
           ), 0)::numeric(14, 3) as stock_units
    from public.locations l
    left join public.daily_sales_summary d
      on d.location_id = l.id and d.tenant_id = v_tenant and d.day between p_from and p_to
    where l.tenant_id = v_tenant and l.active and l.deleted_at is null
      and (p_location_id is null or l.id = p_location_id)
      and (
        (select public.is_superadmin())
        or l.id = any ((select public.auth_location_ids())::uuid[])
      )
    group by l.id, l.code, l.name, l.type
  ) x;

  -- 5. Stock valuation summary
  select jsonb_build_object(
    'total_value', coalesce(sum(round(sl.qty_on_hand * sl.avg_cost)), 0)::bigint,
    'total_units', coalesce(sum(sl.qty_on_hand), 0)::numeric(14, 3),
    'items_count', count(distinct sl.variant_id)::int
  )
  into v_stock_valuation
  from public.stock_levels sl
  where sl.tenant_id = v_tenant
    and (p_location_id is null or sl.location_id = p_location_id)
    and (
      (select public.is_superadmin())
      or sl.location_id = any ((select public.auth_location_ids())::uuid[])
    );

  -- 6. Transfers activity summary
  select jsonb_build_object(
    'total_transfers', count(*)::int,
    'shipped_count', count(*) filter (where t.status = 'shipped')::int,
    'received_count', count(*) filter (where t.status = 'received')::int,
    'discrepancy_count', count(*) filter (where t.has_discrepancy)::int
  )
  into v_transfers
  from public.transfers t
  where t.tenant_id = v_tenant
    and (t.created_at at time zone coalesce((select timezone from public.tenants where id = v_tenant), 'Asia/Manila'))::date between p_from and p_to
    and (p_location_id is null or t.from_location_id = p_location_id or t.to_location_id = p_location_id)
    and (
      (select public.is_superadmin())
      or t.from_location_id = any ((select public.auth_location_ids())::uuid[])
      or t.to_location_id = any ((select public.auth_location_ids())::uuid[])
    );

  -- 7. Expenses summary
  select jsonb_build_object(
    'total', coalesce(sum(e.amount), 0),
    'cash', coalesce(sum(e.cash), 0),
    'ewallet', coalesce(sum(e.ewallet), 0),
    'count', coalesce(sum(e.entry_count), 0),
    'by_category', coalesce((
      select jsonb_agg(jsonb_build_object('category', c.category, 'amount', c.amount, 'count', c.n)
                       order by c.amount desc, c.category)
      from (select e2.category, sum(e2.amount)::bigint as amount, sum(e2.entry_count)::int as n
            from public.daily_expense_summary e2
            where e2.tenant_id = v_tenant and e2.day between p_from and p_to
              and (p_location_id is null or e2.location_id = p_location_id)
            group by e2.category
            having sum(e2.entry_count) > 0) c), '[]'::jsonb),
    'days', coalesce((
      select jsonb_agg(jsonb_build_object('day', dd.day, 'amount', dd.amount) order by dd.day)
      from (select e3.day, sum(e3.amount)::bigint as amount
            from public.daily_expense_summary e3
            where e3.tenant_id = v_tenant and e3.day between p_from and p_to
              and (p_location_id is null or e3.location_id = p_location_id)
            group by e3.day
            having sum(e3.entry_count) > 0) dd), '[]'::jsonb))
  into v_exp
  from public.daily_expense_summary e
  where e.tenant_id = v_tenant and e.day between p_from and p_to
    and (p_location_id is null or e.location_id = p_location_id);

  -- 8. Services summary
  select jsonb_build_object(
    'count', coalesce(sum(s.txn_count) filter (where s.kind in ('cash_in', 'cash_out', 'load')), 0),
    'fee_total', coalesce(sum(s.fee), 0),
    'by_kind', coalesce((
      select jsonb_agg(jsonb_build_object('kind', k.kind, 'count', k.n, 'amount', k.amount, 'fee', k.fee)
                       order by array_position(v_kinds, k.kind))
      from (select s2.kind, sum(s2.txn_count)::int as n, sum(s2.amount)::bigint as amount, sum(s2.fee)::bigint as fee
            from public.daily_service_summary s2
            where s2.tenant_id = v_tenant and s2.day between p_from and p_to
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
  where s.tenant_id = v_tenant and s.day between p_from and p_to
    and (p_location_id is null or s.location_id = p_location_id);

  -- 9. Utang summary
  select jsonb_build_object(
    'owed', coalesce(sum(b.balance) filter (where b.balance > 0), 0),
    'customers', coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name, 'balance', b.balance)
                          order by b.balance desc) filter (where b.balance > 0), '[]'::jsonb))
  into v_utang
  from (
    select c.id, c.name, sum(l.amount)::bigint as balance
    from public.customers c
    join public.customer_ledger l on l.customer_id = c.id and l.tenant_id = c.tenant_id
    where c.tenant_id = v_tenant and c.deleted_at is null
      and (p_location_id is null or l.location_id = p_location_id)
    group by c.id, c.name
  ) b;

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'location_id', p_location_id,
    'days', v_days,
    'totals', v_totals,
    'top_items', v_top,
    'stores', v_stores,
    'stock_valuation', v_stock_valuation,
    'transfers', v_transfers,
    'expenses', v_exp,
    'services', v_svc,
    'utang', v_utang,
    'server_time', now()
  );
end;
$$;

revoke execute on function public.report_multi_store(date, date, uuid) from public, anon;
grant execute on function public.report_multi_store(date, date, uuid) to authenticated;
