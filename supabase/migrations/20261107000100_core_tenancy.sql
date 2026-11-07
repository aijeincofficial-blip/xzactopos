-- P1-01 Core tenancy schema
-- Plan: docs/plan.md sections 4, 6 (Core), 15.
-- Rules: tenant_id on every tenant-owned table, RLS on every table, business keys unique per tenant,
-- UUIDv7 ids (client-generated; uuid_generate_v7() is only a server-side fallback), UTC timestamps,
-- soft delete via deleted_at. Policies are added in P1-03; until then RLS denies all client access.

-- ---------------------------------------------------------------------------
-- Shared functions
-- ---------------------------------------------------------------------------

-- RFC 9562 UUIDv7: 48-bit unix ms timestamp, version 7, random rest. Postgres 17 has no built-in.
create or replace function public.uuid_generate_v7()
returns uuid
language sql
volatile
set search_path = ''
as $$
  select encode(
    set_bit(
      set_bit(
        overlay(
          uuid_send(gen_random_uuid())
          placing substring(int8send(floor(extract(epoch from clock_timestamp()) * 1000)::bigint) from 3)
          from 1 for 6
        ),
        52, 1
      ),
      53, 1
    ),
    'hex'
  )::uuid;
$$;

comment on function public.uuid_generate_v7() is
  'Server-side UUIDv7 fallback. Clients generate their own UUIDv7 ids so offline rows never collide.';

-- updated_at is always server time, never trusted from the client (last-write-wins uses it).
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- A row can never move to another tenant.
create or replace function public.prevent_tenant_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.tenant_id is distinct from old.tenant_id then
    raise exception 'tenant_id is immutable' using errcode = '23514';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reference data (global, read-only to clients)
-- ---------------------------------------------------------------------------

create table public.currencies (
  code      char(3) primary key check (code ~ '^[A-Z]{3}$'),
  exponent  smallint not null check (exponent between 0 and 4),
  name      text not null check (length(name) between 1 and 60)
);

comment on table public.currencies is
  'ISO 4217 reference. Exponent drives minor units (JPY 0, USD 2, KWD 3). Mirrors DEFAULT_EXPONENTS in @pos/core.';

insert into public.currencies (code, exponent, name) values
  ('PHP', 2, 'Philippine peso'),
  ('USD', 2, 'US dollar'),
  ('EUR', 2, 'Euro'),
  ('GBP', 2, 'Pound sterling'),
  ('SGD', 2, 'Singapore dollar'),
  ('JPY', 0, 'Japanese yen'),
  ('KRW', 0, 'South Korean won'),
  ('KWD', 3, 'Kuwaiti dinar'),
  ('BHD', 3, 'Bahraini dinar');

-- ---------------------------------------------------------------------------
-- Tenants
-- ---------------------------------------------------------------------------

create table public.tenants (
  id                  uuid primary key default public.uuid_generate_v7(),
  name                text not null check (length(name) between 1 and 120),
  slug                text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$'),
  base_currency       char(3) not null references public.currencies (code),
  timezone            text not null default 'UTC' check (length(timezone) between 1 and 64),
  tax_mode            text not null default 'inclusive' check (tax_mode in ('inclusive', 'exclusive', 'none')),
  plan                text not null default 'free' check (plan in ('free', 'pro')),
  status              text not null default 'active' check (status in ('active', 'suspended', 'archived')),
  setup_completed_at  timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz
);

comment on table public.tenants is 'One row per customer business. Its id is the tenant_id everywhere else.';

-- One row per tenant. Inventory is the always-on core; POS and Warehouse are add-ons that require it.
-- Booleans (not one row per module) so the "add-on implies inventory" rule is a single row check.
create table public.tenant_modules (
  tenant_id   uuid primary key references public.tenants (id) on delete cascade,
  inventory   boolean not null default true,
  pos         boolean not null default false,
  warehouse   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  constraint tenant_modules_inventory_always_on check (inventory)
);

