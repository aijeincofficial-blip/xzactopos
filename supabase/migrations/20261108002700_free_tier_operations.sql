-- 20261108002700_free_tier_operations.sql: Card F-11 Free-tier operations, storage metering, keep-alive, and maintenance

-- 1. Health ping for automated keep-alive (prevents Supabase 7-day idle project pausing)
create or replace function public.health_ping()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return jsonb_build_object(
    'ok', true,
    'status', 'healthy',
    'timestamp', now(),
    'database', current_database(),
    'version', '1.0.0'
  );
end;
$$;

revoke all on function public.health_ping() from public, anon;
grant execute on function public.health_ping() to authenticated;

-- 2. Database Storage Metrics & Quotas (500 MB free-tier budget)
create or replace function public.get_storage_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant       uuid;
  v_role         text;
  v_total_bytes  bigint;
  v_limit_bytes  bigint := 524288000; -- 500 MB in bytes
  v_used_mb      numeric;
  v_percent_used numeric;
  v_status       text;
  v_tables       jsonb;
  v_tenant_stats jsonb;
begin
  perform public.assert_active_user();

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role not in ('superadmin', 'admin') and not public.is_platform_admin() then
    raise exception 'only administrators can view storage metrics'
      using errcode = '42501', hint = 'not_allowed';
  end if;

  v_total_bytes := pg_database_size(current_database());
  v_used_mb := round((v_total_bytes::numeric / (1024 * 1024)), 2);
  v_percent_used := round((v_total_bytes::numeric / v_limit_bytes::numeric) * 100, 2);

  if v_percent_used >= 90 then
    v_status := 'critical';
  elsif v_percent_used >= 70 then
    v_status := 'warning';
  else
    v_status := 'healthy';
  end if;

  -- Top 15 largest public tables
  select coalesce(jsonb_agg(t), '[]'::jsonb)
  into v_tables
  from (
    select
      c.relname::text as table_name,
      c.reltuples::bigint as estimated_rows,
      pg_total_relation_size(c.oid) as total_bytes,
      pg_size_pretty(pg_total_relation_size(c.oid)) as formatted_size
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
    order by pg_total_relation_size(c.oid) desc
    limit 15
  ) t;

  -- Tenant-specific row counts
  select jsonb_build_object(
    'products', (select count(*) from public.products where tenant_id = v_tenant and deleted_at is null),
    'sales', (select count(*) from public.sales where tenant_id = v_tenant),
    'stock_movements', (select count(*) from public.stock_movements where tenant_id = v_tenant),
    'customers', (select count(*) from public.customers where tenant_id = v_tenant),
    'expenses', (select count(*) from public.expenses where tenant_id = v_tenant),
    'processed_ops', (select count(*) from public.processed_ops where tenant_id = v_tenant),
    'audit_log', (select count(*) from public.audit_log where tenant_id = v_tenant)
  ) into v_tenant_stats;

  return jsonb_build_object(
    'ok', true,
    'total_bytes', v_total_bytes,
    'limit_bytes', v_limit_bytes,
    'used_mb', v_used_mb,
    'limit_mb', 500,
    'percent_used', v_percent_used,
    'status', v_status,
    'tables', v_tables,
    'tenant_stats', v_tenant_stats
  );
end;
$$;

revoke all on function public.get_storage_metrics() from public, anon;
grant execute on function public.get_storage_metrics() to authenticated;

-- 3. Maintenance: Archive Stale Processed Ops & Expired Approvals
create or replace function public.archive_processed_ops(p_days_to_keep integer default 30)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant           uuid;
  v_role             text;
  v_ops_count        integer := 0;
  v_approvals_count  integer := 0;
  v_cutoff           timestamptz;
begin
  perform public.assert_active_user();

  v_tenant := public.auth_tenant_id();
  v_role := public.auth_role();

  if v_role not in ('superadmin', 'admin') and not public.is_platform_admin() then
    raise exception 'only administrators can run maintenance tasks'
      using errcode = '42501', hint = 'not_allowed';
  end if;

  if p_days_to_keep < 7 then
    raise exception 'retention period must be at least 7 days'
      using errcode = '22023', hint = 'min_retention_days';
  end if;

  v_cutoff := now() - (p_days_to_keep || ' days')::interval;

  -- Delete stale processed ops
  with del as (
    delete from public.processed_ops
    where tenant_id = v_tenant
      and processed_at < v_cutoff
    returning 1
  )
  select count(*) into v_ops_count from del;

  -- Delete expired or used supervisor approvals older than retention cutoff
  with del_app as (
    delete from public.supervisor_approvals
    where tenant_id = v_tenant
      and (used_at is not null or expires_at < now())
      and issued_at < v_cutoff
    returning 1
  )
  select count(*) into v_approvals_count from del_app;

  perform public.write_audit(
    'maintenance.archive',
    'system',
    null,
    null,
    jsonb_build_object(
      'days_retained', p_days_to_keep,
      'ops_deleted', v_ops_count,
      'approvals_deleted', v_approvals_count
    )
  );

  return jsonb_build_object(
    'ok', true,
    'ops_deleted', v_ops_count,
    'approvals_deleted', v_approvals_count,
    'days_retained', p_days_to_keep
  );
end;
$$;

revoke all on function public.archive_processed_ops(integer) from public, anon;
grant execute on function public.archive_processed_ops(integer) to authenticated;
