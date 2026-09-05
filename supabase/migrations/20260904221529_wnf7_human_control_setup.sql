alter table wnf7.reviewer_assignments
  add constraint reviewer_assignments_metadata_object_check
  check(jsonb_typeof(metadata)='object');

alter table wnf7.reviewer_assignments
  add constraint reviewer_assignments_lifecycle_check
  check(
    (
      mobilization_status='UNASSIGNED'
      and reviewer_subject_id is null
      and reviewer_display_ref is null
      and appointment_evidence_ref is null
      and conflict_status='PENDING'
      and accepted_at is null
    )
    or (
      mobilization_status='NOMINATED'
      and reviewer_subject_id is not null
      and reviewer_display_ref is not null
      and accepted_at is null
    )
    or (
      mobilization_status='ASSIGNED'
      and reviewer_subject_id is not null
      and reviewer_display_ref is not null
      and appointment_evidence_ref is not null
      and conflict_status in ('PENDING','NO_CONFLICT_DECLARED')
      and accepted_at is null
    )
    or (
      mobilization_status='ACCEPTED'
      and reviewer_subject_id is not null
      and reviewer_display_ref is not null
      and appointment_evidence_ref is not null
      and conflict_status='NO_CONFLICT_DECLARED'
      and accepted_at is not null
    )
    or (
      mobilization_status='HOLD'
      and accepted_at is null
    )
  );

alter table wnf7.reviewer_assignments
  add constraint reviewer_assignments_governed_context_check
  check(
    mobilization_status='UNASSIGNED'
    or (
      coalesce(metadata->>'appointed_by_subject_id','')
        ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      and metadata->>'appointed_by_subject_id'<>reviewer_subject_id::text
      and coalesce(metadata->>'effective_at','')<>''
      and metadata->>'authority_posture'='DOES_NOT_CONFER_AUTHORITY'
      and metadata->>'production_authorized'='false'
    )
  );

insert into wnf7.reviewer_assignments(
  pilot_code,
  reviewer_role_code,
  conflict_status,
  mobilization_status,
  metadata
)
select
  'PILOT-7D-001',
  role_code,
  'PENDING',
  'UNASSIGNED',
  jsonb_build_object(
    'setup_mode',true,
    'human_designer_status','SYSTEM_DESIGNER_NOT_APPROVER',
    'register_ref','SRC-013',
    'appointment_status','AWAITING_NAMED_NOMINEE',
    'human_action_required',true,
    'authority_posture','DOES_NOT_CONFER_AUTHORITY',
    'production_authorized',false
  )
from wnf7.reviewer_roles
where required
on conflict (pilot_code,reviewer_role_code) do nothing;

alter table wnf7.evidence_items
  add column candidate_evidence_id uuid references wnf7.evidence_items(evidence_id),
  add column validated_by_role_code text references wnf7.reviewer_roles(role_code);

alter table wnf7.evidence_items
  add constraint evidence_items_validation_lineage_check
  check(
    (
      validation_status='PENDING'
      and candidate_evidence_id is null
      and validated_by_role_code is null
      and validated_at is null
      and validated_by is null
    )
    or (
      validation_status<>'PENDING'
      and candidate_evidence_id is not null
      and candidate_evidence_id<>evidence_id
      and validated_by_role_code is not null
      and validated_at is not null
      and validated_by is not null
    )
  );

create index evidence_items_candidate_idx
  on wnf7.evidence_items(candidate_evidence_id)
  where candidate_evidence_id is not null;
create index evidence_items_validator_role_idx
  on wnf7.evidence_items(validated_by_role_code)
  where validated_by_role_code is not null;

create function wnf7.enforce_evidence_reviewer_authority() returns trigger
language plpgsql set search_path='' as $$
declare
  v_pilot_code text;
  v_required_role text;
