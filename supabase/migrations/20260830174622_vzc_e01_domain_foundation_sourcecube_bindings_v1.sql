create schema if not exists vzc;

revoke all on schema vzc from public, anon, authenticated;
grant usage on schema vzc to service_role;

create table vzc.domain_registry (
  domain_code text primary key,
  name text not null,
  mission text not null,
  ecosystem_position text not null default 'SourceEnergy One / SIOS -> SourceCube -> VZC Mission Application Domain',
  lifecycle_state text not null default 'concept' check (lifecycle_state in ('concept','evidence_identified','validated','integration_designed','prototype','pilot_approved','pilot_active','production_approved')),
  production_authority boolean not null default false,
  canonical_control_ref text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table vzc.source_bindings (
  binding_id uuid primary key default gen_random_uuid(),
  subject_type text not null,
  subject_key text not null,
  source_schema text not null,
  source_relation text not null,
  source_key text not null,
  authority_class text not null check (authority_class in ('authoritative','governed_reference','candidate_evidence','derived_reference')),
  purpose text not null,
  evidence_state text not null default 'concept' check (evidence_state in ('concept','evidence_identified','validated','integration_designed','prototype','pilot_approved','pilot_active','production_approved')),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(subject_type, subject_key, source_schema, source_relation, source_key)
);

create table vzc.spatial_bindings (
  binding_id uuid primary key default gen_random_uuid(),
  vzc_subject_type text not null,
  vzc_subject_key text not null,
  sourcecube_cube_uid text,
  sourcecube_binding_id uuid,
  ssr_registry_id uuid,
  safety_context jsonb not null default '{}'::jsonb,
  evidence_state text not null default 'concept' check (evidence_state in ('concept','evidence_identified','validated','integration_designed','prototype','pilot_approved','pilot_active','production_approved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sourcecube_cube_uid is not null or sourcecube_binding_id is not null or ssr_registry_id is not null)
);

create table vzc.organization_bindings (
  binding_id uuid primary key default gen_random_uuid(),
  vzc_subject_type text not null,
  vzc_subject_key text not null,
  organization_oid text,
  sourcecube_candidate_id uuid,
  external_organization_ref text,
  relationship_state text not null default 'candidate' check (relationship_state in ('candidate','evidence_identified','validated','authorized','active','suspended','closed')),
  authority_scope text,
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (organization_oid is not null or sourcecube_candidate_id is not null or external_organization_ref is not null)
);

create table vzc.domain_events (
  event_id uuid primary key default gen_random_uuid(),
  event_type text not null,
  subject_type text not null,
  subject_key text not null,
  event_class text not null check (event_class in ('observation','derived_intelligence','prediction','recommendation','authorization','execution','outcome')),
  source_system text not null,
  source_reference text,
  observed_at timestamptz,
  recorded_at timestamptz not null default now(),
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),
  evidence_state text not null default 'concept' check (evidence_state in ('concept','evidence_identified','validated','integration_designed','prototype','pilot_approved','pilot_active','production_approved')),
  payload jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  requires_human_review boolean not null default false,
  authority_reference text,
  check (event_class not in ('authorization','execution') or authority_reference is not null)
);

create index vzc_source_bindings_subject_idx on vzc.source_bindings(subject_type, subject_key);
create index vzc_spatial_bindings_subject_idx on vzc.spatial_bindings(vzc_subject_type, vzc_subject_key);
create index vzc_organization_bindings_subject_idx on vzc.organization_bindings(vzc_subject_type, vzc_subject_key);
create index vzc_domain_events_subject_time_idx on vzc.domain_events(subject_type, subject_key, recorded_at desc);
create index vzc_domain_events_type_time_idx on vzc.domain_events(event_type, recorded_at desc);

alter table vzc.domain_registry enable row level security;
alter table vzc.source_bindings enable row level security;
alter table vzc.spatial_bindings enable row level security;
alter table vzc.organization_bindings enable row level security;
alter table vzc.domain_events enable row level security;

create policy vzc_domain_registry_service_role_all on vzc.domain_registry for all to service_role using (true) with check (true);
create policy vzc_source_bindings_service_role_all on vzc.source_bindings for all to service_role using (true) with check (true);
create policy vzc_spatial_bindings_service_role_all on vzc.spatial_bindings for all to service_role using (true) with check (true);
create policy vzc_organization_bindings_service_role_all on vzc.organization_bindings for all to service_role using (true) with check (true);
create policy vzc_domain_events_service_role_all on vzc.domain_events for all to service_role using (true) with check (true);

grant select, insert, update, delete on all tables in schema vzc to service_role;

insert into vzc.domain_registry(domain_code,name,mission,lifecycle_state,production_authority,canonical_control_ref)
values ('VZC','Vision Zero Connect','Governed mobility-safety intelligence and coordination toward elimination of transportation deaths and serious injuries within approved deployment scopes.','integration_designed',false,'VZC-SC-001')
on conflict (domain_code) do nothing;

comment on schema vzc is 'Vision Zero Connect bounded mobility-safety mission application. Shared SourceCube/SETC primitives remain authoritative.';
comment on table vzc.spatial_bindings is 'VZC safety-context references to shared SourceCube/SSR spatial primitives; does not establish VZC ownership of enterprise spatial identity.';
comment on table vzc.organization_bindings is 'Evidence-backed organization relationships; a binding does not by itself establish contract, partnership, public authority or deployment.';
comment on table vzc.domain_events is 'Governed VZC event envelope separating observation, intelligence, prediction, recommendation, authorization, execution and outcome trust classes.';
