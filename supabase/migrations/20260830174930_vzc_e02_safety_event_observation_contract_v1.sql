create table vzc.observation_registry (
  observation_id uuid primary key default gen_random_uuid(),
  observation_type text not null,
  subject_type text not null,
  subject_key text not null,
  source_system text not null,
  source_reference text,
  source_device_ref text,
  spatial_binding_id uuid references vzc.spatial_bindings(binding_id) on delete restrict,
  observed_at timestamptz not null,
  received_at timestamptz not null default now(),
  quality_state text not null default 'unassessed' check (quality_state in ('unassessed','provisional','validated','degraded','rejected')),
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),
  payload jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table vzc.safety_events (
  safety_event_id uuid primary key default gen_random_uuid(),
  event_type text not null,
  subject_type text not null,
  subject_key text not null,
  spatial_binding_id uuid references vzc.spatial_bindings(binding_id) on delete restrict,
  event_state text not null default 'detected' check (event_state in ('detected','reported','corroborated','authority_confirmed','response_initiated','active','cleared','closed','rejected')),
  severity_class text check (severity_class is null or severity_class in ('informational','low','moderate','high','critical')),
  first_observed_at timestamptz not null,
  last_observed_at timestamptz not null,
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),
  authority_reference text,
  evidence_state text not null default 'evidence_identified' check (evidence_state in ('concept','evidence_identified','validated','integration_designed','prototype','pilot_approved','pilot_active','production_approved')),
  payload jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (last_observed_at >= first_observed_at),
  check (event_state <> 'authority_confirmed' or authority_reference is not null)
);

create table vzc.safety_event_observations (
  safety_event_id uuid not null references vzc.safety_events(safety_event_id) on delete cascade,
  observation_id uuid not null references vzc.observation_registry(observation_id) on delete restrict,
  relationship text not null default 'supports' check (relationship in ('supports','corroborates','contradicts','contextualizes','supersedes')),
  created_at timestamptz not null default now(),
  primary key (safety_event_id, observation_id)
);

create index vzc_observation_subject_time_idx on vzc.observation_registry(subject_type, subject_key, observed_at desc);
create index vzc_observation_spatial_fk_idx on vzc.observation_registry(spatial_binding_id) where spatial_binding_id is not null;
create index vzc_safety_events_subject_time_idx on vzc.safety_events(subject_type, subject_key, first_observed_at desc);
create index vzc_safety_events_state_idx on vzc.safety_events(event_state, first_observed_at desc);
create index vzc_safety_events_spatial_fk_idx on vzc.safety_events(spatial_binding_id) where spatial_binding_id is not null;
create index vzc_safety_event_observations_observation_fk_idx on vzc.safety_event_observations(observation_id);

alter table vzc.observation_registry enable row level security;
alter table vzc.safety_events enable row level security;
alter table vzc.safety_event_observations enable row level security;

create policy vzc_observation_registry_service_role_all on vzc.observation_registry for all to service_role using (true) with check (true);
create policy vzc_safety_events_service_role_all on vzc.safety_events for all to service_role using (true) with check (true);
create policy vzc_safety_event_observations_service_role_all on vzc.safety_event_observations for all to service_role using (true) with check (true);

grant select, insert, update, delete on vzc.observation_registry, vzc.safety_events, vzc.safety_event_observations to service_role;

comment on table vzc.observation_registry is 'Immutable-source-oriented VZC observation envelope. Observations are evidence assertions, not authority-confirmed incidents or commands.';
comment on table vzc.safety_events is 'Correlated mobility-safety event records derived from one or more observations. Authority-confirmed state requires an explicit authority reference.';
comment on table vzc.safety_event_observations is 'Evidence graph connecting raw/governed observations to VZC safety events without collapsing observation into authoritative event state.';
