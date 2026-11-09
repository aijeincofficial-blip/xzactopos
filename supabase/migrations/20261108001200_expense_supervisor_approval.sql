-- P8-02b Supervisor credential and audit trail for expenses.
--
-- Who may record or void an expense at a store:
--   superadmin (the solo owner) ............ always, no credential
--   admin, manager of that store ........... always, no credential
--   admin, supervisor of that store ........ only with a supervisor approval (PIN step-up), single use
--   cashier, warehouse, anyone else ........ never
--
-- The credential (plan section 5: "supervisor or manager enters a PIN ... recorded with approved_by and validated on sync"):
--   1. set_my_pin(new, current?)          the user's own PIN, stored as PBKDF2-HMAC-SHA256 in profiles.pin_hash
--   2. approve_supervisor_action(...)     ONLINE. The approver (the supervisor themself, or a manager / the owner) types the PIN
--                                         on the device; the server checks it (5 wrong tries in 15 min = locked) and issues a
--                                         single-use approval bound to requester + store + action + expense id, valid 12 h.
--   3. record_expense / void_expense carry { approval_id } through the outbox; the op checks and uses it up and stores
--      approved_by (record) or void_approved_by (void). The PIN never enters the outbox, processed_ops, audit_log or the rows.
-- Every successful record / void writes one audit_log row (replays return before it, so they never log twice).
-- Wrong PINs are logged as 'pin.failed' (the approval RPC returns instead of raising, so the row is kept).
-- A refused op (missing / bad approval) is NOT logged: the op's subtransaction is rolled back by sync_push.

-- ---------------------------------------------------------------------------
-- PIN hashing (server side only). Format: pbkdf2_sha256$<iterations>$<salt base64>$<hash base64>
-- ---------------------------------------------------------------------------

create or replace function public.pbkdf2_sha256(p_pass text, p_salt bytea, p_iter int)
returns bytea
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  k bytea := convert_to(p_pass, 'UTF8');
  u bytea;
  t bit(256);
  i int;
begin
  if p_iter not between 1 and 1000000 then
    raise exception 'iterations out of range' using errcode = '22023';
  end if;
  -- one 32-byte block: T = U1 xor U2 xor ... xor Uc, U1 = HMAC(P, S || INT(1)), Ui = HMAC(P, Ui-1)
  u := extensions.hmac(p_salt || '\x00000001'::bytea, k, 'sha256');
  t := ('x' || encode(u, 'hex'))::bit(256);
  for i in 2..p_iter loop
    u := extensions.hmac(u, k, 'sha256');
    t := t # ('x' || encode(u, 'hex'))::bit(256);
  end loop;
  return decode((select string_agg(lpad(to_hex(substring(t from g * 32 + 1 for 32)::int), 8, '0'), '' order by g)
                 from generate_series(0, 7) g), 'hex');
end;
$$;

create or replace function public.pin_hash_make(p_pin text)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_salt bytea := extensions.gen_random_bytes(16);
  v_iter int := 20000;
begin
  return format('pbkdf2_sha256$%s$%s$%s', v_iter, encode(v_salt, 'base64'),
                encode(public.pbkdf2_sha256(p_pin, v_salt, v_iter), 'base64'));
end;
$$;

create or replace function public.pin_hash_check(p_pin text, p_hash text)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  v_parts text[] := string_to_array(p_hash, '$');
begin
  if p_pin is null or p_hash is null or cardinality(v_parts) <> 4 or v_parts[1] <> 'pbkdf2_sha256'
     or v_parts[2] !~ '^[0-9]{1,7}$' then
    return false;
  end if;
  return public.pbkdf2_sha256(p_pin, decode(v_parts[3], 'base64'), v_parts[2]::int) = decode(v_parts[4], 'base64');
end;
$$;

