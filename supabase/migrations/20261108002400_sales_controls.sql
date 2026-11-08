-- ---------------------------------------------------------------------------
-- 20261108002400_sales_controls.sql
-- Card F-07: Sales Controls & Role-Based Permissions
-- Adds tenant settings for cashier discount and void thresholds, expands
-- supervisor approvals to 'void_sale' and 'sale_discount', and updates
-- op_record_sale and op_void_sale to enforce thresholds and PIN escalations.
-- ---------------------------------------------------------------------------

-- 1. Tenant settings: cashier discount and void thresholds
alter table public.tenant_settings
  add column max_cashier_discount_percent smallint not null default 10 check (max_cashier_discount_percent between 0 and 100),
  add column max_cashier_void_amount bigint not null default 50000 check (max_cashier_void_amount >= 0),
  add column cashier_can_void_own boolean not null default false;

comment on column public.tenant_settings.max_cashier_discount_percent is
  'Maximum total discount percentage (0-100) a cashier may apply without supervisor PIN approval.';
comment on column public.tenant_settings.max_cashier_void_amount is
  'Maximum sale total (in minor units) a cashier may void without supervisor PIN approval (when cashier_can_void_own is true).';
comment on column public.tenant_settings.cashier_can_void_own is
  'Whether cashiers may void their own same-day sales below max_cashier_void_amount without supervisor PIN approval.';

grant update (default_locale, locales, offline_session_days, receipt_header, receipt_footer,
              max_cashier_discount_percent, max_cashier_void_amount, cashier_can_void_own)
  on public.tenant_settings to authenticated;

-- 2. Expand supervisor approvals actions to include 'void_sale' and 'sale_discount'
alter table public.supervisor_approvals drop constraint supervisor_approvals_action_check;
alter table public.supervisor_approvals add constraint supervisor_approvals_action_check
  check (action in ('record_expense', 'void_expense', 'close_day', 'record_service_txn', 'void_service_txn', 'void_sale', 'sale_discount'));

