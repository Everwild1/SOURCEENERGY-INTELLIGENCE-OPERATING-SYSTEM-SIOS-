create table if not exists pqc.provider_assessments (
  provider_code text primary key,
  provider_name text not null,
  service_name text not null,
  selection_role text not null check (selection_role in ('PRIMARY_PILOT','INTEROPERABILITY_BENCHMARK','ALTERNATE','HOLD')),
  capability_state text not null check (capability_state in ('EVIDENCED','PARTIAL','UNKNOWN','CONFLICTED','EXPIRED')),
  commissioning_state text not null default 'CANDIDATE' check (commissioning_state in ('CANDIDATE','PREFERRED_FOR_PILOT','APPROVED_FOR_PILOT','APPROVED_FOR_PRODUCTION','SUSPENDED','REJECTED')),
  primary_signature_algorithm text references pqc.algorithm_registry(algorithm_code),
  hsm_assurance_claim text,
  hsm_assurance_state text not null default 'UNVERIFIED' check (hsm_assurance_state in ('UNVERIFIED','EVIDENCED','VALIDATED','CONFLICTED','EXPIRED')),
  region_selection text,
  evidence_cutoff_at timestamptz not null,
  review_due date not null,
  assessed_by text not null,
  approved_by text,
  approved_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider_name, service_name),
  check (commissioning_state not in ('APPROVED_FOR_PILOT','APPROVED_FOR_PRODUCTION') or (approved_by is not null and approved_at is not null))
);

create table if not exists pqc.provider_evidence_items (
  evidence_id uuid primary key default gen_random_uuid(),
  provider_code text not null references pqc.provider_assessments(provider_code) on delete cascade,
  evidence_type text not null check (evidence_type in ('OFFICIAL_DOCUMENTATION','RELEASE_NOTE','API_CONTRACT','HSM_ASSURANCE','AVAILABILITY','SECURITY_CONTROL','CERTIFICATION')),
  source_url text not null,
  source_title text not null,
  publisher text not null,
  published_on date,
  observed_at timestamptz not null default now(),
  assertion text not null,
  verification_state text not null check (verification_state in ('OBSERVED','CORROBORATED','VALIDATED','CONFLICTED','EXPIRED')),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (provider_code, source_url, assertion),
  check (source_url ~ '^https://')
);

create table if not exists pqc.provider_selection_decisions (
  decision_id uuid primary key default gen_random_uuid(),
  provider_code text not null references pqc.provider_assessments(provider_code) on delete cascade,
  decision_type text not null check (decision_type in ('PREFER_PILOT','APPROVE_PILOT','APPROVE_PRODUCTION','SUSPEND','REJECT')),
  decision_state text not null check (decision_state in ('RECOMMENDED','APPROVED','REJECTED','REVOKED')),
  decided_by text not null,
  authority_reference text not null,
  rationale_summary text not null,
  evidence_cutoff_at timestamptz not null,
  decided_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (decision_state <> 'APPROVED' or authority_reference <> '')
);

create table if not exists pqc.key_ceremonies (
  ceremony_id uuid primary key default gen_random_uuid(),
  ceremony_code text not null unique,
  provider_code text not null references pqc.provider_assessments(provider_code),
  environment text not null check (environment in ('PILOT','PRODUCTION')),
  algorithm_code text not null references pqc.algorithm_registry(algorithm_code),
  key_purpose text not null,
  planned_region text,
  ceremony_state text not null default 'PLANNED' check (ceremony_state in ('PLANNED','AWAITING_APPROVAL','APPROVED','EXECUTING','COMPLETE','FAILED','CANCELLED','REVOKED')),
  required_approvals smallint not null default 2 check (required_approvals between 2 and 8),
  provider_key_reference text,
  public_key_fingerprint text,
  evidence_reference text,
  scheduled_at timestamptz,
  completed_at timestamptz,
  created_by text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ceremony_state <> 'COMPLETE' or (provider_key_reference is not null and public_key_fingerprint is not null and evidence_reference is not null and completed_at is not null))
);

