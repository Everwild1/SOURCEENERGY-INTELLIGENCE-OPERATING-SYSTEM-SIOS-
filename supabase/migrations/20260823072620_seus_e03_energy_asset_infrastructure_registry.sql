create table if not exists energy.assets (
  asset_id uuid primary key default gen_random_uuid(),
  asset_code text not null unique check (asset_code ~ '^[A-Z0-9_-]{3,64}$'),
  asset_name text not null check (length(btrim(asset_name)) > 0),
  asset_class text not null check (asset_class in ('GENERATION','TRANSMISSION','DISTRIBUTION','SUBSTATION','INTERCONNECTION','STORAGE','DER','MICROGRID','EV_INFRASTRUCTURE','HYDROGEN','FUEL_INFRASTRUCTURE','OTHER')),
  technology_type text,
  operational_state text not null default 'REFERENCE' check (operational_state in ('REFERENCE','PLANNED','DEVELOPMENT','CONSTRUCTION','COMMISSIONING','OPERATING','MOTHBALLED','RETIRED','CANCELLED','UNKNOWN')),
  country_code text not null default 'US' check (country_code ~ '^[A-Z]{2}$'),
  state_code text,
  locality text,
  latitude numeric(9,6) check (latitude between -90 and 90),
  longitude numeric(9,6) check (longitude between -180 and 180),
  nameplate_capacity_mw numeric check (nameplate_capacity_mw is null or nameplate_capacity_mw >= 0),
  energy_capacity_mwh numeric check (energy_capacity_mwh is null or energy_capacity_mwh >= 0),
  verification_state text not null default 'REFERENCE' check (verification_state in ('REFERENCE','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  source_as_of date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table energy.assets is 'Governed U.S. energy infrastructure registry for SourceEnergy.us. Registry records do not by themselves establish ownership, operating authority, interconnection rights, market participation rights, permits, licenses, or commercial availability.';

create table if not exists energy.asset_market_links (
  link_id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references energy.assets(asset_id) on delete cascade,
  market_id uuid not null references energy.markets(market_id) on delete restrict,
  region_id uuid references energy.market_regions(region_id) on delete restrict,
  relationship_type text not null check (relationship_type in ('LOCATED_IN','INTERCONNECTED_WITH','PARTICIPATES_IN','SERVES','REFERENCE_ONLY')),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PROPOSED','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','DISPUTED','EXPIRED','ARCHIVED')),
  evidence_reference text,
  effective_from timestamptz,
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(asset_id, market_id, relationship_type)
);

create table if not exists energy.asset_organization_links (
  link_id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references energy.assets(asset_id) on delete cascade,
  organization_oid text not null references public.setc_organizations(oid) on delete restrict,
  organization_role text not null check (organization_role in ('OWNER','CO_OWNER','OPERATOR','DEVELOPER','EPC','OFFTAKER','UTILITY','TRANSMISSION_PROVIDER','AGGREGATOR','HOST','FINANCIER_REFERENCE','OTHER')),
  state text not null default 'PROPOSED' check (state in ('PROPOSED','ASSERTED','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','DISPUTED','EXPIRED','TERMINATED','REVOKED','ARCHIVED')),
  evidence_reference text,
  effective_from timestamptz,
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(asset_id, organization_oid, organization_role)
);

create table if not exists energy.der_resources (
  asset_id uuid primary key references energy.assets(asset_id) on delete cascade,
  der_type text not null check (der_type in ('SOLAR_PV','BATTERY','EV','FLEXIBLE_LOAD','GENERATOR','THERMAL_STORAGE','OTHER')),
  aggregation_eligible boolean,
  export_capable boolean,
  max_export_mw numeric check (max_export_mw is null or max_export_mw >= 0),
  max_import_mw numeric check (max_import_mw is null or max_import_mw >= 0),
  telemetry_status text check (telemetry_status is null or telemetry_status in ('UNKNOWN','NOT_CONNECTED','REFERENCE','CONNECTED','VERIFIED')),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists energy.storage_resources (
  asset_id uuid primary key references energy.assets(asset_id) on delete cascade,
  storage_type text not null check (storage_type in ('BATTERY','PUMPED_HYDRO','THERMAL','HYDROGEN','FLYWHEEL','COMPRESSED_AIR','OTHER')),
  power_mw numeric check (power_mw is null or power_mw >= 0),
  energy_mwh numeric check (energy_mwh is null or energy_mwh >= 0),
  duration_hours numeric generated always as (case when power_mw is not null and power_mw > 0 and energy_mwh is not null then energy_mwh / power_mw else null end) stored,
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists energy.asset_external_references (
  reference_id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references energy.assets(asset_id) on delete cascade,
  authority text not null,
  reference_type text not null check (reference_type in ('EIA','FERC','ISO_RTO','STATE_REGULATOR','UTILITY','INTERCONNECTION_QUEUE','PERMIT','OFFICIAL_SITE','MAP','OTHER')),
  external_reference text not null,
  status text not null default 'ACTIVE_REFERENCE' check (status in ('ACTIVE_REFERENCE','PENDING_VERIFICATION','RETIRED')),
  observed_at timestamptz not null default now(),
  unique(asset_id, authority, reference_type, external_reference)
);

alter table energy.assets enable row level security;
alter table energy.asset_market_links enable row level security;
alter table energy.asset_organization_links enable row level security;
alter table energy.der_resources enable row level security;
alter table energy.storage_resources enable row level security;
alter table energy.asset_external_references enable row level security;

revoke all on energy.assets, energy.asset_market_links, energy.asset_organization_links, energy.der_resources, energy.storage_resources, energy.asset_external_references from anon, authenticated;
grant all on energy.assets, energy.asset_market_links, energy.asset_organization_links, energy.der_resources, energy.storage_resources, energy.asset_external_references to service_role;

create index if not exists idx_energy_assets_class_state on energy.assets(asset_class, operational_state);
create index if not exists idx_energy_assets_geo on energy.assets(country_code, state_code, locality);
create index if not exists idx_energy_asset_market_asset on energy.asset_market_links(asset_id);
create index if not exists idx_energy_asset_market_market on energy.asset_market_links(market_id);
create index if not exists idx_energy_asset_market_region on energy.asset_market_links(region_id) where region_id is not null;
create index if not exists idx_energy_asset_org_asset on energy.asset_organization_links(asset_id);
create index if not exists idx_energy_asset_org_oid on energy.asset_organization_links(organization_oid);
create index if not exists idx_energy_asset_external_asset on energy.asset_external_references(asset_id);

comment on table energy.asset_market_links is 'Evidence-governed market and territory relationships for energy assets; participation or interconnection states require authoritative evidence.';
comment on table energy.asset_organization_links is 'Evidence-governed organization relationships anchored to canonical SETC OIDs; links do not independently establish title, control, licensing, or financial authority.';