create table public.tenant_settings (
  tenant_id             uuid primary key references public.tenants (id) on delete cascade,
  default_locale        text not null default 'en' check (default_locale in ('en', 'fil')),
  locales               text[] not null default '{en}' check (locales <@ array['en', 'fil']::text[] and cardinality(locales) >= 1),
  offline_session_days  smallint not null default 7 check (offline_session_days between 1 and 30),
  receipt_header        text check (length(receipt_header) <= 500),
  receipt_footer        text check (length(receipt_footer) <= 500),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz,
  constraint tenant_settings_default_locale_enabled check (default_locale = any (locales))
);

-- Entitlement caps, written only by the platform operator (no client write policy, ever).
create table public.tenant_limits (
  tenant_id      uuid primary key references public.tenants (id) on delete cascade,
  max_locations  integer not null default 25 check (max_locations >= 0),
  max_users      integer not null default 100 check (max_users >= 0),
  max_devices    integer not null default 50 check (max_devices >= 0),
  max_products   integer not null default 10000 check (max_products >= 0),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

-- Extra currencies a tenant accepts. Rates are set manually by admins (no external rate API).
create table public.tenant_currencies (
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  code          char(3) not null references public.currencies (code),
  rate_to_base  numeric(20, 10) not null check (rate_to_base > 0),
  rate_date     date not null default current_date,
  rounding      text not null default 'half-up' check (rounding in ('half-up', 'half-even', 'floor', 'ceil')),
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  primary key (tenant_id, code)
);

-- ---------------------------------------------------------------------------
-- Platform operator (not a tenant role)
-- ---------------------------------------------------------------------------

create table public.platform_admins (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

comment on table public.platform_admins is
  'Platform operators. Separate from tenant roles. Managed with the service role only.';

-- ---------------------------------------------------------------------------
-- People and places
-- ---------------------------------------------------------------------------

create table public.profiles (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  tenant_id   uuid not null references public.tenants (id) on delete cascade,
  username    text not null check (username ~ '^[a-z0-9][a-z0-9._-]{1,38}[a-z0-9]$'),
  full_name   text not null default '' check (length(full_name) <= 120),
  role        text not null check (role in ('superadmin', 'admin', 'warehouse', 'cashier')),
  pin_hash    text check (length(pin_hash) <= 255),
  locale      text check (locale in ('en', 'fil')),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  constraint profiles_username_per_tenant unique (tenant_id, username),
  constraint profiles_tenant_user unique (tenant_id, user_id)
);

comment on column public.profiles.pin_hash is 'PBKDF2 hash for offline unlock and manager overrides. Never the raw PIN.';

create table public.locations (
  id            uuid primary key default public.uuid_generate_v7(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  type          text not null check (type in ('store', 'warehouse')),
  code          text not null check (code ~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,19}$'),
  name          text not null check (length(name) between 1 and 120),
  address       text check (length(address) <= 500),
  bins_enabled  boolean not null default false,
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  constraint locations_code_per_tenant unique (tenant_id, code),
  constraint locations_tenant_id unique (tenant_id, id),
  constraint locations_bins_only_in_warehouses check (not bins_enabled or type = 'warehouse')
);

-- Store / warehouse scope per user. Not in the JWT (large, goes stale); read via has_location_access().
create table public.location_access (
  user_id      uuid not null,
  location_id  uuid not null,
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  position     text check (position in ('manager', 'supervisor')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  primary key (user_id, location_id),
  -- composite FKs: the user and the location must belong to the same tenant as the row
  constraint location_access_user_fk foreign key (tenant_id, user_id)
    references public.profiles (tenant_id, user_id) on delete cascade,
  constraint location_access_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id) on delete cascade
);

create index location_access_location_idx on public.location_access (location_id);
create index location_access_tenant_idx on public.location_access (tenant_id);

-- Role / location-type / position rules:
--   superadmin: never assigned (has every location implicitly)
--   admin:      stores only, position required (manager | supervisor)
--   cashier:    stores only, no position
--   warehouse:  warehouses only, no position
create or replace function public.validate_location_access()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_role text;
  v_type text;
begin
  select p.role into v_role
  from public.profiles p
  where p.user_id = new.user_id and p.tenant_id = new.tenant_id;

  select l.type into v_type
  from public.locations l
  where l.id = new.location_id and l.tenant_id = new.tenant_id;

  if v_role is null or v_type is null then
    raise exception 'user and location must exist in the same tenant' using errcode = '23503';
  end if;

  if v_role = 'superadmin' then
    raise exception 'superadmins have access to every location and are not assigned'
      using errcode = '23514';
  elsif v_role = 'admin' and (v_type <> 'store' or new.position is null) then
    raise exception 'admins are assigned to stores with a position (manager or supervisor)'
      using errcode = '23514';
  elsif v_role = 'cashier' and (v_type <> 'store' or new.position is not null) then
    raise exception 'cashiers are assigned to stores without a position'
      using errcode = '23514';
  elsif v_role = 'warehouse' and (v_type <> 'warehouse' or new.position is not null) then
    raise exception 'warehouse users are assigned to warehouses without a position'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger location_access_validate
  before insert or update of user_id, location_id, tenant_id, position
  on public.location_access
  for each row execute function public.validate_location_access();

-- ---------------------------------------------------------------------------
-- Audit log (append-only; written by RPCs only)
-- ---------------------------------------------------------------------------

create table public.audit_log (
  id          uuid primary key default public.uuid_generate_v7(),
  tenant_id   uuid not null references public.tenants (id) on delete cascade,
  user_id     uuid references auth.users (id) on delete set null,
  action      text not null check (length(action) between 1 and 64),
  entity      text not null check (length(entity) between 1 and 64),
  entity_id   uuid,
  meta        jsonb not null default '{}'::jsonb check (pg_column_size(meta) <= 2048),
  created_at  timestamptz not null default now()
);

comment on table public.audit_log is
  'Append-only. Small payloads only. No updated_at/deleted_at: rows are never edited or synced to devices.';

create index audit_log_tenant_created_idx on public.audit_log (tenant_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Triggers: updated_at and tenant immutability
-- ---------------------------------------------------------------------------

create trigger tenants_set_updated_at before update on public.tenants
  for each row execute function public.set_updated_at();

do $$
declare
  t text;
begin
  foreach t in array array[
    'tenant_modules', 'tenant_settings', 'tenant_limits', 'tenant_currencies',
    'profiles', 'locations', 'location_access'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update of tenant_id on public.%I for each row execute function public.prevent_tenant_change()',
      t || '_tenant_immutable', t);
  end loop;
end;
$$;

create trigger audit_log_tenant_immutable before update of tenant_id on public.audit_log
  for each row execute function public.prevent_tenant_change();

-- ---------------------------------------------------------------------------
-- Row level security: on for every table. No client policies yet (P1-03), so access is denied.
-- ---------------------------------------------------------------------------

alter table public.currencies        enable row level security;
alter table public.tenants           enable row level security;
alter table public.tenant_modules    enable row level security;
alter table public.tenant_settings   enable row level security;
alter table public.tenant_limits     enable row level security;
alter table public.tenant_currencies enable row level security;
alter table public.platform_admins   enable row level security;
alter table public.profiles          enable row level security;
alter table public.locations         enable row level security;
alter table public.location_access   enable row level security;
alter table public.audit_log         enable row level security;

-- Reference data is safe to read for any signed-in user.
create policy currencies_read on public.currencies
  for select to authenticated using (true);

-- Belt and braces: anon gets nothing on tenant data even if a policy is added by mistake later.
revoke all on
  public.tenants, public.tenant_modules, public.tenant_settings, public.tenant_limits,
  public.tenant_currencies, public.platform_admins, public.profiles, public.locations,
  public.location_access, public.audit_log, public.currencies
from anon;

-- Clients never write these directly.
revoke insert, update, delete on public.audit_log, public.platform_admins, public.tenant_limits, public.currencies
from authenticated;
