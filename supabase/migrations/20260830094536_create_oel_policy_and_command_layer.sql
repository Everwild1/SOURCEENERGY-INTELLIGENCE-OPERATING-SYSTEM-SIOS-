create schema if not exists oel_api;

create table if not exists oel.policy_rules (
  id uuid primary key default gen_random_uuid(),
  action text not null,
  resource_type text not null,
  minimum_control_level oel.control_level not null default 'C0',
  maximum_control_level oel.control_level not null default 'C6',
  required_permission text,
  requires_human_approval boolean not null default false,
  requires_evidence boolean not null default false,
  requires_separation_of_duties boolean not null default false,
  active boolean not null default true,
  policy_ref text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (action, resource_type, minimum_control_level, maximum_control_level)
);

create table if not exists oel.command_receipts (
  id uuid primary key default gen_random_uuid(),
  correlation_id uuid not null,
  command_name text not null,
  actor_identity_id uuid references sourceenergy_one.actor_identities(id),
  setc_org_oid text references public.setc_organizations(oid),
  target_type text,
  target_id text,
  requested_control_level oel.control_level not null,
  decision text not null check (decision in ('ALLOW','DENY','REQUIRES_HUMAN_APPROVAL')),
  policy_rule_id uuid references oel.policy_rules(id),
  authorization_request_id uuid references sourceenergy_one.authorization_requests(id),
  reason text,
  created_at timestamptz not null default now()
);

insert into oel.policy_rules(action,resource_type,minimum_control_level,maximum_control_level,required_permission,requires_human_approval,requires_evidence,requires_separation_of_duties,policy_ref)
values
('message.send','message','C0','C1','oel.message.send',false,false,false,'OEL-POL-001'),
('work.assign','work_item','C1','C2','oel.work.assign',false,false,false,'OEL-POL-001'),
('work.acknowledge','work_item','C1','C2','oel.work.acknowledge',false,false,false,'OEL-POL-001'),
('work.start','work_item','C1','C2','oel.work.start',false,false,false,'OEL-POL-001'),
('evidence.submit','evidence','C1','C2','oel.evidence.submit',false,true,false,'OEL-POL-001'),
('work.complete','work_item','C2','C2','oel.work.complete',false,true,false,'OEL-POL-001'),
('decision.execute','decision','C3','C3','oel.decision.execute',true,true,false,'OEL-POL-001'),
('decision.execute','decision','C4','C4','oel.decision.execute',true,true,true,'OEL-POL-001'),
('decision.execute','decision','C5','C5','oel.decision.execute',true,true,true,'OEL-POL-001'),
('decision.execute','decision','C6','C6','oel.decision.execute',true,true,true,'OEL-POL-001')
on conflict do nothing;

create or replace function oel.resolve_actor_identity()
returns uuid
language sql
security invoker
set search_path = oel, sourceenergy_one, auth, public
as $$
  select ai.id
  from sourceenergy_one.actor_identities ai
  where ai.auth_user_id = auth.uid()
    and ai.status = 'active'
  order by ai.verified_at desc nulls last, ai.created_at desc
  limit 1
$$;

create or replace function oel.actor_has_permission(
  p_actor_identity_id uuid,
  p_setc_org_oid text,
  p_permission text,
  p_control_level oel.control_level
)
returns boolean
language sql
security invoker
set search_path = oel, sourceenergy_one, public
as $$
  select exists (
    select 1
    from oel.role_assignments ra
    join oel.roles r on r.id = ra.role_id
    where ra.actor_identity_id = p_actor_identity_id
      and r.setc_org_oid = p_setc_org_oid
      and ra.status = 'active'
      and r.status = 'active'
      and now() >= ra.effective_from
      and (ra.effective_to is null or now() < ra.effective_to)
      and r.max_control_level >= p_control_level
      and (
        r.permissions ? p_permission
        or r.permissions @> jsonb_build_array(p_permission)
      )
  )
  or exists (
    select 1
    from oel.delegations d
    where d.delegate_actor_id = p_actor_identity_id
      and d.status = 'active'
      and now() >= d.effective_from
      and now() < d.effective_to
      and d.maximum_control_level >= p_control_level
      and d.action_scope @> jsonb_build_array(p_permission)
      and (
        d.org_unit_id is null
        or exists (
          select 1 from oel.org_units ou
          where ou.id = d.org_unit_id
            and ou.setc_org_oid = p_setc_org_oid
        )
      )
  )
