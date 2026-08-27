create schema if not exists pqc;
create schema if not exists evidence;

revoke all on schema pqc from anon, authenticated;
revoke all on schema evidence from anon, authenticated;
grant usage on schema pqc, evidence to service_role;

create table if not exists pqc.algorithm_registry (
  algorithm_code text primary key,
  standard text not null,
  function_type text not null check (function_type in ('key_establishment','digital_signature','hash','symmetric','other')),
  security_status text not null check (security_status in ('approved','approved_alternative','transition','deprecated','prohibited','candidate')),
  minimum_parameter_set text,
  implementation_profile jsonb not null default '{}'::jsonb,
  authority_source text,
  approved_from date,
  deprecation_from date,
  prohibited_from date,
  governance_status text not null default 'active' check (governance_status in ('active','review','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists pqc.crypto_assets (
  id uuid primary key default gen_random_uuid(),
  system_name text not null,
  system_component text not null,
  environment text not null default 'production',
  asset_type text not null,
  protocol text,
  algorithm_family text,
  algorithm_name text,
  key_size integer,
  certificate_id text,
  owner_role text,
  data_classification text,
  confidentiality_years integer check (confidentiality_years is null or confidentiality_years >= 0),
  quantum_vulnerable boolean,
  harvest_now_decrypt_later_risk text check (harvest_now_decrypt_later_risk in ('none','low','medium','high','critical')),
  migration_priority integer check (migration_priority between 0 and 100),
  discovery_method text,
  metadata jsonb not null default '{}'::jsonb,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(system_name, system_component, environment, asset_type)
);

create index if not exists crypto_assets_priority_idx on pqc.crypto_assets (migration_priority desc);
create index if not exists crypto_assets_quantum_idx on pqc.crypto_assets (quantum_vulnerable, harvest_now_decrypt_later_risk);

create table if not exists pqc.crypto_policies (
  id uuid primary key default gen_random_uuid(),
  policy_code text not null unique,
  policy_name text not null,
  assurance_class text not null check (assurance_class in ('Q1','Q2','Q3')),
  retention_horizon_years integer,
  require_pqc boolean not null default false,
  require_hybrid boolean not null default false,
  require_dual_authorization boolean not null default false,
  permitted_algorithms text[] not null default '{}'::text[],
  evidence_requirements jsonb not null default '{}'::jsonb,
  governance_gate text,
  status text not null default 'draft' check (status in ('draft','active','suspended','retired')),
  effective_from timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists pqc.key_registry (
  key_id uuid primary key default gen_random_uuid(),
  logical_owner text not null,
  purpose text not null,
  algorithm_code text references pqc.algorithm_registry(algorithm_code),
  provider text not null,
  provider_key_reference text not null,
  public_key_fingerprint text,
  status text not null default 'planned' check (status in ('planned','active','rotating','revoked','expired','retired')),
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  expires_at timestamptz,
  rotated_from uuid references pqc.key_registry(key_id),
  revoked_at timestamptz,
  revocation_reason text,
  metadata jsonb not null default '{}'::jsonb,
  unique(provider, provider_key_reference)
);

create table if not exists pqc.migration_register (
  id uuid primary key default gen_random_uuid(),
  component text not null,
  system_owner text,
  current_algorithm text,
  current_protocol text,
  quantum_risk text not null default 'unknown' check (quantum_risk in ('unknown','none','low','medium','high','critical')),
  data_lifetime_years integer,
  vendor_dependency text,
  replacement_algorithm text,
  migration_stage text not null default 'discovered' check (migration_stage in ('discovered','classified','planned','hybrid','pqc_ready','verified','legacy_retired')),
  target_date date,
  verification_status text not null default 'unverified' check (verification_status in ('unverified','pending','passed','failed','exception')),
  approved_by text,
  approval_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(component, current_algorithm, current_protocol)
);

create table if not exists evidence.signature_envelopes (
  id uuid primary key default gen_random_uuid(),
  object_type text not null,
  object_id text not null,
  object_digest text not null,
  digest_algorithm text not null,
  signature_algorithm text not null,
  signature_version text,
  signer_identity text not null,
  credential_id text,
  signature_value text not null,
  public_key_reference text,
  signed_at timestamptz not null default now(),
  verification_status text not null default 'unverified' check (verification_status in ('unverified','valid','invalid','expired','revoked','error')),
  verification_engine text,
  policy_id uuid references pqc.crypto_policies(id),
  chain_anchor text,
  evidence_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists signature_envelopes_object_idx on evidence.signature_envelopes (object_type, object_id);
create index if not exists signature_envelopes_status_idx on evidence.signature_envelopes (verification_status, signed_at desc);

alter table pqc.algorithm_registry enable row level security;
alter table pqc.crypto_assets enable row level security;
alter table pqc.crypto_policies enable row level security;
alter table pqc.key_registry enable row level security;
alter table pqc.migration_register enable row level security;
alter table evidence.signature_envelopes enable row level security;

revoke all on all tables in schema pqc from anon, authenticated;
revoke all on all tables in schema evidence from anon, authenticated;
grant select, insert, update, delete on all tables in schema pqc to service_role;
grant select, insert, update, delete on all tables in schema evidence to service_role;

insert into pqc.algorithm_registry (algorithm_code, standard, function_type, security_status, authority_source, governance_status)
values
  ('ML-KEM','FIPS 203','key_establishment','approved','NIST','active'),
  ('ML-DSA','FIPS 204','digital_signature','approved','NIST','active'),
  ('SLH-DSA','FIPS 205','digital_signature','approved_alternative','NIST','active'),
  ('RSA','PKCS / legacy public-key family','other','transition','SourceEnergy migration policy','active'),
  ('ECDH','Classical elliptic-curve key agreement','key_establishment','transition','SourceEnergy migration policy','active'),
  ('ECDSA','Classical elliptic-curve digital signature','digital_signature','transition','SourceEnergy migration policy','active')
on conflict (algorithm_code) do nothing;

insert into pqc.crypto_policies (policy_code, policy_name, assurance_class, retention_horizon_years, require_pqc, require_hybrid, require_dual_authorization, permitted_algorithms, evidence_requirements, governance_gate, status, effective_from)
values
  ('STANDARD_TRANSACTION','Standard Transaction','Q1',5,false,false,false,array['RSA','ECDSA','ML-DSA'],jsonb_build_object('audit',true),null,'active',now()),
  ('IP_PROVENANCE','IP Provenance','Q2',50,true,true,false,array['ML-DSA','SLH-DSA'],jsonb_build_object('digest',true,'timestamp',true,'re_attestation',true),'Q5','active',now()),
  ('TRUST_LONG_DURATION','Trust Long Duration','Q3',100,true,true,true,array['ML-DSA','SLH-DSA'],jsonb_build_object('independent_timestamp',true,'immutable_audit',true,'revalidation',true),'Q9','active',now()),
  ('HIGH_VALUE_TRANSFER','High Value Transfer','Q3',25,true,true,true,array['ML-KEM','ML-DSA'],jsonb_build_object('dual_control',true,'verification_receipt',true),'Q9','active',now())
on conflict (policy_code) do nothing;