create table if not exists pqc.key_ceremony_authorizations (
  authorization_id uuid primary key default gen_random_uuid(),
  ceremony_id uuid not null references pqc.key_ceremonies(ceremony_id) on delete cascade,
  decision text not null check (decision in ('APPROVED','REJECTED','REVOKED')),
  authorized_by text not null,
  authority_reference text not null,
  rationale_summary text,
  decided_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists pqc.interoperability_tests (
  test_id uuid primary key default gen_random_uuid(),
  ceremony_id uuid not null references pqc.key_ceremonies(ceremony_id) on delete cascade,
  test_code text not null,
  test_category text not null check (test_category in ('SIGN_VERIFY','TAMPER_REJECTION','WRONG_KEY_REJECTION','EXTERNAL_MU','OFFLINE_VERIFY','REVOCATION','AUDIT_LOG','CROSS_PROVIDER')),
  required boolean not null default true,
  expected_result text not null,
  result text not null default 'PENDING' check (result in ('PENDING','PASSED','FAILED','BLOCKED','EXCEPTION')),
  verification_engine text,
  evidence_reference text,
  run_by text,
  run_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (ceremony_id, test_code),
  check (result = 'PENDING' or (verification_engine is not null and evidence_reference is not null and run_by is not null and run_at is not null))
);

alter table pqc.key_registry
  add column if not exists provider_code text references pqc.provider_assessments(provider_code),
  add column if not exists ceremony_id uuid references pqc.key_ceremonies(ceremony_id),
  add column if not exists assurance_scope text not null default 'PILOT',
  add column if not exists activation_evidence_reference text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='key_registry_assurance_scope_check' and conrelid='pqc.key_registry'::regclass) then
    alter table pqc.key_registry add constraint key_registry_assurance_scope_check check (assurance_scope in ('PILOT','PRODUCTION'));
  end if;
end $$;

create index if not exists provider_evidence_items_provider_idx on pqc.provider_evidence_items(provider_code, verification_state);
create index if not exists provider_selection_decisions_provider_idx on pqc.provider_selection_decisions(provider_code, decided_at desc);
create index if not exists key_ceremonies_provider_idx on pqc.key_ceremonies(provider_code, ceremony_state);
create index if not exists key_ceremony_authorizations_ceremony_idx on pqc.key_ceremony_authorizations(ceremony_id, decided_at desc);
create index if not exists interoperability_tests_ceremony_idx on pqc.interoperability_tests(ceremony_id, required, result);
create index if not exists key_registry_provider_code_idx on pqc.key_registry(provider_code, status);
create index if not exists key_registry_ceremony_id_idx on pqc.key_registry(ceremony_id);

create or replace function pqc.block_provider_governance_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'Provider evidence, selection decisions, and ceremony authorizations are append-only';
end;
$$;

create or replace function pqc.guard_key_registry_activation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_provider pqc.provider_assessments%rowtype;
  v_ceremony pqc.key_ceremonies%rowtype;
  v_approval_count integer;
  v_provider_decision_ok boolean;
