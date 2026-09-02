create type rw.program_type as enum ('pre_incubation','incubator','accelerator','commercialization','replication');
create type rw.participation_status as enum ('applied','admitted','active','paused','completed','exited','removed');
create type rw.milestone_status as enum ('not_started','in_progress','blocked','completed','waived');
create type rw.cluster_membership_status as enum ('candidate','declared','reviewed','verified','restricted','inactive');

create table rw.programs (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  name text not null,
  program_type rw.program_type not null,
  description text,
  active boolean not null default true,
  methodology_version text not null default 'RW-PROGRAM-0.1',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.cohorts (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  program_id uuid not null references rw.programs(id),
  name text not null,
  starts_at timestamptz,
  ends_at timestamptz,
  capacity integer check (capacity is null or capacity > 0),
  status text not null default 'planned' check (status in ('planned','open','active','closed','cancelled')),
  created_at timestamptz not null default now()
);

create table rw.program_participations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  enrollment_id uuid references rw.enrollments(id),
  program_id uuid not null references rw.programs(id),
  cohort_id uuid references rw.cohorts(id),
  status rw.participation_status not null default 'applied',
  admitted_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  exit_reason text,
  created_at timestamptz not null default now(),
  unique (organization_id, program_id, cohort_id)
);

create table rw.program_milestones (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references rw.programs(id),
  code text not null,
  name text not null,
  description text,
  required boolean not null default true,
  sequence_no integer not null check (sequence_no > 0),
  target_r3_status rw.r3_status,
  unique (program_id, code),
  unique (program_id, sequence_no)
);

create table rw.participation_milestones (
  id uuid primary key default gen_random_uuid(),
  participation_id uuid not null references rw.program_participations(id),
  milestone_id uuid not null references rw.program_milestones(id),
  status rw.milestone_status not null default 'not_started',
  evidence_ids uuid[] not null default '{}',
  notes text,
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (participation_id, milestone_id)
);

create table rw.interventions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  participation_id uuid references rw.program_participations(id),
  intervention_type text not null check (intervention_type in ('mentoring','technical_assistance','governance','finance','market','procurement','technology','legal_compliance','trade','operations','other')),
  title text not null,
  description text,
  provider_name text,
  external_reference text,
  status text not null default 'planned' check (status in ('planned','active','completed','cancelled')),
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table rw.organizations
  add column wim_organization_id uuid references wim.organizations(id);

create unique index rw_organizations_wim_org_unique
  on rw.organizations(wim_organization_id)
  where wim_organization_id is not null;

create table rw.cluster_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  wim_cluster_id bigint not null references wim.economic_clusters(id),
  wim_subcluster_id bigint references wim.economic_subclusters(id),
  role text not null default 'participant',
  status rw.cluster_membership_status not null default 'candidate',
  is_primary boolean not null default false,
  evidence_ids uuid[] not null default '{}',
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, wim_cluster_id, wim_subcluster_id, role)
);

create table rw.market_targets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  wim_market_id uuid not null references wim.markets(id),
  target_role text not null check (target_role in ('buyer','seller','supplier','procurer','investor','partner','exporter','importer','commercializer','service_provider')),
  readiness_status text not null default 'candidate' check (readiness_status in ('candidate','assessing','qualified','restricted','inactive')),
  evidence_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, wim_market_id, target_role)
);

create table rw.integration_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  request_type text not null check (request_type in ('wim_organization_projection','wim_cluster_membership','wim_market_membership','wim_product_projection','wim_opportunity_match','rgl_logistics_assessment')),
  source_reference text,
  target_reference text,
  status text not null default 'requested' check (status in ('requested','under_review','approved','rejected','completed','restricted')),
  payload jsonb not null default '{}'::jsonb,
  requested_at timestamptz not null default now(),
  completed_at timestamptz
);

comment on table rw.programs is 'Revolution Wealth enterprise-development program definitions; not financial products or investment vehicles.';
comment on table rw.cluster_memberships is 'RW development-side classification referencing authoritative WIM cluster taxonomy; does not itself create WIM market membership.';
comment on table rw.integration_requests is 'Controlled boundary requests into WIM/RGL domains; approval/completion does not imply legal, financial, or regulatory authorization.';

create index rw_cohorts_program_idx on rw.cohorts(program_id);
create index rw_participations_org_idx on rw.program_participations(organization_id);
create index rw_participations_enrollment_idx on rw.program_participations(enrollment_id);
create index rw_participations_program_idx on rw.program_participations(program_id);
create index rw_participations_cohort_idx on rw.program_participations(cohort_id);
create index rw_program_milestones_program_idx on rw.program_milestones(program_id);
create index rw_participation_milestones_participation_idx on rw.participation_milestones(participation_id);
create index rw_participation_milestones_milestone_idx on rw.participation_milestones(milestone_id);
create index rw_interventions_org_idx on rw.interventions(organization_id);
create index rw_interventions_participation_idx on rw.interventions(participation_id);
create index rw_cluster_memberships_org_idx on rw.cluster_memberships(organization_id);
create index rw_cluster_memberships_cluster_idx on rw.cluster_memberships(wim_cluster_id);
create index rw_cluster_memberships_subcluster_idx on rw.cluster_memberships(wim_subcluster_id);
create index rw_market_targets_org_idx on rw.market_targets(organization_id);
create index rw_market_targets_market_idx on rw.market_targets(wim_market_id);
create index rw_integration_requests_org_idx on rw.integration_requests(organization_id);
create index rw_integration_requests_status_idx on rw.integration_requests(status);

alter table rw.programs enable row level security;
alter table rw.cohorts enable row level security;
alter table rw.program_participations enable row level security;
alter table rw.program_milestones enable row level security;
alter table rw.participation_milestones enable row level security;
alter table rw.interventions enable row level security;
alter table rw.cluster_memberships enable row level security;
alter table rw.market_targets enable row level security;
alter table rw.integration_requests enable row level security;

revoke all on all tables in schema rw from anon, authenticated;
grant usage on schema rw to service_role;
grant all on all tables in schema rw to service_role;
grant all on all sequences in schema rw to service_role;
