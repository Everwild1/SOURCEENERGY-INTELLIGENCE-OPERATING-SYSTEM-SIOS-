create table cruds.opportunities (
  id uuid primary key default gen_random_uuid(),
  opportunity_type text not null check (opportunity_type in ('collaborate','commission','license','publish','fund','sponsor','develop','produce','distribute','commercialize')),
  title text not null check (length(trim(title)) > 0),
  description text,
  originating_creator_id uuid references cruds.creators(id),
  originating_identity_reference text,
  work_id uuid references cruds.works(id),
  status text not null default 'draft' check (status in ('draft','open','under_review','matched','closed','cancelled','restricted')),
  opens_at timestamptz,
  closes_at timestamptz,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table cruds.opportunity_responses (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references cruds.opportunities(id) on delete cascade,
  responding_creator_id uuid references cruds.creators(id),
  responding_identity_reference text,
  response_type text not null check (response_type in ('interest','proposal','offer','collaboration','information')),
  response_reference text not null unique,
  status text not null default 'submitted' check (status in ('submitted','under_review','accepted','rejected','withdrawn','expired','restricted')),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (responding_creator_id is not null or length(trim(coalesce(responding_identity_reference,''))) > 0)
);

create table cruds.commercialization_projects (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  lead_creator_id uuid references cruds.creators(id),
  work_id uuid references cruds.works(id),
  opportunity_id uuid references cruds.opportunities(id),
  stage text not null default 'discovery' check (stage in ('discovery','validation','readiness','market_access','active','scale','closed')),
  wim_market_access_request_id uuid references cruds.market_access_requests(id),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table cruds.market_access_requests
  add column commercialization_project_id uuid references cruds.commercialization_projects(id),
  add column request_type text not null default 'commercialization' check (request_type in ('commercialization','listing','procurement','partnership','distribution','licensing')),
  add column wim_opportunity_reference text,
  add column authority_boundary text not null default 'WIM Exchange authoritative for market workflow';

create table cruds.settlement_requests (
  id uuid primary key default gen_random_uuid(),
  commercialization_project_id uuid references cruds.commercialization_projects(id),
  market_access_request_id uuid references cruds.market_access_requests(id),
  settlement_rail text not null check (settlement_rail in ('fiat_external','source_coin')),
  request_reference text not null unique,
  idempotency_key text not null unique,
  requested_amount numeric,
  currency_code text,
  status text not null default 'requested' check (status in ('requested','pending','confirmed','failed','cancelled','restricted')),
  authoritative_confirmation_reference text,
  source_coin_request_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table cruds.settlement_references
  add column settlement_request_id uuid references cruds.settlement_requests(id),
  add column authority_boundary text not null default 'reference_only_no_settlement_finality';

create table cruds.research_assets (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) > 0),
  source_url text,
  source_block_reference text,
  publication_date date,
  creator_id uuid references cruds.creators(id),
  work_id uuid references cruds.works(id),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table cruds.impact_metric_registry (
  metric_code text primary key,
  metric_name text not null,
  metric_family text not null check (metric_family in ('creative_income','work_creation','collaboration','commercialization','market_access','knowledge_transfer','audience_reach','local_supplier_participation','community_wealth','cultural_value')),
  default_unit text,
  methodology_version text not null,
  description text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table cruds.impact_metrics (
  id uuid primary key default gen_random_uuid(),
  metric_code text not null references cruds.impact_metric_registry(metric_code),
  creator_id uuid references cruds.creators(id),
  work_id uuid references cruds.works(id),
  commercialization_project_id uuid references cruds.commercialization_projects(id),
  metric_value numeric,
  metric_unit text,
  measurement_kind text not null default 'estimate' check (measurement_kind in ('estimate','observed','verified')),
  measurement_period_start date,
  measurement_period_end date,
  methodology_version text not null,
  evidence_reference text,
  source_event_reference text,
  deduplication_key text,
  confidence_score numeric check (confidence_score is null or (confidence_score >= 0 and confidence_score <= 1)),
  corrected_from_impact_metric_id uuid references cruds.impact_metrics(id),
  status text not null default 'active' check (status in ('active','superseded','withdrawn')),
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index cruds_active_impact_deduplication_key
  on cruds.impact_metrics (deduplication_key)
  where deduplication_key is not null and status = 'active';

create table cruds.impact_metric_corrections (
  id uuid primary key default gen_random_uuid(),
  impact_metric_id uuid not null references cruds.impact_metrics(id),
  prior_state jsonb not null,
  corrected_state jsonb not null,
  reason text not null,
  evidence_reference text,
  created_at timestamptz not null default now()
);

create table cruds.intelligence_projections (
  id uuid primary key default gen_random_uuid(),
  projection_type text not null check (projection_type in ('creator','work','opportunity','commercialization','market_access','impact','research')),
  subject_reference text not null,
  projection_version text not null,
  payload jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table cruds.opportunities enable row level security;
alter table cruds.opportunity_responses enable row level security;
alter table cruds.commercialization_projects enable row level security;
alter table cruds.settlement_requests enable row level security;
alter table cruds.research_assets enable row level security;
alter table cruds.impact_metric_registry enable row level security;
alter table cruds.impact_metrics enable row level security;
alter table cruds.impact_metric_corrections enable row level security;
alter table cruds.intelligence_projections enable row level security;

revoke all on cruds.opportunities from anon, authenticated;
revoke all on cruds.opportunity_responses from anon, authenticated;
revoke all on cruds.commercialization_projects from anon, authenticated;
revoke all on cruds.settlement_requests from anon, authenticated;
revoke all on cruds.research_assets from anon, authenticated;
revoke all on cruds.impact_metric_registry from anon, authenticated;
revoke all on cruds.impact_metrics from anon, authenticated;
revoke all on cruds.impact_metric_corrections from anon, authenticated;
revoke all on cruds.intelligence_projections from anon, authenticated;

comment on table cruds.opportunity_responses is 'Non-binding collaboration/commercial responses; acceptance alone creates no contract, award, transaction, settlement, or legal obligation.';
comment on table cruds.market_access_requests is 'Outbound projection/request into WIM Exchange; CRUDS does not own WIM opportunity, transaction, trade, or settlement workflow.';
comment on table cruds.settlement_requests is 'Settlement orchestration request only. Finality belongs to the approved external fiat rail or Source Coin domain confirmation.';
comment on table cruds.impact_metrics is 'Methodology-versioned creative-economy measurements; estimates, observations and verified measurements are explicitly distinguished and active measurements are anti-double-counted.';
comment on table cruds.intelligence_projections is 'Derived intelligence projections only; projections do not create legal, financial, authorship, market, or settlement authority.';