begin
  if new.metadata ?| array['private_key','secret_key','seed','mnemonic','key_material','service_role_key'] then
    raise exception 'Private or secret key material is prohibited in the key registry';
  end if;

  if new.status='active' then
    if new.provider_code is null or new.ceremony_id is null or new.public_key_fingerprint is null or new.activation_evidence_reference is null then
      raise exception 'Active keys require provider, ceremony, public fingerprint, and activation evidence references';
    end if;

    select * into v_provider from pqc.provider_assessments where provider_code=new.provider_code;
    if not found then raise exception 'Registered provider assessment is required'; end if;

    if v_provider.commissioning_state not in ('APPROVED_FOR_PILOT','APPROVED_FOR_PRODUCTION') then
      raise exception 'Provider is not approved for key activation';
    end if;

    if new.assurance_scope='PRODUCTION' and v_provider.commissioning_state <> 'APPROVED_FOR_PRODUCTION' then
      raise exception 'Production key activation requires production provider approval';
    end if;

    select exists (
      select 1 from pqc.provider_selection_decisions d
      where d.provider_code=new.provider_code and d.decision_state='APPROVED'
        and ((new.assurance_scope='PILOT' and d.decision_type in ('APPROVE_PILOT','APPROVE_PRODUCTION')) or (new.assurance_scope='PRODUCTION' and d.decision_type='APPROVE_PRODUCTION'))
    ) into v_provider_decision_ok;
    if not v_provider_decision_ok then raise exception 'An append-only provider approval decision is required'; end if;

    select * into v_ceremony from pqc.key_ceremonies where ceremony_id=new.ceremony_id;
    if not found or v_ceremony.ceremony_state <> 'COMPLETE' or v_ceremony.provider_code <> new.provider_code or v_ceremony.algorithm_code <> new.algorithm_code or v_ceremony.environment <> new.assurance_scope or v_ceremony.provider_key_reference <> new.provider_key_reference or v_ceremony.public_key_fingerprint <> new.public_key_fingerprint then
      raise exception 'Completed matching key ceremony evidence is required';
    end if;

    select count(*) into v_approval_count
    from (
      select distinct on (authorized_by) authorized_by, decision
      from pqc.key_ceremony_authorizations
      where ceremony_id=new.ceremony_id
      order by authorized_by, decided_at desc
    ) latest
    where decision='APPROVED';

    if v_approval_count < v_ceremony.required_approvals then
      raise exception 'Key ceremony requires % independent approvals; observed %', v_ceremony.required_approvals, v_approval_count;
    end if;
  end if;
  return new;
end;
$$;

create or replace function pqc.guard_hybrid_profile_activation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_pqc_key_ok boolean;
  v_classical_key_ok boolean;
begin
  if new.status='active' and old.status is distinct from 'active' then
    if coalesce(new.metadata->>'production_release_enabled','false') <> 'true' then
      raise exception 'Production release must be explicitly enabled by governed metadata';
    end if;

    select exists (
      select 1 from pqc.key_registry k
      join pqc.provider_assessments p on p.provider_code=k.provider_code
      join pqc.key_ceremonies c on c.ceremony_id=k.ceremony_id
      where k.status='active' and k.assurance_scope='PRODUCTION' and k.algorithm_code=new.pqc_algorithm_code
        and p.commissioning_state='APPROVED_FOR_PRODUCTION' and c.ceremony_state='COMPLETE'
        and not exists (select 1 from pqc.interoperability_tests t where t.ceremony_id=c.ceremony_id and t.required and t.result <> 'PASSED')
        and exists (select 1 from pqc.interoperability_tests t where t.ceremony_id=c.ceremony_id and t.required)
    ) into v_pqc_key_ok;

    select exists (
      select 1 from pqc.key_registry k
      join pqc.provider_assessments p on p.provider_code=k.provider_code
      join pqc.key_ceremonies c on c.ceremony_id=k.ceremony_id
      where k.status='active' and k.assurance_scope='PRODUCTION' and k.algorithm_code=new.classical_algorithm_code
        and p.commissioning_state='APPROVED_FOR_PRODUCTION' and c.ceremony_state='COMPLETE'
    ) into v_classical_key_ok;

    if not v_pqc_key_ok or not v_classical_key_ok then
      raise exception 'Production hybrid profile activation requires approved production classical and PQC keys plus completed required interoperability tests';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists provider_evidence_items_append_only on pqc.provider_evidence_items;
create trigger provider_evidence_items_append_only before update or delete on pqc.provider_evidence_items for each row execute function pqc.block_provider_governance_mutation();
drop trigger if exists provider_selection_decisions_append_only on pqc.provider_selection_decisions;
create trigger provider_selection_decisions_append_only before update or delete on pqc.provider_selection_decisions for each row execute function pqc.block_provider_governance_mutation();
drop trigger if exists key_ceremony_authorizations_append_only on pqc.key_ceremony_authorizations;
create trigger key_ceremony_authorizations_append_only before update or delete on pqc.key_ceremony_authorizations for each row execute function pqc.block_provider_governance_mutation();
drop trigger if exists key_registry_activation_guard on pqc.key_registry;
create trigger key_registry_activation_guard before insert or update on pqc.key_registry for each row execute function pqc.guard_key_registry_activation();
drop trigger if exists hybrid_profile_activation_guard on pqc.hybrid_profiles;
create trigger hybrid_profile_activation_guard before update of status on pqc.hybrid_profiles for each row execute function pqc.guard_hybrid_profile_activation();

