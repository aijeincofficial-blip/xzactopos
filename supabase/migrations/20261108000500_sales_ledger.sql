-- P3-01 Stock ledger, sales and utang (plan section 6 "Sales" and "Inventory", cut down for the solo store).
--
--   stock_movements   append-only ledger (opening | sale | sale_void for now; Phase 4 adds the rest)
--   stock_levels      derived by trigger, never written by clients
--   customers + customer_ledger   utang: balance = sum(ledger.amount), charge > 0, payment < 0
--   sales, sale_items, payments   a completed sale as it was rung up (prices and costs are snapshots)
--
-- Clients only read. Writes come from SECURITY DEFINER RPCs in P3-02.
-- Read access: sales/stock follow store access (superadmin: all stores); customers and utang: superadmin, admin, cashier.

-- ---------------------------------------------------------------------------
-- Stock ledger
-- ---------------------------------------------------------------------------

create table public.stock_movements (
  id           uuid primary key default public.uuid_generate_v7(),
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  location_id  uuid not null,
  variant_id   uuid not null,
  qty_delta    numeric(12, 3) not null check (qty_delta <> 0),
  type         text not null check (type in ('opening', 'sale', 'sale_void')),
  ref_type     text check (length(ref_type) <= 24),
  ref_id       uuid,
  unit_cost    bigint check (unit_cost >= 0),
  occurred_at  timestamptz not null default now(),
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  constraint stock_movements_tenant_id unique (tenant_id, id),
  constraint stock_movements_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint stock_movements_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id)
);

create table public.stock_levels (
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  location_id  uuid not null,
  variant_id   uuid not null,
  qty_on_hand  numeric(12, 3) not null default 0,
  updated_at   timestamptz not null default now(),
  primary key (location_id, variant_id),
  constraint stock_levels_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint stock_levels_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id)
);

comment on table public.stock_movements is 'Append-only. Stock is never edited, only added to by movements.';
comment on table public.stock_levels is 'Derived from stock_movements by trigger. Offline sales may push it below zero on purpose.';

create index stock_movements_tenant_variant_idx on public.stock_movements (tenant_id, variant_id, occurred_at);
create index stock_movements_tenant_ref_idx     on public.stock_movements (tenant_id, ref_type, ref_id);
create index stock_levels_tenant_updated_idx    on public.stock_levels (tenant_id, updated_at, location_id, variant_id);

-- Shared by every append-only table
create or replace function public.reject_ledger_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% is append-only', tg_table_name using errcode = '55000', hint = 'append_only';
end;
$$;

revoke execute on function public.reject_ledger_change() from public, anon, authenticated;

create trigger stock_movements_append_only before update or delete on public.stock_movements
  for each row execute function public.reject_ledger_change();

create or replace function public.apply_stock_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.stock_levels as sl (tenant_id, location_id, variant_id, qty_on_hand, updated_at)
  values (new.tenant_id, new.location_id, new.variant_id, new.qty_delta, now())
  on conflict (location_id, variant_id)
  do update set qty_on_hand = sl.qty_on_hand + excluded.qty_on_hand, updated_at = now();
  return new;
end;
$$;

revoke execute on function public.apply_stock_movement() from public, anon, authenticated;

create trigger stock_movements_apply after insert on public.stock_movements
  for each row execute function public.apply_stock_movement();

-- ---------------------------------------------------------------------------
-- Customers and utang
-- ---------------------------------------------------------------------------

create table public.customers (
  id          uuid primary key default public.uuid_generate_v7(),
  tenant_id   uuid not null references public.tenants (id) on delete cascade,
  name        text not null check (length(btrim(name)) between 1 and 80),
  phone       text check (length(phone) <= 32),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  constraint customers_tenant_id unique (tenant_id, id)
);

create index customers_tenant_updated_idx on public.customers (tenant_id, updated_at, id);

-- sales come before the ledger because the ledger can point at a sale
create table public.sales (
  id           uuid primary key default public.uuid_generate_v7(),
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  location_id  uuid not null,
  local_no     text not null check (length(local_no) between 3 and 40),
  status       text not null default 'completed' check (status in ('completed', 'voided')),
  subtotal     bigint not null check (subtotal >= 0),
  discount     bigint not null default 0 check (discount >= 0),
  tax          bigint not null default 0 check (tax >= 0),
  total        bigint not null check (total >= 0),
  customer_id  uuid,
  sold_at      timestamptz not null,
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  voided_at    timestamptz,
  void_reason  text check (length(void_reason) <= 200),
  constraint sales_tenant_id unique (tenant_id, id),
  constraint sales_tenant_id_location unique (tenant_id, id, location_id),
  constraint sales_local_no_per_tenant unique (tenant_id, local_no),
  constraint sales_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint sales_customer_fk foreign key (tenant_id, customer_id)
    references public.customers (tenant_id, id),
  constraint sales_total_adds_up check (discount <= subtotal and total = subtotal - discount),
  constraint sales_void_consistent check ((status = 'voided') = (voided_at is not null))
);

create index sales_tenant_sold_idx on public.sales (tenant_id, sold_at desc, id);
create index sales_tenant_customer_idx on public.sales (tenant_id, customer_id) where customer_id is not null;

