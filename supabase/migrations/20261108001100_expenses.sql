-- P8-02 Expenses: money the store spends (supplier payments, electricity, fare, wages, rent ...).
--   expenses               append-only ledger entry; the only change ever allowed is a void (voided_at + void_reason)
--   daily_expense_summary  per store, day (tenant timezone) and category: amount, count, cash / ewallet; voided entries excluded
--   op_record_expense      through sync_push, idempotent by op id
--   op_void_expense        through sync_push; a reversing state, never an edit or a delete
--   sync_pull_expenses     keyset delta pull (same shape as sync_pull_sales)
--   report_summary         re-created with an `expenses` block read from the rollup
-- Who may record or void: the owner (superadmin) or an admin who is manager of that store (catalog_write_mode() = 'full'
-- plus manager access to the expense's store). Cashiers and warehouse staff cannot. Reads: superadmin and admins of the store.

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table public.expenses (
  id            uuid primary key,
  tenant_id     uuid not null references public.tenants (id) on delete cascade,
  location_id   uuid not null,
  client_op_id  uuid not null,
  -- base-currency minor units (centavos), always positive; a void reverses it, nothing is ever negative
  amount        bigint not null check (amount > 0),
  currency      char(3) not null references public.currencies (code),
  category      text not null check (category in ('stock_purchase', 'utilities', 'transport', 'wages', 'rent', 'other')),
  note          text check (length(note) <= 200),
  paid_from     text not null check (paid_from in ('cash', 'ewallet')),
  spent_at      timestamptz not null,
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  voided_at     timestamptz,
  void_reason   text check (length(void_reason) <= 200),
  constraint expenses_tenant_id unique (tenant_id, id),
  constraint expenses_client_op_per_tenant unique (tenant_id, client_op_id),
  constraint expenses_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id),
  constraint expenses_void_consistent check (void_reason is null or voided_at is not null)
);

comment on table public.expenses is
  'Append-only. Written only by op_record_expense; the only allowed change is a void (op_void_expense).';

create index expenses_tenant_spent_idx   on public.expenses (tenant_id, spent_at desc, id);
create index expenses_tenant_updated_idx on public.expenses (tenant_id, updated_at, id);

create trigger expenses_set_updated_at before update on public.expenses
  for each row execute function public.set_updated_at();

-- Rows never change except: void once (voided_at null -> set, void_reason with it), and created_by -> null when a user is removed.
create or replace function public.guard_expense_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'expenses is append-only' using errcode = '55000', hint = 'append_only';
  end if;
  if (new.id, new.tenant_id, new.location_id, new.client_op_id, new.amount, new.currency, new.category, new.note,
      new.paid_from, new.spent_at, new.created_at, new.deleted_at)
     is distinct from
     (old.id, old.tenant_id, old.location_id, old.client_op_id, old.amount, old.currency, old.category, old.note,
      old.paid_from, old.spent_at, old.created_at, old.deleted_at)
     or (new.created_by is distinct from old.created_by and new.created_by is not null) then
    raise exception 'expenses is append-only; only a void is allowed' using errcode = '55000', hint = 'append_only';
  end if;
  if (new.voided_at is distinct from old.voided_at or new.void_reason is distinct from old.void_reason)
     and (old.voided_at is not null or new.voided_at is null) then
    raise exception 'an expense can be voided once and never un-voided' using errcode = '55000', hint = 'append_only';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_expense_change() from public, anon, authenticated;

create trigger expenses_guard before update or delete on public.expenses
  for each row execute function public.guard_expense_change();

-- ---------------------------------------------------------------------------
-- Rollup: per store, day and category. Kept by plain AFTER triggers (one row, nothing to wait for);
-- they run inside the op's subtransaction, so a rejected op leaves nothing behind.
-- ---------------------------------------------------------------------------