alter table pqc.provider_assessments enable row level security;
alter table pqc.provider_evidence_items enable row level security;
alter table pqc.provider_selection_decisions enable row level security;
alter table pqc.key_ceremonies enable row level security;
alter table pqc.key_ceremony_authorizations enable row level security;
alter table pqc.interoperability_tests enable row level security;

revoke all on table pqc.provider_assessments, pqc.provider_evidence_items, pqc.provider_selection_decisions, pqc.key_ceremonies, pqc.key_ceremony_authorizations, pqc.interoperability_tests from public, anon, authenticated;
grant select, insert, update, delete on table pqc.provider_assessments to service_role;
grant select, insert on table pqc.provider_evidence_items to service_role;
grant select, insert on table pqc.provider_selection_decisions to service_role;
grant select, insert, update, delete on table pqc.key_ceremonies to service_role;
grant select, insert on table pqc.key_ceremony_authorizations to service_role;
grant select, insert, update, delete on table pqc.interoperability_tests to service_role;

create policy provider_assessments_service_role on pqc.provider_assessments for all to service_role using (true) with check (true);
create policy provider_evidence_items_service_select on pqc.provider_evidence_items for select to service_role using (true);
create policy provider_evidence_items_service_insert on pqc.provider_evidence_items for insert to service_role with check (true);
create policy provider_selection_decisions_service_select on pqc.provider_selection_decisions for select to service_role using (true);
create policy provider_selection_decisions_service_insert on pqc.provider_selection_decisions for insert to service_role with check (true);
create policy key_ceremonies_service_role on pqc.key_ceremonies for all to service_role using (true) with check (true);
create policy key_ceremony_authorizations_service_select on pqc.key_ceremony_authorizations for select to service_role using (true);
create policy key_ceremony_authorizations_service_insert on pqc.key_ceremony_authorizations for insert to service_role with check (true);
create policy interoperability_tests_service_role on pqc.interoperability_tests for all to service_role using (true) with check (true);

revoke all on function pqc.block_provider_governance_mutation() from public, anon, authenticated;
revoke all on function pqc.guard_key_registry_activation() from public, anon, authenticated;
revoke all on function pqc.guard_hybrid_profile_activation() from public, anon, authenticated;

insert into pqc.vendor_registry (vendor_name, service_name, service_category, current_crypto_profile, pqc_support_status, supports_ml_kem, supports_ml_dsa, supports_slh_dsa, supports_hybrid, hsm_pqc_support, attestation_reference, evidence_date, review_due, owner_role, notes)
values
  ('Amazon Web Services','AWS KMS','cloud_kms',jsonb_build_object('signature_key_specs',jsonb_build_array('ML_DSA_44','ML_DSA_65','ML_DSA_87'),'signing_algorithm','ML_DSA_SHAKE_256','message_types',jsonb_build_array('RAW','EXTERNAL_MU')),'production',null,true,false,null,true,'https://docs.aws.amazon.com/kms/latest/developerguide/mldsa.html',current_date,current_date+90,'Platform Security','Official documentation evidences ML-DSA signing and FIPS 140-3 Level 3 HSM protection. SourceEnergy account, region, IAM, CloudTrail, billing, and key configuration are not yet verified.'),
  ('Google Cloud','Cloud KMS','cloud_kms',jsonb_build_object('signature_algorithms',jsonb_build_array('PQ_SIGN_ML_DSA_44','PQ_SIGN_ML_DSA_65','PQ_SIGN_ML_DSA_87','PQ_SIGN_SLH_DSA_SHA2_128S'),'availability','general_availability_2026_07_16'),'production',true,true,true,null,null,'https://docs.cloud.google.com/kms/docs/release-notes',current_date,current_date+90,'Platform Security','Official release notes evidence general availability of PQC signing algorithms. Selected protection level, tenancy, IAM, audit logging, billing, and interoperability remain unverified.')