-- One PIN try for p_user, counted for the lockout: 'ok' | 'wrong' | 'locked' | 'not_set'. A wrong try is written to audit_log.
create or replace function public.pin_attempt(p_user uuid, p_pin text, p_location_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_hash   text;
begin
  select p.pin_hash into v_hash from public.profiles p where p.user_id = p_user and p.tenant_id = v_tenant;
  if v_hash is null then
    return 'not_set';
  end if;
  if (select count(*) from public.audit_log a
      where a.tenant_id = v_tenant and a.action = 'pin.failed' and a.entity = 'profile' and a.entity_id = p_user
        and a.created_at > now() - interval '15 minutes') >= 5 then
    return 'locked';
  end if;
  if public.pin_hash_check(p_pin, v_hash) then
    return 'ok';
  end if;
  perform public.write_audit('pin.failed', 'profile', p_user, p_location_id, '{}'::jsonb);
  return 'wrong';
end;
$$;

revoke execute on function public.pbkdf2_sha256(text, bytea, int) from public, anon, authenticated;
revoke execute on function public.pin_hash_make(text) from public, anon, authenticated;
revoke execute on function public.pin_hash_check(text, text) from public, anon, authenticated;
revoke execute on function public.pin_attempt(uuid, text, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- set_my_pin(new, current?)  4 to 8 digits. Changing an existing PIN needs the current one (counted for the lockout).
--   returns { ok: true } | { ok: false, hint: pin_wrong | pin_locked }; raises pin_invalid / pin_required.
-- clear_user_pin(user)       superadmin only (forgotten PIN); the user then sets a new one without the old.
-- ---------------------------------------------------------------------------

create or replace function public.set_my_pin(p_new_pin text, p_current_pin text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_has  boolean;
  v_try  text;
begin
  perform public.assert_active_user();
  if p_new_pin is null or p_new_pin !~ '^[0-9]{4,8}$' then
    raise exception 'PIN must be 4 to 8 digits' using errcode = '22023', hint = 'pin_invalid';
  end if;
  select p.pin_hash is not null into v_has
  from public.profiles p where p.user_id = auth.uid() and p.tenant_id = public.auth_tenant_id() and p.active;
  if not found then
    raise exception 'no active profile' using errcode = '42501', hint = 'not_allowed';
  end if;

  if v_has then
    if p_current_pin is null then
      raise exception 'current PIN is required' using errcode = '22023', hint = 'pin_required';
    end if;
    v_try := public.pin_attempt(auth.uid(), p_current_pin, null);
    if v_try = 'locked' then
      return jsonb_build_object('ok', false, 'hint', 'pin_locked');
    elsif v_try <> 'ok' then
      return jsonb_build_object('ok', false, 'hint', 'pin_wrong');
    end if;
  end if;

  update public.profiles set pin_hash = public.pin_hash_make(p_new_pin)
   where user_id = auth.uid() and tenant_id = public.auth_tenant_id();
  perform public.write_audit('pin.set', 'profile', auth.uid());
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.clear_user_pin(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.assert_superadmin();
  update public.profiles set pin_hash = null where user_id = p_user_id and tenant_id = public.auth_tenant_id();
  if not found then
    raise exception 'user not found' using errcode = '22023', hint = 'user_not_found';
  end if;
  perform public.write_audit('pin.clear', 'profile', p_user_id);
  return jsonb_build_object('ok', true);
end;
$$;

revoke execute on function public.set_my_pin(text, text) from public, anon;
revoke execute on function public.clear_user_pin(uuid) from public, anon;
grant execute on function public.set_my_pin(text, text) to authenticated;
grant execute on function public.clear_user_pin(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- supervisor_approvals: server-only (no client privilege, like processed_ops). Holds no secret: the id is the proof,
-- and it is useless to anyone but the requester, for one action on one expense at one store, once, before expires_at.
-- ---------------------------------------------------------------------------

create table public.supervisor_approvals (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  location_id   uuid not null,
  action        text not null check (action in ('record_expense', 'void_expense')),
  ref_id        uuid not null,
  requested_by  uuid not null references auth.users (id) on delete cascade,
  approved_by   uuid not null references auth.users (id) on delete cascade,
  issued_at     timestamptz not null default now(),
  expires_at    timestamptz not null,
  used_at       timestamptz,
  used_op_id    uuid,
  constraint supervisor_approvals_tenant_id unique (tenant_id, id),
  constraint supervisor_approvals_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint supervisor_approvals_used_consistent check ((used_at is null) = (used_op_id is null))
);

comment on table public.supervisor_approvals is
  'Single-use supervisor approvals issued by approve_supervisor_action after a PIN check. Server-only. No secrets.';

alter table public.supervisor_approvals enable row level security;
revoke all on public.supervisor_approvals from anon, authenticated;

-- May p_user approve at p_location_id? Owner, or an active admin who is supervisor or manager there.
create or replace function public.is_store_approver(p_user uuid, p_location_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    join public.locations l on l.id = p_location_id and l.tenant_id = p.tenant_id and l.deleted_at is null
    where p.user_id = p_user
      and p.tenant_id = public.auth_tenant_id()
      and p.active
      and p.deleted_at is null
      and (p.role = 'superadmin'
           or (p.role = 'admin' and exists (
                 select 1 from public.location_access la
                 where la.user_id = p_user and la.location_id = p_location_id and la.tenant_id = p.tenant_id
                   and la.deleted_at is null and la.position in ('supervisor', 'manager')))));
$$;

revoke execute on function public.is_store_approver(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- approve_supervisor_action(action, ref_id, pin, location_id?, approver_id?)
--   action = record_expense | void_expense; ref_id = the expense id (the client makes it before asking, for a record).
--   approver_id defaults to the caller (a supervisor confirming with their own PIN); a manager or the owner can approve
--   on the supervisor's phone by passing their user id and typing their PIN.
--   Store: the expense's store for a void when the server already has it, else location_id (or the caller's only store).
--   returns { ok: true, approval_id, approved_by, expires_at }
--        or { ok: false, hint: pin_wrong | pin_locked | pin_not_set }   (returned, not raised, so a wrong PIN stays logged)
--   raises not_allowed, approver_invalid, invalid_value, location_required, location_denied.
-- ---------------------------------------------------------------------------

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
  if p_action is null or p_action not in ('record_expense', 'void_expense') or p_ref_id is null then
    raise exception 'action and reference are required' using errcode = '22023', hint = 'invalid_value';
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{4,8}$' then
    return jsonb_build_object('ok', false, 'hint', 'pin_wrong');
  end if;

  if p_action = 'void_expense' then
    select e.location_id into v_loc from public.expenses e where e.id = p_ref_id and e.tenant_id = v_tenant;
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

-- ---------------------------------------------------------------------------
-- authorize_expense_write: the gate inside the ops. Returns the approver's id when a supervisor approval was used
-- (and marks it used by this op), null for the owner or the store's manager. Raises otherwise.
-- ---------------------------------------------------------------------------

create or replace function public.authorize_expense_write(
  p_location_id uuid, p_action text, p_ref_id uuid, p_approval_id uuid, p_op_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.supervisor_approvals;
begin
  if public.is_superadmin() or (public.auth_role() = 'admin' and public.has_location_access(p_location_id, 'manager')) then
    return null;
  end if;
  if public.auth_role() is distinct from 'admin' or not public.has_location_access(p_location_id, 'supervisor') then
    raise exception 'not allowed to manage expenses here' using errcode = '42501', hint = 'not_allowed';
  end if;
  if p_approval_id is null then
    raise exception 'a supervisor approval is required' using errcode = '42501', hint = 'approval_required';
  end if;

  select * into a from public.supervisor_approvals x
  where x.id = p_approval_id and x.tenant_id = public.auth_tenant_id()
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
end;
$$;

revoke execute on function public.authorize_expense_write(uuid, text, uuid, uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- expenses: who approved (record) and who approved the void. The guard keeps them fixed (only the void sets
-- void_approved_by; both may go to null when that user is removed).
-- ---------------------------------------------------------------------------

alter table public.expenses
  add column approved_by uuid references auth.users (id) on delete set null,
  add column void_approved_by uuid references auth.users (id) on delete set null,
  add constraint expenses_void_approval_consistent check (void_approved_by is null or voided_at is not null);

create or replace function public.guard_expense_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_voiding boolean;
begin
  if tg_op = 'DELETE' then
    raise exception 'expenses is append-only' using errcode = '55000', hint = 'append_only';
  end if;
  if (new.id, new.tenant_id, new.location_id, new.client_op_id, new.amount, new.currency, new.category, new.note,
      new.paid_from, new.spent_at, new.created_at, new.deleted_at)
     is distinct from
     (old.id, old.tenant_id, old.location_id, old.client_op_id, old.amount, old.currency, old.category, old.note,
      old.paid_from, old.spent_at, old.created_at, old.deleted_at)
     or (new.created_by is distinct from old.created_by and new.created_by is not null)
     or (new.approved_by is distinct from old.approved_by and new.approved_by is not null) then
    raise exception 'expenses is append-only; only a void is allowed' using errcode = '55000', hint = 'append_only';
  end if;
  v_voiding := old.voided_at is null and new.voided_at is not null;
  if (new.voided_at is distinct from old.voided_at or new.void_reason is distinct from old.void_reason)
     and not v_voiding then
    raise exception 'an expense can be voided once and never un-voided' using errcode = '55000', hint = 'append_only';
  end if;
  if new.void_approved_by is distinct from old.void_approved_by and new.void_approved_by is not null and not v_voiding then
    raise exception 'the void approval is set only by the void' using errcode = '55000', hint = 'append_only';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- op_record_expense   p = { id, amount, category, paid_from?, note?, spent_at?, currency?, location_id?, approval_id? }
--   approval_id: required only for a store supervisor (see the header). Returns { expense_id, approved_by, applied_at }.
-- ---------------------------------------------------------------------------

create or replace function public.op_record_expense(p_op_id uuid, p jsonb)
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
  v_amt_txt  text;
  v_amt      bigint;
  v_cat      text;
  v_from     text;
  v_base     text;
  v_ccy      text;
  v_spent    timestamptz;
  v_appr     uuid;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  -- spending the store's money: the owner, a store manager, or a store supervisor with an approval; never a cashier
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin') then
    raise exception 'not allowed to record expenses' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'expense must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'record_expense');
  if v_replay is not null then
    return v_replay;
  end if;

  v_loc := public.resolve_store((p ->> 'location_id')::uuid);

  v_id := (p ->> 'id')::uuid;
  if v_id is null then
    raise exception 'expense id is required' using errcode = '22023', hint = 'id_required';
  end if;

  -- whole centavos only: a JSON number or digit string, no fraction, no sign, no exponent
  v_amt_txt := p ->> 'amount';
  if not coalesce(jsonb_typeof(p -> 'amount') in ('number', 'string') and v_amt_txt ~ '^[0-9]{1,15}$', false) then
    raise exception 'amount must be whole centavos above zero' using errcode = '22023', hint = 'amount_invalid';
  end if;
  v_amt := v_amt_txt::bigint;
  if v_amt <= 0 then
    raise exception 'amount must be above zero' using errcode = '22023', hint = 'amount_invalid';
  end if;

  v_cat := p ->> 'category';
  if v_cat is null or v_cat not in ('stock_purchase', 'utilities', 'transport', 'wages', 'rent', 'other') then
    raise exception 'category is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_from := coalesce(p ->> 'paid_from', 'cash');
  if v_from not in ('cash', 'ewallet') then
    raise exception 'paid from is invalid' using errcode = '22023', hint = 'invalid_value';
  end if;

  select t.base_currency into v_base from public.tenants t where t.id = v_tenant;
  v_ccy := coalesce(upper(nullif(btrim(p ->> 'currency'), '')), v_base);
  if v_ccy is distinct from v_base then
    raise exception 'expenses are in the base currency' using errcode = '22023', hint = 'invalid_value';
  end if;
  v_spent := coalesce((p ->> 'spent_at')::timestamptz, now());

  v_appr := public.authorize_expense_write(v_loc, 'record_expense', v_id, (p ->> 'approval_id')::uuid, p_op_id);

  begin
    insert into public.expenses (id, tenant_id, location_id, client_op_id, amount, currency, category, note,
                                 paid_from, spent_at, created_by, approved_by)
    values (v_id, v_tenant, v_loc, p_op_id, v_amt, v_ccy, v_cat, left(nullif(btrim(p ->> 'note'), ''), 200),
            v_from, v_spent, auth.uid(), v_appr);
  exception when unique_violation then
    raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  perform public.write_audit('expense.record', 'expense', v_id, v_loc, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_loc, 'amount', v_amt, 'category', v_cat, 'paid_from', v_from,
    'op_id', p_op_id, 'approved_by', v_appr)));
  return public.finish_op(p_op_id, jsonb_build_object('expense_id', v_id, 'approved_by', v_appr, 'applied_at', now()));
end;
$$;

-- ---------------------------------------------------------------------------
-- op_void_expense   p = { expense_id, reason?, approval_id? }
--   Returns { expense_id, already, approved_by, applied_at }. A void of an already voided expense changes and logs nothing.
-- ---------------------------------------------------------------------------

create or replace function public.op_void_expense(p_op_id uuid, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_eid    uuid;
  v_exp    public.expenses;
  v_appr   uuid;
  v_reason text;
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if public.auth_role() is null or public.auth_role() not in ('superadmin', 'admin') then
    raise exception 'not allowed to void expenses' using errcode = '42501', hint = 'not_allowed';
  end if;
  v_tenant := public.auth_tenant_id();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'void must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'void_expense');
  if v_replay is not null then
    return v_replay;
  end if;

  v_eid := (p ->> 'expense_id')::uuid;
  select * into v_exp from public.expenses where id = v_eid and tenant_id = v_tenant for update;
  if not found then
    raise exception 'expense not found' using errcode = '22023', hint = 'expense_not_found';
  end if;
  v_appr := public.authorize_expense_write(v_exp.location_id, 'void_expense', v_eid, (p ->> 'approval_id')::uuid, p_op_id);

  if v_exp.voided_at is not null then
    return public.finish_op(p_op_id, jsonb_build_object('expense_id', v_eid, 'already', true, 'approved_by', v_appr,
                                                        'applied_at', now()));
  end if;

  v_reason := left(nullif(btrim(p ->> 'reason'), ''), 200);
  update public.expenses
     set voided_at = now(), void_reason = v_reason, void_approved_by = v_appr
   where id = v_eid and tenant_id = v_tenant;

  perform public.write_audit('expense.void', 'expense', v_eid, v_exp.location_id, jsonb_strip_nulls(jsonb_build_object(
    'location_id', v_exp.location_id, 'amount', v_exp.amount, 'category', v_exp.category, 'paid_from', v_exp.paid_from,
    'reason', v_reason, 'op_id', p_op_id, 'approved_by', v_appr)));
  return public.finish_op(p_op_id, jsonb_build_object('expense_id', v_eid, 'already', false, 'approved_by', v_appr,
                                                      'applied_at', now()));
end;
$$;

revoke execute on function public.op_record_expense(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_void_expense(uuid, jsonb) from public, anon, authenticated;

-- the manager-only check from P8-02 is replaced by authorize_expense_write
drop function public.assert_expense_writer(uuid);

-- ---------------------------------------------------------------------------
-- sync_pull_expenses re-created (from 20261108001100) with approved_by and void_approved_by
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_expenses(p_cursor jsonb default null, p_limit int default 100)
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
    select x.id, x.location_id, x.amount, x.currency, x.category, x.note, x.paid_from, x.spent_at, x.created_by,
           x.approved_by, x.voided_at, x.void_reason, x.void_approved_by, x.updated_at
    from public.expenses x
    where x.tenant_id = v_tenant
      and x.updated_at <= v_upto
      and (v_ts is null and x.spent_at >= now() - interval '30 days'
           or v_ts is not null and (x.updated_at, x.id::text) > (v_ts, v_k))
    order by x.updated_at, x.id
    limit p_limit + 1
  ), page as (
    select * from s order by updated_at, id limit p_limit
  )
  select
    (select count(*) from s) > p_limit,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'location_id', g.location_id, 'amount', g.amount, 'currency', g.currency,
        'category', g.category, 'note', g.note, 'paid_from', g.paid_from, 'spent_at', g.spent_at,
        'created_by', g.created_by, 'approved_by', g.approved_by, 'voided_at', g.voided_at,
        'void_reason', g.void_reason, 'void_approved_by', g.void_approved_by, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$$;

revoke execute on function public.sync_pull_expenses(jsonb, int) from public, anon;
grant execute on function public.sync_pull_expenses(jsonb, int) to authenticated;
