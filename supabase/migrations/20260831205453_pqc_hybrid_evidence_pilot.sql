do $$
begin
  if to_regclass('pqc.algorithm_registry') is null
     or to_regclass('pqc.crypto_policies') is null
     or to_regclass('pqc.key_registry') is null
     or to_regclass('pqc.verification_events') is null
     or to_regclass('evidence.signature_envelopes') is null then
    raise exception 'PQ-CGL prerequisite objects are missing';
  end if;
end $$;

insert into pqc.algorithm_registry (
  algorithm_code, standard, function_type, security_status,
  minimum_parameter_set, implementation_profile, authority_source, governance_status
)
values
  (
    'SHA-384', 'FIPS 180-4', 'hash', 'approved', 'SHA-384',
    jsonb_build_object('digest_bits',384,'encoding','hex'),
    'NIST', 'active'
  ),
  (
    'ECDSA-P256-SHA256', 'FIPS 186-5', 'digital_signature', 'transition', 'P-256',
    jsonb_build_object('digest','SHA-256','role','classical_hybrid_component','post_quantum_secure',false),
    'NIST / SourceEnergy transition profile', 'active'
  ),
  (
    'ML-DSA-65', 'FIPS 204', 'digital_signature', 'approved', 'ML-DSA-65',
    jsonb_build_object('role','post_quantum_signature_component','standardized',true),
    'NIST', 'active'
  )
on conflict (algorithm_code) do update set
  standard=excluded.standard,
  function_type=excluded.function_type,
  security_status=excluded.security_status,
  minimum_parameter_set=excluded.minimum_parameter_set,
  implementation_profile=excluded.implementation_profile,
  authority_source=excluded.authority_source,
  governance_status=excluded.governance_status,
  updated_at=now();