on conflict (vendor_name,service_name) do update set service_category=excluded.service_category,current_crypto_profile=excluded.current_crypto_profile,pqc_support_status=excluded.pqc_support_status,supports_ml_kem=excluded.supports_ml_kem,supports_ml_dsa=excluded.supports_ml_dsa,supports_slh_dsa=excluded.supports_slh_dsa,supports_hybrid=excluded.supports_hybrid,hsm_pqc_support=excluded.hsm_pqc_support,attestation_reference=excluded.attestation_reference,evidence_date=excluded.evidence_date,review_due=excluded.review_due,owner_role=excluded.owner_role,notes=excluded.notes,updated_at=now();

insert into pqc.provider_assessments (provider_code, provider_name, service_name, selection_role, capability_state, commissioning_state, primary_signature_algorithm, hsm_assurance_claim, hsm_assurance_state, region_selection, evidence_cutoff_at, review_due, assessed_by, metadata)
values
  ('AWS_KMS','Amazon Web Services','AWS KMS','PRIMARY_PILOT','EVIDENCED','PREFERRED_FOR_PILOT','ML-DSA-65','AWS documentation states that ML-DSA keys and signing operations are protected in FIPS 140-3 Security Level 3 validated HSMs.','EVIDENCED','TBD — selected region must be verified before ceremony',now(),current_date+90,'CVI-PQ-CGL',jsonb_build_object('recommendation_basis','native ML-DSA API, managed key custody, audit integration, FIPS 140-3 Level 3 HSM claim','account_created',false,'key_created',false,'spend_authorized',false)),
  ('GOOGLE_CLOUD_KMS','Google Cloud','Cloud KMS','INTEROPERABILITY_BENCHMARK','EVIDENCED','CANDIDATE','ML-DSA-65','Protection-level assurance for the selected PQC key configuration has not yet been validated by SourceEnergy.','UNVERIFIED','TBD — selected location and protection level must be verified before testing',now(),current_date+90,'CVI-PQ-CGL',jsonb_build_object('recommendation_basis','independent GA ML-DSA implementation for interoperability testing','account_created',false,'key_created',false,'spend_authorized',false))
on conflict (provider_code) do update set provider_name=excluded.provider_name,service_name=excluded.service_name,selection_role=excluded.selection_role,capability_state=excluded.capability_state,commissioning_state=excluded.commissioning_state,primary_signature_algorithm=excluded.primary_signature_algorithm,hsm_assurance_claim=excluded.hsm_assurance_claim,hsm_assurance_state=excluded.hsm_assurance_state,region_selection=excluded.region_selection,evidence_cutoff_at=excluded.evidence_cutoff_at,review_due=excluded.review_due,assessed_by=excluded.assessed_by,metadata=excluded.metadata,updated_at=now();

