-- P2-02 Catalog writes and delta pull.
--   processed_ops      idempotency ledger for every outbox op (plan section 7), keyed per tenant
--   upsert_product     product + default variant + base price in one call; safe to retry with the same op id
--   archive_product    soft delete of a product, its variants and prices
--   sync_pull_catalog  keyset-paged delta pull per table, tombstones included
-- Permission (plan section 5, catalog.manage): superadmin and admins who manage at least one store: full;
-- warehouse: cost and SKU of existing products only; everyone else: no writes.

-- ---------------------------------------------------------------------------
-- processed_ops: (tenant_id, client_op_id) so one tenant can never read or block another tenant's op ids
-- ---------------------------------------------------------------------------

create table public.processed_ops (
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  client_op_id  uuid not null,
  kind          text not null check (length(kind) between 1 and 40),
  user_id       uuid references auth.users (id) on delete set null,
  result        jsonb check (pg_column_size(result) <= 2048),
  processed_at  timestamptz not null default now(),
  primary key (tenant_id, client_op_id)
);

comment on table public.processed_ops is
  'Outbox idempotency. A replayed client_op_id returns the stored result instead of applying twice. Server-only.';

alter table public.processed_ops enable row level security;
revoke all on public.processed_ops from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Helpers (not callable by clients)
-- ---------------------------------------------------------------------------

-- 'full' | 'cost_sku' | null for the current user
create or replace function public.catalog_write_mode()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if public.auth_tenant_id() is null then
    return null;
  end if;
  if public.is_superadmin() then
    return 'full';
  end if;
  if public.auth_role() = 'admin' and exists (
       select 1
       from public.location_access la
       join public.locations l on l.id = la.location_id
       where la.user_id = auth.uid()
         and la.tenant_id = public.auth_tenant_id()
         and la.position = 'manager'
         and la.deleted_at is null
         and l.deleted_at is null
         and l.active) then
    return 'full';
  end if;
  if public.auth_role() = 'warehouse' then
    return 'cost_sku';
  end if;
  return null;
end;
$$;

