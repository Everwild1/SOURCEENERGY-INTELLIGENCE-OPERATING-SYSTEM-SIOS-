-- VZC E01/E02 contract smoke assertions.
-- Intended for controlled CI/test database execution.

begin;

-- E01 mission registry must not confer production authority.
do $$
begin
  if not exists (
    select 1 from vzc.domain_registry
    where domain_code='VZC'
      and production_authority=false
      and canonical_control_ref='VZC-SC-001'
  ) then
    raise exception 'VZC domain registry baseline missing or unsafe';
  end if;
end $$;

-- E02: observation -> derived event linkage is valid.
do $$
declare
  obs uuid;
  evt uuid;
begin
  insert into vzc.observation_registry(observation_type,subject_type,subject_key,source_system,observed_at,quality_state,confidence)
  values ('contract.speed_observed','corridor','CI-VZC-E02','ci',now(),'validated',0.95)
  returning observation_id into obs;

  insert into vzc.safety_events(event_type,subject_type,subject_key,event_class,event_state,first_observed_at,last_observed_at,confidence)
  values ('contract.speed_risk','corridor','CI-VZC-E02','derived_intelligence','corroborated',now(),now(),0.90)
  returning safety_event_id into evt;

  insert into vzc.safety_event_observations(safety_event_id,observation_id,relationship)
  values (evt,obs,'supports');
end $$;

-- E02: authority-confirmed event state requires explicit authority evidence.
do $$
begin
  begin
    insert into vzc.safety_events(event_type,subject_type,subject_key,event_class,event_state,first_observed_at,last_observed_at)
    values ('contract.unsafe_authority_state','corridor','CI-VZC-E02','observation','authority_confirmed',now(),now());
    raise exception 'Expected authority-confirmed constraint failure did not occur';
  exception when check_violation then
    null;
  end;
end $$;

-- E02: authorization/execution trust classes require explicit authority evidence.
do $$
begin
  begin
    insert into vzc.safety_events(event_type,subject_type,subject_key,event_class,event_state,first_observed_at,last_observed_at)
    values ('contract.unsafe_authorization','corridor','CI-VZC-E02','authorization','detected',now(),now());
    raise exception 'Expected consequential trust-class constraint failure did not occur';
  exception when check_violation then
    null;
  end;
end $$;

rollback;
