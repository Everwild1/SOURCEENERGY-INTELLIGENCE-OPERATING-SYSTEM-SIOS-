grant select, update on public.setc_media_claims to authenticated;
grant select, insert, update on public.setc_media_reviews to authenticated;
grant select, insert, update on public.setc_media_approvals to authenticated;
grant select, update on public.setc_media_outbox to authenticated;

drop policy if exists media_claims_select on public.setc_media_claims;
create policy media_claims_select on public.setc_media_claims for select to authenticated
using (exists(select 1 from public.setc_media_content c where c.content_id=setc_media_claims.content_id and media_access.has_permission('media.read',c.organization_oid)));

drop policy if exists media_claims_update_validate on public.setc_media_claims;
create policy media_claims_update_validate on public.setc_media_claims for update to authenticated
using (exists(select 1 from public.setc_media_content c where c.content_id=setc_media_claims.content_id and media_access.has_permission('media.fact_validate',c.organization_oid)))
with check (exists(select 1 from public.setc_media_content c where c.content_id=setc_media_claims.content_id and media_access.has_permission('media.fact_validate',c.organization_oid)));

drop policy if exists media_reviews_select on public.setc_media_reviews;
create policy media_reviews_select on public.setc_media_reviews for select to authenticated
using (exists(select 1 from public.setc_media_content c where c.content_id=setc_media_reviews.content_id and media_access.has_permission('media.read',c.organization_oid)));

drop policy if exists media_reviews_insert on public.setc_media_reviews;
create policy media_reviews_insert on public.setc_media_reviews for insert to authenticated
with check (exists(select 1 from public.setc_media_content c where c.content_id=setc_media_reviews.content_id and media_access.has_permission('media.editorial_review',c.organization_oid)));

drop policy if exists media_reviews_update on public.setc_media_reviews;
create policy media_reviews_update on public.setc_media_reviews for update to authenticated
using (exists(select 1 from public.setc_media_content c where c.content_id=setc_media_reviews.content_id and (
  media_access.has_permission('media.editorial_review',c.organization_oid) or
  media_access.has_permission('media.fact_validate',c.organization_oid) or
  media_access.has_permission('media.domain_review',c.organization_oid)
)))
with check (exists(select 1 from public.setc_media_content c where c.content_id=setc_media_reviews.content_id and (
  media_access.has_permission('media.editorial_review',c.organization_oid) or
  media_access.has_permission('media.fact_validate',c.organization_oid) or
  media_access.has_permission('media.domain_review',c.organization_oid)
)));

drop policy if exists media_approvals_select on public.setc_media_approvals;
create policy media_approvals_select on public.setc_media_approvals for select to authenticated
using (exists(select 1 from public.setc_media_content c where c.content_id=setc_media_approvals.content_id and media_access.has_permission('media.read',c.organization_oid)));

drop policy if exists media_approvals_insert on public.setc_media_approvals;
create policy media_approvals_insert on public.setc_media_approvals for insert to authenticated
with check (exists(select 1 from public.setc_media_content c where c.content_id=setc_media_approvals.content_id and media_access.has_permission('media.approve',c.organization_oid)) and approver_user_id=auth.uid());

drop policy if exists media_approvals_update on public.setc_media_approvals;
create policy media_approvals_update on public.setc_media_approvals for update to authenticated
using (approver_user_id=auth.uid() and exists(select 1 from public.setc_media_content c where c.content_id=setc_media_approvals.content_id and media_access.has_permission('media.approve',c.organization_oid)))
with check (approver_user_id=auth.uid() and exists(select 1 from public.setc_media_content c where c.content_id=setc_media_approvals.content_id and media_access.has_permission('media.approve',c.organization_oid)));

drop policy if exists media_outbox_select on public.setc_media_outbox;
create policy media_outbox_select on public.setc_media_outbox for select to authenticated
using (exists(select 1 from public.setc_media_events e where e.event_id=setc_media_outbox.event_id and media_access.has_permission('media.publish',e.organization_oid)));

drop policy if exists media_outbox_update on public.setc_media_outbox;
create policy media_outbox_update on public.setc_media_outbox for update to authenticated
using (exists(select 1 from public.setc_media_events e where e.event_id=setc_media_outbox.event_id and media_access.has_permission('media.publish',e.organization_oid)))
with check (exists(select 1 from public.setc_media_events e where e.event_id=setc_media_outbox.event_id and media_access.has_permission('media.publish',e.organization_oid)));

create or replace function public.setc_media_validate_claim(p_claim_id uuid,p_state text,p_reason text default null)
returns uuid language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_content uuid; v_org text; v_event uuid;
begin
 if p_state not in ('VERIFIED','CONFLICT','REJECTED','PENDING') then raise exception 'MEDIA_CLAIM_STATE_INVALID'; end if;
 select cl.content_id,c.organization_oid into v_content,v_org from public.setc_media_claims cl join public.setc_media_content c on c.content_id=cl.content_id where cl.claim_id=p_claim_id for update of cl;
 if v_content is null then raise exception 'MEDIA_CLAIM_NOT_FOUND'; end if;
 if not media_access.has_permission('media.fact_validate',v_org) then raise exception 'MEDIA_FACT_VALIDATE_FORBIDDEN'; end if;
 update public.setc_media_claims set verification_state=p_state where claim_id=p_claim_id;
 insert into public.setc_media_events(event_type,aggregate_id,organization_oid,content_id,actor_user_id,payload)
 values('media.claim.validation_changed',v_content,v_org,v_content,auth.uid(),jsonb_build_object('claim_id',p_claim_id,'state',p_state,'reason',p_reason)) returning event_id into v_event;
 return v_event;
