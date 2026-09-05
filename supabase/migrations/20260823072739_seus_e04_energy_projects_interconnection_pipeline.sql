create table if not exists energy.projects (
  project_id uuid primary key default gen_random_uuid(),
  project_code text not null unique check (project_code ~ '^[A-Z0-9_-]{3,64}$'),
  project_name text not null check (length(btrim(project_name)) > 0),
  project_type text not null check (project_type in ('GENERATION','STORAGE','DER_AGGREGATION','MICROGRID','TRANSMISSION','DISTRIBUTION','INTERCONNECTION','EV_INFRASTRUCTURE','HYDROGEN','FUEL_INFRASTRUCTURE','HYBRID','OTHER')),
  development_stage text not null default 'CONCEPT' check (development_stage in ('CONCEPT','SCREENING','FEASIBILITY','SITE_CONTROL','INTERCONNECTION','PERMITTING','ENGINEERING','PROCUREMENT','FINANCING','CONSTRUCTION','COMMISSIONING','OPERATING','SUSPENDED','CANCELLED','RETIRED')),
  verification_state text not null default 'REFERENCE' check (verification_state in ('REFERENCE','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  country_code text not null default 'US' check (country_code ~ '^[A-Z]{2}$'),
  state_code text,
  locality text,
  planned_capacity_mw numeric check (planned_capacity_mw is null or planned_capacity_mw >= 0),
  planned_energy_mwh numeric check (planned_energy_mwh is null or planned_energy_mwh >= 0),
  target_commercial_operation_date date,
  evidence_reference text,
  source_as_of date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table energy.projects is 'SourceEnergy.us energy-development project registry. Project registration does not establish financing, title, permits, interconnection rights, market participation, procurement awards, or construction authority.';

create table if not exists energy.project_asset_links (
  link_id uuid primary key default gen_random_uuid(),
  project_id uuid not null references energy.projects(project_id) on delete cascade,
  asset_id uuid not null references energy.assets(asset_id) on delete restrict,
  relationship_type text not null check (relationship_type in ('DEVELOPS','EXPANDS','REPOWERS','INTERCONNECTS','USES','REPLACES','REFERENCE_ONLY')),
  state text not null default 'PROPOSED' check (state in ('PROPOSED','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(project_id, asset_id, relationship_type)
);

create table if not exists energy.project_organization_links (
  link_id uuid primary key default gen_random_uuid(),
  project_id uuid not null references energy.projects(project_id) on delete cascade,
  organization_oid text not null references public.setc_organizations(oid) on delete restrict,
  organization_role text not null check (organization_role in ('SPONSOR','DEVELOPER','OWNER','CO_OWNER','OPERATOR','UTILITY','TRANSMISSION_PROVIDER','EPC','ENGINEER','OFFTAKER','LANDOWNER_REFERENCE','FINANCIER_REFERENCE','REGULATOR_REFERENCE','OTHER')),
  state text not null default 'PROPOSED' check (state in ('PROPOSED','ASSERTED','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','DISPUTED','EXPIRED','TERMINATED','REVOKED','ARCHIVED')),
  evidence_reference text,
  effective_from timestamptz,
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(project_id, organization_oid, organization_role)
);

create table if not exists energy.project_market_links (
  link_id uuid primary key default gen_random_uuid(),
  project_id uuid not null references energy.projects(project_id) on delete cascade,
  market_id uuid not null references energy.markets(market_id) on delete restrict,
  region_id uuid references energy.market_regions(region_id) on delete restrict,
  relationship_type text not null check (relationship_type in ('TARGET_MARKET','LOCATED_IN','INTERCONNECTION_MARKET','OFFTAKE_MARKET','REFERENCE_ONLY')),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PROPOSED','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(project_id, market_id, relationship_type)
);

create table if not exists energy.interconnection_queue_entries (
  queue_entry_id uuid primary key default gen_random_uuid(),
  project_id uuid not null references energy.projects(project_id) on delete cascade,
  market_id uuid references energy.markets(market_id) on delete restrict,
  transmission_provider_oid text references public.setc_organizations(oid) on delete restrict,
  external_queue_id text not null,
  queue_status text not null default 'REFERENCE' check (queue_status in ('REFERENCE','SUBMITTED','VALIDATION','STUDY','FACILITIES_STUDY','AGREEMENT_PENDING','AGREEMENT_EXECUTED','CONSTRUCTION','IN_SERVICE','WITHDRAWN','SUSPENDED','UNKNOWN')),
  requested_capacity_mw numeric check (requested_capacity_mw is null or requested_capacity_mw >= 0),
  point_of_interconnection text,
  requested_in_service_date date,
  queue_date date,
  withdrawal_date date,
  verification_state text not null default 'REFERENCE' check (verification_state in ('REFERENCE','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  source_as_of date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(project_id, external_queue_id)
);

comment on table energy.interconnection_queue_entries is 'Reference registry for interconnection-queue evidence. Presence in this table does not itself establish queue standing, interconnection approval, capacity rights, or permission to energize.';

create table if not exists energy.project_permits (
  permit_id uuid primary key default gen_random_uuid(),
  project_id uuid not null references energy.projects(project_id) on delete cascade,
  permit_type text not null,
  authority_name text not null,
  authority_organization_oid text references public.setc_organizations(oid) on delete restrict,
  external_permit_id text,
  permit_state text not null default 'REFERENCE' check (permit_state in ('REFERENCE','NOT_STARTED','PREPARING','SUBMITTED','UNDER_REVIEW','APPROVED','CONDITIONALLY_APPROVED','DENIED','EXPIRED','WITHDRAWN','SUSPENDED','UNKNOWN')),
  submitted_at date,
  decided_at date,
  expires_at date,
  verification_state text not null default 'REFERENCE' check (verification_state in ('REFERENCE','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists energy.project_stage_events (
  event_id uuid primary key default gen_random_uuid(),
  project_id uuid not null references energy.projects(project_id) on delete cascade,
  from_stage text,
  to_stage text not null,
  decision_state text not null default 'RECORDED' check (decision_state in ('RECORDED','PENDING_VERIFICATION','VERIFIED','REVERSED','DISPUTED')),
  authority_reference text,
  evidence_reference text,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists energy.project_external_links (
  external_link_id uuid primary key default gen_random_uuid(),
  project_id uuid not null references energy.projects(project_id) on delete cascade,
  system_name text not null check (system_name in ('HEI','WIM','RW','CRUDS','RGL','GSC','IOTF','SETC','OTHER')),
  external_entity_type text not null,
  external_reference text not null,
  relationship_type text not null default 'REFERENCE_ONLY' check (relationship_type in ('REFERENCE_ONLY','CAPITAL_PROJECT','COMMERCIALIZATION_PROJECT','PROCUREMENT_PROGRAM','LOGISTICS_PROJECT','INVESTMENT_PROJECT','OTHER')),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED','ACTIVE','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  unique(project_id, system_name, external_entity_type, external_reference)
);

alter table energy.projects enable row level security;
alter table energy.project_asset_links enable row level security;
alter table energy.project_organization_links enable row level security;
alter table energy.project_market_links enable row level security;
alter table energy.interconnection_queue_entries enable row level security;
alter table energy.project_permits enable row level security;
alter table energy.project_stage_events enable row level security;
alter table energy.project_external_links enable row level security;

revoke all on energy.projects, energy.project_asset_links, energy.project_organization_links, energy.project_market_links, energy.interconnection_queue_entries, energy.project_permits, energy.project_stage_events, energy.project_external_links from anon, authenticated;
grant all on energy.projects, energy.project_asset_links, energy.project_organization_links, energy.project_market_links, energy.interconnection_queue_entries, energy.project_permits, energy.project_stage_events, energy.project_external_links to service_role;

create index if not exists idx_energy_projects_stage on energy.projects(development_stage, verification_state);
create index if not exists idx_energy_projects_geo on energy.projects(country_code, state_code, locality);
create index if not exists idx_energy_project_asset_project on energy.project_asset_links(project_id);
create index if not exists idx_energy_project_asset_asset on energy.project_asset_links(asset_id);
create index if not exists idx_energy_project_org_project on energy.project_organization_links(project_id);
create index if not exists idx_energy_project_org_oid on energy.project_organization_links(organization_oid);
create index if not exists idx_energy_project_market_project on energy.project_market_links(project_id);
create index if not exists idx_energy_project_market_market on energy.project_market_links(market_id);
create index if not exists idx_energy_project_market_region on energy.project_market_links(region_id) where region_id is not null;
create index if not exists idx_energy_interconnection_project on energy.interconnection_queue_entries(project_id);
create index if not exists idx_energy_interconnection_market on energy.interconnection_queue_entries(market_id) where market_id is not null;
create index if not exists idx_energy_interconnection_tp on energy.interconnection_queue_entries(transmission_provider_oid) where transmission_provider_oid is not null;
create index if not exists idx_energy_project_permits_project on energy.project_permits(project_id);
create index if not exists idx_energy_project_permits_authority on energy.project_permits(authority_organization_oid) where authority_organization_oid is not null;
create index if not exists idx_energy_project_stage_events_project on energy.project_stage_events(project_id, occurred_at desc);
create index if not exists idx_energy_project_external_project on energy.project_external_links(project_id);

