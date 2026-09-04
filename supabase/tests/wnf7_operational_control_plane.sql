begin;
do $$
declare
  v_count integer;
  v_blocked boolean;
  v_decision uuid;
  v_evidence uuid;
  v_readiness text;
  v_results jsonb;
  v_assessment_state text;
  v_eligibility text;
begin
  select count(*) into v_count from wnf7.dimension_registry;
  if v_count<>7 then raise exception 'Expected 7 dimensions; observed %',v_count; end if;
  select count(*) into v_count from wnf7.component_profiles;
  if v_count<>8 then raise exception 'Expected 8 component profiles; observed %',v_count; end if;
  select count(*) into v_count from wnf7.component_dimension_controls;
  if v_count<>56 then raise exception 'Expected 56 component controls; observed %',v_count; end if;
  select count(distinct control_summary) into v_count from wnf7.component_dimension_controls;
  if v_count<>56 then raise exception 'Expected 56 component-specific control summaries; observed %',v_count; end if;
  select count(*) into v_count from wnf7.pilot_scenarios where pilot_code='PILOT-7D-001';
  if v_count<>15 then raise exception 'Expected 15 scenarios; observed %',v_count; end if;
  if exists(select 1 from wnf7.component_profiles where production_authorized) then
    raise exception 'Baseline must not authorize production';
  end if;
  if not exists(select 1 from wnf7.component_profiles where component_code='SOURCECOIN' and execution_boundary ilike '%No minting%') then
    raise exception 'SourceCoin non-transactional boundary missing';
  end if;
  select count(*) into v_count from (values ('SETC'),('SOURCECUBE'),('CODEX_VERITAS'),('SOURCEONE'),('SIOS'),('SIDEKICK_OEL'),('SOURCECOIN'),('SOURCEBLOCK')) required(component_code)
  where exists(select 1 from wnf7.component_profiles p where p.component_code=required.component_code);
  if v_count<>8 then raise exception 'Full ecosystem profile coverage incomplete; observed %',v_count; end if;
  if not exists(select 1 from wnf7.component_profiles where component_code='SOURCEBLOCK' and operational_scope ilike '%value-producing unit%') then
    raise exception 'Canonical SourceBlock lifecycle definition missing';
  end if;
  select derived_readiness into v_readiness from wnf7.operational_readiness where pilot_code='PILOT-7D-001';
  if v_readiness<>'HOLD_INCOMPLETE' then raise exception 'Pilot must initialize on hold; observed %',v_readiness; end if;
  if has_schema_privilege('anon','wnf7','USAGE') or has_schema_privilege('authenticated','wnf7','USAGE') then
    raise exception 'Client role unexpectedly has WNF-7 schema usage';
  end if;
  select count(*) into v_count from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='wnf7' and c.relkind='r' and not c.relrowsecurity;
  if v_count<>0 then raise exception 'WNF-7 RLS missing on % tables',v_count; end if;

  select jsonb_agg(
    jsonb_build_object(
      'dimension',dimension_code,
      'status','PASS',
      'finding','Synthetic runtime control satisfied.',
      'evidence_refs',jsonb_build_array('synthetic://wnf7/runtime/' || lower(dimension_code)),
      'control_refs',jsonb_build_array('WNF7-SETC-' || lpad(ordinal::text,2,'0')),
      'owner_role','QA_LEAD',
      'reviewed_at','2026-09-04T19:00:00Z'
    ) order by ordinal
  ) into v_results from wnf7.dimension_registry;

  insert into wnf7.assessment_records(
    assessment_id,component_code,profile_code,subject_ref,correlation_id,idempotency_key,
    consequence_class,observed_at,authority_ref,operational_reason,dimension_results,
    input_sha256,output_sha256,evaluator_version
  ) values(
    'WNF7-TEST-PASS','SETC','SETC-PROFILE-7D-001','synthetic://subject/pass','CORR-WNF7-PASS','IDEM-WNF7-PASS',
    'OPERATIONAL','2026-09-04T19:00:00Z','synthetic://authority/current','Exercise deterministic runtime aggregation.',v_results,
    repeat('a',64),repeat('b',64),'wnf7-runtime-1.0'
  ) returning automated_state,decision_eligibility into v_assessment_state,v_eligibility;
  if v_assessment_state<>'PASS' or v_eligibility<>'ELIGIBLE_FOR_HUMAN_DECISION' then
    raise exception 'Passing assessment derived invalid posture: % / %',v_assessment_state,v_eligibility;
  end if;

  v_blocked:=false;
  begin
    insert into wnf7.assessment_records(
      assessment_id,component_code,profile_code,subject_ref,correlation_id,idempotency_key,
      consequence_class,observed_at,authority_ref,operational_reason,dimension_results,
      input_sha256,output_sha256,evaluator_version
    ) values(
      'WNF7-TEST-MISSING','SETC','SETC-PROFILE-7D-001','synthetic://subject/missing','CORR-WNF7-MISSING','IDEM-WNF7-MISSING',
      'ADVISORY','2026-09-04T19:00:00Z','synthetic://authority/current','Reject incomplete dimension set.',v_results-6,
      repeat('c',64),repeat('d',64),'wnf7-runtime-1.0'
    );
  exception when check_violation then v_blocked:=true; end;
  if not v_blocked then raise exception 'Assessment accepted fewer than seven dimensions'; end if;

  select jsonb_agg(
    case when item->>'dimension'='FEAR'
      then jsonb_set(item,'{status}','"REVIEW"'::jsonb)
      else item end
  ) into v_results from jsonb_array_elements(v_results) item;
  insert into wnf7.assessment_records(
    assessment_id,component_code,profile_code,subject_ref,correlation_id,idempotency_key,
    consequence_class,observed_at,operational_reason,dimension_results,
    input_sha256,output_sha256,evaluator_version
  ) values(
    'WNF7-TEST-FEAR-REVIEW','SETC','SETC-PROFILE-7D-001','synthetic://subject/fear','CORR-WNF7-FEAR','IDEM-WNF7-FEAR',
    'ADVISORY','2026-09-04T19:00:00Z','Fear uncertainty must fail closed.',v_results,
    repeat('e',64),repeat('f',64),'wnf7-runtime-1.0'
  ) returning automated_state,decision_eligibility into v_assessment_state,v_eligibility;
  if v_assessment_state<>'BLOCKED' or v_eligibility<>'NOT_ELIGIBLE' then
    raise exception 'Fear uncertainty did not fail closed: % / %',v_assessment_state,v_eligibility;
  end if;

  v_blocked:=false;
  begin update wnf7.assessment_records set operational_reason='mutated' where assessment_id='WNF7-TEST-PASS';
  exception when others then v_blocked:=true; end;
  if not v_blocked then raise exception 'Assessment ledger allowed mutation'; end if;

  v_blocked:=false;
  begin
    insert into wnf7.assessment_records(
      assessment_id,component_code,profile_code,subject_ref,correlation_id,idempotency_key,
      consequence_class,observed_at,operational_reason,dimension_results,human_review_required,
      execution_command,input_sha256,output_sha256,evaluator_version
    ) values(
      'WNF7-TEST-COMMAND','SOURCECUBE','SOURCECUBE-PROFILE-7D-001','synthetic://subject/command','CORR-WNF7-COMMAND','IDEM-WNF7-COMMAND',
      'CONSEQUENTIAL','2026-09-04T19:00:00Z','Reject executable payload.',v_results,true,
      '{"action":"execute"}'::jsonb,repeat('1',64),repeat('2',64),'wnf7-runtime-1.0'
    );
  exception when check_violation then v_blocked:=true; end;
  if not v_blocked then raise exception 'Assessment accepted non-null execution command'; end if;

  if has_function_privilege('anon','wnf7.derive_automated_state(jsonb)','EXECUTE')
    or has_function_privilege('authenticated','wnf7.derive_automated_state(jsonb)','EXECUTE') then
    raise exception 'Client role unexpectedly has WNF-7 evaluator execution privilege';
  end if;

  insert into wnf7.evidence_items(scenario_code,evidence_ref,source_system)
  values('SCN-001','synthetic://wnf7/evidence','CI') returning evidence_id into v_evidence;
  v_blocked:=false;
  begin update wnf7.evidence_items set evidence_ref='synthetic://mutated' where evidence_id=v_evidence;
  exception when others then v_blocked:=true; end;
  if not v_blocked then raise exception 'Evidence ledger allowed mutation'; end if;

  insert into wnf7.adjudication_decisions(scenario_code,reviewer_subject_id,reviewer_role_code,disposition,decision_status,rationale_summary)
  values('SCN-001','00000000-0000-0000-0000-000000000001','SETC_OWNER','HOLD','HOLD','Synthetic fail-closed test')
  returning decision_id into v_decision;
  v_blocked:=false;
  begin delete from wnf7.adjudication_decisions where decision_id=v_decision;
  exception when others then v_blocked:=true; end;
  if not v_blocked then raise exception 'Decision ledger allowed deletion'; end if;

  v_blocked:=false;
  begin update wnf7.release_gates set gate_state='AUTHORIZED',production_authorized=true where pilot_code='PILOT-7D-001';
  exception when others then v_blocked:=true; end;
  if not v_blocked then raise exception 'Production authorization succeeded without authority attestation'; end if;
end;
$$;
rollback;
select 'wnf7_operational_control_plane_contract_passed' as result;
