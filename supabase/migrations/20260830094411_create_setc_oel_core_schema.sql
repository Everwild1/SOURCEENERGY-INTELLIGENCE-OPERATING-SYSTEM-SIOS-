create schema if not exists oel;

create type oel.control_level as enum ('C0','C1','C2','C3','C4','C5','C6');
create type oel.work_status as enum ('DRAFT','READY','ASSIGNED','ACKNOWLEDGED','IN_PROGRESS','EVIDENCE_PENDING','REVIEW_PENDING','COMPLETE','DECLINED','BLOCKED','EXCEPTION','REWORK_REQUIRED','CANCELLED');
create type oel.exception_status as enum ('OPEN','TRIAGED','ASSIGNED','INVESTIGATING','DECISION_REQUIRED','RESOLVED','CLOSED','DISMISSED','ESCALATED','DEFERRED','REOPENED');
create type oel.evidence_type as enum ('ATTESTATION','PHOTO_VIDEO','DOCUMENT','SENSOR_DATA','CHECKLIST_RESULT','SIGNATURE','EXTERNAL_CONFIRMATION','DERIVED_METRIC');

create table oel.org_units (
  id uuid primary key default gen_random_uuid(),
  setc_org_oid text not null references public.setc_organizations(oid),
  parent_unit_id uuid references oel.org_units(id),
  unit_type text not null check (unit_type in ('organization','division','program','project','site','team','position')),
  canonical_name text not null,
  status text not null default 'active',
  jurisdiction text,
  classification text not null default 'internal',
  governance_tags jsonb not null default '[]'::jsonb,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  source_system text not null default 'SETC',
  created_by uuid references sourceenergy_one.actor_identities(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  unique (setc_org_oid, parent_unit_id, unit_type, canonical_name)
);

create table oel.sites (
  id uuid primary key default gen_random_uuid(),
  org_unit_id uuid not null references oel.org_units(id) on delete cascade,
  site_code text,
  country_code text,
  state_code text,
  locality text,
  latitude numeric,
  longitude numeric,
  w3w_address text,
  status text not null default 'active',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table oel.roles (
  id uuid primary key default gen_random_uuid(),
  setc_org_oid text not null references public.setc_organizations(oid),
  role_code text not null,
  role_name text not null,
  description text,
  max_control_level oel.control_level not null default 'C1',
  permissions jsonb not null default '[]'::jsonb,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (setc_org_oid, role_code)
);

create table oel.role_assignments (
  id uuid primary key default gen_random_uuid(),
  actor_identity_id uuid not null references sourceenergy_one.actor_identities(id),
  role_id uuid not null references oel.roles(id),
  org_unit_id uuid references oel.org_units(id),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  authority_reference text,
  approval_reference text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  unique (actor_identity_id, role_id, org_unit_id, effective_from)
);

create table oel.delegations (
  id uuid primary key default gen_random_uuid(),
  delegator_actor_id uuid not null references sourceenergy_one.actor_identities(id),
  delegate_actor_id uuid not null references sourceenergy_one.actor_identities(id),
  role_id uuid references oel.roles(id),
  org_unit_id uuid references oel.org_units(id),
  action_scope jsonb not null default '[]'::jsonb,
  maximum_control_level oel.control_level not null,
  effective_from timestamptz not null,
  effective_to timestamptz not null,
  approval_reference text,
  evidence_reference text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  check (effective_to > effective_from)
);

create table oel.channel_identities (
  id uuid primary key default gen_random_uuid(),
  actor_identity_id uuid not null references sourceenergy_one.actor_identities(id),
  channel_type text not null check (channel_type in ('sms','whatsapp','email','voice','push','web')),
  channel_address text not null,
  assurance_level text not null default 'unverified',
  verification_method text,
  verified_at timestamptz,
  status text not null default 'active',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (channel_type, channel_address)
);

create table oel.work_items (
  id uuid primary key default gen_random_uuid(),
  setc_org_oid text not null references public.setc_organizations(oid),
  org_unit_id uuid references oel.org_units(id),
  site_id uuid references oel.sites(id),
  external_project_ref text,
  parent_work_item_id uuid references oel.work_items(id),
  work_code text,
  title text not null,
  description text,
  assigned_to_actor_id uuid references sourceenergy_one.actor_identities(id),
  assigned_to_role_id uuid references oel.roles(id),
  owner_actor_id uuid references sourceenergy_one.actor_identities(id),
  priority text not null default 'normal',
  control_level oel.control_level not null default 'C1',
  status oel.work_status not null default 'DRAFT',
  due_at timestamptz,
  instructions jsonb not null default '{}'::jsonb,
  policy_refs jsonb not null default '[]'::jsonb,
  dependencies jsonb not null default '[]'::jsonb,
  source_system text not null default 'OEL',
  created_by uuid references sourceenergy_one.actor_identities(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1
);

create table oel.evidence_requirements (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null references oel.work_items(id) on delete cascade,
  evidence_type oel.evidence_type not null,
  required_count integer not null default 1 check (required_count > 0),
  reviewer_role_id uuid references oel.roles(id),
  minimum_control_level oel.control_level not null default 'C1',
  instructions text,
  policy_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table oel.evidence_records (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid references oel.work_items(id) on delete cascade,
  requirement_id uuid references oel.evidence_requirements(id),
  evidence_type oel.evidence_type not null,
  captured_by uuid references sourceenergy_one.actor_identities(id),
  captured_at timestamptz not null default now(),
  source_channel text,
  object_ref text,
  content_hash text,
  classification text not null default 'internal',
  location_context jsonb not null default '{}'::jsonb,
  model_generated boolean not null default false,
  verified_status text not null default 'unverified',
  verified_by uuid references sourceenergy_one.actor_identities(id),
  verification_method text,
  policy_refs jsonb not null default '[]'::jsonb,
  retention_class text,
  supersedes_evidence_id uuid references oel.evidence_records(id),
  created_at timestamptz not null default now()
);

create table oel.exceptions (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid references oel.work_items(id),
  setc_org_oid text not null references public.setc_organizations(oid),
  severity text not null,
  impact_domain text not null,
  control_level oel.control_level not null,
  status oel.exception_status not null default 'OPEN',
  required_role_id uuid references oel.roles(id),
  assigned_actor_id uuid references sourceenergy_one.actor_identities(id),
  deadline timestamptz,
  summary text not null,
  evidence_refs jsonb not null default '[]'::jsonb,
  created_by uuid references sourceenergy_one.actor_identities(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table oel.decision_bindings (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid references oel.work_items(id),
  exception_id uuid references oel.exceptions(id),
  sourceenergy_authorization_request_id uuid references sourceenergy_one.authorization_requests(id),
  ai_action_request_id uuid references ai_governance.action_requests(id),
  control_level oel.control_level not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  check (sourceenergy_authorization_request_id is not null or ai_action_request_id is not null)
);

create table oel.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null default gen_random_uuid(),
  channel_type text not null,
  sender_actor_id uuid references sourceenergy_one.actor_identities(id),
  recipient_actor_ids uuid[] not null default '{}',
  setc_org_oid text references public.setc_organizations(oid),
  org_unit_id uuid references oel.org_units(id),
  site_id uuid references oel.sites(id),
  work_item_id uuid references oel.work_items(id),
  message_type text not null,
  control_level oel.control_level not null default 'C0',
  normalized_content text,
  content_ref text,
  classification text not null default 'internal',
  consent_basis text,
  delivery_status text not null default 'queued',
  correlation_id uuid not null default gen_random_uuid(),
  trace_id uuid not null default gen_random_uuid(),
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table oel.events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  schema_version text not null default '1.0',
  aggregate_type text not null,
  aggregate_id text not null,
  setc_org_oid text references public.setc_organizations(oid),
  actor_id uuid references sourceenergy_one.actor_identities(id),
  occurred_at timestamptz not null default now(),
  recorded_at timestamptz not null default now(),
  source_system text not null default 'OEL',
  correlation_id uuid not null default gen_random_uuid(),
  causation_id uuid,
  control_level oel.control_level not null default 'C0',
  policy_result_ref text,
  evidence_refs jsonb not null default '[]'::jsonb,
  payload jsonb not null default '{}'::jsonb
);

create index oel_org_units_org_idx on oel.org_units(setc_org_oid);
create index oel_role_assignments_actor_idx on oel.role_assignments(actor_identity_id);
create index oel_work_items_org_status_idx on oel.work_items(setc_org_oid, status);
create index oel_work_items_assignee_idx on oel.work_items(assigned_to_actor_id, status);
create index oel_work_items_site_idx on oel.work_items(site_id, status);
create index oel_evidence_work_idx on oel.evidence_records(work_item_id);
create index oel_exceptions_work_status_idx on oel.exceptions(work_item_id, status);
create index oel_events_aggregate_idx on oel.events(aggregate_type, aggregate_id, occurred_at);
create index oel_events_correlation_idx on oel.events(correlation_id);

alter table oel.org_units enable row level security;
alter table oel.sites enable row level security;
alter table oel.roles enable row level security;
alter table oel.role_assignments enable row level security;
alter table oel.delegations enable row level security;
alter table oel.channel_identities enable row level security;
alter table oel.work_items enable row level security;
alter table oel.evidence_requirements enable row level security;
alter table oel.evidence_records enable row level security;
alter table oel.exceptions enable row level security;
alter table oel.decision_bindings enable row level security;
alter table oel.messages enable row level security;
alter table oel.events enable row level security;

revoke all on schema oel from public, anon, authenticated;
revoke all on all tables in schema oel from public, anon, authenticated;
revoke all on all sequences in schema oel from public, anon, authenticated;

comment on schema oel is 'SETC Organizational Execution Layer: Sidekick organizational execution fabric. Canonical identity, policy and authority remain in SETC/SIOS/SourceEnergy One.';
comment on table oel.events is 'Append-only OEL domain-event ledger. Corrections are represented by subsequent events, not destructive history mutation.';
