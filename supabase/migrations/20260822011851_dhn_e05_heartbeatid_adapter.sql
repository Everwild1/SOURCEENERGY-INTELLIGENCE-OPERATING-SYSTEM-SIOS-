create table if not exists dhn_biometric.adapter_evaluations (
  adapter_evaluation_id uuid primary key default gen_random_uuid(),
  actor_id text not null,
  health_credential_id uuid references dhn_identity.health_credentials(health_credential_id),
  cardiac_credential_id uuid not null references setc_heartbeat.cardiac_credentials(cardiac_credential_id),
  assertion_id uuid not null references setc_heartbeat.authentication_assertions(assertion_id),
  device_attestation_id uuid references setc_heartbeat.device_attestations(device_attestation_id),
  verification_event_id uuid references dhn_biometric.verification_events(verification_event_id),
  decision text not null check (decision in ('accept','deny','step_up')),
  reason_code text not null,
  assurance_level text,
  match_confidence numeric check (match_confidence is null or (match_confidence >= 0 and match_confidence <= 1)),
  liveness_status text,
  continuity_status text,
  device_trust_decision text,
  source_assertion_issued_at timestamptz,
  source_assertion_expires_at timestamptz,
  policy_version text not null,
  correlation_id text not null,
  evaluation_metadata jsonb not null default '{}'::jsonb,
  evaluated_at timestamptz not null default now(),
  unique(assertion_id)
);
create index if not exists idx_dhn_adapter_actor_time on dhn_biometric.adapter_evaluations(actor_id, evaluated_at desc);
create index if not exists idx_dhn_adapter_cardiac_credential on dhn_biometric.adapter_evaluations(cardiac_credential_id);
create index if not exists idx_dhn_adapter_device_attestation on dhn_biometric.adapter_evaluations(device_attestation_id);
create index if not exists idx_dhn_adapter_verification_event on dhn_biometric.adapter_evaluations(verification_event_id);
create index if not exists idx_dhn_adapter_correlation on dhn_biometric.adapter_evaluations(correlation_id);
alter table dhn_biometric.adapter_evaluations enable row level security;
revoke all privileges on dhn_biometric.adapter_evaluations from public, anon, authenticated;
grant all privileges on dhn_biometric.adapter_evaluations to service_role;
alter default privileges in schema dhn_biometric revoke all on tables from anon, authenticated;