create table public.sale_items (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  sale_id       uuid not null,
  location_id   uuid not null,
  variant_id    uuid not null,
  product_name  text not null check (length(product_name) between 1 and 120),
  qty           numeric(12, 3) not null check (qty > 0),
  unit_price    bigint not null check (unit_price >= 0),
  unit_cost     bigint not null default 0 check (unit_cost >= 0),
  discount      bigint not null default 0 check (discount >= 0),
  tax           bigint not null default 0 check (tax >= 0),
  line_total    bigint not null check (line_total >= 0),
  created_at    timestamptz not null default now(),
  constraint sale_items_sale_fk foreign key (tenant_id, sale_id, location_id)
    references public.sales (tenant_id, id, location_id),
  constraint sale_items_variant_fk foreign key (tenant_id, variant_id)
    references public.product_variants (tenant_id, id)
);

create index sale_items_tenant_sale_idx    on public.sale_items (tenant_id, sale_id);
create index sale_items_tenant_variant_idx on public.sale_items (tenant_id, variant_id);

create table public.payments (
  id             uuid primary key default public.uuid_generate_v7(),
  tenant_id      uuid not null references public.tenants (id) on delete cascade,
  sale_id        uuid not null,
  location_id    uuid not null,
  method         text not null check (method in ('cash', 'utang', 'ewallet')),
  -- the part of the sale this payment covers (change given back is not included)
  amount         bigint not null check (amount > 0),
  -- cash handed over; change = tendered - amount
  tendered       bigint check (tendered >= amount),
  reference      text check (length(reference) <= 64),
  created_at     timestamptz not null default now(),
  constraint payments_sale_fk foreign key (tenant_id, sale_id, location_id)
    references public.sales (tenant_id, id, location_id),
  constraint payments_tendered_cash_only check (tendered is null or method = 'cash')
);

create index payments_tenant_sale_idx on public.payments (tenant_id, sale_id);

create table public.customer_ledger (
  id           uuid primary key default public.uuid_generate_v7(),
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  customer_id  uuid not null,
  kind         text not null check (kind in ('charge', 'payment', 'adjust')),
  -- base minor units: charge > 0 (customer owes more), payment < 0, adjust either way
  amount       bigint not null check (amount <> 0),
  sale_id      uuid,
  note         text check (length(note) <= 200),
  occurred_at  timestamptz not null default now(),
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  constraint customer_ledger_sign check (
    (kind = 'charge' and amount > 0) or (kind = 'payment' and amount < 0) or kind = 'adjust'),
  constraint customer_ledger_customer_fk foreign key (tenant_id, customer_id)
    references public.customers (tenant_id, id),
  constraint customer_ledger_sale_fk foreign key (tenant_id, sale_id)
    references public.sales (tenant_id, id)
);

comment on table public.customer_ledger is
  'Append-only utang ledger. A customer''s balance is sum(amount); it is never stored, so it cannot drift.';

create index customer_ledger_tenant_created_idx  on public.customer_ledger (tenant_id, created_at, id);
create index customer_ledger_tenant_customer_idx on public.customer_ledger (tenant_id, customer_id, occurred_at);

create trigger customer_ledger_append_only before update or delete on public.customer_ledger
  for each row execute function public.reject_ledger_change();

-- ---------------------------------------------------------------------------
-- updated_at and tenant immutability on the editable tables
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array['customers', 'sales'] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update of tenant_id on public.%I for each row execute function public.prevent_tenant_change()',
      t || '_tenant_immutable', t);
  end loop;
end;
$$;

-- Sale lines and payments never change after the sale is recorded
create trigger sale_items_append_only before update or delete on public.sale_items
  for each row execute function public.reject_ledger_change();
create trigger payments_append_only before update or delete on public.payments
  for each row execute function public.reject_ledger_change();

-- ---------------------------------------------------------------------------
-- RLS: read only
-- ---------------------------------------------------------------------------

alter table public.stock_movements enable row level security;
alter table public.stock_levels    enable row level security;
alter table public.sales           enable row level security;
alter table public.sale_items      enable row level security;
alter table public.payments        enable row level security;
alter table public.customers       enable row level security;
alter table public.customer_ledger enable row level security;

-- store-scoped: the user's stores (superadmin: all stores)
create policy stock_movements_store_read on public.stock_movements
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and location_id = any ((select public.auth_location_ids())::uuid[]));
create policy stock_levels_store_read on public.stock_levels
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and location_id = any ((select public.auth_location_ids())::uuid[]));
create policy sales_store_read on public.sales
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and location_id = any ((select public.auth_location_ids())::uuid[]));
create policy sale_items_store_read on public.sale_items
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and location_id = any ((select public.auth_location_ids())::uuid[]));
create policy payments_store_read on public.payments
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and location_id = any ((select public.auth_location_ids())::uuid[]));

-- customers and utang: front-of-store roles only (warehouse staff do not see who owes what)
create policy customers_member_read on public.customers
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'admin', 'cashier'));
create policy customer_ledger_member_read on public.customer_ledger
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'admin', 'cashier'));

revoke all on public.stock_movements, public.stock_levels, public.sales, public.sale_items,
              public.payments, public.customers, public.customer_ledger from anon;
revoke insert, update, delete, truncate
  on public.stock_movements, public.stock_levels, public.sales, public.sale_items,
     public.payments, public.customers, public.customer_ledger
  from authenticated;
grant select on public.stock_movements, public.stock_levels, public.sales, public.sale_items,
                public.payments, public.customers, public.customer_ledger to authenticated;
