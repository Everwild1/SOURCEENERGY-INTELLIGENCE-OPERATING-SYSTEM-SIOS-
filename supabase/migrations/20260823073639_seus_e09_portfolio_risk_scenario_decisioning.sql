create table if not exists energy.portfolios (
  portfolio_id uuid primary key default gen_random_uuid(),
  portfolio_code text not null unique check (portfolio_code ~ '^[A-Z0-9_-]{3,96}$'),
  portfolio_name text not null check (length(btrim(portfolio_name)) > 0),
  portfolio_type text not null check (portfolio_type in ('PROJECT','ASSET','MIXED','MARKET','REGIONAL','STRATEGIC','OTHER')),
  owner_organization_oid text references public.setc_organizations(oid) on delete restrict,
  portfolio_state text not null default 'DRAFT' check (portfolio_state in ('DRAFT','ACTIVE_REFERENCE','IN_REVIEW','SUSPENDED','ARCHIVED')),
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table energy.portfolios is 'Analytical portfolio registry for SourceEnergy.us. Portfolio membership does not convey ownership, control, investment authority, trading authority, or consolidated accounting treatment.';

create table if not exists energy.portfolio_members (
  portfolio_member_id uuid primary key default gen_random_uuid(),
  portfolio_id uuid not null references energy.portfolios(portfolio_id) on delete cascade,
  project_id uuid references energy.projects(project_id) on delete restrict,
  asset_id uuid references energy.assets(asset_id) on delete restrict,
  market_id uuid references energy.markets(market_id) on delete restrict,
  member_role text not null check (member_role in ('PRIMARY','EXPOSURE','BENCHMARK','WATCHLIST','REFERENCE_ONLY','OTHER')),
  allocation_weight_pct numeric check (allocation_weight_pct is null or (allocation_weight_pct between 0 and 100)),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED','ACTIVE','SUSPENDED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  check ((project_id is not null)::int + (asset_id is not null)::int + (market_id is not null)::int = 1)
);

create table if not exists energy.risk_register (
  risk_id uuid primary key default gen_random_uuid(),
  portfolio_id uuid references energy.portfolios(portfolio_id) on delete cascade,
  project_id uuid references energy.projects(project_id) on delete cascade,
  asset_id uuid references energy.assets(asset_id) on delete cascade,
  risk_category text not null check (risk_category in ('MARKET','PRICE','VOLUME','COUNTERPARTY','CREDIT_REFERENCE','REGULATORY','PERMITTING','INTERCONNECTION','CONSTRUCTION','TECHNOLOGY','OPERATIONS','FUEL','TRANSMISSION','LIQUIDITY_REFERENCE','FINANCING_REFERENCE','ENVIRONMENTAL','CYBER_REFERENCE','SUPPLY_CHAIN','GEOPOLITICAL_REFERENCE','OTHER')),
  risk_title text not null check (length(btrim(risk_title)) > 0),
  likelihood_score numeric check (likelihood_score is null or (likelihood_score between 0 and 100)),
  impact_score numeric check (impact_score is null or (impact_score between 0 and 100)),
  inherent_risk_score numeric check (inherent_risk_score is null or (inherent_risk_score between 0 and 100)),
  residual_risk_score numeric check (residual_risk_score is null or (residual_risk_score between 0 and 100)),
  risk_state text not null default 'IDENTIFIED' check (risk_state in ('IDENTIFIED','ASSESSING','MITIGATING','MONITORING','ACCEPTED_REFERENCE','TRANSFERRED_REFERENCE','CLOSED','DISPUTED','ARCHIVED')),
  mitigation_summary text,
  evidence_reference text,
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (portfolio_id is not null or project_id is not null or asset_id is not null)
);
comment on table energy.risk_register is 'Analytical risk register. Risk scores are decision-support outputs and do not constitute credit ratings, regulatory determinations, insurance coverage, or investment recommendations.';

create table if not exists energy.scenarios (
  scenario_id uuid primary key default gen_random_uuid(),
  scenario_code text not null unique check (scenario_code ~ '^[A-Z0-9_-]{3,96}$'),
  scenario_name text not null check (length(btrim(scenario_name)) > 0),
  scenario_type text not null check (scenario_type in ('BASE','UPSIDE','DOWNSIDE','STRESS','MARKET_PRICE','LOAD','FUEL','CURTAILMENT','INTERCONNECTION_DELAY','CAPEX_OVERRUN','RATE','POLICY','WEATHER_REFERENCE','COMBINED','OTHER')),
  scenario_state text not null default 'DRAFT' check (scenario_state in ('DRAFT','ACTIVE_REFERENCE','IN_REVIEW','APPROVED_REFERENCE','SUPERSEDED','ARCHIVED')),
  horizon_start date,
  horizon_end date,
  probability_pct numeric check (probability_pct is null or (probability_pct between 0 and 100)),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (horizon_end is null or horizon_start is null or horizon_end >= horizon_start)
);
comment on table energy.scenarios is 'Analytical scenarios are assumptions for decision support and are not forecasts, guarantees, market guidance, regulatory findings, or commitments.';

create table if not exists energy.scenario_assumptions (
  scenario_assumption_id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references energy.scenarios(scenario_id) on delete cascade,
  assumption_type text not null check (assumption_type in ('ENERGY_PRICE','CAPACITY_PRICE','REC_PRICE','FUEL_PRICE','LOAD','CAPEX','OPEX','COD_DELAY_MONTHS','CURTAILMENT_PCT','AVAILABILITY_PCT','INTEREST_RATE_REFERENCE','DISCOUNT_RATE','EMISSIONS_PRICE_REFERENCE','OTHER')),
  value_numeric numeric,
  value_text text,
  unit text,
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  check (value_numeric is not null or value_text is not null)
);

create table if not exists energy.scenario_results (
  scenario_result_id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references energy.scenarios(scenario_id) on delete cascade,
  portfolio_id uuid references energy.portfolios(portfolio_id) on delete cascade,
  project_id uuid references energy.projects(project_id) on delete cascade,
  asset_id uuid references energy.assets(asset_id) on delete cascade,
  metric_type text not null check (metric_type in ('NPV','IRR_PCT','ENTERPRISE_VALUE','EQUITY_VALUE','DSCR_REFERENCE','REVENUE','EBITDA_REFERENCE','GENERATION_MWH','CURTAILMENT_MWH','CAPACITY_FACTOR_PCT','CARBON_INTENSITY_REFERENCE','RISK_SCORE','OTHER')),
  metric_value numeric not null,
  unit text,
  result_state text not null default 'MODEL_OUTPUT' check (result_state in ('MODEL_OUTPUT','IN_REVIEW','REFERENCE_VERIFIED','APPROVED_REFERENCE','SUPERSEDED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  check (portfolio_id is not null or project_id is not null or asset_id is not null)
);
comment on table energy.scenario_results is 'Scenario output only. Results do not constitute audited results, actual financial performance, guaranteed returns, or authority to transact.';

create table if not exists energy.exposure_snapshots (
  exposure_snapshot_id uuid primary key default gen_random_uuid(),
  portfolio_id uuid not null references energy.portfolios(portfolio_id) on delete cascade,
  snapshot_date date not null,
  exposure_dimension text not null check (exposure_dimension in ('MARKET','REGION','TECHNOLOGY','COUNTERPARTY','PROJECT_STAGE','ASSET_CLASS','FUEL','REVENUE_CONTRACT','REGULATORY','OTHER')),
  exposure_key text not null,
  exposure_value numeric not null,
  unit text not null,
  concentration_pct numeric check (concentration_pct is null or (concentration_pct between 0 and 100)),
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  created_at timestamptz not null default now(),
  unique(portfolio_id, snapshot_date, exposure_dimension, exposure_key)
);

create table if not exists energy.portfolio_performance_snapshots (
  performance_snapshot_id uuid primary key default gen_random_uuid(),
  portfolio_id uuid not null references energy.portfolios(portfolio_id) on delete cascade,
  period_start date not null,
  period_end date not null,
  snapshot_kind text not null check (snapshot_kind in ('OBSERVED_REFERENCE','ESTIMATED','MODELED','FORECAST','CORRECTED_REFERENCE')),
  gross_generation_mwh numeric check (gross_generation_mwh is null or gross_generation_mwh >= 0),
  net_generation_mwh numeric check (net_generation_mwh is null or net_generation_mwh >= 0),
  revenue_amount numeric,
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  weighted_capacity_factor_pct numeric check (weighted_capacity_factor_pct is null or (weighted_capacity_factor_pct between 0 and 100)),
  weighted_availability_pct numeric check (weighted_availability_pct is null or (weighted_availability_pct between 0 and 100)),
  portfolio_risk_score numeric check (portfolio_risk_score is null or (portfolio_risk_score between 0 and 100)),
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (period_end >= period_start),
  check (snapshot_kind not in ('OBSERVED_REFERENCE','CORRECTED_REFERENCE') or evidence_reference is not null)
);

create table if not exists energy.executive_decision_cases (
  decision_case_id uuid primary key default gen_random_uuid(),
  decision_code text not null unique check (decision_code ~ '^[A-Z0-9_-]{3,96}$'),
  portfolio_id uuid references energy.portfolios(portfolio_id) on delete restrict,
  project_id uuid references energy.projects(project_id) on delete restrict,
  decision_type text not null check (decision_type in ('ADVANCE_DILIGENCE','HOLD','REMEDIATE','PRIORITIZE','DEPRIORITIZE','REFER_TO_HEI','REFER_TO_RW','REFER_TO_IOTF','REFER_TO_WIM','REVIEW_RISK','OTHER')),
  recommendation_state text not null default 'DRAFT' check (recommendation_state in ('DRAFT','ANALYTICAL_RECOMMENDATION','IN_REVIEW','ENDORSED_REFERENCE','REJECTED','SUPERSEDED','ARCHIVED')),
  recommendation_summary text not null check (length(btrim(recommendation_summary)) > 0),
  rationale_summary text,
  evidence_reference text,
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PENDING_VERIFICATION','REFERENCE_VERIFIED','VERIFIED','DISPUTED','ARCHIVED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (portfolio_id is not null or project_id is not null)
);
comment on table energy.executive_decision_cases is 'Executive analytical recommendation registry only. No record here approves an investment, funding, trade, settlement, regulatory action, procurement award, or binding commitment.';

create table if not exists energy.decision_external_references (
  decision_reference_id uuid primary key default gen_random_uuid(),
  decision_case_id uuid not null references energy.executive_decision_cases(decision_case_id) on delete cascade,
  system_name text not null check (system_name in ('HEI','RW','IOTF','WIM','SETC','OTHER')),
  external_entity_type text not null check (external_entity_type in ('INVESTMENT_DECISION','GATE_DECISION','GATEWAY_DECISION','GOVERNANCE_DECISION','TRANSACTION_REQUEST','OTHER')),
  external_reference text not null,
  relationship_type text not null default 'REFERENCE_ONLY' check (relationship_type in ('REFERENCE_ONLY','REFERRED_TO','SUPERSEDES_REFERENCE','SUPPORTS','OTHER')),
  state text not null default 'REFERENCE' check (state in ('REFERENCE','PENDING_VERIFICATION','VERIFIED_REFERENCE','RECONCILED','DISPUTED','ARCHIVED')),
  evidence_reference text,
  observed_at timestamptz not null default now(),
  unique(system_name, external_entity_type, external_reference)
);

alter table energy.portfolios enable row level security;
alter table energy.portfolio_members enable row level security;
alter table energy.risk_register enable row level security;
alter table energy.scenarios enable row level security;
alter table energy.scenario_assumptions enable row level security;
alter table energy.scenario_results enable row level security;
alter table energy.exposure_snapshots enable row level security;
alter table energy.portfolio_performance_snapshots enable row level security;
alter table energy.executive_decision_cases enable row level security;
alter table energy.decision_external_references enable row level security;

revoke all on energy.portfolios, energy.portfolio_members, energy.risk_register, energy.scenarios, energy.scenario_assumptions, energy.scenario_results, energy.exposure_snapshots, energy.portfolio_performance_snapshots, energy.executive_decision_cases, energy.decision_external_references from anon, authenticated;
grant all on energy.portfolios, energy.portfolio_members, energy.risk_register, energy.scenarios, energy.scenario_assumptions, energy.scenario_results, energy.exposure_snapshots, energy.portfolio_performance_snapshots, energy.executive_decision_cases, energy.decision_external_references to service_role;

create index if not exists idx_energy_portfolios_owner on energy.portfolios(owner_organization_oid) where owner_organization_oid is not null;
create index if not exists idx_energy_portfolio_members_portfolio on energy.portfolio_members(portfolio_id);
create index if not exists idx_energy_portfolio_members_project on energy.portfolio_members(project_id) where project_id is not null;
create index if not exists idx_energy_portfolio_members_asset on energy.portfolio_members(asset_id) where asset_id is not null;
create index if not exists idx_energy_portfolio_members_market on energy.portfolio_members(market_id) where market_id is not null;
create index if not exists idx_energy_risk_portfolio on energy.risk_register(portfolio_id) where portfolio_id is not null;
create index if not exists idx_energy_risk_project on energy.risk_register(project_id) where project_id is not null;
create index if not exists idx_energy_risk_asset on energy.risk_register(asset_id) where asset_id is not null;
create index if not exists idx_energy_scenario_assumptions_scenario on energy.scenario_assumptions(scenario_id);
create index if not exists idx_energy_scenario_results_scenario on energy.scenario_results(scenario_id);
create index if not exists idx_energy_scenario_results_portfolio on energy.scenario_results(portfolio_id) where portfolio_id is not null;
create index if not exists idx_energy_scenario_results_project on energy.scenario_results(project_id) where project_id is not null;
create index if not exists idx_energy_scenario_results_asset on energy.scenario_results(asset_id) where asset_id is not null;
create index if not exists idx_energy_exposure_portfolio_date on energy.exposure_snapshots(portfolio_id, snapshot_date desc);
create index if not exists idx_energy_portfolio_perf_portfolio_period on energy.portfolio_performance_snapshots(portfolio_id, period_start desc);
create index if not exists idx_energy_exec_decision_portfolio on energy.executive_decision_cases(portfolio_id) where portfolio_id is not null;
create index if not exists idx_energy_exec_decision_project on energy.executive_decision_cases(project_id) where project_id is not null;
create index if not exists idx_energy_decision_ext_case on energy.decision_external_references(decision_case_id);
