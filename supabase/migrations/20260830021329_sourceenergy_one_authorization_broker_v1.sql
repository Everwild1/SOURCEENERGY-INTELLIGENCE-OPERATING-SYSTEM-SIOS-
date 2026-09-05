create table sourceenergy_one.authorization_requests (
  id uuid primary key default gen_random_uuid(),
  correlation_id uuid not null,
  access_context_id uuid not null references sourceenergy_one.access_contexts(id) on delete restrict,
  subject_id text not null,
  action text not null,
  resource_type text not null,
  resource_ref text,
  status text not null default 'pending' check (status in ('pending','approved','declined','expired','cancelled')),
  requested_by uuid default auth.uid(),
  requested_at timestamptz not null default now(),
  decided_by uuid,
  decided_at timestamptz,
  decision_reason text,
  unique(correlation_id, action, resource_type, resource_ref)
);
create index on sourceenergy_one.authorization_requests(status, requested_at);
alter table sourceenergy_one.authorization_requests enable row level security;
revoke all on sourceenergy_one.authorization_requests from public, anon, authenticated;
grant all on sourceenergy_one.authorization_requests to service_role;
create policy authorization_requests_service_role_all on sourceenergy_one.authorization_requests for all to service_role using (true) with check (true);

create or replace function sourceenergy_one.request_consequential_authorization(
  p_access_context_id uuid,
  p_correlation_id uuid,
  p_action text,
  p_resource_type text,
  p_resource_ref text default null
) returns uuid
language plpgsql security definer set search_path=sourceenergy_one,pg_temp
as $$
declare c sourceenergy_one.access_contexts%rowtype; r_id uuid;
begin
  select * into c from sourceenergy_one.access_contexts where id=p_access_context_id;
  if not found then raise exception 'access context not found'; end if;
  if c.expires_at is not null and c.expires_at <= now() then raise exception 'access context expired'; end if;
  if c.heartbeat_assertion_id is null then raise exception 'required heartbeat step-up absent'; end if;
  if not exists(select 1 from sourceenergy_one.policy_decisions p where p.correlation_id=p_correlation_id and p.subject_id=c.subject_id and p.action=p_action and p.decision='require_authorization') then
    raise exception 'matching require_authorization policy decision absent';
  end if;
  insert into sourceenergy_one.authorization_requests(correlation_id,access_context_id,subject_id,action,resource_type,resource_ref)
  values(p_correlation_id,c.id,c.subject_id,p_action,p_resource_type,p_resource_ref) returning id into r_id;
  insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
  values(p_correlation_id,c.subject_id,auth.uid(),'authorization_requested','authorization_request',r_id::text,jsonb_build_object('action',p_action,'resource_type',p_resource_type,'resource_ref',p_resource_ref));
  return r_id;
end; $$;

create or replace function sourceenergy_one.decide_consequential_authorization(
  p_request_id uuid,
  p_decision text,
  p_reason text default null
) returns text
language plpgsql security definer set search_path=sourceenergy_one,pg_temp
as $$
declare r sourceenergy_one.authorization_requests%rowtype; d text;
begin
  if p_decision not in ('approved','declined') then raise exception 'invalid authorization decision'; end if;
  select * into r from sourceenergy_one.authorization_requests where id=p_request_id for update;
  if not found then raise exception 'authorization request not found'; end if;
  if r.status <> 'pending' then raise exception 'authorization request is not pending'; end if;
  update sourceenergy_one.authorization_requests set status=p_decision,decided_by=auth.uid(),decided_at=now(),decision_reason=p_reason where id=p_request_id;
  d := case when p_decision='approved' then 'allow' else 'deny' end;
  insert into sourceenergy_one.policy_decisions(correlation_id,subject_id,action,resource_type,resource_ref,decision,policy_refs,reasons)
  values(r.correlation_id,r.subject_id,r.action,r.resource_type,r.resource_ref,d,jsonb_build_array('SE1-HUMAN-AUTHORIZATION'),jsonb_build_array(coalesce(p_reason,p_decision)));
  insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload)
  values(r.correlation_id,r.subject_id,auth.uid(),'authorization_'||p_decision,'authorization_request',r.id::text,jsonb_build_object('decision',p_decision,'reason',p_reason));
  return d;
end; $$;

revoke all on function sourceenergy_one.request_consequential_authorization(uuid,uuid,text,text,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.decide_consequential_authorization(uuid,text,text) from public,anon,authenticated;
grant execute on function sourceenergy_one.request_consequential_authorization(uuid,uuid,text,text,text) to service_role;
grant execute on function sourceenergy_one.decide_consequential_authorization(uuid,text,text) to service_role;
comment on table sourceenergy_one.authorization_requests is 'Human authorization broker requests. HeartBeat identity assurance is prerequisite evidence only and never auto-approves a request.';
