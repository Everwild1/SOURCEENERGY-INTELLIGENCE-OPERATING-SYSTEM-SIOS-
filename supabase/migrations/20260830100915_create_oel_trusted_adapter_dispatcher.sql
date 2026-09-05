create or replace function oel.execute_adapter_command(p_adapter_command_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = oel, sourceenergy_one, public, pg_temp
as $$
declare
  v_cmd oel.adapter_commands%rowtype;
  v_client oel.adapter_clients%rowtype;
  v_actor sourceenergy_one.actor_identities%rowtype;
  v_work oel.work_items%rowtype;
  v_permission text;
  v_event_id uuid;
  v_evidence_id uuid;
  v_exception_id uuid;
  v_auth_id uuid;
  v_target oel.control_level;
  v_response jsonb;
begin
  select * into v_cmd from oel.adapter_commands where id=p_adapter_command_id for update;
  if v_cmd.id is null then raise exception 'adapter_command_not_found'; end if;
  if v_cmd.status in ('EXECUTED','FAILED','REQUIRES_HUMAN_APPROVAL','REJECTED') then
    return jsonb_build_object('status','DUPLICATE','previous_status',v_cmd.status,'response',v_cmd.response);
  end if;
  if v_cmd.status <> 'ACCEPTED' or not v_cmd.signature_verified then raise exception 'adapter_command_not_accepted'; end if;

  select * into v_client from oel.adapter_clients where id=v_cmd.client_id and status='active';
  if v_client.id is null then raise exception 'adapter_client_inactive'; end if;
  if cardinality(v_client.allowed_org_oids)>0 and not (v_cmd.setc_org_oid=any(v_client.allowed_org_oids)) then raise exception 'organization_not_allowed'; end if;
  if cardinality(v_client.allowed_actions)>0 and not (v_cmd.action=any(v_client.allowed_actions)) then raise exception 'action_not_allowed'; end if;
  if v_cmd.requested_control_level > v_client.maximum_control_level then raise exception 'control_level_exceeds_client_limit'; end if;

  select * into v_actor from sourceenergy_one.actor_identities
   where actor_ref=v_cmd.actor_external_ref and status='active'
   order by verified_at desc nulls last, created_at desc limit 1;
  if v_actor.id is null then raise exception 'actor_not_resolved'; end if;

  if nullif(v_cmd.channel_identity,'') is not null and not exists (
    select 1 from oel.channel_identities ci
    where ci.actor_identity_id=v_actor.id and ci.channel_address=v_cmd.channel_identity
      and ci.status='active' and ci.verified_at is not null and lower(ci.assurance_level) <> 'unverified'
  ) then raise exception 'channel_not_verified'; end if;

  if v_cmd.resource_type <> 'work_item' or v_cmd.resource_id is null then raise exception 'unsupported_resource'; end if;
  select * into v_work from oel.work_items where id=v_cmd.resource_id::uuid for update;
  if v_work.id is null then raise exception 'work_item_not_found'; end if;
  if v_work.setc_org_oid <> v_cmd.setc_org_oid then raise exception 'resource_org_mismatch'; end if;

  v_permission := case v_cmd.action
    when 'work.acknowledge' then 'oel.work.acknowledge'
    when 'work.start' then 'oel.work.start'
    when 'evidence.submit' then 'oel.evidence.submit'
    when 'work.exception' then 'oel.work.exception'
    when 'work.escalate' then 'oel.work.escalate'
    else null end;
  if v_permission is null then raise exception 'unsupported_action'; end if;
  if not oel.actor_has_permission(v_actor.id,v_cmd.setc_org_oid,v_permission,least(v_cmd.requested_control_level,'C2'::oel.control_level)) then raise exception 'actor_permission_denied'; end if;

  if v_cmd.action in ('work.acknowledge','work.start','evidence.submit') and v_work.assigned_to_actor_id is distinct from v_actor.id then raise exception 'not_assigned_actor'; end if;
  if v_cmd.action in ('work.exception','work.escalate') and v_work.assigned_to_actor_id is distinct from v_actor.id and v_work.owner_actor_id is distinct from v_actor.id then raise exception 'not_authorized_for_work_item'; end if;

  if v_cmd.action='work.acknowledge' then
    update oel.work_items set status='ACKNOWLEDGED',updated_at=now(),version=version+1 where id=v_work.id and status='ASSIGNED';
    if not found then raise exception 'invalid_transition'; end if;
    insert into oel.events(event_type,aggregate_type,aggregate_id,setc_org_oid,actor_id,correlation_id,control_level,payload)
    values('work.acknowledged','work_item',v_work.id::text,v_work.setc_org_oid,v_actor.id,v_cmd.correlation_id,v_work.control_level,jsonb_build_object('source','sidekick-oel','adapter_command_id',v_cmd.id,'previous_status','ASSIGNED','new_status','ACKNOWLEDGED')) returning id into v_event_id;
    v_response:=jsonb_build_object('status','ACKNOWLEDGED','work_item_id',v_work.id,'correlation_id',v_cmd.correlation_id);
  elsif v_cmd.action='work.start' then
    update oel.work_items set status='IN_PROGRESS',updated_at=now(),version=version+1 where id=v_work.id and status='ACKNOWLEDGED';
    if not found then raise exception 'invalid_transition'; end if;
    insert into oel.events(event_type,aggregate_type,aggregate_id,setc_org_oid,actor_id,correlation_id,control_level,payload)
    values('work.started','work_item',v_work.id::text,v_work.setc_org_oid,v_actor.id,v_cmd.correlation_id,v_work.control_level,jsonb_build_object('source','sidekick-oel','adapter_command_id',v_cmd.id,'previous_status','ACKNOWLEDGED','new_status','IN_PROGRESS')) returning id into v_event_id;
    v_response:=jsonb_build_object('status','IN_PROGRESS','work_item_id',v_work.id,'correlation_id',v_cmd.correlation_id);
  elsif v_cmd.action='evidence.submit' then
    if nullif(v_cmd.payload->>'object_ref','') is null then raise exception 'object_ref_required'; end if;
    insert into oel.evidence_records(work_item_id,evidence_type,captured_by,source_channel,object_ref,content_hash,verified_status)
    values(v_work.id,(v_cmd.payload->>'evidence_type')::oel.evidence_type,v_actor.id,'sidekick',v_cmd.payload->>'object_ref',nullif(v_cmd.payload->>'content_hash',''),'unverified') returning id into v_evidence_id;
    insert into oel.events(event_type,aggregate_type,aggregate_id,setc_org_oid,actor_id,correlation_id,control_level,evidence_refs,payload)
    values('work.evidence_submitted','work_item',v_work.id::text,v_work.setc_org_oid,v_actor.id,v_cmd.correlation_id,v_work.control_level,jsonb_build_array(v_evidence_id),jsonb_build_object('source','sidekick-oel','adapter_command_id',v_cmd.id,'evidence_id',v_evidence_id)) returning id into v_event_id;
    v_response:=jsonb_build_object('status','EVIDENCE_RECORDED','evidence_id',v_evidence_id,'correlation_id',v_cmd.correlation_id);
  elsif v_cmd.action='work.exception' then
    if nullif(btrim(v_cmd.payload->>'reason'),'') is null then raise exception 'reason_required'; end if;
    insert into oel.exceptions(work_item_id,setc_org_oid,severity,impact_domain,control_level,status,summary,evidence_refs,created_by)
    values(v_work.id,v_work.setc_org_oid,coalesce(nullif(v_cmd.payload->>'severity',''),'medium'),coalesce(nullif(v_cmd.payload->>'impact_domain',''),'operations'),least(v_work.control_level,'C2'::oel.control_level),'OPEN',v_cmd.payload->>'reason',case when nullif(v_cmd.payload->>'evidence_ref','') is null then '[]'::jsonb else jsonb_build_array(v_cmd.payload->>'evidence_ref') end,v_actor.id) returning id into v_exception_id;
    update oel.work_items set status='EXCEPTION',updated_at=now(),version=version+1 where id=v_work.id and status not in ('COMPLETE','CANCELLED');
    if not found then raise exception 'invalid_transition'; end if;
    insert into oel.events(event_type,aggregate_type,aggregate_id,setc_org_oid,actor_id,correlation_id,control_level,evidence_refs,payload)
    values('work.exception_raised','work_item',v_work.id::text,v_work.setc_org_oid,v_actor.id,v_cmd.correlation_id,v_work.control_level,case when nullif(v_cmd.payload->>'evidence_ref','') is null then '[]'::jsonb else jsonb_build_array(v_cmd.payload->>'evidence_ref') end,jsonb_build_object('source','sidekick-oel','adapter_command_id',v_cmd.id,'exception_id',v_exception_id,'reason',v_cmd.payload->>'reason')) returning id into v_event_id;
    v_response:=jsonb_build_object('status','EXCEPTION','exception_id',v_exception_id,'work_item_id',v_work.id,'correlation_id',v_cmd.correlation_id);
  else
    v_target:=coalesce(nullif(v_cmd.payload->>'target_control_level','')::oel.control_level,'C3'::oel.control_level);
    if v_target<'C3'::oel.control_level then raise exception 'target_control_level_must_be_C3_or_higher'; end if;
    if nullif(btrim(v_cmd.payload->>'reason'),'') is null then raise exception 'reason_required'; end if;
    insert into sourceenergy_one.authorization_requests(correlation_id,access_context_id,subject_id,action,resource_type,resource_ref,status,requested_by,requested_at,requested_actor_ref)
    select v_cmd.correlation_id,ac.id,coalesce(v_actor.subject_id,v_actor.actor_ref),'work.escalation.execute','work_item',v_work.id::text,'pending',v_actor.auth_user_id,now(),v_actor.actor_ref
    from sourceenergy_one.access_contexts ac where ac.actor_identity_id=v_actor.id order by ac.created_at desc limit 1 returning id into v_auth_id;
    if v_auth_id is null then raise exception 'access_context_required'; end if;
    update oel.work_items set status='REVIEW_PENDING',control_level=v_target,updated_at=now(),version=version+1 where id=v_work.id and status not in ('COMPLETE','CANCELLED');
    if not found then raise exception 'invalid_transition'; end if;
    insert into oel.events(event_type,aggregate_type,aggregate_id,setc_org_oid,actor_id,correlation_id,control_level,payload)
    values('work.escalated','work_item',v_work.id::text,v_work.setc_org_oid,v_actor.id,v_cmd.correlation_id,v_target,jsonb_build_object('source','sidekick-oel','adapter_command_id',v_cmd.id,'reason',v_cmd.payload->>'reason','authorization_request_id',v_auth_id,'previous_control_level',v_work.control_level,'target_control_level',v_target)) returning id into v_event_id;
    perform oel.finalize_adapter_command(v_cmd.id,'REQUIRES_HUMAN_APPROVAL',jsonb_build_object('status','REQUIRES_HUMAN_APPROVAL','work_item_id',v_work.id,'authorization_request_id',v_auth_id,'target_control_level',v_target,'correlation_id',v_cmd.correlation_id),v_auth_id,array[v_event_id]);
    return jsonb_build_object('status','REQUIRES_HUMAN_APPROVAL','work_item_id',v_work.id,'authorization_request_id',v_auth_id,'target_control_level',v_target,'correlation_id',v_cmd.correlation_id,'event_id',v_event_id);
  end if;

  perform oel.finalize_adapter_command(v_cmd.id,'EXECUTED',v_response,null,array[v_event_id]);
  return v_response || jsonb_build_object('event_id',v_event_id,'adapter_command_id',v_cmd.id);
end;
$$;

revoke all on function oel.execute_adapter_command(uuid) from public, anon, authenticated;
comment on function oel.execute_adapter_command(uuid) is 'OEL-COMMISSION-001 trusted Sidekick adapter dispatcher. Explicit actor context; C0-C2 execution only; C3+ escalation creates canonical human authorization request. Server/Edge only.';