end $$;
revoke all on function public.setc_media_validate_claim(uuid,text,text) from public,anon;
grant execute on function public.setc_media_validate_claim(uuid,text,text) to authenticated;

create or replace function public.setc_media_review_decide(p_review_id uuid,p_decision text,p_notes text default null)
returns uuid language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_content uuid; v_org text; v_type text; v_required_permission text; v_event uuid;
begin
 if p_decision not in ('APPROVED','CHANGES_REQUIRED','REJECTED','WAIVED') then raise exception 'MEDIA_REVIEW_DECISION_INVALID'; end if;
 select r.content_id,r.review_type,c.organization_oid into v_content,v_type,v_org from public.setc_media_reviews r join public.setc_media_content c on c.content_id=r.content_id where r.review_id=p_review_id for update of r;
 if v_content is null then raise exception 'MEDIA_REVIEW_NOT_FOUND'; end if;
 v_required_permission := case when v_type='FACT' then 'media.fact_validate' when v_type='EDITORIAL' then 'media.editorial_review' else 'media.domain_review' end;
 if not media_access.has_permission(v_required_permission,v_org) then raise exception 'MEDIA_REVIEW_FORBIDDEN'; end if;
 update public.setc_media_reviews set decision=p_decision,notes=p_notes,reviewer_user_id=auth.uid(),decided_at=now() where review_id=p_review_id;
 insert into public.setc_media_events(event_type,aggregate_id,organization_oid,content_id,actor_user_id,payload)
 values('media.review.decided',v_content,v_org,v_content,auth.uid(),jsonb_build_object('review_id',p_review_id,'review_type',v_type,'decision',p_decision)) returning event_id into v_event;
 return v_event;
end $$;
revoke all on function public.setc_media_review_decide(uuid,text,text) from public,anon;
grant execute on function public.setc_media_review_decide(uuid,text,text) to authenticated;

create or replace function public.setc_media_approval_decide(p_content_id uuid,p_decision text,p_scope text,p_authority_basis text default null)
returns uuid language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_org text; v_version integer; v_unresolved bigint; v_pending bigint; v_event uuid;
begin
 if p_decision not in ('APPROVED','REJECTED') then raise exception 'MEDIA_APPROVAL_DECISION_INVALID'; end if;
 select organization_oid,current_version into v_org,v_version from public.setc_media_content where content_id=p_content_id for update;
 if v_org is null then raise exception 'MEDIA_CONTENT_NOT_FOUND'; end if;
 if not media_access.has_permission('media.approve',v_org) then raise exception 'MEDIA_APPROVAL_FORBIDDEN'; end if;
 select count(*) into v_unresolved from public.setc_media_claims where content_id=p_content_id and authoritative_source_required and verification_state<>'VERIFIED';
 select count(*) into v_pending from public.setc_media_reviews where content_id=p_content_id and decision='PENDING';
 if p_decision='APPROVED' and (v_unresolved>0 or v_pending>0) then raise exception 'MEDIA_APPROVAL_BLOCKED'; end if;
 insert into public.setc_media_approvals(content_id,approval_scope,approver_user_id,authority_basis,decision,approved_version,decided_at)
 values(p_content_id,p_scope,auth.uid(),p_authority_basis,p_decision,case when p_decision='APPROVED' then v_version else null end,now());
 update public.setc_media_content set lifecycle_status=case when p_decision='APPROVED' then 'APPROVED' else 'APPROVAL_PENDING' end,updated_at=now() where content_id=p_content_id;
 insert into public.setc_media_events(event_type,aggregate_id,organization_oid,content_id,actor_user_id,payload)
 values('media.approval.decided',p_content_id,v_org,p_content_id,auth.uid(),jsonb_build_object('decision',p_decision,'scope',p_scope,'version',v_version,'unresolved_claims',v_unresolved,'pending_reviews',v_pending)) returning event_id into v_event;
 return v_event;
end $$;
revoke all on function public.setc_media_approval_decide(uuid,text,text,text) from public,anon;
grant execute on function public.setc_media_approval_decide(uuid,text,text,text) to authenticated;

create or replace function public.setc_media_retry_outbox(p_outbox_id uuid)
returns uuid language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_event uuid; v_org text;
begin
 select o.event_id,e.organization_oid into v_event,v_org from public.setc_media_outbox o join public.setc_media_events e on e.event_id=o.event_id where o.outbox_id=p_outbox_id for update of o;
 if v_event is null then raise exception 'MEDIA_OUTBOX_NOT_FOUND'; end if;
 if not media_access.has_permission('media.publish',v_org) then raise exception 'MEDIA_OUTBOX_FORBIDDEN'; end if;
 update public.setc_media_outbox set delivery_status='PENDING',available_at=now(),locked_at=null,locked_by=null,last_error=null,updated_at=now() where outbox_id=p_outbox_id and delivery_status in ('FAILED','DEAD_LETTER');
 if not found then raise exception 'MEDIA_OUTBOX_NOT_RETRYABLE'; end if;
 return v_event;
end $$;
revoke all on function public.setc_media_retry_outbox(uuid) from public,anon;
grant execute on function public.setc_media_retry_outbox(uuid) to authenticated;
