-- Correct argument ordering for Media permission checks and remove exposed SECURITY DEFINER queue functions.
-- media_access.has_permission signature is (permission, organization_oid).

create or replace function public.setc_media_editorial_queue()
returns table(content_id uuid, organization_oid text, title text, content_type text, representation_class text, lifecycle_status text, current_version integer, updated_at timestamptz)
language sql security invoker set search_path=public,media_access,pg_temp as $$
  select c.content_id,c.organization_oid,c.title,c.content_type,c.representation_class,c.lifecycle_status,c.current_version,c.updated_at
  from public.setc_media_content c
  where media_access.has_permission('media.read',c.organization_oid)
    and c.lifecycle_status not in ('PUBLISHED','ARCHIVED','WITHDRAWN')
  order by c.updated_at desc
$$;

create or replace function public.setc_media_evidence_queue()
returns table(claim_id uuid, content_id uuid, organization_oid text, title text, claim_text text, claim_category text, materiality text, verification_state text, authoritative_source_required boolean, created_at timestamptz)
language sql security invoker set search_path=public,media_access,pg_temp as $$
  select cl.claim_id,cl.content_id,c.organization_oid,c.title,cl.claim_text,cl.claim_category,cl.materiality,cl.verification_state,cl.authoritative_source_required,cl.created_at
  from public.setc_media_claims cl join public.setc_media_content c on c.content_id=cl.content_id
  where media_access.has_permission('media.fact_validate',c.organization_oid)
    and cl.verification_state in ('UNVERIFIED','PENDING','CONFLICT')
  order by case cl.materiality when 'CRITICAL' then 1 when 'HIGH' then 2 when 'STANDARD' then 3 else 4 end, cl.created_at
$$;

create or replace function public.setc_media_approval_queue()
returns table(content_id uuid, organization_oid text, title text, representation_class text, lifecycle_status text, current_version integer, unresolved_claims bigint, pending_reviews bigint, updated_at timestamptz)
language sql security invoker set search_path=public,media_access,pg_temp as $$
  select c.content_id,c.organization_oid,c.title,c.representation_class,c.lifecycle_status,c.current_version,
    (select count(*) from public.setc_media_claims cl where cl.content_id=c.content_id and cl.authoritative_source_required and cl.verification_state<>'VERIFIED') as unresolved_claims,
    (select count(*) from public.setc_media_reviews r where r.content_id=c.content_id and r.decision='PENDING') as pending_reviews,
    c.updated_at
  from public.setc_media_content c
  where media_access.has_permission('media.approve',c.organization_oid)
    and c.lifecycle_status in ('DOMAIN_REVIEW','APPROVAL_PENDING','APPROVED')
  order by c.updated_at desc
$$;

create or replace function public.setc_media_distribution_queue()
returns table(outbox_id uuid,event_id uuid,organization_oid text,content_id uuid,event_type text,destination_type text,destination_key text,delivery_status text,attempt_count integer,available_at timestamptz,created_at timestamptz)
language sql security invoker set search_path=public,media_access,pg_temp as $$
  select o.outbox_id,o.event_id,e.organization_oid,e.content_id,e.event_type,o.destination_type,o.destination_key,o.delivery_status,o.attempt_count,o.available_at,o.created_at
  from public.setc_media_outbox o join public.setc_media_events e on e.event_id=o.event_id
  where media_access.has_permission('media.publish',e.organization_oid)
  order by case o.delivery_status when 'FAILED' then 1 when 'DEAD_LETTER' then 2 when 'PENDING' then 3 else 4 end, o.created_at desc
$$;

revoke all on function public.setc_media_editorial_queue() from public,anon;
revoke all on function public.setc_media_evidence_queue() from public,anon;
revoke all on function public.setc_media_approval_queue() from public,anon;
revoke all on function public.setc_media_distribution_queue() from public,anon;
grant execute on function public.setc_media_editorial_queue() to authenticated;
grant execute on function public.setc_media_evidence_queue() to authenticated;
grant execute on function public.setc_media_approval_queue() to authenticated;
grant execute on function public.setc_media_distribution_queue() to authenticated;

-- Correct event RLS policies that had reversed has_permission arguments.
drop policy if exists media_events_select on public.setc_media_events;
create policy media_events_select on public.setc_media_events for select to authenticated
using (organization_oid is not null and media_access.has_permission('media.read',organization_oid));
drop policy if exists media_events_insert on public.setc_media_events;
create policy media_events_insert on public.setc_media_events for insert to authenticated
with check (actor_user_id=(select auth.uid()) and organization_oid is not null and media_access.has_permission('media.read',organization_oid));

