create table if not exists public.setc_media_events (
 event_id uuid primary key default gen_random_uuid(),
 event_type text not null,
 aggregate_type text not null default 'MEDIA_CONTENT',
 aggregate_id uuid,
 organization_oid text references public.setc_organizations(oid) on update cascade on delete restrict,
 content_id uuid references public.setc_media_content(content_id) on delete set null,
 actor_user_id uuid,
 correlation_id uuid,
 causation_id uuid,
 event_version integer not null default 1 check (event_version > 0),
 payload jsonb not null default '{}'::jsonb,
 occurred_at timestamptz not null default now(),
 created_at timestamptz not null default now()
);
comment on table public.setc_media_events is 'Append-oriented Media domain event ledger for SIOS/API integration; events are evidence of system actions and do not create underlying institutional authority.';
create index if not exists idx_setc_media_events_content on public.setc_media_events(content_id, occurred_at desc);
create index if not exists idx_setc_media_events_org on public.setc_media_events(organization_oid, occurred_at desc);
alter table public.setc_media_events enable row level security;
revoke all on public.setc_media_events from anon, authenticated;

grant select, insert on public.setc_media_events to authenticated;
create policy media_events_select on public.setc_media_events for select to authenticated using (organization_oid is not null and media_access.has_permission(organization_oid,'media.read'));
create policy media_events_insert on public.setc_media_events for insert to authenticated with check (actor_user_id = auth.uid() and organization_oid is not null and media_access.has_permission(organization_oid,'media.read'));

create or replace function public.setc_media_emit_event(p_event_type text, p_content_id uuid, p_payload jsonb default '{}'::jsonb, p_correlation_id uuid default null, p_causation_id uuid default null)
returns uuid language plpgsql security invoker set search_path = public, pg_temp as $$
declare v_event_id uuid; v_org text;
begin
 select organization_oid into v_org from public.setc_media_content where content_id=p_content_id;
 if v_org is null then raise exception 'MEDIA_CONTENT_NOT_FOUND'; end if;
 if not media_access.has_permission(v_org,'media.read') then raise exception 'MEDIA_FORBIDDEN'; end if;
 insert into public.setc_media_events(event_type,aggregate_id,organization_oid,content_id,actor_user_id,correlation_id,causation_id,payload)
 values(p_event_type,p_content_id,v_org,p_content_id,auth.uid(),p_correlation_id,p_causation_id,coalesce(p_payload,'{}'::jsonb)) returning event_id into v_event_id;
 return v_event_id;
end $$;
revoke all on function public.setc_media_emit_event(text,uuid,jsonb,uuid,uuid) from public, anon;
grant execute on function public.setc_media_emit_event(text,uuid,jsonb,uuid,uuid) to authenticated;

create or replace function public.setc_media_publish(p_content_id uuid, p_external_url text default null)
returns uuid language plpgsql security invoker set search_path = public, pg_temp as $$
declare v_org text; v_version integer; v_channel uuid; v_event uuid;
begin
 select organization_oid,current_version into v_org,v_version from public.setc_media_content where content_id=p_content_id for update;
 if v_org is null then raise exception 'MEDIA_CONTENT_NOT_FOUND'; end if;
 if not media_access.has_permission(v_org,'media.publish') then raise exception 'MEDIA_PUBLISH_FORBIDDEN'; end if;
 if not public.setc_media_publication_ready(p_content_id) then raise exception 'MEDIA_NOT_PUBLICATION_READY'; end if;
 update public.setc_media_content set lifecycle_status='PUBLISHED', published_at=coalesce(published_at,now()), updated_at=now() where content_id=p_content_id;
 insert into public.setc_media_events(event_type,aggregate_id,organization_oid,content_id,actor_user_id,payload)
 values('media.content.published',p_content_id,v_org,p_content_id,auth.uid(),jsonb_build_object('version',v_version,'external_url',p_external_url)) returning event_id into v_event;
 return v_event;
end $$;
revoke all on function public.setc_media_publish(uuid,text) from public, anon;
grant execute on function public.setc_media_publish(uuid,text) to authenticated;

create or replace function public.setc_media_transition(p_content_id uuid, p_target_status text, p_reason text default null)
returns uuid language plpgsql security invoker set search_path = public, pg_temp as $$
declare v_org text; v_old text; v_event uuid;
begin
 select organization_oid,lifecycle_status into v_org,v_old from public.setc_media_content where content_id=p_content_id for update;
 if v_org is null then raise exception 'MEDIA_CONTENT_NOT_FOUND'; end if;
 if p_target_status in ('DRAFT','ASSIGNED','FACT_VALIDATION','EDITORIAL_REVIEW','DOMAIN_REVIEW','APPROVAL_PENDING') then
   if not media_access.has_permission(v_org,'media.draft') then raise exception 'MEDIA_TRANSITION_FORBIDDEN'; end if;
 elsif p_target_status='APPROVED' then
   if not media_access.has_permission(v_org,'media.approve') then raise exception 'MEDIA_APPROVAL_FORBIDDEN'; end if;
 elsif p_target_status in ('CORRECTED','SUPERSEDED','ARCHIVED','WITHDRAWN') then
   if not (media_access.has_permission(v_org,'media.correct') or media_access.has_permission(v_org,'media.admin')) then raise exception 'MEDIA_CORRECTION_FORBIDDEN'; end if;
 elsif p_target_status='PUBLISHED' then
   raise exception 'USE_MEDIA_PUBLISH_FUNCTION';
 else raise exception 'MEDIA_TARGET_STATUS_INVALID'; end if;
 update public.setc_media_content set lifecycle_status=p_target_status,updated_at=now(),archived_at=case when p_target_status='ARCHIVED' then now() else archived_at end where content_id=p_content_id;
 insert into public.setc_media_events(event_type,aggregate_id,organization_oid,content_id,actor_user_id,payload)
 values('media.content.status_changed',p_content_id,v_org,p_content_id,auth.uid(),jsonb_build_object('from',v_old,'to',p_target_status,'reason',p_reason)) returning event_id into v_event;
 return v_event;
end $$;
revoke all on function public.setc_media_transition(uuid,text,text) from public, anon;
grant execute on function public.setc_media_transition(uuid,text,text) to authenticated;