create table if not exists pqc.hybrid_profiles (
  profile_code text primary key,
  profile_name text not null,
  classical_algorithm_code text not null references pqc.algorithm_registry(algorithm_code),
  pqc_algorithm_code text not null references pqc.algorithm_registry(algorithm_code),
  digest_algorithm_code text not null references pqc.algorithm_registry(algorithm_code),
  minimum_classical_components smallint not null default 1 check (minimum_classical_components between 1 and 8),
  minimum_pqc_components smallint not null default 1 check (minimum_pqc_components between 1 and 8),
  require_active_keys boolean not null default true,
  require_external_verifier boolean not null default true,
  require_human_authorization boolean not null default true,
  allowed_object_types text[] not null default '{}'::text[],
  status text not null default 'pilot' check (status in ('pilot','active','suspended','retired')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (classical_algorithm_code <> pqc_algorithm_code)
);

create table if not exists pqc.protection_templates (
  object_type text primary key,
  subject_class text not null check (subject_class in ('ORGANIZATION','INDIVIDUAL','TRANSACTION','SYSTEM','IP','OTHER')),
  policy_code text not null references pqc.crypto_policies(policy_code),
  hybrid_profile_code text not null references pqc.hybrid_profiles(profile_code),
  default_data_classification text not null check (default_data_classification in ('INTERNAL','CONFIDENTIAL','RESTRICTED','HIGHLY_RESTRICTED')),
  require_lawful_basis boolean not null default false,
  require_minimum_necessary boolean not null default true,
  require_retention_limit boolean not null default false,
  enabled boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table evidence.signature_envelopes
  add column if not exists key_id uuid,
  add column if not exists signature_encoding text not null default 'base64',
  add column if not exists canonicalization_method text not null default 'detached-payload-v1',
  add column if not exists verified_at timestamptz,
  add column if not exists verification_evidence_reference text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname='signature_envelopes_key_id_fkey'
      and conrelid='evidence.signature_envelopes'::regclass
  ) then
    alter table evidence.signature_envelopes
      add constraint signature_envelopes_key_id_fkey
      foreign key (key_id) references pqc.key_registry(key_id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname='signature_envelopes_digest_algorithm_fkey'
      and conrelid='evidence.signature_envelopes'::regclass
  ) then
    alter table evidence.signature_envelopes
      add constraint signature_envelopes_digest_algorithm_fkey
      foreign key (digest_algorithm) references pqc.algorithm_registry(algorithm_code);
  end if;

  if not exists (
    select 1 from pg_constraint where conname='signature_envelopes_signature_algorithm_fkey'
      and conrelid='evidence.signature_envelopes'::regclass
  ) then
    alter table evidence.signature_envelopes
      add constraint signature_envelopes_signature_algorithm_fkey
      foreign key (signature_algorithm) references pqc.algorithm_registry(algorithm_code);
  end if;

  if not exists (
    select 1 from pg_constraint where conname='signature_envelopes_encoding_check'
      and conrelid='evidence.signature_envelopes'::regclass
  ) then
    alter table evidence.signature_envelopes
      add constraint signature_envelopes_encoding_check
      check (signature_encoding in ('base64','base64url','hex'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname='signature_envelopes_valid_receipt_check'
      and conrelid='evidence.signature_envelopes'::regclass
  ) then
    alter table evidence.signature_envelopes
      add constraint signature_envelopes_valid_receipt_check
      check (
        verification_status <> 'valid'
        or (
          key_id is not null
          and public_key_reference is not null
          and verification_engine is not null
          and verified_at is not null
          and verification_evidence_reference is not null
        )
      );
  end if;
end $$;

create index if not exists signature_envelopes_key_id_idx
  on evidence.signature_envelopes(key_id);

create table if not exists evidence.protected_objects (
  id uuid primary key default gen_random_uuid(),
  object_type text not null references pqc.protection_templates(object_type),
  object_id text not null,
  object_version text not null default '1',
  object_digest text not null,
  digest_algorithm text not null references pqc.algorithm_registry(algorithm_code),
  policy_id uuid not null references pqc.crypto_policies(id),
  hybrid_profile_code text not null references pqc.hybrid_profiles(profile_code),
  subject_class text not null check (subject_class in ('ORGANIZATION','INDIVIDUAL','TRANSACTION','SYSTEM','IP','OTHER')),
  data_classification text not null check (data_classification in ('INTERNAL','CONFIDENTIAL','RESTRICTED','HIGHLY_RESTRICTED')),
  content_reference text not null,
  processing_purpose text not null,
  lawful_basis_code text,
  authority_reference text,
  retention_until timestamptz,
  minimum_necessary_attested boolean not null default false,
  protection_state text not null default 'DRAFT' check (protection_state in ('DRAFT','HASHED','SIGNING','PILOT_VERIFIED','RELEASE_READY','BLOCKED','RETIRED')),
  created_by text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (object_type, object_id, object_version),
  check (object_digest ~ '^[0-9A-Fa-f]{64}$|^[0-9A-Fa-f]{96}$|^[0-9A-Fa-f]{128}$'),
  check (retention_until is null or retention_until > created_at),
  check (
    subject_class <> 'INDIVIDUAL'
    or (
      lawful_basis_code is not null
      and authority_reference is not null
      and retention_until is not null
      and minimum_necessary_attested
    )
  )
);

create table if not exists evidence.hybrid_signature_components (
  component_id uuid primary key default gen_random_uuid(),
  protected_object_id uuid not null references evidence.protected_objects(id) on delete cascade,
  signature_envelope_id uuid not null unique references evidence.signature_envelopes(id) on delete cascade,
  component_role text not null check (component_role in ('CLASSICAL','PQC')),
  required boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (protected_object_id, component_role, signature_envelope_id)
);

create table if not exists evidence.human_authorizations (
  authorization_id uuid primary key default gen_random_uuid(),
  protected_object_id uuid not null references evidence.protected_objects(id) on delete cascade,
  authorization_type text not null check (authorization_type in ('PILOT_APPROVAL','RELEASE','REVOKE','EXCEPTION')),
  decision text not null check (decision in ('PENDING','APPROVED','REJECTED','REVOKED','EXPIRED')),
  authorized_by text not null,
  authority_reference text not null,
  rationale_summary text,
  evidence_reference text,
  decided_at timestamptz,
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (decision <> 'APPROVED' or decided_at is not null),
  check (expires_at is null or decided_at is null or expires_at > decided_at)
);

create table if not exists evidence.protection_gate_events (
  event_id uuid primary key default gen_random_uuid(),
  protected_object_id uuid not null references evidence.protected_objects(id) on delete cascade,
  prior_state text not null,
  requested_state text not null,
  decision text not null check (decision in ('PASS','BLOCK')),
  reasons jsonb not null default '[]'::jsonb,
  evaluation_snapshot jsonb not null default '{}'::jsonb,
  evaluated_by text not null,
  correlation_id text not null unique,
  evaluated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists protected_objects_state_idx
  on evidence.protected_objects(protection_state, object_type);
create index if not exists protected_objects_digest_idx
  on evidence.protected_objects(digest_algorithm, object_digest);
create index if not exists hybrid_signature_components_object_idx
  on evidence.hybrid_signature_components(protected_object_id, component_role);
create index if not exists human_authorizations_object_idx
  on evidence.human_authorizations(protected_object_id, authorization_type, decision);
create index if not exists protection_gate_events_object_idx
  on evidence.protection_gate_events(protected_object_id, evaluated_at desc);

insert into pqc.hybrid_profiles (
  profile_code, profile_name, classical_algorithm_code, pqc_algorithm_code,
  digest_algorithm_code, minimum_classical_components, minimum_pqc_components,
  require_active_keys, require_external_verifier, require_human_authorization,
  allowed_object_types, status, metadata
)
values (
  'HYB-Q3-ECDSA-P256-MLDSA65-V1',
  'Q3 Hybrid Evidence Signature — ECDSA P-256 + ML-DSA-65',
  'ECDSA-P256-SHA256', 'ML-DSA-65', 'SHA-384', 1, 1,
  true, true, true,
  array['CVI_OPEN_SCROLL','DPOT_TRACE_RUN','ORGANIZATION_DD_REPORT','INDIVIDUAL_DD_REPORT','HIGH_VALUE_AUTHORIZATION','IP_PROVENANCE'],
  'pilot',
  jsonb_build_object(
    'production_release_enabled',false,
    'cryptographic_execution','external_kms_hsm_or_verified_signer_required',
    'database_role','orchestration_evidence_and_gate_enforcement_only'
  )
)
on conflict (profile_code) do update set
  profile_name=excluded.profile_name,
  classical_algorithm_code=excluded.classical_algorithm_code,
  pqc_algorithm_code=excluded.pqc_algorithm_code,
  digest_algorithm_code=excluded.digest_algorithm_code,
  minimum_classical_components=excluded.minimum_classical_components,
  minimum_pqc_components=excluded.minimum_pqc_components,
  require_active_keys=excluded.require_active_keys,
  require_external_verifier=excluded.require_external_verifier,
  require_human_authorization=excluded.require_human_authorization,
  allowed_object_types=excluded.allowed_object_types,
  status=excluded.status,
  metadata=excluded.metadata,
  updated_at=now();

insert into pqc.protection_templates (
  object_type, subject_class, policy_code, hybrid_profile_code,
  default_data_classification, require_lawful_basis,
  require_minimum_necessary, require_retention_limit, enabled, metadata
)
values
  ('CVI_OPEN_SCROLL','SYSTEM','TRUST_LONG_DURATION','HYB-Q3-ECDSA-P256-MLDSA65-V1','RESTRICTED',false,true,false,true,jsonb_build_object('payload_storage','reference_only')),
  ('DPOT_TRACE_RUN','SYSTEM','TRUST_LONG_DURATION','HYB-Q3-ECDSA-P256-MLDSA65-V1','RESTRICTED',false,true,false,true,jsonb_build_object('payload_storage','reference_only')),
  ('ORGANIZATION_DD_REPORT','ORGANIZATION','TRUST_LONG_DURATION','HYB-Q3-ECDSA-P256-MLDSA65-V1','RESTRICTED',false,true,true,true,jsonb_build_object('raw_due_diligence_payload_prohibited',true)),
  ('INDIVIDUAL_DD_REPORT','INDIVIDUAL','TRUST_LONG_DURATION','HYB-Q3-ECDSA-P256-MLDSA65-V1','HIGHLY_RESTRICTED',true,true,true,true,jsonb_build_object('raw_personal_data_prohibited',true,'lawful_authority_required',true)),
  ('HIGH_VALUE_AUTHORIZATION','TRANSACTION','HIGH_VALUE_TRANSFER','HYB-Q3-ECDSA-P256-MLDSA65-V1','HIGHLY_RESTRICTED',false,true,true,true,jsonb_build_object('transaction_payload_storage','reference_only')),
  ('IP_PROVENANCE','IP','IP_PROVENANCE','HYB-Q3-ECDSA-P256-MLDSA65-V1','RESTRICTED',false,true,false,true,jsonb_build_object('payload_storage','reference_only'))
on conflict (object_type) do update set
  subject_class=excluded.subject_class,
  policy_code=excluded.policy_code,
  hybrid_profile_code=excluded.hybrid_profile_code,
  default_data_classification=excluded.default_data_classification,
  require_lawful_basis=excluded.require_lawful_basis,
  require_minimum_necessary=excluded.require_minimum_necessary,
  require_retention_limit=excluded.require_retention_limit,
  enabled=excluded.enabled,
  metadata=excluded.metadata,
  updated_at=now();

update pqc.crypto_policies
set permitted_algorithms = case policy_code
      when 'IP_PROVENANCE' then array['ECDSA-P256-SHA256','ML-DSA-65','SLH-DSA']
      when 'TRUST_LONG_DURATION' then array['ECDSA-P256-SHA256','ML-DSA-65','SLH-DSA']
      when 'HIGH_VALUE_TRANSFER' then array['ML-KEM','ECDSA-P256-SHA256','ML-DSA-65']
      else permitted_algorithms
    end,
    evidence_requirements = evidence_requirements || jsonb_build_object(
      'hybrid_profile','HYB-Q3-ECDSA-P256-MLDSA65-V1',
      'active_key_reference',true,
      'external_verifier_receipt',true,
      'human_authorization',true
    ),
    updated_at=now()
where policy_code in ('IP_PROVENANCE','TRUST_LONG_DURATION','HIGH_VALUE_TRANSFER');

create or replace function pqc.register_protected_object(
  p_object_type text,
  p_object_id text,
  p_object_version text,
  p_object_digest text,
  p_digest_algorithm text,
  p_content_reference text,
  p_processing_purpose text,
  p_lawful_basis_code text default null,
  p_authority_reference text default null,
  p_retention_until timestamptz default null,
  p_minimum_necessary_attested boolean default false,
  p_created_by text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_template pqc.protection_templates%rowtype;
  v_policy_id uuid;
  v_id uuid;
begin
  select * into v_template
  from pqc.protection_templates
  where object_type=p_object_type and enabled;

  if not found then
    raise exception 'No enabled PQC protection template exists for object type %', p_object_type;
  end if;

  select id into v_policy_id
  from pqc.crypto_policies
  where policy_code=v_template.policy_code and status='active';

  if v_policy_id is null then
    raise exception 'Active crypto policy % is unavailable', v_template.policy_code;
  end if;

  if p_created_by is null or btrim(p_created_by)='' then
    raise exception 'created_by is required';
  end if;

  if p_object_digest !~ '^[0-9A-Fa-f]{64}$|^[0-9A-Fa-f]{96}$|^[0-9A-Fa-f]{128}$' then
    raise exception 'Object digest must be a 256, 384, or 512-bit hexadecimal digest';
  end if;

  if v_template.require_lawful_basis and (p_lawful_basis_code is null or p_authority_reference is null) then
    raise exception 'Lawful basis and authority reference are required for %', p_object_type;
  end if;

  if v_template.require_minimum_necessary and not p_minimum_necessary_attested then
    raise exception 'Minimum-necessary attestation is required for %', p_object_type;
  end if;

  if v_template.require_retention_limit and p_retention_until is null then
    raise exception 'Retention limit is required for %', p_object_type;
  end if;

  insert into evidence.protected_objects (
    object_type, object_id, object_version, object_digest, digest_algorithm,
    policy_id, hybrid_profile_code, subject_class, data_classification,
    content_reference, processing_purpose, lawful_basis_code,
    authority_reference, retention_until, minimum_necessary_attested,
    protection_state, created_by, metadata
  ) values (
    p_object_type, p_object_id, coalesce(nullif(p_object_version,''),'1'),
    lower(p_object_digest), p_digest_algorithm,
    v_policy_id, v_template.hybrid_profile_code, v_template.subject_class,
    v_template.default_data_classification, p_content_reference,
    p_processing_purpose, p_lawful_basis_code, p_authority_reference,
    p_retention_until, p_minimum_necessary_attested,
    'HASHED', p_created_by, coalesce(p_metadata,'{}'::jsonb)
  ) returning id into v_id;

  return v_id;
end;
$$;

create or replace function pqc.evaluate_protected_object(
  p_protected_object_id uuid,
  p_target_state text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_obj evidence.protected_objects%rowtype;
  v_profile pqc.hybrid_profiles%rowtype;
  v_policy_status text;
  v_template_enabled boolean;
  v_classical_count integer := 0;
  v_pqc_count integer := 0;
  v_authorization_ok boolean := true;
  v_required_authorization text;
  v_allowed boolean := false;
  v_reasons jsonb := '[]'::jsonb;
begin
  select * into v_obj
  from evidence.protected_objects
  where id=p_protected_object_id;

  if not found then
    raise exception 'Protected object % does not exist', p_protected_object_id;
  end if;

  select * into v_profile
  from pqc.hybrid_profiles
  where profile_code=v_obj.hybrid_profile_code;

  select status into v_policy_status
  from pqc.crypto_policies
  where id=v_obj.policy_id;

  select enabled into v_template_enabled
  from pqc.protection_templates
  where object_type=v_obj.object_type;

  select
    count(*) filter (
      where c.component_role='CLASSICAL'
        and s.signature_algorithm=v_profile.classical_algorithm_code
        and s.verification_status='valid'
        and s.verification_engine is not null
        and s.verification_evidence_reference is not null
        and s.verified_at is not null
        and k.status='active'
        and k.algorithm_code=v_profile.classical_algorithm_code
    ),
    count(*) filter (
      where c.component_role='PQC'
        and s.signature_algorithm=v_profile.pqc_algorithm_code
        and s.verification_status='valid'
        and s.verification_engine is not null
        and s.verification_evidence_reference is not null
        and s.verified_at is not null
        and k.status='active'
        and k.algorithm_code=v_profile.pqc_algorithm_code
    )
  into v_classical_count, v_pqc_count
  from evidence.hybrid_signature_components c
  join evidence.signature_envelopes s on s.id=c.signature_envelope_id
  join pqc.key_registry k on k.key_id=s.key_id
  where c.protected_object_id=v_obj.id and c.required;

  v_required_authorization := case p_target_state
    when 'PILOT_VERIFIED' then 'PILOT_APPROVAL'
    when 'RELEASE_READY' then 'RELEASE'
    when 'RETIRED' then 'REVOKE'
    else null
  end;

  if v_required_authorization is not null
     and (v_profile.require_human_authorization or v_obj.subject_class='INDIVIDUAL') then
    select exists (
      select 1
      from evidence.human_authorizations a
      where a.protected_object_id=v_obj.id
        and a.authorization_type=v_required_authorization
        and a.decision='APPROVED'
        and a.decided_at is not null
        and (a.expires_at is null or a.expires_at > now())
    ) into v_authorization_ok;
  end if;

  if v_policy_status <> 'active' then
    v_reasons := v_reasons || jsonb_build_array('CRYPTO_POLICY_NOT_ACTIVE');
  end if;

  if not coalesce(v_template_enabled,false) then
    v_reasons := v_reasons || jsonb_build_array('PROTECTION_TEMPLATE_DISABLED');
  end if;

  if not (v_obj.object_type = any(v_profile.allowed_object_types)) then
    v_reasons := v_reasons || jsonb_build_array('OBJECT_TYPE_NOT_ALLOWED_BY_PROFILE');
  end if;

  if p_target_state in ('PILOT_VERIFIED','RELEASE_READY') then
    if v_classical_count < v_profile.minimum_classical_components then
      v_reasons := v_reasons || jsonb_build_array('CLASSICAL_SIGNATURE_COMPONENT_MISSING_OR_UNVERIFIED');
    end if;
    if v_pqc_count < v_profile.minimum_pqc_components then
      v_reasons := v_reasons || jsonb_build_array('PQC_SIGNATURE_COMPONENT_MISSING_OR_UNVERIFIED');
    end if;
    if not v_authorization_ok then
      v_reasons := v_reasons || jsonb_build_array('ACCOUNTABLE_HUMAN_AUTHORIZATION_MISSING');
    end if;
  end if;

  if p_target_state='PILOT_VERIFIED' and v_profile.status not in ('pilot','active') then
    v_reasons := v_reasons || jsonb_build_array('HYBRID_PROFILE_NOT_PILOT_CAPABLE');
  end if;

  if p_target_state='RELEASE_READY' and v_profile.status <> 'active' then
    v_reasons := v_reasons || jsonb_build_array('HYBRID_PROFILE_NOT_PRODUCTION_ACTIVE');
  end if;

  if p_target_state='RETIRED' and not v_authorization_ok then
    v_reasons := v_reasons || jsonb_build_array('REVOCATION_AUTHORIZATION_MISSING');
  end if;

  if p_target_state not in ('HASHED','SIGNING','PILOT_VERIFIED','RELEASE_READY','BLOCKED','RETIRED') then
    v_reasons := v_reasons || jsonb_build_array('UNSUPPORTED_TARGET_STATE');
  end if;

  v_allowed := jsonb_array_length(v_reasons)=0;

  return jsonb_build_object(
    'allowed',v_allowed,
    'protected_object_id',v_obj.id,
    'object_type',v_obj.object_type,
    'object_id',v_obj.object_id,
    'prior_state',v_obj.protection_state,
    'target_state',p_target_state,
    'policy_status',v_policy_status,
    'hybrid_profile',v_profile.profile_code,
    'hybrid_profile_status',v_profile.status,
    'classical_algorithm',v_profile.classical_algorithm_code,
    'pqc_algorithm',v_profile.pqc_algorithm_code,
    'classical_verified_components',v_classical_count,
    'pqc_verified_components',v_pqc_count,
    'human_authorization_satisfied',v_authorization_ok,
    'reasons',v_reasons,
    'cryptographic_execution_boundary','EXTERNAL_VERIFIER_REQUIRED',
    'database_role','EVIDENCE_ORCHESTRATION_AND_GATE_ENFORCEMENT'
  );
end;
$$;

create or replace function pqc.guard_protected_object_state_transition()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_expected text;
begin
  if new.protection_state is distinct from old.protection_state then
    v_expected := new.id::text || ':' || new.protection_state || ':' || txid_current()::text;
    if coalesce(current_setting('pqc.transition_token',true),'') <> v_expected then
      raise exception 'Protected object state transitions must use pqc.request_protected_object_transition()';
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create or replace function pqc.guard_signature_envelope_validity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_key_ok boolean;
begin
  if new.evidence_metadata ?| array['private_key','secret_key','seed','mnemonic','service_role_key'] then
    raise exception 'Private or secret key material is prohibited in evidence metadata';
  end if;

  if new.verification_status='valid' then
    select exists (
      select 1
      from pqc.key_registry k
      where k.key_id=new.key_id
        and k.status='active'
        and k.algorithm_code=new.signature_algorithm
    ) into v_key_ok;

    if not v_key_ok then
      raise exception 'A valid signature envelope requires an active registered key matching the signature algorithm';
    end if;
  end if;

  if tg_op='UPDATE' and old.verification_status='valid' and (
       new.object_type is distinct from old.object_type
    or new.object_id is distinct from old.object_id
    or new.object_digest is distinct from old.object_digest
    or new.digest_algorithm is distinct from old.digest_algorithm
    or new.signature_algorithm is distinct from old.signature_algorithm
    or new.signature_value is distinct from old.signature_value
    or new.key_id is distinct from old.key_id
    or new.signer_identity is distinct from old.signer_identity
    or new.signed_at is distinct from old.signed_at
  ) then
    raise exception 'Verified signature envelope core fields are immutable';
  end if;

  return new;
end;
$$;

create or replace function pqc.guard_hybrid_signature_component()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_obj evidence.protected_objects%rowtype;
  v_profile pqc.hybrid_profiles%rowtype;
  v_sig evidence.signature_envelopes%rowtype;
  v_expected_algorithm text;
begin
  select * into v_obj from evidence.protected_objects where id=new.protected_object_id;
  select * into v_profile from pqc.hybrid_profiles where profile_code=v_obj.hybrid_profile_code;
  select * into v_sig from evidence.signature_envelopes where id=new.signature_envelope_id;

  v_expected_algorithm := case new.component_role
    when 'CLASSICAL' then v_profile.classical_algorithm_code
    when 'PQC' then v_profile.pqc_algorithm_code
    else null
  end;

  if v_sig.object_type <> v_obj.object_type
     or v_sig.object_id <> v_obj.object_id
     or v_sig.object_digest <> v_obj.object_digest
     or v_sig.digest_algorithm <> v_obj.digest_algorithm
     or v_sig.policy_id is distinct from v_obj.policy_id
     or coalesce(v_sig.evidence_metadata->>'object_version','') <> v_obj.object_version then
    raise exception 'Signature envelope does not match the protected object identity, digest, version, or policy';
  end if;

  if v_sig.signature_algorithm <> v_expected_algorithm then
    raise exception 'Signature algorithm % does not match required % component algorithm %',
      v_sig.signature_algorithm, new.component_role, v_expected_algorithm;
  end if;

  return new;
end;
$$;

create or replace function evidence.block_protection_gate_event_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'Protection gate events are append-only';
end;
$$;

create or replace function evidence.block_human_authorization_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'Human authorization records are append-only; create a superseding authorization event';
end;
$$;

create or replace function pqc.request_protected_object_transition(
  p_protected_object_id uuid,
  p_target_state text,
  p_requested_by text,
  p_correlation_id text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_eval jsonb;
  v_prior_state text;
  v_correlation_id text;
  v_event_id uuid;
  v_token text;
  v_decision text;
begin
  if p_requested_by is null or btrim(p_requested_by)='' then
    raise exception 'requested_by is required';
  end if;

  select protection_state into v_prior_state
  from evidence.protected_objects
  where id=p_protected_object_id
  for update;

  if v_prior_state is null then
    raise exception 'Protected object % does not exist', p_protected_object_id;
  end if;

  v_correlation_id := coalesce(nullif(p_correlation_id,''),gen_random_uuid()::text);
  v_eval := pqc.evaluate_protected_object(p_protected_object_id,p_target_state);
  v_decision := case when (v_eval->>'allowed')::boolean then 'PASS' else 'BLOCK' end;

  insert into evidence.protection_gate_events (
    protected_object_id, prior_state, requested_state, decision,
    reasons, evaluation_snapshot, evaluated_by, correlation_id
  ) values (
    p_protected_object_id, v_prior_state, p_target_state, v_decision,
    coalesce(v_eval->'reasons','[]'::jsonb), v_eval, p_requested_by, v_correlation_id
  ) returning event_id into v_event_id;

  insert into pqc.verification_events (
    event_type, subject_type, subject_ref, algorithm_code, policy_code,
    verification_status, verification_engine, verifier_identity,
    evidence_reference, correlation_id, result_metadata
  )
  select
    'protected_object_transition', o.object_type, o.object_id,
    v_eval->>'pqc_algorithm', p.policy_code,
    case when v_decision='PASS' then 'passed' else 'failed' end,
    'pqc.request_protected_object_transition', p_requested_by,
    'evidence.protection_gate_events/' || v_event_id::text,
    v_correlation_id, v_eval
  from evidence.protected_objects o
  join pqc.crypto_policies p on p.id=o.policy_id
  where o.id=p_protected_object_id;

  if v_decision='PASS' then
    v_token := p_protected_object_id::text || ':' || p_target_state || ':' || txid_current()::text;
    perform set_config('pqc.transition_token',v_token,true);
    update evidence.protected_objects
      set protection_state=p_target_state, updated_at=now()
      where id=p_protected_object_id;
    perform set_config('pqc.transition_token','',true);
  end if;

  return v_eval || jsonb_build_object(
    'gate_event_id',v_event_id,
    'correlation_id',v_correlation_id,
    'decision',v_decision,
    'state_changed',v_decision='PASS'
  );
end;
$$;

drop trigger if exists protected_object_state_guard on evidence.protected_objects;
create trigger protected_object_state_guard
before update of protection_state on evidence.protected_objects
for each row execute function pqc.guard_protected_object_state_transition();

drop trigger if exists signature_envelope_validity_guard on evidence.signature_envelopes;
create trigger signature_envelope_validity_guard
before insert or update on evidence.signature_envelopes
for each row execute function pqc.guard_signature_envelope_validity();

drop trigger if exists hybrid_signature_component_guard on evidence.hybrid_signature_components;
create trigger hybrid_signature_component_guard
before insert or update on evidence.hybrid_signature_components
for each row execute function pqc.guard_hybrid_signature_component();

drop trigger if exists protection_gate_events_append_only on evidence.protection_gate_events;
create trigger protection_gate_events_append_only
before update or delete on evidence.protection_gate_events
for each row execute function evidence.block_protection_gate_event_mutation();

drop trigger if exists human_authorizations_append_only on evidence.human_authorizations;
create trigger human_authorizations_append_only
before update or delete on evidence.human_authorizations
for each row execute function evidence.block_human_authorization_mutation();

alter table pqc.hybrid_profiles enable row level security;
alter table pqc.protection_templates enable row level security;
alter table evidence.protected_objects enable row level security;
alter table evidence.hybrid_signature_components enable row level security;
alter table evidence.human_authorizations enable row level security;
alter table evidence.protection_gate_events enable row level security;

revoke all on table pqc.hybrid_profiles from public, anon, authenticated;
revoke all on table pqc.protection_templates from public, anon, authenticated;
revoke all on table evidence.protected_objects from public, anon, authenticated;
revoke all on table evidence.hybrid_signature_components from public, anon, authenticated;
revoke all on table evidence.human_authorizations from public, anon, authenticated;
revoke all on table evidence.protection_gate_events from public, anon, authenticated;

grant select, insert, update, delete on table pqc.hybrid_profiles to service_role;
grant select, insert, update, delete on table pqc.protection_templates to service_role;
grant select, insert, update, delete on table evidence.protected_objects to service_role;
grant select, insert, update, delete on table evidence.hybrid_signature_components to service_role;
grant select, insert on table evidence.human_authorizations to service_role;
grant select, insert on table evidence.protection_gate_events to service_role;

drop policy if exists hybrid_profiles_service_role on pqc.hybrid_profiles;
create policy hybrid_profiles_service_role on pqc.hybrid_profiles
for all to service_role using (true) with check (true);

drop policy if exists protection_templates_service_role on pqc.protection_templates;
create policy protection_templates_service_role on pqc.protection_templates
for all to service_role using (true) with check (true);

drop policy if exists protected_objects_service_role on evidence.protected_objects;
create policy protected_objects_service_role on evidence.protected_objects
for all to service_role using (true) with check (true);

drop policy if exists hybrid_components_service_role on evidence.hybrid_signature_components;
create policy hybrid_components_service_role on evidence.hybrid_signature_components
for all to service_role using (true) with check (true);

drop policy if exists human_authorizations_service_select on evidence.human_authorizations;
create policy human_authorizations_service_select on evidence.human_authorizations
for select to service_role using (true);

drop policy if exists human_authorizations_service_insert on evidence.human_authorizations;
create policy human_authorizations_service_insert on evidence.human_authorizations
for insert to service_role with check (true);

drop policy if exists protection_gate_events_service_select on evidence.protection_gate_events;
create policy protection_gate_events_service_select on evidence.protection_gate_events
for select to service_role using (true);

drop policy if exists protection_gate_events_service_insert on evidence.protection_gate_events;
create policy protection_gate_events_service_insert on evidence.protection_gate_events
for insert to service_role with check (true);

revoke all on function pqc.register_protected_object(text,text,text,text,text,text,text,text,text,timestamptz,boolean,text,jsonb) from public, anon, authenticated;
revoke all on function pqc.evaluate_protected_object(uuid,text) from public, anon, authenticated;
revoke all on function pqc.request_protected_object_transition(uuid,text,text,text) from public, anon, authenticated;
revoke all on function pqc.guard_protected_object_state_transition() from public, anon, authenticated;
revoke all on function pqc.guard_signature_envelope_validity() from public, anon, authenticated;
revoke all on function pqc.guard_hybrid_signature_component() from public, anon, authenticated;
revoke all on function evidence.block_protection_gate_event_mutation() from public, anon, authenticated;
revoke all on function evidence.block_human_authorization_mutation() from public, anon, authenticated;

grant execute on function pqc.register_protected_object(text,text,text,text,text,text,text,text,text,timestamptz,boolean,text,jsonb) to service_role;
grant execute on function pqc.evaluate_protected_object(uuid,text) to service_role;
grant execute on function pqc.request_protected_object_transition(uuid,text,text,text) to service_role;

create or replace view pqc.operational_pqc_status
with (security_invoker=true)
as
select
  (select count(*) from pqc.hybrid_profiles where status='pilot') as pilot_profiles,
  (select count(*) from pqc.hybrid_profiles where status='active') as active_profiles,
  (select count(*) from pqc.key_registry where status='active' and algorithm_code in ('ML-DSA-65','ML-DSA','SLH-DSA')) as active_pqc_keys,
  (select count(*) from evidence.signature_envelopes where verification_status='valid' and signature_algorithm in ('ML-DSA-65','ML-DSA','SLH-DSA')) as valid_pqc_signature_envelopes,
  (select count(*) from evidence.protected_objects) as protected_objects,
  (select count(*) from evidence.protected_objects where protection_state='PILOT_VERIFIED') as pilot_verified_objects,
  (select count(*) from evidence.protected_objects where protection_state='RELEASE_READY') as release_ready_objects,
  (
    (select count(*) from pqc.hybrid_profiles where status='active') > 0
    and (select count(*) from pqc.key_registry where status='active' and algorithm_code in ('ML-DSA-65','ML-DSA','SLH-DSA')) > 0
    and (select count(*) from evidence.signature_envelopes where verification_status='valid' and signature_algorithm in ('ML-DSA-65','ML-DSA','SLH-DSA')) > 0
    and (select count(*) from evidence.protected_objects where protection_state='RELEASE_READY') > 0
  ) as end_to_end_pqc_evidence_established,
  case
    when (select count(*) from pqc.hybrid_profiles where status='active') > 0
      and (select count(*) from evidence.protected_objects where protection_state='RELEASE_READY') > 0
      then 'PQC_ENFORCED_FOR_REGISTERED_OBJECTS'
    when (select count(*) from evidence.protected_objects where protection_state='PILOT_VERIFIED') > 0
      then 'HYBRID_PILOT_VERIFIED'
    else 'PQC_GOVERNED_NOT_YET_PQC_ENFORCED'
  end as status_label;

revoke all on table pqc.operational_pqc_status from public, anon, authenticated;
grant select on table pqc.operational_pqc_status to service_role;

-- Close the pre-existing CVI RLS-policy gap while keeping the interface service-only.
do $$
begin
  if to_regclass('public.cvi_interface_config') is not null then
    execute 'drop policy if exists cvi_interface_config_service_role on public.cvi_interface_config';
    execute 'create policy cvi_interface_config_service_role on public.cvi_interface_config for all to service_role using (true) with check (true)';
  end if;
  if to_regclass('public.cvi_nodes') is not null then
    execute 'drop policy if exists cvi_nodes_service_role on public.cvi_nodes';
    execute 'create policy cvi_nodes_service_role on public.cvi_nodes for all to service_role using (true) with check (true)';
  end if;
  if to_regclass('public.cvi_watchtraces') is not null then
    execute 'drop policy if exists cvi_watchtraces_service_role on public.cvi_watchtraces';
    execute 'create policy cvi_watchtraces_service_role on public.cvi_watchtraces for all to service_role using (true) with check (true)';
  end if;
  if to_regclass('public.cvi_evidence_events') is not null then
    execute 'drop policy if exists cvi_evidence_events_service_role on public.cvi_evidence_events';
    execute 'create policy cvi_evidence_events_service_role on public.cvi_evidence_events for all to service_role using (true) with check (true)';
  end if;
end $$;

insert into pqc.migration_register (
  component, system_owner, current_algorithm, current_protocol,
  quantum_risk, data_lifetime_years, vendor_dependency,
  replacement_algorithm, migration_stage, verification_status,
  approval_reference
)
values (
  'CVI/DPOT and due-diligence evidence envelopes',
  'Knowledge Governance / Platform Engineering',
  'Classical or unsigned evidence references',
  'Detached evidence envelope',
  'critical', 100,
  'External KMS/HSM and independent verifier',
  'Hybrid ECDSA-P256-SHA256 + ML-DSA-65 with SHA-384 object digest',
  'planned', 'pending',
  'PQC hybrid evidence pilot control-plane installation'
)
on conflict (component,current_algorithm,current_protocol) do update set
  replacement_algorithm=excluded.replacement_algorithm,
  migration_stage=excluded.migration_stage,
  verification_status=excluded.verification_status,
  approval_reference=excluded.approval_reference,
  updated_at=now();

insert into pqc.verification_events (
  event_type, subject_type, subject_ref, algorithm_code, policy_code,
  verification_status, verification_engine, verifier_identity,
  evidence_reference, correlation_id, result_metadata
)
values (
  'hybrid_evidence_control_plane',
  'system',
  'pqc:hybrid-evidence-pilot',
  'ML-DSA-65',
  'TRUST_LONG_DURATION',
  'passed',
  'PostgreSQL schema contract',
  'SIOS PQ-CGL',
  'migration:pqc_hybrid_evidence_pilot',
  'pqc-hybrid-evidence-pilot-20260831',
  jsonb_build_object(
    'scope','control_plane_only',
    'operational_pqc_keys_registered',false,
    'production_profile_active',false,
    'claim','PQC_GOVERNED_NOT_YET_PQC_ENFORCED'
  )
)
on conflict do nothing;

update pqc.readiness_assessments
set metadata = metadata || jsonb_build_object(
      'hybrid_evidence_control_plane_installed',true,
      'hybrid_profile_status','pilot',
      'operational_pqc_keys_registered',false,
      'production_release_enabled',false
    ),
    updated_at=now()
where assessment_code='QRI-BASELINE-2026-08-26';

-- Register the existing CV-ENTRY-002 Open Scroll as a HASHED pilot object without copying its payload.
with latest_open_scroll as (
  select s.session_id, s.snapshot, s.evidence_cutoff_at
  from public.dpot_open_scroll_sessions s
  where s.trace_id='CV-ENTRY-002'
  order by s.opened_at desc
  limit 1
), prepared as (
  select
    session_id,
    evidence_cutoff_at,
    encode(extensions.digest(convert_to(snapshot::text,'UTF8'),'sha384'),'hex') as object_digest
  from latest_open_scroll
)
select pqc.register_protected_object(
  'CVI_OPEN_SCROLL',
  p.session_id::text,
  'baseline-' || to_char(p.evidence_cutoff_at at time zone 'UTC','YYYYMMDDHH24MISS'),
  p.object_digest,
  'SHA-384',
  'supabase://public.dpot_open_scroll_sessions/' || p.session_id::text,
  'Governed CVI evidence review and provenance preservation',
  null,
  null,
  null,
  true,
  'CVI-DPOT-CONTROL-PLANE',
  jsonb_build_object('trace_id','CV-ENTRY-002','payload_copied',false,'pilot_status','HASHED_AWAITING_SIGNATURES')
)
from prepared p
where not exists (
  select 1 from evidence.protected_objects o
  where o.object_type='CVI_OPEN_SCROLL' and o.object_id=p.session_id::text
);

update public.cvi_interface_config
set version_label='Tier III+ — DPOT + PQC Hybrid Evidence Pilot',
    operational_definition='LIVE means the SourceEnergy command backend is reachable and the CVI/DPOT/PQ-CGL control planes record evidence-backed state. Protected Open Scroll, trace, due-diligence, IP and authorization objects are hash-registered and may advance only through the hybrid evidence gate. The current hybrid profile is PILOT, no operational PQC keys are registered, and end-to-end PQC is not yet established.',
    updated_at=now()
where config_key='primary';

comment on table pqc.hybrid_profiles is 'Hybrid signature profiles. A pilot profile defines required algorithms and evidence but cannot authorize production release until independently validated and activated.';
comment on table pqc.protection_templates is 'Policy templates for protected CVI, DPOT, due-diligence, authorization and IP objects. Templates store governance requirements, not payloads.';
comment on table evidence.protected_objects is 'Hash-and-reference registry for protected objects. Raw due-diligence payloads, account details, credentials and private keys are prohibited.';
comment on table evidence.hybrid_signature_components is 'Binds classical and post-quantum signature envelopes to a protected object; cryptographic verification occurs in an external approved engine.';
comment on table evidence.human_authorizations is 'Append-only accountable authorization evidence. Cryptographic validity does not create legal or institutional authority.';
comment on table evidence.protection_gate_events is 'Append-only gate decision ledger for protected-object transitions.';
comment on function pqc.evaluate_protected_object(uuid,text) is 'Evaluates evidence and governance readiness. It does not perform ML-DSA or ECDSA cryptographic verification inside Postgres.';
comment on function pqc.request_protected_object_transition(uuid,text,text,text) is 'Only supported route for governed protected-object state promotion; records PASS/BLOCK evidence before any state change.';