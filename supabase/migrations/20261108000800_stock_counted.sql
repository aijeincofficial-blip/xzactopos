-- P4-02 "Counted" flag on stock levels.
-- A product is "counted" once someone has told the system how many there are (opening stock, stock in, a count).
-- Sales alone push a level negative without that, so the app can say "not counted" instead of "none left".

alter table public.stock_levels add column counted boolean not null default false;

update public.stock_levels l set counted = true
where exists (select 1 from public.stock_movements m
              where m.location_id = l.location_id and m.variant_id = l.variant_id
                and m.type in ('opening', 'receipt', 'count_correction', 'damage'));

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
  v_counted  boolean := new.type in ('opening', 'receipt', 'count_correction', 'damage');
begin
  select l.qty_on_hand, l.avg_cost into v_old_qty, v_old_cost
  from public.stock_levels l
  where l.location_id = new.location_id and l.variant_id = new.variant_id
  for update;

  v_cost := v_old_cost;
  if new.type = 'receipt' and new.unit_cost is not null then
    if coalesce(v_old_qty, 0) <= 0 or v_old_cost is null then
      v_cost := new.unit_cost;
    else
      v_cost := round((v_old_qty * v_old_cost + new.qty_delta * new.unit_cost) / (v_old_qty + new.qty_delta))::bigint;
    end if;
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

-- sync_pull_pos returns the flag too
create or replace function public.sync_pull_pos(p_cursors jsonb default '{}'::jsonb, p_limit int default 500)
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
    ('stock_levels',    'location_id, variant_id, qty_on_hand, avg_cost, counted, updated_at',
                        'updated_at', 'location_id::text || ''|'' || variant_id::text'),
    ('customers',       'id, name, phone, updated_at, deleted_at',
                        'updated_at', 'id::text'),
    ('customer_ledger', 'id, customer_id, kind, amount, sale_id, note, occurred_at, created_at',
                        'created_at', 'id::text')
  ) t(tbl, cols, tscol, keyexpr) loop
    v_cur := p_cursors -> r.tbl;

    execute format($q$
      with s as (
        select %2$s, %3$s as _k
        from public.%1$I
        where tenant_id = $1
          and %4$I <= $2
          and ($3::timestamptz is null or (%4$I, %3$s) > ($3::timestamptz, $4::text))
        order by %4$I, _k
        limit $5 + 1
      ), page as (
        select * from s order by %4$I, _k limit $5
      )
      select
        (select count(*) from s) > $5,
        coalesce((select jsonb_agg(to_jsonb(page) - '_k' order by page.%4$I, page._k) from page), '[]'::jsonb),
        (select jsonb_build_object('ts', page.%4$I, 'k', page._k) from page order by page.%4$I desc, page._k desc limit 1)
    $q$, r.tbl, r.cols, r.keyexpr, r.tscol)
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

revoke execute on function public.sync_pull_pos(jsonb, int) from public, anon;
grant execute on function public.sync_pull_pos(jsonb, int) to authenticated;
