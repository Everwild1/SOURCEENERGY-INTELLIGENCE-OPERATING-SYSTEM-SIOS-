-- RECONCILIATION BASELINE, NOT THE ORIGINAL HISTORICAL MIGRATION BODY.
-- Reconstructed from the live production schema for migration version 20260822012846.
-- Purpose: preserve clean replay and document provenance without misrepresenting history.

create schema if not exists dhn_ops;

create table if not exists dhn_ops.security_events (
  security_event_id uuid primary key default gen_random_uuid(),
  event_class text not null check (event_class in ('authorization_denied','step_up_required','telemetry_quarantined','telemetry_rejected','settlement_restricted','ledger_anchor_failed','credential_revoked','device_trust_degraded','integrity_failure','privileged_action','other')),
  severity text not null default 'info' check (severity in ('info','low','medium','high','critical')),
  component text not null,
  actor_reference_digest text,
  resource_reference_digest text,
  correlation_id text not null,
  policy_version text,
  reason_code text,
  event_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  check (event_metadata::text !~* '"(patient_id|actor_id|principal_ref|health_credential_id|cardiac_credential_id|clinical_resource_ref_id|storage_object_ref|payload_location_ref|diagnosis|medication|ecg|waveform|samples|raw_payload|biometric_template|phi)"[[:space:]]*:')
);

create table if not exists dhn_ops.service_health_observations (
  health_observation_id uuid primary key default gen_random_uuid(),
  component text not null,
  environment text not null default 'production',
  status text not null check (status in ('healthy','degraded','offline','maintenance')),
  source text not null,
  correlation_id text,
  metrics jsonb not null default '{}'::jsonb,
  observed_at timestamptz not null default now(),
  check (metrics::text !~* '"(patient_id|actor_id|principal_ref|health_credential_id|cardiac_credential_id|clinical_resource_ref_id|storage_object_ref|payload_location_ref|diagnosis|medication|ecg|waveform|samples|raw_payload|biometric_template|phi)"[[:space:]]*:')
);

create table if not exists dhn_ops.operational_controls (
  control_code text primary key,
  control_name text not null,
  control_family text not null check (control_family in ('access','privacy','integrity','availability','settlement','audit','deployment','incident_response')),
  required boolean not null default true,
  status text not null default 'implemented' check (status in ('implemented','verified','degraded','exception','retired')),
  evidence_reference text,
  control_version text not null,
  last_verified_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists idx_dhn_ops_security_class_time on dhn_ops.security_events(event_class, occurred_at desc);
create index if not exists idx_dhn_ops_security_correlation on dhn_ops.security_events(correlation_id);
create index if not exists idx_dhn_ops_security_severity_time on dhn_ops.security_events(severity, occurred_at desc);
create index if not exists idx_dhn_ops_health_component_time on dhn_ops.service_health_observations(component, observed_at desc);
create index if not exists idx_dhn_ops_health_status_time on dhn_ops.service_health_observations(status, observed_at desc);

alter table dhn_ops.security_events enable row level security;
alter table dhn_ops.service_health_observations enable row level security;
alter table dhn_ops.operational_controls enable row level security;

revoke all on schema dhn_ops from public, anon, authenticated;
grant usage on schema dhn_ops to service_role;
revoke all privileges on dhn_ops.security_events, dhn_ops.service_health_observations, dhn_ops.operational_controls from public, anon, authenticated;
grant all privileges on dhn_ops.security_events, dhn_ops.service_health_observations, dhn_ops.operational_controls to service_role;

create policy dhn_ops_security_service_role on dhn_ops.security_events for all to service_role using (true) with check (true);
create policy dhn_ops_health_service_role on dhn_ops.service_health_observations for all to service_role using (true) with check (true);
create policy dhn_ops_controls_service_role on dhn_ops.operational_controls for all to service_role using (true) with check (true);
