create table if not exists public.source_cubes (
  id uuid primary key default gen_random_uuid(),
  cube_code text not null unique,
  cube_name text not null,
  domain text not null,
  description text,
  control_state text not null check (control_state in ('CORE','CONTROLLED','DOMAIN','RESTRICTED','EVIDENCE_REQUIRED','INFRASTRUCTURE')),
  lifecycle_state text not null default 'ACTIVE' check (lifecycle_state in ('DRAFT','ACTIVE','SUSPENDED','RETIRED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sourcecube_assignments (
  id uuid primary key default gen_random_uuid(),
  assignment_code text not null unique,
  source_cube_id uuid not null references public.source_cubes(id) on delete restrict,
  organization_oid text references public.setc_organizations(oid) on delete restrict,
  object_type text not null,
  object_ref text not null,
  mandate text not null,
  geography text,
  assignment_state text not null default 'PROPOSED' check (assignment_state in ('VERIFIED','CONDITIONAL','PROPOSED','RESTRICTED','EVIDENCE_REQUIRED')),
  effective_from timestamptz,
  effective_until timestamptz,
  restrictions jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(source_cube_id, object_type, object_ref)
);

create table if not exists public.sourcecube_authorities (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.sourcecube_assignments(id) on delete cascade,
  authority_type text not null check (authority_type in ('VIEW_ASSIGNMENT','MANAGE_ASSIGNMENT','GRANT_AUTHORITY','EXECUTE_GOVERNED_ACTION')),
  subject_user_id uuid references auth.users(id),
  subject_organization_oid text references public.setc_organizations(oid),
  authority_state text not null default 'PROPOSED' check (authority_state in ('VERIFIED','CONDITIONAL','PROPOSED','RESTRICTED','EVIDENCE_REQUIRED','REVOKED','EXPIRED')),
  evidence_ref text,
  granted_by uuid references auth.users(id),
  valid_from timestamptz,
  valid_until timestamptz,
  created_at timestamptz not null default now(),
  check (subject_user_id is not null or subject_organization_oid is not null)
);

create table if not exists public.sourcecube_evidence (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.sourcecube_assignments(id) on delete cascade,
  evidence_type text not null,
  evidence_ref text not null,
  verification_state text not null default 'PENDING' check (verification_state in ('PENDING','VERIFIED','REJECTED','EXPIRED','SUPERSEDED')),
  verified_by uuid references auth.users(id),
  verified_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.sourcecube_dependencies (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.sourcecube_assignments(id) on delete cascade,
  depends_on_assignment_id uuid not null references public.sourcecube_assignments(id) on delete restrict,
  dependency_type text not null,
  state text not null default 'ACTIVE' check (state in ('ACTIVE','SATISFIED','WAIVED','BLOCKED','RETIRED')),
  created_at timestamptz not null default now(),
  check (assignment_id <> depends_on_assignment_id),
  unique(assignment_id, depends_on_assignment_id, dependency_type)
);

create table if not exists public.sourcecube_approvals (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.sourcecube_assignments(id) on delete cascade,
  action_type text not null,
  requested_by uuid references auth.users(id),
  decision text not null default 'PENDING' check (decision in ('PENDING','APPROVED','REJECTED','REVOKED','EXPIRED')),
  decided_by uuid references auth.users(id),
  decision_evidence_ref text,
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.sourcecube_events (
  id bigint generated always as identity primary key,
  assignment_id uuid references public.sourcecube_assignments(id) on delete set null,
  source_cube_id uuid references public.source_cubes(id) on delete set null,
  event_type text not null,
  actor_user_id uuid references auth.users(id),
  object_type text,
  object_ref text,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists sourcecube_assignments_cube_idx on public.sourcecube_assignments(source_cube_id);
create index if not exists sourcecube_assignments_org_idx on public.sourcecube_assignments(organization_oid);
create index if not exists sourcecube_assignments_object_idx on public.sourcecube_assignments(object_type, object_ref);
create index if not exists sourcecube_authorities_assignment_idx on public.sourcecube_authorities(assignment_id);
create index if not exists sourcecube_authorities_user_idx on public.sourcecube_authorities(subject_user_id);
create index if not exists sourcecube_evidence_assignment_idx on public.sourcecube_evidence(assignment_id);
create index if not exists sourcecube_events_assignment_time_idx on public.sourcecube_events(assignment_id, occurred_at desc);

alter table public.source_cubes enable row level security;
alter table public.sourcecube_assignments enable row level security;
alter table public.sourcecube_authorities enable row level security;
alter table public.sourcecube_evidence enable row level security;
alter table public.sourcecube_dependencies enable row level security;
alter table public.sourcecube_approvals enable row level security;
alter table public.sourcecube_events enable row level security;

revoke all on public.source_cubes, public.sourcecube_assignments, public.sourcecube_authorities, public.sourcecube_evidence, public.sourcecube_dependencies, public.sourcecube_approvals, public.sourcecube_events from anon, authenticated;
grant select, insert, update, delete on public.source_cubes, public.sourcecube_assignments, public.sourcecube_authorities, public.sourcecube_evidence, public.sourcecube_dependencies, public.sourcecube_approvals to service_role;
grant select, insert on public.sourcecube_events to service_role;

comment on table public.source_cubes is 'Canonical SourceCube governance domains. A cube classifies and coordinates responsibility; it does not itself create legal, financial, governmental, regulatory, ownership, custody or execution authority.';
comment on table public.sourcecube_assignments is 'Governed SourceCube-to-object assignments. Assignment does not confer authority; operative authority requires separately verified evidence and authorization.';
comment on table public.sourcecube_authorities is 'Explicit authority records separated into view, assignment management, authority grant and governed execution. Administrative assignment rights do not imply financial or institutional execution rights.';
comment on table public.sourcecube_evidence is 'Evidence references supporting SourceCube assignments and authority. Store references/metadata, not credentials, private keys or full sensitive financial messages.';
comment on table public.sourcecube_events is 'Append-oriented SourceCube governance event ledger; event records evidence system actions and do not independently create underlying authority.';

insert into public.source_cubes (cube_code,cube_name,domain,description,control_state) values
('SC-01','Enterprise','Enterprise','Ecosystem governance, identity and inter-entity orchestration','CORE'),
('SC-02','Global Commerce','Commerce','Cross-border commercial development and strategic partnerships','CORE'),
('SC-03','Capital','Capital','Capital formation, structuring, allocation and investment governance','CONTROLLED'),
('SC-04','Trade / WIM','Trade','Market access, procurement and trade-flow intelligence','CORE'),
('SC-05','Logistics','Logistics','Marine, air, rail, inland, drone and multimodal corridors','CONTROLLED'),
('SC-06','Energy','Energy','Energy sourcing, infrastructure and supply interfaces','EVIDENCE_REQUIRED'),
('SC-07','Foundation / Impact','Impact','Foundation mandates, development capital and impact deployment','CONTROLLED'),
('SC-08','Health','Health','Diaspora-health ecosystem and health initiatives','DOMAIN'),
('SC-09','Financial Infrastructure','Financial Infrastructure','Settlement, token and financial-rail architecture','RESTRICTED'),
('SC-10','Government Interface','Government','Public-body evidence, permits, authority and procurement governance','EVIDENCE_REQUIRED'),
('SC-11','Intelligence','Intelligence','SIOS, research, analytics and Wealth Ecology intelligence','CORE'),
('SC-12','Spatial Infrastructure','Spatial','Spatial registry, physical assets, corridors and geospatial relationships','INFRASTRUCTURE')
on conflict (cube_code) do update set cube_name=excluded.cube_name, domain=excluded.domain, description=excluded.description, control_state=excluded.control_state, updated_at=now();
