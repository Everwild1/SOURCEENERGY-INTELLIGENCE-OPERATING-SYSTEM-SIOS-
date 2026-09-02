create type rw.capital_readiness_status as enum ('not_assessed','developing','conditionally_ready','ready','restricted');
create type rw.capital_request_status as enum ('draft','submitted','under_review','qualified','referred','declined','withdrawn','closed');
create type rw.opportunity_match_status as enum ('candidate','screening','qualified','submitted','accepted','rejected','withdrawn','expired');
create type rw.commercialization_status as enum ('discovery','validation','readiness','market_entry','active','scale','closed','restricted');

create table rw.capital_readiness_profiles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  assessment_id uuid references rw.assessments(id),
  status rw.capital_readiness_status not null default 'not_assessed',
  capital_need_amount numeric check (capital_need_amount is null or capital_need_amount >= 0),
  currency_code text,
  capital_purpose text,
  preferred_capital_types text[] not null default '{}',
  financial_statements_status text not null default 'not_reviewed' check (financial_statements_status in ('not_reviewed','incomplete','management_prepared','reviewed','audited','not_applicable')),
  governance_docs_status text not null default 'not_reviewed' check (governance_docs_status in ('not_reviewed','incomplete','complete','verified','not_applicable')),
  use_of_funds_status text not null default 'not_reviewed' check (use_of_funds_status in ('not_reviewed','incomplete','complete','verified')),
  repayment_or_return_model_status text not null default 'not_reviewed' check (repayment_or_return_model_status in ('not_reviewed','incomplete','complete','verified','not_applicable')),
  evidence_ids uuid[] not null default '{}',
  methodology_version text not null default 'RW-CAPITAL-0.1',
  assessed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.capital_requests (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  organization_id uuid not null references rw.organizations(id),
  readiness_profile_id uuid references rw.capital_readiness_profiles(id),
  request_type text not null check (request_type in ('working_capital','equipment','project_finance','trade_finance','growth_equity','debt','grant','guarantee','other')),
  requested_amount numeric check (requested_amount is null or requested_amount >= 0),
  currency_code text,
  purpose text,
  status rw.capital_request_status not null default 'draft',
  evidence_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  closed_at timestamptz
);

create table rw.capital_referrals (
  id uuid primary key default gen_random_uuid(),
  capital_request_id uuid not null references rw.capital_requests(id),
  organization_id uuid not null references rw.organizations(id),
  destination_domain text not null check (destination_domain in ('sourceenergy_capital','sourceenergy_wealth_advisors','scrollbank_covenant_trust','iotf','external_financial_institution','grant_program','other')),
  destination_reference text,
  referral_status text not null default 'pending' check (referral_status in ('pending','accepted','declined','completed','restricted')),
  authority_boundary text not null default 'referral_only_no_commitment_or_funding_authority',
  evidence_ids uuid[] not null default '{}',
  referred_at timestamptz not null default now(),
  completed_at timestamptz
);

create table rw.procurement_readiness_profiles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  profile_status text not null default 'developing' check (profile_status in ('developing','conditionally_ready','ready','restricted')),
  registration_status text not null default 'not_reviewed',
  certifications_status text not null default 'not_reviewed',
  insurance_status text not null default 'not_reviewed',
  past_performance_status text not null default 'not_reviewed',
  pricing_status text not null default 'not_reviewed',
  fulfillment_status text not null default 'not_reviewed',
  evidence_ids uuid[] not null default '{}',
  methodology_version text not null default 'RW-PROCURE-0.1',
  assessed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table rw.opportunity_matches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  wim_opportunity_id uuid not null references wim.opportunities(id),
  match_status rw.opportunity_match_status not null default 'candidate',
  fit_score numeric check (fit_score is null or (fit_score >= 0 and fit_score <= 100)),
  readiness_profile_id uuid references rw.procurement_readiness_profiles(id),
  rationale text,
  evidence_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, wim_opportunity_id)
);

create table rw.commercialization_cases (
  id uuid primary key default gen_random_uuid(),
  registry_code text not null unique,
  organization_id uuid not null references rw.organizations(id),
  product_service_id uuid references rw.products_services(id),
  opportunity_match_id uuid references rw.opportunity_matches(id),
  wim_commercialization_project_id uuid references wim.commercialization_projects(id),
  status rw.commercialization_status not null default 'discovery',
  market_entry_plan text,
  pricing_model text,
  delivery_model text,
  risk_notes text,
  evidence_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz
);

