create table vzc.mobility_safety_bindings (
  mobility_binding_id uuid primary key default gen_random_uuid(),
  mode text not null check (mode in ('road_logistics','rail','port','drone','multimodal')),
  source_schema text not null,
  source_table text not null,
  source_record_key text not null,
  binding_role text not null check (binding_role in ('corridor','shipment','asset','network','segment','terminal','hub','zone','mission','facility','other')),
  operator_organization_binding_id uuid references vzc.organization_bindings(binding_id) on delete restrict,
  spatial_binding_id uuid references vzc.spatial_bindings(binding_id) on delete restrict,
  evidence_state text not null default 'evidence_identified' check (evidence_state in ('concept','evidence_identified','validated','integration_designed','prototype','pilot_approved','pilot_active','production_approved')),
  authority_reference text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(source_schema, source_table, source_record_key, binding_role)
);

create table vzc.multimodal_safety_events (
  multimodal_event_id uuid primary key default gen_random_uuid(),
  mobility_binding_id uuid not null references vzc.mobility_safety_bindings(mobility_binding_id) on delete restrict,
  safety_event_id uuid references vzc.safety_events(safety_event_id) on delete restrict,
  mode text not null check (mode in ('road_logistics','rail','port','drone','multimodal')),
  event_type text not null,
  operational_state text,
  safety_state text not null default 'observed' check (safety_state in ('observed','assessed','hazard_identified','intervention_recommended','authority_confirmed','resolved','closed')),
  observed_at timestamptz not null,
  authority_reference text,
  payload jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (safety_state <> 'authority_confirmed' or authority_reference is not null)
);

create table vzc.mobility_authority_boundaries (
  boundary_id uuid primary key default gen_random_uuid(),
  mobility_binding_id uuid not null references vzc.mobility_safety_bindings(mobility_binding_id) on delete restrict,
  authority_domain text not null check (authority_domain in ('movement','dispatch','custody','rail_operations','port_operations','airspace','flight_operations','infrastructure_control','other')),
  competent_authority_ref text not null,
  evidence_reference text not null,
  boundary_state text not null default 'evidence_identified' check (boundary_state in ('evidence_identified','validated','expired','revoked')),
  valid_from timestamptz,
  valid_until timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  check (valid_until is null or valid_from is null or valid_until > valid_from),
  unique(mobility_binding_id, authority_domain, competent_authority_ref)
);

create table vzc.drone_safety_authority_checks (
  drone_check_id uuid primary key default gen_random_uuid(),
  mobility_binding_id uuid not null references vzc.mobility_safety_bindings(mobility_binding_id) on delete restrict,
  mission_reference text,
  jurisdiction_code text,
  airspace_authority_ref text,
  flight_authorization_ref text,
  authorization_state text not null default 'unverified' check (authorization_state in ('unverified','evidence_identified','validated','expired','revoked','not_required')),
  checked_at timestamptz not null default now(),
  provenance jsonb not null default '{}'::jsonb,
  check (authorization_state <> 'validated' or (airspace_authority_ref is not null and flight_authorization_ref is not null))
);

create index vzc_mobility_safety_bindings_mode_idx on vzc.mobility_safety_bindings(mode, evidence_state);
create index vzc_mobility_safety_bindings_org_idx on vzc.mobility_safety_bindings(operator_organization_binding_id) where operator_organization_binding_id is not null;
create index vzc_mobility_safety_bindings_spatial_idx on vzc.mobility_safety_bindings(spatial_binding_id) where spatial_binding_id is not null;
create index vzc_multimodal_safety_events_binding_time_idx on vzc.multimodal_safety_events(mobility_binding_id, observed_at desc);
create index vzc_multimodal_safety_events_safety_event_idx on vzc.multimodal_safety_events(safety_event_id) where safety_event_id is not null;
create index vzc_mobility_authority_boundaries_binding_idx on vzc.mobility_authority_boundaries(mobility_binding_id, authority_domain);
create index vzc_drone_safety_authority_checks_binding_idx on vzc.drone_safety_authority_checks(mobility_binding_id, checked_at desc);

alter table vzc.mobility_safety_bindings enable row level security;
alter table vzc.multimodal_safety_events enable row level security;
alter table vzc.mobility_authority_boundaries enable row level security;
alter table vzc.drone_safety_authority_checks enable row level security;

revoke all on table vzc.mobility_safety_bindings, vzc.multimodal_safety_events, vzc.mobility_authority_boundaries, vzc.drone_safety_authority_checks from anon, authenticated;
grant select, insert, update, delete on vzc.mobility_safety_bindings, vzc.multimodal_safety_events, vzc.mobility_authority_boundaries, vzc.drone_safety_authority_checks to service_role;

comment on table vzc.mobility_safety_bindings is 'VZC safety-context references to authoritative logistics, rail, port and drone records. VZC does not become operator, dispatcher, custodian, rail/port authority or airspace authority.';
comment on table vzc.multimodal_safety_events is 'Cross-modal VZC safety projection; operational state remains sourced from the competent operating domain.';
comment on table vzc.mobility_authority_boundaries is 'Evidence-backed record of competent operational authority. VZC coordination does not transfer authority.';
comment on table vzc.drone_safety_authority_checks is 'Drone safety authorization evidence. Spatial representation or mission reference alone never establishes airspace or flight authorization.';