insert into pqc.provider_evidence_items (provider_code,evidence_type,source_url,source_title,publisher,published_on,assertion,verification_state,evidence_reference,metadata)
values
  ('AWS_KMS','OFFICIAL_DOCUMENTATION','https://docs.aws.amazon.com/kms/latest/developerguide/mldsa.html','ML-DSA keys in AWS KMS','Amazon Web Services',null,'AWS KMS supports FIPS 204 ML-DSA key specs ML_DSA_44, ML_DSA_65, and ML_DSA_87 for signing and verification.','OBSERVED','AWS-KMS-MLDSA-DOC-2026-08-31',jsonb_build_object('source_class','primary','capability_only',true)),
  ('AWS_KMS','HSM_ASSURANCE','https://docs.aws.amazon.com/kms/latest/developerguide/mldsa.html','ML-DSA keys in AWS KMS','Amazon Web Services',null,'AWS states that ML-DSA keys and signing operations are protected in FIPS 140-3 Security Level 3 validated hardware security modules.','OBSERVED','AWS-KMS-HSM-DOC-2026-08-31',jsonb_build_object('source_class','primary','independent_validation_pending',true)),
  ('AWS_KMS','API_CONTRACT','https://docs.aws.amazon.com/kms/latest/APIReference/API_Sign.html','AWS KMS Sign API','Amazon Web Services',null,'The Sign API supports ML_DSA_SHAKE_256 and RAW or EXTERNAL_MU message types, with RAW messages limited to 4096 bytes.','OBSERVED','AWS-KMS-SIGN-API-2026-08-31',jsonb_build_object('source_class','primary')),
  ('AWS_KMS','RELEASE_NOTE','https://aws.amazon.com/about-aws/whats-new/2025/06/aws-kms-post-quantum-ml-dsa-digital-signatures/','AWS KMS adds support for post-quantum ML-DSA digital signatures','Amazon Web Services','2025-06-13','AWS announced general availability of FIPS 204 ML-DSA signing integrated with existing KMS CreateKey and Sign APIs.','CORROBORATED','AWS-KMS-GA-2025-06-13',jsonb_build_object('source_class','primary','region_availability_must_be_rechecked',true)),
  ('GOOGLE_CLOUD_KMS','RELEASE_NOTE','https://docs.cloud.google.com/kms/docs/release-notes','Cloud KMS release notes','Google Cloud','2026-07-16','Google Cloud KMS lists ML-DSA-44, ML-DSA-65, ML-DSA-87, External Mu variants, and SLH-DSA signing algorithms as generally available.','OBSERVED','GCP-KMS-PQC-GA-2026-07-16',jsonb_build_object('source_class','primary')),
  ('GOOGLE_CLOUD_KMS','OFFICIAL_DOCUMENTATION','https://cloud.google.com/blog/products/identity-security/future-proofing-data-integrity-quantum-safe-digital-signatures-in-cloud-kms','Future-proofing data integrity: Quantum-safe digital signatures in Cloud KMS','Google Cloud','2026-07-28','Google Cloud announced general availability of ML-DSA, SLH-DSA, and ML-KEM capabilities in Cloud KMS.','CORROBORATED','GCP-KMS-PQC-BLOG-2026-07-28',jsonb_build_object('source_class','primary','protection_level_verification_pending',true))
on conflict (provider_code,source_url,assertion) do nothing;

insert into pqc.provider_selection_decisions (provider_code,decision_type,decision_state,decided_by,authority_reference,rationale_summary,evidence_cutoff_at,metadata)
select 'AWS_KMS','PREFER_PILOT','RECOMMENDED','CVI-PQ-CGL-EVIDENCE-REVIEW','PROVIDER-REVIEW-2026-08-31','AWS KMS is recommended as the primary non-production ML-DSA-65 pilot candidate because official documentation evidences native ML-DSA Sign/Verify APIs and FIPS 140-3 Level 3 HSM protection. This is a recommendation, not spend, account, key, or production approval.',now(),jsonb_build_object('human_approval_required',true,'production_approval',false)
where not exists (select 1 from pqc.provider_selection_decisions where provider_code='AWS_KMS' and decision_type='PREFER_PILOT' and authority_reference='PROVIDER-REVIEW-2026-08-31');

insert into pqc.key_ceremonies (ceremony_code,provider_code,environment,algorithm_code,key_purpose,planned_region,ceremony_state,required_approvals,created_by,metadata)
values ('AWS-KMS-MLDSA65-PILOT-001','AWS_KMS','PILOT','ML-DSA-65','Detached post-quantum signature component for CVI Open Scroll and due-diligence evidence-envelope interoperability testing','TBD','PLANNED',2,'CVI-PQ-CGL',jsonb_build_object('account_authorization_required',true,'cost_authorization_required',true,'iam_design_required',true,'cloudtrail_evidence_required',true,'private_key_export_prohibited',true,'key_created',false))
on conflict (ceremony_code) do update set provider_code=excluded.provider_code,environment=excluded.environment,algorithm_code=excluded.algorithm_code,key_purpose=excluded.key_purpose,planned_region=excluded.planned_region,required_approvals=excluded.required_approvals,metadata=excluded.metadata,updated_at=now();

