begin;

do $$
declare v_count bigint; v_uid uuid; v_content uuid; v_event uuid; v_outbox1 uuid; v_outbox2 uuid;
begin
  select count(*) into v_count from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in ('setc_media_content','setc_media_events','setc_media_outbox') and c.relrowsecurity;
  if v_count <> 3 then raise exception 'MEDIA_RLS_ASSERTION_FAILED'; end if;
  select count(*) into v_count from auth.users; if v_count <> 0 then raise exception 'MEDIA_AUTH_ISOLATION_FAILED'; end if;

  if media_access.assert_test_principal('TEST_CONTRIBUTOR') <> '10000000-0000-4000-8000-000000000001'::uuid then raise exception 'MEDIA_TEST_PRINCIPAL_FAILED'; end if;
  perform media_access.test_set_principal('TEST_CONTRIBUTOR'); v_uid:=auth.uid();
  if v_uid <> '10000000-0000-4000-8000-000000000001'::uuid then raise exception 'MEDIA_JWT_SIMULATION_FAILED'; end if;
  perform media_access.test_set_principal('TEST_OUTSIDER'); if media_access.has_permission('ORG-A','media.publish') then raise exception 'MEDIA_AUTHZ_FAILED'; end if;

  if exists(select 1 from media_access.role_permissions where role_code='MEDIA_CONTRIBUTOR' and permission_code in ('media.approve','media.publish','media.fact_validate')) then raise exception 'MEDIA_SOD_CONTRIBUTOR_FAILED'; end if;
  if exists(select 1 from media_access.role_permissions where role_code='MEDIA_APPROVER' and permission_code='media.publish') then raise exception 'MEDIA_SOD_APPROVER_FAILED'; end if;
  if exists(select 1 from media_access.role_permissions where role_code='MEDIA_PUBLISHER' and permission_code='media.approve') then raise exception 'MEDIA_SOD_PUBLISHER_FAILED'; end if;

  insert into media_access.user_role_assignments(user_id,organization_oid,role_code) values
   ('10000000-0000-4000-8000-000000000003','ORG-A','MEDIA_PUBLISHER');
  perform media_access.test_set_principal('TEST_PUBLISHER');
  if not media_access.has_permission('ORG-A','media.publish') then raise exception 'MEDIA_PUBLISH_PERMISSION_FAILED'; end if;
  if media_access.has_permission('ORG-B','media.publish') then raise exception 'MEDIA_CROSS_ORG_FAILED'; end if;

  insert into public.setc_media_content(organization_oid,title,lifecycle_status,current_version) values('ORG-A','Integration Test','APPROVED',1) returning content_id into v_content;
  if public.setc_media_publication_ready(v_content) then raise exception 'MEDIA_READINESS_FAILED no approval should block'; end if;
  insert into public.setc_media_approvals(content_id,decision,approved_version) values(v_content,'APPROVED',1);
  if not public.setc_media_publication_ready(v_content) then raise exception 'MEDIA_READINESS_FAILED approved clean content should pass'; end if;
  insert into public.setc_media_claims(content_id,claim_text,materiality,verification_state,authoritative_source_required) values(v_content,'Material test claim','HIGH','PENDING',true);
  if public.setc_media_publication_ready(v_content) then raise exception 'MEDIA_READINESS_FAILED unverified material claim should block'; end if;
  update public.setc_media_claims set verification_state='VERIFIED' where content_id=v_content;
  if not public.setc_media_publication_ready(v_content) then raise exception 'MEDIA_READINESS_FAILED verified material claim should pass'; end if;

  insert into public.setc_media_events(organization_oid,content_id,event_type) values('ORG-A',v_content,'media.content.published') returning event_id into v_event;
  insert into public.setc_media_outbox(event_id,destination_type,destination_key,idempotency_key) values(v_event,'WEB','media.sourceenergy','idem-1') returning outbox_id into v_outbox1;
  insert into public.setc_media_outbox(event_id,destination_type,destination_key,idempotency_key) values(v_event,'WEB','media.sourceenergy','idem-1') on conflict(destination_type,destination_key,idempotency_key) do update set destination_key=excluded.destination_key returning outbox_id into v_outbox2;
  if v_outbox1 <> v_outbox2 then raise exception 'MEDIA_OUTBOX_IDEMPOTENCY_FAILED'; end if;
  select count(*) into v_count from public.setc_media_outbox where destination_type='WEB' and destination_key='media.sourceenergy' and idempotency_key='idem-1';
  if v_count <> 1 then raise exception 'MEDIA_OUTBOX_DUPLICATE_FAILED'; end if;
end $$;

rollback;
