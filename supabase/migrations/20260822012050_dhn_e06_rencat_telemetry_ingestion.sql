create table if not exists dhn_telemetry.source_registry (
  telemetry_source_id uuid primary key default gen_random_uuid(),
  source_reference text not null unique,
  source_type text not null default 'rencat',
  device_reference text,
  organization_id uuid references dhn_org.organizations(organization_id),
  trust_status text not null default 'pending' check (trust_status in ('pending','trusted','degraded','untrusted','revoked')),
  schema_version text,
  trust_policy_version text not null default 'dhn-rencat-e06-v1',
  provenance jsonb not null default '{}'::jsonb,
  activated_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((trust_status = 'revoked' and revoked_at is not null) or trust_status <> 'revoked')
);

create table if not exists dhn_telemetry.ingestion_evaluations (
  ingestion_evaluation_id uuid primary key default gen_random_uuid(),
  telemetry_event_id uuid not null references dhn_telemetry.telemetry_events(telemetry_event_id),
  telemetry_source_id uuid references dhn_telemetry.source_registry(telemetry_source_id),
  actor_id text not null,
  consent_id uuid references dhn_consent.consents(consent_id),
  health_credential_id uuid references dhn_identity.health_credentials(health_credential_id),
  clinical_resource_ref_id uuid references dhn_clinical.clinical_resource_refs(clinical_resource_ref_id),
  decision text not null check (decision in ('validated','quarantined','rejected')),
  reason_code text not null,
  subject_resolution_status text not null check (subject_resolution_status in ('resolved','ambiguous','missing')),
  consent_status text not null check (consent_status in ('active','missing','invalid','expired','revoked')),
  source_trust_status text not null,
  schema_status text not null check (schema_status in ('valid','unsupported','missing')),
  integrity_status text not null check (integrity_status in ('valid','missing','failed','unchecked')),
  policy_version text not null default 'dhn-rencat-e06-v1',
  correlation_id text not null,
  evaluation_metadata jsonb not null default '{}'::jsonb,
  evaluated_at timestamptz not null default now(),
  unique(telemetry_event_id)
);

create index if not exists idx_dhn_telemetry_source_org on dhn_telemetry.source_registry(organization_id);
create index if not exists idx_dhn_telemetry_source_trust on dhn_telemetry.source_registry(trust_status);
create index if not exists idx_dhn_telemetry_eval_actor_time on dhn_telemetry.ingestion_evaluations(actor_id, evaluated_at desc);
create index if not exists idx_dhn_telemetry_eval_source on dhn_telemetry.ingestion_evaluations(telemetry_source_id);
create index if not exists idx_dhn_telemetry_eval_consent on dhn_telemetry.ingestion_evaluations(consent_id);
create index if not exists idx_dhn_telemetry_eval_credential on dhn_telemetry.ingestion_evaluations(health_credential_id);
create index if not exists idx_dhn_telemetry_eval_clinical on dhn_telemetry.ingestion_evaluations(clinical_resource_ref_id);
create index if not exists idx_dhn_telemetry_eval_correlation on dhn_telemetry.ingestion_evaluations(correlation_id);

alter table dhn_telemetry.source_registry enable row level security;
alter table dhn_telemetry.ingestion_evaluations enable row level security;
revoke all privileges on dhn_telemetry.source_registry, dhn_telemetry.ingestion_evaluations from public, anon, authenticated;
grant all privileges on dhn_telemetry.source_registry, dhn_telemetry.ingestion_evaluations to service_role;
alter default privileges in schema dhn_telemetry revoke all on tables from anon, authenticated;