insert into pqc.interoperability_tests (ceremony_id,test_code,test_category,required,expected_result,metadata)
select c.ceremony_id,v.test_code,v.test_category,v.required,v.expected_result,v.metadata
from pqc.key_ceremonies c
cross join lateral (values
  ('AWS-MLDSA65-RAW-SIGN-VERIFY','SIGN_VERIFY',true,'A RAW payload of 4096 bytes or less signs and verifies with the registered ML-DSA-65 public key.',jsonb_build_object('message_type','RAW')),
  ('AWS-MLDSA65-EXTERNAL-MU','EXTERNAL_MU',true,'A correctly computed 64-byte external mu signs and verifies for a larger canonical payload.',jsonb_build_object('message_type','EXTERNAL_MU')),
  ('AWS-MLDSA65-OFFLINE-VERIFY','OFFLINE_VERIFY',true,'The exported public key verifies the detached signature in an independent verifier.',jsonb_build_object('private_key_export',false)),
  ('AWS-MLDSA65-TAMPER-REJECT','TAMPER_REJECTION',true,'Any canonical payload modification causes verification failure.',jsonb_build_object('negative_test',true)),
  ('AWS-MLDSA65-WRONG-KEY-REJECT','WRONG_KEY_REJECTION',true,'Verification with a non-matching public key fails.',jsonb_build_object('negative_test',true)),
  ('AWS-MLDSA65-REVOKE-DISABLE','REVOCATION',true,'Key disable or revocation prevents new signatures and produces auditable evidence.',jsonb_build_object('recovery_runbook_required',true)),
  ('AWS-MLDSA65-AUDIT-RECEIPT','AUDIT_LOG',true,'Key creation, policy changes, Sign, Verify, disable, and deletion scheduling produce attributable audit events.',jsonb_build_object('cloudtrail_expected',true)),
  ('AWS-GCP-MLDSA65-CROSS-VERIFY','CROSS_PROVIDER',false,'An AWS-generated signature is independently verified outside AWS and compared against a Google Cloud KMS ML-DSA-65 test vector workflow.',jsonb_build_object('secondary_provider','GOOGLE_CLOUD_KMS'))
) as v(test_code,test_category,required,expected_result,metadata)
where c.ceremony_code='AWS-KMS-MLDSA65-PILOT-001'
on conflict (ceremony_id,test_code) do update set test_category=excluded.test_category,required=excluded.required,expected_result=excluded.expected_result,metadata=excluded.metadata,updated_at=now();

create or replace view pqc.provider_commissioning_status with (security_invoker=true) as
select
  (select count(*) from pqc.provider_assessments) as assessed_providers,
  (select count(*) from pqc.provider_assessments where commissioning_state='PREFERRED_FOR_PILOT') as preferred_pilot_providers,
  (select count(*) from pqc.provider_assessments where commissioning_state='APPROVED_FOR_PILOT') as approved_pilot_providers,
  (select count(*) from pqc.provider_assessments where commissioning_state='APPROVED_FOR_PRODUCTION') as approved_production_providers,
  (select count(*) from pqc.provider_evidence_items where verification_state in ('OBSERVED','CORROBORATED','VALIDATED')) as current_evidence_items,
  (select count(*) from pqc.key_ceremonies where ceremony_state='PLANNED') as planned_ceremonies,
  (select count(*) from pqc.key_ceremonies where ceremony_state='COMPLETE') as completed_ceremonies,
  (select count(*) from pqc.interoperability_tests where required and result='PENDING') as required_tests_pending,
  (select count(*) from pqc.interoperability_tests where required and result='PASSED') as required_tests_passed,
  (select count(*) from pqc.key_registry where status='active' and algorithm_code in ('ML-DSA-65','ML-DSA','SLH-DSA')) as active_pqc_keys,
  case
    when (select count(*) from pqc.provider_assessments where commissioning_state='APPROVED_FOR_PRODUCTION') > 0 and (select count(*) from pqc.key_ceremonies where ceremony_state='COMPLETE' and environment='PRODUCTION') > 0 and (select count(*) from pqc.interoperability_tests where required and result <> 'PASSED') = 0 and (select count(*) from pqc.key_registry where status='active' and assurance_scope='PRODUCTION' and algorithm_code in ('ML-DSA-65','ML-DSA','SLH-DSA')) > 0 then 'PRODUCTION_COMMISSIONING_EVIDENCED'
    when (select count(*) from pqc.provider_assessments where commissioning_state='APPROVED_FOR_PILOT') > 0 then 'PILOT_APPROVED_AWAITING_CEREMONY_OR_TESTS'
    when (select count(*) from pqc.provider_assessments where commissioning_state='PREFERRED_FOR_PILOT') > 0 then 'PROVIDER_PREFERRED_AWAITING_HUMAN_APPROVAL'
    else 'PROVIDER_DISCOVERY'
  end as commissioning_label;

