create type rw.claim_status as enum ('documented_internal','pending_verification','verified','target','proposed','historical','superseded');
create type rw.fund_status as enum ('draft','forming','active','paused','closed','restricted');
create type rw.vehicle_status as enum ('draft','forming','active','paused','closed','restricted');
create type rw.capital_event_type as enum ('commitment','subscription','allocation','deployment','reserve','distribution','return','valuation','write_down','transfer','other');

create table rw.funds (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  managing_organization_id uuid references rw.organizations(id),
  legal_name text not null,
  display_name text,
  fund_type text not null,
  jurisdiction text,
  stated_target_amount numeric,
  currency_code text,
  status rw.fund_status not null default 'draft',
  verification_status rw.claim_status not null default 'pending_verification',
  effective_date date,
  evidence_ids uuid[] not null default '{}',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.fund_vehicles (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  fund_id uuid not null references rw.funds(id) on delete cascade,
  parent_vehicle_id uuid references rw.fund_vehicles(id),
  legal_name text not null,
  display_name text,
  vehicle_type text not null,
  jurisdiction text,
  status rw.vehicle_status not null default 'draft',
  verification_status rw.claim_status not null default 'pending_verification',
  effective_date date,
  evidence_ids uuid[] not null default '{}',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.investment_projects (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  organization_id uuid references rw.organizations(id),
  fund_id uuid references rw.funds(id),
  vehicle_id uuid references rw.fund_vehicles(id),
  wim_opportunity_id uuid,
  wim_commercialization_project_id uuid,
  name text not null,
  project_type text,
  jurisdiction text,
  status text not null default 'proposed',
  verification_status rw.claim_status not null default 'pending_verification',
  evidence_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.investment_assets (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  project_id uuid references rw.investment_projects(id),
  fund_id uuid references rw.funds(id),
  vehicle_id uuid references rw.fund_vehicles(id),
  owner_organization_id uuid references rw.organizations(id),
  asset_type text not null,
  name text not null,
  jurisdiction text,
  external_reference text,
  stated_value numeric,
  currency_code text,
  valuation_date date,
  verification_status rw.claim_status not null default 'pending_verification',
  evidence_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.capital_events (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  fund_id uuid not null references rw.funds(id),
  vehicle_id uuid references rw.fund_vehicles(id),
  project_id uuid references rw.investment_projects(id),
  asset_id uuid references rw.investment_assets(id),
  organization_id uuid references rw.organizations(id),
  capital_request_id uuid references rw.capital_requests(id),
  event_type rw.capital_event_type not null,
  amount numeric,
  currency_code text,
  occurred_at timestamptz not null,
  verification_status rw.claim_status not null default 'pending_verification',
  external_reference text,
  evidence_ids uuid[] not null default '{}',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table rw.registry_claims (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  subject_type text not null,
  subject_id uuid not null,
  claim_key text not null,
  claim_value jsonb not null,
  status rw.claim_status not null default 'pending_verification',
  jurisdiction text,
  effective_date date,
  expires_at timestamptz,
  evidence_ids uuid[] not null default '{}',
  approved_by uuid,
  approved_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(subject_type, subject_id, claim_key, effective_date)
);

create index funds_manager_idx on rw.funds(managing_organization_id);
create index fund_vehicles_fund_idx on rw.fund_vehicles(fund_id);
create index investment_projects_fund_idx on rw.investment_projects(fund_id);
create index investment_projects_org_idx on rw.investment_projects(organization_id);
create index investment_assets_project_idx on rw.investment_assets(project_id);
create index capital_events_fund_idx on rw.capital_events(fund_id);
create index capital_events_project_idx on rw.capital_events(project_id);
create index capital_events_occurred_idx on rw.capital_events(occurred_at);
create index registry_claims_subject_idx on rw.registry_claims(subject_type, subject_id);
create index registry_claims_status_idx on rw.registry_claims(status);

alter table rw.funds enable row level security;
alter table rw.fund_vehicles enable row level security;
alter table rw.investment_projects enable row level security;
alter table rw.investment_assets enable row level security;
alter table rw.capital_events enable row level security;
alter table rw.registry_claims enable row level security;

