create schema if not exists dhn_identity;
create schema if not exists dhn_consent;
create schema if not exists dhn_org;
create schema if not exists dhn_biometric;
create schema if not exists dhn_telemetry;
create schema if not exists dhn_clinical;
create schema if not exists dhn_audit;
create schema if not exists dhn_attestation;
create schema if not exists dhn_research;
create schema if not exists dhn_integration;

create table if not exists dhn_identity.health_credentials (
  health_credential_id uuid primary key default gen_random_uuid(),
  actor_id text not null,
  credential_type text not null default 'dhn_health',
  issuer text not null default 'diaspora_health_network',
  status text not null default 'active' check (status in ('active','suspended','revoked','expired')),
  assurance_level text,
  issued_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (expires_at is null or expires_at > issued_at),
  check (revoked_at is null or revoked_at >= issued_at)
);
create index if not exists idx_dhn_health_credentials_actor on dhn_identity.health_credentials(actor_id);
create index if not exists idx_dhn_health_credentials_status on dhn_identity.health_credentials(status);

create table if not exists dhn_identity.identity_mappings (
  identity_mapping_id uuid primary key default gen_random_uuid(),
  actor_id text not null,
  health_credential_id uuid references dhn_identity.health_credentials(health_credential_id),
  auth_user_id uuid references auth.users(id),
  external_subject_ref text,
  mapping_scope text not null,
  status text not null default 'active' check (status in ('active','suspended','revoked')),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(actor_id, mapping_scope)
);
create index if not exists idx_dhn_identity_mappings_auth_user on dhn_identity.identity_mappings(auth_user_id);

create table if not exists dhn_consent.consents (
  consent_id uuid primary key default gen_random_uuid(),
  actor_id text not null,
  grantee_type text not null,
  grantee_ref text not null,
  purpose text not null,
  scope jsonb not null default '{}'::jsonb,
  legal_basis text,
  status text not null default 'active' check (status in ('active','revoked','expired','superseded')),
  effective_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (expires_at is null or expires_at > effective_at),
  check (revoked_at is null or revoked_at >= effective_at)
);
create index if not exists idx_dhn_consents_actor_status on dhn_consent.consents(actor_id, status);

create table if not exists dhn_consent.authorization_decisions (
  authorization_decision_id uuid primary key default gen_random_uuid(),
  actor_id text not null,
  consent_id uuid references dhn_consent.consents(consent_id),
  principal_ref text not null,
  resource_type text not null,
  resource_ref text,
  requested_action text not null,
  purpose text,
  decision text not null check (decision in ('allow','deny','step_up')),
  policy_version text not null,
  risk_context jsonb not null default '{}'::jsonb,
  correlation_id text not null,
  decided_at timestamptz not null default now()
);
create index if not exists idx_dhn_authz_actor on dhn_consent.authorization_decisions(actor_id);
create index if not exists idx_dhn_authz_correlation on dhn_consent.authorization_decisions(correlation_id);