-- 3. Helper to consume a supervisor approval inside ops
create or replace function public.consume_supervisor_approval(
  p_location_id uuid,
  p_action      text,
  p_ref_id      uuid,
  p_approval_id uuid,
  p_op_id       uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.supervisor_approvals;
begin
  if p_approval_id is null then
    raise exception 'a supervisor approval is required' using errcode = '42501', hint = 'approval_required';
  end if;

  select * into a from public.supervisor_approvals x
  where x.id = p_approval_id and x.tenant_id = public.auth_tenant_id()
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
end;
$$;

revoke execute on function public.consume_supervisor_approval(uuid, text, uuid, uuid, uuid) from public, anon, authenticated;

-- 4. Update approve_supervisor_action to allow cashiers to ask for 'sale_discount' and 'void_sale'
create or replace function public.approve_supervisor_action(
  p_action      text,
  p_ref_id      uuid,
  p_pin         text,
  p_location_id uuid default null,
  p_approver_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_loc      uuid;
  v_approver uuid;
  v_try      text;
  v_id       uuid;
  v_exp      timestamptz;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin', 'cashier') then
    raise exception 'not allowed to ask for approvals' using errcode = '42501', hint = 'not_allowed';
  end if;

  if public.auth_role() = 'cashier' and p_action not in ('sale_discount', 'void_sale') then
    raise exception 'not allowed to ask for approvals' using errcode = '42501', hint = 'not_allowed';
  end if;

  if p_action is null
     or p_action not in ('record_expense', 'void_expense', 'close_day', 'record_service_txn', 'void_service_txn', 'void_sale', 'sale_discount')
     or p_ref_id is null then
    raise exception 'action and reference are required' using errcode = '22023', hint = 'invalid_value';
  end if;

  if p_pin is null or p_pin !~ '^[0-9]{4,8}$' then
    return jsonb_build_object('ok', false, 'hint', 'pin_wrong');
  end if;

  if p_action = 'void_expense' then
    select e.location_id into v_loc from public.expenses e where e.id = p_ref_id and e.tenant_id = v_tenant;
  elsif p_action = 'void_service_txn' then
    select s.location_id into v_loc from public.service_txns s where s.id = p_ref_id and s.tenant_id = v_tenant;
  elsif p_action = 'void_sale' then
    select s.location_id into v_loc from public.sales s where s.id = p_ref_id and s.tenant_id = v_tenant;
  end if;

  if v_loc is null then
    v_loc := public.resolve_store(p_location_id);
  end if;

  if p_action in ('sale_discount', 'void_sale') then
    if not public.has_location_access(v_loc) then
      raise exception 'not assigned to this store' using errcode = '42501', hint = 'not_allowed';
    end if;
  else
    if not public.has_location_access(v_loc, 'supervisor') then
      raise exception 'not a supervisor of this store' using errcode = '42501', hint = 'not_allowed';
    end if;
  end if;

  v_approver := coalesce(p_approver_id, auth.uid());
  if not public.is_store_approver(v_approver, v_loc) then
    raise exception 'this person cannot approve here' using errcode = '42501', hint = 'approver_invalid';
  end if;

  v_try := public.pin_attempt(v_approver, p_pin, v_loc);
  if v_try = 'locked' then
    return jsonb_build_object('ok', false, 'hint', 'pin_locked');
  elsif v_try = 'not_set' then
    return jsonb_build_object('ok', false, 'hint', 'pin_not_set');
  elsif v_try <> 'ok' then
    return jsonb_build_object('ok', false, 'hint', 'pin_wrong');
  end if;

  v_exp := now() + interval '12 hours';
  insert into public.supervisor_approvals (tenant_id, location_id, action, ref_id, requested_by, approved_by, expires_at)
  values (v_tenant, v_loc, p_action, p_ref_id, auth.uid(), v_approver, v_exp)
  returning id into v_id;

  perform public.write_audit('approval.grant', 'approval', v_id, v_loc,
    jsonb_build_object('action', p_action, 'ref_id', p_ref_id, 'approved_by', v_approver));

  return jsonb_build_object('ok', true, 'approval_id', v_id, 'approved_by', v_approver, 'expires_at', v_exp);
end;
$$;

revoke execute on function public.approve_supervisor_action(text, uuid, text, uuid, uuid) from public, anon;
grant execute on function public.approve_supervisor_action(text, uuid, text, uuid, uuid) to authenticated;

-- 5. List eligible approvers for a store (safe query for cashiers in UI)
create or replace function public.list_store_approvers(p_location_id uuid default null)
returns table (user_id uuid, full_name text, role text, "position" text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_loc    uuid;
begin
  perform public.assert_active_user();
  v_tenant := public.auth_tenant_id();
  v_loc := public.resolve_store(p_location_id);
  if not public.has_location_access(v_loc) then
    raise exception 'not assigned to this store' using errcode = '42501', hint = 'not_allowed';
  end if;

  return query
  select p.user_id, p.full_name, p.role, la.position
  from public.profiles p
  left join public.location_access la on la.user_id = p.user_id and la.location_id = v_loc and la.deleted_at is null
  where p.tenant_id = v_tenant
    and p.active
    and p.deleted_at is null
    and (
      p.role = 'superadmin'
      or (p.role = 'admin' and la.position in ('supervisor', 'manager'))
    )
  order by (case when p.role = 'superadmin' then 1 else 2 end), p.full_name;
end;
$$;

revoke execute on function public.list_store_approvers(uuid) from public, anon;
grant execute on function public.list_store_approvers(uuid) to authenticated;

-- 6. Update op_record_sale with cashier discount threshold enforcement
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
    v_appr := public.consume_supervisor_approval(v_loc, 'sale_discount', v_sale, (p ->> 'approval_id')::uuid, p_op_id);
  elsif (p ->> 'approval_id') is not null then
    v_appr := public.consume_supervisor_approval(v_loc, 'sale_discount', v_sale, (p ->> 'approval_id')::uuid, p_op_id);
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
    if not v_can_void_own and (p ->> 'approval_id') is null then
      raise exception 'not allowed to cancel sales here' using errcode = '42501', hint = 'not_allowed';
    end if;
  end if;

  if v_sale.status = 'voided' then
    return public.finish_op(p_op_id, jsonb_build_object('sale_id', v_sid, 'already', true, 'applied_at', now()));
  end if;

  -- Approval consumption
  if not v_is_super then
    if (not v_can_void_own) or (v_sale.total > v_max_void_amt) or (p ->> 'approval_id') is not null then
      v_appr := public.consume_supervisor_approval(v_sale.location_id, 'void_sale', v_sid, (p ->> 'approval_id')::uuid, p_op_id);
    end if;
  elsif (p ->> 'approval_id') is not null then
    v_appr := public.consume_supervisor_approval(v_sale.location_id, 'void_sale', v_sid, (p ->> 'approval_id')::uuid, p_op_id);
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
