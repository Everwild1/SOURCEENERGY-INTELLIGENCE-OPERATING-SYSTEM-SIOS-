-- VZC E01-E05 contract smoke assertions.
-- Intended for controlled CI/test database execution.
begin;

do $$ begin
 if not exists (select 1 from vzc.domain_registry where domain_code='VZC' and production_authority=false and canonical_control_ref='VZC-SC-001') then raise exception 'VZC domain registry baseline missing or unsafe'; end if;
end $$;

do $$ declare obs uuid; evt uuid; begin
 insert into vzc.observation_registry(observation_type,subject_type,subject_key,source_system,observed_at,quality_state,confidence)
 values ('contract.speed_observed','corridor','CI-VZC-E02','ci',now(),'validated',0.95) returning observation_id into obs;
 insert into vzc.safety_events(event_type,subject_type,subject_key,event_class,event_state,first_observed_at,last_observed_at,confidence)
 values ('contract.speed_risk','corridor','CI-VZC-E02','derived_intelligence','corroborated',now(),now(),0.90) returning safety_event_id into evt;
 insert into vzc.safety_event_observations(safety_event_id,observation_id,relationship) values (evt,obs,'supports');
end $$;

do $$ begin
 begin
  insert into vzc.safety_events(event_type,subject_type,subject_key,event_class,event_state,first_observed_at,last_observed_at)
  values ('contract.unsafe_authority_state','corridor','CI-VZC-E02','observation','authority_confirmed',now(),now());
  raise exception 'Expected authority-confirmed constraint failure did not occur';
 exception when check_violation then null; end;
end $$;

do $$ begin
 begin
  insert into vzc.safety_events(event_type,subject_type,subject_key,event_class,event_state,first_observed_at,last_observed_at)
  values ('contract.unsafe_authorization','corridor','CI-VZC-E02','authorization','detected',now(),now());
  raise exception 'Expected consequential trust-class constraint failure did not occur';
 exception when check_violation then null; end;
end $$;

-- E04: a control request cannot self-authorize without explicit authority evidence.
do $$ declare d uuid; r uuid; dec uuid; begin
 insert into vzc.device_bindings(device_key,device_type,control_capable) values ('CI-VZC-E04','traffic_signal_controller',true) returning device_binding_id into d;
 begin
  insert into vzc.control_requests(target_device_binding_id,requested_action,request_state,requested_by_ref)
  values(d,'change_signal_plan','authorized','ci');
  raise exception 'Expected unsafe E04 self-authorization failure did not occur';
 exception when check_violation then null; end;
 insert into vzc.control_requests(target_device_binding_id,requested_action,request_state,requested_by_ref)
 values(d,'change_signal_plan','pending_authority','ci') returning control_request_id into r;
 insert into vzc.control_authority_decisions(control_request_id,decision,authority_reference,decision_maker_ref)
 values(r,'authorized','AUTH-CI-E04','ci-authority') returning decision_id into dec;
 update vzc.control_requests set request_state='authorized', authority_reference='AUTH-CI-E04' where control_request_id=r;
 insert into vzc.control_execution_receipts(control_request_id,authority_decision_id,executing_system_ref,execution_state)
 values(r,dec,'authoritative-controller','accepted');
end $$;

-- E05: a drone mission cannot be marked authority-validated from spatial/mission presence alone.
do $$ declare b uuid; begin
 insert into vzc.mobility_safety_bindings(mode,source_schema,source_table,source_record_key,binding_role,evidence_state)
 values ('drone','rgl','drone_missions','CI-VZC-E05','mission','integration_designed') returning mobility_binding_id into b;
 begin
  insert into vzc.drone_safety_authority_checks(mobility_binding_id,mission_reference,authorization_state)
  values (b,'CI-VZC-E05','validated');
  raise exception 'Expected drone authority evidence constraint failure did not occur';
 exception when check_violation then null; end;
 insert into vzc.drone_safety_authority_checks(mobility_binding_id,mission_reference,jurisdiction_code,airspace_authority_ref,flight_authorization_ref,authorization_state)
 values (b,'CI-VZC-E05','TEST','competent-authority:test','flight-auth:test','validated');
end $$;
rollback;
