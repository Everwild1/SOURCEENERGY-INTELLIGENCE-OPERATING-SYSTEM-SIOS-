begin;

do $$
declare
  v_open_scroll_id uuid;
  v_org_id uuid;
  v_individual_id uuid;
  v_eval jsonb;
  v_gate jsonb;
  v_gate_event_id uuid;
  v_blocked boolean;
  v_status text;
  v_count integer;
begin
  if to_regclass('pqc.hybrid_profiles') is null
     or to_regclass('pqc.protection_templates') is null
     or to_regclass('evidence.protected_objects') is null
     or to_regclass('evidence.hybrid_signature_components') is null
     or to_regclass('evidence.human_authorizations') is null
     or to_regclass('evidence.protection_gate_events') is null then
    raise exception 'PQC hybrid evidence objects are incomplete';
  end if;

  select status_label into v_status from pqc.operational_pqc_status;
  if v_status <> 'PQC_GOVERNED_NOT_YET_PQC_ENFORCED' then
    raise exception 'Unexpected operational PQC posture: %', v_status;
  end if;

  select count(*) into v_count
  from pqc.hybrid_profiles
  where profile_code='HYB-Q3-ECDSA-P256-MLDSA65-V1'
    and status='pilot'
    and classical_algorithm_code='ECDSA-P256-SHA256'
    and pqc_algorithm_code='ML-DSA-65'
    and digest_algorithm_code='SHA-384';
  if v_count <> 1 then
    raise exception 'Hybrid pilot profile contract failed';
  end if;

  if exists (
    select 1 from pqc.key_registry
    where status='active' and algorithm_code in ('ML-DSA-65','ML-DSA','SLH-DSA')
  ) then
    raise exception 'Clean pilot unexpectedly contains active PQC keys';
  end if;

  if exists (
    select 1 from evidence.signature_envelopes
    where verification_status='valid' and signature_algorithm in ('ML-DSA-65','ML-DSA','SLH-DSA')
  ) then
    raise exception 'Clean pilot unexpectedly contains valid PQC signatures';
  end if;

  select id into v_open_scroll_id
  from evidence.protected_objects
  where object_type='CVI_OPEN_SCROLL'
    and metadata->>'trace_id'='CV-ENTRY-002'
  order by created_at
  limit 1;

  if v_open_scroll_id is null then
    raise exception 'CV-ENTRY-002 protected Open Scroll was not registered';
  end if;

  if (select protection_state from evidence.protected_objects where id=v_open_scroll_id) <> 'HASHED' then
    raise exception 'CV-ENTRY-002 protected Open Scroll is not HASHED';
  end if;

  select pqc.evaluate_protected_object(v_open_scroll_id,'PILOT_VERIFIED') into v_eval;
  if (v_eval->>'allowed')::boolean then
    raise exception 'Unsigned Open Scroll unexpectedly passed the hybrid gate';
  end if;
  if not (v_eval->'reasons' ? 'CLASSICAL_SIGNATURE_COMPONENT_MISSING_OR_UNVERIFIED')
     or not (v_eval->'reasons' ? 'PQC_SIGNATURE_COMPONENT_MISSING_OR_UNVERIFIED')
     or not (v_eval->'reasons' ? 'ACCOUNTABLE_HUMAN_AUTHORIZATION_MISSING') then
    raise exception 'Open Scroll block reasons are incomplete: %', v_eval->'reasons';
  end if;

  select pqc.request_protected_object_transition(
    v_open_scroll_id,
    'PILOT_VERIFIED',
    'PQC-CONTRACT-TEST',
    'pqc-contract-negative-gate-001'
  ) into v_gate;

  if v_gate->>'decision' <> 'BLOCK' or (v_gate->>'state_changed')::boolean then
    raise exception 'Negative transition gate did not block';
  end if;

  if (select protection_state from evidence.protected_objects where id=v_open_scroll_id) <> 'HASHED' then
    raise exception 'Blocked transition changed the protected-object state';
  end if;

  v_blocked := false;
  begin
    update evidence.protected_objects
    set protection_state='PILOT_VERIFIED'
    where id=v_open_scroll_id;
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Direct protected-object state mutation was not blocked';
  end if;

  select event_id into v_gate_event_id
  from evidence.protection_gate_events
  where correlation_id='pqc-contract-negative-gate-001';

  v_blocked := false;
  begin
    update evidence.protection_gate_events
    set reasons='[]'::jsonb
    where event_id=v_gate_event_id;
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Protection gate event mutation was not blocked';
  end if;

  v_blocked := false;
  begin
    perform pqc.register_protected_object(
      'ORGANIZATION_DD_REPORT','SYNTHETIC-ORG-NO-RETENTION','1',repeat('d',96),'SHA-384',
      'case://synthetic/org-negative','Synthetic organization DD contract test',
      null,null,null,true,'PQC-CONTRACT-TEST',jsonb_build_object('synthetic',true)
    );
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Organization DD without retention limit was not blocked';
  end if;

  v_org_id := pqc.register_protected_object(
    'ORGANIZATION_DD_REPORT','SYNTHETIC-ORG-POSITIVE','1',repeat('e',96),'SHA-384',
    'case://synthetic/org-positive','Synthetic organization DD contract test',
    null,null,now()+interval '30 days',true,'PQC-CONTRACT-TEST',
    jsonb_build_object('synthetic',true,'payload_copied',false)
  );

  select pqc.evaluate_protected_object(v_org_id,'PILOT_VERIFIED') into v_eval;
  if (v_eval->>'allowed')::boolean
     or not (v_eval->'reasons' ? 'PQC_SIGNATURE_COMPONENT_MISSING_OR_UNVERIFIED') then
    raise exception 'Unsigned organization DD did not remain blocked';
  end if;

  v_blocked := false;
  begin
    perform pqc.register_protected_object(
      'INDIVIDUAL_DD_REPORT','SYNTHETIC-IND-NO-BASIS','1',repeat('a',96),'SHA-384',
      'case://synthetic/individual-negative','Synthetic individual DD contract test',
      null,null,now()+interval '30 days',true,'PQC-CONTRACT-TEST','{}'::jsonb
    );
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Individual DD without lawful basis was not blocked';
  end if;

  v_blocked := false;
  begin
    perform pqc.register_protected_object(
      'INDIVIDUAL_DD_REPORT','SYNTHETIC-IND-PII','1',repeat('b',96),'SHA-384',
      'case://synthetic/individual-pii','Synthetic individual DD contract test',
      'CONSENT_OR_LEGAL_AUTHORITY','AUTH-SYNTHETIC-001',now()+interval '30 days',true,
      'PQC-CONTRACT-TEST',jsonb_build_object('ssn','000-00-0000')
    );
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Sensitive individual DD metadata was not blocked';
  end if;

  v_individual_id := pqc.register_protected_object(
    'INDIVIDUAL_DD_REPORT','SYNTHETIC-IND-POSITIVE','1',repeat('c',96),'SHA-384',
    'case://synthetic/individual-positive','Synthetic individual DD contract test',
    'CONSENT_OR_LEGAL_AUTHORITY','AUTH-SYNTHETIC-002',now()+interval '30 days',true,
    'PQC-CONTRACT-TEST',jsonb_build_object('payload_copied',false,'synthetic',true)
  );

  select pqc.evaluate_protected_object(v_individual_id,'PILOT_VERIFIED') into v_eval;
  if (v_eval->>'allowed')::boolean
     or not (v_eval->'reasons' ? 'PQC_SIGNATURE_COMPONENT_MISSING_OR_UNVERIFIED')
     or not (v_eval->'reasons' ? 'ACCOUNTABLE_HUMAN_AUTHORIZATION_MISSING') then
    raise exception 'Unsigned individual DD did not remain blocked';
  end if;

  if has_schema_privilege('anon','pqc','USAGE')
     or has_schema_privilege('authenticated','pqc','USAGE')
     or has_schema_privilege('anon','evidence','USAGE')
     or has_schema_privilege('authenticated','evidence','USAGE') then
    raise exception 'Client role unexpectedly has PQC/evidence schema usage';
  end if;
end;
$$;

rollback;

select 'pqc_hybrid_evidence_pilot_contract_passed' as result;
