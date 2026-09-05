begin;

do $$
declare
  v_count integer;
  v_blocked boolean;
  v_mobilization_state text;
  v_operational_readiness text;
  v_gate_state text;
  v_production_authorized boolean;
begin
  select count(*) into v_count
  from wnf7.evidence_items
  where source_system='SOURCEENERGY_DRIVE_CONTROLLED_EVIDENCE'
    and metadata->>'package_ref'='SRC-011';
  if v_count<>15 then
    raise exception 'Expected 15 candidate evidence records; observed %',v_count;
  end if;

  select count(distinct scenario_code) into v_count
  from wnf7.evidence_items
  where source_system='SOURCEENERGY_DRIVE_CONTROLLED_EVIDENCE'
    and metadata->>'package_ref'='SRC-011';
  if v_count<>15 then
    raise exception 'Expected evidence coverage for 15 distinct scenarios; observed %',v_count;
  end if;

  select count(*) into v_count
  from wnf7.evidence_items
  where source_system='SOURCEENERGY_DRIVE_CONTROLLED_EVIDENCE'
    and metadata->>'package_ref'='SRC-011'
    and freshness_status='PENDING'
    and validation_status='PENDING'
    and validated_at is null
    and validated_by is null;
  if v_count<>15 then
    raise exception 'Candidate evidence must remain pending human validation; observed % compliant rows',v_count;
  end if;

  select count(*) into v_count
  from wnf7.evidence_items
  where source_system='SOURCEENERGY_DRIVE_CONTROLLED_EVIDENCE'
    and metadata->>'package_ref'='SRC-011'
    and content_sha256='2af020c74f36472f021e27e2fa549f47012ae8ba39bd3dad0fe39f0db4dbe98c'
    and metadata->>'package_manifest_sha256'='cac5cd8757e52af04b6bed409879e70f6fd5abdc1e7c3842f4411e77580c0811'
    and metadata->>'integrity_status'='SHA256_MANIFEST_MATCH'
    and metadata->>'hash_scope'='CHARTER_RESULTS_ARTIFACT'
    and metadata->>'authority_posture'='DOES_NOT_CONFER_AUTHORITY'
    and metadata->>'substantive_validation'='PENDING_HUMAN_REVIEW'
    and metadata->>'execution_allowed'='false';
  if v_count<>15 then
    raise exception 'Evidence integrity or non-authority metadata is incomplete; observed % compliant rows',v_count;
  end if;

  if exists(
    select 1 from wnf7.evidence_items
    where validation_status='VALIDATED'
  ) then
    raise exception 'Mobilization migration unexpectedly created validated evidence';
  end if;

  if exists(
    select 1 from wnf7.evidence_items
    where evidence_ref ilike '%drive.google.com%'
       or evidence_ref ilike '%docs.google.com%'
       or metadata::text ilike '%drive.google.com%'
       or metadata::text ilike '%docs.google.com%'
  ) then
    raise exception 'Private Drive location leaked into WNF-7 evidence metadata';
  end if;

  select mobilization_state,gate_state,production_authorized
    into v_mobilization_state,v_gate_state,v_production_authorized
  from wnf7.evidence_mobilization_readiness
  where pilot_code='PILOT-7D-001';
  if v_mobilization_state<>'MOBILIZED_PENDING_HUMAN_VALIDATION' then
    raise exception 'Unexpected evidence mobilization state: %',v_mobilization_state;
  end if;
  if v_gate_state<>'HOLD' or v_production_authorized then
    raise exception 'Evidence mobilization advanced the release gate or production authorization';
  end if;

  select derived_readiness into v_operational_readiness
  from wnf7.operational_readiness
  where pilot_code='PILOT-7D-001';
  if v_operational_readiness<>'HOLD_INCOMPLETE' then
    raise exception 'Operational readiness advanced during evidence mobilization: %',v_operational_readiness;
  end if;

  select count(*) into v_count
  from wnf7.reviewer_assignments
  where pilot_code='PILOT-7D-001' and mobilization_status='ACCEPTED';
  if v_count<>0 then raise exception 'Reviewer acceptance unexpectedly advanced'; end if;

  select count(*) into v_count
  from wnf7.adjudication_decisions d
  join wnf7.pilot_scenarios s using(scenario_code)
  where s.pilot_code='PILOT-7D-001' and d.decision_status='COMPLETE';
  if v_count<>0 then raise exception 'Human adjudication unexpectedly advanced'; end if;

  if not exists(
    select 1
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='wnf7'
      and c.relname='evidence_mobilization_readiness'
      and c.reloptions @> array['security_invoker=true']
  ) then
    raise exception 'Evidence mobilization view is not security invoker';
  end if;

  if has_table_privilege('anon','wnf7.evidence_mobilization_readiness','SELECT')
    or has_table_privilege('authenticated','wnf7.evidence_mobilization_readiness','SELECT') then
    raise exception 'Client role unexpectedly has evidence mobilization view access';
  end if;
  if not has_table_privilege('service_role','wnf7.evidence_mobilization_readiness','SELECT') then
    raise exception 'Service role is missing evidence mobilization view access';
  end if;

  v_blocked:=false;
  begin
    insert into wnf7.evidence_items(scenario_code,evidence_ref,source_system)
    values('SCN-001','controlled://SRC-011/scenario/SCN-001','CI_DUPLICATE_PROBE');
  exception when unique_violation then v_blocked:=true; end;
  if not v_blocked then raise exception 'Duplicate scenario evidence reference was accepted'; end if;

  v_blocked:=false;
  begin
    update wnf7.evidence_items
    set validation_status='REJECTED'
    where scenario_code='SCN-001'
      and evidence_ref='controlled://SRC-011/scenario/SCN-001';
  exception when others then v_blocked:=true; end;
  if not v_blocked then raise exception 'Candidate evidence record allowed mutation'; end if;

  v_blocked:=false;
  begin
    delete from wnf7.evidence_items
    where scenario_code='SCN-001'
      and evidence_ref='controlled://SRC-011/scenario/SCN-001';
  exception when others then v_blocked:=true; end;
  if not v_blocked then raise exception 'Candidate evidence record allowed deletion'; end if;
end;
$$;

rollback;
select 'wnf7_evidence_mobilization_contract_passed' as result;
