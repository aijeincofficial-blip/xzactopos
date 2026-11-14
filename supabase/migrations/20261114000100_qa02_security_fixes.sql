-- Migration: 20261114000100_qa02_security_fixes.sql
-- Purpose: QA-02 Critical & High security fixes:
--   S01: Cryptographic HMAC-SHA256 offline supervisor approval proofs + approver-only SHA-256 verifiers in pull_offline_pins
--   S02: Catalog unit_price discount-bypass enforcement & server-authoritative non-negative unit_cost in op_record_sale
--   S03: Restrict global database storage/table metrics in get_storage_metrics() to platform admins
--   S04: Enforce role/position/module/is_active_user() guards across reports, transfers, warehouse bins, health_ping, sync pulls, and devices RLS

CREATE OR REPLACE FUNCTION public.pull_offline_pins(p_location_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(user_id uuid, username text, full_name text, role text, "position" text, pin_hash text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_loc    uuid := p_location_id;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');

  if v_loc is null then
    v_loc := public.resolve_store(v_loc);
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
    (
      select format(
        '%s$%s$%s$v2:%s',
        s.parts[1],
        s.parts[2],
        s.parts[3],
        replace(encode(extensions.digest(decode(s.parts[4], 'base64'), 'sha256'), 'base64'), E'\n', '')
      )
      from (select string_to_array(p.pin_hash, '$') as parts) s
      where cardinality(s.parts) = 4
        and s.parts[1] = 'pbkdf2_sha256'
    ) as pin_hash
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
    and array_length(string_to_array(p.pin_hash, '$'), 1) = 4
    and (
      p.role = 'superadmin'
      or (p.role = 'admin' and la.position in ('supervisor', 'manager'))
    )
  order by p.username;
end;
$function$;
revoke execute on function public.pull_offline_pins(uuid) from public, anon;
grant execute on function public.pull_offline_pins(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.consume_supervisor_approval(p_location_id uuid, p_action text, p_ref_id uuid, p_approval_id uuid, p_op_id uuid, p_offline_approval jsonb DEFAULT NULL::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  a             public.supervisor_approvals;
  v_approver    uuid;
  v_approved_at timestamptz;
  v_off_action  text;
  v_off_ref_txt text;
  v_off_ref     uuid;
  v_tenant          uuid := public.auth_tenant_id();
  v_hash            text;
  v_approved_at_raw text;
  v_proof           text;
  v_parts           text[];
  v_dk              bytea;
  v_msg             text;
  v_expected_hex    text;
  v_proof_digest    text;
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

  -- Path B: Offline supervisor override validated cryptographically on sync
  if p_offline_approval is not null and jsonb_typeof(p_offline_approval) = 'object' then
    v_approved_at_raw := nullif(btrim(p_offline_approval ->> 'approved_at'), '');
    v_proof := lower(nullif(btrim(p_offline_approval ->> 'proof'), ''));

    begin
      v_approver := (p_offline_approval ->> 'approver_id')::uuid;
      if v_approved_at_raw is not null then
        v_approved_at := v_approved_at_raw::timestamptz;
      end if;
    exception when others then
      raise exception 'invalid offline approval' using errcode = '22023', hint = 'approval_invalid';
    end;

    if v_approver is null or v_approved_at is null or v_proof is null or v_proof !~ '^[0-9a-f]{64}$' then
      raise exception 'invalid or missing offline approval proof' using errcode = '42501', hint = 'approval_invalid';
    end if;

    -- Action & ref_id checks prevent cross-action / cross-entity replay
    v_off_action := nullif(btrim(p_offline_approval ->> 'action'), '');
    if v_off_action is not null and v_off_action is distinct from p_action then
      raise exception 'offline approval action mismatch' using errcode = '42501', hint = 'approval_invalid';
    end if;

    v_off_ref_txt := nullif(btrim(p_offline_approval ->> 'ref_id'), '');
    if v_off_ref_txt is not null then
      begin
        v_off_ref := v_off_ref_txt::uuid;
      exception when others then
        raise exception 'offline approval ref_id invalid' using errcode = '22023', hint = 'approval_invalid';
      end;
      if v_off_ref is distinct from p_ref_id then
        raise exception 'offline approval ref_id mismatch' using errcode = '42501', hint = 'approval_invalid';
      end if;
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

    -- Verify HMAC-SHA256 proof keyed by approver derived PIN key dk
    v_parts := string_to_array(v_hash, '$');
    if cardinality(v_parts) <> 4 or v_parts[1] <> 'pbkdf2_sha256' then
      raise exception 'approver PIN hash invalid' using errcode = '42501', hint = 'approval_invalid';
    end if;

    begin
      v_dk := decode(v_parts[4], 'base64');
    exception when others then
      raise exception 'approver PIN hash invalid' using errcode = '42501', hint = 'approval_invalid';
    end;

    v_msg := lower(v_tenant::text) || '|' || lower(v_approver::text) || '|' || p_action
          || '|' || coalesce(lower(p_ref_id::text), '') || '|' || v_approved_at_raw;
    v_expected_hex := encode(extensions.hmac(convert_to(v_msg, 'UTF8'), v_dk, 'sha256'), 'hex');

    if extensions.hmac(convert_to(v_proof, 'UTF8'), v_dk, 'sha256')
       is distinct from extensions.hmac(convert_to(v_expected_hex, 'UTF8'), v_dk, 'sha256') then
      raise exception 'offline approval signature invalid' using errcode = '42501', hint = 'approval_invalid';
    end if;

    -- Single-use enforcement per op via cryptographic digest of proof (never logging raw proof)
    v_proof_digest := encode(extensions.digest(convert_to(v_proof, 'UTF8'), 'sha256'), 'hex');
    if exists (
      select 1 from public.audit_log al
      where al.tenant_id = v_tenant
        and al.action = 'approval.offline'
        and al.meta ->> 'proof_digest' = v_proof_digest
        and al.meta ->> 'op_id' is distinct from p_op_id::text
    ) then
      raise exception 'offline approval already used' using errcode = '42501', hint = 'approval_used';
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
        'requester_id', auth.uid(),
        'proof_digest', v_proof_digest
      )
    );

    return v_approver;
  end if;

  raise exception 'a supervisor approval is required' using errcode = '42501', hint = 'approval_required';
end;
$function$;
revoke execute on function public.consume_supervisor_approval(uuid, text, uuid, uuid, uuid, jsonb) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.op_record_sale(p_op_id uuid, p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_appr           uuid := null;
  v_base_currency  text;
  v_catalog_price  bigint;
  v_catalog_gross  bigint := 0;
  v_effective_disc bigint := 0;
  v_price_override boolean := false;
  v_server_cost    bigint;
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
  select t.base_currency into v_base_currency from public.tenants t where t.id = v_tenant;
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

  -- pass 1: validate lines, catalog prices, and costs
  for it in select * from jsonb_array_elements(p -> 'items') loop
    v_vid := (it ->> 'variant_id')::uuid;
    v_qty := (it ->> 'qty')::numeric;
    v_price := (it ->> 'unit_price')::bigint;
    v_idisc := coalesce((it ->> 'discount')::bigint, 0);
    v_itax := coalesce((it ->> 'tax')::bigint, 0);
    if v_vid is null or not exists (
      select 1 from public.product_variants pv where pv.id = v_vid and pv.tenant_id = v_tenant
    ) then
      raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
    end if;
    if v_qty is null or v_qty <= 0 or v_qty >= 1000000000 then
      raise exception 'quantity must be above zero' using errcode = '22023', hint = 'qty_invalid';
    end if;
    if v_price is null or v_price < 0 then
      raise exception 'price is invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    if it ? 'unit_cost' and jsonb_typeof(it -> 'unit_cost') <> 'null' and (it ->> 'unit_cost')::bigint < 0 then
      raise exception 'unit cost cannot be negative' using errcode = '22023', hint = 'invalid_value';
    end if;
    v_line := round(v_qty * v_price)::bigint - v_idisc;
    if v_line < 0 or v_idisc < 0 or v_itax < 0 or v_itax > v_line then
      raise exception 'line amounts are invalid' using errcode = '22023', hint = 'invalid_value';
    end if;
    if it ? 'line_total' and (it ->> 'line_total')::bigint <> v_line then
      raise exception 'line total does not match' using errcode = '22023', hint = 'totals_mismatch';
    end if;

    v_catalog_price := null;
    select vp.price into v_catalog_price
    from public.variant_prices vp
    where vp.tenant_id = v_tenant
      and vp.variant_id = v_vid
      and vp.currency = v_base_currency
    limit 1;

    if v_catalog_price is not null and v_catalog_price > 0 and v_price < v_catalog_price then
      v_price_override := true;
    end if;

    v_gross := v_gross + round(v_qty * v_price)::bigint;
    v_catalog_gross := v_catalog_gross + round(v_qty * greatest(coalesce(v_catalog_price, 0), v_price))::bigint;
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

  -- Cashier discount & downward unit_price override threshold check
  v_total_disc := v_gross - v_total;
  v_effective_disc := v_catalog_gross - v_total;
  select max_cashier_discount_percent
    into v_max_disc_pct
    from public.tenant_settings
   where tenant_id = v_tenant;
  v_max_disc_pct := coalesce(v_max_disc_pct, 10);

  if public.auth_role() = 'cashier' and (v_price_override or (v_catalog_gross > 0 and (v_effective_disc * 100 > v_catalog_gross * v_max_disc_pct))) then
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
    if v_method = 'cash' and pay ? 'tendered' and jsonb_typeof(pay -> 'tendered') <> 'null' and (pay ->> 'tendered')::bigint < v_amt then
      raise exception 'cash tendered cannot be less than payment amount' using errcode = '22023', hint = 'invalid_value';
    end if;
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

      select coalesce(nullif(sl.avg_cost, 0), v.cost, 0), pr.track_stock, pr.name into v_server_cost, v_track, v_pname
      from public.product_variants v
      join public.products pr on pr.tenant_id = v.tenant_id and pr.id = v.product_id
      left join public.stock_levels sl on sl.tenant_id = v.tenant_id and sl.location_id = v_loc and sl.variant_id = v.id
      where v.id = v_vid and v.tenant_id = v_tenant;
      if not found then
        raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
      end if;
      v_cost := greatest(coalesce(v_server_cost, 0), 0);

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
$function$;
revoke execute on function public.op_record_sale(uuid, jsonb) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_storage_metrics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant       uuid;
  v_role         text;
  v_total_bytes  bigint;
  v_limit_bytes  bigint := 524288000; -- 500 MB in bytes
  v_used_mb      numeric;
  v_percent_used numeric;
  v_status       text;
  v_tables       jsonb := '[]'::jsonb;
  v_tenant_stats jsonb;
  v_is_platform  boolean := false;
begin
  perform public.assert_active_user();

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  v_is_platform := coalesce(auth.role(), '') = 'service_role' or public.is_platform_admin();

  if v_role <> 'superadmin' and not v_is_platform then
    raise exception 'only platform admins or account owners can view storage metrics'
      using errcode = '42501', hint = 'not_allowed';
  end if;

  -- Tenant-specific row counts (strictly tenant-scoped)
  select jsonb_build_object(
    'products', (select count(*) from public.products where tenant_id = v_tenant and deleted_at is null),
    'sales', (select count(*) from public.sales where tenant_id = v_tenant),
    'stock_movements', (select count(*) from public.stock_movements where tenant_id = v_tenant),
    'customers', (select count(*) from public.customers where tenant_id = v_tenant),
    'expenses', (select count(*) from public.expenses where tenant_id = v_tenant),
    'processed_ops', (select count(*) from public.processed_ops where tenant_id = v_tenant),
    'audit_log', (select count(*) from public.audit_log where tenant_id = v_tenant)
  ) into v_tenant_stats;

  -- Global DB size and table breakdown: ONLY platform admins / service_role
  if v_is_platform then
    v_total_bytes := pg_database_size(current_database());
    v_used_mb := round((v_total_bytes::numeric / (1024 * 1024)), 2);
    v_percent_used := round((v_total_bytes::numeric / v_limit_bytes::numeric) * 100, 2);

    if v_percent_used >= 90 then
      v_status := 'critical';
    elsif v_percent_used >= 70 then
      v_status := 'warning';
    else
      v_status := 'healthy';
    end if;

    select coalesce(jsonb_agg(t), '[]'::jsonb)
    into v_tables
    from (
      select
        c.relname::text as table_name,
        c.reltuples::bigint as estimated_rows,
        pg_total_relation_size(c.oid) as total_bytes,
        pg_size_pretty(pg_total_relation_size(c.oid)) as formatted_size
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind in ('r', 'p')
      order by pg_total_relation_size(c.oid) desc
      limit 15
    ) t;

    return jsonb_build_object(
      'ok', true,
      'scope', 'global',
      'total_bytes', v_total_bytes,
      'limit_bytes', v_limit_bytes,
      'used_mb', v_used_mb,
      'limit_mb', 500,
      'percent_used', v_percent_used,
      'status', v_status,
      'tables', v_tables,
      'tenant_stats', v_tenant_stats
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'scope', 'tenant',
    'total_bytes', null,
    'limit_bytes', null,
    'used_mb', null,
    'limit_mb', null,
    'percent_used', null,
    'status', 'healthy',
    'tables', '[]'::jsonb,
    'tenant_stats', v_tenant_stats
  );
end;
$function$;
revoke execute on function public.get_storage_metrics() from public, anon;
grant execute on function public.get_storage_metrics() to authenticated;

CREATE OR REPLACE FUNCTION public.snapshot_daily_stock(p_day date DEFAULT NULL::date)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant uuid;
  v_tz     text;
  v_day    date;
  v_count  int;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  if public.auth_role() = 'cashier' then
    raise exception 'cashiers cannot snapshot stock valuations'
      using errcode = '42501', hint = 'not_allowed';
  end if;

  v_tenant := public.auth_tenant_id();
  select coalesce(timezone, 'Asia/Manila') into v_tz from public.tenants where id = v_tenant;
  v_day := coalesce(p_day, (now() at time zone v_tz)::date);

  insert into public.stock_snapshots_daily (
    tenant_id, location_id, day, variant_id, qty_on_hand, unit_cost, total_value, updated_at
  )
  select
    sl.tenant_id,
    sl.location_id,
    v_day,
    sl.variant_id,
    sl.qty_on_hand,
    coalesce(sl.avg_cost, 0),
    round(sl.qty_on_hand * coalesce(sl.avg_cost, 0))::bigint,
    now()
  from public.stock_levels sl
  where sl.tenant_id = v_tenant
  on conflict (location_id, day, variant_id) do update set
    qty_on_hand = excluded.qty_on_hand,
    unit_cost   = excluded.unit_cost,
    total_value = excluded.total_value,
    updated_at  = now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;
revoke execute on function public.snapshot_daily_stock(date) from public, anon;
grant execute on function public.snapshot_daily_stock(date) to authenticated;

CREATE OR REPLACE FUNCTION public.report_multi_store(p_from date, p_to date, p_location_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
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

  if public.auth_role() = 'cashier' then
    raise exception 'cashiers cannot view management reports' using errcode = '42501', hint = 'not_allowed';
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
$function$;
revoke execute on function public.report_multi_store(date, date, uuid) from public, anon;
grant execute on function public.report_multi_store(date, date, uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.health_ping()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public.assert_active_user();

  return jsonb_build_object(
    'ok', true,
    'status', 'healthy',
    'timestamp', now(),
    'version', '1.0.0'
  );
end;
$function$;
revoke execute on function public.health_ping() from public, anon;
grant execute on function public.health_ping() to authenticated;

CREATE OR REPLACE FUNCTION public.sync_pull_catalog(p_cursors jsonb DEFAULT '{}'::jsonb, p_limit integer DEFAULT 500)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
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
  if not exists (
    select 1 from public.tenant_modules m
    where m.tenant_id = v_tenant and m.deleted_at is null and (m.inventory or m.pos or m.warehouse)
  ) then
    raise exception 'required module is not enabled' using errcode = '42501', hint = 'module_disabled';
  end if;
  if p_limit is null or p_limit not between 1 and 1000 then
    raise exception 'limit must be 1 to 1000' using errcode = '22023', hint = 'invalid_value';
  end if;

  for r in select * from (values
    ('categories',       'id, parent_id, name, updated_at, deleted_at',
                         'id::text'),
    ('products',         'id, category_id, name, unit, tax_rate, track_stock, active, photo_path, updated_at, deleted_at',
                         'id::text'),
    ('product_variants', 'id, product_id, name, sku, barcode, is_default, cost, reorder_point, active, '
                         'breaks_into_variant_id, breaks_into_qty, updated_at, deleted_at',
                         'id::text'),
    ('variant_prices',   'variant_id, currency, price, updated_at, deleted_at',
                         'variant_id::text || ''|'' || currency')
  ) t(tbl, cols, keyexpr) loop
    v_cur := p_cursors -> r.tbl;

    execute format($q$
      with s as (
        select %2$s, %3$s as _k
        from public.%1$I
        where tenant_id = $1
          and updated_at <= $2
          and ($3::timestamptz is null or (updated_at, %3$s) > ($3::timestamptz, $4::text))
        order by updated_at, _k
        limit $5 + 1
      ), page as (
        select * from s order by updated_at, _k limit $5
      )
      select
        (select count(*) from s) > $5,
        coalesce((select jsonb_agg(to_jsonb(page) - '_k' order by page.updated_at, page._k) from page), '[]'::jsonb),
        (select jsonb_build_object('ts', page.updated_at, 'k', page._k) from page order by page.updated_at desc, page._k desc limit 1)
    $q$, r.tbl, r.cols, r.keyexpr)
    into v_more, v_rows, v_last
    using v_tenant, v_upto, v_cur ->> 'ts', v_cur ->> 'k', p_limit;

    v_out := v_out || jsonb_build_object(r.tbl, jsonb_build_object(
      'rows', v_rows,
      'cursor', coalesce(v_last, v_cur),
      'has_more', v_more));
  end loop;

  return v_out;
end;
$function$;
revoke execute on function public.sync_pull_catalog(jsonb, int) from public, anon;
grant execute on function public.sync_pull_catalog(jsonb, int) to authenticated;

CREATE OR REPLACE FUNCTION public.sync_pull_conversions(p_cursor jsonb DEFAULT NULL::jsonb, p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
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
  perform public.assert_module('inventory');
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.id, x.location_id, x.pack_variant_id, x.piece_variant_id, x.packs, x.ratio, x.pieces, x.pack_cost,
           x.total_cost, x.piece_cost, x.note, x.converted_at, x.created_by, x.voided_at, x.void_reason, x.updated_at
    from public.conversions x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and (v_ts is null and x.converted_at >= now() - interval '30 days'
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'pack_variant_id', g.pack_variant_id,
        'piece_variant_id', g.piece_variant_id, 'packs', g.packs, 'ratio', g.ratio, 'pieces', g.pieces,
        'pack_cost', g.pack_cost, 'total_cost', g.total_cost, 'piece_cost', g.piece_cost, 'note', g.note,
        'converted_at', g.converted_at, 'created_by', g.created_by, 'voided_at', g.voided_at,
        'void_reason', g.void_reason, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more,
                            'server_time', now());
end;
$function$;
revoke execute on function public.sync_pull_conversions(jsonb, int) from public, anon;
grant execute on function public.sync_pull_conversions(jsonb, int) to authenticated;

CREATE OR REPLACE FUNCTION public.enable_warehouse_bins(p_warehouse_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant         uuid;
  v_role           text;
  v_type           text;
  v_rcv_zone       uuid;
  v_stg_zone       uuid;
  v_gen_zone       uuid;
  v_rcv_bin        uuid;
  v_stg_bin        uuid;
  v_gen_bin        uuid;
  v_migrated_count int := 0;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'only managers or warehouse staff can manage warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if public.auth_role() = 'admin' and not public.has_location_access(p_warehouse_id, 'manager') then
    raise exception 'only managers or warehouse staff can manage warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  select type into v_type
  from public.locations
  where id = p_warehouse_id and tenant_id = v_tenant and active and deleted_at is null;

  if not found then
    raise exception 'location not found' using errcode = '22023', hint = 'location_not_found';
  end if;

  if v_type <> 'warehouse' then
    raise exception 'only warehouses can enable bins' using errcode = '22023', hint = 'not_a_warehouse';
  end if;

  update public.locations
  set bins_enabled = true, updated_at = now()
  where id = p_warehouse_id and tenant_id = v_tenant;

  select id into v_rcv_zone from public.warehouse_zones
  where warehouse_id = p_warehouse_id and code = 'RCV' and tenant_id = v_tenant;

  if v_rcv_zone is null then
    v_rcv_zone := public.uuid_generate_v7();
    insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type)
    values (v_rcv_zone, v_tenant, p_warehouse_id, 'RCV', 'Receiving', 'receiving');
  end if;

  select id into v_stg_zone from public.warehouse_zones
  where warehouse_id = p_warehouse_id and code = 'STG' and tenant_id = v_tenant;

  if v_stg_zone is null then
    v_stg_zone := public.uuid_generate_v7();
    insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type)
    values (v_stg_zone, v_tenant, p_warehouse_id, 'STG', 'Staging', 'staging');
  end if;

  select id into v_gen_zone from public.warehouse_zones
  where warehouse_id = p_warehouse_id and code = 'GEN' and tenant_id = v_tenant;

  if v_gen_zone is null then
    v_gen_zone := public.uuid_generate_v7();
    insert into public.warehouse_zones (id, tenant_id, warehouse_id, code, name, type)
    values (v_gen_zone, v_tenant, p_warehouse_id, 'GEN', 'General Storage', 'storage');
  end if;

  select id into v_rcv_bin from public.bins
  where warehouse_id = p_warehouse_id and code = 'RECEIVING' and tenant_id = v_tenant;

  if v_rcv_bin is null then
    v_rcv_bin := public.uuid_generate_v7();
    insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, type, active)
    values (v_rcv_bin, v_tenant, p_warehouse_id, v_rcv_zone, 'RECEIVING', 'floor', true);
  end if;

  select id into v_stg_bin from public.bins
  where warehouse_id = p_warehouse_id and code = 'STAGING' and tenant_id = v_tenant;

  if v_stg_bin is null then
    v_stg_bin := public.uuid_generate_v7();
    insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, type, active)
    values (v_stg_bin, v_tenant, p_warehouse_id, v_stg_zone, 'STAGING', 'floor', true);
  end if;

  select id into v_gen_bin from public.bins
  where warehouse_id = p_warehouse_id and code = 'A-01-1' and tenant_id = v_tenant;

  if v_gen_bin is null then
    v_gen_bin := public.uuid_generate_v7();
    insert into public.bins (id, tenant_id, warehouse_id, zone_id, code, aisle, rack, shelf, position, type, active)
    values (v_gen_bin, v_tenant, p_warehouse_id, v_gen_zone, 'A-01-1', 'A', '01', '1', '1', 'shelf', true);
  end if;

  insert into public.bin_stock_levels (tenant_id, bin_id, variant_id, qty_on_hand, updated_at)
  select sl.tenant_id, v_rcv_bin, sl.variant_id, sl.qty_on_hand, now()
  from public.stock_levels sl
  where sl.location_id = p_warehouse_id and sl.tenant_id = v_tenant and sl.qty_on_hand <> 0
  on conflict (bin_id, variant_id)
  do update set qty_on_hand = excluded.qty_on_hand, updated_at = now();

  get diagnostics v_migrated_count = row_count;

  perform public.write_audit('warehouse.bins_enabled', 'location', p_warehouse_id, p_warehouse_id,
    jsonb_build_object('migrated_stock_count', v_migrated_count));

  return jsonb_build_object(
    'ok', true,
    'warehouse_id', p_warehouse_id,
    'receiving_bin_id', v_rcv_bin,
    'staging_bin_id', v_stg_bin,
    'general_bin_id', v_gen_bin,
    'migrated_count', v_migrated_count
  );
end;
$function$;
revoke execute on function public.enable_warehouse_bins(uuid) from public, anon;
grant execute on function public.enable_warehouse_bins(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.upsert_warehouse_zone(p_warehouse_id uuid, p_code text, p_name text, p_type text, p_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant uuid;
  v_role   text;
  v_id     uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'only managers or warehouse staff can manage warehouse zones' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if public.auth_role() = 'admin' and not public.has_location_access(p_warehouse_id, 'manager') then
    raise exception 'only managers or warehouse staff can manage warehouse zones' using errcode = '42501', hint = 'not_allowed';
  end if;

  if p_code !~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,19}$' then
    raise exception 'invalid zone code' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if length(btrim(p_name)) < 1 or length(p_name) > 120 then
    raise exception 'invalid zone name' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if p_type not in ('receiving', 'storage', 'picking', 'staging', 'quarantine', 'damaged') then
    raise exception 'invalid zone type' using errcode = '22023', hint = 'invalid_argument';
  end if;

  v_id := coalesce(p_id, public.uuid_generate_v7());

  insert into public.warehouse_zones (
    id, tenant_id, warehouse_id, code, name, type
  ) values (
    v_id, v_tenant, p_warehouse_id, upper(p_code), btrim(p_name), p_type
  )
  on conflict (tenant_id, id)
  do update set
    code = excluded.code,
    name = excluded.name,
    type = excluded.type,
    updated_at = now();

  return v_id;
end;
$function$;
revoke execute on function public.upsert_warehouse_zone(uuid, text, text, text, uuid) from public, anon;
grant execute on function public.upsert_warehouse_zone(uuid, text, text, text, uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.upsert_warehouse_bin(p_warehouse_id uuid, p_code text, p_zone_id uuid DEFAULT NULL::uuid, p_aisle text DEFAULT NULL::text, p_rack text DEFAULT NULL::text, p_shelf text DEFAULT NULL::text, p_position text DEFAULT NULL::text, p_type text DEFAULT 'shelf'::text, p_max_qty numeric DEFAULT NULL::numeric, p_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant uuid;
  v_role   text;
  v_id     uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'only managers or warehouse staff can manage warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if public.auth_role() = 'admin' and not public.has_location_access(p_warehouse_id, 'manager') then
    raise exception 'only managers or warehouse staff can manage warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  if p_code !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,29}$' then
    raise exception 'invalid bin code' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if p_type not in ('pallet', 'shelf', 'floor', 'bin') then
    raise exception 'invalid bin type' using errcode = '22023', hint = 'invalid_argument';
  end if;

  if p_max_qty is not null and p_max_qty <= 0 then
    raise exception 'max qty must be positive' using errcode = '22023', hint = 'positive_qty';
  end if;

  if p_zone_id is not null and not exists (
    select 1 from public.warehouse_zones
    where id = p_zone_id and warehouse_id = p_warehouse_id and tenant_id = v_tenant and deleted_at is null
  ) then
    raise exception 'zone not found' using errcode = '22023', hint = 'not_found';
  end if;

  v_id := coalesce(p_id, public.uuid_generate_v7());

  insert into public.bins (
    id, tenant_id, warehouse_id, zone_id, code,
    aisle, rack, shelf, position, type, max_qty, active
  ) values (
    v_id, v_tenant, p_warehouse_id, p_zone_id, upper(p_code),
    p_aisle, p_rack, p_shelf, p_position, p_type, p_max_qty, true
  )
  on conflict (tenant_id, id)
  do update set
    zone_id = excluded.zone_id,
    code = excluded.code,
    aisle = excluded.aisle,
    rack = excluded.rack,
    shelf = excluded.shelf,
    position = excluded.position,
    type = excluded.type,
    max_qty = excluded.max_qty,
    updated_at = now();

  return v_id;
end;
$function$;
revoke execute on function public.upsert_warehouse_bin(uuid, text, uuid, text, text, text, text, text, numeric, uuid) from public, anon;
grant execute on function public.upsert_warehouse_bin(uuid, text, uuid, text, text, text, text, text, numeric, uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.list_warehouse_bins(p_warehouse_id uuid, p_zone_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(id uuid, code text, zone_id uuid, zone_code text, zone_name text, zone_type text, aisle text, rack text, shelf text, "position" text, type text, max_qty numeric, active boolean, item_count bigint, total_qty numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'only managers or warehouse staff can inspect warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if public.auth_role() = 'admin' and not public.has_location_access(p_warehouse_id, 'manager') then
    raise exception 'only managers or warehouse staff can inspect warehouse bins' using errcode = '42501', hint = 'not_allowed';
  end if;

  return query
  select
    b.id,
    b.code,
    b.zone_id,
    z.code as zone_code,
    z.name as zone_name,
    z.type as zone_type,
    b.aisle,
    b.rack,
    b.shelf,
    b."position",
    b.type,
    b.max_qty,
    b.active,
    coalesce(count(distinct case when bsl.qty_on_hand <> 0 then bsl.variant_id end), 0) as item_count,
    coalesce(sum(case when bsl.qty_on_hand <> 0 then bsl.qty_on_hand else 0 end), 0) as total_qty
  from public.bins b
  left join public.warehouse_zones z on z.id = b.zone_id
  left join public.bin_stock_levels bsl on bsl.bin_id = b.id
  where b.warehouse_id = p_warehouse_id
    and b.tenant_id = v_tenant
    and b.deleted_at is null
    and (p_zone_id is null or b.zone_id = p_zone_id)
  group by b.id, b.code, b.zone_id, z.code, z.name, z.type, b.aisle, b.rack, b.shelf, b."position", b.type, b.max_qty, b.active
  order by
    coalesce(b.aisle, ''),
    coalesce(b.rack, ''),
    coalesce(b.shelf, ''),
    coalesce(b."position", ''),
    b.code;
end;
$function$;
revoke execute on function public.list_warehouse_bins(uuid, uuid) from public, anon;
grant execute on function public.list_warehouse_bins(uuid, uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.check_bin_stock_invariant(p_warehouse_id uuid)
 RETURNS TABLE(variant_id uuid, sku text, warehouse_qty numeric, bins_qty numeric, diff numeric, is_valid boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'only managers or warehouse staff can inspect warehouse bin invariants' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if public.auth_role() = 'admin' and not public.has_location_access(p_warehouse_id, 'manager') then
    raise exception 'only managers or warehouse staff can inspect warehouse bin invariants' using errcode = '42501', hint = 'not_allowed';
  end if;

  return query
  with b_sum as (
    select bsl.variant_id, coalesce(sum(bsl.qty_on_hand), 0) as total_bins_qty
    from public.bin_stock_levels bsl
    join public.bins b on b.id = bsl.bin_id
    where b.warehouse_id = p_warehouse_id and b.tenant_id = v_tenant and bsl.tenant_id = v_tenant
    group by bsl.variant_id
  ),
  all_vars as (
    select sl.variant_id
    from public.stock_levels sl
    where sl.location_id = p_warehouse_id and sl.tenant_id = v_tenant
    union
    select bs.variant_id
    from b_sum bs
  )
  select
    av.variant_id,
    pv.sku,
    coalesce(sl.qty_on_hand, 0) as warehouse_qty,
    coalesce(bs.total_bins_qty, 0) as bins_qty,
    (coalesce(sl.qty_on_hand, 0) - coalesce(bs.total_bins_qty, 0)) as diff,
    (coalesce(sl.qty_on_hand, 0) = coalesce(bs.total_bins_qty, 0)) as is_valid
  from all_vars av
  join public.product_variants pv on pv.id = av.variant_id and pv.tenant_id = v_tenant
  left join public.stock_levels sl on sl.location_id = p_warehouse_id and sl.variant_id = av.variant_id and sl.tenant_id = v_tenant
  left join b_sum bs on bs.variant_id = av.variant_id
  order by pv.sku;
end;
$function$;
revoke execute on function public.check_bin_stock_invariant(uuid) from public, anon;
grant execute on function public.check_bin_stock_invariant(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.move_bin_stock(p_warehouse_id uuid, p_from_bin_id uuid, p_to_bin_id uuid, p_variant_id uuid, p_qty numeric, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant uuid;
  v_role   text;
  v_avail  numeric := 0;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'only managers or warehouse staff can move bin stock' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if public.auth_role() = 'admin' and not public.has_location_access(p_warehouse_id, 'manager') then
    raise exception 'only managers or warehouse staff can move bin stock' using errcode = '42501', hint = 'not_allowed';
  end if;

  if p_from_bin_id = p_to_bin_id then
    raise exception 'source and destination bins must be different' using errcode = '22023', hint = 'same_bin';
  end if;

  if p_qty <= 0 then
    raise exception 'quantity must be positive' using errcode = '22023', hint = 'positive_qty';
  end if;

  if not exists (
    select 1 from public.bins where id = p_from_bin_id and warehouse_id = p_warehouse_id and tenant_id = v_tenant and deleted_at is null
  ) or not exists (
    select 1 from public.bins where id = p_to_bin_id and warehouse_id = p_warehouse_id and tenant_id = v_tenant and deleted_at is null
  ) then
    raise exception 'bin not found' using errcode = '22023', hint = 'not_found';
  end if;

  select coalesce(qty_on_hand, 0) into v_avail
  from public.bin_stock_levels
  where bin_id = p_from_bin_id and variant_id = p_variant_id;

  if v_avail < p_qty then
    raise exception 'insufficient stock in source bin' using errcode = '55000', hint = 'insufficient_bin_stock';
  end if;

  insert into public.stock_movements (
    tenant_id, location_id, bin_id, variant_id, qty_delta, type, ref_type, created_by
  ) values (
    v_tenant, p_warehouse_id, p_from_bin_id, p_variant_id, -p_qty, 'bin_move', p_reason, auth.uid()
  );

  insert into public.stock_movements (
    tenant_id, location_id, bin_id, variant_id, qty_delta, type, ref_type, created_by
  ) values (
    v_tenant, p_warehouse_id, p_to_bin_id, p_variant_id, p_qty, 'bin_move', p_reason, auth.uid()
  );
end;
$function$;
revoke execute on function public.move_bin_stock(uuid, uuid, uuid, uuid, numeric, text) from public, anon;
grant execute on function public.move_bin_stock(uuid, uuid, uuid, uuid, numeric, text) to authenticated;

CREATE OR REPLACE FUNCTION public.list_receiving_stock(p_warehouse_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant uuid;
  v_result jsonb;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'only managers or warehouse staff can inspect warehouse receiving stock' using errcode = '42501', hint = 'not_allowed';
  end if;

  perform public.assert_location_access(p_warehouse_id);

  if public.auth_role() = 'admin' and not public.has_location_access(p_warehouse_id, 'manager') then
    raise exception 'only managers or warehouse staff can inspect warehouse receiving stock' using errcode = '42501', hint = 'not_allowed';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'bin_id', b.id,
    'bin_code', b.code,
    'variant_id', bsl.variant_id,
    'sku', pv.sku,
    'variant_name', pv.name,
    'product_name', p.name,
    'qty_on_hand', bsl.qty_on_hand,
    'updated_at', bsl.updated_at
  ) order by b.code, p.name, pv.name, pv.sku), '[]'::jsonb)
  into v_result
  from public.bin_stock_levels bsl
  join public.bins b on b.id = bsl.bin_id
  join public.warehouse_zones z on z.id = b.zone_id
  join public.product_variants pv on pv.id = bsl.variant_id
  join public.products p on p.id = pv.product_id
  where b.warehouse_id = p_warehouse_id
    and b.tenant_id = v_tenant
    and b.deleted_at is null
    and z.type = 'receiving'
    and bsl.qty_on_hand > 0;

  return v_result;
end;
$function$;
revoke execute on function public.list_receiving_stock(uuid) from public, anon;
grant execute on function public.list_receiving_stock(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.generate_pick_list(p_transfer_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant       uuid;
  v_role         text;
  v_transfer     record;
  v_pick_list_id uuid;
  v_pick_no      text;
  v_item         record;
  v_bin_rec      record;
  v_needed       numeric;
  v_take         numeric;
  v_day          text := to_char(now() at time zone 'Asia/Manila', 'YYMMDD');
  v_seq          integer;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'only managers or warehouse staff can generate pick lists' using errcode = '42501', hint = 'not_allowed';
  end if;

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_transfer.status <> 'draft' then
    raise exception 'pick lists can only be generated for draft transfers' using errcode = '42501', hint = 'transfer_not_draft';
  end if;

  perform public.assert_location_access(v_transfer.from_location_id);

  if public.auth_role() = 'admin' and not public.has_location_access(v_transfer.from_location_id, 'manager') then
    raise exception 'only managers or warehouse staff can generate pick lists' using errcode = '42501', hint = 'not_allowed';
  end if;

  select id into v_pick_list_id
  from public.pick_lists
  where transfer_id = p_transfer_id and tenant_id = v_tenant and status <> 'cancelled';

  if v_pick_list_id is not null then
    return v_pick_list_id;
  end if;

  select coalesce(max(substring(pick_list_no from 'PCK-[0-9]{6}-([0-9]+)')::int), 0) + 1
  into v_seq
  from public.pick_lists
  where tenant_id = v_tenant and pick_list_no like 'PCK-' || v_day || '-%';

  v_pick_no := 'PCK-' || v_day || '-' || lpad(v_seq::text, 4, '0');
  v_pick_list_id := public.uuid_generate_v7();

  insert into public.pick_lists (
    id, tenant_id, warehouse_id, transfer_id, pick_list_no, status, created_by
  ) values (
    v_pick_list_id, v_tenant, v_transfer.from_location_id, p_transfer_id, v_pick_no, 'pending', auth.uid()
  );

  for v_item in (
    select ti.variant_id, ti.qty_shipped
    from public.transfer_items ti
    where ti.transfer_id = p_transfer_id and ti.tenant_id = v_tenant
  ) loop
    v_needed := v_item.qty_shipped;

    for v_bin_rec in (
      select bsl.bin_id, bsl.qty_on_hand, b.aisle, b.rack, b.shelf, b."position", b.code
      from public.bin_stock_levels bsl
      join public.bins b on b.id = bsl.bin_id
      left join public.warehouse_zones z on z.id = b.zone_id
      where b.warehouse_id = v_transfer.from_location_id
        and bsl.variant_id = v_item.variant_id
        and bsl.qty_on_hand > 0
        and b.active
        and b.deleted_at is null
      order by
        case when z.type in ('picking', 'storage') then 0 else 1 end,
        coalesce(b.aisle, ''),
        coalesce(b.rack, ''),
        coalesce(b.shelf, ''),
        coalesce(b."position", ''),
        b.code
    ) loop
      exit when v_needed <= 0;

      v_take := least(v_needed, v_bin_rec.qty_on_hand);
      insert into public.pick_list_items (
        id, tenant_id, pick_list_id, variant_id, bin_id, qty_requested, qty_picked
      ) values (
        public.uuid_generate_v7(), v_tenant, v_pick_list_id, v_item.variant_id, v_bin_rec.bin_id, v_take, 0
      );

      v_needed := v_needed - v_take;
    end loop;

    if v_needed > 0 then
      select b.id into v_bin_rec.bin_id
      from public.bins b
      where b.warehouse_id = v_transfer.from_location_id and b.deleted_at is null
      order by b.code limit 1;

      if v_bin_rec.bin_id is not null then
        insert into public.pick_list_items (
          id, tenant_id, pick_list_id, variant_id, bin_id, qty_requested, qty_picked
        ) values (
          public.uuid_generate_v7(), v_tenant, v_pick_list_id, v_item.variant_id, v_bin_rec.bin_id, v_needed, 0
        );
      end if;
    end if;
  end loop;

  perform public.write_audit('warehouse.pick_list_generated', 'pick_list', v_pick_list_id, v_transfer.from_location_id,
    jsonb_build_object('pick_list_no', v_pick_no, 'transfer_id', p_transfer_id));

  return v_pick_list_id;
end;
$function$;
revoke execute on function public.generate_pick_list(uuid) from public, anon;
grant execute on function public.generate_pick_list(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.confirm_pick_item(p_pick_list_id uuid, p_item_id uuid, p_qty_picked numeric, p_short_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant        uuid;
  v_role          text;
  v_pick_list     record;
  v_item          record;
  v_stg_bin       uuid;
  v_unpicked_cnt  integer;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  perform public.assert_module('warehouse');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'only managers or warehouse staff can confirm picks' using errcode = '42501', hint = 'not_allowed';
  end if;

  select * into v_pick_list
  from public.pick_lists
  where id = p_pick_list_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'pick list not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_pick_list.status = 'completed' or v_pick_list.status = 'cancelled' then
    raise exception 'pick list is already completed or cancelled' using errcode = '42501', hint = 'invalid_state';
  end if;

  perform public.assert_location_access(v_pick_list.warehouse_id);

  if public.auth_role() = 'admin' and not public.has_location_access(v_pick_list.warehouse_id, 'manager') then
    raise exception 'only managers or warehouse staff can confirm picks' using errcode = '42501', hint = 'not_allowed';
  end if;

  select * into v_item
  from public.pick_list_items
  where id = p_item_id and pick_list_id = p_pick_list_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'pick item not found' using errcode = '22023', hint = 'not_found';
  end if;

  if p_qty_picked < 0 then
    raise exception 'picked quantity cannot be negative' using errcode = '22023', hint = 'non_negative_qty';
  end if;

  select b.id into v_stg_bin
  from public.bins b
  join public.warehouse_zones z on z.id = b.zone_id
  where b.warehouse_id = v_pick_list.warehouse_id and z.type = 'staging' and b.deleted_at is null
  order by b.code limit 1;

  if v_stg_bin is null then
    select b.id into v_stg_bin
    from public.bins b
    where b.warehouse_id = v_pick_list.warehouse_id and b.deleted_at is null
    order by b.code limit 1;
  end if;

  if p_qty_picked > 0 and v_item.bin_id <> v_stg_bin then
    perform public.move_bin_stock(
      v_pick_list.warehouse_id,
      v_item.bin_id,
      v_stg_bin,
      v_item.variant_id,
      p_qty_picked,
      'pick'
    );
  end if;

  update public.pick_list_items
  set qty_picked = p_qty_picked,
      short_reason = case when p_qty_picked < qty_requested then p_short_reason else null end,
      updated_at = now()
  where id = p_item_id and tenant_id = v_tenant;

  update public.pick_lists
  set status = 'in_progress', updated_at = now()
  where id = p_pick_list_id and status = 'pending';

  select count(*) into v_unpicked_cnt
  from public.pick_list_items
  where pick_list_id = p_pick_list_id and tenant_id = v_tenant and qty_picked = 0;

  if v_unpicked_cnt = 0 then
    update public.pick_lists
    set status = 'completed',
        completed_at = now(),
        completed_by = auth.uid(),
        updated_at = now()
    where id = p_pick_list_id;
  end if;
end;
$function$;
revoke execute on function public.confirm_pick_item(uuid, uuid, numeric, text) from public, anon;
grant execute on function public.confirm_pick_item(uuid, uuid, numeric, text) to authenticated;

CREATE OR REPLACE FUNCTION public.list_bin_stock(p_bin_id uuid)
 RETURNS TABLE(variant_id uuid, sku text, product_name text, qty_on_hand numeric, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant       uuid;
  v_warehouse_id uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse')
     or (public.auth_role() = 'admin' and not exists (
       select 1 from public.location_access la
       where la.user_id = auth.uid() and la.tenant_id = v_tenant and la.deleted_at is null and la.position = 'manager'
     )) then
    raise exception 'only managers or warehouse staff can inspect warehouse bin stock' using errcode = '42501', hint = 'not_allowed';
  end if;

  select b.warehouse_id into v_warehouse_id
  from public.bins b
  where b.id = p_bin_id and b.tenant_id = v_tenant and b.deleted_at is null;

  if v_warehouse_id is null then
    return;
  end if;

  perform public.assert_location_access(v_warehouse_id);

  if public.auth_role() = 'admin' and not public.has_location_access(v_warehouse_id, 'manager') then
    raise exception 'only managers or warehouse staff can inspect warehouse bin stock' using errcode = '42501', hint = 'not_allowed';
  end if;

  return query
  select
    bsl.variant_id,
    pv.sku,
    case
      when pv.is_default and pv.name = 'Default' then p.name
      else p.name || ' (' || pv.name || ')'
    end as product_name,
    bsl.qty_on_hand,
    bsl.updated_at
  from public.bin_stock_levels bsl
  join public.product_variants pv on pv.id = bsl.variant_id
  join public.products p on p.id = pv.product_id
  where bsl.bin_id = p_bin_id
    and bsl.tenant_id = v_tenant
    and bsl.qty_on_hand <> 0
  order by p.name, pv.name, pv.sku;
end;
$function$;
revoke execute on function public.list_bin_stock(uuid) from public, anon;
grant execute on function public.list_bin_stock(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.get_pick_list_for_transfer(p_transfer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant   uuid;
  v_from_loc uuid;
  v_result   jsonb;
begin
  perform public.assert_active_user();
  perform public.assert_module('warehouse');
  v_tenant := public.auth_tenant_id();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse')
     or (public.auth_role() = 'admin' and not exists (
       select 1 from public.location_access la
       where la.user_id = auth.uid() and la.tenant_id = v_tenant and la.deleted_at is null and la.position = 'manager'
     )) then
    raise exception 'only managers or warehouse staff can view warehouse pick lists' using errcode = '42501', hint = 'not_allowed';
  end if;

  select t.from_location_id into v_from_loc
  from public.transfers t
  where t.id = p_transfer_id and t.tenant_id = v_tenant;

  if v_from_loc is null then
    return null;
  end if;

  perform public.assert_location_access(v_from_loc);

  if public.auth_role() = 'admin' and not public.has_location_access(v_from_loc, 'manager') then
    raise exception 'only managers or warehouse staff can view warehouse pick lists' using errcode = '42501', hint = 'not_allowed';
  end if;

  select jsonb_build_object(
    'id', pl.id,
    'warehouse_id', pl.warehouse_id,
    'transfer_id', pl.transfer_id,
    'pick_list_no', pl.pick_list_no,
    'status', pl.status,
    'created_at', pl.created_at,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pli.id,
        'pick_list_id', pli.pick_list_id,
        'variant_id', pli.variant_id,
        'sku', pv.sku,
        'variant_name', pv.name,
        'product_name', p.name,
        'bin_id', pli.bin_id,
        'bin_code', b.code,
        'location_info', concat_ws('-', b.aisle, b.rack, b.shelf, b."position"),
        'qty_requested', pli.qty_requested,
        'qty_picked', pli.qty_picked,
        'short_reason', pli.short_reason
      ) order by coalesce(b.aisle, ''), coalesce(b.rack, ''), coalesce(b.shelf, ''), coalesce(b."position", ''), b.code)
      from public.pick_list_items pli
      join public.product_variants pv on pv.id = pli.variant_id
      join public.products p on p.id = pv.product_id
      join public.bins b on b.id = pli.bin_id
      where pli.pick_list_id = pl.id and pli.tenant_id = v_tenant
    ), '[]'::jsonb)
  )
  into v_result
  from public.pick_lists pl
  where pl.transfer_id = p_transfer_id and pl.tenant_id = v_tenant
  order by pl.created_at desc
  limit 1;

  return v_result;
end;
$function$;
revoke execute on function public.get_pick_list_for_transfer(uuid) from public, anon;
grant execute on function public.get_pick_list_for_transfer(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.create_transfer(p_from_location_id uuid, p_to_location_id uuid, p_notes text DEFAULT NULL::text, p_items jsonb DEFAULT '[]'::jsonb, p_ship_now boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant       uuid;
  v_role         text;
  v_transfer_id  uuid;
  v_transfer_no  text;
  v_status       text;
  v_item         jsonb;
  v_variant_id   uuid;
  v_qty          numeric;
  v_unit_cost    bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'supervisors and cashiers cannot create transfers' using errcode = '42501', hint = 'not_allowed';
  end if;

  if p_from_location_id = p_to_location_id then
    raise exception 'from and to locations must be different' using errcode = '22023', hint = 'invalid_argument';
  end if;

  perform public.assert_location_access(p_from_location_id);

  if public.auth_role() = 'admin' and not public.has_location_access(p_from_location_id, 'manager') then
    raise exception 'supervisors and cashiers cannot create transfers' using errcode = '42501', hint = 'not_allowed';
  end if;

  if not exists (
    select 1 from public.locations
    where id = p_to_location_id and tenant_id = v_tenant and active and deleted_at is null
  ) then
    raise exception 'destination location not found' using errcode = '22023', hint = 'location_not_found';
  end if;

  if exists (
    select 1 from public.locations l
    where l.tenant_id = v_tenant
      and l.id in (p_from_location_id, p_to_location_id)
      and l.type = 'warehouse'
  ) then
    perform public.assert_module('warehouse');
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'transfer must have at least one item' using errcode = '22023', hint = 'items_required';
  end if;

  v_transfer_id := public.uuid_generate_v7();
  v_transfer_no := public.next_transfer_no(v_tenant);
  v_status := case when p_ship_now then 'shipped' else 'draft' end;

  insert into public.transfers (
    id, tenant_id, transfer_no, from_location_id, to_location_id,
    status, notes, shipped_at, shipped_by, created_by
  ) values (
    v_transfer_id, v_tenant, v_transfer_no, p_from_location_id, p_to_location_id,
    v_status, p_notes, case when p_ship_now then now() else null end,
    case when p_ship_now then auth.uid() else null end, auth.uid()
  );

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_variant_id := (v_item ->> 'variant_id')::uuid;
    v_qty := (v_item ->> 'qty')::numeric;

    if v_qty is null or v_qty <= 0 then
      raise exception 'quantity must be greater than zero' using errcode = '22023', hint = 'qty_invalid';
    end if;

    if not exists (
      select 1 from public.product_variants
      where id = v_variant_id and tenant_id = v_tenant and active and deleted_at is null
    ) then
      raise exception 'product variant not found' using errcode = '22023', hint = 'unknown_variant';
    end if;

    insert into public.transfer_items (
      tenant_id, transfer_id, variant_id, qty_shipped
    ) values (
      v_tenant, v_transfer_id, v_variant_id, v_qty
    );

    if p_ship_now then
      select avg_cost into v_unit_cost
      from public.stock_levels
      where location_id = p_from_location_id and variant_id = v_variant_id;

      insert into public.stock_movements (
        tenant_id, location_id, variant_id, qty_delta, type,
        ref_type, ref_id, unit_cost, created_by
      ) values (
        v_tenant, p_from_location_id, v_variant_id, -v_qty, 'transfer_out',
        'transfer', v_transfer_id, v_unit_cost, auth.uid()
      );
    end if;
  end loop;

  if p_ship_now then
    perform public.write_audit('transfer.ship', 'transfer', v_transfer_id, p_from_location_id,
      jsonb_build_object('transfer_no', v_transfer_no, 'items_count', jsonb_array_length(p_items)));
  else
    perform public.write_audit('transfer.create', 'transfer', v_transfer_id, p_from_location_id,
      jsonb_build_object('transfer_no', v_transfer_no, 'items_count', jsonb_array_length(p_items)));
  end if;

  return v_transfer_id;
end;
$function$;
revoke execute on function public.create_transfer(uuid, uuid, text, jsonb, boolean) from public, anon;
grant execute on function public.create_transfer(uuid, uuid, text, jsonb, boolean) to authenticated;

CREATE OR REPLACE FUNCTION public.ship_transfer(p_transfer_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant   uuid;
  v_transfer record;
  v_item     record;
  v_unit_cost bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'supervisors and cashiers cannot ship transfers' using errcode = '42501', hint = 'not_allowed';
  end if;

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if exists (
    select 1 from public.locations l
    where l.tenant_id = v_tenant
      and l.id in (v_transfer.from_location_id, v_transfer.to_location_id)
      and l.type = 'warehouse'
  ) then
    perform public.assert_module('warehouse');
  end if;

  if v_transfer.status <> 'draft' then
    raise exception 'transfer is not in draft status' using errcode = '22023', hint = 'invalid_argument';
  end if;

  perform public.assert_location_access(v_transfer.from_location_id);

  if public.auth_role() = 'admin' and not public.has_location_access(v_transfer.from_location_id, 'manager') then
    raise exception 'supervisors and cashiers cannot ship transfers' using errcode = '42501', hint = 'not_allowed';
  end if;

  update public.transfers
  set status = 'shipped', shipped_at = now(), shipped_by = auth.uid(), updated_at = now()
  where id = p_transfer_id;

  for v_item in
    select variant_id, qty_shipped
    from public.transfer_items
    where transfer_id = p_transfer_id
  loop
    select avg_cost into v_unit_cost
    from public.stock_levels
    where location_id = v_transfer.from_location_id and variant_id = v_item.variant_id;

    insert into public.stock_movements (
      tenant_id, location_id, variant_id, qty_delta, type,
      ref_type, ref_id, unit_cost, created_by
    ) values (
      v_tenant, v_transfer.from_location_id, v_item.variant_id, -v_item.qty_shipped, 'transfer_out',
      'transfer', p_transfer_id, v_unit_cost, auth.uid()
    );
  end loop;

  perform public.write_audit('transfer.ship', 'transfer', p_transfer_id, v_transfer.from_location_id,
    jsonb_build_object('transfer_no', v_transfer.transfer_no));

  return p_transfer_id;
end;
$function$;
revoke execute on function public.ship_transfer(uuid) from public, anon;
grant execute on function public.ship_transfer(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.cancel_transfer(p_transfer_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant   uuid;
  v_transfer record;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse') then
    raise exception 'supervisors and cashiers cannot cancel transfers' using errcode = '42501', hint = 'not_allowed';
  end if;

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if exists (
    select 1 from public.locations l
    where l.tenant_id = v_tenant
      and l.id in (v_transfer.from_location_id, v_transfer.to_location_id)
      and l.type = 'warehouse'
  ) then
    perform public.assert_module('warehouse');
  end if;

  if v_transfer.status <> 'draft' then
    raise exception 'can only cancel draft transfers' using errcode = '22023', hint = 'invalid_argument';
  end if;

  perform public.assert_location_access(v_transfer.from_location_id);

  if public.auth_role() = 'admin' and not public.has_location_access(v_transfer.from_location_id, 'manager') then
    raise exception 'supervisors and cashiers cannot cancel transfers' using errcode = '42501', hint = 'not_allowed';
  end if;

  update public.transfers
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = auth.uid(),
      notes = case
        when p_reason is not null and btrim(p_reason) <> '' then
          coalesce(notes || E'\nCancellation reason: ' || p_reason, 'Cancellation reason: ' || p_reason)
        else notes
      end,
      updated_at = now()
  where id = p_transfer_id;

  perform public.write_audit('transfer.cancel', 'transfer', p_transfer_id, v_transfer.from_location_id,
    jsonb_build_object('transfer_no', v_transfer.transfer_no, 'reason', p_reason));

  return p_transfer_id;
end;
$function$;
revoke execute on function public.cancel_transfer(uuid, text) from public, anon;
grant execute on function public.cancel_transfer(uuid, text) to authenticated;

CREATE OR REPLACE FUNCTION public.list_transfer_destinations()
 RETURNS TABLE(id uuid, code text, name text, type text, address text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_wh_enabled boolean := false;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  if public.auth_role() not in ('superadmin', 'admin', 'warehouse')
     or (public.auth_role() = 'admin' and not exists (
       select 1 from public.location_access la
       where la.user_id = auth.uid()
         and la.tenant_id = public.auth_tenant_id()
         and la.deleted_at is null
         and la.position = 'manager'
     )) then
    raise exception 'supervisors and cashiers cannot manage transfers'
      using errcode = '42501', hint = 'not_allowed';
  end if;

  select coalesce(m.warehouse, false)
    into v_wh_enabled
  from public.tenant_modules m
  where m.tenant_id = public.auth_tenant_id();

  return query
  select l.id, l.code, l.name, l.type, l.address
  from public.locations l
  where l.tenant_id = public.auth_tenant_id()
    and l.active
    and l.deleted_at is null
    and (l.type <> 'warehouse' or v_wh_enabled)
  order by l.name;
end;
$function$;
revoke execute on function public.list_transfer_destinations() from public, anon;
grant execute on function public.list_transfer_destinations() to authenticated;

CREATE OR REPLACE FUNCTION public.receive_transfer(p_transfer_id uuid, p_items jsonb DEFAULT '[]'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tenant          uuid;
  v_transfer        record;
  v_item            jsonb;
  v_variant_id      uuid;
  v_qty_received    numeric;
  v_qty_shipped     numeric;
  v_has_discrepancy boolean := false;
  v_unit_cost       bigint;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');

  v_tenant := public.auth_tenant_id();

  select * into v_transfer
  from public.transfers
  where id = p_transfer_id and tenant_id = v_tenant
  for update;

  if not found then
    raise exception 'transfer not found' using errcode = '22023', hint = 'not_found';
  end if;

  if exists (
    select 1 from public.locations l
    where l.tenant_id = v_tenant
      and l.id in (v_transfer.from_location_id, v_transfer.to_location_id)
      and l.type = 'warehouse'
  ) then
    perform public.assert_module('warehouse');
  end if;

  if v_transfer.status <> 'shipped' then
    raise exception 'transfer is not in shipped status' using errcode = '22023', hint = 'invalid_argument';
  end if;

  perform public.assert_location_access(v_transfer.to_location_id);

  if exists (
    select 1 from public.locations l
    where l.id = v_transfer.to_location_id and l.tenant_id = v_tenant and l.type = 'warehouse'
  ) and not (
    public.is_superadmin()
    or public.auth_role() = 'warehouse'
    or (public.auth_role() = 'admin' and public.has_location_access(v_transfer.to_location_id, 'manager'))
  ) then
    raise exception 'only managers or warehouse staff can receive into a warehouse'
      using errcode = '42501', hint = 'not_allowed';
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'received items list required' using errcode = '22023', hint = 'items_required';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_variant_id := (v_item ->> 'variant_id')::uuid;
    v_qty_received := (v_item ->> 'qty_received')::numeric;

    if v_qty_received is null or v_qty_received < 0 then
      raise exception 'received quantity cannot be negative' using errcode = '22023', hint = 'qty_invalid';
    end if;

    select qty_shipped into v_qty_shipped
    from public.transfer_items
    where transfer_id = p_transfer_id and variant_id = v_variant_id;

    if not found then
      raise exception 'item not part of this transfer' using errcode = '22023', hint = 'unknown_variant';
    end if;

    if v_qty_received <> v_qty_shipped then
      v_has_discrepancy := true;
    end if;

    update public.transfer_items
    set qty_received = v_qty_received
    where transfer_id = p_transfer_id and variant_id = v_variant_id;

    if v_qty_received > 0 then
      select unit_cost into v_unit_cost
      from public.stock_movements
      where tenant_id = v_tenant and ref_type = 'transfer' and ref_id = p_transfer_id
        and location_id = v_transfer.from_location_id and variant_id = v_variant_id
        and type = 'transfer_out'
      order by occurred_at desc
      limit 1;

      insert into public.stock_movements (
        tenant_id, location_id, variant_id, qty_delta, type,
        ref_type, ref_id, unit_cost, created_by
      ) values (
        v_tenant, v_transfer.to_location_id, v_variant_id, v_qty_received, 'transfer_in',
        'transfer', p_transfer_id, v_unit_cost, auth.uid()
      );
    end if;
  end loop;

  update public.transfers
  set status = 'received', received_at = now(), received_by = auth.uid(),
      has_discrepancy = v_has_discrepancy, updated_at = now()
  where id = p_transfer_id;

  perform public.write_audit('transfer.receive', 'transfer', p_transfer_id, v_transfer.to_location_id,
    jsonb_build_object(
      'transfer_no', v_transfer.transfer_no,
      'has_discrepancy', v_has_discrepancy
    ));

  return p_transfer_id;
end;
$function$;
revoke execute on function public.receive_transfer(uuid, jsonb) from public, anon;
grant execute on function public.receive_transfer(uuid, jsonb) to authenticated;

drop policy if exists devices_insert_own on public.devices;
create policy devices_insert_own on public.devices
  for insert to authenticated
  with check (
    tenant_id = (select public.auth_tenant_id())
    and user_id = (select auth.uid())
    and (select public.is_active_user())
  );

drop policy if exists devices_update on public.devices;
create policy devices_update on public.devices
  for update to authenticated
  using (
    tenant_id = (select public.auth_tenant_id())
    and (select public.is_active_user())
    and (user_id = (select auth.uid()) or (select public.auth_role()) = 'superadmin')
  )
  with check (
    tenant_id = (select public.auth_tenant_id())
    and (select public.is_active_user())
    and (user_id = (select auth.uid()) or (select public.auth_role()) = 'superadmin')
  );