-- Correct command permission checks. These remain SECURITY INVOKER.
create or replace function public.setc_media_transition(p_content_id uuid,p_target_status text,p_reason text default null)
returns uuid language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_org text; v_old text; v_event uuid;
begin
 select organization_oid,lifecycle_status into v_org,v_old from public.setc_media_content where content_id=p_content_id for update;
 if v_org is null then raise exception 'MEDIA_CONTENT_NOT_FOUND'; end if;
 if p_target_status in ('DRAFT','ASSIGNED','FACT_VALIDATION','EDITORIAL_REVIEW','DOMAIN_REVIEW','APPROVAL_PENDING') then
   if not media_access.has_permission('media.draft',v_org) then raise exception 'MEDIA_TRANSITION_FORBIDDEN'; end if;
 elsif p_target_status='APPROVED' then
   if not media_access.has_permission('media.approve',v_org) then raise exception 'MEDIA_APPROVAL_FORBIDDEN'; end if;
 elsif p_target_status in ('CORRECTED','SUPERSEDED','ARCHIVED','WITHDRAWN') then
   if not (media_access.has_permission('media.correct',v_org) or media_access.has_permission('media.withdraw',v_org)) then raise exception 'MEDIA_CORRECTION_FORBIDDEN'; end if;
 elsif p_target_status='PUBLISHED' then raise exception 'USE_MEDIA_PUBLISH_FUNCTION';
 else raise exception 'MEDIA_TARGET_STATUS_INVALID'; end if;
 update public.setc_media_content set lifecycle_status=p_target_status,updated_at=now(),archived_at=case when p_target_status='ARCHIVED' then now() else archived_at end where content_id=p_content_id;
 insert into public.setc_media_events(event_type,aggregate_id,organization_oid,content_id,actor_user_id,payload)
 values('media.content.status_changed',p_content_id,v_org,p_content_id,(select auth.uid()),jsonb_build_object('from',v_old,'to',p_target_status,'reason',p_reason)) returning event_id into v_event;
 return v_event;
end $$;

create or replace function public.setc_media_emit_event(p_event_type text,p_content_id uuid,p_payload jsonb default '{}'::jsonb,p_correlation_id uuid default null,p_causation_id uuid default null)
returns uuid language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_event_id uuid; v_org text;
begin
 select organization_oid into v_org from public.setc_media_content where content_id=p_content_id;
 if v_org is null then raise exception 'MEDIA_CONTENT_NOT_FOUND'; end if;
 if not media_access.has_permission('media.read',v_org) then raise exception 'MEDIA_FORBIDDEN'; end if;
 insert into public.setc_media_events(event_type,aggregate_id,organization_oid,content_id,actor_user_id,correlation_id,causation_id,payload)
 values(p_event_type,p_content_id,v_org,p_content_id,(select auth.uid()),p_correlation_id,p_causation_id,coalesce(p_payload,'{}'::jsonb)) returning event_id into v_event_id;
 return v_event_id;
end $$;

create or replace function public.setc_media_enqueue_outbox(p_event_id uuid,p_destination_type text,p_destination_key text,p_idempotency_key text)
returns uuid language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_id uuid; v_org text;
begin
 select organization_oid into v_org from public.setc_media_events where event_id=p_event_id;
 if v_org is null then raise exception 'MEDIA_EVENT_NOT_FOUND'; end if;
 if not media_access.has_permission('media.publish',v_org) then raise exception 'MEDIA_OUTBOX_FORBIDDEN'; end if;
 insert into public.setc_media_outbox(event_id,destination_type,destination_key,idempotency_key)
 values(p_event_id,p_destination_type,p_destination_key,p_idempotency_key)
 on conflict(destination_type,destination_key,idempotency_key) do update set updated_at=now()
 returning outbox_id into v_id;
 return v_id;
end $$;

create or replace function public.setc_media_publish(p_content_id uuid,p_external_url text default null)
returns uuid language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_org text; v_version integer; v_event uuid;
begin
 select organization_oid,current_version into v_org,v_version from public.setc_media_content where content_id=p_content_id for update;
 if v_org is null then raise exception 'MEDIA_CONTENT_NOT_FOUND'; end if;
 if not media_access.has_permission('media.publish',v_org) then raise exception 'MEDIA_PUBLISH_FORBIDDEN'; end if;
 if not public.setc_media_publication_ready(p_content_id) then raise exception 'MEDIA_NOT_PUBLICATION_READY'; end if;
 update public.setc_media_content set lifecycle_status='PUBLISHED',published_at=coalesce(published_at,now()),updated_at=now() where content_id=p_content_id;
 insert into public.setc_media_events(event_type,aggregate_id,organization_oid,content_id,actor_user_id,payload)
 values('media.content.published',p_content_id,v_org,p_content_id,(select auth.uid()),jsonb_build_object('version',v_version,'external_url',p_external_url)) returning event_id into v_event;
 return v_event;
end $$;

revoke all on function public.setc_media_transition(uuid,text,text) from public,anon;
revoke all on function public.setc_media_emit_event(text,uuid,jsonb,uuid,uuid) from public,anon;
revoke all on function public.setc_media_enqueue_outbox(uuid,text,text,text) from public,anon;
revoke all on function public.setc_media_publish(uuid,text) from public,anon;
grant execute on function public.setc_media_transition(uuid,text,text) to authenticated;
grant execute on function public.setc_media_emit_event(text,uuid,jsonb,uuid,uuid) to authenticated;
grant execute on function public.setc_media_enqueue_outbox(uuid,text,text,text) to authenticated;
grant execute on function public.setc_media_publish(uuid,text) to authenticated;
