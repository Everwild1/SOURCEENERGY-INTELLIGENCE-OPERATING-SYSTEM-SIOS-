-- SourceEnergy Insurance — INS-E02 underwriting and risk engineering
-- A score, decision, recommendation, referral or model output does not itself bind coverage.

create table if not exists public.setc_insurance_risk_factors (
  risk_factor_id uuid primary key default gen_random_uuid(),
  factor_code text not null unique,
  factor_name text not null,
  factor_category text not null,
  description text,
  scoring_method text not null default 'manual',
  status text not null default 'active' check (status in ('draft','active','suspended','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_risk_factor_observations (
  risk_factor_observation_id uuid primary key default gen_random_uuid(),
  risk_assessment_id uuid not null references public.setc_insurance_risk_assessments(risk_assessment_id),
  risk_factor_id uuid not null references public.setc_insurance_risk_factors(risk_factor_id),
  observing_organization_oid text not null references public.setc_organizations(oid),
  raw_value jsonb not null default '{}'::jsonb,
  normalized_score numeric(18,8),
  confidence_score numeric(9,8) check (confidence_score is null or (confidence_score >= 0 and confidence_score <= 1)),
  evidence_refs jsonb not null default '[]'::jsonb,
  observed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(risk_assessment_id, risk_factor_id, observed_at)
);

create table if not exists public.setc_insurance_risk_controls (
  risk_control_id uuid primary key default gen_random_uuid(),
  risk_object_id uuid not null references public.setc_insurance_risk_objects(risk_object_id),
  organization_oid text not null references public.setc_organizations(oid),
  control_code text not null,
  control_name text not null,
  control_type text not null,
  implementation_status text not null default 'proposed' check (implementation_status in ('proposed','planned','implemented','verified','failed','retired')),
  effectiveness_score numeric(9,8) check (effectiveness_score is null or (effectiveness_score >= 0 and effectiveness_score <= 1)),
  evidence_refs jsonb not null default '[]'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(risk_object_id, control_code)
);

create table if not exists public.setc_insurance_underwriting_decisions (
  underwriting_decision_id uuid primary key default gen_random_uuid(),
  underwriting_submission_id uuid not null references public.setc_insurance_underwriting_submissions(underwriting_submission_id),
  deciding_organization_oid text not null references public.setc_organizations(oid),
  decision_type text not null check (decision_type in ('recommend_accept','recommend_decline','refer','request_information','conditional','no_decision')),
  decision_status text not null default 'draft' check (decision_status in ('draft','review','final','superseded','withdrawn')),
  model_name text,
  model_version text,
  decision_score numeric(18,8),
  rationale text,
  conditions jsonb not null default '[]'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  authority_status text not null default 'unverified' check (authority_status in ('unverified','pending','verified','restricted','expired','revoked')),
  authority_evidence_ref text,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  check (authority_status <> 'verified' or authority_evidence_ref is not null)
);

create table if not exists public.setc_insurance_underwriting_referrals (
  underwriting_referral_id uuid primary key default gen_random_uuid(),
  underwriting_submission_id uuid not null references public.setc_insurance_underwriting_submissions(underwriting_submission_id),
  underwriting_decision_id uuid references public.setc_insurance_underwriting_decisions(underwriting_decision_id),
  referring_organization_oid text not null references public.setc_organizations(oid),
  referral_reason text not null,
  referral_status text not null default 'open' check (referral_status in ('open','assigned','in_review','resolved','closed','withdrawn')),
  resolution text,
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists idx_ins_factor_obs_assessment on public.setc_insurance_risk_factor_observations(risk_assessment_id);
create index if not exists idx_ins_factor_obs_factor on public.setc_insurance_risk_factor_observations(risk_factor_id);
create index if not exists idx_ins_factor_obs_org on public.setc_insurance_risk_factor_observations(observing_organization_oid);
create index if not exists idx_ins_controls_risk on public.setc_insurance_risk_controls(risk_object_id);
create index if not exists idx_ins_controls_org on public.setc_insurance_risk_controls(organization_oid);
create index if not exists idx_ins_uw_decision_submission on public.setc_insurance_underwriting_decisions(underwriting_submission_id);
create index if not exists idx_ins_uw_decision_org on public.setc_insurance_underwriting_decisions(deciding_organization_oid);
create index if not exists idx_ins_uw_referral_submission on public.setc_insurance_underwriting_referrals(underwriting_submission_id);
create index if not exists idx_ins_uw_referral_decision on public.setc_insurance_underwriting_referrals(underwriting_decision_id);
create index if not exists idx_ins_uw_referral_org on public.setc_insurance_underwriting_referrals(referring_organization_oid);

alter table public.setc_insurance_risk_factors enable row level security;
alter table public.setc_insurance_risk_factor_observations enable row level security;
alter table public.setc_insurance_risk_controls enable row level security;
alter table public.setc_insurance_underwriting_decisions enable row level security;
alter table public.setc_insurance_underwriting_referrals enable row level security;

revoke all privileges on public.setc_insurance_risk_factors, public.setc_insurance_risk_factor_observations,
 public.setc_insurance_risk_controls, public.setc_insurance_underwriting_decisions,
 public.setc_insurance_underwriting_referrals from anon, authenticated;

grant all privileges on public.setc_insurance_risk_factors, public.setc_insurance_risk_factor_observations,
 public.setc_insurance_risk_controls, public.setc_insurance_underwriting_decisions,
 public.setc_insurance_underwriting_referrals to service_role;

comment on table public.setc_insurance_underwriting_decisions is 'Underwriting analysis and decision record. No row, score, recommendation, or final status independently creates coverage or bind authority.';
