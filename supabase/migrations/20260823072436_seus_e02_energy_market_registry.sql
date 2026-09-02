create schema if not exists energy;

revoke all on schema energy from anon, authenticated;
grant usage on schema energy to service_role;

create table energy.markets (
  market_id uuid primary key default gen_random_uuid(),
  market_code text not null unique check (market_code ~ '^[A-Z0-9_-]{2,32}$'),
  market_name text not null check (length(btrim(market_name)) > 0),
  market_class text not null check (market_class in ('RTO','ISO','ERCOT','NON_RTO')),
  regulatory_scope text not null check (regulatory_scope in ('FERC','STATE','MIXED','OTHER')),
  jurisdiction_summary text,
  verification_state text not null default 'REFERENCE_VERIFIED' check (verification_state in ('REFERENCE','REFERENCE_VERIFIED','PENDING_VERIFICATION','VERIFIED','SUSPENDED','ARCHIVED')),
  evidence_reference text,
  source_as_of date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table energy.markets is 'Authoritative SourceEnergy U.S. electricity market registry. Registry status describes reference verification only and does not confer regulatory, trading, market-participant, or licensing authority.';

create table energy.market_regions (
  region_id uuid primary key default gen_random_uuid(),
  region_code text not null unique check (region_code ~ '^[A-Z0-9_-]{2,48}$'),
  region_name text not null check (length(btrim(region_name)) > 0),
  region_type text not null check (region_type in ('MARKET_TERRITORY','NON_RTO_REGION','STATE','SUBREGION')),
  market_id uuid references energy.markets(market_id) on delete restrict,
  parent_region_id uuid references energy.market_regions(region_id) on delete restrict,
  geography_summary text,
  status text not null default 'REFERENCE' check (status in ('REFERENCE','ACTIVE_REFERENCE','PENDING_VERIFICATION','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table energy.market_regions is 'Geographic and market-territory reference layer for SourceEnergy.us. Boundaries are informational unless backed by authoritative evidence.';

create table energy.market_organization_links (
  link_id uuid primary key default gen_random_uuid(),
  market_id uuid not null references energy.markets(market_id) on delete restrict,
  organization_oid text not null references public.setc_organizations(oid) on delete restrict,
  organization_role text not null check (organization_role in ('MARKET_OPERATOR','RTO','ISO','REGULATOR','UTILITY','TRANSMISSION_OWNER','MARKET_PARTICIPANT','AGGREGATOR','OTHER')),
  state text not null default 'PROPOSED' check (state in ('PROPOSED','ASSERTED','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','DISPUTED','EXPIRED','TERMINATED','REVOKED','ARCHIVED')),
  evidence_reference text,
  effective_from timestamptz,
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (market_id, organization_oid, organization_role)
);

comment on table energy.market_organization_links is 'Evidence-governed links between U.S. electricity markets and canonical SETC organizations. A link does not itself establish legal or regulatory authority.';

create table energy.market_external_references (
  reference_id uuid primary key default gen_random_uuid(),
  market_id uuid not null references energy.markets(market_id) on delete cascade,
  authority text not null,
  reference_type text not null check (reference_type in ('OFFICIAL_SITE','REGULATOR','FILING','DOCKET','MAP','OTHER')),
  external_reference text not null,
  status text not null default 'ACTIVE_REFERENCE' check (status in ('ACTIVE_REFERENCE','PENDING_VERIFICATION','RETIRED')),
  observed_at timestamptz not null default now(),
  unique (market_id, authority, reference_type, external_reference)
);

alter table energy.markets enable row level security;
alter table energy.market_regions enable row level security;
alter table energy.market_organization_links enable row level security;
alter table energy.market_external_references enable row level security;

revoke all on all tables in schema energy from anon, authenticated;
grant all on all tables in schema energy to service_role;
grant usage, select on all sequences in schema energy to service_role;

alter default privileges in schema energy revoke all on tables from anon, authenticated;
alter default privileges in schema energy grant all on tables to service_role;
alter default privileges in schema energy grant usage, select on sequences to service_role;

insert into energy.markets (market_code, market_name, market_class, regulatory_scope, jurisdiction_summary, verification_state, evidence_reference, source_as_of)
values
('PJM','PJM Interconnection','RTO','FERC','Organized U.S. wholesale electricity market operated under FERC jurisdiction.','REFERENCE_VERIFIED','FERC Introductory Guide to Electricity Markets','2026-08-23'),
('MISO','Midcontinent Independent System Operator','RTO','FERC','Organized U.S. wholesale electricity market operated under FERC jurisdiction.','REFERENCE_VERIFIED','FERC Introductory Guide to Electricity Markets','2026-08-23'),
('CAISO','California Independent System Operator','ISO','FERC','Organized U.S. wholesale electricity market operated under FERC jurisdiction.','REFERENCE_VERIFIED','FERC Introductory Guide to Electricity Markets','2026-08-23'),
('SPP','Southwest Power Pool','RTO','FERC','Organized U.S. wholesale electricity market operated under FERC jurisdiction.','REFERENCE_VERIFIED','FERC Introductory Guide to Electricity Markets','2026-08-23'),
('NYISO','New York Independent System Operator','ISO','FERC','Organized U.S. wholesale electricity market operated under FERC jurisdiction.','REFERENCE_VERIFIED','FERC Introductory Guide to Electricity Markets','2026-08-23'),
('ISO_NE','ISO New England','ISO','FERC','Organized U.S. wholesale electricity market operated under FERC jurisdiction.','REFERENCE_VERIFIED','FERC Introductory Guide to Electricity Markets','2026-08-23'),
('ERCOT','Electric Reliability Council of Texas','ERCOT','STATE','Regional grid operator and electricity market primarily subject to Texas state oversight rather than FERC wholesale-market jurisdiction.','REFERENCE_VERIFIED','FERC Introductory Guide to Electricity Markets','2026-08-23'),
('US_NON_RTO','U.S. Non-RTO/ISO Regions','NON_RTO','MIXED','Reference umbrella for U.S. regions outside organized RTO/ISO market territories.','REFERENCE_VERIFIED','FERC RTO/ISO regional market references','2026-08-23')
on conflict (market_code) do nothing;

insert into energy.market_regions (region_code, region_name, region_type, market_id, geography_summary, status, evidence_reference)
select 'NON_RTO_NORTHWEST','Northwest Non-RTO Region','NON_RTO_REGION', market_id,'Reference region outside an RTO/ISO market territory; precise utility and balancing-authority boundaries require separate evidence.','ACTIVE_REFERENCE','FERC regional market map'
from energy.markets where market_code='US_NON_RTO'
on conflict (region_code) do nothing;

insert into energy.market_regions (region_code, region_name, region_type, market_id, geography_summary, status, evidence_reference)
select 'NON_RTO_SOUTHWEST','Southwest Non-RTO Region','NON_RTO_REGION', market_id,'Reference region outside an RTO/ISO market territory; precise utility and balancing-authority boundaries require separate evidence.','ACTIVE_REFERENCE','FERC regional market map'
from energy.markets where market_code='US_NON_RTO'
on conflict (region_code) do nothing;

insert into energy.market_regions (region_code, region_name, region_type, market_id, geography_summary, status, evidence_reference)
select 'NON_RTO_SOUTHEAST','Southeast Non-RTO Region','NON_RTO_REGION', market_id,'Reference region outside an RTO/ISO market territory; precise utility and balancing-authority boundaries require separate evidence.','ACTIVE_REFERENCE','FERC regional market map'
from energy.markets where market_code='US_NON_RTO'
on conflict (region_code) do nothing;
