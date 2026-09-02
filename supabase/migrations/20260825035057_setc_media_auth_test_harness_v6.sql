create table if not exists media_access.test_principals (
  principal_code text primary key,
  user_id uuid not null unique,
  description text,
  created_at timestamptz not null default now()
);
revoke all on media_access.test_principals from public, anon, authenticated;
comment on table media_access.test_principals is 'Non-production synthetic principals reserved for database authorization tests. Rows do not create Supabase Auth users and confer no authority unless an explicit test-only role assignment exists.';

insert into media_access.test_principals(principal_code,user_id,description) values
 ('TEST_CONTRIBUTOR','10000000-0000-4000-8000-000000000001','Synthetic contributor principal'),
 ('TEST_APPROVER','10000000-0000-4000-8000-000000000002','Synthetic approver principal'),
 ('TEST_PUBLISHER','10000000-0000-4000-8000-000000000003','Synthetic publisher principal'),
 ('TEST_OUTSIDER','10000000-0000-4000-8000-000000000004','Synthetic unassigned principal')
on conflict (principal_code) do update set description=excluded.description;

create or replace function media_access.assert_test_principal(p_principal_code text)
returns uuid language plpgsql security invoker set search_path=media_access,pg_temp as $$
declare v_user uuid;
begin
 select user_id into v_user from media_access.test_principals where principal_code=p_principal_code;
 if v_user is null then raise exception 'MEDIA_TEST_PRINCIPAL_NOT_FOUND'; end if;
 return v_user;
end $$;
revoke all on function media_access.assert_test_principal(text) from public, anon, authenticated;

create or replace function media_access.test_set_principal(p_principal_code text)
returns uuid language plpgsql security invoker set search_path=media_access,pg_temp as $$
declare v_user uuid;
begin
 v_user := media_access.assert_test_principal(p_principal_code);
 perform set_config('request.jwt.claim.sub',v_user::text,true);
 perform set_config('request.jwt.claim.role','authenticated',true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user,'role','authenticated','aud','authenticated')::text,true);
 return v_user;
end $$;
revoke all on function media_access.test_set_principal(text) from public, anon, authenticated;

create or replace function media_access.test_clear_principal()
returns void language plpgsql security invoker set search_path=media_access,pg_temp as $$
begin
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claim.role','',true);
 perform set_config('request.jwt.claims','{}',true);
end $$;
revoke all on function media_access.test_clear_principal() from public, anon, authenticated;

comment on function media_access.test_set_principal(text) is 'Database-test helper only. Simulates JWT session claims inside the current transaction; it does not create or authenticate a production user.';
