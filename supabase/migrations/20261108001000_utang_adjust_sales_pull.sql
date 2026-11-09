-- Gaps B5 and A6.
--   op_adjust_utang   write off or correct a customer's balance (ledger kind 'adjust'); through sync_push
--   sync_pull_sales   recent sales with their lines and payments, so a new or reinstalled phone has its receipts and "Today"
-- Both follow the existing patterns (claim_op / finish_op idempotency; keyset pull with the 5 s hold-back, runs as the caller).

-- ---------------------------------------------------------------------------
-- op_adjust_utang   p = { customer_id, amount (signed, not 0: positive = owes more, negative = owes less), note? }
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

  v_cust := (p ->> 'customer_id')::uuid;
  v_amt := (p ->> 'amount')::bigint;
  if v_amt is null or v_amt = 0 then
    raise exception 'amount must not be zero' using errcode = '22023', hint = 'amount_invalid';
  end if;
  if not exists (select 1 from public.customers c where c.id = v_cust and c.tenant_id = v_tenant) then
    raise exception 'unknown customer' using errcode = '22023', hint = 'unknown_customer';
  end if;

  insert into public.customer_ledger (tenant_id, customer_id, kind, amount, note, occurred_at, created_by)
  values (v_tenant, v_cust, 'adjust', v_amt, left(nullif(btrim(p ->> 'note'), ''), 200),
          coalesce((p ->> 'occurred_at')::timestamptz, now()), auth.uid());

  perform public.write_audit('utang.adjust', 'customer', v_cust, null, jsonb_build_object('amount', v_amt));
  return public.finish_op(p_op_id, jsonb_build_object('customer_id', v_cust, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_adjust_utang(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_sales(cursor, limit)
--   p_cursor = { ts, k } of the last row received, or null for the first pull (then only the last 30 days).
--   Returns { rows: [ { id, local_no, status, subtotal, discount, tax, total, customer_id, sold_at, voided_at, void_reason,
--                       updated_at, items: [...], payments: [...] } ], cursor, has_more, server_time }.
--   A cancelled sale comes again (its updated_at moves), so devices see cancels made elsewhere.
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
                    'method', p.method, 'amount', p.amount, 'tendered', p.tendered, 'reference', p.reference)
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

-- sync_push re-created with the adjust_utang kind

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
        when 'receive_stock'       then public.op_receive_stock(v_id, o -> 'payload')
        when 'adjust_stock'        then public.op_adjust_stock(v_id, o -> 'payload')
        when 'adjust_utang'        then public.op_adjust_utang(v_id, o -> 'payload')
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

revoke execute on function public.sync_push(jsonb) from public, anon;
grant execute on function public.sync_push(jsonb) to authenticated;
