create schema if not exists rw;

create type rw.r3_stage as enum ('reclaim','reconstruct','reproduce');
create type rw.r3_status as enum ('discovered','registered','assessed','qualified','design','formation','validation','incubation','commercial_ready','market_ready','opportunity_matched','transaction_ready','active_commerce','scale_ready','replicating');
create type rw.readiness_dimension as enum ('governance','commercial','financial','operational','capital','trade','wealth_ecology');
create type rw.readiness_band as enum ('critical','developing','emerging','ready','advanced');
create type rw.gate_decision as enum ('approved','conditionally_approved','rejected','deferred');

create or replace function rw.readiness_band_for_score(p_score numeric)
returns rw.readiness_band
language sql
immutable
set search_path = rw, pg_catalog
as $$
  select case
    when p_score < 25 then 'critical'::rw.readiness_band
    when p_score < 50 then 'developing'::rw.readiness_band
    when p_score < 70 then 'emerging'::rw.readiness_band
    when p_score < 85 then 'ready'::rw.readiness_band
    else 'advanced'::rw.readiness_band
  end;
$$;

create table rw.entrepreneurs (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  auth_user_id uuid references auth.users(id) on delete set null,
  full_name text not null,
  email text,
  jurisdiction text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.organizations (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  legal_name text not null,
  display_name text,
  jurisdiction text,
  organization_type text,
  external_wim_org_id text,
  status rw.r3_status not null default 'discovered',
  current_stage rw.r3_stage not null default 'reclaim',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.organization_members (
  organization_id uuid not null references rw.organizations(id) on delete cascade,
  entrepreneur_id uuid not null references rw.entrepreneurs(id) on delete cascade,
  role_name text not null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (organization_id, entrepreneur_id, role_name)
);

create table rw.enrollments (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  organization_id uuid not null references rw.organizations(id) on delete cascade,
  entrepreneur_id uuid references rw.entrepreneurs(id) on delete set null,
  stage rw.r3_stage not null default 'reclaim',
  status rw.r3_status not null default 'registered',
  enrolled_at timestamptz not null default now(),
  exited_at timestamptz
);

create table rw.enterprise_profiles (
  organization_id uuid primary key references rw.organizations(id) on delete cascade,
  mission text,
  problem_statement text,
  value_proposition text,
  business_model text,
  target_markets text[],
  economic_clusters text[],
  notes text,
  updated_at timestamptz not null default now()
);

create table rw.products_services (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  organization_id uuid not null references rw.organizations(id) on delete cascade,
  name text not null,
  kind text not null check (kind in ('product','service')),
  description text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table rw.assessments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id) on delete cascade,
  enrollment_id uuid references rw.enrollments(id) on delete set null,
  methodology_version text not null,
  status text not null default 'draft' check (status in ('draft','in_review','final')),
  assessed_at timestamptz,
  created_at timestamptz not null default now()
);

create table rw.assessment_scores (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references rw.assessments(id) on delete cascade,
  dimension rw.readiness_dimension not null,
  score numeric(5,2) not null check (score >= 0 and score <= 100),
  band rw.readiness_band generated always as (rw.readiness_band_for_score(score)) stored,
  evidence_summary text,
  created_at timestamptz not null default now(),
  unique (assessment_id, dimension)
);

create table rw.readiness_snapshots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id) on delete cascade,
  assessment_id uuid not null references rw.assessments(id) on delete restrict,
  methodology_version text not null,
  captured_at timestamptz not null default now(),
  locked boolean not null default true,
  unique (organization_id, assessment_id)
);

create table rw.evidence (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id) on delete cascade,
  assessment_id uuid references rw.assessments(id) on delete cascade,
  evidence_type text not null,
  title text not null,
  source_uri text,
  checksum text,
  verified boolean not null default false,
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create table rw.remediation_actions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id) on delete cascade,
  assessment_id uuid references rw.assessments(id) on delete set null,
  dimension rw.readiness_dimension not null,
  action_text text not null,
  owner_user_id uuid references auth.users(id) on delete set null,
  due_at timestamptz,
  status text not null default 'open' check (status in ('open','in_progress','completed','waived')),
  created_at timestamptz not null default now()
);

create table rw.gate_decisions (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  organization_id uuid not null references rw.organizations(id) on delete cascade,
  enrollment_id uuid references rw.enrollments(id) on delete set null,
  from_status rw.r3_status not null,
  to_status rw.r3_status not null,
  decision rw.gate_decision not null,
  conditions text,
  rationale text,
  approved_by uuid references auth.users(id) on delete set null,
  evidence_ids uuid[] not null default '{}',
  decided_at timestamptz not null default now()
);

create table rw.status_history (
  id bigint generated always as identity primary key,
  organization_id uuid not null references rw.organizations(id) on delete cascade,
  prior_stage rw.r3_stage,
  new_stage rw.r3_stage not null,
  prior_status rw.r3_status,
  new_status rw.r3_status not null,
  gate_decision_id uuid references rw.gate_decisions(id) on delete set null,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now()
);

create index rw_org_members_ent_idx on rw.organization_members(entrepreneur_id);
create index rw_enrollments_org_idx on rw.enrollments(organization_id);
create index rw_products_org_idx on rw.products_services(organization_id);
create index rw_assessments_org_idx on rw.assessments(organization_id);
create index rw_scores_assessment_idx on rw.assessment_scores(assessment_id);
create index rw_evidence_org_idx on rw.evidence(organization_id);
create index rw_remediation_org_idx on rw.remediation_actions(organization_id);
create index rw_gate_org_idx on rw.gate_decisions(organization_id);
create index rw_history_org_idx on rw.status_history(organization_id, changed_at desc);

alter table rw.entrepreneurs enable row level security;
alter table rw.organizations enable row level security;
alter table rw.organization_members enable row level security;
alter table rw.enrollments enable row level security;
alter table rw.enterprise_profiles enable row level security;
alter table rw.products_services enable row level security;
alter table rw.assessments enable row level security;
alter table rw.assessment_scores enable row level security;
alter table rw.readiness_snapshots enable row level security;
alter table rw.evidence enable row level security;
alter table rw.remediation_actions enable row level security;
alter table rw.gate_decisions enable row level security;
alter table rw.status_history enable row level security;

revoke all on schema rw from anon, authenticated;
revoke all on all tables in schema rw from anon, authenticated;
revoke all on all sequences in schema rw from anon, authenticated;
revoke execute on all functions in schema rw from anon, authenticated;

grant usage on schema rw to service_role;
grant all on all tables in schema rw to service_role;
grant all on all sequences in schema rw to service_role;
grant execute on all functions in schema rw to service_role;

comment on schema rw is 'Revolution Wealth enterprise development bounded context. Default-deny to client roles; expose only through reviewed APIs/RPCs.';
comment on table rw.organizations is 'Authoritative Revolution Wealth enterprise registry record; external systems referenced by identifiers, not duplicated.';
comment on table rw.assessment_scores is 'Seven-dimensional Wealth Ecology readiness scoring; no opaque aggregate score is authoritative.';
comment on table rw.gate_decisions is 'Evidence-based R3 lifecycle gate decisions. Scores do not override mandatory legal/compliance controls.';