begin
  if new.validation_status='PENDING' then
    return new;
  end if;

  select s.pilot_code,s.reviewer_role_code
    into v_pilot_code,v_required_role
  from wnf7.pilot_scenarios s
  where s.scenario_code=new.scenario_code and s.active;

  if v_pilot_code is null or new.validated_by_role_code<>v_required_role then
    raise exception 'Evidence validation reviewer role does not match the active scenario';
  end if;

  if not exists(
    select 1
    from wnf7.reviewer_assignments r
    where r.pilot_code=v_pilot_code
      and r.reviewer_role_code=new.validated_by_role_code
      and r.reviewer_subject_id=new.validated_by
      and r.mobilization_status='ACCEPTED'
      and r.conflict_status='NO_CONFLICT_DECLARED'
      and r.appointment_evidence_ref is not null
  ) then
    raise exception 'Evidence validation requires an accepted no-conflict reviewer assignment';
  end if;

  if not exists(
    select 1
    from wnf7.evidence_items candidate
    where candidate.evidence_id=new.candidate_evidence_id
      and candidate.scenario_code=new.scenario_code
      and candidate.validation_status='PENDING'
      and candidate.metadata->>'evidence_stage'='CANDIDATE'
  ) then
    raise exception 'Evidence validation requires the matching pending candidate record';
  end if;

  return new;
end;
$$;

create trigger evidence_reviewer_authority
before insert on wnf7.evidence_items
for each row execute function wnf7.enforce_evidence_reviewer_authority();

alter table wnf7.adjudication_decisions
  add constraint adjudication_decisions_metadata_object_check
  check(jsonb_typeof(metadata)='object');

create function wnf7.enforce_adjudication_authority() returns trigger
language plpgsql set search_path='' as $$
declare
  v_pilot_code text;
  v_required_role text;
begin
  select s.pilot_code,s.reviewer_role_code
    into v_pilot_code,v_required_role
  from wnf7.pilot_scenarios s
  where s.scenario_code=new.scenario_code and s.active;

  if v_pilot_code is null or new.reviewer_role_code<>v_required_role then
    raise exception 'Adjudication reviewer role does not match the active scenario';
  end if;

  if new.decision_status='COMPLETE' then
    if not exists(
      select 1
      from wnf7.reviewer_assignments r
      where r.pilot_code=v_pilot_code
        and r.reviewer_role_code=new.reviewer_role_code
        and r.reviewer_subject_id=new.reviewer_subject_id
        and r.mobilization_status='ACCEPTED'
        and r.conflict_status='NO_CONFLICT_DECLARED'
        and r.appointment_evidence_ref is not null
    ) then
      raise exception 'Completed adjudication requires an accepted no-conflict reviewer assignment';
    end if;

    if not exists(
      select 1
      from wnf7.evidence_items e
      where e.scenario_code=new.scenario_code
        and e.validation_status='VALIDATED'
        and e.validated_by=new.reviewer_subject_id
        and e.validated_by_role_code=new.reviewer_role_code
    ) then
      raise exception 'Completed adjudication requires validated scenario evidence';
    end if;

    if jsonb_typeof(new.metadata->'evidence_refs')<>'array'
      or jsonb_array_length(new.metadata->'evidence_refs')=0
      or coalesce(new.metadata->>'automated_result_ref','') not like 'controlled://%'
      or coalesce(new.metadata->>'authority_posture','')<>'DOES_NOT_CONFER_AUTHORITY'
      or coalesce((new.metadata->>'production_authorized')::boolean,true) then
      raise exception 'Completed adjudication is missing governed non-production context';
    end if;
  end if;

  return new;
end;
$$;

create trigger adjudication_reviewer_authority
before insert on wnf7.adjudication_decisions
for each row execute function wnf7.enforce_adjudication_authority();

revoke execute on function wnf7.enforce_evidence_reviewer_authority() from public,anon,authenticated;
revoke execute on function wnf7.enforce_adjudication_authority() from public,anon,authenticated;
grant execute on function wnf7.enforce_evidence_reviewer_authority() to service_role;
grant execute on function wnf7.enforce_adjudication_authority() to service_role;

