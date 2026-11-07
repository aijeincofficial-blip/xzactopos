-- P3-02 Sale RPCs, batch push and the POS delta pull.
--
--   sync_push(ops)        the one client entry for sales, voids, customers, utang payments and opening stock.
--                         Up to 50 ops in order; each op runs in its own subtransaction and is idempotent
--                         through processed_ops (claim_op / finish_op from P2-02).
--   op_*                  per-kind functions. Not callable by clients; only sync_push calls them.
--   sync_pull_pos         keyset delta pull of stock levels, customers and the utang ledger.
--
-- Result per op: { op_id, status: ok | rejected | error, result | hint, code }.
--   rejected = permanent (retrying cannot help), error = transient (retry the same op id later).
--   After an `error` the batch stops, so later ops that depend on it are not applied out of order.
--
-- Hints for i18n: not_allowed, location_required, location_denied, customer_required, unknown_customer, unknown_variant,
--   items_required, qty_invalid, totals_mismatch, payments_mismatch, duplicate_local_no, id_conflict, sale_not_found,
--   amount_invalid, invalid_value, unknown_kind, batch_invalid, plus the P2-02 ones (op_id_required, op_id_reused, ...).

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Who may ring up sales: superadmin, admin and cashier (not warehouse), POS module on.
create or replace function public.assert_seller()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if public.auth_role() not in ('superadmin', 'admin', 'cashier') then
    raise exception 'not allowed to sell' using errcode = '42501', hint = 'not_allowed';
  end if;
end;
$$;

