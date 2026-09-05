create type rw.trade_readiness_status as enum ('candidate','assessing','qualified','restricted','inactive');
create type rw.trade_case_status as enum ('draft','under_review','approved','routed','active','completed','cancelled','restricted');
create type rw.outcome_verification_status as enum ('unverified','evidence_received','verified','rejected','superseded');

alter table rw.organizations
  add column if not exists rgl_organization_id uuid references rgl.organizations(id);

create unique index if not exists rw_organizations_rgl_org_unique
  on rw.organizations(rgl_organization_id)
  where rgl_organization_id is not null;

create table rw.trade_readiness_profiles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  assessment_id uuid references rw.assessments(id),
  status rw.trade_readiness_status not null default 'candidate',
  importer_exporter_registration_ready boolean,
  customs_documentation_ready boolean,
  trade_compliance_ready boolean,
  incoterms_capability boolean,
  insurance_readiness boolean,
  logistics_readiness boolean,
  payment_terms_readiness boolean,
  sanctions_screening_status text,
  evidence_ids uuid[] not null default '{}',
  assessed_at timestamptz,
  methodology_version text not null default 'RW-TRADE-0.1',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.trade_route_cases (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  organization_id uuid not null references rw.organizations(id),
  commercialization_case_id uuid references rw.commercialization_cases(id),
  wim_transaction_id uuid references wim.transactions(id),
  wim_trade_corridor_id uuid references wim.trade_corridors(id),
  trade_readiness_profile_id uuid references rw.trade_readiness_profiles(id),
  status rw.trade_case_status not null default 'draft',
  origin_description text,
  destination_description text,
  commodity_or_service text,
  trade_mode text,
  evidence_ids uuid[] not null default '{}',
  conditions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.logistics_referrals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  trade_route_case_id uuid not null references rw.trade_route_cases(id),
  rgl_organization_id uuid references rgl.organizations(id),
  referral_type text not null check (referral_type in ('assessment','quotation','fulfillment','shipment','customs','warehousing','last_mile','multimodal','other')),
  status text not null default 'requested' check (status in ('requested','under_review','accepted','declined','completed','cancelled')),
  external_reference text,
  evidence_ids uuid[] not null default '{}',
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table rw.execution_links (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  trade_route_case_id uuid references rw.trade_route_cases(id),
  wim_transaction_id uuid references wim.transactions(id),
  rgl_order_id uuid references rgl.orders(id),
  rgl_shipment_id uuid references rgl.shipments(id),
  rgl_delivery_evidence_id uuid references rgl.delivery_evidence(id),
  link_status text not null default 'referenced' check (link_status in ('referenced','active','completed','exception','superseded')),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.commercial_outcomes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  commercialization_case_id uuid references rw.commercialization_cases(id),
  execution_link_id uuid references rw.execution_links(id),
  wim_transaction_id uuid references wim.transactions(id),
  outcome_type text not null check (outcome_type in ('contract_awarded','sale','purchase','service_delivery','export','import','shipment_delivered','revenue_realized','procurement_completed','other')),
  occurred_at timestamptz not null,
  currency_code text,
  gross_amount numeric,
  verification_status rw.outcome_verification_status not null default 'unverified',
  evidence_ids uuid[] not null default '{}',
  external_reference text,
  notes text,
  created_at timestamptz not null default now()
);

create table rw.impact_observations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  commercial_outcome_id uuid references rw.commercial_outcomes(id),
  wim_metric_code text references wim.impact_metric_registry(metric_code),
  wim_impact_metric_id uuid references wim.impact_metrics(id),
  rgl_economic_event_id uuid references rgl.economic_events(id),
  rgl_wealth_ecology_impact_id uuid references rgl.wealth_ecology_impacts(id),
  metric_value numeric not null,
  metric_unit text not null,
  measurement_period_start date,
  measurement_period_end date,
  methodology_version text not null default 'RW-WEALTH-ECOLOGY-0.1',
  verification_status rw.outcome_verification_status not null default 'unverified',
  evidence_ids uuid[] not null default '{}',
  measured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (measurement_period_end is null or measurement_period_start is null or measurement_period_end >= measurement_period_start)
);

create table rw.wealth_yield_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  period_start date not null,
  period_end date not null,
  methodology_version text not null default 'RW-WY-0.1',
  value_created_amount numeric,
  value_created_currency text,
  jobs_created numeric,
  jobs_sustained numeric,
  procurement_value numeric,
  export_value numeric,
  local_supplier_value numeric,
  community_value numeric,
  enterprise_reinvestment_value numeric,
  impact_observation_ids uuid[] not null default '{}',
  verification_status rw.outcome_verification_status not null default 'unverified',
  evidence_ids uuid[] not null default '{}',
  notes text,
  created_at timestamptz not null default now(),
  check (period_end >= period_start)
);

