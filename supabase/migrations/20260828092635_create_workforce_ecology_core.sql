create extension if not exists pgcrypto;

create schema if not exists workforce_ecology;
revoke all on schema workforce_ecology from public, anon, authenticated;
grant usage on schema workforce_ecology to service_role;

create table workforce_ecology.metric_registry (
  metric_id uuid primary key default gen_random_uuid(),
  dimension_code text not null check (dimension_code in ('productive_performance','human_connection','social_capital','development','belonging','sustainable_capacity','community_contribution')),
  metric_name text not null,
  description text,
  evidence_class text not null,
  aggregation_method text not null,
  normalization_method text not null,
  weight_within_dimension numeric(6,5) not null check (weight_within_dimension >= 0 and weight_within_dimension <= 1),
  minimum_cohort_size integer not null default 5 check (minimum_cohort_size >= 1),
  active_from date not null default current_date,
  active_to date,
  calculation_version text not null,
  governance_status text not null default 'draft' check (governance_status in ('draft','approved','retired')),
  created_at timestamptz not null default now(),
  unique (dimension_code, metric_name, calculation_version),
  check (active_to is null or active_to >= active_from)
);

create table workforce_ecology.measurement_observations (
  observation_id uuid primary key default gen_random_uuid(),
  organization_id text not null,
  operating_unit_id text,
  team_id text,
  metric_id uuid not null references workforce_ecology.metric_registry(metric_id),
  period_start date not null,
  period_end date not null,
  numerator numeric,
  denominator numeric,
  raw_value numeric not null,
  normalized_value numeric(6,3) check (normalized_value between 0 and 100),
  evidence_reference text,
  source_system text not null,
  captured_at timestamptz not null default now(),
  quality_status text not null default 'pending' check (quality_status in ('pending','validated','rejected')),
  check (period_end >= period_start),
  check (denominator is null or denominator >= 0)
);

create table workforce_ecology.dimension_scores (
  score_id uuid primary key default gen_random_uuid(),
  organization_id text not null,
  operating_unit_id text,
  team_id text,
  period_start date not null,
  period_end date not null,
  dimension_code text not null check (dimension_code in ('productive_performance','human_connection','social_capital','development','belonging','sustainable_capacity','community_contribution')),
  score_0_100 numeric(6,3) not null check (score_0_100 between 0 and 100),
  evidence_completeness numeric(6,3) not null default 0 check (evidence_completeness between 0 and 100),
  trend_delta numeric(7,3),
  calculation_version text not null,
  calculated_at timestamptz not null default now(),
  review_status text not null default 'pending' check (review_status in ('pending','reviewed','approved','rejected')),
  check (period_end >= period_start)
);

create table workforce_ecology.index_scores (
  index_score_id uuid primary key default gen_random_uuid(),
  organization_id text not null,
  operating_unit_id text,
  team_id text,
  period_start date not null,
  period_end date not null,
  wei_score numeric(6,3) not null check (wei_score between 0 and 100),
  band text not null check (band in ('flourishing','resilient','watch','intervention','critical')),
  lowest_dimension text,
  intervention_flag boolean not null default false,
  calculation_version text not null,
  calculated_at timestamptz not null default now(),
  approved_at timestamptz,
  approval_reference text,
  check (period_end >= period_start)
);

create table workforce_ecology.interventions (
  intervention_id uuid primary key default gen_random_uuid(),
  organization_id text not null,
  operating_unit_id text,
  team_id text,
  trigger_dimension text not null,
  trigger_score numeric(6,3) not null check (trigger_score between 0 and 100),
  intervention_type text not null,
  action_owner text not null,
  opened_at timestamptz not null default now(),
  target_review_at timestamptz not null,
  status text not null default 'open' check (status in ('open','in_review','closed','cancelled')),
  outcome_summary text,
  closed_at timestamptz,
  check (closed_at is null or closed_at >= opened_at)
);

create table workforce_ecology.policy_versions (
  policy_version_id uuid primary key default gen_random_uuid(),
  version_name text not null unique,
  effective_from date not null,
  effective_to date,
  weight_configuration jsonb not null,
  band_configuration jsonb not null,
  privacy_rules jsonb not null,
  minimum_evidence_rules jsonb not null,
  approved_by_reference text,
  approval_date date,
  status text not null default 'draft' check (status in ('draft','approved','retired')),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create table workforce_ecology.audit_events (
  event_id uuid primary key default gen_random_uuid(),
  event_type text not null check (event_type in ('WEI_SCORE_CALCULATED','WEI_DIMENSION_THRESHOLD_BREACHED','WEI_INTERVENTION_OPENED','WEI_INTERVENTION_REVIEWED','WEI_POLICY_VERSION_ACTIVATED')),
  organization_id text not null,
  operating_unit_id text,
  team_id text,
  period_start date,
  period_end date,
  calculation_version text,
  evidence_lineage_reference text,
  human_approval_state text,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index measurement_observations_scope_period_idx on workforce_ecology.measurement_observations (organization_id, operating_unit_id, team_id, period_end desc);
create index measurement_observations_metric_idx on workforce_ecology.measurement_observations (metric_id, period_end desc);
create index dimension_scores_scope_period_idx on workforce_ecology.dimension_scores (organization_id, operating_unit_id, team_id, period_end desc);
create index index_scores_scope_period_idx on workforce_ecology.index_scores (organization_id, operating_unit_id, team_id, period_end desc);
create index interventions_open_idx on workforce_ecology.interventions (organization_id, status, target_review_at);
create index audit_events_scope_time_idx on workforce_ecology.audit_events (organization_id, occurred_at desc);

alter table workforce_ecology.metric_registry enable row level security;
alter table workforce_ecology.measurement_observations enable row level security;
alter table workforce_ecology.dimension_scores enable row level security;
alter table workforce_ecology.index_scores enable row level security;
alter table workforce_ecology.interventions enable row level security;
alter table workforce_ecology.policy_versions enable row level security;
alter table workforce_ecology.audit_events enable row level security;

revoke all on all tables in schema workforce_ecology from public, anon, authenticated;
grant select, insert, update, delete on all tables in schema workforce_ecology to service_role;
alter default privileges for role postgres in schema workforce_ecology revoke all on tables from public, anon, authenticated;
alter default privileges for role postgres in schema workforce_ecology grant select, insert, update, delete on tables to service_role;

insert into workforce_ecology.policy_versions (
  version_name, effective_from, weight_configuration, band_configuration, privacy_rules, minimum_evidence_rules, status
) values (
  'WEI-1.0', current_date,
  '{"productive_performance":0.20,"human_connection":0.15,"social_capital":0.15,"development":0.15,"belonging":0.10,"sustainable_capacity":0.15,"community_contribution":0.10}'::jsonb,
  '{"flourishing":{"min":85,"max":100},"resilient":{"min":70,"max":84.999},"watch":{"min":55,"max":69.999},"intervention":{"min":40,"max":54.999},"critical":{"min":0,"max":39.999},"dimension_override_below":40}'::jsonb,
  '{"exclude_clinical_data":true,"exclude_individual_psychological_risk_scores":true,"executive_views_aggregated":true,"human_review_required_for_material_actions":true}'::jsonb,
  '{"minimum_evidence_classes_per_dimension":2,"default_minimum_cohort_size":5,"score_requires_lineage":true}'::jsonb,
  'draft'
) on conflict (version_name) do nothing;