revoke all on table pqc.provider_commissioning_status from public, anon, authenticated;
grant select on table pqc.provider_commissioning_status to service_role;

insert into pqc.governance_recommendations (assessment_id,recommendation_code,recommendation_type,priority,recommendation_text,rationale,evidence_reference,requires_human_authorization,governance_gate,decision_status,metadata)
select a.id,'QRI-PROVIDER-PILOT-001','PROVIDER_COMMISSIONING',95,'Authorize a bounded non-production AWS KMS ML-DSA-65 pilot only after account ownership, selected region, cost boundary, IAM design, logging, two independent ceremony approvers, and evidence-retention controls are confirmed.','Official AWS documentation supports the technical capability, but SourceEnergy tenant configuration, access authority, operational costs, and key ceremony evidence remain unverified.','pqc.provider_assessments/AWS_KMS',true,'Q9','pending',jsonb_build_object('recommended_provider','AWS_KMS','secondary_interoperability_provider','GOOGLE_CLOUD_KMS','no_key_created',true)
from pqc.readiness_assessments a where a.assessment_code='QRI-BASELINE-2026-08-26'
on conflict (recommendation_code) do update set recommendation_text=excluded.recommendation_text,rationale=excluded.rationale,evidence_reference=excluded.evidence_reference,priority=excluded.priority,metadata=excluded.metadata,updated_at=now();

update pqc.readiness_assessments set metadata=metadata || jsonb_build_object('primary_pilot_provider_candidate','AWS_KMS','interoperability_benchmark_candidate','GOOGLE_CLOUD_KMS','provider_human_approval_recorded',false,'key_ceremony_completed',false,'operational_pqc_keys_registered',false,'production_release_enabled',false),updated_at=now() where assessment_code='QRI-BASELINE-2026-08-26';

update public.cvi_interface_config set version_label='Tier III+ — DPOT + PQC Provider Commissioning',operational_definition='LIVE means the SourceEnergy command backend is reachable and the CVI/DPOT/PQ-CGL control planes record evidence-backed state. AWS KMS is the preferred non-production ML-DSA-65 pilot candidate and Google Cloud KMS is the interoperability benchmark. No provider approval, cloud account authority, spend authorization, key ceremony, active PQC key, valid PQC signature envelope, production profile, or end-to-end PQC status is inferred.',updated_at=now() where config_key='primary';

comment on table pqc.provider_assessments is 'Evidence-backed provider assessment and commissioning state. Preferred is not approved; approved requires accountable human authority.';
comment on table pqc.provider_evidence_items is 'Append-only primary-source evidence supporting provider capabilities and assurance claims.';
comment on table pqc.provider_selection_decisions is 'Append-only provider recommendations and accountable approvals. Recommendation does not authorize spend or key creation.';
comment on table pqc.key_ceremonies is 'Governed key-ceremony plan and evidence. No private key material may be stored.';
comment on table pqc.interoperability_tests is 'Required positive and negative cryptographic interoperability tests before production activation.';
comment on function pqc.guard_key_registry_activation() is 'Blocks active key registration unless provider approval, completed matching ceremony, independent approvals, fingerprint, and evidence references are present.';
comment on function pqc.guard_hybrid_profile_activation() is 'Blocks production profile activation until approved production keys and required interoperability tests are evidenced.';