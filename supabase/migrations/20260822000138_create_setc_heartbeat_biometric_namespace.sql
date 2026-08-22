-- SETC-HB-001 biometric identity namespace.
-- Mirrors applied Supabase migration 20260822000138.
-- Raw cardiac signals and reusable biometric templates MUST NOT be stored here.

create schema if not exists setc_heartbeat;

create table if not exists setc_heartbeat.cardiac_credentials (
  cardiac_credential_id uuid primary key default gen_random_uuid(),
  actor_id text not null,
  template_id uuid not null unique default gen_random_uuid(),
  template_version text not null,
  algorithm_version text not null,
  status text not null default 'active' check (status in ('active','suspended','revoked')),
  provenance jsonb not null default '{}'::jsonb,
  enrolled_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists setc_heartbeat.authentication_assertions (
  assertion_id uuid primary key default gen_random_uuid(),
  cardiac_credential_id uuid not null references setc_heartbeat.cardiac_credentials(cardiac_credential_id),
  actor_id text not null,
  authentication_method text not null,
  assurance_level text not null,
  match_confidence numeric(6,5) not null check (match_confidence >= 0 and match_confidence <= 1),
  liveness_status text not null check (liveness_status in ('succeeded','failed','degraded')),
  continuity_status text check (continuity_status in ('succeeded','failed','degraded')),
  device_trust_reference text not null,
  template_version text not null,
  algorithm_version text not null,
  policy_version text not null,
  correlation_id text not null,
  integrity_metadata jsonb not null default '{}'::jsonb,
  issued_at timestamptz not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (expires_at > issued_at)
);

alter table setc_heartbeat.cardiac_credentials enable row level security;
alter table setc_heartbeat.authentication_assertions enable row level security;

revoke all on schema setc_heartbeat from public, anon, authenticated;
revoke all on all tables in schema setc_heartbeat from public, anon, authenticated;
grant usage on schema setc_heartbeat to service_role;
grant select, insert, update on setc_heartbeat.cardiac_credentials to service_role;
grant select, insert on setc_heartbeat.authentication_assertions to service_role;

create policy heartbeat_credentials_service_role on setc_heartbeat.cardiac_credentials
for all to service_role using (true) with check (true);
create policy heartbeat_assertions_service_role_read on setc_heartbeat.authentication_assertions
for select to service_role using (true);
create policy heartbeat_assertions_service_role_insert on setc_heartbeat.authentication_assertions
for insert to service_role with check (true);
