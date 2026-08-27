do $$ begin
  create type rw.claim_status as enum ('documented_internal','pending_verification','verified','target','proposed','historical','superseded');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type rw.fund_status as enum ('draft','forming','active','paused','closed','restricted');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type rw.vehicle_status as enum ('draft','forming','active','paused','closed','restricted');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type rw.capital_event_type as enum ('commitment','subscription','allocation','deployment','reserve','distribution','return','valuation','write_down','transfer','other');
exception when duplicate_object then null;
end $$;

create table if not exists rw.funds (
  id uuid primary key default gen_random_uuid(), registry_code text not null unique,
  managing_organization_id uuid references rw.organizations(id), legal_name text not null,
  display_name text, fund_type text not null, jurisdiction text, stated_target_amount numeric,
  currency_code text, status rw.fund_status not null default 'draft',
  verification_status rw.claim_status not null default 'pending_verification', effective_date date,
  evidence_ids uuid[] not null default '{}', notes text, created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists rw.fund_vehicles (
  id uuid primary key default gen_random_uuid(), registry_code text not null unique,
  fund_id uuid not null references rw.funds(id) on delete cascade,
  parent_vehicle_id uuid references rw.fund_vehicles(id), legal_name text not null,
  display_name text, vehicle_type text not null, jurisdiction text,
  status rw.vehicle_status not null default 'draft', verification_status rw.claim_status not null default 'pending_verification',
  effective_date date, evidence_ids uuid[] not null default '{}', notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists rw.investment_projects (
  id uuid primary key default gen_random_uuid(), registry_code text not null unique,
  organization_id uuid references rw.organizations(id), fund_id uuid references rw.funds(id),
  vehicle_id uuid references rw.fund_vehicles(id), wim_opportunity_id uuid, wim_commercialization_project_id uuid,
  name text not null, project_type text, jurisdiction text, status text not null default 'proposed',
  verification_status rw.claim_status not null default 'pending_verification', evidence_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists rw.investment_assets (
  id uuid primary key default gen_random_uuid(), registry_code text not null unique,
  project_id uuid references rw.investment_projects(id), fund_id uuid references rw.funds(id),
  vehicle_id uuid references rw.fund_vehicles(id), owner_organization_id uuid references rw.organizations(id),
  asset_type text not null, name text not null, jurisdiction text, external_reference text,
  stated_value numeric, currency_code text, valuation_date date,
  verification_status rw.claim_status not null default 'pending_verification', evidence_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists rw.capital_events (
  id uuid primary key default gen_random_uuid(), registry_code text not null unique,
  fund_id uuid not null references rw.funds(id), vehicle_id uuid references rw.fund_vehicles(id),
  project_id uuid references rw.investment_projects(id), asset_id uuid references rw.investment_assets(id),
  organization_id uuid references rw.organizations(id), capital_request_id uuid references rw.capital_requests(id),
  event_type rw.capital_event_type not null, amount numeric, currency_code text, occurred_at timestamptz not null,
  verification_status rw.claim_status not null default 'pending_verification', external_reference text,
  evidence_ids uuid[] not null default '{}', metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists rw.registry_claims (
  id uuid primary key default gen_random_uuid(), registry_code text not null unique,
  subject_type text not null, subject_id uuid not null, claim_key text not null, claim_value jsonb not null,
  status rw.claim_status not null default 'pending_verification', jurisdiction text, effective_date date,
  expires_at timestamptz, evidence_ids uuid[] not null default '{}', approved_by uuid, approved_at timestamptz,
  notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(subject_type, subject_id, claim_key, effective_date)
);

create index if not exists funds_manager_idx on rw.funds(managing_organization_id);
create index if not exists fund_vehicles_fund_idx on rw.fund_vehicles(fund_id);
create index if not exists fund_vehicles_parent_idx on rw.fund_vehicles(parent_vehicle_id) where parent_vehicle_id is not null;
create index if not exists investment_projects_fund_idx on rw.investment_projects(fund_id);
create index if not exists investment_projects_org_idx on rw.investment_projects(organization_id);
create index if not exists investment_projects_vehicle_idx on rw.investment_projects(vehicle_id) where vehicle_id is not null;
create index if not exists investment_assets_project_idx on rw.investment_assets(project_id);
create index if not exists investment_assets_fund_idx on rw.investment_assets(fund_id) where fund_id is not null;
create index if not exists investment_assets_vehicle_idx on rw.investment_assets(vehicle_id) where vehicle_id is not null;
create index if not exists investment_assets_owner_org_idx on rw.investment_assets(owner_organization_id) where owner_organization_id is not null;
create index if not exists capital_events_fund_idx on rw.capital_events(fund_id);
create index if not exists capital_events_project_idx on rw.capital_events(project_id);
create index if not exists capital_events_occurred_idx on rw.capital_events(occurred_at);
create index if not exists capital_events_vehicle_idx on rw.capital_events(vehicle_id) where vehicle_id is not null;
create index if not exists capital_events_asset_idx on rw.capital_events(asset_id) where asset_id is not null;
create index if not exists capital_events_org_idx on rw.capital_events(organization_id) where organization_id is not null;
create index if not exists capital_events_capital_request_idx on rw.capital_events(capital_request_id) where capital_request_id is not null;
create index if not exists registry_claims_subject_idx on rw.registry_claims(subject_type, subject_id);
create index if not exists registry_claims_status_idx on rw.registry_claims(status);

alter table rw.funds enable row level security;
alter table rw.fund_vehicles enable row level security;
alter table rw.investment_projects enable row level security;
alter table rw.investment_assets enable row level security;
alter table rw.capital_events enable row level security;
alter table rw.registry_claims enable row level security;
