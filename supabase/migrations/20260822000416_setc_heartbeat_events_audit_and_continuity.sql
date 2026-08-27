-- SETC-HB-001 event, audit and continuity persistence.
-- Mirrors applied Supabase migration 20260822000416.

create table if not exists setc_heartbeat.heartbeat_events (
  event_id uuid primary key default gen_random_uuid(),
  event_type text not null check (event_type in ('CardiacEnrollmentCompleted','CardiacAuthenticationSucceeded','CardiacAuthenticationFailed','CardiacContinuityDegraded','CardiacCredentialRevoked','CardiacSensorIntegrityFailed')),
  actor_id text not null,
  correlation_id text not null,
  causation_id text,
  assertion_id uuid references setc_heartbeat.authentication_assertions(assertion_id),
  cardiac_credential_id uuid references setc_heartbeat.cardiac_credentials(cardiac_credential_id),
  decision text check (decision in ('succeeded','failed','degraded','revoked')),
  schema_version text not null,
  algorithm_version text not null,
  policy_version text not null,
  integrity_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null,
  recorded_at timestamptz not null default now()
);

create table if not exists setc_heartbeat.audit_attestations (
  audit_attestation_id uuid primary key default gen_random_uuid(),
  assertion_id uuid not null references setc_heartbeat.authentication_assertions(assertion_id),
  actor_id text not null,
  requested_action text not null,
  policy_decision text not null check (policy_decision in ('allow','deny','step_up')),
  action_outcome text not null,
  correlation_id text not null,
  assertion_issued_at timestamptz not null,
  assertion_expires_at timestamptz not null,
  policy_version text not null,
  algorithm_version text not null,
  device_trust_reference text not null,
  integrity_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists setc_heartbeat.continuity_state (
  actor_id text primary key,
  cardiac_credential_id uuid not null references setc_heartbeat.cardiac_credentials(cardiac_credential_id),
  current_status text not null check (current_status in ('succeeded','failed','degraded','revoked')),
  last_assertion_id uuid references setc_heartbeat.authentication_assertions(assertion_id),
  last_event_id uuid references setc_heartbeat.heartbeat_events(event_id),
  last_evaluated_at timestamptz not null,
  updated_at timestamptz not null default now()
);

alter table setc_heartbeat.heartbeat_events enable row level security;
alter table setc_heartbeat.audit_attestations enable row level security;
alter table setc_heartbeat.continuity_state enable row level security;
revoke all on setc_heartbeat.heartbeat_events, setc_heartbeat.audit_attestations, setc_heartbeat.continuity_state from public, anon, authenticated;
grant select, insert on setc_heartbeat.heartbeat_events to service_role;
grant select, insert on setc_heartbeat.audit_attestations to service_role;
grant select, insert, update on setc_heartbeat.continuity_state to service_role;

create policy heartbeat_events_service_role on setc_heartbeat.heartbeat_events for all to service_role using (true) with check (true);
create policy heartbeat_audit_service_role on setc_heartbeat.audit_attestations for all to service_role using (true) with check (true);
create policy heartbeat_continuity_service_role on setc_heartbeat.continuity_state for all to service_role using (true) with check (true);

create or replace function setc_heartbeat.enforce_assertion_credential_state()
returns trigger language plpgsql security invoker set search_path = setc_heartbeat, public as $$
declare v_status text;
begin
  select status into v_status from setc_heartbeat.cardiac_credentials where cardiac_credential_id = new.cardiac_credential_id;
  if v_status is distinct from 'active' then raise exception 'cardiac credential is not active'; end if;
  return new;
end;
$$;

drop trigger if exists trg_hb_assertion_active_credential on setc_heartbeat.authentication_assertions;
create trigger trg_hb_assertion_active_credential before insert on setc_heartbeat.authentication_assertions
for each row execute function setc_heartbeat.enforce_assertion_credential_state();
