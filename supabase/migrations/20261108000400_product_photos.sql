-- P2-06 Product photos in Supabase Storage (never in the database; products.photo_path holds the object path).
-- Bucket: private, JPEG only, 200 KB cap (devices send ~640 px JPEGs under 100 KB).
-- Object path: <tenant_id>/<product_id>/<client_op_id>.jpg  -- a new path per change, so devices never show a stale cached photo.
-- Read: any active member of the tenant. Upload: catalog writers with full rights (superadmin, store managers). Delete: nobody.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-photos', 'product-photos', false, 204800, array['image/jpeg'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Policy helper: catalog_write_mode() is not callable by clients, so expose only the yes/no answer.
create or replace function public.can_upload_product_photo()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if public.auth_tenant_id() is null then
    return false;
  end if;
  if not exists (select 1 from public.tenants t where t.id = public.auth_tenant_id() and t.status = 'active') then
    return false;
  end if;
  if not exists (select 1 from public.tenant_modules m where m.tenant_id = public.auth_tenant_id() and m.inventory) then
    return false;
  end if;
  return public.catalog_write_mode() = 'full';
end;
$$;

revoke execute on function public.can_upload_product_photo() from public, anon;
grant execute on function public.can_upload_product_photo() to authenticated;

-- <uuid>/<uuid>/<uuid>.jpg, first folder = caller's tenant
create or replace function public.is_own_product_photo_path(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
     and split_part(p_name, '/', 1) = public.auth_tenant_id()::text;
$$;

revoke execute on function public.is_own_product_photo_path(text) from public, anon;
grant execute on function public.is_own_product_photo_path(text) to authenticated;

create policy product_photos_member_read on storage.objects
  for select to authenticated
  using (bucket_id = 'product-photos' and (select public.is_own_product_photo_path(name)));

create policy product_photos_writer_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'product-photos'
              and (select public.is_own_product_photo_path(name))
              and (select public.can_upload_product_photo()));

-- upsert (retry of the same upload) needs update too
create policy product_photos_writer_update on storage.objects
  for update to authenticated
  using (bucket_id = 'product-photos'
         and (select public.is_own_product_photo_path(name))
         and (select public.can_upload_product_photo()))
  with check (bucket_id = 'product-photos'
              and (select public.is_own_product_photo_path(name))
              and (select public.can_upload_product_photo()));
