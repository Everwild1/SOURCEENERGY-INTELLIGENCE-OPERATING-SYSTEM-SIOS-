-- VZC-E04 — Connected Infrastructure & Device Trust control boundary
create table vzc.device_bindings (
 device_binding_id uuid primary key default gen_random_uuid(), device_key text not null unique, device_type text not null,
 owner_organization_binding_id uuid references vzc.organization_bindings(binding_id) on delete restrict,
 spatial_binding_id uuid references vzc.spatial_bindings(binding_id) on delete restrict,
 trust_state text not null default 'registered' check (trust_state in ('registered','provisioning','trusted','degraded','quarantined','revoked','retired')),
 operational_health text not null default 'unknown' check (operational_health in ('unknown','healthy','degraded','failed','offline')),
 observation_capable boolean not null default true, control_capable boolean not null default false,
 credential_reference text, firmware_reference text, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table vzc.telemetry_observations (
 telemetry_id uuid primary key default gen_random_uuid(), device_binding_id uuid not null references vzc.device_bindings(device_binding_id) on delete restrict,
 observation_id uuid references vzc.observation_registry(observation_id) on delete restrict, telemetry_type text not null,
 observed_at timestamptz not null, received_at timestamptz not null default now(), device_trust_state text not null,
 quality_state text not null default 'unassessed' check (quality_state in ('unassessed','provisional','validated','degraded','rejected')),
 payload jsonb not null default '{}'::jsonb, provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table vzc.control_requests (
 control_request_id uuid primary key default gen_random_uuid(), target_device_binding_id uuid not null references vzc.device_bindings(device_binding_id) on delete restrict,
 requested_action text not null, requested_parameters jsonb not null default '{}'::jsonb,
 originating_recommendation_id uuid references vzc.risk_recommendations(recommendation_id) on delete restrict,
 request_state text not null default 'proposed' check (request_state in ('proposed','pending_authority','authorized','rejected','expired','cancelled')),
 authority_reference text, requested_by_ref text not null, requested_at timestamptz not null default now(), expires_at timestamptz, safety_case_reference text,
 check (request_state <> 'authorized' or authority_reference is not null), check (expires_at is null or expires_at > requested_at)
);
create table vzc.control_authority_decisions (
 decision_id uuid primary key default gen_random_uuid(), control_request_id uuid not null references vzc.control_requests(control_request_id) on delete restrict,
 decision text not null check (decision in ('authorized','rejected','revoked')), authority_reference text not null,
 decision_maker_ref text not null, decision_at timestamptz not null default now(), bounded_scope jsonb not null default '{}'::jsonb,
 policy_reference text, notes text, unique(control_request_id, decision, decision_at)
);
create table vzc.control_execution_receipts (
 execution_receipt_id uuid primary key default gen_random_uuid(), control_request_id uuid not null references vzc.control_requests(control_request_id) on delete restrict,
 authority_decision_id uuid not null references vzc.control_authority_decisions(decision_id) on delete restrict,
 executing_system_ref text not null, execution_state text not null check (execution_state in ('accepted','executed','failed','aborted','rolled_back','unknown')),
 executed_at timestamptz, observed_result jsonb not null default '{}'::jsonb, fail_safe_state text, provenance jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index vzc_device_bindings_spatial_idx on vzc.device_bindings(spatial_binding_id) where spatial_binding_id is not null;
create index vzc_telemetry_device_time_idx on vzc.telemetry_observations(device_binding_id, observed_at desc);
create index vzc_control_requests_target_state_idx on vzc.control_requests(target_device_binding_id, request_state, requested_at desc);
create index vzc_control_decisions_request_idx on vzc.control_authority_decisions(control_request_id, decision_at desc);
create index vzc_control_receipts_request_idx on vzc.control_execution_receipts(control_request_id, created_at desc);
alter table vzc.device_bindings enable row level security; alter table vzc.telemetry_observations enable row level security;
alter table vzc.control_requests enable row level security; alter table vzc.control_authority_decisions enable row level security; alter table vzc.control_execution_receipts enable row level security;
create policy vzc_device_bindings_service_role_all on vzc.device_bindings for all to service_role using (true) with check (true);
create policy vzc_telemetry_observations_service_role_all on vzc.telemetry_observations for all to service_role using (true) with check (true);
create policy vzc_control_requests_service_role_all on vzc.control_requests for all to service_role using (true) with check (true);
create policy vzc_control_authority_decisions_service_role_all on vzc.control_authority_decisions for all to service_role using (true) with check (true);
create policy vzc_control_execution_receipts_service_role_all on vzc.control_execution_receipts for all to service_role using (true) with check (true);
grant select, insert, update, delete on vzc.device_bindings, vzc.telemetry_observations, vzc.control_requests, vzc.control_authority_decisions, vzc.control_execution_receipts to service_role;
comment on table vzc.device_bindings is 'VZC safety-context device projection. Device identity/trust does not by itself confer control authority.';
comment on table vzc.control_requests is 'Bounded VZC control proposal. Predictive or recommendation origin cannot self-authorize the request.';
comment on table vzc.control_authority_decisions is 'Explicit authority evidence for a bounded VZC control request.';
comment on table vzc.control_execution_receipts is 'Execution evidence from the authoritative control system; existence of a request or authorization does not prove execution.';