create table public.daily_expense_summary (
  tenant_id    uuid not null references public.tenants (id) on delete cascade,
  location_id  uuid not null,
  day          date not null,
  category     text not null,
  amount       bigint not null default 0,
  entry_count  int not null default 0,
  cash         bigint not null default 0,
  ewallet      bigint not null default 0,
  updated_at   timestamptz not null default now(),
  primary key (location_id, day, category),
  constraint daily_expense_summary_location_fk foreign key (tenant_id, location_id)
    references public.locations (tenant_id, id)
);

create index daily_expense_summary_tenant_day_idx on public.daily_expense_summary (tenant_id, day);

-- Adds (p_sign = 1) or removes (p_sign = -1) one expense.
create or replace function public.rollup_expense(e public.expenses, p_sign int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz  text;
  v_day date;
begin
  select coalesce(t.timezone, 'UTC') into v_tz from public.tenants t where t.id = e.tenant_id;
  v_day := (e.spent_at at time zone coalesce(v_tz, 'UTC'))::date;

  insert into public.daily_expense_summary as d
    (tenant_id, location_id, day, category, amount, entry_count, cash, ewallet, updated_at)
  values (e.tenant_id, e.location_id, v_day, e.category,
          p_sign * e.amount, p_sign,
          case when e.paid_from = 'cash' then p_sign * e.amount else 0 end,
          case when e.paid_from = 'ewallet' then p_sign * e.amount else 0 end,
          now())
  on conflict (location_id, day, category) do update set
    amount = d.amount + excluded.amount, entry_count = d.entry_count + excluded.entry_count,
    cash = d.cash + excluded.cash, ewallet = d.ewallet + excluded.ewallet, updated_at = now();
end;
$$;

create or replace function public.trg_rollup_expense()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.voided_at is null then
      perform public.rollup_expense(new, 1);
    end if;
  elsif old.voided_at is null and new.voided_at is not null then
    perform public.rollup_expense(old, -1);
  end if;
  return null;
end;
$$;

revoke execute on function public.rollup_expense(public.expenses, int) from public, anon, authenticated;
revoke execute on function public.trg_rollup_expense() from public, anon, authenticated;

create trigger expenses_rollup_insert after insert on public.expenses
  for each row execute function public.trg_rollup_expense();
create trigger expenses_rollup_void after update of voided_at on public.expenses
  for each row execute function public.trg_rollup_expense();

-- ---------------------------------------------------------------------------
-- RLS: superadmin and admins read their stores' expenses and rollups; nobody writes from a client
-- ---------------------------------------------------------------------------

alter table public.expenses enable row level security;
alter table public.daily_expense_summary enable row level security;

create policy expenses_read on public.expenses
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'admin')
         and location_id = any ((select public.auth_location_ids())::uuid[]));
create policy daily_expense_summary_read on public.daily_expense_summary
  for select to authenticated
  using (tenant_id = (select public.auth_tenant_id())
         and (select public.auth_role()) in ('superadmin', 'admin')
         and location_id = any ((select public.auth_location_ids())::uuid[]));

revoke all on public.expenses, public.daily_expense_summary from anon;
revoke insert, update, delete, truncate on public.expenses, public.daily_expense_summary from authenticated;
grant select on public.expenses, public.daily_expense_summary to authenticated;

-- ---------------------------------------------------------------------------
-- Permission helper: record or void an expense at this store
-- ---------------------------------------------------------------------------

