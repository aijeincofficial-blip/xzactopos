-- P8-06 Load / e-wallet service ledger (GCash / Maya cash-in and cash-out, prepaid load, wallet float).
--   service_txns            append-only ledger entry; the only change ever allowed is a void (voided_at + void_reason)
--   wallet_float            per store and wallet: running balance of the store's own e-wallet / load money (trigger-kept)
--   daily_service_summary   per store, day (tenant timezone) and kind: count, amount, fee, cash effect, float effect
--   op_record_service_txn   through sync_push, idempotent by op id
--   op_void_service_txn     through sync_push; a reversing state, never an edit or a delete
--   sync_pull_service       keyset delta pull of service_txns (same rules as sync_pull_expenses) + the float balances
--   day_close_server_expected, report_summary, approve_supervisor_action, sync_push: re-created (additive)
--
-- Money model (base-currency centavos; "cash" = the drawer, "float" = the wallet named by `wallet`).
-- The fee is ALWAYS collected in cash, on top of the principal, and is the store's income for the entry.
--   kind            amount              fee      price          cash effect        float effect   income
--   cash_in         principal > 0       >= 0     -              + amount + fee     - amount       fee
--   cash_out        principal > 0       >= 0     -              - amount + fee     + amount       fee
--   load            wallet debit > 0    = price - amount        + price            - amount       fee (price - amount)
--   float_topup     > 0                 0        -              - amount           + amount       0
--   float_withdraw  > 0                 0        -              + amount           - amount       0
--   float_adjust    signed, non-zero    0        -              0                  + amount       0
-- For every kind but float_adjust: cash effect + float effect = fee (the store's money only grows by its income).
-- Load: `amount` is what the wallet is actually debited (face value, or the discounted cost when the provider debits less),
-- `price` is the cash the customer pays; the margin is stored as the fee. A rebate credited later is a float_adjust.
-- cash_in / cash_out never use the `load` wallet. A load may come from any wallet (default `load`; GCash "Buy Load" = gcash).
--
-- Who may record or void (the UI hides; this enforces):
--   cash_in, cash_out, load ......... anyone who may sell at the store (owner, admin, cashier; not warehouse)
--   float_topup, float_withdraw ..... owner, store manager; a store supervisor with a supervisor approval
--                                     (action 'record_service_txn', ref_id = the txn id); cashiers never
--   float_adjust (needs a note) ..... owner or store manager only
--   void (any kind) ................. owner, store manager; a store supervisor with an approval ('void_service_txn');
--                                     voiding a float_adjust: owner or store manager only
-- Reads: service_txns and wallet_float by owner, admins and cashiers of the store (front of store);
--        daily_service_summary by owner and admins (like the other rollups). Nobody writes from a client.
-- Audit: one row per record / void ('service.record' / 'service.void', entity 'service_txn'); the customer reference
-- (`ref`, e.g. a phone number) and the note are never put in the audit meta. Replays write nothing.

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table public.service_txns (
  id                uuid primary key,
  tenant_id         uuid not null references public.tenants (id) on delete cascade,
  location_id       uuid not null,
  client_op_id      uuid not null,
  kind              text not null
                    check (kind in ('cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust')),
  wallet            text not null check (wallet in ('gcash', 'maya', 'load', 'other')),
  -- base-currency minor units (centavos); positive, except a float_adjust which is signed and never zero
  amount            bigint not null,
  fee               bigint not null default 0 check (fee >= 0),
  price             bigint,
  currency          char(3) not null references public.currencies (code),
  -- customer reference (phone number, wallet reference no.). Sensitive: never copied into audit_log.
  ref               text check (length(ref) <= 200),
  note              text check (length(note) <= 200),
  txn_at            timestamptz not null,
  created_by        uuid references auth.users (id) on delete set null,
  approved_by       uuid references auth.users (id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  voided_at         timestamptz,
  void_reason       text check (length(void_reason) <= 200),
  void_approved_by  uuid references auth.users (id) on delete set null,
  constraint service_txns_tenant_id unique (tenant_id, id),
  constraint service_txns_client_op_per_tenant unique (tenant_id, client_op_id),
  constraint service_txns_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint service_txns_amount check (amount <> 0 and (kind = 'float_adjust' or amount > 0)),
  constraint service_txns_fee_kind check (fee = 0 or kind in ('cash_in', 'cash_out', 'load')),
  constraint service_txns_price check ((kind = 'load') = (price is not null) and (price is null or price = amount + fee)),
  constraint service_txns_wallet_kind check (kind not in ('cash_in', 'cash_out') or wallet <> 'load'),
  constraint service_txns_adjust_note check (kind <> 'float_adjust' or note is not null),
  constraint service_txns_void_consistent check (void_reason is null or voided_at is not null),
  constraint service_txns_void_approval_consistent check (void_approved_by is null or voided_at is not null)
);

comment on table public.service_txns is
  'Append-only load / e-wallet service ledger. Written only by op_record_service_txn; the only change is a void.';

create index service_txns_tenant_at_idx      on public.service_txns (tenant_id, txn_at desc, id);
create index service_txns_tenant_updated_idx on public.service_txns (tenant_id, updated_at, id);

create trigger service_txns_set_updated_at before update on public.service_txns
  for each row execute function public.set_updated_at();

-- Rows never change except: void once (voided_at null -> set, with void_reason / void_approved_by), and
-- created_by / approved_by / void_approved_by going to null when that user is removed.
create or replace function public.guard_service_txn_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_voiding boolean;
begin
  if tg_op = 'DELETE' then
    raise exception 'service_txns is append-only' using errcode = '55000', hint = 'append_only';
  end if;
  if (new.id, new.tenant_id, new.location_id, new.client_op_id, new.kind, new.wallet, new.amount, new.fee, new.price,
      new.currency, new.ref, new.note, new.txn_at, new.created_at, new.deleted_at)
     is distinct from
     (old.id, old.tenant_id, old.location_id, old.client_op_id, old.kind, old.wallet, old.amount, old.fee, old.price,
      old.currency, old.ref, old.note, old.txn_at, old.created_at, old.deleted_at)
     or (new.created_by is distinct from old.created_by and new.created_by is not null)
     or (new.approved_by is distinct from old.approved_by and new.approved_by is not null) then
    raise exception 'service_txns is append-only; only a void is allowed' using errcode = '55000', hint = 'append_only';
  end if;
  v_voiding := old.voided_at is null and new.voided_at is not null;
  if (new.voided_at is distinct from old.voided_at or new.void_reason is distinct from old.void_reason)
     and not v_voiding then
    raise exception 'a service entry can be voided once and never un-voided' using errcode = '55000', hint = 'append_only';
  end if;
  if new.void_approved_by is distinct from old.void_approved_by and new.void_approved_by is not null and not v_voiding then
    raise exception 'the void approval is set only by the void' using errcode = '55000', hint = 'append_only';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_service_txn_change() from public, anon, authenticated;

create trigger service_txns_guard before update or delete on public.service_txns
  for each row execute function public.guard_service_txn_change();

-- ---------------------------------------------------------------------------
-- The money model as two pure functions (the only place it is written down in SQL)
-- ---------------------------------------------------------------------------

create or replace function public.service_cash_effect(p_kind text, p_amount bigint, p_fee bigint, p_price bigint)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select (case p_kind
    when 'cash_in'        then p_amount + p_fee
    when 'cash_out'       then p_fee - p_amount
    when 'load'           then p_price
    when 'float_topup'    then -p_amount
    when 'float_withdraw' then p_amount
    else 0
  end)::bigint
$$;

create or replace function public.service_float_effect(p_kind text, p_amount bigint)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select (case p_kind
    when 'cash_in'        then -p_amount
    when 'load'           then -p_amount
    when 'float_withdraw' then -p_amount
    when 'cash_out'       then p_amount
    when 'float_topup'    then p_amount
    when 'float_adjust'   then p_amount
    else 0
  end)::bigint
$$;

revoke execute on function public.service_cash_effect(text, bigint, bigint, bigint) from public, anon, authenticated;
revoke execute on function public.service_float_effect(text, bigint) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Derived tables. Kept by plain AFTER triggers (inside the op's subtransaction: a refused op leaves nothing).
-- ---------------------------------------------------------------------------

-- The store's money in each wallet. May go below zero (the tindera recorded a cash-in before the top-up):
-- allowed, so a sale is never blocked, but flagged (`negative`) for the UI.
create table public.wallet_float (
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  location_id  uuid not null,
  wallet       text not null check (wallet in ('gcash', 'maya', 'load', 'other')),
  balance      bigint not null default 0,
  -- non-voided entries that moved this wallet
  txn_count    int not null default 0,
  negative     boolean generated always as (balance < 0) stored,
  updated_at   timestamptz not null default now(),
  primary key (location_id, wallet),
  constraint wallet_float_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id)
);

create index wallet_float_tenant_idx on public.wallet_float (tenant_id);

create table public.daily_service_summary (
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  location_id   uuid not null,
  day           date not null,
  kind          text not null,
  txn_count     int not null default 0,
  amount        bigint not null default 0,
  fee           bigint not null default 0,
  -- sum of the cash effects (what the drawer gained, below zero when it paid out) and of the float effects
  cash          bigint not null default 0,
  float_change  bigint not null default 0,
  updated_at    timestamptz not null default now(),
  primary key (location_id, day, kind),
  constraint daily_service_summary_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id)
);

create index daily_service_summary_tenant_day_idx on public.daily_service_summary (tenant_id, day);

-- Adds (p_sign = 1) or removes (p_sign = -1) one service entry.
create or replace function public.rollup_service_txn(t public.service_txns, p_sign int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz    text;
  v_day   date;
  v_cash  bigint := public.service_cash_effect(t.kind, t.amount, t.fee, t.price);
  v_float bigint := public.service_float_effect(t.kind, t.amount);
begin
  select coalesce(x.timezone, 'UTC') into v_tz from public.tenants x where x.id = t.tenant_id;
  v_day := (t.txn_at at time zone coalesce(v_tz, 'UTC'))::date;

  insert into public.daily_service_summary as d
    (tenant_id, location_id, day, kind, txn_count, amount, fee, cash, float_change, updated_at)
  values (t.tenant_id, t.location_id, v_day, t.kind, p_sign, p_sign * t.amount, p_sign * t.fee,
          p_sign * v_cash, p_sign * v_float, now())
  on conflict (location_id, day, kind) do update set
    txn_count = d.txn_count + excluded.txn_count, amount = d.amount + excluded.amount, fee = d.fee + excluded.fee,
    cash = d.cash + excluded.cash, float_change = d.float_change + excluded.float_change, updated_at = now();

  insert into public.wallet_float as w (tenant_id, location_id, wallet, balance, txn_count, updated_at)
  values (t.tenant_id, t.location_id, t.wallet, p_sign * v_float, p_sign, now())
  on conflict (location_id, wallet) do update set
    balance = w.balance + excluded.balance, txn_count = w.txn_count + excluded.txn_count, updated_at = now();
end;
$$;

create or replace function public.trg_rollup_service_txn()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.voided_at is null then
      perform public.rollup_service_txn(new, 1);
    end if;
  elsif old.voided_at is null and new.voided_at is not null then
    perform public.rollup_service_txn(old, -1);
  end if;
  return null;
end;
$$;

revoke execute on function public.rollup_service_txn(public.service_txns, int) from public, anon, authenticated;
revoke execute on function public.trg_rollup_service_txn() from public, anon, authenticated;

create trigger service_txns_rollup_insert after insert on public.service_txns
  for each row execute function public.trg_rollup_service_txn();
create trigger service_txns_rollup_void after update of voided_at on public.service_txns
  for each row execute function public.trg_rollup_service_txn();

-- ---------------------------------------------------------------------------
-- RLS. service_txns + wallet_float: front of store (owner, admins, cashiers) at their stores.
-- daily_service_summary: owner and admins at their stores. No client writes anywhere.
-- ---------------------------------------------------------------------------

alter table public.service_txns enable row level security;
alter table public.wallet_float enable row level security;
alter table public.daily_service_summary enable row level security;

create policy service_txns_read on public.service_txns
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'admin', 'cashier')
         and location_id = any ((select public.auth_location_ids())::uuid[]));