-- Claims an op id for this tenant. Returns null when newly claimed, else the stored result of the earlier run.
-- A concurrent duplicate waits on the primary key until the first one commits or rolls back.
create or replace function public.claim_op(p_op_id uuid, p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_kind   text;
  v_result jsonb;
begin
  if p_op_id is null then
    raise exception 'client op id is required' using errcode = '22023', hint = 'op_id_required';
  end if;

  insert into public.processed_ops (tenant_id, client_op_id, kind, user_id)
    values (v_tenant, p_op_id, p_kind, auth.uid())
    on conflict do nothing;
  if found then
    return null;
  end if;

  select o.kind, o.result into v_kind, v_result
  from public.processed_ops o
  where o.tenant_id = v_tenant and o.client_op_id = p_op_id;

  if v_kind <> p_kind then
    raise exception 'op id already used for %', v_kind using errcode = '22023', hint = 'op_id_reused';
  end if;
  return coalesce(v_result, '{}'::jsonb) || jsonb_build_object('replay', true);
end;
$$;

create or replace function public.finish_op(p_op_id uuid, p_result jsonb)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  update public.processed_ops
     set result = p_result, processed_at = now()
   where tenant_id = public.auth_tenant_id() and client_op_id = p_op_id;
  select p_result || jsonb_build_object('replay', false);
$$;

revoke execute on function public.catalog_write_mode() from public, anon, authenticated;
revoke execute on function public.claim_op(uuid, text) from public, anon, authenticated;
revoke execute on function public.finish_op(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- upsert_product
--   p_product = { id, name, category_id?, unit?, tax_rate?, track_stock?, active?, photo_path?, price?,
--                 variant: { id, sku?, barcode?, cost?, reorder_point?, active? } }
--   price is base-currency minor units and is required on create. Missing keys keep their current value on update.
--   Returns { product_id, variant_id, sku, created, replay }.
-- ---------------------------------------------------------------------------

create or replace function public.upsert_product(p_op_id uuid, p_product jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_mode     text;
  v_replay   jsonb;
  p          jsonb := p_product;
  v          jsonb := coalesce(p_product -> 'variant', '{}'::jsonb);
  v_pid      uuid;
  v_vid      uuid;
  v_prod     public.products;
  v_var      public.product_variants;
  v_created  boolean;
  v_base     char(3);
  v_sku      text;
  v_con      text;
  v_result   jsonb;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  v_mode := public.catalog_write_mode();
  if v_mode is null then
    raise exception 'not allowed to change the catalog' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' or jsonb_typeof(v) is distinct from 'object' then
    raise exception 'product must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'upsert_product');
  if v_replay is not null then
    return v_replay;
  end if;

  v_pid := (p ->> 'id')::uuid;
  v_vid := (v ->> 'id')::uuid;
  if v_pid is null or v_vid is null then
    raise exception 'product id and variant id are required' using errcode = '22023', hint = 'id_required';
  end if;

  select * into v_prod from public.products where id = v_pid and tenant_id = v_tenant for update;
  v_created := not found;
  select t.base_currency into v_base from public.tenants t where t.id = v_tenant;

  begin
    if v_created then
      if v_mode <> 'full' then
        raise exception 'warehouse can only change cost and SKU' using errcode = '42501', hint = 'cost_and_sku_only';
      end if;
      if nullif(btrim(p ->> 'name'), '') is null then
        raise exception 'name is required' using errcode = '22023', hint = 'name_required';
      end if;
      if (p ->> 'price') is null then
        raise exception 'price is required' using errcode = '22023', hint = 'price_required';
      end if;

      v_sku := coalesce(nullif(btrim(v ->> 'sku'), ''),
                        'P-' || upper(substr(replace(v_vid::text, '-', ''), 21, 12)));

      insert into public.products (id, tenant_id, category_id, name, unit, tax_rate, track_stock, active, photo_path)
      values (
        v_pid, v_tenant, (p ->> 'category_id')::uuid, btrim(p ->> 'name'),
        coalesce(nullif(btrim(p ->> 'unit'), ''), 'pc'),
        coalesce((p ->> 'tax_rate')::numeric, 0),
        coalesce((p ->> 'track_stock')::boolean, true),
        coalesce((p ->> 'active')::boolean, true),
        p ->> 'photo_path');

      insert into public.product_variants (id, tenant_id, product_id, sku, barcode, is_default, cost, reorder_point, active)
      values (
        v_vid, v_tenant, v_pid, v_sku, nullif(btrim(v ->> 'barcode'), ''), true,
        coalesce((v ->> 'cost')::bigint, 0),
        coalesce((v ->> 'reorder_point')::numeric, 0),
        coalesce((v ->> 'active')::boolean, true));
    else
      if v_prod.deleted_at is not null then
        raise exception 'product is archived' using errcode = 'P0001', hint = 'product_archived';
      end if;

      select * into v_var from public.product_variants
       where tenant_id = v_tenant and product_id = v_pid and is_default and deleted_at is null
       for update;
      if v_var.id is distinct from v_vid then
        raise exception 'variant id does not match the default variant' using errcode = '22023', hint = 'variant_mismatch';
      end if;

      if v_mode = 'cost_sku' and ((p - 'id' - 'variant') <> '{}'::jsonb or (v - 'id' - 'sku' - 'cost') <> '{}'::jsonb) then
        raise exception 'warehouse can only change cost and SKU' using errcode = '42501', hint = 'cost_and_sku_only';
      end if;
      if p ? 'name' and nullif(btrim(p ->> 'name'), '') is null then
        raise exception 'name is required' using errcode = '22023', hint = 'name_required';
      end if;

      update public.products set
        name        = case when p ? 'name' then btrim(p ->> 'name') else name end,
        category_id = case when p ? 'category_id' then (p ->> 'category_id')::uuid else category_id end,
        unit        = case when p ? 'unit' then coalesce(nullif(btrim(p ->> 'unit'), ''), 'pc') else unit end,
        tax_rate    = case when p ? 'tax_rate' then coalesce((p ->> 'tax_rate')::numeric, 0) else tax_rate end,
        track_stock = case when p ? 'track_stock' then coalesce((p ->> 'track_stock')::boolean, true) else track_stock end,
        active      = case when p ? 'active' then coalesce((p ->> 'active')::boolean, true) else active end,
        photo_path  = case when p ? 'photo_path' then p ->> 'photo_path' else photo_path end
      where id = v_pid;

      update public.product_variants set
        sku           = case when nullif(btrim(v ->> 'sku'), '') is not null then btrim(v ->> 'sku') else sku end,
        barcode       = case when v ? 'barcode' then nullif(btrim(v ->> 'barcode'), '') else barcode end,
        cost          = case when v ? 'cost' then coalesce((v ->> 'cost')::bigint, 0) else cost end,
        reorder_point = case when v ? 'reorder_point' then coalesce((v ->> 'reorder_point')::numeric, 0) else reorder_point end,
        active        = case when v ? 'active' then coalesce((v ->> 'active')::boolean, true) else active end
      where id = v_vid
      returning sku into v_sku;
    end if;

    if p ? 'price' then
      insert into public.variant_prices (tenant_id, variant_id, currency, price)
      values (v_tenant, v_vid, v_base, (p ->> 'price')::bigint)
      on conflict (variant_id, currency) do update set price = excluded.price, deleted_at = null;
    end if;
  exception
    when unique_violation then
      get stacked diagnostics v_con = constraint_name;
      if v_con = 'product_variants_sku_per_tenant' then
        raise exception 'SKU already used' using errcode = '23505', hint = 'duplicate_sku';
      elsif v_con = 'product_variants_barcode_per_tenant' then
        raise exception 'barcode already used' using errcode = '23505', hint = 'duplicate_barcode';
      elsif v_con in ('products_pkey', 'product_variants_pkey') then
        raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
      end if;
      raise;
    when foreign_key_violation then
      raise exception 'unknown category' using errcode = '22023', hint = 'bad_category';
    when check_violation then
      raise exception 'invalid value' using errcode = '23514', hint = 'invalid_value';
  end;

  v_result := jsonb_build_object('product_id', v_pid, 'variant_id', v_vid, 'sku', v_sku, 'created', v_created);

  perform public.write_audit(
    case when v_created then 'product.create' else 'product.update' end, 'product', v_pid, null,
    jsonb_build_object('sku', v_sku, 'price', p -> 'price', 'mode', v_mode));

  return public.finish_op(p_op_id, v_result);
end;
$$;

-- ---------------------------------------------------------------------------
-- archive_product: soft delete (tombstones sync to devices). Never a hard delete.
-- ---------------------------------------------------------------------------

create or replace function public.archive_product(p_op_id uuid, p_product_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_prod   public.products;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  if public.catalog_write_mode() is distinct from 'full' then
    raise exception 'not allowed to archive products' using errcode = '42501', hint = 'not_allowed';
  end if;

  v_replay := public.claim_op(p_op_id, 'archive_product');
  if v_replay is not null then
    return v_replay;
  end if;

  select * into v_prod from public.products where id = p_product_id and tenant_id = v_tenant for update;
  if not found then
    raise exception 'product not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_prod.deleted_at is null then
    update public.products set deleted_at = now() where id = p_product_id;
    update public.product_variants set deleted_at = now()
      where tenant_id = v_tenant and product_id = p_product_id and deleted_at is null;
    update public.variant_prices vp set deleted_at = now()
      from public.product_variants pv
      where pv.id = vp.variant_id and pv.product_id = p_product_id
        and vp.tenant_id = v_tenant and vp.deleted_at is null;
    perform public.write_audit('product.archive', 'product', p_product_id, null, '{}'::jsonb);
  end if;

  return public.finish_op(p_op_id, jsonb_build_object('product_id', p_product_id, 'archived', true));
end;
$$;

-- ---------------------------------------------------------------------------
-- sync_pull_catalog: per-table keyset pages ordered by (updated_at, key), tombstones included.
--   p_cursors = { "<table>": { "ts": "<updated_at>", "k": "<key>" }, ... }   (missing = from the start)
--   Returns   { "<table>": { "rows": [...], "cursor": {ts, k} | null, "has_more": bool }, "server_time": ... }
-- Rows newer than now() - 5 s are held back so a write that started earlier but commits later is never
-- skipped by a cursor that already moved past its updated_at.
-- Runs as the caller: RLS limits it to the caller's tenant as well.
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_catalog(p_cursors jsonb default '{}'::jsonb, p_limit int default 500)
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
    ('categories',       'id, parent_id, name, updated_at, deleted_at',
                         'id::text'),
    ('products',         'id, category_id, name, unit, tax_rate, track_stock, active, photo_path, updated_at, deleted_at',
                         'id::text'),
    ('product_variants', 'id, product_id, sku, barcode, is_default, cost, reorder_point, active, updated_at, deleted_at',
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
$$;

revoke execute on function public.upsert_product(uuid, jsonb) from public, anon;
revoke execute on function public.archive_product(uuid, uuid) from public, anon;
revoke execute on function public.sync_pull_catalog(jsonb, int) from public, anon;
grant execute on function public.upsert_product(uuid, jsonb) to authenticated;
grant execute on function public.archive_product(uuid, uuid) to authenticated;
grant execute on function public.sync_pull_catalog(jsonb, int) to authenticated;
