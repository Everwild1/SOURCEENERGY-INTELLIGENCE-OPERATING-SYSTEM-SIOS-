create table if not exists energy.commercial_agreements (
  agreement_id uuid primary key default gen_random_uuid(),
  agreement_code text not null unique check (agreement_code ~ '^[A-Z0-9_-]{3,64}$'),
  agreement_type text not null check (agreement_type in ('PPA','VPPA','OFFTAKE','TOLLING','CAPACITY','ENERGY_SERVICES','FUEL_SUPPLY','REC','INTERCONNECTION_RELATED','OTHER')),
  agreement_title text not null check (length(btrim(agreement_title)) > 0),
  commercial_state text not null default 'DRAFT' check (commercial_state in ('DRAFT','INDICATIVE','NEGOTIATING','PENDING_APPROVAL','EXECUTED_REFERENCE','ACTIVE_REFERENCE','SUSPENDED','TERMINATED','EXPIRED','DISPUTED','ARCHIVED')),
  verification_state text not null default 'REFERENCE' check (verification_state in ('REFERENCE','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  governing_law_reference text,
  effective_date date,
  expiration_date date,
  contract_reference text,
  evidence_reference text,
  source_as_of date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table energy.commercial_agreements is 'Evidence-governed commercial agreement registry for SourceEnergy.us. EXECUTED_REFERENCE or VERIFIED states require authoritative evidence and do not themselves prove enforceability, regulatory approval, credit support, settlement, or performance.';

create table if not exists energy.agreement_counterparties (
  counterparty_id uuid primary key default gen_random_uuid(),
  agreement_id uuid not null references energy.commercial_agreements(agreement_id) on delete cascade,
  organization_oid text not null references public.setc_organizations(oid) on delete restrict,
  counterparty_role text not null check (counterparty_role in ('SELLER','BUYER','GENERATOR','OFFTAKER','UTILITY','MARKETER','AGGREGATOR','GUARANTOR_REFERENCE','TRANSMISSION_PROVIDER','AGENT_REFERENCE','OTHER')),
  state text not null default 'PROPOSED' check (state in ('PROPOSED','ASSERTED','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','DISPUTED','EXPIRED','TERMINATED','REVOKED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(agreement_id, organization_oid, counterparty_role)
);

create table if not exists energy.agreement_project_links (
  link_id uuid primary key default gen_random_uuid(),
  agreement_id uuid not null references energy.commercial_agreements(agreement_id) on delete cascade,
  project_id uuid not null references energy.projects(project_id) on delete restrict,
  relationship_type text not null check (relationship_type in ('PRIMARY_PROJECT','SUPPLY_SOURCE','OFFTAKE_PROJECT','HOST_PROJECT','REFERENCE_ONLY')),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PROPOSED','PENDING_VERIFICATION','VERIFIED','ACTIVE','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  unique(agreement_id, project_id, relationship_type)
);

create table if not exists energy.agreement_asset_links (
  link_id uuid primary key default gen_random_uuid(),
  agreement_id uuid not null references energy.commercial_agreements(agreement_id) on delete cascade,
  asset_id uuid not null references energy.assets(asset_id) on delete restrict,
  relationship_type text not null check (relationship_type in ('DELIVERY_ASSET','GENERATION_SOURCE','STORAGE_SOURCE','HOST_ASSET','REFERENCE_ONLY')),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PROPOSED','PENDING_VERIFICATION','VERIFIED','ACTIVE','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  unique(agreement_id, asset_id, relationship_type)
);

create table if not exists energy.agreement_market_links (
  link_id uuid primary key default gen_random_uuid(),
  agreement_id uuid not null references energy.commercial_agreements(agreement_id) on delete cascade,
  market_id uuid not null references energy.markets(market_id) on delete restrict,
  relationship_type text not null check (relationship_type in ('DELIVERY_MARKET','SETTLEMENT_MARKET_REFERENCE','CAPACITY_MARKET_REFERENCE','REFERENCE_ONLY')),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED','ACTIVE','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  unique(agreement_id, market_id, relationship_type)
);

create table if not exists energy.agreement_terms (
  term_id uuid primary key default gen_random_uuid(),
  agreement_id uuid not null references energy.commercial_agreements(agreement_id) on delete cascade,
  term_type text not null check (term_type in ('CONTRACT_CAPACITY_MW','ANNUAL_ENERGY_MWH','TERM_YEARS','PRICE_REFERENCE','PRICE_AMOUNT','CURRENCY','ESCALATOR','DELIVERY_POINT','PRODUCT','REC_TREATMENT','CREDIT_SUPPORT_REFERENCE','OTHER')),
  term_value_text text,
  term_value_numeric numeric,
  unit text,
  confidentiality_state text not null default 'INTERNAL' check (confidentiality_state in ('PUBLIC_REFERENCE','INTERNAL','RESTRICTED')),
  verification_state text not null default 'REFERENCE' check (verification_state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists energy.commercial_transaction_intents (
  intent_id uuid primary key default gen_random_uuid(),
  intent_code text not null unique check (intent_code ~ '^[A-Z0-9_-]{3,64}$'),
  agreement_id uuid references energy.commercial_agreements(agreement_id) on delete set null,
  project_id uuid references energy.projects(project_id) on delete set null,
  buyer_organization_oid text references public.setc_organizations(oid) on delete restrict,
  seller_organization_oid text references public.setc_organizations(oid) on delete restrict,
  intent_type text not null check (intent_type in ('ENERGY_PURCHASE','ENERGY_SALE','CAPACITY_PURCHASE','CAPACITY_SALE','OFFTAKE','FUEL_PURCHASE','FUEL_SALE','OTHER')),
  requested_quantity numeric check (requested_quantity is null or requested_quantity >= 0),
  quantity_unit text,
  requested_amount numeric check (requested_amount is null or requested_amount >= 0),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  intent_state text not null default 'INDICATIVE' check (intent_state in ('INDICATIVE','QUALIFYING','NEGOTIATING','PENDING_APPROVAL','APPROVED_REFERENCE','SUBMITTED_TO_EXECUTION','CANCELLED','EXPIRED','ARCHIVED')),
  verification_state text not null default 'REFERENCE' check (verification_state in ('REFERENCE','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table energy.commercial_transaction_intents is 'Pre-execution commercial intent registry. A record here is not a trade confirmation, settlement event, purchase order, executed contract, financing commitment, or proof of performance.';

create table if not exists energy.execution_references (
  execution_reference_id uuid primary key default gen_random_uuid(),
  intent_id uuid references energy.commercial_transaction_intents(intent_id) on delete cascade,
  agreement_id uuid references energy.commercial_agreements(agreement_id) on delete cascade,
  system_name text not null check (system_name in ('WIM','IOTF','RGL','RW','HEI','OTHER')),
  external_entity_type text not null check (external_entity_type in ('TRANSACTION','TRANSACTION_REQUEST','SETTLEMENT_REQUEST','SETTLEMENT_EVENT','ORDER','SHIPMENT','COMMERCIAL_OUTCOME','OTHER')),
  external_reference text not null,
  execution_state text not null default 'REFERENCE' check (execution_state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED_REFERENCE','ACTIVE_REFERENCE','RECONCILED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  observed_at timestamptz not null default now(),
  check (intent_id is not null or agreement_id is not null),
  unique(system_name, external_entity_type, external_reference)
);
comment on table energy.execution_references is 'Reference-only bridge to authoritative WIM/IOTF/RGL/RW/HEI execution records. This table does not own or recreate settlement, logistics, trade, or outcome state.';

alter table energy.commercial_agreements enable row level security;
alter table energy.agreement_counterparties enable row level security;
alter table energy.agreement_project_links enable row level security;
alter table energy.agreement_asset_links enable row level security;
alter table energy.agreement_market_links enable row level security;
alter table energy.agreement_terms enable row level security;
alter table energy.commercial_transaction_intents enable row level security;
alter table energy.execution_references enable row level security;

revoke all on energy.commercial_agreements, energy.agreement_counterparties, energy.agreement_project_links, energy.agreement_asset_links, energy.agreement_market_links, energy.agreement_terms, energy.commercial_transaction_intents, energy.execution_references from anon, authenticated;
grant all on energy.commercial_agreements, energy.agreement_counterparties, energy.agreement_project_links, energy.agreement_asset_links, energy.agreement_market_links, energy.agreement_terms, energy.commercial_transaction_intents, energy.execution_references to service_role;

create index if not exists idx_energy_agreement_counterparty_agreement on energy.agreement_counterparties(agreement_id);
create index if not exists idx_energy_agreement_counterparty_oid on energy.agreement_counterparties(organization_oid);
create index if not exists idx_energy_agreement_project_agreement on energy.agreement_project_links(agreement_id);
create index if not exists idx_energy_agreement_project_project on energy.agreement_project_links(project_id);
create index if not exists idx_energy_agreement_asset_agreement on energy.agreement_asset_links(agreement_id);
create index if not exists idx_energy_agreement_asset_asset on energy.agreement_asset_links(asset_id);
create index if not exists idx_energy_agreement_market_agreement on energy.agreement_market_links(agreement_id);
create index if not exists idx_energy_agreement_market_market on energy.agreement_market_links(market_id);
create index if not exists idx_energy_agreement_terms_agreement on energy.agreement_terms(agreement_id);
create index if not exists idx_energy_intents_agreement on energy.commercial_transaction_intents(agreement_id) where agreement_id is not null;
create index if not exists idx_energy_intents_project on energy.commercial_transaction_intents(project_id) where project_id is not null;
create index if not exists idx_energy_intents_buyer on energy.commercial_transaction_intents(buyer_organization_oid) where buyer_organization_oid is not null;
create index if not exists idx_energy_intents_seller on energy.commercial_transaction_intents(seller_organization_oid) where seller_organization_oid is not null;
create index if not exists idx_energy_exec_intent on energy.execution_references(intent_id) where intent_id is not null;
create index if not exists idx_energy_exec_agreement on energy.execution_references(agreement_id) where agreement_id is not null;
