begin;
do $$
declare v_count integer; v_blocked boolean; v_decision uuid; v_evidence uuid; v_readiness text;
begin
  select count(*) into v_count from wnf7.dimension_registry;
  if v_count<>7 then raise exception 'Expected 7 dimensions; observed %',v_count; end if;
  select count(*) into v_count from wnf7.component_profiles;
  if v_count<>8 then raise exception 'Expected 8 component profiles; observed %',v_count; end if;
  select count(*) into v_count from wnf7.component_dimension_controls;
  if v_count<>56 then raise exception 'Expected 56 component controls; observed %',v_count; end if;
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
