-- Partial Item Returns / Refunds (Phase P-Retail+):
-- 1. Widen stock_movements_type_check with 'sale_return'
-- 2. Add immutable append-only sale_returns & sale_return_items tables with tenant-safe FKs and store-scoped RLS
-- 3. op_return_sale_items: pro-rata line & cart-discount refund math, stock restoration, utang ledger credit,
--    daily_sales_summary / daily_item_sales adjustment, cashier threshold + supervisor PIN escalation, audit log
-- 4. Guard op_void_sale against double-reversal when partial returns already exist
-- 5. Include cash refunds in shift_server_expected and wire 'return_sale_items' in sync_push

-- ---------------------------------------------------------------------------
-- 1. Sale item tenant composite key & stock_movements_type_check
-- ---------------------------------------------------------------------------

alter table public.sale_items
  add constraint sale_items_tenant_id unique (tenant_id, id);

alter table public.stock_movements drop constraint if exists stock_movements_type_check;
alter table public.stock_movements add constraint stock_movements_type_check
  check (type in ('opening', 'sale', 'sale_void', 'sale_return', 'receipt', 'count_correction', 'damage',
                  'conversion_out', 'conversion_in', 'conversion_void',
                  'transfer_out', 'transfer_in', 'bin_move'));

-- ---------------------------------------------------------------------------
-- 2. Append-only sale_returns & sale_return_items tables
-- ---------------------------------------------------------------------------

create table public.sale_returns (
  id               uuid primary key default public.uuid_generate_v7(),
  tenant_id        uuid not null references public.tenants (id) on delete cascade,
  location_id      uuid not null,
  sale_id          uuid not null,
  client_op_id     uuid not null,
  refund_method    text not null check (refund_method in ('cash', 'utang', 'ewallet', 'card')),
  subtotal_refund  bigint not null check (subtotal_refund >= 0),
  discount_refund  bigint not null default 0 check (discount_refund >= 0),
  tax_refund       bigint not null default 0 check (tax_refund >= 0),
  refund_total     bigint not null check (refund_total >= 0 and discount_refund <= subtotal_refund and refund_total = subtotal_refund - discount_refund),
  reason           text check (length(reason) <= 200),
  returned_at      timestamptz not null default now(),
  created_by       uuid references auth.users (id) on delete set null,
  approved_by      uuid references auth.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  constraint sale_returns_tenant_id unique (tenant_id, id),
  constraint sale_returns_tenant_id_loc unique (tenant_id, id, location_id),
  constraint sale_returns_client_op unique (tenant_id, client_op_id),
  constraint sale_returns_sale_fk foreign key (tenant_id, sale_id, location_id)
    references public.sales (tenant_id, id, location_id)
);

create index sale_returns_tenant_sale_idx on public.sale_returns (tenant_id, sale_id, returned_at desc);
create index sale_returns_tenant_loc_idx  on public.sale_returns (tenant_id, location_id, returned_at desc);

create trigger sale_returns_append_only before update or delete on public.sale_returns
  for each row execute function public.reject_ledger_change();

create table public.sale_return_items (
  id             uuid primary key default public.uuid_generate_v7(),
  tenant_id      uuid not null references public.tenants (id) on delete cascade,
  return_id      uuid not null,
  sale_id        uuid not null,
  sale_item_id   uuid not null,
  location_id    uuid not null,
  variant_id     uuid not null,
  product_name   text not null check (length(product_name) between 1 and 120),
  qty            numeric(12, 3) not null check (qty > 0),
  unit_price     bigint not null check (unit_price >= 0),
  unit_cost      bigint not null default 0 check (unit_cost >= 0),
  refund_amount  bigint not null check (refund_amount >= 0),
  tax_refund     bigint not null default 0 check (tax_refund >= 0),
  created_at     timestamptz not null default now(),
  constraint sale_return_items_return_fk foreign key (tenant_id, return_id, location_id)
    references public.sale_returns (tenant_id, id, location_id),
  constraint sale_return_items_sale_fk foreign key (tenant_id, sale_id, location_id)
    references public.sales (tenant_id, id, location_id),
  constraint sale_return_items_item_fk foreign key (tenant_id, sale_item_id)
    references public.sale_items (tenant_id, id),
  constraint sale_return_items_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id)
);

