create schema if not exists sourceenergy_one;

create table sourceenergy_one.purpose_profiles (
  id uuid primary key default gen_random_uuid(),
  subject_id text not null,
  version integer not null default 1 check (version > 0),
  status text not null default 'draft' check (status in ('draft','submitted','superseded','withdrawn')),
  responses jsonb not null default '{}'::jsonb,
  source_uri text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  unique(subject_id, version)
);

create table sourceenergy_one.codex24_interpretations (
  id uuid primary key default gen_random_uuid(),
  purpose_profile_id uuid not null references sourceenergy_one.purpose_profiles(id) on delete restrict,
  version integer not null default 1 check (version > 0),
  status text not null default 'candidate' check (status in ('candidate','reviewed','rejected','superseded')),
  interpretation jsonb not null,
  model_provenance jsonb not null default '{}'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique(purpose_profile_id, version)
);

create table sourceenergy_one.impact_reports (
  id uuid primary key default gen_random_uuid(),
  subject_id text not null,
  purpose_profile_id uuid not null references sourceenergy_one.purpose_profiles(id) on delete restrict,
  interpretation_id uuid not null references sourceenergy_one.codex24_interpretations(id) on delete restrict,
  version integer not null default 1 check (version > 0),
  mission text not null,
  vision text not null,
  purpose text not null,
  impact_thesis text not null,
  impact_horizons jsonb not null default '[]'::jsonb,
  status text not null default 'draft' check (status in ('draft','in_review','approved','rejected','superseded')),
  created_at timestamptz not null default now(),
  unique(subject_id, version)
);

create table sourceenergy_one.genesis_approvals (
  id uuid primary key default gen_random_uuid(),
  impact_report_id uuid not null references sourceenergy_one.impact_reports(id) on delete restrict,
  decision text not null check (decision in ('approve','reject','defer','request_revision')),
  actor_id uuid default auth.uid(),
  actor_ref text,
  consent_receipt_id text,
  rationale text,
  decided_at timestamptz not null default now()
);

create table sourceenergy_one.genesis_packages (
  id uuid primary key default gen_random_uuid(),
  subject_id text not null,
  impact_report_id uuid not null unique references sourceenergy_one.impact_reports(id) on delete restrict,
  approval_id uuid not null unique references sourceenergy_one.genesis_approvals(id) on delete restrict,
  schema_version text not null default '1.0',
  package jsonb not null,
  package_hash text not null,
  setc_genesis_ref text,
  sourcecube_context_ref text,
  created_at timestamptz not null default now()
);

create table sourceenergy_one.orchestration_plans (
  id uuid primary key default gen_random_uuid(),
  subject_id text not null,
  genesis_package_id uuid references sourceenergy_one.genesis_packages(id) on delete restrict,
  intent text not null,
  plan jsonb not null,
  evidence_refs jsonb not null default '[]'::jsonb,
  policy_evaluation jsonb not null default '{}'::jsonb,
  consequence_class text not null default 'advisory' check (consequence_class in ('advisory','operational','consequential')),
  authorization_status text not null default 'not_required' check (authorization_status in ('not_required','required','approved','declined','deferred')),
  correlation_id uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table sourceenergy_one.audit_events (
  id bigint generated always as identity primary key,
  correlation_id uuid not null,
  subject_id text,
  actor_id uuid default auth.uid(),
  event_type text not null,
  object_type text not null,
  object_ref text,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index on sourceenergy_one.purpose_profiles(subject_id, status);
create index on sourceenergy_one.impact_reports(subject_id, status);
create index on sourceenergy_one.genesis_packages(subject_id);
create index on sourceenergy_one.orchestration_plans(subject_id, created_at desc);
create index on sourceenergy_one.audit_events(correlation_id, occurred_at);

alter table sourceenergy_one.purpose_profiles enable row level security;
alter table sourceenergy_one.codex24_interpretations enable row level security;
alter table sourceenergy_one.impact_reports enable row level security;
alter table sourceenergy_one.genesis_approvals enable row level security;
alter table sourceenergy_one.genesis_packages enable row level security;
alter table sourceenergy_one.orchestration_plans enable row level security;
alter table sourceenergy_one.audit_events enable row level security;

revoke all on schema sourceenergy_one from public, anon, authenticated;
revoke all on all tables in schema sourceenergy_one from public, anon, authenticated;
grant usage on schema sourceenergy_one to service_role;
grant all on all tables in schema sourceenergy_one to service_role;
grant usage, select on all sequences in schema sourceenergy_one to service_role;

comment on schema sourceenergy_one is 'SourceEnergy One protected backend boundary. Client access must occur through governed APIs/RPCs rather than direct table grants.';
comment on table sourceenergy_one.codex24_interpretations is 'Derived candidate interpretations. Never authoritative until human-reviewed impact artifact is approved.';
comment on table sourceenergy_one.genesis_packages is 'Approved provenance packages for SETC Genesis and SourceCube context handoff.';
