-- P8-15 E-wallet sale payments and e-wallet expenses name their wallet, so the wallet float moves (closes the P8-06 gap).
--   payments.wallet    nullable: gcash | maya | other; only on an `ewallet` payment; set once by op_record_sale
--   expenses.wallet    nullable: gcash | maya | other; only when paid_from = 'ewallet'; set once by op_record_expense
--   wallet_float       now also kept by AFTER triggers on payments (insert), sales (void), expenses (insert, void)
--   op_record_sale, op_record_expense, guard_expense_change, sync_pull_sales, sync_pull_expenses: re-created (additive)
--   op_void_sale, op_void_expense, sync_push, report_summary, sync_pull_service, day_close_server_expected: unchanged
--
-- Money model (base-currency centavos; "float" = the store's own money in that wallet, as in P8-06):
--   e-wallet sale payment of A into wallet W ..... float(W) + A   (the customer paid into the store's wallet; not cash)
--   that sale voided ............................. float(W) - A   (exactly the payments it added, nothing else)
--   expense paid_from ewallet of A from W ........ float(W) - A
--   that expense voided .......................... float(W) + A
--   no wallet named (rows before P8-15, older apps, wallet left out): accepted exactly as before, NO float movement.
--   Only ewallet payments move a float (a cash + ewallet sale moves it by the ewallet part only). The `load` wallet is the
--   prepaid-load float and is never a payment or expense wallet (invalid_value). A float may go below zero (flagged).
--   wallet_float.balance = sum of the signed float effects of: service entries not voided (P8-06) + ewallet payments with a
--   wallet of sales not voided + ewallet expenses with a wallet not voided. wallet_float.txn_count counts all three.
--   Cash, expected cash, day_close_server_expected, daily_sales_summary (cash / ewallet / utang by method) and
--   daily_expense_summary are unchanged: e-wallet money was never cash.
--
-- Timing: the float rows move inside the op's own subtransaction (plain AFTER triggers, not deferred), at the push's now(),
-- which is the `applied_at` the op returns. sync_pull_service reads `floats` in one statement at `server_time`, so the
-- P8-06 device rule (drop a local float effect once a balance with server_time >= applied_at is pulled) holds unchanged.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

alter table public.payments
  add column wallet text check (wallet in ('gcash', 'maya', 'other')),
  add constraint payments_wallet_ewallet_only check (wallet is null or method = 'ewallet');

comment on column public.payments.wallet is
  'The store wallet an ewallet payment went into (gcash | maya | other); null = not named (moves no float).';

alter table public.expenses
  add column wallet text check (wallet in ('gcash', 'maya', 'other')),
  add constraint expenses_wallet_ewallet_only check (wallet is null or paid_from = 'ewallet');

comment on column public.expenses.wallet is
  'The store wallet an ewallet expense was paid from (gcash | maya | other); null = not named (moves no float).';

-- payments stay append-only through reject_ledger_change (no column list). The expense guard lists its frozen columns:
-- re-created (from 20261108001200) with wallet among them.
create or replace function public.guard_expense_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_voiding boolean;
begin
  if tg_op = 'DELETE' then
    raise exception 'expenses is append-only' using errcode = '55000', hint = 'append_only';
  end if;
  if (new.id, new.tenant_id, new.location_id, new.client_op_id, new.amount, new.currency, new.category, new.note,
      new.paid_from, new.wallet, new.spent_at, new.created_at, new.deleted_at)
     is distinct from
     (old.id, old.tenant_id, old.location_id, old.client_op_id, old.amount, old.currency, old.category, old.note,
      old.paid_from, old.wallet, old.spent_at, old.created_at, old.deleted_at)
     or (new.created_by is distinct from old.created_by and new.created_by is not null)
     or (new.approved_by is distinct from old.approved_by and new.approved_by is not null) then
    raise exception 'expenses is append-only; only a void is allowed' using errcode = '55000', hint = 'append_only';
  end if;
  v_voiding := old.voided_at is null and new.voided_at is not null;
  if (new.voided_at is distinct from old.voided_at or new.void_reason is distinct from old.void_reason)
     and not v_voiding then
    raise exception 'an expense can be voided once and never un-voided' using errcode = '55000', hint = 'append_only';
  end if;
  if new.void_approved_by is distinct from old.void_approved_by and new.void_approved_by is not null and not v_voiding then
    raise exception 'the void approval is set only by the void' using errcode = '55000', hint = 'append_only';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_expense_change() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Float maintenance
-- ---------------------------------------------------------------------------

-- Moves one wallet's float by p_delta and its entry count by p_count (same upsert as rollup_service_txn).
create or replace function public.move_wallet_float(p_tenant uuid, p_location uuid, p_wallet text, p_delta bigint,
                                                    p_count int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.wallet_float as w (tenant_id, location_id, wallet, balance, txn_count, updated_at)
  values (p_tenant, p_location, p_wallet, p_delta, p_count, now())
  on conflict (location_id, wallet) do update set
    balance = w.balance + excluded.balance, txn_count = w.txn_count + excluded.txn_count, updated_at = now();
end;
$$;

-- A new ewallet payment with a wallet adds to that float (only while its sale counts; a sale is always completed when its
-- payments are written, the check only keeps the rule exact).
create or replace function public.trg_wallet_float_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.method = 'ewallet' and new.wallet is not null
     and exists (select 1 from public.sales s
                 where s.id = new.sale_id and s.tenant_id = new.tenant_id and s.status = 'completed') then
    perform public.move_wallet_float(new.tenant_id, new.location_id, new.wallet, new.amount, 1);
  end if;
  return null;
end;
$$;

-- A sale going completed -> voided takes every ewallet payment with a wallet back out of its float.
create or replace function public.trg_wallet_float_sale_void()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  p record;
begin
  if old.status = 'completed' and new.status = 'voided' then
    for p in select x.location_id, x.wallet, sum(x.amount)::bigint as amount, count(*)::int as n
             from public.payments x
             where x.sale_id = new.id and x.tenant_id = new.tenant_id and x.method = 'ewallet' and x.wallet is not null
             group by x.location_id, x.wallet loop
      perform public.move_wallet_float(new.tenant_id, p.location_id, p.wallet, -p.amount, -p.n);
    end loop;
  end if;
  return null;
end;
$$;

-- An ewallet expense with a wallet takes the money out of that float; its void puts it back.
create or replace function public.trg_wallet_float_expense()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.voided_at is null and new.paid_from = 'ewallet' and new.wallet is not null then
      perform public.move_wallet_float(new.tenant_id, new.location_id, new.wallet, -new.amount, 1);
    end if;
  elsif old.voided_at is null and new.voided_at is not null and old.paid_from = 'ewallet' and old.wallet is not null then
    perform public.move_wallet_float(old.tenant_id, old.location_id, old.wallet, old.amount, -1);
  end if;
  return null;
end;
$$;

revoke execute on function public.move_wallet_float(uuid, uuid, text, bigint, int) from public, anon, authenticated;
revoke execute on function public.trg_wallet_float_payment() from public, anon, authenticated;
revoke execute on function public.trg_wallet_float_sale_void() from public, anon, authenticated;
revoke execute on function public.trg_wallet_float_expense() from public, anon, authenticated;

create trigger payments_wallet_float after insert on public.payments
  for each row execute function public.trg_wallet_float_payment();
create trigger sales_wallet_float_void after update of status on public.sales
  for each row execute function public.trg_wallet_float_sale_void();
create trigger expenses_wallet_float_insert after insert on public.expenses
  for each row execute function public.trg_wallet_float_expense();
create trigger expenses_wallet_float_void after update of voided_at on public.expenses
  for each row execute function public.trg_wallet_float_expense();

-- ---------------------------------------------------------------------------
-- op_record_sale re-created (from 20261108000600, the only definition). The one change: each payment may carry
--   `wallet` (gcash | maya | other) on an `ewallet` payment; null / missing / "" = not named. Anything else
--   ('load', an unknown value, a wallet on a cash or utang payment) is refused with invalid_value, nothing written.
--   p = { id, local_no, location_id?, sold_at, discount?, subtotal?, total?, customer_id?,
--         items:    [ { variant_id, name?, qty, unit_price, unit_cost?, discount?, tax?, line_total? } ],
--         payments: [ { method: cash|utang|ewallet, amount, tendered?, reference?, wallet? } ] }
--   Audit meta unchanged ({ no, total, utang }): the wallets are on the payment rows.
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
      insert into public.customer_ledger (tenant_id, customer_id, kind, amount, sale_id, occurred_at, created_by)
      values (v_tenant, v_cust, 'charge', v_utang, v_sale, v_sold, auth.uid());
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
-- op_record_expense re-created (from 20261108001200, the newest definition). The one change: optional `wallet`
--   (gcash | maya | other), only with paid_from = 'ewallet'; null / missing / "" = not named. Anything else ('load', an
--   unknown value, a wallet on a cash expense) is refused with invalid_value, nothing written.
--   p = { id, amount, category, paid_from?, wallet?, note?, spent_at?, currency?, location_id?, approval_id? }
--   Audit meta gains `wallet` when one is named. Returns { expense_id, approved_by, applied_at }.
-- ---------------------------------------------------------------------------

create or replace function public.op_record_expense(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_replay   jsonb;
  v_loc      uuid;
  v_id       uuid;
  v_amt_txt  text;
  v_amt      bigint;
  v_cat      text;
  v_from     text;
  v_wallet   text;
  v_base     text;
  v_ccy      text;
  v_spent    timestamptz;
  v_appr     uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  -- spending the store's money: the owner, a store manager, or a store supervisor with an approval; never a cashier
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin') then
    raise exception 'not allowed to record expenses' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'expense must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'record_expense');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);

  v_id := (p ->> 'id')::uuid;
  if v_id is null then
    raise exception 'expense id is required' using errcode = '22023', hint = 'id_required';
  end if;

  -- whole centavos only: a JSON number or digit string, no fraction, no sign, no exponent
  v_amt_txt := p ->> 'amount';
  if not coalesce(jsonb_typeof(p -> 'amount') in ('number', 'string') and v_amt_txt ~ '^[0-9]{1,15}$', false) then
    raise exception 'amount must be whole centavos above zero' using errcode = '22023', hint = 'amount_invalid';
  end if;
  v_amt := v_amt_txt::bigint;
  if v_amt <= 0 then
    raise exception 'amount must be above zero' using errcode = '22023', hint = 'amount_invalid';
  end if;

  v_cat := p ->> 'category';
  if v_cat is null or v_cat not in ('stock_purchase', 'utilities', 'transport', 'wages', 'rent', 'other') then
    raise exception 'category is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_from := coalesce(p ->> 'paid_from', 'cash');
  if v_from not in ('cash', 'ewallet') then
    raise exception 'paid from is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_wallet := nullif(btrim(p ->> 'wallet'), '');
  if v_wallet is not null and (v_from <> 'ewallet' or v_wallet not in ('gcash', 'maya', 'other')) then
    raise exception 'wallet is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;

  select t.base_currency into v_base from public.tenants t where t.id = v_tenant;
  v_ccy := coalesce(upper(nullif(btrim(p ->> 'currency'), '')), v_base);
  if v_ccy is distinct from v_base then
    raise exception 'expenses are in the base currency' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_spent := coalesce((p ->> 'spent_at')::timestamptz, now());

  v_appr := public.authorize_expense_write(v_loc, 'record_expense', v_id, (p ->> 'approval_id')::uuid, p_op_id);

  begin
    -- the expenses_wallet_float_insert trigger moves the float of a named wallet
    insert into public.expenses (id, tenant_id, location_id, client_op_id, amount, currency, category, note,
                                 paid_from, wallet, spent_at, created_by, approved_by)
    values (v_id, v_tenant, v_loc, p_op_id, v_amt, v_ccy, v_cat, left(nullif(btrim(p ->> 'note'), ''), 200),
            v_from, v_wallet, v_spent, auth.uid(), v_appr);
  exception when unique_violation then
    raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  perform public.write_audit('expense.record', 'expense', v_id, v_loc, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_loc, 'amount', v_amt, 'category', v_cat, 'paid_from', v_from, 'wallet', v_wallet,
    'op_id', p_op_id, 'approved_by', v_appr)));
  return public.finish_op(p_op_id, jsonb_build_object('expense_id', v_id, 'approved_by', v_appr, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_record_expense(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_sales re-created (from 20261108001000): each payment gains `wallet` (null when not named). Nothing else changes.
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
        'id', g.id, 'local_no', g.local_no, 'status', g.status, 'subtotal', g.subtotal, 'discount', g.discount,
        'tax', g.tax, 'total', g.total, 'customer_id', g.customer_id, 'sold_at', g.sold_at,
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

-- ---------------------------------------------------------------------------
-- sync_pull_expenses re-created (from 20261108001200): rows gain `wallet` (null when not named). Nothing else changes.
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_expenses(p_cursor jsonb default null, p_limit int default 100)
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
    select x.id, x.location_id, x.amount, x.currency, x.category, x.note, x.paid_from, x.wallet, x.spent_at, x.created_by,
           x.approved_by, x.voided_at, x.void_reason, x.void_approved_by, x.updated_at
    from public.expenses x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and (v_ts is null and x.spent_at >= now() - interval '30 days'
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'amount', g.amount, 'currency', g.currency,
        'category', g.category, 'note', g.note, 'paid_from', g.paid_from, 'wallet', g.wallet, 'spent_at', g.spent_at,
        'created_by', g.created_by, 'approved_by', g.approved_by, 'voided_at', g.voided_at,
        'void_reason', g.void_reason, 'void_approved_by', g.void_approved_by, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$$;

revoke execute on function public.sync_pull_expenses(jsonb, int) from public, anon;
grant execute on function public.sync_pull_expenses(jsonb, int) to authenticated;
