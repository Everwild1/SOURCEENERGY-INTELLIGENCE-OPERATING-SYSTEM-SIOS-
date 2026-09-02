alter table sourceenergy_one.authorization_requests
  add column if not exists requested_actor_ref text,
  add column if not exists decided_actor_ref text;

alter table sourceenergy_one.authorization_requests
  alter column expires_at set default (now() + interval '15 minutes');

update sourceenergy_one.authorization_requests
set expires_at = requested_at + interval '15 minutes'
where expires_at is null;

revoke all on function sourceenergy_one.request_consequential_authorization(uuid,uuid,text,text,text) from public, anon, authenticated, service_role;
drop function sourceenergy_one.request_consequential_authorization(uuid,uuid,text,text,text);

create function sourceenergy_one.request_consequential_authorization(
  p_access_context_id uuid,
  p_correlation_id uuid,
  p_action text,
  p_resource_type text,
  p_request_actor_ref text,
  p_resource_ref text default null,
  p_ttl interval default interval '15 minutes'
) returns uuid
language plpgsql
security definer
set search_path = sourceenergy_one, pg_temp
as $$
declare
  c sourceenergy_one.access_contexts%rowtype;
  r_id uuid;
begin
  if p_request_actor_ref is null or btrim(p_request_actor_ref) = '' then raise exception 'request actor reference required'; end if;
  if p_ttl is null or p_ttl <= interval '0 seconds' or p_ttl > interval '60 minutes' then raise exception 'authorization ttl must be >0 and <=60 minutes'; end if;
  select * into c from sourceenergy_one.access_contexts where id=p_access_context_id for update;
  if not found then raise exception 'access context not found'; end if;
  if c.expires_at is not null and c.expires_at <= now() then raise exception 'access context expired'; end if;
  if c.heartbeat_assertion_id is null then raise exception 'required heartbeat step-up absent'; end if;
  if not exists(select 1 from sourceenergy_one.policy_decisions p where p.correlation_id=p_correlation_id and p.subject_id=c.subject_id and p.action=p_action and p.resource_type=p_resource_type and p.resource_ref is not distinct from p_resource_ref and p.decision='require_authorization') then
    raise exception 'matching require_authorization policy decision absent';
  end if;
  insert into sourceenergy_one.authorization_requests(correlation_id,access_context_id,subject_id,action,resource_type,resource_ref,requested_by,requested_actor_ref,expires_at)
  values(p_correlation_id,c.id,c.subject_id,p_action,p_resource_type,p_resource_ref,auth.uid(),btrim(p_request_actor_ref),least(now()+p_ttl,coalesce(c.expires_at,now()+p_ttl))) returning id into r_id;
  insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
  values(p_correlation_id,c.subject_id,auth.uid(),'authorization_requested','authorization_request',r_id::text,jsonb_build_object('action',p_action,'resource_type',p_resource_type,'resource_ref',p_resource_ref,'requested_actor_ref',btrim(p_request_actor_ref),'expires_at',(select expires_at from sourceenergy_one.authorization_requests where id=r_id)));
  return r_id;
end;
$$;

revoke all on function sourceenergy_one.request_consequential_authorization(uuid,uuid,text,text,text,text,interval) from public, anon, authenticated;
grant execute on function sourceenergy_one.request_consequential_authorization(uuid,uuid,text,text,text,text,interval) to service_role;

revoke all on function sourceenergy_one.decide_consequential_authorization(uuid,text,text) from public, anon, authenticated, service_role;
drop function sourceenergy_one.decide_consequential_authorization(uuid,text,text);

create function sourceenergy_one.decide_consequential_authorization(
  p_request_id uuid,
  p_decision text,
  p_decider_actor_ref text,
  p_reason text default null
) returns text
language plpgsql
security definer
set search_path = sourceenergy_one, pg_temp
as $$
declare r sourceenergy_one.authorization_requests%rowtype; d text;
begin
  if p_decision not in ('approved','declined') then raise exception 'invalid authorization decision'; end if;
  if p_decider_actor_ref is null or btrim(p_decider_actor_ref) = '' then raise exception 'decider actor reference required'; end if;
  select * into r from sourceenergy_one.authorization_requests where id=p_request_id for update;
  if not found then raise exception 'authorization request not found'; end if;
  if r.status <> 'pending' then raise exception 'authorization request is not pending'; end if;
  if r.expires_at is null or r.expires_at <= now() then raise exception 'authorization request expired'; end if;
  if r.consumed_at is not null then raise exception 'authorization request already consumed'; end if;
  update sourceenergy_one.authorization_requests set status=p_decision,decided_by=auth.uid(),decided_actor_ref=btrim(p_decider_actor_ref),decided_at=now(),decision_reason=p_reason where id=p_request_id;
  d := case when p_decision='approved' then 'allow' else 'deny' end;
  insert into sourceenergy_one.policy_decisions(correlation_id,subject_id,action,resource_type,resource_ref,decision,policy_refs,reasons)
  values(r.correlation_id,r.subject_id,r.action,r.resource_type,r.resource_ref,d,jsonb_build_array('SE1-HUMAN-AUTHORIZATION'),jsonb_build_array(coalesce(p_reason,p_decision)));
  insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
  values(r.correlation_id,r.subject_id,auth.uid(),'authorization_'||p_decision,'authorization_request',r.id::text,jsonb_build_object('decision',p_decision,'reason',p_reason,'decider_actor_ref',btrim(p_decider_actor_ref)));
  return d;
end;
$$;

revoke all on function sourceenergy_one.decide_consequential_authorization(uuid,text,text,text) from public, anon, authenticated;
grant execute on function sourceenergy_one.decide_consequential_authorization(uuid,text,text,text) to service_role;

create index if not exists authorization_requests_pending_expiry_idx on sourceenergy_one.authorization_requests(expires_at) where status='pending';

comment on column sourceenergy_one.authorization_requests.requested_actor_ref is 'Required accountable actor reference for service-mediated authorization request.';
comment on column sourceenergy_one.authorization_requests.decided_actor_ref is 'Required accountable human actor reference for authorization decision.';
