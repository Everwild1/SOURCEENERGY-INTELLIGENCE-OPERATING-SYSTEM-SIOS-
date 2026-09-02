create table vzc.emergency_incident_bindings (
  emergency_binding_id uuid primary key default gen_random_uuid(),
  safety_event_id uuid not null references vzc.safety_events(safety_event_id) on delete restrict,
  source_schema text not null,
  source_table text not null,
  source_record_key text not null,
  incident_role text not null check (incident_role in ('emergency_incident','responder_event','health_incident','logistics_incident','other')),
  spatial_binding_id uuid references vzc.spatial_bindings(binding_id) on delete restrict,
  evidence_state text not null default 'evidence_identified' check (evidence_state in ('concept','evidence_identified','validated','integration_designed','prototype','pilot_approved','pilot_active','production_approved')),
  authority_reference text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(source_schema, source_table, source_record_key, incident_role)
);

create table vzc.emergency_coordination_requests (
  coordination_request_id uuid primary key default gen_random_uuid(),
  emergency_binding_id uuid not null references vzc.emergency_incident_bindings(emergency_binding_id) on delete restrict,
  coordination_type text not null check (coordination_type in ('responder_mobility','route_awareness','facility_awareness','resource_awareness','handoff_context','other')),
  request_state text not null default 'proposed' check (request_state in ('proposed','shared','acknowledged','authority_accepted','authority_declined','closed')),
  requested_by_ref text not null,
  competent_authority_ref text,
  authority_reference text,
  payload jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (request_state not in ('authority_accepted','authority_declined') or (competent_authority_ref is not null and authority_reference is not null))
);

create table vzc.health_context_references (
  health_context_id uuid primary key default gen_random_uuid(),
  emergency_binding_id uuid not null references vzc.emergency_incident_bindings(emergency_binding_id) on delete restrict,
  source_schema text not null,
  source_table text not null,
  source_record_key text not null,
  context_class text not null check (context_class in ('facility_capability','clinical_resource_reference','interoperability_exchange','consent_reference','health_credential_reference','other')),
  purpose text not null,
  consent_or_legal_basis_ref text,
  contains_person_level_data boolean not null default false,
  contains_clinical_data boolean not null default false,
  data_minimization_state text not null default 'reference_only' check (data_minimization_state in ('reference_only','minimum_necessary','approved_bounded_copy')),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check ((not contains_person_level_data and not contains_clinical_data) or consent_or_legal_basis_ref is not null),
  unique(emergency_binding_id, source_schema, source_table, source_record_key, context_class)
);

create table vzc.emergency_authority_boundaries (
  emergency_authority_boundary_id uuid primary key default gen_random_uuid(),
  emergency_binding_id uuid not null references vzc.emergency_incident_bindings(emergency_binding_id) on delete restrict,
  authority_domain text not null check (authority_domain in ('dispatch','incident_command','emergency_operations','clinical_decision','patient_care','facility_operations','other')),
  competent_authority_ref text not null,
  evidence_reference text not null,
  boundary_state text not null default 'evidence_identified' check (boundary_state in ('evidence_identified','validated','expired','revoked')),
  valid_from timestamptz,
  valid_until timestamptz,
  created_at timestamptz not null default now(),
  check (valid_until is null or valid_from is null or valid_until > valid_from),
  unique(emergency_binding_id, authority_domain, competent_authority_ref)
);

create index vzc_emergency_incident_safety_event_idx on vzc.emergency_incident_bindings(safety_event_id);
create index vzc_emergency_incident_spatial_idx on vzc.emergency_incident_bindings(spatial_binding_id) where spatial_binding_id is not null;
create index vzc_emergency_coordination_binding_idx on vzc.emergency_coordination_requests(emergency_binding_id, request_state);
create index vzc_health_context_binding_idx on vzc.health_context_references(emergency_binding_id, context_class);
create index vzc_emergency_authority_binding_idx on vzc.emergency_authority_boundaries(emergency_binding_id, authority_domain);

alter table vzc.emergency_incident_bindings enable row level security;
alter table vzc.emergency_coordination_requests enable row level security;
alter table vzc.health_context_references enable row level security;
alter table vzc.emergency_authority_boundaries enable row level security;

revoke all on table vzc.emergency_incident_bindings, vzc.emergency_coordination_requests, vzc.health_context_references, vzc.emergency_authority_boundaries from anon, authenticated;
grant select, insert, update, delete on vzc.emergency_incident_bindings, vzc.emergency_coordination_requests, vzc.health_context_references, vzc.emergency_authority_boundaries to service_role;

create policy vzc_emergency_incident_service_role_all on vzc.emergency_incident_bindings for all to service_role using (true) with check (true);
create policy vzc_emergency_coordination_service_role_all on vzc.emergency_coordination_requests for all to service_role using (true) with check (true);
create policy vzc_health_context_service_role_all on vzc.health_context_references for all to service_role using (true) with check (true);
create policy vzc_emergency_authority_service_role_all on vzc.emergency_authority_boundaries for all to service_role using (true) with check (true);

comment on table vzc.emergency_incident_bindings is 'VZC safety coordination references to authoritative emergency, health or operating-domain incidents. VZC is not dispatch authority or incident commander.';
comment on table vzc.emergency_coordination_requests is 'Non-command coordination envelope for responder mobility and emergency context. Authority acceptance requires explicit competent-authority evidence.';
comment on table vzc.health_context_references is 'Purpose-limited references to health context. Sensitive person-level or clinical context requires explicit consent or lawful-basis evidence and remains outside VZC clinical authority.';
comment on table vzc.emergency_authority_boundaries is 'Evidence-backed emergency and clinical authority boundaries; VZC coordination never transfers dispatch, incident-command or clinical-decision authority.';