create table rw.replication_evidence (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  source_commercial_outcome_id uuid references rw.commercial_outcomes(id),
  source_wealth_yield_record_id uuid references rw.wealth_yield_records(id),
  replication_type text not null check (replication_type in ('new_market','new_jurisdiction','new_cluster','new_location','licensed_model','franchise','joint_venture','capacity_expansion','other')),
  target_market_id uuid references wim.markets(id),
  target_cluster_id bigint references wim.economic_clusters(id),
  status text not null default 'candidate' check (status in ('candidate','approved','active','validated','completed','cancelled','restricted')),
  rationale text,
  evidence_ids uuid[] not null default '{}',
  approved_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table rw.trade_readiness_profiles is 'RW trade-readiness assessment only; does not confer customs, sanctions, licensing, import/export, banking, or regulatory approval.';
comment on table rw.execution_links is 'References authoritative WIM/RGL execution records; RW does not confer transaction, shipment, delivery, or settlement finality.';
comment on table rw.wealth_yield_records is 'Wealth Ecology impact/accounting intelligence construct; not investment yield, interest, dividend, security return, or promise of financial performance.';
comment on table rw.replication_evidence is 'Evidence and governance for enterprise replication; does not itself authorize market entry, licensing, financing, or contracting.';

create index rw_trade_readiness_org_idx on rw.trade_readiness_profiles(organization_id);
create index rw_trade_readiness_assessment_idx on rw.trade_readiness_profiles(assessment_id);
create index rw_trade_cases_org_idx on rw.trade_route_cases(organization_id);
create index rw_trade_cases_commercialization_idx on rw.trade_route_cases(commercialization_case_id);
create index rw_trade_cases_wim_tx_idx on rw.trade_route_cases(wim_transaction_id);
create index rw_trade_cases_corridor_idx on rw.trade_route_cases(wim_trade_corridor_id);
create index rw_trade_cases_profile_idx on rw.trade_route_cases(trade_readiness_profile_id);
create index rw_logistics_referrals_org_idx on rw.logistics_referrals(organization_id);
create index rw_logistics_referrals_case_idx on rw.logistics_referrals(trade_route_case_id);
create index rw_logistics_referrals_rgl_org_idx on rw.logistics_referrals(rgl_organization_id);
create index rw_execution_links_org_idx on rw.execution_links(organization_id);
create index rw_execution_links_case_idx on rw.execution_links(trade_route_case_id);
create index rw_execution_links_wim_tx_idx on rw.execution_links(wim_transaction_id);
create index rw_execution_links_order_idx on rw.execution_links(rgl_order_id);
create index rw_execution_links_shipment_idx on rw.execution_links(rgl_shipment_id);
create index rw_execution_links_delivery_idx on rw.execution_links(rgl_delivery_evidence_id);
create index rw_commercial_outcomes_org_idx on rw.commercial_outcomes(organization_id);
create index rw_commercial_outcomes_case_idx on rw.commercial_outcomes(commercialization_case_id);
create index rw_commercial_outcomes_exec_idx on rw.commercial_outcomes(execution_link_id);
create index rw_commercial_outcomes_wim_tx_idx on rw.commercial_outcomes(wim_transaction_id);
create index rw_impact_obs_org_idx on rw.impact_observations(organization_id);
create index rw_impact_obs_outcome_idx on rw.impact_observations(commercial_outcome_id);
create index rw_impact_obs_metric_code_idx on rw.impact_observations(wim_metric_code);
create index rw_impact_obs_wim_metric_idx on rw.impact_observations(wim_impact_metric_id);
create index rw_impact_obs_rgl_event_idx on rw.impact_observations(rgl_economic_event_id);
create index rw_impact_obs_rgl_wealth_idx on rw.impact_observations(rgl_wealth_ecology_impact_id);
create index rw_wealth_yield_org_period_idx on rw.wealth_yield_records(organization_id, period_start, period_end);
create index rw_replication_org_idx on rw.replication_evidence(organization_id);
create index rw_replication_outcome_idx on rw.replication_evidence(source_commercial_outcome_id);
create index rw_replication_yield_idx on rw.replication_evidence(source_wealth_yield_record_id);
create index rw_replication_market_idx on rw.replication_evidence(target_market_id);
create index rw_replication_cluster_idx on rw.replication_evidence(target_cluster_id);

alter table rw.trade_readiness_profiles enable row level security;
alter table rw.trade_route_cases enable row level security;
alter table rw.logistics_referrals enable row level security;
alter table rw.execution_links enable row level security;
alter table rw.commercial_outcomes enable row level security;
alter table rw.impact_observations enable row level security;
alter table rw.wealth_yield_records enable row level security;
alter table rw.replication_evidence enable row level security;

revoke all on rw.trade_readiness_profiles, rw.trade_route_cases, rw.logistics_referrals, rw.execution_links, rw.commercial_outcomes, rw.impact_observations, rw.wealth_yield_records, rw.replication_evidence from anon, authenticated;
grant usage on schema rw to service_role;
grant all on rw.trade_readiness_profiles, rw.trade_route_cases, rw.logistics_referrals, rw.execution_links, rw.commercial_outcomes, rw.impact_observations, rw.wealth_yield_records, rw.replication_evidence to service_role;
