-- Migration: 20261108002500_offline_pins_and_approvals.sql
-- F-06: Offline PIN unlock & material delivery, offline supervisor overrides validated on sync, and audit of refused ops.

-- 1. Dedicated RPC to deliver store approver & staff PIN material for offline verification
create or replace function public.pull_offline_pins(p_location_id uuid default null)
returns table (
  user_id    uuid,
  username   text,
  full_name  text,
  role       text,
  "position" text,
  pin_hash   text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_loc    uuid := p_location_id;
begin
  perform public.assert_active_user();

  if v_loc is null then
    v_loc := public.resolve_caller_store(v_loc);
  end if;

  if not public.is_superadmin() and not public.has_location_access(v_loc) then
    raise exception 'location access denied' using errcode = '42501', hint = 'location_denied';
  end if;

  return query
  select distinct
    p.user_id,
    p.username,
    p.full_name,
    p.role,
    la.position,
    p.pin_hash
  from public.profiles p
  left join public.location_access la
    on la.user_id = p.user_id
   and la.tenant_id = v_tenant
   and la.location_id = v_loc
   and la.deleted_at is null
  where p.tenant_id = v_tenant
    and p.active = true
    and p.deleted_at is null
    and p.pin_hash is not null
    and (
      p.role = 'superadmin'
      or la.user_id is not null
    )
  order by p.username;
end;
$$;

revoke execute on function public.pull_offline_pins(uuid) from public, anon;
grant execute on function public.pull_offline_pins(uuid) to authenticated;

-- 2. Enhanced consume_supervisor_approval: supports both online tokens and offline supervisor approvals
drop function if exists public.consume_supervisor_approval(uuid, text, uuid, uuid, uuid);

create or replace function public.consume_supervisor_approval(
  p_location_id      uuid,
  p_action           text,
  p_ref_id           uuid,
  p_approval_id      uuid,
  p_op_id            uuid,
  p_offline_approval jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  a             public.supervisor_approvals;
  v_approver    uuid;
  v_approved_at timestamptz;
  v_tenant      uuid := public.auth_tenant_id();
  v_hash        text;
begin
  -- Path A: Online approval token
  if p_approval_id is not null then
    select * into a from public.supervisor_approvals x
    where x.id = p_approval_id and x.tenant_id = v_tenant
    for update;

    if not found or a.requested_by is distinct from auth.uid() or a.location_id is distinct from p_location_id
       or a.action is distinct from p_action or a.ref_id is distinct from p_ref_id
       or not public.is_store_approver(a.approved_by, p_location_id) then
      raise exception 'approval does not match' using errcode = '42501', hint = 'approval_invalid';
    end if;

    if a.used_at is not null then
      raise exception 'approval already used' using errcode = '42501', hint = 'approval_used';
    end if;

    if a.expires_at <= now() then
      raise exception 'approval expired' using errcode = '42501', hint = 'approval_expired';
    end if;

    update public.supervisor_approvals set used_at = now(), used_op_id = p_op_id where id = a.id;
    return a.approved_by;
  end if;

  -- Path B: Offline supervisor override validated on sync
  if p_offline_approval is not null and jsonb_typeof(p_offline_approval) = 'object' then
    begin
      v_approver := (p_offline_approval ->> 'approver_id')::uuid;
      v_approved_at := coalesce((p_offline_approval ->> 'approved_at')::timestamptz, now());
    exception when others then
      raise exception 'invalid offline approval' using errcode = '22023', hint = 'approval_invalid';
    end;

    if v_approver is null then
      raise exception 'missing approver' using errcode = '22023', hint = 'approval_invalid';
    end if;

    -- Approver must exist, be active in this tenant, and have a configured PIN
    select p.pin_hash into v_hash from public.profiles p
    where p.user_id = v_approver and p.tenant_id = v_tenant and p.active = true and p.deleted_at is null;

    if v_hash is null then
      raise exception 'approver has no active PIN or is inactive' using errcode = '42501', hint = 'approval_invalid';
    end if;

    -- Approver must have supervisor/manager/owner authority for this location
    if not public.is_store_approver(v_approver, p_location_id) then
      raise exception 'approver not authorized for this location' using errcode = '42501', hint = 'approval_invalid';
    end if;

    -- Approver PIN must not be locked out (5 failed attempts within 15 min)
    if (select count(*) from public.audit_log l
        where l.tenant_id = v_tenant and l.action = 'pin.failed' and l.entity = 'profile' and l.entity_id = v_approver
          and l.created_at > now() - interval '15 minutes') >= 5 then
      raise exception 'approver PIN is locked' using errcode = '42501', hint = 'pin_locked';
    end if;

    -- Timestamp sanity: not in the future by > 10 min, not older than 7 days
    if v_approved_at > now() + interval '10 minutes' or v_approved_at < now() - interval '7 days' then
      raise exception 'offline approval timestamp expired or invalid' using errcode = '42501', hint = 'approval_expired';
    end if;

    -- Audit offline supervisor override
    perform public.write_audit(
      'approval.offline',
      'supervisor_approval',
      v_approver,
      p_location_id,
      jsonb_build_object(
        'action', p_action,
        'ref_id', p_ref_id,
        'op_id', p_op_id,
        'approved_at', v_approved_at,
        'requester_id', auth.uid()
      )
    );

    return v_approver;
  end if;

  raise exception 'a supervisor approval is required' using errcode = '42501', hint = 'approval_required';
end;
$$;

revoke execute on function public.consume_supervisor_approval(uuid, text, uuid, uuid, uuid, jsonb) from public, anon, authenticated;

-- 3. Update authorize_expense_write to accept offline approval
drop function if exists public.authorize_expense_write(uuid, text, uuid, uuid, uuid);

create or replace function public.authorize_expense_write(
  p_location_id      uuid,
  p_action           text,
  p_ref_id           uuid,
  p_approval_id      uuid,
  p_op_id            uuid,
  p_offline_approval jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_superadmin() or (public.auth_role() = 'admin' and public.has_location_access(p_location_id, 'manager')) then
    return null;
  end if;

  if public.auth_role() is distinct from 'admin' or not public.has_location_access(p_location_id, 'supervisor') then
    raise exception 'not allowed to manage expenses here' using errcode = '42501', hint = 'not_allowed';
  end if;

  return public.consume_supervisor_approval(p_location_id, p_action, p_ref_id, p_approval_id, p_op_id, p_offline_approval);
end;
$$;

revoke execute on function public.authorize_expense_write(uuid, text, uuid, uuid, uuid, jsonb) from public, anon, authenticated;

-- 4. Update op_record_expense to pass offline_approval
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

  v_id := coalesce((p ->> 'expense_id')::uuid, (p ->> 'id')::uuid);
  if v_id is null then
    raise exception 'expense id is required' using errcode = '22023', hint = 'id_required';
  end if;

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

  v_appr := public.authorize_expense_write(v_loc, 'record_expense', v_id, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval');

  begin
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

-- 5. Update op_void_expense to pass offline_approval
create or replace function public.op_void_expense(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_replay   jsonb;
  v_id       uuid;
  v_reason   text;
  v_exp      public.expenses;
  v_appr     uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin') then
    raise exception 'not allowed to void expenses' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'payload must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'void_expense');
  if v_replay is not null then
    return v_replay;
  end if;

  v_id := coalesce((p ->> 'expense_id')::uuid, (p ->> 'id')::uuid);
  if v_id is null then
    raise exception 'expense id is required' using errcode = '22023', hint = 'id_required';
  end if;
  v_reason := left(nullif(btrim(p ->> 'reason'), ''), 200);

  select * into v_exp from public.expenses
  where id = v_id and tenant_id = v_tenant for update;
  if not found then
    raise exception 'expense not found' using errcode = '22023', hint = 'expense_not_found';
  end if;

  v_appr := public.authorize_expense_write(v_exp.location_id, 'void_expense', v_id, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval');

  if v_exp.voided_at is not null then
    return public.finish_op(p_op_id, jsonb_build_object('expense_id', v_id, 'already', true, 'approved_by', v_appr, 'applied_at', now()));
  end if;

  update public.expenses
  set voided_at = now(),
      void_reason = v_reason,
      void_approved_by = v_appr
  where id = v_id;

  perform public.write_audit('expense.void', 'expense', v_id, v_exp.location_id, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_exp.location_id, 'amount', v_exp.amount, 'reason', v_reason,
    'op_id', p_op_id, 'approved_by', v_appr)));

  return public.finish_op(p_op_id, jsonb_build_object('expense_id', v_id, 'already', false, 'approved_by', v_appr, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_void_expense(uuid, jsonb) from public, anon, authenticated;

-- 6. Update op_record_sale to pass offline_approval
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

-- 7. Update op_void_sale with cashier void permissions and supervisor escalation
create or replace function public.op_void_sale(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant       uuid;
  v_replay       jsonb;
  v_sale         public.sales;
  v_sid          uuid;
  v_is_super     boolean;
  v_can_void_own boolean;
  v_max_void_amt bigint;
  v_tz           text;
  v_appr         uuid := null;
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

  -- Store assignment check
  if not public.has_location_access(v_sale.location_id) then
    raise exception 'not allowed to cancel sales here' using errcode = '42501', hint = 'not_allowed';
  end if;

  v_is_super := public.has_location_access(v_sale.location_id, 'supervisor');

  if not v_is_super then
    -- Non-supervisor: must be cashier
    if public.auth_role() is distinct from 'cashier' then
      raise exception 'not allowed to cancel sales here' using errcode = '42501', hint = 'not_allowed';
    end if;

    select cashier_can_void_own, max_cashier_void_amount
      into v_can_void_own, v_max_void_amt
      from public.tenant_settings
     where tenant_id = v_tenant;
    v_can_void_own := coalesce(v_can_void_own, false);
    v_max_void_amt := coalesce(v_max_void_amt, 50000);

    -- Cashier may only void own sales
    if v_sale.created_by is distinct from auth.uid() then
      raise exception 'cashier may only void own sales' using errcode = '42501', hint = 'not_allowed';
    end if;

    -- Cashier may only void same-day sales (in tenant's timezone)
    select timezone into v_tz from public.tenants where id = v_tenant;
    v_tz := coalesce(v_tz, 'Asia/Manila');
    if (v_sale.sold_at at time zone v_tz)::date <> (now() at time zone v_tz)::date then
      raise exception 'can only void sales from today' using errcode = '42501', hint = 'not_allowed';
    end if;

    -- If cashier cannot void on their own without approval, require approval
    if not v_can_void_own and (p ->> 'approval_id') is null and (p -> 'offline_approval') is null then
      raise exception 'not allowed to cancel sales here' using errcode = '42501', hint = 'not_allowed';
    end if;
  end if;

  if v_sale.status = 'voided' then
    return public.finish_op(p_op_id, jsonb_build_object('sale_id', v_sid, 'already', true, 'applied_at', now()));
  end if;

  -- Approval consumption
  if not v_is_super then
    if (not v_can_void_own) or (v_sale.total > v_max_void_amt) or (p ->> 'approval_id') is not null or (p -> 'offline_approval') is not null then
      v_appr := public.consume_supervisor_approval(v_sale.location_id, 'void_sale', v_sid, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval');
    end if;
  elsif (p ->> 'approval_id') is not null or (p -> 'offline_approval') is not null then
    v_appr := public.consume_supervisor_approval(v_sale.location_id, 'void_sale', v_sid, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval');
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
    jsonb_strip_nulls(jsonb_build_object('no', v_sale.local_no, 'total', v_sale.total, 'approved_by', v_appr)));

  return public.finish_op(p_op_id, jsonb_build_object('sale_id', v_sid, 'already', false, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_void_sale(uuid, jsonb) from public, anon, authenticated;

-- 8. Update sync_push to audit refused ops
create or replace function public.sync_push(p_ops jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o            jsonb;
  v_out        jsonb := '[]'::jsonb;
  v_id         uuid;
  v_kind       text;
  v_res        jsonb;
  v_state      text;
  v_hint       text;
  v_op_loc     uuid;
  v_audit_hint text;
begin
  perform public.assert_active_user();
  if jsonb_typeof(p_ops) is distinct from 'array' or jsonb_array_length(p_ops) not between 1 and 50 then
    raise exception 'send 1 to 50 ops' using errcode = '22023', hint = 'batch_invalid';
  end if;

  for o in select * from jsonb_array_elements(p_ops) loop
    begin
      v_id := (o ->> 'op_id')::uuid;
      v_kind := o ->> 'kind';
      v_res := case v_kind
        when 'record_sale'          then public.op_record_sale(v_id, o -> 'payload')
        when 'void_sale'            then public.op_void_sale(v_id, o -> 'payload')
        when 'upsert_customer'      then public.op_upsert_customer(v_id, o -> 'payload')
        when 'record_utang_payment' then public.op_record_utang_payment(v_id, o -> 'payload')
        when 'post_opening_stock'   then public.op_post_opening_stock(v_id, o -> 'payload')
        when 'receive_stock'        then public.op_receive_stock(v_id, o -> 'payload')
        when 'adjust_stock'         then public.op_adjust_stock(v_id, o -> 'payload')
        when 'adjust_utang'         then public.op_adjust_utang(v_id, o -> 'payload')
        when 'record_expense'       then public.op_record_expense(v_id, o -> 'payload')
        when 'void_expense'         then public.op_void_expense(v_id, o -> 'payload')
        when 'close_day'            then public.op_close_day(v_id, o -> 'payload')
        when 'record_service_txn'   then public.op_record_service_txn(v_id, o -> 'payload')
        when 'void_service_txn'     then public.op_void_service_txn(v_id, o -> 'payload')
        when 'set_tingi_link'       then public.op_set_tingi_link(v_id, o -> 'payload')
        when 'open_pack'            then public.op_open_pack(v_id, o -> 'payload')
        when 'void_open_pack'       then public.op_void_open_pack(v_id, o -> 'payload')
        when 'set_utang_due'        then public.op_set_utang_due(v_id, o -> 'payload')
        when 'set_expiry'           then public.op_set_expiry(v_id, o -> 'payload')
        else null
      end;
      if v_res is null then
        v_out := v_out || jsonb_build_object('op_id', v_id, 'status', 'rejected', 'hint', 'unknown_kind');
      else
        v_out := v_out || jsonb_build_object('op_id', v_id, 'status', 'ok', 'result', v_res);
      end if;
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      v_state := sqlstate;
      if v_state in ('40001', '40P01', '55P03', '57014', '53300', '53200', '08006') then
        -- transient: stop here so later ops are not applied before this one
        v_out := v_out || jsonb_build_object('op_id', v_id, 'status', 'error', 'code', v_state);
        return v_out;
      end if;

      v_audit_hint := coalesce(nullif(v_hint, ''), case v_state
        when '22P02' then 'invalid_value' when '22003' then 'invalid_value' when '22007' then 'invalid_value'
        when '23503' then 'unknown_reference' when '23514' then 'invalid_value'
        when '23505' then 'id_conflict' when '42501' then 'not_allowed'
        else 'rejected' end);

      -- Audit refused op
      begin
        if (o -> 'payload' ->> 'location_id') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
          v_op_loc := (o -> 'payload' ->> 'location_id')::uuid;
        else
          v_op_loc := null;
        end if;

        perform public.write_audit(
          'op.refused',
          coalesce(nullif(v_kind, ''), 'op'),
          v_id,
          v_op_loc,
          jsonb_build_object(
            'kind', v_kind,
            'code', v_state,
            'hint', v_audit_hint
          )
        );
      exception when others then
        null;
      end;

      v_out := v_out || jsonb_build_object(
        'op_id', v_id, 'status', 'rejected', 'code', v_state,
        'hint', v_audit_hint);
    end;
  end loop;

  return v_out;
end;
$$;

revoke execute on function public.sync_push(jsonb) from public, anon;
grant execute on function public.sync_push(jsonb) to authenticated;