-- The store a sale or stock entry belongs to. Given: the user must have access and it must be a store.
-- Missing: the user must have exactly one store (the solo case).
create or replace function public.resolve_store(p_location_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ids uuid[];
begin
  if p_location_id is not null then
    perform public.assert_location_access(p_location_id);
    if not exists (select 1 from public.locations l
                   where l.id = p_location_id and l.tenant_id = public.auth_tenant_id() and l.type = 'store') then
      raise exception 'not a store' using errcode = '42501', hint = 'location_denied';
    end if;
    return p_location_id;
  end if;

  select array_agg(l.id) into v_ids
  from public.locations l
  where l.id = any (public.auth_location_ids()) and l.type = 'store' and l.active;
  if v_ids is null or cardinality(v_ids) <> 1 then
    raise exception 'store is required' using errcode = '22023', hint = 'location_required';
  end if;
  return v_ids[1];
end;
$$;

revoke execute on function public.assert_seller() from public, anon, authenticated;
revoke execute on function public.resolve_store(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_record_sale
--   p = { id, local_no, location_id?, sold_at, discount?, subtotal?, total?, customer_id?,
--         items:    [ { variant_id, name?, qty, unit_price, unit_cost?, discount?, tax?, line_total? } ],
--         payments: [ { method: cash|utang|ewallet, amount, tendered?, reference? } ] }
--   Money is base-currency minor units. The server recomputes every total; a client that disagrees is refused.
--   Returns { sale_id, local_no, applied_at }.
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

  -- payments must cover the total exactly (change is not a payment)
  for pay in select * from jsonb_array_elements(coalesce(p -> 'payments', '[]'::jsonb)) loop
    v_method := pay ->> 'method';
    v_amt := (pay ->> 'amount')::bigint;
    if v_method not in ('cash', 'utang', 'ewallet') or v_amt is null or v_amt <= 0 then
      raise exception 'payment is invalid' using errcode = '22023', hint = 'invalid_value';
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
      insert into public.payments (tenant_id, sale_id, location_id, method, amount, tendered, reference)
      values (v_tenant, v_sale, v_loc, v_method, v_amt, v_tend, left(nullif(btrim(pay ->> 'reference'), ''), 64));
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

-- ---------------------------------------------------------------------------
-- op_void_sale: a compensating entry, never a delete. Stock goes back, the utang charge is reversed.
-- Needs supervisor access to the store (the solo owner is superadmin).
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

  insert into public.customer_ledger (tenant_id, customer_id, kind, amount, sale_id, note, occurred_at, created_by)
  select l.tenant_id, l.customer_id, 'adjust', -l.amount, v_sid, 'void', now(), auth.uid()
  from public.customer_ledger l
  where l.tenant_id = v_tenant and l.sale_id = v_sid and l.kind = 'charge';

  perform public.write_audit('sale.void', 'sale', v_sid, v_sale.location_id,
    jsonb_build_object('no', v_sale.local_no, 'total', v_sale.total));

  return public.finish_op(p_op_id, jsonb_build_object('sale_id', v_sid, 'already', false, 'applied_at', now()));
end;
$$;

-- ---------------------------------------------------------------------------
-- op_upsert_customer   p = { id, name, phone? }     (name and phone replace the old ones)
-- ---------------------------------------------------------------------------

create or replace function public.op_upsert_customer(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_id     uuid;
  v_name   text;
  v_created boolean;
begin
  perform public.assert_seller();
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'customer must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'upsert_customer');
  if v_replay is not null then
    return v_replay;
  end if;

  v_id := (p ->> 'id')::uuid;
  v_name := btrim(p ->> 'name');
  if v_id is null then
    raise exception 'customer id is required' using errcode = '22023', hint = 'id_required';
  end if;
  if v_name is null or length(v_name) not between 1 and 80 then
    raise exception 'name is required' using errcode = '22023', hint = 'name_required';
  end if;

  if exists (select 1 from public.customers c where c.id = v_id and c.tenant_id = v_tenant) then
    update public.customers
       set name = v_name, phone = left(nullif(btrim(p ->> 'phone'), ''), 32), deleted_at = null
     where id = v_id and tenant_id = v_tenant;
    v_created := false;
  else
    begin
      insert into public.customers (id, tenant_id, name, phone)
      values (v_id, v_tenant, v_name, left(nullif(btrim(p ->> 'phone'), ''), 32));
    exception when unique_violation then
      raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
    end;
    v_created := true;
  end if;

  perform public.write_audit(case when v_created then 'customer.create' else 'customer.update' end, 'customer', v_id);
  return public.finish_op(p_op_id, jsonb_build_object('customer_id', v_id, 'created', v_created));
end;
$$;

-- ---------------------------------------------------------------------------
-- op_record_utang_payment   p = { customer_id, amount (positive), note?, occurred_at? }
-- Overpaying is allowed here (the money was handed over; the ledger only records facts). The app warns first.
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

  v_cust := (p ->> 'customer_id')::uuid;
  v_amt := (p ->> 'amount')::bigint;
  if v_amt is null or v_amt <= 0 then
    raise exception 'amount must be above zero' using errcode = '22023', hint = 'amount_invalid';
  end if;
  if not exists (select 1 from public.customers c where c.id = v_cust and c.tenant_id = v_tenant) then
    raise exception 'unknown customer' using errcode = '22023', hint = 'unknown_customer';
  end if;

  insert into public.customer_ledger (tenant_id, customer_id, kind, amount, note, occurred_at, created_by)
  values (v_tenant, v_cust, 'payment', -v_amt, left(nullif(btrim(p ->> 'note'), ''), 200),
          coalesce((p ->> 'occurred_at')::timestamptz, now()), auth.uid());

  perform public.write_audit('utang.payment', 'customer', v_cust, null, jsonb_build_object('amount', v_amt));
  return public.finish_op(p_op_id, jsonb_build_object('customer_id', v_cust, 'applied_at', now()));
end;
$$;

-- ---------------------------------------------------------------------------
-- op_post_opening_stock   p = { variant_id, qty, location_id? }
-- Turns the "how many do you have now" typed at product add into an `opening` movement.
-- Same permission as editing the catalog.
-- ---------------------------------------------------------------------------

create or replace function public.op_post_opening_stock(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_loc    uuid;
  v_vid    uuid;
  v_qty    numeric;
  v_cost   bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  if public.catalog_write_mode() is distinct from 'full' then
    raise exception 'not allowed to set opening stock' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'opening stock must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'post_opening_stock');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);
  v_vid := (p ->> 'variant_id')::uuid;
  v_qty := (p ->> 'qty')::numeric;
  if v_qty is null or v_qty <= 0 or v_qty >= 1000000000 then
    raise exception 'quantity must be above zero' using errcode = '22023', hint = 'qty_invalid';
  end if;
  select v.cost into v_cost from public.product_variants v where v.id = v_vid and v.tenant_id = v_tenant;
  if not found then
    raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
  end if;

  insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id,
                                      unit_cost, created_by)
  values (v_tenant, v_loc, v_vid, v_qty, 'opening', 'opening', v_vid, v_cost, auth.uid());

  perform public.write_audit('stock.opening', 'variant', v_vid, v_loc, jsonb_build_object('qty', v_qty));
  return public.finish_op(p_op_id, jsonb_build_object('variant_id', v_vid, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_record_sale(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_void_sale(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_upsert_customer(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_record_utang_payment(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_post_opening_stock(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_push: ordered batch, one subtransaction per op
--   p_ops = [ { op_id, kind, payload } ... ]  (1 to 50)
--   returns [ { op_id, status, result? , hint?, code? } ... ]
-- ---------------------------------------------------------------------------

create or replace function public.sync_push(p_ops jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o        jsonb;
  v_out    jsonb := '[]'::jsonb;
  v_id     uuid;
  v_kind   text;
  v_res    jsonb;
  v_state  text;
  v_hint   text;
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
        when 'record_sale'         then public.op_record_sale(v_id, o -> 'payload')
        when 'void_sale'           then public.op_void_sale(v_id, o -> 'payload')
        when 'upsert_customer'     then public.op_upsert_customer(v_id, o -> 'payload')
        when 'record_utang_payment' then public.op_record_utang_payment(v_id, o -> 'payload')
        when 'post_opening_stock'  then public.op_post_opening_stock(v_id, o -> 'payload')
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
      v_out := v_out || jsonb_build_object(
        'op_id', v_id, 'status', 'rejected', 'code', v_state,
        'hint', coalesce(nullif(v_hint, ''), case v_state
          when '22P02' then 'invalid_value' when '22003' then 'invalid_value' when '22007' then 'invalid_value'
          when '23503' then 'unknown_reference' when '23514' then 'invalid_value'
          when '23505' then 'id_conflict' when '42501' then 'not_allowed'
          else 'rejected' end));
    end;
  end loop;

  return v_out;
end;
$$;

-- ---------------------------------------------------------------------------
-- sync_pull_pos: same shape as sync_pull_catalog (keyset pages, 5 s hold-back, runs as the caller).
-- Rows come from stock_levels (store-scoped), customers and the utang ledger (front-of-store roles).
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
    ('stock_levels',    'location_id, variant_id, qty_on_hand, updated_at',
                        'updated_at', 'location_id::text || ''|'' || variant_id::text'),
    ('customers',       'id, name, phone, updated_at, deleted_at',
                        'updated_at', 'id::text'),
    ('customer_ledger', 'id, customer_id, kind, amount, sale_id, note, occurred_at, created_at',
                        'created_at', 'id::text')
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

revoke execute on function public.sync_push(jsonb) from public, anon;
revoke execute on function public.sync_pull_pos(jsonb, int) from public, anon;
grant execute on function public.sync_push(jsonb) to authenticated;
grant execute on function public.sync_pull_pos(jsonb, int) to authenticated;
