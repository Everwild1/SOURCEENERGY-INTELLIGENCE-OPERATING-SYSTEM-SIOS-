create or replace function sourceenergy_one.consume_heartbeat_step_up(
  p_assertion_id uuid,
  p_correlation_id uuid,
  p_purpose text,
  p_action text,
  p_resource_type text,
  p_resource_ref text default null
) returns uuid
language plpgsql
security definer
set search_path = sourceenergy_one, pg_temp
as $$
declare
  a sourceenergy_one.heartbeat_verification_assertions%rowtype;
  ctx_id uuid;
begin
  if p_purpose is null or btrim(p_purpose) = '' or p_action is null or btrim(p_action) = '' then
    raise exception 'purpose and action are required';
  end if;

  select * into a from sourceenergy_one.heartbeat_verification_assertions where id = p_assertion_id for update;
  if not found then raise exception 'heartbeat assertion not found'; end if;
  if a.verification_status <> 'verified' then raise exception 'heartbeat assertion not verified'; end if;
  if a.assurance_level not in ('elevated','institutional') then raise exception 'insufficient heartbeat assurance'; end if;
  if a.expires_at <= now() then raise exception 'heartbeat assertion expired'; end if;
  if a.revoked_at is not null and a.revoked_at <= now() then raise exception 'heartbeat assertion revoked'; end if;

  insert into sourceenergy_one.heartbeat_consumption_receipts(assertion_digest, assertion_id, correlation_id, purpose)
  values (a.assertion_digest, a.id, p_correlation_id, p_purpose);

  insert into sourceenergy_one.access_contexts(subject_id, actor_id, roles, permissions, assurance_level, expires_at, heartbeat_assertion_id, authentication_factors)
  values (a.subject_id, auth.uid(), '[]'::jsonb, '[]'::jsonb, a.assurance_level, a.expires_at, a.id,
          jsonb_build_array(jsonb_build_object('type','heartbeat-id','assertion_id',a.id,'verified_at',a.issued_at)))
  returning id into ctx_id;

  insert into sourceenergy_one.policy_decisions(correlation_id, subject_id, action, resource_type, resource_ref, decision, policy_refs, reasons)
  values (p_correlation_id, a.subject_id, p_action, p_resource_type, p_resource_ref,
          'require_authorization', jsonb_build_array('SE1-08A'),
          jsonb_build_array('HeartBeatID step-up establishes identity assurance only; consequential execution requires separate authorization.'));

  insert into sourceenergy_one.audit_events(correlation_id, subject_id, actor_id, event_type, object_type, object_ref, payload)
  values (p_correlation_id, a.subject_id, auth.uid(), 'heartbeat_step_up_consumed', 'access_context', ctx_id::text,
          jsonb_build_object('assertion_id',a.id,'assurance_level',a.assurance_level,'action',p_action,'purpose',p_purpose));

  return ctx_id;
exception
  when unique_violation then
    raise exception 'heartbeat assertion already consumed';
end;
$$;

revoke all on function sourceenergy_one.consume_heartbeat_step_up(uuid,uuid,text,text,text,text) from public, anon, authenticated;
grant execute on function sourceenergy_one.consume_heartbeat_step_up(uuid,uuid,text,text,text,text) to service_role;
comment on function sourceenergy_one.consume_heartbeat_step_up(uuid,uuid,text,text,text,text) is 'Service-role-only atomic HeartBeatID step-up. Consumes assertion once, creates bounded access context, records require_authorization policy decision and audit event. Never authorizes execution.';
