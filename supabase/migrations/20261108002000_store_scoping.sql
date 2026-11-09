-- F-01 Store scoping (server side). Full mode: a tenant may have several stores.
--
--   customer_ledger.location_id   nullable fk to locations (same tenant): the store where the entry happened
--   customer_ledger.method        'cash' | 'ewallet', default 'cash': how an utang PAYMENT was handed over. Only a payment may
--                                 be 'ewallet'; charges and adjustments always carry the default 'cash' (meaningless there).
--   Backfill (existing rows; the append-only guard is switched off for this one statement only):
--     rows tied to a sale (a charge, and the 'void' reversal of that charge) -> the sale's store;
--     every other row (payments, manual adjustments)                        -> the tenant's only store, or when it has
--       several, its first store (active stores first, then by code, created_at, id); null when the tenant has no store.
--     method = 'cash' for every existing row (before F-01 every utang payment was counted as cash).
--   op_record_sale        re-created (from 20261108001900): the utang charge row gets the sale's store. Nothing else changes;
--                         a missing location_id is still accepted when the user has exactly one store and refused with
--                         `location_required` otherwise (resolve_store, unchanged since 20261108000600).
--   op_void_sale          re-created (from 20261108000600): the reversal row gets the sale's store.
--   op_record_utang_payment re-created (from 20261108000600): p gains optional location_id (resolve_store: the user must have
--                         access to that store; missing = the user's only store, else `location_required`) and optional
--                         method (cash | ewallet, default cash; anything else `invalid_value`).
--   op_adjust_utang       re-created (from 20261108001000): p gains optional location_id (given: resolve_store; missing: the
--                         user's only store, else null; an adjustment is not cash, so several stores do not refuse it).
--   day_close_server_expected re-created (from 20261108001400): utang payments count only when method = 'cash' AND the payment
--                         was taken at the closing store.
--   sync_pull_pos         re-created (from 20261108001700): customer_ledger rows carry location_id and method (additive).
--   sync_pull_sales       re-created (from 20261108001900): sale rows carry location_id (additive), so a phone can show each
--                         store's sales only.
--   user_sole_store()     new internal helper: the caller's only active store, or null.
--   Unchanged: sync_push (no new op kind), RLS (customer_ledger stays tenant-wide for front-of-store roles: a customer's balance
--   is tenant-wide), audit rows, report_summary, every other op.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

alter table public.customer_ledger
  add column location_id uuid,
  add column method text not null default 'cash' check (method in ('cash', 'ewallet')),
  add constraint customer_ledger_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  add constraint customer_ledger_method_payment_only check (method = 'cash' or kind = 'payment');

comment on column public.customer_ledger.location_id is
  'The store where the entry happened (F-01). Null only for adjustments made without a store by a user with several stores.';
comment on column public.customer_ledger.method is
  'How an utang payment was handed over: cash (counts in the closing store''s drawer) or ewallet. Always cash on other kinds.';

create index customer_ledger_tenant_payment_idx on public.customer_ledger (tenant_id, location_id, occurred_at)
  where kind = 'payment';

-- ---------------------------------------------------------------------------
-- Backfill (rule in the header)
-- ---------------------------------------------------------------------------

-- The rule as a function, so pgTAP checks exactly what the migration ran. Internal; only for this backfill: it fills EVERY
-- row with no store, so it is not meant to be called again on live data (an adjustment made later without a store by a
-- user with several stores is null on purpose). The caller must switch the append-only guard off around it.
create or replace function public.customer_ledger_location_backfill()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  update public.customer_ledger l
     set location_id = f.loc
    from (select l2.id, coalesce(
            (select s.location_id from public.sales s where s.tenant_id = l2.tenant_id and s.id = l2.sale_id),
            (select x.id from public.locations x
             where x.tenant_id = l2.tenant_id and x.type = 'store' and x.deleted_at is null
             order by x.active desc, x.code, x.created_at, x.id
             limit 1)) as loc
          from public.customer_ledger l2
          where l2.location_id is null) f
   where l.id = f.id and f.loc is not null;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke execute on function public.customer_ledger_location_backfill() from public, anon, authenticated;

alter table public.customer_ledger disable trigger customer_ledger_append_only;
select public.customer_ledger_location_backfill();
alter table public.customer_ledger enable trigger customer_ledger_append_only;

-- ---------------------------------------------------------------------------
-- user_sole_store(): the caller's only active store, or null (none or several). Internal.
-- ---------------------------------------------------------------------------

create or replace function public.user_sole_store()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ids uuid[];
begin
  select array_agg(l.id) into v_ids
  from public.locations l
  where l.id = any (public.auth_location_ids()) and l.type = 'store' and l.active;
  if v_ids is null or cardinality(v_ids) <> 1 then
    return null;
  end if;
  return v_ids[1];
end;
$$;

revoke execute on function public.user_sole_store() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_record_sale re-created (from 20261108001900, the newest definition). The one change: the utang charge row carries the
-- sale's store (location_id). p, result, audit and every check are unchanged.
-- ---------------------------------------------------------------------------

create or replace function public.op_record_sale(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant  uuid;
  v_replay  jsonb;
  v_loc     uuid;
  v_sale    uuid;
  v_no      text;
  v_sold    timestamptz;
  v_cust    uuid;
  v_disc    bigint;
  v_sub     bigint := 0;
  v_total   bigint;
  v_tax     bigint := 0;
  v_paid    bigint := 0;
  v_utang   bigint := 0;
  it        jsonb;
  pay       jsonb;
  v_vid     uuid;
  v_qty     numeric;
  v_price   bigint;
  v_idisc   bigint;
  v_itax    bigint;
  v_line    bigint;
  v_cost    bigint;
  v_track   boolean;
  v_pname   text;
  v_method  text;
  v_amt     bigint;
  v_tend    bigint;
  v_wallet  text;
  v_con     text;
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

  -- payments must cover the total exactly (change is not a payment); a wallet only on an ewallet payment
  for pay in select * from jsonb_array_elements(coalesce(p -> 'payments', '[]'::jsonb)) loop
    v_method := pay ->> 'method';
    v_amt := (pay ->> 'amount')::bigint;
    if v_method not in ('cash', 'utang', 'ewallet') or v_amt is null or v_amt <= 0 then
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

  begin
    insert into public.sales (id, tenant_id, location_id, local_no, subtotal, discount, tax, total,
                              customer_id, sold_at, created_by)
    values (v_sale, v_tenant, v_loc, v_no, v_sub, v_disc, v_tax, v_total, v_cust, v_sold, auth.uid());

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
      if v_con = 'sales_local_no_per_tenant' then
        raise exception 'receipt number already used' using errcode = '23505', hint = 'duplicate_local_no';
      end if;
      raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  perform public.write_audit('sale.create', 'sale', v_sale, v_loc,
    jsonb_build_object('no', v_no, 'total', v_total, 'utang', v_utang));

  return public.finish_op(p_op_id, jsonb_build_object(
    'sale_id', v_sale, 'local_no', v_no, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_record_sale(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_void_sale re-created (from 20261108000600, the only definition). The one change: the reversal of the utang charge
-- carries the sale's store. p = { sale_id, reason? } (a location_id sent by the app is ignored: the sale names its store).
-- ---------------------------------------------------------------------------

create or replace function public.op_void_sale(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_sale   public.sales;
  v_sid    uuid;
begin
  perform public.assert_seller();
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'void must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'void_sale');
  if v_replay is not null then
    return v_replay;
  end if;

  v_sid := (p ->> 'sale_id')::uuid;
  select * into v_sale from public.sales where id = v_sid and tenant_id = v_tenant for update;
  if not found then
    raise exception 'sale not found' using errcode = '22023', hint = 'sale_not_found';
  end if;
  if not public.has_location_access(v_sale.location_id, 'supervisor') then
    raise exception 'not allowed to cancel sales here' using errcode = '42501', hint = 'not_allowed';
  end if;

  if v_sale.status = 'voided' then
    return public.finish_op(p_op_id, jsonb_build_object('sale_id', v_sid, 'already', true, 'applied_at', now()));
  end if;

  update public.sales
     set status = 'voided', voided_at = now(), void_reason = left(nullif(btrim(p ->> 'reason'), ''), 200)
   where id = v_sid;

  insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id,
                                      unit_cost, occurred_at, created_by)
  select m.tenant_id, m.location_id, m.variant_id, -m.qty_delta, 'sale_void', 'sale', v_sid,
         m.unit_cost, now(), auth.uid()
  from public.stock_movements m
  where m.tenant_id = v_tenant and m.ref_type = 'sale' and m.ref_id = v_sid and m.type = 'sale';

  insert into public.customer_ledger (tenant_id, customer_id, kind, amount, sale_id, note, occurred_at, created_by,
                                      location_id)
  select l.tenant_id, l.customer_id, 'adjust', -l.amount, v_sid, 'void', now(), auth.uid(), v_sale.location_id
  from public.customer_ledger l
  where l.tenant_id = v_tenant and l.sale_id = v_sid and l.kind = 'charge';

  perform public.write_audit('sale.void', 'sale', v_sid, v_sale.location_id,
    jsonb_build_object('no', v_sale.local_no, 'total', v_sale.total));

  return public.finish_op(p_op_id, jsonb_build_object('sale_id', v_sid, 'already', false, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_void_sale(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_record_utang_payment re-created (from 20261108000600, the only definition)
--   p = { customer_id, amount (positive), note?, occurred_at?, location_id?, method? }
--   location_id: the store that took the money; the user must have access to it (location_denied otherwise). Missing: the
--     user's only store; with several stores it is required (location_required).
--   method: cash (default) | ewallet; anything else invalid_value. Only cash payments count in that store's day close.
--   Overpaying is allowed here (the money was handed over; the ledger only records facts). Audit unchanged.
-- ---------------------------------------------------------------------------

create or replace function public.op_record_utang_payment(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_cust   uuid;
  v_amt    bigint;
  v_loc    uuid;
  v_method text;
begin
  perform public.assert_seller();
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'payment must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'record_utang_payment');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);
  v_method := coalesce(nullif(btrim(p ->> 'method'), ''), 'cash');
  if v_method not in ('cash', 'ewallet') then
    raise exception 'payment method is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_cust := (p ->> 'customer_id')::uuid;
  v_amt := (p ->> 'amount')::bigint;
  if v_amt is null or v_amt <= 0 then
    raise exception 'amount must be above zero' using errcode = '22023', hint = 'amount_invalid';
  end if;
  if not exists (select 1 from public.customers c where c.id = v_cust and c.tenant_id = v_tenant) then
    raise exception 'unknown customer' using errcode = '22023', hint = 'unknown_customer';
  end if;

  insert into public.customer_ledger (tenant_id, customer_id, kind, amount, note, occurred_at, created_by,
                                      location_id, method)
  values (v_tenant, v_cust, 'payment', -v_amt, left(nullif(btrim(p ->> 'note'), ''), 200),
          coalesce((p ->> 'occurred_at')::timestamptz, now()), auth.uid(), v_loc, v_method);

  perform public.write_audit('utang.payment', 'customer', v_cust, null, jsonb_build_object('amount', v_amt));
  return public.finish_op(p_op_id, jsonb_build_object('customer_id', v_cust, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_record_utang_payment(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_adjust_utang re-created (from 20261108001000, the only definition)
--   p = { customer_id, amount (signed, not 0), note?, occurred_at?, location_id? }
--   location_id given: resolve_store (access + a store). Missing: the user's only store, else null (not refused: an
--   adjustment moves no cash). Permission, audit and result unchanged.
-- ---------------------------------------------------------------------------

create or replace function public.op_adjust_utang(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_cust   uuid;
  v_amt    bigint;
  v_loc    uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  -- writing off or correcting a debt is the owner's (or a store manager's) call, not a cashier's
  if public.catalog_write_mode() is distinct from 'full' then
    raise exception 'not allowed to adjust utang' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'adjustment must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'adjust_utang');
  if v_replay is not null then
    return v_replay;
  end if;

  if nullif(p ->> 'location_id', '') is not null then
    v_loc := public.resolve_store((p ->> 'location_id')::uuid);
  else
    v_loc := public.user_sole_store();
  end if;
  v_cust := (p ->> 'customer_id')::uuid;
  v_amt := (p ->> 'amount')::bigint;
  if v_amt is null or v_amt = 0 then
    raise exception 'amount must not be zero' using errcode = '22023', hint = 'amount_invalid';
  end if;
  if not exists (select 1 from public.customers c where c.id = v_cust and c.tenant_id = v_tenant) then
    raise exception 'unknown customer' using errcode = '22023', hint = 'unknown_customer';
  end if;

  insert into public.customer_ledger (tenant_id, customer_id, kind, amount, note, occurred_at, created_by, location_id)
  values (v_tenant, v_cust, 'adjust', v_amt, left(nullif(btrim(p ->> 'note'), ''), 200),
          coalesce((p ->> 'occurred_at')::timestamptz, now()), auth.uid(), v_loc);

  perform public.write_audit('utang.adjust', 'customer', v_cust, null, jsonb_build_object('amount', v_amt));
  return public.finish_op(p_op_id, jsonb_build_object('customer_id', v_cust, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_adjust_utang(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- day_close_server_expected re-created (from 20261108001400, the newest definition). The one change: utang payments count
-- only when they were CASH and taken at the closing store (before F-01: every payment of the tenant, as cash).
-- ---------------------------------------------------------------------------

create or replace function public.day_close_server_expected(p_tenant uuid, p_location_id uuid, p_day date)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz    text;
  v_from  timestamptz;
  v_to    timestamptz;
  v_sales bigint;
  v_utang bigint;
  v_exp   bigint;
  v_svc   bigint;
begin
  select coalesce(t.timezone, 'UTC') into v_tz from public.tenants t where t.id = p_tenant;
  v_from := p_day::timestamp at time zone coalesce(v_tz, 'UTC');
  v_to   := (p_day + 1)::timestamp at time zone coalesce(v_tz, 'UTC');

  select coalesce(sum(p.amount), 0) into v_sales
  from public.sales s
  join public.payments p on p.sale_id = s.id and p.tenant_id = s.tenant_id
  where s.tenant_id = p_tenant and s.location_id = p_location_id and s.status = 'completed'
    and s.sold_at >= v_from and s.sold_at < v_to and p.method = 'cash';

  -- payments are stored negative; cash ones taken at this store only (F-01)
  select coalesce(-sum(l.amount), 0) into v_utang
  from public.customer_ledger l
  where l.tenant_id = p_tenant and l.kind = 'payment' and l.method = 'cash' and l.location_id = p_location_id
    and l.occurred_at >= v_from and l.occurred_at < v_to;

  select coalesce(sum(e.amount), 0) into v_exp
  from public.expenses e
  where e.tenant_id = p_tenant and e.location_id = p_location_id and e.voided_at is null and e.paid_from = 'cash'
    and e.spent_at >= v_from and e.spent_at < v_to;

  select coalesce(sum(d.cash), 0) into v_svc
  from public.daily_service_summary d
  where d.tenant_id = p_tenant and d.location_id = p_location_id and d.day = p_day;

  return v_sales + v_utang - v_exp + v_svc;
end;
$$;

revoke execute on function public.day_close_server_expected(uuid, uuid, date) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_pos re-created (from 20261108001700, the newest definition). The one change: customer_ledger rows carry
-- location_id and method (additive). Same sections, cursors and keyset rules.
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_pos(p_cursors jsonb default '{}'::jsonb, p_limit int default 500)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_upto   timestamptz := now() - interval '5 seconds';
  v_out    jsonb := jsonb_build_object('server_time', now());
  r        record;
  v_cur    jsonb;
  v_rows   jsonb;
  v_last   jsonb;
  v_more   boolean;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  if p_limit is null or p_limit not between 1 and 1000 then
    raise exception 'limit must be 1 to 1000' using errcode = '22023', hint = 'invalid_value';
  end if;

  for r in select * from (values
    ('stock_levels',    'location_id, variant_id, qty_on_hand, avg_cost, counted, updated_at',
                        'updated_at', 'location_id::text || ''|'' || variant_id::text'),
    ('customers',       'id, name, phone, due_on, updated_at, deleted_at',
                        'updated_at', 'id::text'),
    ('customer_ledger', 'id, customer_id, kind, amount, sale_id, note, occurred_at, created_at, location_id, method',
                        'created_at', 'id::text'),
    ('stock_expiry',    'location_id, variant_id, expires_on, updated_at',
                        'updated_at', 'location_id::text || ''|'' || variant_id::text')
  ) t(tbl, cols, tscol, keyexpr) loop
    v_cur := p_cursors -> r.tbl;

    execute format($q$
      with s as (
        select %2$s, %3$s as _k
        from public.%1$I
        where tenant_id = $1
          and %4$I <= $2
          and ($3::timestamptz is null or (%4$I, %3$s) > ($3::timestamptz, $4::text))
        order by %4$I, _k
        limit $5 + 1
      ), page as (
        select * from s order by %4$I, _k limit $5
      )
      select
        (select count(*) from s) > $5,
        coalesce((select jsonb_agg(to_jsonb(page) - '_k' order by page.%4$I, page._k) from page), '[]'::jsonb),
        (select jsonb_build_object('ts', page.%4$I, 'k', page._k) from page order by page.%4$I desc, page._k desc limit 1)
    $q$, r.tbl, r.cols, r.keyexpr, r.tscol)
    into v_more, v_rows, v_last
    using v_tenant, v_upto, v_cur ->> 'ts', v_cur ->> 'k', p_limit;

    v_out := v_out || jsonb_build_object(r.tbl, jsonb_build_object(
      'rows', v_rows,
      'cursor', coalesce(v_last, v_cur),
      'has_more', v_more));
  end loop;

  return v_out;
end;
$$;

revoke execute on function public.sync_pull_pos(jsonb, int) from public, anon;
grant execute on function public.sync_pull_pos(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_sales re-created (from 20261108001900, the newest definition). The one change: each sale row carries
-- location_id (additive). RLS (security invoker) still limits the rows to the caller's stores.
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_sales(p_cursor jsonb default null, p_limit int default 100)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_upto   timestamptz := now() - interval '5 seconds';
  v_ts     timestamptz := nullif(p_cursor ->> 'ts', '')::timestamptz;
  v_k      text := p_cursor ->> 'k';
  v_rows   jsonb;
  v_last   jsonb;
  v_more   boolean;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.*
    from public.sales x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and (v_ts is null and x.sold_at >= now() - interval '30 days'
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'local_no', g.local_no, 'status', g.status, 'subtotal', g.subtotal,
        'discount', g.discount, 'tax', g.tax, 'total', g.total, 'customer_id', g.customer_id, 'sold_at', g.sold_at,
        'voided_at', g.voided_at, 'void_reason', g.void_reason, 'updated_at', g.updated_at,
        'items', coalesce((select jsonb_agg(jsonb_build_object(
                    'variant_id', i.variant_id, 'name', i.product_name, 'qty', i.qty, 'unit_price', i.unit_price,
                    'unit_cost', i.unit_cost, 'discount', i.discount, 'tax', i.tax, 'line_total', i.line_total,
                    'tracked', coalesce(pr.track_stock, true)) order by i.created_at, i.id)
                  from public.sale_items i
                  left join public.product_variants v on v.id = i.variant_id and v.tenant_id = i.tenant_id
                  left join public.products pr on pr.id = v.product_id and pr.tenant_id = v.tenant_id
                  where i.sale_id = g.id), '[]'::jsonb),
        'payments', coalesce((select jsonb_agg(jsonb_build_object(
                    'method', p.method, 'amount', p.amount, 'tendered', p.tendered, 'reference', p.reference,
                    'wallet', p.wallet)
                    order by p.created_at, p.id)
                  from public.payments p where p.sale_id = g.id), '[]'::jsonb)
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$$;

revoke execute on function public.sync_pull_sales(jsonb, int) from public, anon;
grant execute on function public.sync_pull_sales(jsonb, int) to authenticated;