create table if not exists dhn_org.organizations (
  organization_id uuid primary key default gen_random_uuid(),
  organization_type text not null,
  canonical_name text not null,
  external_registry_ref text,
  status text not null default 'active' check (status in ('active','suspended','inactive')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_dhn_org_name on dhn_org.organizations(canonical_name);

create table if not exists dhn_org.practitioner_relationships (
  practitioner_relationship_id uuid primary key default gen_random_uuid(),
  actor_id text not null,
  organization_id uuid not null references dhn_org.organizations(organization_id),
  role_type text not null,
  professional_status text,
  status text not null default 'active' check (status in ('active','suspended','ended')),
  effective_at timestamptz not null default now(),
  ended_at timestamptz,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (ended_at is null or ended_at >= effective_at)
);
create index if not exists idx_dhn_practitioner_actor on dhn_org.practitioner_relationships(actor_id);
create index if not exists idx_dhn_practitioner_org on dhn_org.practitioner_relationships(organization_id);

create table if not exists dhn_biometric.verification_events (
  verification_event_id uuid primary key default gen_random_uuid(),
  actor_id text not null,
  health_credential_id uuid references dhn_identity.health_credentials(health_credential_id),
  cardiac_credential_id uuid references setc_heartbeat.cardiac_credentials(cardiac_credential_id),
  assertion_id uuid references setc_heartbeat.authentication_assertions(assertion_id),
  verification_method text not null default 'heartbeatid',
  outcome text not null check (outcome in ('succeeded','failed','degraded','step_up_required')),
  assurance_level text,
  device_reference text,
  consent_id uuid references dhn_consent.consents(consent_id),
  relying_party_ref text,
  correlation_id text not null,
  provenance jsonb not null default '{}'::jsonb,
  verified_at timestamptz not null default now(),
  unique(assertion_id)
);
create index if not exists idx_dhn_biometric_actor on dhn_biometric.verification_events(actor_id);
create index if not exists idx_dhn_biometric_correlation on dhn_biometric.verification_events(correlation_id);

create table if not exists dhn_telemetry.telemetry_events (
  telemetry_event_id uuid primary key default gen_random_uuid(),
  actor_id text not null,
  source_type text not null default 'rencat',
  source_reference text not null,
  device_reference text,
  clinical_context_ref text,
  consent_id uuid references dhn_consent.consents(consent_id),
  storage_object_ref text,
  integrity_digest text,
  processing_status text not null default 'received' check (processing_status in ('received','validated','quarantined','routed','rejected')),
  schema_version text not null,
  provenance jsonb not null default '{}'::jsonb,
  acquired_at timestamptz,
  ingested_at timestamptz not null default now(),
  correlation_id text not null
);
create index if not exists idx_dhn_telemetry_actor on dhn_telemetry.telemetry_events(actor_id);
create index if not exists idx_dhn_telemetry_status on dhn_telemetry.telemetry_events(processing_status);
create index if not exists idx_dhn_telemetry_correlation on dhn_telemetry.telemetry_events(correlation_id);

create table if not exists dhn_clinical.clinical_resource_refs (
  clinical_resource_ref_id uuid primary key default gen_random_uuid(),
  actor_id text not null,
  resource_type text not null,
  repository_ref text not null,
  sensitivity_class text not null default 'phi' check (sensitivity_class in ('phi','biometric','clinical_restricted')),
  organization_id uuid references dhn_org.organizations(organization_id),
  integrity_digest text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_dhn_clinical_actor on dhn_clinical.clinical_resource_refs(actor_id);

create table if not exists dhn_audit.audit_events (
  audit_event_id uuid primary key default gen_random_uuid(),
  actor_id text,
  event_type text not null,
  principal_ref text,
  resource_type text,
  resource_ref text,
  outcome text,
  correlation_id text not null,
  policy_version text,
  integrity_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);
create index if not exists idx_dhn_audit_correlation on dhn_audit.audit_events(correlation_id);
create index if not exists idx_dhn_audit_event_type on dhn_audit.audit_events(event_type);

create table if not exists dhn_attestation.attestations (
  attestation_id uuid primary key default gen_random_uuid(),
  actor_id text,
  attestation_type text not null,
  source_event_ref text not null,
  integrity_digest text not null,
  ledger_reference text,
  status text not null default 'pending' check (status in ('pending','recorded','failed','revoked')),
  correlation_id text not null,
  attestation_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  recorded_at timestamptz
);
create index if not exists idx_dhn_attestation_correlation on dhn_attestation.attestations(correlation_id);

create table if not exists dhn_research.research_access_grants (
  research_access_grant_id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references dhn_org.organizations(organization_id),
  principal_ref text not null,
  dataset_ref text not null,
  purpose text not null,
  access_mode text not null check (access_mode in ('deidentified','limited','controlled')),
  status text not null default 'active' check (status in ('active','suspended','revoked','expired')),
  effective_at timestamptz not null default now(),
  expires_at timestamptz,
  provenance jsonb not null default '{}'::jsonb,
  check (expires_at is null or expires_at > effective_at)
);
create index if not exists idx_dhn_research_org on dhn_research.research_access_grants(organization_id);

create table if not exists dhn_integration.settlement_references (
  settlement_reference_id uuid primary key default gen_random_uuid(),
  actor_id text,
  service_reference text not null,
  economic_reference text not null,
  settlement_system text not null default 'source_coin',
  status text not null default 'referenced' check (status in ('referenced','submitted','settled','failed','voided')),
  correlation_id text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_dhn_settlement_correlation on dhn_integration.settlement_references(correlation_id);

alter table dhn_identity.health_credentials enable row level security;
alter table dhn_identity.identity_mappings enable row level security;
alter table dhn_consent.consents enable row level security;
alter table dhn_consent.authorization_decisions enable row level security;
alter table dhn_org.organizations enable row level security;
alter table dhn_org.practitioner_relationships enable row level security;
alter table dhn_biometric.verification_events enable row level security;
alter table dhn_telemetry.telemetry_events enable row level security;
alter table dhn_clinical.clinical_resource_refs enable row level security;
alter table dhn_audit.audit_events enable row level security;
alter table dhn_attestation.attestations enable row level security;
alter table dhn_research.research_access_grants enable row level security;
alter table dhn_integration.settlement_references enable row level security;

revoke all on schema dhn_identity, dhn_consent, dhn_org, dhn_biometric, dhn_telemetry, dhn_clinical, dhn_audit, dhn_attestation, dhn_research, dhn_integration from public, anon, authenticated;
grant usage on schema dhn_identity, dhn_consent, dhn_org, dhn_biometric, dhn_telemetry, dhn_clinical, dhn_audit, dhn_attestation, dhn_research, dhn_integration to service_role;

grant all privileges on all tables in schema dhn_identity, dhn_consent, dhn_org, dhn_biometric, dhn_telemetry, dhn_clinical, dhn_audit, dhn_attestation, dhn_research, dhn_integration to service_role;
revoke all privileges on all tables in schema dhn_identity, dhn_consent, dhn_org, dhn_biometric, dhn_telemetry, dhn_clinical, dhn_audit, dhn_attestation, dhn_research, dhn_integration from anon, authenticated;

alter default privileges in schema dhn_identity revoke all on tables from anon, authenticated;
alter default privileges in schema dhn_consent revoke all on tables from anon, authenticated;
alter default privileges in schema dhn_org revoke all on tables from anon, authenticated;
alter default privileges in schema dhn_biometric revoke all on tables from anon, authenticated;
alter default privileges in schema dhn_telemetry revoke all on tables from anon, authenticated;
alter default privileges in schema dhn_clinical revoke all on tables from anon, authenticated;
alter default privileges in schema dhn_audit revoke all on tables from anon, authenticated;
alter default privileges in schema dhn_attestation revoke all on tables from anon, authenticated;
alter default privileges in schema dhn_research revoke all on tables from anon, authenticated;
alter default privileges in schema dhn_integration revoke all on tables from anon, authenticated;
