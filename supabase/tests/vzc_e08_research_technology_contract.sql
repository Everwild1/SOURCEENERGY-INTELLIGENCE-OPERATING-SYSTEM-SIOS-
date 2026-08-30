-- VZC E08 research / technology validation contract smoke assertions
begin;

do $$
declare rb uuid; tb uuid; vr uuid;
begin
  insert into vzc.research_project_bindings(source_schema,source_table,source_record_key,research_role,relationship_state,evidence_reference)
  values ('public','hei_research_projects','vzc-e08-contract','participant','discussion','e:test') returning research_binding_id into rb;

  begin
    update vzc.research_project_bindings set relationship_state='research_active' where research_binding_id=rb;
    raise exception 'expected research_active agreement gate to fail';
  exception when check_violation then null; end;

  insert into vzc.technology_candidate_bindings(source_schema,source_table,source_record_key,candidate_source,evidence_reference)
  values ('public','seg_technology_registry','vzc-e08-contract-tech','nasa_registry','e:test') returning technology_candidate_binding_id into tb;

  begin
    update vzc.technology_candidate_bindings set rights_status='licensed_or_authorized' where technology_candidate_binding_id=tb;
    raise exception 'expected technology rights gate to fail';
  exception when check_violation then null; end;

  insert into vzc.research_validation_records(technology_candidate_binding_id,validation_stage,validation_state,method_reference)
  values (tb,'technical_assessment','planned','method:test') returning validation_record_id into vr;

  begin
    update vzc.research_validation_records set validation_state='passed' where validation_record_id=vr;
    raise exception 'expected validation evidence gate to fail';
  exception when check_violation then null; end;

  begin
    insert into vzc.research_data_access_controls(research_binding_id,data_domain,purpose_reference,access_state,lawful_basis_or_authority_ref)
    values (rb,'person_level','purpose:test','approved','lawful:test');
    raise exception 'expected sensitive research ethics/consent gate to fail';
  exception when check_violation then null; end;

  update vzc.technology_candidate_bindings set rights_status='verified_for_evaluation', rights_reference='rights:test' where technology_candidate_binding_id=tb;
  update vzc.research_validation_records set validation_state='inconclusive', evidence_reference='evidence:test', reviewer_authority_ref='reviewer:test', completed_at=now(), negative_or_null_result=true where validation_record_id=vr;
  insert into vzc.research_findings_return(research_binding_id,validation_record_id,knowledge_state,evidence_reference)
  values (rb,vr,'negative_result','evidence:test');
end $$;

rollback;