$$;

create or replace function oel.evaluate_command(
  p_action text,
  p_resource_type text,
  p_setc_org_oid text,
  p_control_level oel.control_level,
  p_target_id text default null,
  p_correlation_id uuid default gen_random_uuid()
)
returns table(decision text, policy_rule_id uuid, authorization_request_id uuid, reason text)
language plpgsql
security invoker
set search_path = oel, sourceenergy_one, public, auth
as $$
declare
  v_actor uuid;
  v_rule oel.policy_rules%rowtype;
  v_auth uuid;
begin
  v_actor := oel.resolve_actor_identity();
  if v_actor is null then
    insert into oel.command_receipts(correlation_id,command_name,actor_identity_id,setc_org_oid,target_type,target_id,requested_control_level,decision,reason)
    values (p_correlation_id,p_action,null,p_setc_org_oid,p_resource_type,p_target_id,p_control_level,'DENY','No active verified actor identity mapped to auth.uid()');
    return query select 'DENY'::text,null::uuid,null::uuid,'No active verified actor identity mapped to auth.uid()'::text;
    return;
  end if;

  select * into v_rule
  from oel.policy_rules pr
  where pr.active
    and pr.action = p_action
    and pr.resource_type = p_resource_type
    and p_control_level >= pr.minimum_control_level
    and p_control_level <= pr.maximum_control_level
  order by pr.minimum_control_level desc
  limit 1;

  if v_rule.id is null then
    insert into oel.command_receipts(correlation_id,command_name,actor_identity_id,setc_org_oid,target_type,target_id,requested_control_level,decision,reason)
    values (p_correlation_id,p_action,v_actor,p_setc_org_oid,p_resource_type,p_target_id,p_control_level,'DENY','No active policy rule');
    return query select 'DENY'::text,null::uuid,null::uuid,'No active policy rule'::text;
    return;
  end if;

  if not oel.actor_has_permission(v_actor,p_setc_org_oid,v_rule.required_permission,p_control_level) then
    insert into oel.command_receipts(correlation_id,command_name,actor_identity_id,setc_org_oid,target_type,target_id,requested_control_level,decision,policy_rule_id,reason)
    values (p_correlation_id,p_action,v_actor,p_setc_org_oid,p_resource_type,p_target_id,p_control_level,'DENY',v_rule.id,'Actor lacks required permission or control level');
    return query select 'DENY'::text,v_rule.id,null::uuid,'Actor lacks required permission or control level'::text;
    return;
  end if;

  if v_rule.requires_human_approval then
    insert into sourceenergy_one.authorization_requests(
      correlation_id, access_context_id, subject_id, action, resource_type, resource_ref, status, requested_by, requested_at, requested_actor_ref
    )
    select p_correlation_id, ac.id, coalesce(ai.subject_id, ai.actor_ref), p_action, p_resource_type, p_target_id, 'pending', ai.auth_user_id, now(), ai.actor_ref
    from sourceenergy_one.actor_identities ai
    join sourceenergy_one.access_contexts ac on ac.actor_identity_id = ai.id
    where ai.id = v_actor
    order by ac.created_at desc
    limit 1
    returning id into v_auth;

    insert into oel.command_receipts(correlation_id,command_name,actor_identity_id,setc_org_oid,target_type,target_id,requested_control_level,decision,policy_rule_id,authorization_request_id,reason)
    values (p_correlation_id,p_action,v_actor,p_setc_org_oid,p_resource_type,p_target_id,p_control_level,'REQUIRES_HUMAN_APPROVAL',v_rule.id,v_auth,'Policy requires accountable human approval');
    return query select 'REQUIRES_HUMAN_APPROVAL'::text,v_rule.id,v_auth,'Policy requires accountable human approval'::text;
    return;
  end if;

  insert into oel.command_receipts(correlation_id,command_name,actor_identity_id,setc_org_oid,target_type,target_id,requested_control_level,decision,policy_rule_id,reason)
  values (p_correlation_id,p_action,v_actor,p_setc_org_oid,p_resource_type,p_target_id,p_control_level,'ALLOW',v_rule.id,'Policy and authority satisfied');
  return query select 'ALLOW'::text,v_rule.id,null::uuid,'Policy and authority satisfied'::text;
