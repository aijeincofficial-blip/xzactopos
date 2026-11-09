-- P8-08 Tingi / repack: open a pack (a box, a bundle, a kaha) and sell the pieces one by one.
--
-- Model. The piece is its OWN product with its own default variant (the Sell screen, search and quick tiles show a
-- product's default variant, and the variant is the stockable / sellable unit). A LINK on the pack variant says
-- "1 of me breaks into N of that piece variant":
--   product_variants.breaks_into_variant_id   the piece variant (same tenant, never itself)
--   product_variants.breaks_into_qty          N, whole pieces per pack (1 .. 10000); both set or both null
-- No chains: a variant is a pack OR a piece, never both (so no cycle of any length can exist). Several packs may break
-- into the same piece (a carton and a kaha both into sticks). Archived (soft-deleted) variants do not count for the rule.
--
--   conversions          append-only record of every opened pack; the only change ever allowed is a void
--   stock_movements      new types conversion_out (pack, -packs), conversion_in (piece, +pieces), conversion_void (both
--                        reversals); new column total_cost (the value a conversion_in carries into the piece)
--   apply_stock_movement re-created (from 20261108000800): one weighted-average rule (stock_blend_cost) for receipts and
--                        conversion_in, conversion_in makes a product "counted" like a receipt
--   op_set_tingi_link    through sync_push; same permission as editing the catalog
--   op_open_pack         through sync_push; same permission as stock in / counts (no approval, like those)
--   op_void_open_pack    through sync_push; same permission; reverses both movements once (never a delete)
--   sync_pull_conversions keyset delta pull (same rules as sync_pull_service)
--   sync_pull_catalog, sync_push re-created (additive)
--
-- COST RULE (integer centavos, no floats; the phone uses the same rule, `blendAvgCost` in sales_models.dart):
--   A  = the pack's average cost at the store (stock_levels.avg_cost); if it has none, the pack variant's cost when > 0;
--        else unknown (then the pieces' average cost is left alone).
--   T  = packs * A   (exact: whole packs times whole centavos, nothing is rounded here)
--   The pack leaves at A per pack: its stock value drops by exactly T (an outgoing movement never changes avg_cost).
--   The pieces come in carrying T. Their new average, with Q, C the pieces' level and average before and N the pieces:
--        Q > 0 and C known:  C' = half_up((Q * C + T) / (Q + N))
--        otherwise:          C' = half_up(T / N)
--   half_up(n / d) = floor((2n + d) / (2d)) computed exactly (numeric div), never through a rounded division.
--   That stored average is the ONLY rounding: stock value (qty x avg_cost) of pack + pieces after the opening differs from
--   before by (Q + N) x (C' - exact) centavos, i.e. at most half a centavo per piece on hand (2 |diff| <= Q + N), and by
--   nothing at all when the division is exact. Receipts use the same function with value = qty x unit_cost.
--   Example: a kaha at 103.50 (10350) opened into 20 sticks, none before: T = 10350, C' = half_up(517.5) = 518;
--   the sticks are worth 20 x 518 = 10360, 10 centavos over T, the bound for 20 pieces is 10.
--   A void puts the packs back and takes the pieces out; it does not move either average (like a sale void).
--
-- STOCK RULES: opening more packs than counted is allowed (the pack level goes below zero), like a sale: the app warns,
-- the server never blocks. A void may push the piece level below zero (pieces already sold): allowed for the same reason.
-- Both products must track stock (hint not_tracked). The pack needs a live link to a live piece.
--
-- Who (the UI hides, this enforces): set_tingi_link = catalog_write_mode() 'full' (owner, store managers);
-- open_pack / void_open_pack = the same people as receive_stock / adjust_stock (catalog_write_mode() 'full').
-- Cashiers and warehouse staff: not_allowed. Reads: conversions follow store access like stock_movements.
-- Audit: 'product.tingi_link' (entity variant), 'stock.open_pack' / 'stock.void_open_pack' (entity conversion), small meta.
-- Replays (same op id) write nothing.
--
-- Hints: not_allowed, invalid_value, id_required, unknown_variant, piece_archived, not_tracked, link_self, link_chain,
--   ratio_invalid, qty_invalid, no_tingi_link, link_changed, id_conflict, conversion_not_found, already_voided.

-- ---------------------------------------------------------------------------
-- The link on the pack variant
-- ---------------------------------------------------------------------------

alter table public.product_variants
  add column breaks_into_variant_id uuid,
  add column breaks_into_qty integer,
  add constraint product_variants_breaks_into_fk foreign key (tenant_id, breaks_into_variant_id)
    references public.product_variants (tenant_id, id),
  add constraint product_variants_breaks_into_pair
    check ((breaks_into_variant_id is null) = (breaks_into_qty is null)),
  add constraint product_variants_breaks_into_qty check (breaks_into_qty between 1 and 10000),
  add constraint product_variants_breaks_into_not_self check (breaks_into_variant_id <> id);

comment on column public.product_variants.breaks_into_variant_id is
  'Tingi: one of this (pack) variant breaks into breaks_into_qty of that piece variant. A variant is a pack or a piece, never both.';

create index product_variants_breaks_into_idx on public.product_variants (tenant_id, breaks_into_variant_id)
  where breaks_into_variant_id is not null;

-- No chains (and so no cycles): the piece must not be a pack, and a pack must not be anyone's piece.
-- Serialised per tenant so two concurrent links (A -> B and B -> C) cannot both pass.
create or replace function public.guard_tingi_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.breaks_into_variant_id is null then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('tingi:' || new.tenant_id::text, 0));
  if exists (select 1 from public.product_variants v
             where v.tenant_id = new.tenant_id and v.id = new.breaks_into_variant_id
               and v.breaks_into_variant_id is not null and v.deleted_at is null) then
    raise exception 'the piece is itself a pack' using errcode = '22023', hint = 'link_chain';
  end if;
  if exists (select 1 from public.product_variants v
             where v.tenant_id = new.tenant_id and v.breaks_into_variant_id = new.id
               and v.id <> new.id and v.deleted_at is null) then
    raise exception 'this variant is already the piece of another pack' using errcode = '22023', hint = 'link_chain';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_tingi_link() from public, anon, authenticated;

create trigger product_variants_tingi_link before insert or update of breaks_into_variant_id, breaks_into_qty
  on public.product_variants
  for each row execute function public.guard_tingi_link();

-- ---------------------------------------------------------------------------
-- Stock ledger: conversion movement types, the value a conversion_in carries, one average-cost rule
-- ---------------------------------------------------------------------------

alter table public.stock_movements drop constraint stock_movements_type_check;
alter table public.stock_movements add constraint stock_movements_type_check
  check (type in ('opening', 'sale', 'sale_void', 'receipt', 'count_correction', 'damage',
                  'conversion_out', 'conversion_in', 'conversion_void'));

alter table public.stock_movements
  add column total_cost bigint check (total_cost >= 0),
  add constraint stock_movements_total_cost_kind check (total_cost is null or type = 'conversion_in');

comment on column public.stock_movements.total_cost is
  'conversion_in only: the value (centavos) moved into the piece variant (packs x pack average cost). Feeds avg_cost.';

-- Weighted average after adding p_add_qty units worth p_add_value centavos in total to (p_old_qty at p_old_cost).
-- Half up, exact (numeric div is an exact integer quotient). Null value or nothing added: the old cost stays.
create or replace function public.stock_blend_cost(p_old_qty numeric, p_old_cost bigint, p_add_qty numeric, p_add_value numeric)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case
    when p_add_value is null or p_add_qty is null or p_add_qty <= 0 then p_old_cost
    when coalesce(p_old_qty, 0) <= 0 or p_old_cost is null
      then div(2 * p_add_value + p_add_qty, 2 * p_add_qty)::bigint
    else div(2 * (p_old_qty * p_old_cost + p_add_value) + (p_old_qty + p_add_qty), 2 * (p_old_qty + p_add_qty))::bigint
  end
$$;

revoke execute on function public.stock_blend_cost(numeric, bigint, numeric, numeric) from public, anon, authenticated;

create or replace function public.apply_stock_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_qty  numeric;
  v_old_cost bigint;
  v_cost     bigint;
  v_counted  boolean := new.type in ('opening', 'receipt', 'count_correction', 'damage', 'conversion_in');
begin
  select l.qty_on_hand, l.avg_cost into v_old_qty, v_old_cost
  from public.stock_levels l
  where l.location_id = new.location_id and l.variant_id = new.variant_id
  for update;

  v_cost := v_old_cost;
  if new.type = 'receipt' and new.unit_cost is not null then
    v_cost := public.stock_blend_cost(v_old_qty, v_old_cost, new.qty_delta, new.qty_delta * new.unit_cost);
  elsif new.type = 'conversion_in' and new.total_cost is not null then
    v_cost := public.stock_blend_cost(v_old_qty, v_old_cost, new.qty_delta, new.total_cost);
  end if;

  insert into public.stock_levels as sl (tenant_id, location_id, variant_id, qty_on_hand, avg_cost, counted, updated_at)
  values (new.tenant_id, new.location_id, new.variant_id, new.qty_delta, v_cost, v_counted, now())
  on conflict (location_id, variant_id)
  do update set qty_on_hand = sl.qty_on_hand + excluded.qty_on_hand,
                avg_cost = excluded.avg_cost,
                counted = sl.counted or excluded.counted,
                updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- conversions: one row per opened pack
-- ---------------------------------------------------------------------------

create table public.conversions (
  id                uuid primary key,
  tenant_id         uuid not null references public.tenants (id) on delete cascade,
  location_id       uuid not null,
  client_op_id      uuid not null,
  pack_variant_id   uuid not null,
  piece_variant_id  uuid not null,
  packs             integer not null check (packs between 1 and 10000),
  -- pieces per pack at the time of opening (the link may change later)
  ratio             integer not null check (ratio between 1 and 10000),
  pieces            integer not null,
  -- centavos: the pack cost used (A), packs x A, and half_up(total / pieces) for display; all null when unknown
  pack_cost         bigint check (pack_cost >= 0),
  total_cost        bigint check (total_cost >= 0),
  piece_cost        bigint check (piece_cost >= 0),
  note              text check (length(note) <= 200),
  converted_at      timestamptz not null,
  created_by        uuid references auth.users (id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  voided_at         timestamptz,
  void_reason       text check (length(void_reason) <= 200),
  voided_by         uuid references auth.users (id) on delete set null,
  constraint conversions_tenant_id unique (tenant_id, id),
  constraint conversions_client_op_per_tenant unique (tenant_id, client_op_id),
  constraint conversions_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint conversions_pack_fk foreign key (tenant_id, pack_variant_id)
    references public.product_variants (tenant_id, id),
  constraint conversions_piece_fk foreign key (tenant_id, piece_variant_id)
    references public.product_variants (tenant_id, id),
  constraint conversions_not_self check (pack_variant_id <> piece_variant_id),
  constraint conversions_pieces check (pieces = packs * ratio),
  constraint conversions_cost_consistent check (
    (pack_cost is null and total_cost is null and piece_cost is null)
    or (pack_cost is not null and total_cost = packs * pack_cost and piece_cost is not null)),
  constraint conversions_void_consistent check (void_reason is null or voided_at is not null),
  constraint conversions_voided_by_consistent check (voided_by is null or voided_at is not null)
);

comment on table public.conversions is
  'Tingi: append-only record of opened packs (conversion_out / conversion_in movements share its id). Only a void changes it.';

create index conversions_tenant_at_idx      on public.conversions (tenant_id, converted_at desc, id);
create index conversions_tenant_updated_idx on public.conversions (tenant_id, updated_at, id);

create trigger conversions_set_updated_at before update on public.conversions
  for each row execute function public.set_updated_at();

-- Rows never change except: void once (voided_at null -> set, with void_reason / voided_by), and created_by / voided_by
-- going to null when that user is removed.
create or replace function public.guard_conversion_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_voiding boolean;
begin
  if tg_op = 'DELETE' then
    raise exception 'conversions is append-only' using errcode = '55000', hint = 'append_only';
  end if;
  if (new.id, new.tenant_id, new.location_id, new.client_op_id, new.pack_variant_id, new.piece_variant_id, new.packs,
      new.ratio, new.pieces, new.pack_cost, new.total_cost, new.piece_cost, new.note, new.converted_at, new.created_at,
      new.deleted_at)
     is distinct from
     (old.id, old.tenant_id, old.location_id, old.client_op_id, old.pack_variant_id, old.piece_variant_id, old.packs,
      old.ratio, old.pieces, old.pack_cost, old.total_cost, old.piece_cost, old.note, old.converted_at, old.created_at,
      old.deleted_at)
     or (new.created_by is distinct from old.created_by and new.created_by is not null) then
    raise exception 'conversions is append-only; only a void is allowed' using errcode = '55000', hint = 'append_only';
  end if;
  v_voiding := old.voided_at is null and new.voided_at is not null;
  if (new.voided_at is distinct from old.voided_at or new.void_reason is distinct from old.void_reason)
     and not v_voiding then
    raise exception 'a pack opening can be voided once and never un-voided' using errcode = '55000', hint = 'append_only';
  end if;
  if new.voided_by is distinct from old.voided_by and new.voided_by is not null and not v_voiding then
    raise exception 'voided_by is set only by the void' using errcode = '55000', hint = 'append_only';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_conversion_change() from public, anon, authenticated;

create trigger conversions_guard before update or delete on public.conversions
  for each row execute function public.guard_conversion_change();

alter table public.conversions enable row level security;

-- store-scoped like stock_movements: the user's stores (superadmin: all stores)
create policy conversions_store_read on public.conversions
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and location_id = any ((select public.auth_location_ids())::uuid[]));

revoke all on public.conversions from anon;
revoke insert, update, delete, truncate on public.conversions from authenticated;
grant select on public.conversions to authenticated;

-- ---------------------------------------------------------------------------
-- Shared input helper: a whole number 1 .. p_max sent as a JSON number or a digit string, else null
-- ---------------------------------------------------------------------------

create or replace function public.json_whole(p jsonb, p_key text, p_max integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when jsonb_typeof(p -> p_key) in ('number', 'string') and (p ->> p_key) ~ '^[0-9]{1,9}$'
         and (p ->> p_key)::bigint between 1 and p_max
      then (p ->> p_key)::integer
  end
$$;

revoke execute on function public.json_whole(jsonb, text, integer) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_set_tingi_link   p = { variant_id (the pack), piece_variant_id (null or missing = clear), pieces_per_pack }
--   Returns { variant_id, piece_variant_id, pieces_per_pack, changed, applied_at }.
-- ---------------------------------------------------------------------------

create or replace function public.op_set_tingi_link(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant  uuid;
  v_replay  jsonb;
  v_vid     uuid;
  v_pid     uuid;
  v_ratio   integer;
  v_pack    public.product_variants;
  v_ptrack  boolean;
  v_pdel    timestamptz;
  v_piece   record;
  v_changed boolean;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  if public.catalog_write_mode() is distinct from 'full' then
    raise exception 'not allowed to change the catalog' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'link must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'set_tingi_link');
  if v_replay is not null then
    return v_replay;
  end if;

  v_vid := (p ->> 'variant_id')::uuid;
  v_pid := (p ->> 'piece_variant_id')::uuid;

  select * into v_pack from public.product_variants where id = v_vid and tenant_id = v_tenant for update;
  if not found or v_pack.deleted_at is not null then
    raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
  end if;
  select pr.track_stock, pr.deleted_at into v_ptrack, v_pdel
  from public.products pr where pr.tenant_id = v_tenant and pr.id = v_pack.product_id;
  if v_pdel is not null then
    raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
  end if;

  if v_pid is null then
    v_ratio := null;
  else
    v_ratio := public.json_whole(p, 'pieces_per_pack', 10000);
    if v_ratio is null then
      raise exception 'pieces per pack must be a whole number from 1 to 10000' using errcode = '22023', hint = 'ratio_invalid';
    end if;
    if v_pid = v_vid then
      raise exception 'a pack cannot break into itself' using errcode = '22023', hint = 'link_self';
    end if;
    select v.id, v.deleted_at as vdel, pr.deleted_at as pdel, pr.track_stock into v_piece
    from public.product_variants v
    join public.products pr on pr.tenant_id = v.tenant_id and pr.id = v.product_id
    where v.id = v_pid and v.tenant_id = v_tenant;
    if not found then
      raise exception 'unknown piece product' using errcode = '22023', hint = 'unknown_variant';
    end if;
    if v_piece.vdel is not null or v_piece.pdel is not null then
      raise exception 'the piece product is archived' using errcode = '22023', hint = 'piece_archived';
    end if;
    if not v_ptrack or not v_piece.track_stock then
      raise exception 'both products must keep a stock count' using errcode = '22023', hint = 'not_tracked';
    end if;
  end if;

  v_changed := (v_pack.breaks_into_variant_id, v_pack.breaks_into_qty) is distinct from (v_pid, v_ratio);
  if v_changed then
    -- guard_tingi_link refuses chains (hint link_chain)
    update public.product_variants
       set breaks_into_variant_id = v_pid, breaks_into_qty = v_ratio
     where id = v_vid and tenant_id = v_tenant;
    perform public.write_audit('product.tingi_link', 'variant', v_vid, null, jsonb_build_object(
      'piece_variant_id', v_pid, 'pieces_per_pack', v_ratio, 'op_id', p_op_id));
  end if;

  return public.finish_op(p_op_id, jsonb_build_object(
    'variant_id', v_vid, 'piece_variant_id', v_pid, 'pieces_per_pack', v_ratio, 'changed', v_changed, 'applied_at', now()));
end;
$$;

-- ---------------------------------------------------------------------------
-- op_open_pack   p = { id, pack_variant_id, packs (whole, 1 .. 10000), location_id?, note?, at?,
--                      piece_variant_id?, pieces_per_pack? }
--   The two optional link fields are what the phone showed; when sent and the link is now different the op is refused
--   (link_changed) so the phone and the server never disagree on how many pieces came out.
--   Returns { conversion_id, piece_variant_id, pieces, pack_cost, total_cost, piece_cost, applied_at }.
-- ---------------------------------------------------------------------------

create or replace function public.op_open_pack(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant  uuid;
  v_replay  jsonb;
  v_loc     uuid;
  v_id      uuid;
  v_packs   integer;
  v_pack    record;
  v_piece   record;
  v_pieces  integer;
  v_avg     bigint;
  v_a       bigint;
  v_total   bigint;
  v_pcost   bigint;
  v_at      timestamptz;
  v_note    text;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  if public.catalog_write_mode() is distinct from 'full' then
    raise exception 'not allowed to change stock' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'pack opening must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'open_pack');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);
  v_id := (p ->> 'id')::uuid;
  if v_id is null then
    raise exception 'pack opening id is required' using errcode = '22023', hint = 'id_required';
  end if;
  v_packs := public.json_whole(p, 'packs', 10000);
  if v_packs is null then
    raise exception 'packs must be a whole number from 1 to 10000' using errcode = '22023', hint = 'qty_invalid';
  end if;

  -- FOR SHARE: the link cannot change under this op
  select v.id, v.cost, v.breaks_into_variant_id as piece_id, v.breaks_into_qty as ratio, pr.track_stock
    into v_pack
  from public.product_variants v
  join public.products pr on pr.tenant_id = v.tenant_id and pr.id = v.product_id
  where v.id = (p ->> 'pack_variant_id')::uuid and v.tenant_id = v_tenant
    and v.deleted_at is null and pr.deleted_at is null
  for share of v;
  if not found then
    raise exception 'unknown product' using errcode = '22023', hint = 'unknown_variant';
  end if;
  if v_pack.piece_id is null then
    raise exception 'this product is not sold by the piece' using errcode = '22023', hint = 'no_tingi_link';
  end if;
  if (p ? 'piece_variant_id' and (p ->> 'piece_variant_id')::uuid is distinct from v_pack.piece_id)
     or (p ? 'pieces_per_pack' and public.json_whole(p, 'pieces_per_pack', 10000) is distinct from v_pack.ratio) then
    raise exception 'the pieces per pack changed; check the product and try again' using errcode = '22023', hint = 'link_changed';
  end if;

  select v.id, v.deleted_at as vdel, pr.deleted_at as pdel, pr.track_stock into v_piece
  from public.product_variants v
  join public.products pr on pr.tenant_id = v.tenant_id and pr.id = v.product_id
  where v.id = v_pack.piece_id and v.tenant_id = v_tenant;
  if v_piece.vdel is not null or v_piece.pdel is not null then
    raise exception 'the piece product is archived' using errcode = '22023', hint = 'piece_archived';
  end if;
  if not v_pack.track_stock or not v_piece.track_stock then
    raise exception 'both products must keep a stock count' using errcode = '22023', hint = 'not_tracked';
  end if;

  v_pieces := v_packs * v_pack.ratio;
  if v_pieces > 1000000 then
    raise exception 'too many pieces at once' using errcode = '22023', hint = 'qty_invalid';
  end if;

  -- the cost rule (header): A = average cost of the pack at this store, else the variant cost when > 0
  select l.avg_cost into v_avg from public.stock_levels l
  where l.location_id = v_loc and l.variant_id = v_pack.id for update;
  v_a := coalesce(v_avg, nullif(v_pack.cost, 0));
  if v_a is not null then
    v_total := v_packs * v_a;
    v_pcost := public.stock_blend_cost(0, null, v_pieces, v_total);
  end if;

  v_at := coalesce((p ->> 'at')::timestamptz, now());
  v_note := left(nullif(btrim(p ->> 'note'), ''), 200);

  begin
    insert into public.conversions (id, tenant_id, location_id, client_op_id, pack_variant_id, piece_variant_id, packs,
                                    ratio, pieces, pack_cost, total_cost, piece_cost, note, converted_at, created_by)
    values (v_id, v_tenant, v_loc, p_op_id, v_pack.id, v_pack.piece_id, v_packs, v_pack.ratio, v_pieces, v_a, v_total,
            v_pcost, v_note, v_at, auth.uid());
  exception when unique_violation then
    raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id,
                                      unit_cost, total_cost, occurred_at, created_by)
  values (v_tenant, v_loc, v_pack.id, -v_packs, 'conversion_out', 'conversion', v_id, v_a, null, v_at, auth.uid()),
         (v_tenant, v_loc, v_pack.piece_id, v_pieces, 'conversion_in', 'conversion', v_id, v_pcost, v_total, v_at, auth.uid());

  perform public.write_audit('stock.open_pack', 'conversion', v_id, v_loc, jsonb_strip_nulls(jsonb_build_object(
    'pack_variant_id', v_pack.id, 'piece_variant_id', v_pack.piece_id, 'packs', v_packs, 'pieces', v_pieces,
    'total_cost', v_total, 'op_id', p_op_id)));
  return public.finish_op(p_op_id, jsonb_build_object(
    'conversion_id', v_id, 'piece_variant_id', v_pack.piece_id, 'pieces', v_pieces, 'pack_cost', v_a,
    'total_cost', v_total, 'piece_cost', v_pcost, 'applied_at', now()));
end;
$$;

-- ---------------------------------------------------------------------------
-- op_void_open_pack   p = { conversion_id, reason? }
--   Once: the packs go back (conversion_void, +packs) and the pieces come out (conversion_void, -pieces); averages stay.
--   A second void is refused (already_voided). Returns { conversion_id, applied_at }.
-- ---------------------------------------------------------------------------

create or replace function public.op_void_open_pack(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_cid    uuid;
  v_conv   public.conversions;
  v_reason text;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  if public.catalog_write_mode() is distinct from 'full' then
    raise exception 'not allowed to change stock' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'void must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'void_open_pack');
  if v_replay is not null then
    return v_replay;
  end if;

  v_cid := (p ->> 'conversion_id')::uuid;
  select * into v_conv from public.conversions where id = v_cid and tenant_id = v_tenant for update;
  if not found then
    raise exception 'pack opening not found' using errcode = '22023', hint = 'conversion_not_found';
  end if;
  perform public.resolve_store(v_conv.location_id);
  if v_conv.voided_at is not null then
    raise exception 'this pack opening is already voided' using errcode = '22023', hint = 'already_voided';
  end if;

  v_reason := left(nullif(btrim(p ->> 'reason'), ''), 200);
  update public.conversions set voided_at = now(), void_reason = v_reason, voided_by = auth.uid()
   where id = v_cid and tenant_id = v_tenant;

  insert into public.stock_movements (tenant_id, location_id, variant_id, qty_delta, type, ref_type, ref_id, created_by)
  values (v_tenant, v_conv.location_id, v_conv.pack_variant_id, v_conv.packs, 'conversion_void', 'conversion_void', v_cid,
          auth.uid()),
         (v_tenant, v_conv.location_id, v_conv.piece_variant_id, -v_conv.pieces, 'conversion_void', 'conversion_void', v_cid,
          auth.uid());

  perform public.write_audit('stock.void_open_pack', 'conversion', v_cid, v_conv.location_id, jsonb_strip_nulls(
    jsonb_build_object('packs', v_conv.packs, 'pieces', v_conv.pieces, 'reason', v_reason, 'op_id', p_op_id)));
  return public.finish_op(p_op_id, jsonb_build_object('conversion_id', v_cid, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_set_tingi_link(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_open_pack(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_void_open_pack(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_conversions(cursor, limit)   same rules as sync_pull_service
--   first pull (cursor null) = openings from the last 30 days by converted_at; afterwards delta by (updated_at, id);
--   rows newer than now - 5 s wait for the next pull; a voided opening comes again (its updated_at moves).
--   The stock levels themselves arrive through sync_pull_pos as always. Runs as the caller (store access, RLS).
--   Returns { rows: [ { id, location_id, pack_variant_id, piece_variant_id, packs, ratio, pieces, pack_cost, total_cost,
--                       piece_cost, note, converted_at, created_by, voided_at, void_reason, updated_at } ],
--             cursor, has_more, server_time }.
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_conversions(p_cursor jsonb default null, p_limit int default 100)
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
$$;

revoke execute on function public.sync_pull_conversions(jsonb, int) from public, anon;
grant execute on function public.sync_pull_conversions(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_catalog re-created (from 20261108000300): product_variants also carry the tingi link
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
    ('product_variants', 'id, product_id, sku, barcode, is_default, cost, reorder_point, active, '
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
$$;

revoke execute on function public.sync_pull_catalog(jsonb, int) from public, anon;
grant execute on function public.sync_pull_catalog(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- sync_push re-created (from 20261108001400, the newest definition) with set_tingi_link, open_pack, void_open_pack
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
        when 'receive_stock'       then public.op_receive_stock(v_id, o -> 'payload')
        when 'adjust_stock'        then public.op_adjust_stock(v_id, o -> 'payload')
        when 'adjust_utang'        then public.op_adjust_utang(v_id, o -> 'payload')
        when 'record_expense'      then public.op_record_expense(v_id, o -> 'payload')
        when 'void_expense'        then public.op_void_expense(v_id, o -> 'payload')
        when 'close_day'           then public.op_close_day(v_id, o -> 'payload')
        when 'record_service_txn'  then public.op_record_service_txn(v_id, o -> 'payload')
        when 'void_service_txn'    then public.op_void_service_txn(v_id, o -> 'payload')
        when 'set_tingi_link'      then public.op_set_tingi_link(v_id, o -> 'payload')
        when 'open_pack'           then public.op_open_pack(v_id, o -> 'payload')
        when 'void_open_pack'      then public.op_void_open_pack(v_id, o -> 'payload')
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
