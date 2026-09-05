create table if not exists energy.environmental_attribute_programs (
  program_id uuid primary key default gen_random_uuid(),
  program_code text not null unique check (program_code ~ '^[A-Z0-9_-]{3,64}$'),
  program_name text not null check (length(btrim(program_name)) > 0),
  program_type text not null check (program_type in ('REC_REGISTRY','CARBON_REGISTRY','EMISSIONS_PROGRAM','CLEAN_ENERGY_STANDARD','VOLUNTARY_STANDARD','OTHER')),
  jurisdiction text,
  administrator_name text,
  administrator_organization_oid text references public.setc_organizations(oid) on delete restrict,
  verification_state text not null default 'REFERENCE' check (verification_state in ('REFERENCE','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  external_reference text,
  evidence_reference text,
  source_as_of date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table energy.environmental_attribute_programs is 'Reference registry for REC, carbon, emissions, and clean-energy programs. Registration here does not establish program eligibility, accreditation, issuance authority, or legal compliance.';

create table if not exists energy.environmental_attributes (
  attribute_id uuid primary key default gen_random_uuid(),
  attribute_code text not null unique check (attribute_code ~ '^[A-Z0-9_-]{3,96}$'),
  attribute_type text not null check (attribute_type in ('REC','SREC','GO_REFERENCE','CARBON_CREDIT','CARBON_OFFSET_REFERENCE','EMISSIONS_ALLOWANCE_REFERENCE','CLEAN_ENERGY_ATTRIBUTE','OTHER')),
  program_id uuid references energy.environmental_attribute_programs(program_id) on delete restrict,
  project_id uuid references energy.projects(project_id) on delete restrict,
  asset_id uuid references energy.assets(asset_id) on delete restrict,
  vintage_start date,
  vintage_end date,
  quantity numeric not null check (quantity > 0),
  unit text not null,
  attribute_state text not null default 'REFERENCE' check (attribute_state in ('REFERENCE','PENDING_ELIGIBILITY','ELIGIBLE_REFERENCE','ISSUED_REFERENCE','TRANSFERRED_REFERENCE','RETIRED_REFERENCE','CANCELLED_REFERENCE','DISPUTED','ARCHIVED')),
  verification_state text not null default 'REFERENCE' check (verification_state in ('REFERENCE','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  serial_or_batch_reference text,
  evidence_reference text,
  source_as_of date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (project_id is not null or asset_id is not null),
  check (vintage_end is null or vintage_start is null or vintage_end >= vintage_start)
);
comment on table energy.environmental_attributes is 'Environmental attribute evidence registry. ISSUED_REFERENCE, TRANSFERRED_REFERENCE, or RETIRED_REFERENCE states are references to external evidence and do not mint, transfer, retire, or settle certificates in this database.';

create table if not exists energy.attribute_generation_links (
  link_id uuid primary key default gen_random_uuid(),
  attribute_id uuid not null references energy.environmental_attributes(attribute_id) on delete cascade,
  generation_observation_id bigint references energy.generation_observations(observation_id) on delete restrict,
  meter_reading_id bigint references energy.meter_readings(reading_id) on delete restrict,
  relationship_type text not null check (relationship_type in ('SUPPORTING_GENERATION','ELIGIBILITY_EVIDENCE','REFERENCE_ONLY')),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  check (generation_observation_id is not null or meter_reading_id is not null),
  unique(attribute_id, generation_observation_id, meter_reading_id, relationship_type)
);
comment on table energy.attribute_generation_links is 'Links certificates or attributes to operational evidence. The link does not itself prove issuance eligibility or registry acceptance.';

create table if not exists energy.attribute_lifecycle_events (
  event_id uuid primary key default gen_random_uuid(),
  attribute_id uuid not null references energy.environmental_attributes(attribute_id) on delete cascade,
  event_type text not null check (event_type in ('ELIGIBILITY_SUBMISSION','ELIGIBILITY_APPROVAL_REFERENCE','ISSUANCE_REFERENCE','TRANSFER_REFERENCE','RETIREMENT_REFERENCE','CANCELLATION_REFERENCE','CORRECTION','DISPUTE','OTHER')),
  event_state text not null default 'REFERENCE' check (event_state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED_REFERENCE','VERIFIED','DISPUTED','REJECTED','ARCHIVED')),
  quantity numeric check (quantity is null or quantity > 0),
  unit text,
  counterparty_organization_oid text references public.setc_organizations(oid) on delete restrict,
  external_event_reference text,
  evidence_reference text,
  occurred_at timestamptz,
  observed_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
comment on table energy.attribute_lifecycle_events is 'Reference lifecycle events for environmental attributes. Events do not execute registry transfers, retirement, cancellation, or settlement.';

create table if not exists energy.emissions_observations (
  observation_id bigint generated by default as identity primary key,
  project_id uuid references energy.projects(project_id) on delete set null,
  asset_id uuid references energy.assets(asset_id) on delete set null,
  source_id uuid references energy.measurement_sources(source_id) on delete set null,
  emissions_scope text not null check (emissions_scope in ('SCOPE_1','SCOPE_2_LOCATION','SCOPE_2_MARKET','SCOPE_3_REFERENCE','AVOIDED_EMISSIONS_REFERENCE','OTHER')),
  pollutant text not null check (pollutant in ('CO2','CO2E','CH4','N2O','NOX','SO2','PM','OTHER')),
  observation_kind text not null check (observation_kind in ('MEASURED','CALCULATED','ESTIMATED','MODELED','FORECAST','CORRECTED')),
  period_start timestamptz not null,
  period_end timestamptz not null,
  quantity numeric not null check (quantity >= 0),
  unit text not null,
  methodology_reference text,
  emission_factor_reference text,
  quality_state text not null default 'UNVERIFIED' check (quality_state in ('UNVERIFIED','SOURCE_VERIFIED','VALIDATED','ESTIMATED','MODELED','FORECAST','CORRECTED','DISPUTED','REJECTED')),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (project_id is not null or asset_id is not null),
  check (period_end > period_start),
  check ((observation_kind = 'MODELED' and quality_state in ('MODELED','UNVERIFIED')) or
         (observation_kind = 'FORECAST' and quality_state in ('FORECAST','UNVERIFIED')) or
         (observation_kind not in ('MODELED','FORECAST')))
);
comment on table energy.emissions_observations is 'Measured, calculated, estimated, modeled, or forecast emissions evidence with explicit quality classification. Records do not independently establish regulatory emissions compliance, offsets, credits, or avoided-emissions claims.';

create table if not exists energy.sustainability_claims (
  claim_id uuid primary key default gen_random_uuid(),
  claim_code text not null unique check (claim_code ~ '^[A-Z0-9_-]{3,96}$'),
  project_id uuid references energy.projects(project_id) on delete restrict,
  asset_id uuid references energy.assets(asset_id) on delete restrict,
  organization_oid text references public.setc_organizations(oid) on delete restrict,
  claim_type text not null check (claim_type in ('RENEWABLE_GENERATION','LOW_CARBON','CARBON_NEUTRAL_REFERENCE','NET_ZERO_REFERENCE','EMISSIONS_REDUCTION','AVOIDED_EMISSIONS','REC_BACKED','CLEAN_ENERGY','OTHER')),
  claim_text text not null check (length(btrim(claim_text)) > 0),
  period_start date,
  period_end date,
  claim_state text not null default 'DRAFT' check (claim_state in ('DRAFT','INTERNAL_REVIEW','PENDING_EVIDENCE','EVIDENCE_ASSEMBLED','VERIFIED_REFERENCE','APPROVED_FOR_PUBLICATION','PUBLISHED_REFERENCE','WITHDRAWN','DISPUTED','ARCHIVED')),
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','REJECTED','ARCHIVED')),
  methodology_reference text,
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (project_id is not null or asset_id is not null or organization_oid is not null),
  check (period_end is null or period_start is null or period_end >= period_start),
  check (claim_state not in ('VERIFIED_REFERENCE','APPROVED_FOR_PUBLICATION','PUBLISHED_REFERENCE') or evidence_reference is not null)
);
comment on table energy.sustainability_claims is 'Governed sustainability assertion registry. Public-facing or verified-reference states require evidence; this table does not itself certify environmental performance or regulatory compliance.';

create table if not exists energy.claim_attribute_links (
  link_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references energy.sustainability_claims(claim_id) on delete cascade,
  attribute_id uuid not null references energy.environmental_attributes(attribute_id) on delete restrict,
  relationship_type text not null check (relationship_type in ('SUPPORTS','RETIRED_FOR_CLAIM_REFERENCE','DISCLOSURE_REFERENCE','OTHER')),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  unique(claim_id, attribute_id, relationship_type)
);

create table if not exists energy.claim_emissions_links (
  link_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references energy.sustainability_claims(claim_id) on delete cascade,
  emissions_observation_id bigint not null references energy.emissions_observations(observation_id) on delete restrict,
  relationship_type text not null check (relationship_type in ('SUPPORTS','BASELINE','COMPARISON','DISCLOSURE_REFERENCE','OTHER')),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  unique(claim_id, emissions_observation_id, relationship_type)
);

create table if not exists energy.environmental_external_references (
  reference_id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('PROGRAM','ATTRIBUTE','ATTRIBUTE_EVENT','EMISSIONS_OBSERVATION','SUSTAINABILITY_CLAIM')),
  entity_reference text not null,
  system_name text not null check (system_name in ('REGISTRY','REGULATOR','WIM','IOTF','CRUDS','RGL','RW','SETC','OTHER')),
  external_entity_type text not null,
  external_reference text not null,
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED_REFERENCE','RECONCILED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  observed_at timestamptz not null default now(),
  unique(entity_type, entity_reference, system_name, external_reference)
);

alter table energy.environmental_attribute_programs enable row level security;
alter table energy.environmental_attributes enable row level security;
alter table energy.attribute_generation_links enable row level security;
alter table energy.attribute_lifecycle_events enable row level security;
alter table energy.emissions_observations enable row level security;
alter table energy.sustainability_claims enable row level security;
alter table energy.claim_attribute_links enable row level security;
alter table energy.claim_emissions_links enable row level security;
alter table energy.environmental_external_references enable row level security;

revoke all on energy.environmental_attribute_programs, energy.environmental_attributes, energy.attribute_generation_links, energy.attribute_lifecycle_events, energy.emissions_observations, energy.sustainability_claims, energy.claim_attribute_links, energy.claim_emissions_links, energy.environmental_external_references from anon, authenticated;
grant all on energy.environmental_attribute_programs, energy.environmental_attributes, energy.attribute_generation_links, energy.attribute_lifecycle_events, energy.emissions_observations, energy.sustainability_claims, energy.claim_attribute_links, energy.claim_emissions_links, energy.environmental_external_references to service_role;

create index if not exists idx_energy_env_program_admin on energy.environmental_attribute_programs(administrator_organization_oid) where administrator_organization_oid is not null;
create index if not exists idx_energy_env_attribute_program on energy.environmental_attributes(program_id) where program_id is not null;
create index if not exists idx_energy_env_attribute_project on energy.environmental_attributes(project_id) where project_id is not null;
create index if not exists idx_energy_env_attribute_asset on energy.environmental_attributes(asset_id) where asset_id is not null;
create index if not exists idx_energy_attr_generation_attr on energy.attribute_generation_links(attribute_id);
create index if not exists idx_energy_attr_generation_obs on energy.attribute_generation_links(generation_observation_id) where generation_observation_id is not null;
create index if not exists idx_energy_attr_meter_reading on energy.attribute_generation_links(meter_reading_id) where meter_reading_id is not null;
create index if not exists idx_energy_attr_events_attr_time on energy.attribute_lifecycle_events(attribute_id, observed_at desc);
create index if not exists idx_energy_attr_events_counterparty on energy.attribute_lifecycle_events(counterparty_organization_oid) where counterparty_organization_oid is not null;
create index if not exists idx_energy_emissions_project_period on energy.emissions_observations(project_id, period_start desc) where project_id is not null;
create index if not exists idx_energy_emissions_asset_period on energy.emissions_observations(asset_id, period_start desc) where asset_id is not null;
create index if not exists idx_energy_emissions_source on energy.emissions_observations(source_id) where source_id is not null;
create index if not exists idx_energy_claim_project on energy.sustainability_claims(project_id) where project_id is not null;
create index if not exists idx_energy_claim_asset on energy.sustainability_claims(asset_id) where asset_id is not null;
create index if not exists idx_energy_claim_org on energy.sustainability_claims(organization_oid) where organization_oid is not null;
create index if not exists idx_energy_claim_attr_claim on energy.claim_attribute_links(claim_id);
create index if not exists idx_energy_claim_attr_attribute on energy.claim_attribute_links(attribute_id);
create index if not exists idx_energy_claim_emissions_claim on energy.claim_emissions_links(claim_id);
create index if not exists idx_energy_claim_emissions_obs on energy.claim_emissions_links(emissions_observation_id);