end;
$$;

create or replace function oel_api.get_my_work()
returns setof oel.work_items
language sql
security invoker
set search_path = oel, auth
as $$
  select wi.*
  from oel.work_items wi
  where wi.assigned_to_actor_id = oel.resolve_actor_identity()
    and wi.status not in ('COMPLETE','CANCELLED')
  order by wi.due_at nulls last, wi.created_at
$$;

create or replace function oel_api.acknowledge_work(
  p_work_item_id uuid,
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security invoker
set search_path = oel, oel_api, auth, public
as $$
declare
  v_work oel.work_items%rowtype;
  v_eval record;
  v_actor uuid;
begin
  v_actor := oel.resolve_actor_identity();
  select * into v_work from oel.work_items where id = p_work_item_id;
  if v_work.id is null then raise exception 'work_item_not_found'; end if;
  if v_work.assigned_to_actor_id is distinct from v_actor then raise exception 'not_assigned_actor'; end if;

  select * into v_eval from oel.evaluate_command('work.acknowledge','work_item',v_work.setc_org_oid,v_work.control_level,v_work.id::text,p_correlation_id);
  if v_eval.decision <> 'ALLOW' then
    return jsonb_build_object('status',v_eval.decision,'reason',v_eval.reason,'authorization_request_id',v_eval.authorization_request_id);
  end if;

  update oel.work_items
  set status='ACKNOWLEDGED', updated_at=now(), version=version+1
  where id=p_work_item_id and status='ASSIGNED';
  if not found then raise exception 'invalid_transition'; end if;

  insert into oel.events(event_type,aggregate_type,aggregate_id,setc_org_oid,actor_id,correlation_id,control_level,payload)
  values ('work.acknowledged','work_item',p_work_item_id::text,v_work.setc_org_oid,v_actor,p_correlation_id,v_work.control_level,jsonb_build_object('previous_status','ASSIGNED','new_status','ACKNOWLEDGED'));

  return jsonb_build_object('status','ACKNOWLEDGED','work_item_id',p_work_item_id,'correlation_id',p_correlation_id);
end;
$$;

create or replace function oel_api.start_work(
  p_work_item_id uuid,
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security invoker
set search_path = oel, oel_api, auth, public
as $$
declare
  v_work oel.work_items%rowtype;
  v_eval record;
  v_actor uuid;
begin
  v_actor := oel.resolve_actor_identity();
  select * into v_work from oel.work_items where id = p_work_item_id;
  if v_work.id is null then raise exception 'work_item_not_found'; end if;
  if v_work.assigned_to_actor_id is distinct from v_actor then raise exception 'not_assigned_actor'; end if;
  select * into v_eval from oel.evaluate_command('work.start','work_item',v_work.setc_org_oid,v_work.control_level,v_work.id::text,p_correlation_id);
  if v_eval.decision <> 'ALLOW' then return jsonb_build_object('status',v_eval.decision,'reason',v_eval.reason,'authorization_request_id',v_eval.authorization_request_id); end if;
  update oel.work_items set status='IN_PROGRESS',updated_at=now(),version=version+1 where id=p_work_item_id and status='ACKNOWLEDGED';
  if not found then raise exception 'invalid_transition'; end if;
  insert into oel.events(event_type,aggregate_type,aggregate_id,setc_org_oid,actor_id,correlation_id,control_level,payload)
  values ('work.started','work_item',p_work_item_id::text,v_work.setc_org_oid,v_actor,p_correlation_id,v_work.control_level,jsonb_build_object('previous_status','ACKNOWLEDGED','new_status','IN_PROGRESS'));
  return jsonb_build_object('status','IN_PROGRESS','work_item_id',p_work_item_id,'correlation_id',p_correlation_id);
end;
$$;

create or replace function oel_api.submit_evidence(
  p_work_item_id uuid,
  p_evidence_type oel.evidence_type,
  p_object_ref text,
  p_content_hash text default null,
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security invoker
set search_path = oel, oel_api, auth, public
as $$
declare
  v_work oel.work_items%rowtype;
  v_eval record;
  v_actor uuid;
  v_evidence_id uuid;
begin
  v_actor := oel.resolve_actor_identity();
  select * into v_work from oel.work_items where id=p_work_item_id;
  if v_work.id is null then raise exception 'work_item_not_found'; end if;
  if v_work.assigned_to_actor_id is distinct from v_actor then raise exception 'not_assigned_actor'; end if;
  select * into v_eval from oel.evaluate_command('evidence.submit','evidence',v_work.setc_org_oid,least(v_work.control_level,'C2'::oel.control_level),v_work.id::text,p_correlation_id);
  if v_eval.decision <> 'ALLOW' then return jsonb_build_object('status',v_eval.decision,'reason',v_eval.reason,'authorization_request_id',v_eval.authorization_request_id); end if;
  insert into oel.evidence_records(work_item_id,evidence_type,captured_by,source_channel,object_ref,content_hash,verified_status)
  values (p_work_item_id,p_evidence_type,v_actor,'api',p_object_ref,p_content_hash,'unverified') returning id into v_evidence_id;
  insert into oel.events(event_type,aggregate_type,aggregate_id,setc_org_oid,actor_id,correlation_id,control_level,evidence_refs,payload)
  values ('work.evidence_submitted','work_item',p_work_item_id::text,v_work.setc_org_oid,v_actor,p_correlation_id,v_work.control_level,jsonb_build_array(v_evidence_id),jsonb_build_object('evidence_id',v_evidence_id,'evidence_type',p_evidence_type));
  return jsonb_build_object('status','EVIDENCE_RECORDED','evidence_id',v_evidence_id,'correlation_id',p_correlation_id);
end;
$$;

revoke all on schema oel_api from public, anon;
revoke all on all functions in schema oel_api from public, anon;
grant usage on schema oel_api to authenticated;
grant execute on function oel_api.get_my_work() to authenticated;
grant execute on function oel_api.acknowledge_work(uuid,uuid) to authenticated;
grant execute on function oel_api.start_work(uuid,uuid) to authenticated;
grant execute on function oel_api.submit_evidence(uuid,oel.evidence_type,text,text,uuid) to authenticated;

revoke all on function oel.resolve_actor_identity() from public, anon;
revoke all on function oel.actor_has_permission(uuid,text,text,oel.control_level) from public, anon;
revoke all on function oel.evaluate_command(text,text,text,oel.control_level,text,uuid) from public, anon;
grant execute on function oel.resolve_actor_identity() to authenticated;
grant execute on function oel.actor_has_permission(uuid,text,text,oel.control_level) to authenticated;
grant execute on function oel.evaluate_command(text,text,text,oel.control_level,text,uuid) to authenticated;

alter table oel.policy_rules enable row level security;
alter table oel.command_receipts enable row level security;
revoke all on oel.policy_rules,oel.command_receipts from public,anon,authenticated;

comment on schema oel_api is 'Controlled command surface for the SETC Organizational Execution Layer. Authenticated clients invoke governed commands; direct OEL table mutation remains closed.';
comment on function oel.evaluate_command(text,text,text,oel.control_level,text,uuid) is 'Evaluates OEL-POL-001 authority and creates a SourceEnergy One authorization request for C3-C6 policy gates.';
