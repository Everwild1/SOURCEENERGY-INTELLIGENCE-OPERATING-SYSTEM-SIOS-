-- VZC E07 government / municipal evidence and deployment controls
-- Smoke contract intended to run in a transaction and roll back.
begin;

do $$
declare
  oid uuid;
  rid uuid;
  failed boolean := false;
begin
  insert into vzc.organization_bindings(vzc_subject_type,vzc_subject_key,external_organization_ref,relationship_state)
  values ('government','e07-contract-org','test:municipality','candidate') returning binding_id into oid;

  insert into vzc.government_relationships(organization_binding_id,jurisdiction_ref,relationship_type,relationship_state)
  values (oid,'test-jurisdiction','discussion','discussion') returning government_relationship_id into rid;

  begin
    insert into vzc.government_relationships(organization_binding_id,jurisdiction_ref,relationship_type,relationship_state)
    values (oid,'test-jurisdiction-2','agreement','production_or_contracted');
  exception when check_violation then failed := true;
  end;
  if not failed then raise exception 'E07: unsupported production relationship was accepted'; end if;

  failed := false;
  begin
    insert into vzc.procurement_status_bindings(government_relationship_id,source_schema,source_table,source_record_key,procurement_stage)
    values (rid,'public','test_procurement','1','award');
  exception when check_violation then failed := true;
  end;
  if not failed then raise exception 'E07: procurement award without evidence was accepted'; end if;

  failed := false;
  begin
    insert into vzc.deployment_authorization_gates(government_relationship_id,deployment_scope,deployment_stage)
    values (rid,'test corridor','pilot_approved');
  exception when check_violation then failed := true;
  end;
  if not failed then raise exception 'E07: pilot approval without authority/safety/governance/owner was accepted'; end if;
end $$;

rollback;