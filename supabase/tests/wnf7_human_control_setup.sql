begin;

do $$
declare
  v_count integer;
  v_assigned integer;
  v_validation integer;
  v_decisions integer;
  v_blocked boolean;
  v_candidate_id uuid;
  v_setup_state text;
  v_operational_readiness text;
  v_queue_state text;
begin
  select count(*) into v_count
  from wnf7.reviewer_assignments
  where pilot_code='PILOT-7D-001'
    and mobilization_status='UNASSIGNED'
    and conflict_status='PENDING'
    and reviewer_subject_id is null
    and reviewer_display_ref is null
    and appointment_evidence_ref is null
    and accepted_at is null
    and metadata->>'human_designer_status'='SYSTEM_DESIGNER_NOT_APPROVER'
    and metadata->>'authority_posture'='DOES_NOT_CONFER_AUTHORITY'
    and metadata->>'production_authorized'='false';
  if v_count<>6 then raise exception 'Reviewer slots exceeded system-setup posture'; end if;

  select count(*),sum(assigned_scenarios),sum(outstanding_validation_scenarios),sum(outstanding_decision_scenarios)
    into v_count,v_assigned,v_validation,v_decisions
  from wnf7.reviewer_mobilization_queue
  where pilot_code='PILOT-7D-001';
  if v_count<>6 or v_assigned<>15 or v_validation<>15 or v_decisions<>15 then
    raise exception 'Reviewer queue is incomplete: rows %, scenarios %, validation %, decisions %',v_count,v_assigned,v_validation,v_decisions;
  end if;

  select setup_state into v_setup_state
  from wnf7.human_control_setup_readiness
  where pilot_code='PILOT-7D-001';
  if v_setup_state<>'SYSTEM_SETUP_COMPLETE_AWAITING_HUMAN_ACTION' then
    raise exception 'Unexpected human-control setup state: %',v_setup_state;
  end if;

  select derived_readiness into v_operational_readiness
  from wnf7.operational_readiness
  where pilot_code='PILOT-7D-001';
  if v_operational_readiness<>'HOLD_INCOMPLETE' then
    raise exception 'System setup advanced operational readiness: %',v_operational_readiness;
  end if;
  if exists(select 1 from wnf7.release_gates where pilot_code='PILOT-7D-001' and (gate_state<>'HOLD' or production_authorized)) then
    raise exception 'System setup advanced the release gate or production authorization';
  end if;

  if has_table_privilege('anon','wnf7.reviewer_mobilization_queue','SELECT')
    or has_table_privilege('authenticated','wnf7.reviewer_mobilization_queue','SELECT')
    or has_table_privilege('anon','wnf7.human_control_setup_readiness','SELECT')
    or has_table_privilege('authenticated','wnf7.human_control_setup_readiness','SELECT') then
    raise exception 'Client role unexpectedly has human-control view access';
  end if;

  select count(*) into v_count
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='wnf7'
    and c.relname in ('reviewer_mobilization_queue','human_control_setup_readiness')
    and c.reloptions @> array['security_invoker=true'];
  if v_count<>2 then raise exception 'Human-control views are not security invoker'; end if;

  if has_function_privilege('anon','wnf7.enforce_evidence_reviewer_authority()','EXECUTE')
    or has_function_privilege('authenticated','wnf7.enforce_evidence_reviewer_authority()','EXECUTE')
    or has_function_privilege('anon','wnf7.enforce_adjudication_authority()','EXECUTE')
    or has_function_privilege('authenticated','wnf7.enforce_adjudication_authority()','EXECUTE') then
    raise exception 'Client role unexpectedly has human-control trigger execution privilege';
  end if;

  v_blocked:=false;
  begin
    update wnf7.reviewer_assignments
    set mobilization_status='ACCEPTED'
    where pilot_code='PILOT-7D-001' and reviewer_role_code='SETC_OWNER';
  exception when check_violation then v_blocked:=true; end;
  if not v_blocked then raise exception 'Reviewer acceptance succeeded without identity, appointment, conflict, and time evidence'; end if;

  v_blocked:=false;
  begin
    update wnf7.reviewer_assignments
    set reviewer_subject_id='00000000-0000-4000-8000-000000000001',
        reviewer_display_ref='controlled://identity/reviewer/001',
        appointment_evidence_ref='controlled://SRC-013/appointment/SETC_OWNER',
        mobilization_status='NOMINATED',
        metadata=jsonb_build_object(
          'appointed_by_subject_id','00000000-0000-4000-8000-000000000001',
          'effective_at','2026-09-04T22:00:00Z',
          'authority_posture','DOES_NOT_CONFER_AUTHORITY',
          'production_authorized',false
        )
    where pilot_code='PILOT-7D-001' and reviewer_role_code='SETC_OWNER';
  exception when check_violation then v_blocked:=true; end;
  if not v_blocked then raise exception 'Reviewer self-appointment was accepted'; end if;

  update wnf7.reviewer_assignments
  set reviewer_subject_id='00000000-0000-4000-8000-000000000001',
      reviewer_display_ref='controlled://identity/reviewer/001',
      appointment_evidence_ref='controlled://SRC-013/appointment/SETC_OWNER',
      mobilization_status='NOMINATED',
      metadata=jsonb_build_object(
        'appointed_by_subject_id','00000000-0000-4000-8000-000000000002',
        'effective_at','2026-09-04T22:00:00Z',
        'authority_posture','DOES_NOT_CONFER_AUTHORITY',
        'production_authorized',false
      )
  where pilot_code='PILOT-7D-001' and reviewer_role_code='SETC_OWNER';

  select reviewer_queue_state into v_queue_state
  from wnf7.reviewer_mobilization_queue
  where pilot_code='PILOT-7D-001' and reviewer_role_code='SETC_OWNER';
  if v_queue_state<>'NOMINATED_PENDING_APPOINTMENT' then
    raise exception 'Valid nomination did not reach the nomination queue';
  end if;

  select evidence_id into v_candidate_id
  from wnf7.evidence_items
  where scenario_code='SCN-001'
    and evidence_ref='controlled://SRC-011/scenario/SCN-001';

  v_blocked:=false;
  begin
    insert into wnf7.evidence_items(
      scenario_code,evidence_ref,source_system,content_sha256,freshness_status,
      validation_status,observed_at,validated_at,validated_by,
      candidate_evidence_id,validated_by_role_code,metadata
    ) values(
      'SCN-001','controlled://SRC-013/validation/SCN-001','HUMAN_REVIEW',repeat('a',64),'CURRENT',
      'VALIDATED','2026-09-04T16:11:22Z','2026-09-04T22:10:00Z',
      '00000000-0000-4000-8000-000000000001',v_candidate_id,'SETC_OWNER',
      '{"authority_posture":"DOES_NOT_CONFER_AUTHORITY","production_authorized":false}'::jsonb
    );
  exception when others then v_blocked:=true; end;
  if not v_blocked then raise exception 'Unaccepted nominee validated evidence'; end if;

  v_blocked:=false;
  begin
    insert into wnf7.adjudication_decisions(
      scenario_code,reviewer_subject_id,reviewer_role_code,disposition,
      decision_status,rationale_summary
    ) values(
      'SCN-001','00000000-0000-4000-8000-000000000001','TECH_AUTHORITY',
      'HOLD','HOLD','Role mismatch probe'
    );
  exception when others then v_blocked:=true; end;
  if not v_blocked then raise exception 'Mismatched reviewer role adjudicated a scenario'; end if;

  v_blocked:=false;
  begin
    insert into wnf7.adjudication_decisions(
      scenario_code,reviewer_subject_id,reviewer_role_code,disposition,
      decision_status,rationale_summary,attestation_ref,metadata
    ) values(
      'SCN-001','00000000-0000-4000-8000-000000000001','SETC_OWNER',
      'CONFIRM','COMPLETE','Premature completion probe','controlled://SRC-013/attestation/SCN-001',
      '{"evidence_refs":["controlled://SRC-013/validation/SCN-001"],"automated_result_ref":"controlled://SRC-011/scenario/SCN-001","authority_posture":"DOES_NOT_CONFER_AUTHORITY","production_authorized":false}'::jsonb
    );
  exception when others then v_blocked:=true; end;
  if not v_blocked then raise exception 'Completed adjudication bypassed accepted reviewer and validated evidence gates'; end if;

  if exists(select 1 from wnf7.evidence_items where validation_status='VALIDATED') then
    raise exception 'System setup persisted a validated evidence result';
  end if;
  if exists(select 1 from wnf7.adjudication_decisions where decision_status='COMPLETE') then
    raise exception 'System setup persisted a completed adjudication';
  end if;
  if exists(select 1 from wnf7.reviewer_assignments where mobilization_status='ACCEPTED') then
    raise exception 'System setup persisted an accepted reviewer';
  end if;
end;
$$;

rollback;
select 'wnf7_human_control_setup_contract_passed' as result;
