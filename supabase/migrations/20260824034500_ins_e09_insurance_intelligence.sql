-- SourceEnergy Insurance — INS-E09 insurance intelligence and portfolio analytics
-- Decision-support records only. Analytics do not independently bind coverage, establish reserves,
-- prove triggers/losses, determine liability, or constitute actuarial/regulatory determinations.

create table if not exists public.setc_insurance_analytics_models (
  insurance_analytics_model_id uuid primary key default gen_random_uuid(),
  organization_oid text references public.setc_organizations(oid),
  model_code text not null,
  model_name text not null,
  model_type text not null check (model_type in ('exposure','pricing','claims','reserve','catastrophe','parametric','reinsurance','capital','solvency','stress','other')),
  model_version text not null,
  methodology_reference text,
  model_status text not null default 'draft' check (model_status in ('draft','reviewed','evidence_supported','approved_reference','superseded','retired','void')),
  validation_evidence_ref text,
  created_at timestamptz not null default now(),
  unique(model_code,model_version),
  check (model_status not in ('evidence_supported','approved_reference') or validation_evidence_ref is not null)
);

create table if not exists public.setc_insurance_portfolio_snapshots (
  portfolio_snapshot_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  snapshot_at timestamptz not null,
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  policy_count bigint not null default 0 check (policy_count >= 0),
  exposure_amount numeric(24,6) check (exposure_amount is null or exposure_amount >= 0),
  written_premium_amount numeric(24,6) check (written_premium_amount is null or written_premium_amount >= 0),
  incurred_loss_amount numeric(24,6) check (incurred_loss_amount is null or incurred_loss_amount >= 0),
  reserve_amount numeric(24,6) check (reserve_amount is null or reserve_amount >= 0),
  source_evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_concentration_metrics (
  concentration_metric_id uuid primary key default gen_random_uuid(),
  portfolio_snapshot_id uuid not null references public.setc_insurance_portfolio_snapshots(portfolio_snapshot_id),
  dimension_type text not null check (dimension_type in ('geography','industry','product','peril','counterparty','asset_type','organization','other')),
  dimension_value text not null,
  exposure_amount numeric(24,6) not null check (exposure_amount >= 0),
  exposure_pct numeric(12,8) check (exposure_pct is null or (exposure_pct >= 0 and exposure_pct <= 100)),
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_performance_metrics (
  performance_metric_id uuid primary key default gen_random_uuid(),
  portfolio_snapshot_id uuid not null references public.setc_insurance_portfolio_snapshots(portfolio_snapshot_id),
  metric_code text not null,
  metric_value numeric(30,10) not null,
  metric_unit text not null,
  methodology_reference text,
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique(portfolio_snapshot_id,metric_code)
);

create table if not exists public.setc_insurance_risk_aggregations (
  risk_aggregation_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  portfolio_snapshot_id uuid references public.setc_insurance_portfolio_snapshots(portfolio_snapshot_id),
  aggregation_type text not null check (aggregation_type in ('peril','event','geography','counterparty','correlation','accumulation','other')),
  aggregation_key text not null,
  gross_exposure_amount numeric(24,6) check (gross_exposure_amount is null or gross_exposure_amount >= 0),
  net_exposure_amount numeric(24,6) check (net_exposure_amount is null or net_exposure_amount >= 0),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  check (gross_exposure_amount is null or net_exposure_amount is null or net_exposure_amount <= gross_exposure_amount)
);

create table if not exists public.setc_insurance_scenarios (
  insurance_scenario_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  insurance_analytics_model_id uuid references public.setc_insurance_analytics_models(insurance_analytics_model_id),
  scenario_code text not null,
  scenario_type text not null check (scenario_type in ('catastrophe','parametric','stress','sensitivity','reverse_stress','portfolio','capital','other')),
  scenario_status text not null default 'draft' check (scenario_status in ('draft','reviewed','evidence_supported','approved_reference','superseded','void')),
  assumptions jsonb not null default '{}'::jsonb,
  methodology_reference text,
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique(organization_oid,scenario_code),
  check (scenario_status not in ('evidence_supported','approved_reference') or jsonb_array_length(evidence_refs) > 0)
);

create table if not exists public.setc_insurance_scenario_results (
  insurance_scenario_result_id uuid primary key default gen_random_uuid(),
  insurance_scenario_id uuid not null references public.setc_insurance_scenarios(insurance_scenario_id),
  portfolio_snapshot_id uuid references public.setc_insurance_portfolio_snapshots(portfolio_snapshot_id),
  result_metric text not null,
  result_value numeric(30,10) not null,
  result_unit text not null,
  confidence_score numeric(9,8) check (confidence_score is null or (confidence_score >= 0 and confidence_score <= 1)),
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_intelligence_lineage (
  intelligence_lineage_id uuid primary key default gen_random_uuid(),
  organization_oid text references public.setc_organizations(oid),
  artifact_type text not null check (artifact_type in ('portfolio_snapshot','metric','aggregation','scenario','scenario_result','model_output','report','other')),
  artifact_reference text not null,
  source_system text,
  source_reference text,
  transformation_reference text,
  model_reference text,
  evidence_ref text,
  lineage_status text not null default 'unverified' check (lineage_status in ('unverified','partial','evidence_supported','verified_reference','superseded','void')),
  created_at timestamptz not null default now(),
  check (lineage_status in ('unverified','partial','superseded','void') or evidence_ref is not null)
);

create table if not exists public.setc_insurance_intelligence_explanations (
  intelligence_explanation_id uuid primary key default gen_random_uuid(),
  organization_oid text references public.setc_organizations(oid),
  artifact_type text not null,
  artifact_reference text not null,
  explanation_text text not null,
  confidence_score numeric(9,8) check (confidence_score is null or (confidence_score >= 0 and confidence_score <= 1)),
  limitations text,
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_ins_analytics_models_org on public.setc_insurance_analytics_models(organization_oid);
create index if not exists idx_ins_portfolio_org on public.setc_insurance_portfolio_snapshots(organization_oid);
create index if not exists idx_ins_concentration_snapshot on public.setc_insurance_concentration_metrics(portfolio_snapshot_id);
create index if not exists idx_ins_performance_snapshot on public.setc_insurance_performance_metrics(portfolio_snapshot_id);
create index if not exists idx_ins_riskagg_org on public.setc_insurance_risk_aggregations(organization_oid);
create index if not exists idx_ins_riskagg_snapshot on public.setc_insurance_risk_aggregations(portfolio_snapshot_id);
create index if not exists idx_ins_scenario_org on public.setc_insurance_scenarios(organization_oid);
create index if not exists idx_ins_scenario_model on public.setc_insurance_scenarios(insurance_analytics_model_id);
create index if not exists idx_ins_scenario_result_scenario on public.setc_insurance_scenario_results(insurance_scenario_id);
create index if not exists idx_ins_scenario_result_snapshot on public.setc_insurance_scenario_results(portfolio_snapshot_id);
create index if not exists idx_ins_lineage_org on public.setc_insurance_intelligence_lineage(organization_oid);
create index if not exists idx_ins_explanation_org on public.setc_insurance_intelligence_explanations(organization_oid);

alter table public.setc_insurance_analytics_models enable row level security;
alter table public.setc_insurance_portfolio_snapshots enable row level security;
alter table public.setc_insurance_concentration_metrics enable row level security;
alter table public.setc_insurance_performance_metrics enable row level security;
alter table public.setc_insurance_risk_aggregations enable row level security;
alter table public.setc_insurance_scenarios enable row level security;
alter table public.setc_insurance_scenario_results enable row level security;
alter table public.setc_insurance_intelligence_lineage enable row level security;
alter table public.setc_insurance_intelligence_explanations enable row level security;

revoke all privileges on public.setc_insurance_analytics_models,public.setc_insurance_portfolio_snapshots,public.setc_insurance_concentration_metrics,public.setc_insurance_performance_metrics,public.setc_insurance_risk_aggregations,public.setc_insurance_scenarios,public.setc_insurance_scenario_results,public.setc_insurance_intelligence_lineage,public.setc_insurance_intelligence_explanations from anon,authenticated;
grant all privileges on public.setc_insurance_analytics_models,public.setc_insurance_portfolio_snapshots,public.setc_insurance_concentration_metrics,public.setc_insurance_performance_metrics,public.setc_insurance_risk_aggregations,public.setc_insurance_scenarios,public.setc_insurance_scenario_results,public.setc_insurance_intelligence_lineage,public.setc_insurance_intelligence_explanations to service_role;

comment on table public.setc_insurance_scenario_results is 'Decision-support scenario outputs only; do not independently prove catastrophe occurrence, parametric trigger satisfaction, claims liability, reserve adequacy or regulatory capital.';