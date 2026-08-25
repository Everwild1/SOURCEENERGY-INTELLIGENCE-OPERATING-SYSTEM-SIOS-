begin;

-- Synthetic UUIDs simulate JWT subjects only. They are not production identities.
-- Fail fast with native PostgreSQL exceptions so CI has no external pgTAP package dependency.

do $$
declare v_count bigint; v_uid uuid;
begin
  select count(*) into v_count
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in ('setc_media_content','setc_media_events','setc_media_outbox') and c.relrowsecurity;
  if v_count <> 3 then raise exception 'MEDIA_RLS_ASSERTION_FAILED expected 3 RLS tables, got %', v_count; end if;

  select count(*) into v_count from auth.users;
  if v_count <> 0 then raise exception 'MEDIA_AUTH_ISOLATION_FAILED expected zero production auth users, got %', v_count; end if;

  if media_access.assert_test_principal('TEST_CONTRIBUTOR') <> '10000000-0000-4000-8000-000000000001'::uuid then
    raise exception 'MEDIA_TEST_PRINCIPAL_FAILED contributor UUID mismatch';
  end if;

  perform media_access.test_set_principal('TEST_CONTRIBUTOR');
  v_uid := auth.uid();
  if v_uid <> '10000000-0000-4000-8000-000000000001'::uuid then
    raise exception 'MEDIA_JWT_SIMULATION_FAILED expected contributor UUID, got %', v_uid;
  end if;

  perform media_access.test_set_principal('TEST_OUTSIDER');
  if media_access.has_permission(null,'media.publish') then
    raise exception 'MEDIA_AUTHZ_FAILED outsider unexpectedly has publish permission';
  end if;

  if not exists(select 1 from media_access.permissions where permission_code='media.publish') then
    raise exception 'MEDIA_PERMISSION_FAILED media.publish missing';
  end if;
  if not exists(select 1 from media_access.permissions where permission_code='media.approve') then
    raise exception 'MEDIA_PERMISSION_FAILED media.approve missing';
  end if;
  if not exists(select 1 from media_access.permissions where permission_code='media.fact_validate') then
    raise exception 'MEDIA_PERMISSION_FAILED media.fact_validate missing';
  end if;

  if exists(
    select 1 from media_access.role_permissions rp
    where rp.role_code='MEDIA_CONTRIBUTOR' and rp.permission_code in ('media.approve','media.publish','media.fact_validate')
  ) then raise exception 'MEDIA_SOD_FAILED contributor has elevated approval/publish/fact permission'; end if;

  if exists(
    select 1 from media_access.role_permissions rp
    where rp.role_code='MEDIA_APPROVER' and rp.permission_code='media.publish'
  ) then raise exception 'MEDIA_SOD_FAILED approver can publish'; end if;

  if exists(
    select 1 from media_access.role_permissions rp
    where rp.role_code='MEDIA_PUBLISHER' and rp.permission_code='media.approve'
  ) then raise exception 'MEDIA_SOD_FAILED publisher can approve'; end if;
end $$;

rollback;
