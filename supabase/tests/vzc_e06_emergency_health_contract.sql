-- VZC E06 emergency and health coordination authority contract.
begin;
do $$ declare e uuid; b uuid; begin
 insert into vzc.safety_events(event_type,subject_type,subject_key,event_class,event_state,first_observed_at,last_observed_at)
 values ('contract.emergency','corridor','CI-VZC-E06','observation','detected',now(),now()) returning safety_event_id into e;
 insert into vzc.emergency_incident_bindings(safety_event_id,source_schema,source_table,source_record_key,incident_role)
 values(e,'dhn_ops','incidents','CI-VZC-E06','health_incident') returning emergency_binding_id into b;
 begin
  insert into vzc.emergency_coordination_requests(emergency_binding_id,coordination_type,request_state,requested_by_ref)
  values(b,'responder_mobility','authority_accepted','ci');
  raise exception 'Expected E06 authority-evidence constraint failure did not occur';
 exception when check_violation then null; end;
 begin
  insert into vzc.health_context_references(emergency_binding_id,source_schema,source_table,source_record_key,context_class,purpose,contains_person_level_data)
  values(b,'dhn_clinical','clinical_resource_refs','CI-PERSON','clinical_resource_reference','emergency coordination',true);
  raise exception 'Expected E06 lawful-basis constraint failure did not occur';
 exception when check_violation then null; end;
 insert into vzc.emergency_coordination_requests(emergency_binding_id,coordination_type,request_state,requested_by_ref,competent_authority_ref,authority_reference)
 values(b,'responder_mobility','authority_accepted','ci','dispatch-authority:test','AUTH-E06');
end $$;
rollback;