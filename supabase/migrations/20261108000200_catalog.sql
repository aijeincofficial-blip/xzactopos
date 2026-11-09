-- P2-01 Catalog: categories, products, product_variants, variant_prices (plan section 6 "Catalog").
-- Additive. Option sets, translations and suppliers come later (Full mode); option_value_ids is kept now
-- so adding them later needs no change to variants or to anything that references variant_id.
--
-- Access: every active user of the tenant reads the catalog (cashiers sell, warehouse receives).
-- Clients never write these tables directly; upsert_product / archive_product RPCs do (P2-02).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.categories (
  id          uuid primary key default public.uuid_generate_v7(),
  tenant_id   uuid not null references public.tenants (id) on delete cascade,
  parent_id   uuid,
  name        text not null check (length(btrim(name)) between 1 and 80),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  constraint categories_tenant_id unique (tenant_id, id),
  constraint categories_parent_fk foreign key (tenant_id, parent_id)
    references public.categories (tenant_id, id),
  constraint categories_not_own_parent check (parent_id is null or parent_id <> id)
);

create table public.products (
  id           uuid primary key default public.uuid_generate_v7(),
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  category_id  uuid,
  name         text not null check (length(btrim(name)) between 1 and 120),
  unit         text not null default 'pc' check (length(unit) between 1 and 16),
  tax_rate     numeric(6, 4) not null default 0 check (tax_rate >= 0 and tax_rate < 1),
  track_stock  boolean not null default true,
  active       boolean not null default true,
  -- Supabase Storage object path (P2-06), never image bytes
  photo_path   text check (length(photo_path) <= 200),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  constraint products_tenant_id unique (tenant_id, id),
  constraint products_category_fk foreign key (tenant_id, category_id)
    references public.categories (tenant_id, id)
);

-- The stockable and sellable unit. Every product has exactly one default variant (Solo mode shows only that one).
create table public.product_variants (
  id                uuid primary key default public.uuid_generate_v7(),
  tenant_id         uuid not null references public.tenants (id) on delete cascade,
  product_id        uuid not null,
  sku               text not null check (sku ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$'),
  barcode           text check (barcode ~ '^[A-Za-z0-9._-]{1,64}$'),
  option_value_ids  uuid[] not null default '{}' check (cardinality(option_value_ids) <= 3),
  is_default        boolean not null default false,
  -- base-currency minor units (weighted average lives in stock_levels later)
  cost              bigint not null default 0 check (cost >= 0),
  -- quantities may be fractional (rice by the kilo)
  reorder_point     numeric(12, 3) not null default 0 check (reorder_point >= 0),
  active            boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  constraint product_variants_tenant_id unique (tenant_id, id),
  constraint product_variants_sku_per_tenant unique (tenant_id, sku),
  constraint product_variants_product_fk foreign key (tenant_id, product_id)
    references public.products (tenant_id, id)
);

-- One price per variant per currency, integer minor units. The base-currency row is required (enforced by the RPC).
create table public.variant_prices (
  tenant_id   uuid not null references public.tenants (id) on delete cascade,
  variant_id  uuid not null,
  currency    char(3) not null references public.currencies (code),
  price       bigint not null check (price >= 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  primary key (variant_id, currency),
  constraint variant_prices_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id)
);

comment on table public.product_variants is
  'Stockable and sellable unit. Every product has one is_default variant; transactions always reference variant_id.';
comment on column public.variant_prices.price is 'Integer minor units of currency (centavos for PHP).';

-- ---------------------------------------------------------------------------
-- Indexes: tenant-leading delta-sync cursors, lookups, business keys
-- ---------------------------------------------------------------------------

create index categories_tenant_updated_idx       on public.categories (tenant_id, updated_at, id);
create index products_tenant_updated_idx         on public.products (tenant_id, updated_at, id);
create index product_variants_tenant_updated_idx on public.product_variants (tenant_id, updated_at, id);
create index variant_prices_tenant_updated_idx   on public.variant_prices (tenant_id, updated_at);

create index products_category_idx on public.products (category_id) where category_id is not null;
create index product_variants_product_idx on public.product_variants (product_id);

-- A barcode identifies one live variant per tenant; an archived product frees its barcode.
create unique index product_variants_barcode_per_tenant
  on public.product_variants (tenant_id, barcode)
  where barcode is not null and deleted_at is null;

create unique index product_variants_one_default
  on public.product_variants (product_id)
  where is_default and deleted_at is null;

-- ---------------------------------------------------------------------------
-- Product limit (tenant_limits.max_products), counted on live products
-- ---------------------------------------------------------------------------

create or replace function public.enforce_product_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_max   int;
  v_count int;
begin
  -- serialize concurrent inserts for one tenant so the count is exact
  perform pg_advisory_xact_lock(hashtextextended('products:' || new.tenant_id::text, 0));
  select l.max_products into v_max from public.tenant_limits l where l.tenant_id = new.tenant_id;
  select count(*) into v_count from public.products p where p.tenant_id = new.tenant_id and p.deleted_at is null;
  if v_max is not null and v_count >= v_max then
    raise exception 'product limit reached (%)', v_max using errcode = 'P0001', hint = 'limit_products';
  end if;
  return new;
end;
$$;

revoke execute on function public.enforce_product_limit() from public, anon, authenticated;

create trigger products_limit before insert on public.products
  for each row execute function public.enforce_product_limit();

-- ---------------------------------------------------------------------------
-- updated_at (server time, used by last-write-wins and delta sync) and tenant immutability
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array['categories', 'products', 'product_variants', 'variant_prices'] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update of tenant_id on public.%I for each row execute function public.prevent_tenant_change()',
      t || '_tenant_immutable', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS: read for active members of the tenant; no client writes (RPC only)
-- auth_tenant_id() resolves to null for deactivated users and archived tenants.
-- ---------------------------------------------------------------------------

alter table public.categories       enable row level security;
alter table public.products         enable row level security;
alter table public.product_variants enable row level security;
alter table public.variant_prices   enable row level security;

create policy categories_member_read on public.categories
  for select to authenticated using (tenant_id = (select public.auth_tenant_id()));
create policy products_member_read on public.products
  for select to authenticated using (tenant_id = (select public.auth_tenant_id()));
create policy product_variants_member_read on public.product_variants
  for select to authenticated using (tenant_id = (select public.auth_tenant_id()));
create policy variant_prices_member_read on public.variant_prices
  for select to authenticated using (tenant_id = (select public.auth_tenant_id()));

revoke all on public.categories, public.products, public.product_variants, public.variant_prices from anon;
revoke insert, update, delete, truncate
  on public.categories, public.products, public.product_variants, public.variant_prices
  from authenticated;
grant select on public.categories, public.products, public.product_variants, public.variant_prices to authenticated;