create view wnf7.reviewer_mobilization_queue with(security_invoker=true) as
select
  a.pilot_code,
  r.role_code reviewer_role_code,
  r.display_name,
  r.control_scope,
  a.assignment_id,
  a.mobilization_status,
  a.conflict_status,
  a.reviewer_subject_id,
  a.reviewer_display_ref,
  a.appointment_evidence_ref,
  a.accepted_at,
  (select count(*) from wnf7.pilot_scenarios s
    where s.pilot_code=a.pilot_code and s.reviewer_role_code=r.role_code and s.active) assigned_scenarios,
  (select count(*) from wnf7.pilot_scenarios s
    where s.pilot_code=a.pilot_code and s.reviewer_role_code=r.role_code and s.active
      and not exists(
        select 1 from wnf7.evidence_items e
        where e.scenario_code=s.scenario_code and e.validation_status='VALIDATED'
      )) outstanding_validation_scenarios,
  (select count(*) from wnf7.pilot_scenarios s
    where s.pilot_code=a.pilot_code and s.reviewer_role_code=r.role_code and s.active
      and not exists(
        select 1 from wnf7.adjudication_decisions d
        where d.scenario_code=s.scenario_code and d.decision_status='COMPLETE'
      )) outstanding_decision_scenarios,
  case a.mobilization_status
    when 'UNASSIGNED' then 'AWAITING_NAMED_NOMINEE'
    when 'NOMINATED' then 'NOMINATED_PENDING_APPOINTMENT'
    when 'ASSIGNED' then 'ASSIGNED_PENDING_ACCEPTANCE'
    when 'ACCEPTED' then 'ACCEPTED_READY_FOR_REVIEW'
    else 'HOLD'
  end reviewer_queue_state
from wnf7.reviewer_assignments a
join wnf7.reviewer_roles r on r.role_code=a.reviewer_role_code
where r.required;

create view wnf7.human_control_setup_readiness with(security_invoker=true) as
select
  g.pilot_code,
  (select count(*) from wnf7.reviewer_assignments a
    where a.pilot_code=g.pilot_code) initialized_reviewer_slots,
  (select count(*) from wnf7.reviewer_assignments a
    where a.pilot_code=g.pilot_code and a.mobilization_status='ACCEPTED') accepted_reviewers,
  (select count(distinct e.scenario_code) from wnf7.evidence_items e
    join wnf7.pilot_scenarios s using(scenario_code)
    where s.pilot_code=g.pilot_code and e.metadata->>'evidence_stage'='CANDIDATE') candidate_scenarios,
  (select count(distinct e.scenario_code) from wnf7.evidence_items e
    join wnf7.pilot_scenarios s using(scenario_code)
    where s.pilot_code=g.pilot_code and e.validation_status='VALIDATED') validated_scenarios,
  (select count(distinct d.scenario_code) from wnf7.adjudication_decisions d
    join wnf7.pilot_scenarios s using(scenario_code)
    where s.pilot_code=g.pilot_code and d.decision_status='COMPLETE') completed_decisions,
  case
    when (select count(*) from wnf7.reviewer_assignments a where a.pilot_code=g.pilot_code)=6
      and (select count(distinct e.scenario_code) from wnf7.evidence_items e
        join wnf7.pilot_scenarios s using(scenario_code)
        where s.pilot_code=g.pilot_code and e.metadata->>'evidence_stage'='CANDIDATE')=15
      then 'SYSTEM_SETUP_COMPLETE_AWAITING_HUMAN_ACTION'
    else 'SYSTEM_SETUP_INCOMPLETE'
  end setup_state,
  g.gate_state,
  g.production_authorized
from wnf7.release_gates g;

revoke all on wnf7.reviewer_mobilization_queue from public,anon,authenticated;
revoke all on wnf7.human_control_setup_readiness from public,anon,authenticated;
grant select on wnf7.reviewer_mobilization_queue to service_role;
grant select on wnf7.human_control_setup_readiness to service_role;

comment on view wnf7.reviewer_mobilization_queue is
  'Pre-approval reviewer work queue. Empty slots do not appoint, accept, or authorize a reviewer.';
comment on view wnf7.human_control_setup_readiness is
  'System setup readiness only. It is separate from evidence validation, adjudication, authority review, gate passage, and production authorization.';
