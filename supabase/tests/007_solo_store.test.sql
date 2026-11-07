-- S-01 provision_solo_store
begin;
select plan(13);

create function pg_temp.u(p text) returns uuid language sql immutable as $$ select md5('u:' || p)::uuid $$;

insert into auth.users (id, email)
select pg_temp.u(n), n || '@test.invalid' from unnest(array['tindera', 'tindera2', 'weird']) n;
update auth.users set email = '!!@test.invalid' where id = pg_temp.u('weird');

-- signed in as a user with no business
select set_config('request.jwt.claims',
  jsonb_build_object('sub', pg_temp.u('tindera'), 'role', 'authenticated')::text, true);
set local role authenticated;

select is(
  public.provision_solo_store(md5('t:solo1')::uuid, md5('l:solo1')::uuid, '  Aling Nena Store  '),
  md5('t:solo1')::uuid, 'creates the tenant and returns its id');

-- RLS reads need the tenant_id claim, which a real session only gets after refreshing its token (S-02 must do this)
select set_config('request.jwt.claims',
  jsonb_build_object('sub', pg_temp.u('tindera'), 'role', 'authenticated', 'tenant_id', md5('t:solo1')::uuid)::text, true);

select is(
  (select row(t.name, t.base_currency, t.timezone, t.setup_completed_at is not null)::text
     from public.tenants t where t.id = md5('t:solo1')::uuid),
  row('Aling Nena Store', 'PHP', 'Asia/Manila', true)::text,
  'store name trimmed, PHP, Manila, setup already complete');

select is(
  (select row(m.inventory, m.pos, m.warehouse)::text from public.tenant_modules m where m.tenant_id = md5('t:solo1')::uuid),
  row(true, true, false)::text, 'inventory and POS on, warehouse off');

select is(
  (select row(s.default_locale, p.role, p.username, p.locale)::text
     from public.tenant_settings s
     join public.profiles p on p.tenant_id = s.tenant_id and p.user_id = pg_temp.u('tindera')
    where s.tenant_id = md5('t:solo1')::uuid),
  row('fil', 'superadmin', 'tindera', 'fil')::text, 'owner is superadmin, Filipino default, username from email');

select is(
  (select count(*)::int from public.locations where tenant_id = md5('t:solo1')::uuid and type = 'store' and code = 'MAIN'),
  1, 'exactly one store');

select is(
  (select count(*)::int from public.audit_log where tenant_id = md5('t:solo1')::uuid and action = 'tenant.provision_solo'),
  1, 'audit entry written');

select throws_ok(
  $$ select public.provision_solo_store(md5('t:solo2')::uuid, md5('l:solo2')::uuid, 'Second') $$,
  'P0001', null, 'second call by the same user is refused');

select throws_ok(
  $$ select public.provision_solo_store(md5('t:solo3')::uuid, md5('l:solo3')::uuid, '   ') $$,
  '22023', null, 'blank name refused (user already has one, but validation runs first)');

-- another user: validation and isolation
select set_config('request.jwt.claims',
  jsonb_build_object('sub', pg_temp.u('tindera2'), 'role', 'authenticated')::text, true);

select throws_ok(
  $$ select public.provision_solo_store(md5('t:solo4')::uuid, md5('l:solo4')::uuid, 'X', 'de') $$,
  '22023', null, 'unsupported locale refused');

select lives_ok(
  $$ select public.provision_solo_store(md5('t:solo5')::uuid, md5('l:solo5')::uuid, 'Tindahan ni Ana', 'en') $$,
  'a second, different user gets a separate business');

select set_config('request.jwt.claims',
  jsonb_build_object('sub', pg_temp.u('tindera2'), 'role', 'authenticated', 'tenant_id', md5('t:solo5')::uuid)::text, true);
select is(
  (select count(*)::int from public.tenants where id in (md5('t:solo1')::uuid, md5('t:solo5')::uuid)),
  1, 'RLS: the second tindera cannot see the first tenant');

select set_config('request.jwt.claims',
  jsonb_build_object('sub', pg_temp.u('weird'), 'role', 'authenticated')::text, true);
select lives_ok(
  $$ select public.provision_solo_store(md5('t:solo6')::uuid, md5('l:solo6')::uuid, 'Odd email') $$,
  'unusable email prefix falls back to username owner');

reset role;
set local role anon;
select throws_ok(
  $$ select public.provision_solo_store(md5('t:solo7')::uuid, md5('l:solo7')::uuid, 'Anon') $$,
  '42501', null, 'anon cannot call it');
reset role;

select * from finish();
rollback;