create or replace function public.assert_expense_writer(p_location_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if public.catalog_write_mode() is distinct from 'full'
     or not public.has_location_access(p_location_id, 'manager') then
    raise exception 'not allowed to manage expenses here' using errcode = '42501', hint = 'not_allowed';
  end if;
end;
$$;

revoke execute on function public.assert_expense_writer(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- op_record_expense
--   p = { id, amount (integer centavos > 0), category, paid_from?: cash|ewallet (default cash), note?, spent_at?,
--         currency? (must be the tenant's base currency), location_id? }
--   Returns { expense_id, applied_at }.
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
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  -- spending the store's money is the owner's (or a store manager's) call, not a cashier's
  if public.catalog_write_mode() is distinct from 'full' then
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
  perform public.assert_expense_writer(v_loc);

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

  begin
    insert into public.expenses (id, tenant_id, location_id, client_op_id, amount, currency, category, note,
                                 paid_from, spent_at, created_by)
    values (v_id, v_tenant, v_loc, p_op_id, v_amt, v_ccy, v_cat, left(nullif(btrim(p ->> 'note'), ''), 200),
            v_from, v_spent, auth.uid());
  exception when unique_violation then
    raise exception 'id already in use' using errcode = '22023', hint = 'id_conflict';
  end;

  perform public.write_audit('expense.create', 'expense', v_id, v_loc,
    jsonb_build_object('amount', v_amt, 'category', v_cat, 'paid_from', v_from));
  return public.finish_op(p_op_id, jsonb_build_object('expense_id', v_id, 'applied_at', now()));
end;
$$;

-- ---------------------------------------------------------------------------
-- op_void_expense   p = { expense_id, reason? }
--   Sets voided_at / void_reason once; the rollup takes the amount back out. Voiding twice is a no-op ({ already: true }).
--   Returns { expense_id, already, applied_at }.
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
begin
  perform public.assert_active_user();
  perform public.assert_module('pos');
  if public.catalog_write_mode() is distinct from 'full' then
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
  perform public.assert_expense_writer(v_exp.location_id);

  if v_exp.voided_at is not null then
    return public.finish_op(p_op_id, jsonb_build_object('expense_id', v_eid, 'already', true, 'applied_at', now()));
  end if;

  update public.expenses
     set voided_at = now(), void_reason = left(nullif(btrim(p ->> 'reason'), ''), 200)
   where id = v_eid and tenant_id = v_tenant;

  perform public.write_audit('expense.void', 'expense', v_eid, v_exp.location_id,
    jsonb_build_object('amount', v_exp.amount, 'category', v_exp.category));
  return public.finish_op(p_op_id, jsonb_build_object('expense_id', v_eid, 'already', false, 'applied_at', now()));
end;
$$;

revoke execute on function public.op_record_expense(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.op_void_expense(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- sync_pull_expenses(cursor, limit)   same shape and rules as sync_pull_sales
--   p_cursor = { ts, k } of the last row received, or null for the first pull (then only the last 30 days by spent_at).
--   Returns { rows: [ { id, location_id, amount, currency, category, note, paid_from, spent_at, created_by,
--                       voided_at, void_reason, updated_at } ], cursor, has_more, server_time }.
--   A voided expense comes again (its updated_at moves). Runs as the caller: cashiers get no rows (RLS).
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
           x.voided_at, x.void_reason, x.updated_at
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
        'created_by', g.created_by, 'voided_at', g.voided_at, 'void_reason', g.void_reason, 'updated_at', g.updated_at
      ) order by g.updated_at, g.id) from page g), '[]'::jsonb),
    (select jsonb_build_object('ts', g.updated_at, 'k', g.id::text) from page g order by g.updated_at desc, g.id desc limit 1)
  into v_more, v_rows, v_last;

  return jsonb_build_object('rows', v_rows, 'cursor', coalesce(v_last, p_cursor), 'has_more', v_more, 'server_time', now());
end;
$$;

revoke execute on function public.sync_pull_expenses(jsonb, int) from public, anon;
grant execute on function public.sync_pull_expenses(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- report_summary re-created (from 20261108000900) with an `expenses` block from daily_expense_summary:
--   expenses = { total, cash, ewallet, count, by_category: [ { category, amount, count } ], days: [ { day, amount } ] }
-- Everything else is unchanged.
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

  return jsonb_build_object('from', p_from, 'to', p_to, 'days', v_days, 'totals', v_totals,
                            'top_items', v_top, 'utang', v_utang, 'expenses', v_exp, 'server_time', now());
end;
$$;

revoke execute on function public.report_summary(date, date) from public, anon;
grant execute on function public.report_summary(date, date) to authenticated;

-- ---------------------------------------------------------------------------
-- sync_push re-created (from 20261108001000) with the record_expense and void_expense kinds
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
