-- Migration: 20261108002800_catalog_categories.sql
-- Description: Category management RPCs (upsert_category, archive_category) with RBAC and audit logging.

create or replace function public.upsert_category(p_op_id uuid, p_category jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant   uuid;
  v_mode     text;
  v_replay   jsonb;
  p          jsonb := p_category;
  v_cid      uuid;
  v_parent   uuid;
  v_name     text;
  v_cat      public.categories;
  v_created  boolean;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  v_mode := public.catalog_write_mode();
  if v_mode is distinct from 'full' then
    raise exception 'not allowed to change categories' using errcode = '42501', hint = 'not_allowed';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'category must be an object' using errcode = '22023', hint = 'invalid_value';
  end if;

  v_replay := public.claim_op(p_op_id, 'upsert_category');
  if v_replay is not null then
    return v_replay;
  end if;

  v_name := nullif(btrim(p ->> 'name'), '');
  if v_name is null or length(v_name) > 80 then
    raise exception 'category name must be between 1 and 80 characters' using errcode = '22023', hint = 'name_invalid';
  end if;

  if p ? 'parent_id' and (p ->> 'parent_id') is not null then
    v_parent := (p ->> 'parent_id')::uuid;
  else
    v_parent := null;
  end if;

  if p ? 'id' and (p ->> 'id') is not null then
    v_cid := (p ->> 'id')::uuid;
    select * into v_cat from public.categories where id = v_cid and tenant_id = v_tenant for update;
    v_created := not found;
  else
    v_cid := public.uuid_generate_v7();
    v_created := true;
  end if;

  if v_parent is not null then
    if v_parent = v_cid then
      raise exception 'category cannot be its own parent' using errcode = '22023', hint = 'parent_self';
    end if;
    if not exists (select 1 from public.categories where id = v_parent and tenant_id = v_tenant and deleted_at is null) then
      raise exception 'parent category not found' using errcode = '22023', hint = 'parent_not_found';
    end if;
  end if;

  if v_created then
    insert into public.categories (id, tenant_id, parent_id, name, created_at, updated_at, deleted_at)
    values (v_cid, v_tenant, v_parent, v_name, now(), now(), null);
    perform public.write_audit('category.create', 'category', v_cid, null,
      jsonb_build_object('name', v_name, 'parent_id', v_parent, 'op_id', p_op_id));
  else
    update public.categories
    set name = v_name,
        parent_id = v_parent,
        updated_at = now(),
        deleted_at = null
    where id = v_cid and tenant_id = v_tenant;
    perform public.write_audit('category.update', 'category', v_cid, null,
      jsonb_build_object('name', v_name, 'parent_id', v_parent, 'op_id', p_op_id));
  end if;

  return public.finish_op(p_op_id, jsonb_build_object(
    'id', v_cid,
    'name', v_name,
    'parent_id', v_parent,
    'created', v_created
  ));
end;
$$;

create or replace function public.archive_category(p_op_id uuid, p_category_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_replay jsonb;
  v_cat    public.categories;
begin
  perform public.assert_active_user();
  perform public.assert_module('inventory');
  v_tenant := public.auth_tenant_id();
  if public.catalog_write_mode() is distinct from 'full' then
    raise exception 'not allowed to archive categories' using errcode = '42501', hint = 'not_allowed';
  end if;

  v_replay := public.claim_op(p_op_id, 'archive_category');
  if v_replay is not null then
    return v_replay;
  end if;

  select * into v_cat from public.categories where id = p_category_id and tenant_id = v_tenant for update;
  if not found then
    raise exception 'category not found' using errcode = '22023', hint = 'not_found';
  end if;

  if v_cat.deleted_at is null then
    update public.categories set deleted_at = now(), updated_at = now() where id = p_category_id and tenant_id = v_tenant;
    -- Detach active products referencing this archived category
    update public.products
    set category_id = null, updated_at = now()
    where tenant_id = v_tenant and category_id = p_category_id and deleted_at is null;

    perform public.write_audit('category.archive', 'category', p_category_id, null,
      jsonb_build_object('op_id', p_op_id));
  end if;

  return public.finish_op(p_op_id, jsonb_build_object('category_id', p_category_id, 'archived', true));
end;
$$;

revoke all on function public.upsert_category(uuid, jsonb) from public, anon;
grant execute on function public.upsert_category(uuid, jsonb) to authenticated;

revoke all on function public.archive_category(uuid, uuid) from public, anon;
grant execute on function public.archive_category(uuid, uuid) to authenticated;
