create or replace function public.setc_media_editorial_queue()
returns table(content_id uuid, organization_oid text, title text, content_type text, representation_class text, lifecycle_status text, current_version integer, updated_at timestamptz)
language sql security definer set search_path=public,media_access,pg_temp as $$
  select c.content_id,c.organization_oid,c.title,c.content_type,c.representation_class,c.lifecycle_status,c.current_version,c.updated_at
  from public.setc_media_content c
  where media_access.has_permission(c.organization_oid,'media.read')
    and c.lifecycle_status not in ('PUBLISHED','ARCHIVED','WITHDRAWN')
  order by c.updated_at desc
$$;
revoke all on function public.setc_media_editorial_queue() from public,anon;
grant execute on function public.setc_media_editorial_queue() to authenticated;

create or replace function public.setc_media_evidence_queue()
returns table(claim_id uuid, content_id uuid, organization_oid text, title text, claim_text text, claim_category text, materiality text, verification_state text, authoritative_source_required boolean, created_at timestamptz)
language sql security definer set search_path=public,media_access,pg_temp as $$
  select cl.claim_id,cl.content_id,c.organization_oid,c.title,cl.claim_text,cl.claim_category,cl.materiality,cl.verification_state,cl.authoritative_source_required,cl.created_at
  from public.setc_media_claims cl join public.setc_media_content c on c.content_id=cl.content_id
  where media_access.has_permission(c.organization_oid,'media.fact_validate')
    and cl.verification_state in ('UNVERIFIED','PENDING','CONFLICT')
  order by case cl.materiality when 'CRITICAL' then 1 when 'HIGH' then 2 when 'STANDARD' then 3 else 4 end, cl.created_at
$$;
revoke all on function public.setc_media_evidence_queue() from public,anon;
grant execute on function public.setc_media_evidence_queue() to authenticated;

create or replace function public.setc_media_approval_queue()
returns table(content_id uuid, organization_oid text, title text, representation_class text, lifecycle_status text, current_version integer, unresolved_claims bigint, pending_reviews bigint, updated_at timestamptz)
language sql security definer set search_path=public,media_access,pg_temp as $$
  select c.content_id,c.organization_oid,c.title,c.representation_class,c.lifecycle_status,c.current_version,
    (select count(*) from public.setc_media_claims cl where cl.content_id=c.content_id and cl.authoritative_source_required and cl.verification_state<>'VERIFIED') as unresolved_claims,
    (select count(*) from public.setc_media_reviews r where r.content_id=c.content_id and r.decision='PENDING') as pending_reviews,
    c.updated_at
  from public.setc_media_content c
  where media_access.has_permission(c.organization_oid,'media.approve')
    and c.lifecycle_status in ('DOMAIN_REVIEW','APPROVAL_PENDING','APPROVED')
  order by c.updated_at desc
$$;
revoke all on function public.setc_media_approval_queue() from public,anon;
grant execute on function public.setc_media_approval_queue() to authenticated;

create or replace function public.setc_media_distribution_queue()
returns table(outbox_id uuid,event_id uuid,organization_oid text,content_id uuid,event_type text,destination_type text,destination_key text,delivery_status text,attempt_count integer,available_at timestamptz,created_at timestamptz)
language sql security definer set search_path=public,media_access,pg_temp as $$
  select o.outbox_id,o.event_id,e.organization_oid,e.content_id,e.event_type,o.destination_type,o.destination_key,o.delivery_status,o.attempt_count,o.available_at,o.created_at
  from public.setc_media_outbox o join public.setc_media_events e on e.event_id=o.event_id
  where media_access.has_permission(e.organization_oid,'media.publish')
  order by case o.delivery_status when 'FAILED' then 1 when 'DEAD_LETTER' then 2 when 'PENDING' then 3 else 4 end, o.created_at desc
$$;
revoke all on function public.setc_media_distribution_queue() from public,anon;
grant execute on function public.setc_media_distribution_queue() to authenticated;

comment on function public.setc_media_editorial_queue() is 'Authenticated organization-scoped editorial work queue. Returned rows do not grant mutation authority.';
comment on function public.setc_media_evidence_queue() is 'Authenticated fact-validation queue scoped by media.fact_validate.';
comment on function public.setc_media_approval_queue() is 'Authenticated approval queue scoped by media.approve; unresolved counts are advisory and command/RLS checks remain authoritative.';
comment on function public.setc_media_distribution_queue() is 'Authenticated distribution queue scoped by media.publish; transport status does not establish underlying content truth.';