create table rw.commercialization_events (
  id bigint generated always as identity primary key,
  commercialization_case_id uuid not null references rw.commercialization_cases(id),
  event_type text not null,
  event_payload jsonb not null default '{}'::jsonb,
  external_reference text,
  occurred_at timestamptz not null default now()
);

create table rw.gateway_decisions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references rw.organizations(id),
  gateway_type text not null check (gateway_type in ('capital','procurement','opportunity','commercialization')),
  subject_reference text not null,
  decision text not null check (decision in ('approved','conditionally_approved','rejected','deferred','restricted')),
  conditions text,
  rationale text,
  evidence_ids uuid[] not null default '{}',
  decided_by uuid references auth.users(id),
  decided_at timestamptz not null default now()
);

comment on table rw.capital_readiness_profiles is 'Enterprise preparation record only; readiness is not an offer, commitment, underwriting decision, security, deposit, or proof of funds.';
comment on table rw.capital_referrals is 'Referral boundary to governed capital providers or external institutions; no referral creates financing authority or settlement finality.';
comment on table rw.opportunity_matches is 'RW suitability match to an authoritative WIM opportunity; a match is non-binding and does not create an award, contract, transaction, or settlement.';
comment on table rw.commercialization_cases is 'RW commercialization workflow; WIM remains authoritative for marketplace projects and transactions.';

create index rw_capital_readiness_org_idx on rw.capital_readiness_profiles(organization_id);
create index rw_capital_readiness_assessment_idx on rw.capital_readiness_profiles(assessment_id);
create index rw_capital_requests_org_idx on rw.capital_requests(organization_id);
create index rw_capital_requests_profile_idx on rw.capital_requests(readiness_profile_id);
create index rw_capital_requests_status_idx on rw.capital_requests(status);
create index rw_capital_referrals_request_idx on rw.capital_referrals(capital_request_id);
create index rw_capital_referrals_org_idx on rw.capital_referrals(organization_id);
create index rw_procurement_readiness_org_idx on rw.procurement_readiness_profiles(organization_id);
create index rw_opportunity_matches_org_idx on rw.opportunity_matches(organization_id);
create index rw_opportunity_matches_wim_idx on rw.opportunity_matches(wim_opportunity_id);
create index rw_opportunity_matches_readiness_idx on rw.opportunity_matches(readiness_profile_id);
create index rw_commercialization_org_idx on rw.commercialization_cases(organization_id);
create index rw_commercialization_product_idx on rw.commercialization_cases(product_service_id);
create index rw_commercialization_match_idx on rw.commercialization_cases(opportunity_match_id);
create index rw_commercialization_wim_project_idx on rw.commercialization_cases(wim_commercialization_project_id);
create index rw_commercialization_events_case_idx on rw.commercialization_events(commercialization_case_id);
create index rw_gateway_decisions_org_idx on rw.gateway_decisions(organization_id);
create index rw_gateway_decisions_decided_by_idx on rw.gateway_decisions(decided_by);

alter table rw.capital_readiness_profiles enable row level security;
alter table rw.capital_requests enable row level security;
alter table rw.capital_referrals enable row level security;
alter table rw.procurement_readiness_profiles enable row level security;
alter table rw.opportunity_matches enable row level security;
alter table rw.commercialization_cases enable row level security;
alter table rw.commercialization_events enable row level security;
alter table rw.gateway_decisions enable row level security;

revoke all on rw.capital_readiness_profiles, rw.capital_requests, rw.capital_referrals, rw.procurement_readiness_profiles, rw.opportunity_matches, rw.commercialization_cases, rw.commercialization_events, rw.gateway_decisions from anon, authenticated;
grant all on rw.capital_readiness_profiles, rw.capital_requests, rw.capital_referrals, rw.procurement_readiness_profiles, rw.opportunity_matches, rw.commercialization_cases, rw.commercialization_events, rw.gateway_decisions to service_role;
grant usage, select on sequence rw.commercialization_events_id_seq to service_role;