create index sale_return_items_tenant_sale_idx   on public.sale_return_items (tenant_id, sale_id);
create index sale_return_items_tenant_return_idx on public.sale_return_items (tenant_id, return_id);

create trigger sale_return_items_append_only before update or delete on public.sale_return_items
  for each row execute function public.reject_ledger_change();

alter table public.sale_returns       enable row level security;
alter table public.sale_return_items  enable row level security;

create policy sale_returns_store_read on public.sale_returns
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and location_id = any ((select public.auth_location_ids())::uuid[]));

create policy sale_return_items_store_read on public.sale_return_items
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and location_id = any ((select public.auth_location_ids())::uuid[]));

revoke all on public.sale_returns, public.sale_return_items from anon;
revoke insert, update, delete, truncate on public.sale_returns, public.sale_return_items from authenticated;
grant select on public.sale_returns, public.sale_return_items to authenticated;

-- ---------------------------------------------------------------------------
-- 3. op_return_sale_items
-- ---------------------------------------------------------------------------

create or replace function public.op_return_sale_items(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant           uuid;
  v_replay           jsonb;
  v_sale             public.sales;
  v_sid              uuid;
  v_return_id        uuid;
  v_method           text;
  v_reason           text;
  v_returned_at      timestamptz;
  v_is_super         boolean;
  v_can_void_own     boolean;
  v_max_void_amt     bigint;
  v_tz               text;
  v_day              date;
  v_appr             uuid := null;
  v_item             jsonb;
  v_vid              uuid;
  v_req_qty          numeric;
  v_sold_qty         numeric;
  v_prev_qty         numeric;
  v_rem_qty          numeric;
  v_take             numeric;
  v_si               record;
  v_si_prev_qty      numeric;
  v_si_prev_sub      bigint;
  v_si_prev_tax      bigint;
  v_line_sub         bigint;
  v_line_disc        bigint;
  v_line_tax         bigint;
  v_line_ref         bigint;
  v_sub_refund       bigint := 0;
  v_disc_refund      bigint := 0;
  v_tax_refund       bigint := 0;
  v_total_refund     bigint := 0;
  v_cogs_refund      bigint := 0;
  v_prev_sub_all     bigint := 0;
  v_prev_disc_all    bigint := 0;
  v_prev_tax_all     bigint := 0;
  v_prev_ref_all     bigint := 0;
  v_total_sold_units numeric := 0;
  v_total_prev_units numeric := 0;
  v_total_req_units  numeric := 0;
  v_track            boolean;
  v_seen_variants    uuid[] := '{}'::uuid[];
begin
  perform public.assert_seller();
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object'
     or jsonb_typeof(p -> 'items') is distinct from 'array' then
    raise exception 'return payload must be an object with items' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'return_sale_items');
  if v_replay is not null then
    return v_replay;
  end if;

  v_sid := (p ->> 'sale_id')::uuid;
  if v_sid is null then
    raise exception 'sale_id is required' using errcode = '22023', hint = 'id_required';
  end if;

  select * into v_sale from public.sales where id = v_sid and tenant_id = v_tenant for update;
  if not found then
    raise exception 'sale not found' using errcode = '22023', hint = 'sale_not_found';
  end if;

  if not public.has_location_access(v_sale.location_id) then
    raise exception 'not allowed to return sales here' using errcode = '42501', hint = 'not_allowed';
  end if;

  if v_sale.status = 'voided' then
    raise exception 'cannot return items from a voided sale' using errcode = '22023', hint = 'sale_voided';
  end if;

  v_method := coalesce(nullif(btrim(p ->> 'refund_method'), ''), 'cash');
  if v_method not in ('cash', 'utang', 'ewallet', 'card') then
    raise exception 'invalid refund method' using errcode = '22023', hint = 'invalid_value';
  end if;
  if v_method = 'utang' and v_sale.customer_id is null then
    raise exception 'utang refund requires a customer on the sale' using errcode = '22023', hint = 'customer_required';
  end if;

  if jsonb_array_length(p -> 'items') not between 1 and 200 then
    raise exception 'a return needs 1 to 200 items' using errcode = '22023', hint = 'items_required';
  end if;

  v_reason := left(nullif(btrim(p ->> 'reason'), ''), 200);
  v_returned_at := coalesce((p ->> 'returned_at')::timestamptz, now());
  v_return_id := coalesce((p ->> 'id')::uuid, public.uuid_generate_v7());

  -- Pre-validate all requested lines & compute aggregate quantities
  for v_item in select * from jsonb_array_elements(p -> 'items') loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_req_qty := (v_item ->> 'qty')::numeric;
    if v_vid is null or v_req_qty is null or v_req_qty <= 0 or v_req_qty >= 1000000000 then
      raise exception 'return quantity must be above zero' using errcode = '22023', hint = 'qty_invalid';
    end if;
    if v_vid = any(v_seen_variants) then
      raise exception 'duplicate variant in return payload' using errcode = '22023', hint = 'invalid_value';
    end if;
    v_seen_variants := array_append(v_seen_variants, v_vid);

    select coalesce(sum(qty), 0) into v_sold_qty
      from public.sale_items
     where tenant_id = v_tenant and sale_id = v_sid and variant_id = v_vid;
    if v_sold_qty <= 0 then
      raise exception 'item was not part of this sale' using errcode = '22023', hint = 'unknown_variant';
    end if;

    select coalesce(sum(qty), 0) into v_prev_qty
      from public.sale_return_items
     where tenant_id = v_tenant and sale_id = v_sid and variant_id = v_vid;

    if v_prev_qty + v_req_qty > v_sold_qty then
      raise exception 'return quantity exceeds remaining sold quantity' using errcode = '22023', hint = 'return_exceeds_sold';
    end if;

    v_total_req_units := v_total_req_units + v_req_qty;
  end loop;

  select coalesce(sum(qty), 0) into v_total_sold_units
    from public.sale_items where tenant_id = v_tenant and sale_id = v_sid;
  select coalesce(sum(subtotal_refund), 0), coalesce(sum(discount_refund), 0),
         coalesce(sum(tax_refund), 0), coalesce(sum(refund_total), 0)
    into v_prev_sub_all, v_prev_disc_all, v_prev_tax_all, v_prev_ref_all
    from public.sale_returns where tenant_id = v_tenant and sale_id = v_sid;
  select coalesce(sum(qty), 0) into v_total_prev_units
    from public.sale_return_items where tenant_id = v_tenant and sale_id = v_sid;

  -- Temp staging table for computed return lines before header insert
  create temp table if not exists _ret_lines (
    sale_item_id  uuid,
    variant_id    uuid,
    product_name  text,
    qty           numeric(12, 3),
    unit_price    bigint,
    unit_cost     bigint,
    line_sub      bigint,
    line_disc     bigint,
    line_tax      bigint,
    line_ref      bigint,
    track_stock   boolean
  ) on commit drop;
  truncate table _ret_lines;

  for v_item in select * from jsonb_array_elements(p -> 'items') loop
    v_vid := (v_item ->> 'variant_id')::uuid;
    v_rem_qty := (v_item ->> 'qty')::numeric;

    select pr.track_stock into v_track
      from public.product_variants pv
      join public.products pr on pr.tenant_id = pv.tenant_id and pr.id = pv.product_id
     where pv.tenant_id = v_tenant and pv.id = v_vid;
    v_track := coalesce(v_track, false);

    for v_si in
      select * from public.sale_items
       where tenant_id = v_tenant and sale_id = v_sid and variant_id = v_vid
       order by created_at, id
    loop
      exit when v_rem_qty <= 0;

      select coalesce(sum(qty), 0), coalesce(sum(tax_refund), 0)
        into v_si_prev_qty, v_si_prev_tax
        from public.sale_return_items
       where tenant_id = v_tenant and sale_item_id = v_si.id;

      if v_si_prev_qty >= v_si.qty then
        continue;
      end if;

      v_take := least(v_rem_qty, v_si.qty - v_si_prev_qty);

      -- Pro-rata line subtotal (before cart-level discount)
      if v_si_prev_qty + v_take = v_si.qty then
        -- Compute previous line_sub for exact remainder
        v_si_prev_sub := round(v_si.line_total * (v_si_prev_qty / v_si.qty))::bigint;
        v_line_sub := greatest(0, v_si.line_total - v_si_prev_sub);
        v_line_tax := greatest(0, v_si.tax - v_si_prev_tax);
      else
        v_line_sub := round(v_si.line_total * (v_take / v_si.qty))::bigint;
        v_line_tax := round(v_si.tax * (v_take / v_si.qty))::bigint;
      end if;

      if v_sale.subtotal > 0 and v_sale.discount > 0 then
        v_line_disc := least(v_line_sub, round(v_sale.discount * (v_line_sub::numeric / v_sale.subtotal))::bigint);
      else
        v_line_disc := 0;
      end if;
      v_line_ref := greatest(0, v_line_sub - v_line_disc);

      insert into _ret_lines (sale_item_id, variant_id, product_name, qty, unit_price, unit_cost,
                              line_sub, line_disc, line_tax, line_ref, track_stock)
      values (v_si.id, v_vid, v_si.product_name, v_take, v_si.unit_price, v_si.unit_cost,
              v_line_sub, v_line_disc, v_line_tax, v_line_ref, v_track);

      v_sub_refund := v_sub_refund + v_line_sub;
      v_disc_refund := v_disc_refund + v_line_disc;
      v_tax_refund := v_tax_refund + v_line_tax;
      v_total_refund := v_total_refund + v_line_ref;
      v_cogs_refund := v_cogs_refund + round(v_si.unit_cost * v_take)::bigint;
      v_rem_qty := v_rem_qty - v_take;
    end loop;
  end loop;

  -- Exact penny reconciliation when all remaining units on the sale are now returned
  if v_total_prev_units + v_total_req_units = v_total_sold_units then
    v_sub_refund := greatest(0, v_sale.subtotal - v_prev_sub_all);
    v_disc_refund := least(v_sub_refund, greatest(0, v_sale.discount - v_prev_disc_all));
    v_tax_refund := greatest(0, v_sale.tax - v_prev_tax_all);
    v_total_refund := v_sub_refund - v_disc_refund;
  end if;

  -- Permission & supervisor PIN check (mirrors op_void_sale)
  select coalesce(timezone, 'Asia/Manila') into v_tz from public.tenants where id = v_tenant;
  v_is_super := public.has_location_access(v_sale.location_id, 'supervisor');

  if not v_is_super then
    if public.auth_role() is distinct from 'cashier' then
      raise exception 'not allowed to return sales here' using errcode = '42501', hint = 'not_allowed';
    end if;

    select coalesce(cashier_can_void_own, false), coalesce(max_cashier_void_amount, 50000)
      into v_can_void_own, v_max_void_amt
      from public.tenant_settings
     where tenant_id = v_tenant;

    if v_sale.created_by is distinct from auth.uid() then
      raise exception 'cashier may only return own sales' using errcode = '42501', hint = 'not_allowed';
    end if;

    if (v_sale.sold_at at time zone v_tz)::date <> (now() at time zone v_tz)::date then
      raise exception 'cashier can only return sales from today' using errcode = '42501', hint = 'not_allowed';
    end if;

    if (not v_can_void_own) or (v_total_refund > v_max_void_amt) or (p ->> 'approval_id') is not null or (p -> 'offline_approval') is not null then
      v_appr := public.consume_supervisor_approval(v_sale.location_id, 'void_sale', v_sid, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval');
    end if;
  elsif (p ->> 'approval_id') is not null or (p -> 'offline_approval') is not null then
    v_appr := public.consume_supervisor_approval(v_sale.location_id, 'void_sale', v_sid, (p ->> 'approval_id')::uuid, p_op_id, p -> 'offline_approval');
  end if;

  insert into public.sale_returns (
    id, tenant_id, location_id, sale_id, client_op_id, refund_method,
    subtotal_refund, discount_refund, tax_refund, refund_total,
    reason, returned_at, created_by, approved_by
  ) values (
    v_return_id, v_tenant, v_sale.location_id, v_sid, p_op_id, v_method,
    v_sub_refund, v_disc_refund, v_tax_refund, v_total_refund,
    v_reason, v_returned_at, auth.uid(), v_appr
  );

  insert into public.sale_return_items (
    tenant_id, return_id, sale_id, sale_item_id, location_id, variant_id,
    product_name, qty, unit_price, unit_cost, refund_amount, tax_refund
  )
  select v_tenant, v_return_id, v_sid, r.sale_item_id, v_sale.location_id, r.variant_id,
         r.product_name, r.qty, r.unit_price, r.unit_cost, r.line_ref, r.line_tax
    from _ret_lines r;

  -- Restore stock for tracked items
  insert into public.stock_movements (
    tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id,
    unit_cost, occurred_at, created_by
  )
  select v_tenant, v_sale.location_id, r.variant_id, sum(r.qty), 'sale_return', 'sale_return', v_return_id,
         max(r.unit_cost), v_returned_at, auth.uid()
    from _ret_lines r
   where r.track_stock
   group by r.variant_id;

  -- Credit customer utang balance when refunded to utang
  if v_method = 'utang' and v_total_refund > 0 and v_sale.customer_id is not null then
    insert into public.customer_ledger (
      tenant_id, customer_id, kind, amount, sale_id, note, occurred_at, created_by, location_id
    ) values (
      v_tenant, v_sale.customer_id, 'adjust', -v_total_refund, v_sid,
      coalesce(v_reason, 'return'), v_returned_at, auth.uid(), v_sale.location_id
    );
  end if;

  -- Adjust daily_sales_summary & daily_item_sales on return business day
  v_day := (v_returned_at at time zone v_tz)::date;

  insert into public.daily_sales_summary as d
    (tenant_id, location_id, day, gross, discount, net, tax, cogs, txn_count, cash, ewallet, card, utang, updated_at)
  values (
    v_tenant, v_sale.location_id, v_day,
    -v_sub_refund, -v_disc_refund, -v_total_refund, -v_tax_refund, -v_cogs_refund, 0,
    case when v_method = 'cash'    then -v_total_refund else 0 end,
    case when v_method = 'ewallet' then -v_total_refund else 0 end,
    case when v_method = 'card'    then -v_total_refund else 0 end,
    case when v_method = 'utang'   then -v_total_refund else 0 end,
    now()
  )
  on conflict (location_id, day) do update set
    gross = d.gross + excluded.gross,
    discount = d.discount + excluded.discount,
    net = d.net + excluded.net,
    tax = d.tax + excluded.tax,
    cogs = d.cogs + excluded.cogs,
    cash = d.cash + excluded.cash,
    ewallet = d.ewallet + excluded.ewallet,
    card = d.card + excluded.card,
    utang = d.utang + excluded.utang,
    updated_at = now();

  insert into public.daily_item_sales as d (tenant_id, location_id, day, variant_id, product_name, qty, revenue, cogs)
  select v_tenant, v_sale.location_id, v_day, r.variant_id, max(r.product_name),
         -sum(r.qty), -sum(r.line_ref)::bigint, -sum(round(r.unit_cost * r.qty))::bigint
    from _ret_lines r
   group by r.variant_id
  on conflict (location_id, day, variant_id) do update set
    qty = d.qty + excluded.qty,
    revenue = d.revenue + excluded.revenue,
    cogs = d.cogs + excluded.cogs;

  perform public.write_audit(
    'sale.return', 'sale_return', v_return_id, v_sale.location_id,
    jsonb_strip_nulls(jsonb_build_object(
      'sale_id', v_sid,
      'no', coalesce(v_sale.sale_no, v_sale.local_no),
      'refund_total', v_total_refund,
      'refund_method', v_method,
      'approved_by', v_appr
    ))
  );

  return public.finish_op(
    p_op_id,
    jsonb_build_object(
      'return_id', v_return_id,
      'sale_id', v_sid,
      'refund_total', v_total_refund,
      'refund_method', v_method,
      'applied_at', now()
    )
  );
end;
$$;

revoke execute on function public.op_return_sale_items(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Guard op_void_sale when partial returns already exist
-- ---------------------------------------------------------------------------

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

  if not public.has_location_access(v_sale.location_id) then
    raise exception 'not allowed to cancel sales here' using errcode = '42501', hint = 'not_allowed';
  end if;

  v_is_super := public.has_location_access(v_sale.location_id, 'supervisor');

  if not v_is_super then
    if public.auth_role() is distinct from 'cashier' then
      raise exception 'not allowed to cancel sales here' using errcode = '42501', hint = 'not_allowed';
    end if;

    select cashier_can_void_own, max_cashier_void_amount
      into v_can_void_own, v_max_void_amt
      from public.tenant_settings
     where tenant_id = v_tenant;
    v_can_void_own := coalesce(v_can_void_own, false);
    v_max_void_amt := coalesce(v_max_void_amt, 50000);

    if v_sale.created_by is distinct from auth.uid() then
      raise exception 'cashier may only void own sales' using errcode = '42501', hint = 'not_allowed';
    end if;

    select timezone into v_tz from public.tenants where id = v_tenant;
    v_tz := coalesce(v_tz, 'Asia/Manila');
    if (v_sale.sold_at at time zone v_tz)::date <> (now() at time zone v_tz)::date then
      raise exception 'can only void sales from today' using errcode = '42501', hint = 'not_allowed';
    end if;

    if not v_can_void_own and (p ->> 'approval_id') is null and (p -> 'offline_approval') is null then
      raise exception 'not allowed to cancel sales here' using errcode = '42501', hint = 'not_allowed';
    end if;
  end if;

  if v_sale.status = 'voided' then
    return public.finish_op(p_op_id, jsonb_build_object('sale_id', v_sid, 'already', true, 'applied_at', now()));
  end if;

  if exists (select 1 from public.sale_returns where tenant_id = v_tenant and sale_id = v_sid) then
    raise exception 'sale has partial returns; return remaining items instead' using errcode = '22023', hint = 'has_partial_returns';
  end if;

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

-- ---------------------------------------------------------------------------
-- 5. Include cash returns in shift_server_expected & register in sync_push
-- ---------------------------------------------------------------------------

create or replace function public.shift_server_expected(
  p_tenant uuid,
  p_location_id uuid,
  p_cashier uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_opening bigint
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_sales bigint;
  v_utang bigint;
  v_exp   bigint;
  v_ret   bigint;
  v_svc   bigint;
begin
  select coalesce(sum(p.amount), 0) into v_sales
  from public.sales s
  join public.payments p on p.sale_id = s.id and p.tenant_id = s.tenant_id
  where s.tenant_id = p_tenant and s.location_id = p_location_id and s.created_by = p_cashier and s.status = 'completed'
    and s.sold_at >= p_from and s.sold_at <= p_to and p.method = 'cash';

  select coalesce(-sum(l.amount), 0) into v_utang
  from public.customer_ledger l
  where l.tenant_id = p_tenant and l.kind = 'payment' and l.method = 'cash' and l.location_id = p_location_id
    and l.created_by = p_cashier and l.occurred_at >= p_from and l.occurred_at <= p_to;

  select coalesce(sum(e.amount), 0) into v_exp
  from public.expenses e
  where e.tenant_id = p_tenant and e.location_id = p_location_id and e.created_by = p_cashier
    and e.voided_at is null and e.paid_from = 'cash' and e.spent_at >= p_from and e.spent_at <= p_to;

  select coalesce(sum(sr.refund_total), 0) into v_ret
  from public.sale_returns sr
  where sr.tenant_id = p_tenant and sr.location_id = p_location_id and sr.created_by = p_cashier
    and sr.refund_method = 'cash' and sr.returned_at >= p_from and sr.returned_at <= p_to;

  select coalesce(sum(public.service_cash_effect(t.kind, t.amount, t.fee, t.price)), 0) into v_svc
  from public.service_txns t
  where t.tenant_id = p_tenant and t.location_id = p_location_id and t.created_by = p_cashier
    and t.voided_at is null and t.txn_at >= p_from and t.txn_at <= p_to;

  return p_opening + v_sales + v_utang - v_exp - v_ret + v_svc;
end;
$$;

revoke execute on function public.shift_server_expected(uuid, uuid, uuid, timestamptz, timestamptz, bigint) from public, anon, authenticated;

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
  v_loc_text   text;
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
        when 'record_sale'              then public.op_record_sale(v_id, o -> 'payload')
        when 'void_sale'                then public.op_void_sale(v_id, o -> 'payload')
        when 'return_sale_items'        then public.op_return_sale_items(v_id, o -> 'payload')
        when 'upsert_customer'          then public.op_upsert_customer(v_id, o -> 'payload')
        when 'record_utang_payment'     then public.op_record_utang_payment(v_id, o -> 'payload')
        when 'post_opening_stock'       then public.op_post_opening_stock(v_id, o -> 'payload')
        when 'receive_stock'            then public.op_receive_stock(v_id, o -> 'payload')
        when 'receive_warehouse_stock'  then public.op_receive_warehouse_stock(v_id, o -> 'payload')
        when 'receive_po'               then public.op_receive_po(v_id, o -> 'payload')
        when 'receive_without_po'      then public.op_receive_without_po(v_id, o -> 'payload')
        when 'adjust_stock'             then public.op_adjust_stock(v_id, o -> 'payload')
        when 'adjust_utang'             then public.op_adjust_utang(v_id, o -> 'payload')
        when 'record_expense'           then public.op_record_expense(v_id, o -> 'payload')
        when 'void_expense'             then public.op_void_expense(v_id, o -> 'payload')
        when 'close_day'                then public.op_close_day(v_id, o -> 'payload')
        when 'record_service_txn'       then public.op_record_service_txn(v_id, o -> 'payload')
        when 'void_service_txn'         then public.op_void_service_txn(v_id, o -> 'payload')
        when 'set_tingi_link'           then public.op_set_tingi_link(v_id, o -> 'payload')
        when 'open_pack'                then public.op_open_pack(v_id, o -> 'payload')
        when 'void_open_pack'           then public.op_void_open_pack(v_id, o -> 'payload')
        when 'set_utang_due'            then public.op_set_utang_due(v_id, o -> 'payload')
        when 'set_expiry'               then public.op_set_expiry(v_id, o -> 'payload')
        when 'open_shift'               then public.op_open_shift(v_id, o -> 'payload')
        when 'close_shift'              then public.op_close_shift(v_id, o -> 'payload')
        when 'start_count'              then public.op_start_count(v_id, o -> 'payload')
        when 'record_count'             then public.op_record_count(v_id, o -> 'payload')
        when 'close_count'              then public.op_close_count(v_id, o -> 'payload')
        when 'cancel_count'             then public.op_cancel_count(v_id, o -> 'payload')
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
        v_out := v_out || jsonb_build_object('op_id', v_id, 'status', 'error', 'code', v_state);
        return v_out;
      end if;

      v_audit_hint := coalesce(nullif(v_hint, ''), case v_state
        when '22P02' then 'invalid_value' when '22003' then 'invalid_value' when '22007' then 'invalid_value'
        when '23503' then 'unknown_reference' when '23514' then 'invalid_value'
        when '23505' then 'id_conflict' when '42501' then 'not_allowed'
        else 'rejected' end);

      begin
        v_loc_text := coalesce(o -> 'payload' ->> 'location_id', o -> 'payload' ->> 'warehouse_id');
        if v_loc_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
          v_op_loc := v_loc_text::uuid;
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
            'hint', v_audit_hint,
            'state', v_state,
            'payload', o -> 'payload'
          )
        );
      exception when others then
        null;
      end;

      v_out := v_out || jsonb_build_object(
        'op_id', v_id,
        'status', 'rejected',
        'hint', coalesce(nullif(v_hint, ''), 'rejected'),
        'code', v_state
      );
    end;
  end loop;

  return v_out;
end;
$$;

revoke execute on function public.sync_push(jsonb) from public, anon;
grant execute on function public.sync_push(jsonb) to authenticated;