create policy wallet_float_read on public.wallet_float
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'admin', 'cashier')
         and location_id = any ((select public.auth_location_ids())::uuid[]));
create policy daily_service_summary_read on public.daily_service_summary
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'admin')
         and location_id = any ((select public.auth_location_ids())::uuid[]));

revoke all on public.service_txns, public.wallet_float, public.daily_service_summary from anon;
revoke insert, update, delete, truncate on public.service_txns, public.wallet_float, public.daily_service_summary
  from authenticated;
grant select on public.service_txns, public.wallet_float, public.daily_service_summary to authenticated;

-- ---------------------------------------------------------------------------
-- Approvals: the two service actions join the actions a supervisor approval can cover
-- ---------------------------------------------------------------------------

alter table public.supervisor_approvals drop constraint supervisor_approvals_action_check;
alter table public.supervisor_approvals add constraint supervisor_approvals_action_check
  check (action in ('record_expense', 'void_expense', 'close_day', 'record_service_txn', 'void_service_txn'));

-- approve_supervisor_action re-created (from 20261108001300); the only change is the two service actions
-- ('record_service_txn': ref_id = the txn id the client made, for a float top-up / withdraw;
--  'void_service_txn': ref_id = the txn id; the store is the txn's store when the server has it).
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
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin') then
    raise exception 'not allowed to ask for approvals' using errcode = '42501', hint = 'not_allowed';
  end if;
  if p_action is null
     or p_action not in ('record_expense', 'void_expense', 'close_day', 'record_service_txn', 'void_service_txn')
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
  end if;
  if v_loc is null then
    v_loc := public.resolve_store(p_location_id);
  end if;
  if not public.has_location_access(v_loc, 'supervisor') then
    raise exception 'not a supervisor of this store' using errcode = '42501', hint = 'not_allowed';
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

-- owner, or an admin who is manager of the store (float_adjust and voiding one)
create or replace function public.is_store_manager_or_owner(p_location_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_superadmin() or (public.auth_role() = 'admin' and public.has_location_access(p_location_id, 'manager'))
$$;

revoke execute on function public.is_store_manager_or_owner(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_record_service_txn
--   p = { id, kind, wallet?, amount, fee?, price? (load only), ref?, note?, txn_at?, currency?, location_id?, approval_id? }
--   Money: whole centavos (JSON number or digit string; a float_adjust amount may carry a minus sign).
--   wallet: gcash | maya | load | other (default `load` for a load; required otherwise).
--   load: price required (>= amount); fee is price - amount (if sent it must equal that).
--   float kinds: fee must be 0 or missing. float_adjust: note required.
--   Returns { txn_id, kind, fee, approved_by, applied_at }.
-- ---------------------------------------------------------------------------

create or replace function public.op_record_service_txn(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_replay   jsonb;
  v_loc      uuid;
  v_id       uuid;
  v_kind     text;
  v_wallet   text;
  v_txt      text;
  v_amt      bigint;
  v_fee      bigint;
  v_price    bigint;
  v_base     text;
  v_ccy      text;
  v_at       timestamptz;
  v_ref      text;
  v_note     text;
  v_appr     uuid;
begin
  -- active user, POS module on, superadmin | admin | cashier (who may sell)
  perform public.assert_seller();
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'service entry must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'record_service_txn');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);

  v_id := (p ->> 'id')::uuid;
  if v_id is null then
    raise exception 'service entry id is required' using errcode = '22023', hint = 'id_required';
  end if;

  v_kind := p ->> 'kind';
  if v_kind is null or v_kind not in ('cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust') then
    raise exception 'kind is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_wallet := coalesce(nullif(p ->> 'wallet', ''), case when v_kind = 'load' then 'load' end);
  if v_wallet is null or v_wallet not in ('gcash', 'maya', 'load', 'other')
     or (v_kind in ('cash_in', 'cash_out') and v_wallet = 'load') then
    raise exception 'wallet is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;

  -- amount: whole centavos; signed only for a float_adjust; never zero
  v_txt := p ->> 'amount';
  if not coalesce(jsonb_typeof(p -> 'amount') in ('number', 'string')
                  and v_txt ~ (case when v_kind = 'float_adjust' then '^-?[0-9]{1,15}$' else '^[0-9]{1,15}$' end), false) then
    raise exception 'amount must be whole centavos' using errcode = '22023', hint = 'amount_invalid';
  end if;
  v_amt := v_txt::bigint;
  if v_amt = 0 then
    raise exception 'amount must not be zero' using errcode = '22023', hint = 'amount_invalid';
  end if;

  -- fee: optional whole centavos >= 0
  if coalesce(jsonb_typeof(p -> 'fee'), 'null') <> 'null' then
    v_txt := p ->> 'fee';
    if not coalesce(jsonb_typeof(p -> 'fee') in ('number', 'string') and v_txt ~ '^[0-9]{1,15}$', false) then
      raise exception 'fee must be whole centavos' using errcode = '22023', hint = 'amount_invalid';
    end if;
    v_fee := v_txt::bigint;
  end if;

  if v_kind = 'load' then
    v_txt := p ->> 'price';
    if not coalesce(jsonb_typeof(p -> 'price') in ('number', 'string') and v_txt ~ '^[0-9]{1,15}$', false) then
      raise exception 'a load needs the price the customer pays' using errcode = '22023', hint = 'amount_invalid';
    end if;
    v_price := v_txt::bigint;
    if v_price < v_amt or (v_fee is not null and v_fee <> v_price - v_amt) then
      raise exception 'load price must cover the amount; fee = price - amount' using errcode = '22023', hint = 'amount_invalid';
    end if;
    v_fee := v_price - v_amt;
  else
    if coalesce(jsonb_typeof(p -> 'price'), 'null') <> 'null' then
      raise exception 'only a load has a price' using errcode = '22023', hint = 'invalid_value';
    end if;
    if v_kind in ('float_topup', 'float_withdraw', 'float_adjust') and coalesce(v_fee, 0) <> 0 then
      raise exception 'moving float has no fee' using errcode = '22023', hint = 'amount_invalid';
    end if;
    v_fee := coalesce(v_fee, 0);
  end if;

  select t.base_currency into v_base from public.tenants t where t.id = v_tenant;
  v_ccy := coalesce(upper(nullif(btrim(p ->> 'currency'), '')), v_base);
  if v_ccy is distinct from v_base then
    raise exception 'service entries are in the base currency' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_at := coalesce((p ->> 'txn_at')::timestamptz, now());
  v_ref := left(nullif(btrim(p ->> 'ref'), ''), 200);
  v_note := left(nullif(btrim(p ->> 'note'), ''), 200);
  if v_kind = 'float_adjust' and v_note is null then
    raise exception 'a float correction needs a note' using errcode = '22023', hint = 'note_required';
  end if;

  -- customer services: any seller at the store (resolve_store checked the access). Moving float: see the header.
  if v_kind = 'float_adjust' then
    if not public.is_store_manager_or_owner(v_loc) then
      raise exception 'only the owner or the store manager corrects a float' using errcode = '42501', hint = 'not_allowed';
    end if;
  elsif v_kind in ('float_topup', 'float_withdraw') then
    v_appr := public.authorize_expense_write(v_loc, 'record_service_txn', v_id, (p ->> 'approval_id')::uuid, p_op_id);
  end if;

  begin
    insert into public.service_txns (id, tenant_id, location_id, client_op_id, kind, wallet, amount, fee, price, currency,
                                     ref, note, txn_at, created_by, approved_by)
    values (v_id, v_tenant, v_loc, p_op_id, v_kind, v_wallet, v_amt, v_fee, v_price, v_ccy,
            v_ref, v_note, v_at, auth.uid(), v_appr);
  exception when unique_violation then
    raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  -- no ref, no note: the customer reference is sensitive
  perform public.write_audit('service.record', 'service_txn', v_id, v_loc, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_loc, 'kind', v_kind, 'wallet', v_wallet, 'amount', v_amt, 'fee', v_fee,
    'op_id', p_op_id, 'approved_by', v_appr)));
  return public.finish_op(p_op_id, jsonb_build_object(
    'txn_id', v_id, 'kind', v_kind, 'fee', v_fee, 'approved_by', v_appr, 'applied_at', now()));
end;
$$;

-- ---------------------------------------------------------------------------
-- op_void_service_txn   p = { txn_id, reason?, approval_id? }
--   Sets voided_at / void_reason once; the triggers take the entry back out of the float and the day summary.
--   Voiding twice changes and logs nothing ({ already: true }). Returns { txn_id, already, approved_by, applied_at }.
-- ---------------------------------------------------------------------------

create or replace function public.op_void_service_txn(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_tid    uuid;
  v_txn    public.service_txns;
  v_appr   uuid;
  v_reason text;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin') then
    raise exception 'not allowed to void service entries' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'void must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'void_service_txn');
  if v_replay is not null then
    return v_replay;
  end if;

  v_tid := (p ->> 'txn_id')::uuid;
  select * into v_txn from public.service_txns where id = v_tid and tenant_id = v_tenant for update;
  if not found then
    raise exception 'service entry not found' using errcode = '22023', hint = 'txn_not_found';
  end if;
  if v_txn.kind = 'float_adjust' and not public.is_store_manager_or_owner(v_txn.location_id) then
    raise exception 'only the owner or the store manager voids a float correction' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_appr := public.authorize_expense_write(v_txn.location_id, 'void_service_txn', v_tid, (p ->> 'approval_id')::uuid, p_op_id);

  if v_txn.voided_at is not null then
    return public.finish_op(p_op_id, jsonb_build_object('txn_id', v_tid, 'already', true, 'approved_by', v_appr,
                                                        'applied_at', now()));
  end if;

  v_reason := left(nullif(btrim(p ->> 'reason'), ''), 200);
  update public.service_txns
     set voided_at = now(), void_reason = v_reason, void_approved_by = v_appr
   where id = v_tid and tenant_id = v_tenant;

  perform public.write_audit('service.void', 'service_txn', v_tid, v_txn.location_id, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_txn.location_id, 'kind', v_txn.kind, 'wallet', v_txn.wallet, 'amount', v_txn.amount, 'fee', v_txn.fee,
    'reason', v_reason, 'op_id', p_op_id, 'approved_by', v_appr)));
  return public.finish_op(p_op_id, jsonb_build_object('txn_id', v_tid, 'already', false, 'approved_by', v_appr,
                                                      'applied_at', now()));
end;
$$;

revoke execute on function public.op_record_service_txn(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_void_service_txn(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_service(cursor, limit)   same rules as sync_pull_expenses, plus the float balances
--   first pull (cursor null) = entries from the last 30 days by txn_at; afterwards delta by (updated_at, id);
--   rows newer than now - 5 s wait for the next pull; a voided entry comes again (its updated_at moves).
--   `floats` is the CURRENT balance of every wallet of every store the caller can see (small; never held back),
--   read in the same statement as the rows, at `server_time`.
--   Runs as the caller: owner, admins and cashiers of the store get rows; warehouse staff none (RLS).
--   Returns { rows: [ { id, location_id, kind, wallet, amount, fee, price, currency, ref, note, txn_at, created_by,
--                       approved_by, voided_at, void_reason, void_approved_by, updated_at } ],
--             floats: [ { location_id, wallet, balance, negative, txn_count, updated_at } ],
--             cursor, has_more, server_time }.
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_service(p_cursor jsonb default null, p_limit int default 100)
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
  v_floats jsonb;
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'limit must be 1 to 200' using errcode = '22023', hint = 'invalid_value';
  end if;

  with s as (
    select x.id, x.location_id, x.kind, x.wallet, x.amount, x.fee, x.price, x.currency, x.ref, x.note, x.txn_at,
           x.created_by, x.approved_by, x.voided_at, x.void_reason, x.void_approved_by, x.updated_at
    from public.service_txns x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and (v_ts is null and x.txn_at >= now() - interval '30 days'
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'kind', g.kind, 'wallet', g.wallet, 'amount', g.amount,
        'fee', g.fee, 'price', g.price, 'currency', g.currency, 'ref', g.ref, 'note', g.note, 'txn_at', g.txn_at,
        'created_by', g.created_by, 'approved_by', g.approved_by, 'voided_at', g.voided_at,
        'void_reason', g.void_reason, 'void_approved_by', g.void_approved_by, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1),
    coalesce((select jsonb_agg(jsonb_build_object(
        'location_id', w.location_id, 'wallet', w.wallet, 'balance', w.balance, 'negative', w.negative,
        'txn_count', w.txn_count, 'updated_at', w.updated_at) order by w.location_id, w.wallet)
      from public.wallet_float w where w.tenant_id = v_tenant), '[]'::jsonb)
  into v_more, v_rows, v_last, v_floats;

  return jsonb_build_object('rows', v_rows, 'floats', v_floats, 'cursor', coalesce(v_last, p_cursor),
                            'has_more', v_more, 'server_time', now());
end;
$$;

revoke execute on function public.sync_pull_service(jsonb, int) from public, anon;
grant execute on function public.sync_pull_service(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- day_close_server_expected re-created (from 20261108001300): the drawer's service cash now counts.
--   + cash_in amount + fee, - cash_out amount + fee, + load price, - float_topup, + float_withdraw (voided left out),
--   read from daily_service_summary.cash for that store and day (same tenant-timezone day as everything else).
-- ---------------------------------------------------------------------------

create or replace function public.day_close_server_expected(p_tenant uuid, p_location_id uuid, p_day date)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz    text;
  v_from  timestamptz;
  v_to    timestamptz;
  v_sales bigint;
  v_utang bigint;
  v_exp   bigint;
  v_svc   bigint;
begin
  select coalesce(t.timezone, 'UTC') into v_tz from public.tenants t where t.id = p_tenant;
  v_from := p_day::timestamp at time zone coalesce(v_tz, 'UTC');
  v_to   := (p_day + 1)::timestamp at time zone coalesce(v_tz, 'UTC');

  select coalesce(sum(p.amount), 0) into v_sales
  from public.sales s
  join public.payments p on p.sale_id = s.id and p.tenant_id = s.tenant_id
  where s.tenant_id = p_tenant and s.location_id = p_location_id and s.status = 'completed'
    and s.sold_at >= v_from and s.sold_at < v_to and p.method = 'cash';

  -- payments are stored negative
  select coalesce(-sum(l.amount), 0) into v_utang
  from public.customer_ledger l
  where l.tenant_id = p_tenant and l.kind = 'payment' and l.occurred_at >= v_from and l.occurred_at < v_to;

  select coalesce(sum(e.amount), 0) into v_exp
  from public.expenses e
  where e.tenant_id = p_tenant and e.location_id = p_location_id and e.voided_at is null and e.paid_from = 'cash'
    and e.spent_at >= v_from and e.spent_at < v_to;

  select coalesce(sum(d.cash), 0) into v_svc
  from public.daily_service_summary d
  where d.tenant_id = p_tenant and d.location_id = p_location_id and d.day = p_day;

  return v_sales + v_utang - v_exp + v_svc;
end;
$$;

revoke execute on function public.day_close_server_expected(uuid, uuid, date) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- report_summary re-created (from 20261108001100) with a `services` block. Every other key is unchanged.
--   services = { count,      -- customer services (cash_in + cash_out + load), voided left out
--                fee_total,  -- the store's service income in the range (NOT part of totals.net)
--                by_kind: [ { kind, count, amount, fee } ],   -- fixed kind order, kinds with no entries left out
--                float:   [ { wallet, balance } ] }            -- current balance per wallet over the caller's stores
-- ---------------------------------------------------------------------------

create or replace function public.report_summary(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_days   jsonb;
  v_totals jsonb;
  v_top    jsonb;
  v_utang  jsonb;
  v_exp    jsonb;
  v_svc    jsonb;
  v_kinds  text[] := array['cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust'];
  v_wals   text[] := array['gcash', 'maya', 'load', 'other'];
begin
  if v_tenant is null then
    raise exception 'not signed in to an active account' using errcode = '42501', hint = 'no_account';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then
    raise exception 'date range is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.day), '[]'::jsonb) into v_days from (
    select d.day, sum(d.net)::bigint as net, sum(d.gross)::bigint as gross, sum(d.discount)::bigint as discount,
           sum(d.cogs)::bigint as cogs, sum(d.txn_count)::int as txns,
           sum(d.cash)::bigint as cash, sum(d.ewallet)::bigint as ewallet, sum(d.utang)::bigint as utang
    from public.daily_sales_summary d
    where d.tenant_id = v_tenant and d.day between p_from and p_to
    group by d.day
  ) x;

  select jsonb_build_object(
    'net', coalesce(sum(d.net), 0), 'gross', coalesce(sum(d.gross), 0), 'discount', coalesce(sum(d.discount), 0),
    'cogs', coalesce(sum(d.cogs), 0), 'txns', coalesce(sum(d.txn_count), 0),
    'cash', coalesce(sum(d.cash), 0), 'ewallet', coalesce(sum(d.ewallet), 0), 'utang', coalesce(sum(d.utang), 0))
  into v_totals
  from public.daily_sales_summary d
  where d.tenant_id = v_tenant and d.day between p_from and p_to;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue desc, x.name), '[]'::jsonb) into v_top from (
    select i.variant_id, max(i.product_name) as name, sum(i.qty) as qty, sum(i.revenue)::bigint as revenue
    from public.daily_item_sales i
    where i.tenant_id = v_tenant and i.day between p_from and p_to
    group by i.variant_id
    having sum(i.qty) > 0
    order by sum(i.revenue) desc, max(i.product_name)
    limit 10
  ) x;

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
    group by c.id, c.name
  ) b;

  select jsonb_build_object(
    'total', coalesce(sum(e.amount), 0), 'cash', coalesce(sum(e.cash), 0), 'ewallet', coalesce(sum(e.ewallet), 0),
    'count', coalesce(sum(e.entry_count), 0),
    'by_category', coalesce((
      select jsonb_agg(jsonb_build_object('category', c.category, 'amount', c.amount, 'count', c.n)
                       order by c.amount desc, c.category)
      from (select e2.category, sum(e2.amount)::bigint as amount, sum(e2.entry_count)::int as n
            from public.daily_expense_summary e2
            where e2.tenant_id = v_tenant and e2.day between p_from and p_to
            group by e2.category
            having sum(e2.entry_count) > 0) c), '[]'::jsonb),
    'days', coalesce((
      select jsonb_agg(jsonb_build_object('day', dd.day, 'amount', dd.amount) order by dd.day)
      from (select e3.day, sum(e3.amount)::bigint as amount
            from public.daily_expense_summary e3
            where e3.tenant_id = v_tenant and e3.day between p_from and p_to
            group by e3.day
            having sum(e3.entry_count) > 0) dd), '[]'::jsonb))
  into v_exp
  from public.daily_expense_summary e
  where e.tenant_id = v_tenant and e.day between p_from and p_to;

  select jsonb_build_object(
    'count', coalesce(sum(s.txn_count) filter (where s.kind in ('cash_in', 'cash_out', 'load')), 0),
    'fee_total', coalesce(sum(s.fee), 0),
    'by_kind', coalesce((
      select jsonb_agg(jsonb_build_object('kind', k.kind, 'count', k.n, 'amount', k.amount, 'fee', k.fee)
                       order by array_position(v_kinds, k.kind))
      from (select s2.kind, sum(s2.txn_count)::int as n, sum(s2.amount)::bigint as amount, sum(s2.fee)::bigint as fee
            from public.daily_service_summary s2
            where s2.tenant_id = v_tenant and s2.day between p_from and p_to
            group by s2.kind
            having sum(s2.txn_count) > 0) k), '[]'::jsonb),
    'float', coalesce((
      select jsonb_agg(jsonb_build_object('wallet', f.wallet, 'balance', f.balance) order by array_position(v_wals, f.wallet))
      from (select w.wallet, sum(w.balance)::bigint as balance
            from public.wallet_float w
            where w.tenant_id = v_tenant
            group by w.wallet) f), '[]'::jsonb))
  into v_svc
  from public.daily_service_summary s
  where s.tenant_id = v_tenant and s.day between p_from and p_to;

  return jsonb_build_object('from', p_from, 'to', p_to, 'days', v_days, 'totals', v_totals,
                            'top_items', v_top, 'utang', v_utang, 'expenses', v_exp, 'services', v_svc,
                            'server_time', now());
end;
$$;

revoke execute on function public.report_summary(date, date) from public, anon;
grant execute on function public.report_summary(date, date) to authenticated;

-- ---------------------------------------------------------------------------
-- sync_push re-created (from 20261108001300, the newest definition) with record_service_txn and void_service_txn
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
