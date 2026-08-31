begin;

do $$
declare
  v_label text;
  v_count integer;
  v_blocked boolean;
  v_ceremony_id uuid;
begin
  if to_regclass('pqc.provider_assessments') is null
     or to_regclass('pqc.provider_evidence_items') is null
     or to_regclass('pqc.provider_selection_decisions') is null
     or to_regclass('pqc.key_ceremonies') is null
     or to_regclass('pqc.key_ceremony_authorizations') is null
     or to_regclass('pqc.interoperability_tests') is null then
    raise exception 'Provider commissioning control-plane objects are incomplete';
  end if;

  select commissioning_label into v_label
  from pqc.provider_commissioning_status;

  if v_label <> 'PROVIDER_PREFERRED_AWAITING_HUMAN_APPROVAL' then
    raise exception 'Unexpected commissioning label: %', v_label;
  end if;

  select count(*) into v_count
  from pqc.provider_assessments
  where provider_code in ('AWS_KMS','GOOGLE_CLOUD_KMS');

  if v_count <> 2 then
    raise exception 'Expected two assessed provider candidates; observed %', v_count;
  end if;

  select count(*) into v_count
  from pqc.provider_assessments
  where commissioning_state in ('APPROVED_FOR_PILOT','APPROVED_FOR_PRODUCTION');

  if v_count <> 0 then
    raise exception 'No provider should be approved before accountable authorization';
  end if;

  select count(*) into v_count
  from pqc.provider_evidence_items
  where provider_code='AWS_KMS'
    and verification_state in ('OBSERVED','CORROBORATED','VALIDATED');

  if v_count < 4 then
    raise exception 'AWS provider evidence is incomplete; observed % items', v_count;
  end if;

  select ceremony_id into v_ceremony_id
  from pqc.key_ceremonies
  where ceremony_code='AWS-KMS-MLDSA65-PILOT-001';

  if v_ceremony_id is null then
    raise exception 'Planned AWS ML-DSA-65 ceremony is missing';
  end if;

  select count(*) into v_count
  from pqc.interoperability_tests
  where ceremony_id=v_ceremony_id and required;

  if v_count <> 7 then
    raise exception 'Expected seven required interoperability tests; observed %', v_count;
  end if;

  if exists (
    select 1
    from pqc.interoperability_tests
    where ceremony_id=v_ceremony_id
      and required
      and result <> 'PENDING'
  ) then
    raise exception 'Required interoperability tests must remain pending before the ceremony';
  end if;

  v_blocked := false;
  begin
    insert into pqc.key_registry (
      logical_owner,
      purpose,
      algorithm_code,
      provider,
      provider_key_reference,
      public_key_fingerprint,
      status,
      provider_code,
      ceremony_id,
      assurance_scope,
      activation_evidence_reference,
      metadata
    ) values (
      'PQC-CONTRACT-TEST',
      'Negative provider-activation test',
      'ML-DSA-65',
      'AWS KMS',
      'arn:aws:kms:synthetic',
      repeat('a',96),
      'active',
      'AWS_KMS',
      v_ceremony_id,
      'PILOT',
      'synthetic://activation-evidence',
      jsonb_build_object('synthetic',true)
    );
  exception when others then
    v_blocked := true;
  end;

  if not v_blocked then
    raise exception 'Unapproved provider or incomplete ceremony allowed active-key registration';
  end if;

  v_blocked := false;
  begin
    update pqc.hybrid_profiles
    set status='active',
        metadata=metadata || jsonb_build_object('production_release_enabled',true)
    where profile_code='HYB-Q3-ECDSA-P256-MLDSA65-V1';
  exception when others then
    v_blocked := true;
  end;

  if not v_blocked then
    raise exception 'Production hybrid profile activation was not blocked';
  end if;

  v_blocked := false;
  begin
    update pqc.provider_evidence_items
    set assertion='mutated'
    where evidence_id=(select evidence_id from pqc.provider_evidence_items limit 1);
  exception when others then
    v_blocked := true;
  end;

  if not v_blocked then
    raise exception 'Append-only provider evidence was mutable';
  end if;

  v_blocked := false;
  begin
    update pqc.provider_selection_decisions
    set rationale_summary='mutated'
    where decision_id=(select decision_id from pqc.provider_selection_decisions limit 1);
  exception when others then
    v_blocked := true;
  end;

  if not v_blocked then
    raise exception 'Append-only provider decision was mutable';
  end if;

  if has_schema_privilege('anon','pqc','USAGE')
     or has_schema_privilege('authenticated','pqc','USAGE') then
    raise exception 'Client role unexpectedly has PQC schema access';
  end if;

  if (select status_label from pqc.operational_pqc_status)
       <> 'PQC_GOVERNED_NOT_YET_PQC_ENFORCED' then
    raise exception 'Operational PQC posture was overstated';
  end if;

  if exists (
    select 1 from pqc.key_registry
    where status='active'
      and algorithm_code in ('ML-DSA-65','ML-DSA','SLH-DSA')
  ) then
    raise exception 'No active PQC key should exist in the commissioning baseline';
  end if;
end;
$$;

rollback;

select 'pqc_provider_commissioning_contract_passed' as result;
