-- SourceEnergy Insurance — INS-E08 accounting, capital, reserves and solvency
-- Administrative/accounting/analytical evidence only; no row independently constitutes an audit,
-- actuarial opinion, regulatory capital determination, solvency certification or regulator acceptance.

create table if not exists public.setc_insurance_accounting_frameworks (
  accounting_framework_id uuid primary key default gen_random_uuid(),
  framework_code text not null unique,
  framework_name text not null,
  framework_type text not null check (framework_type in ('statutory','gaap','ifrs','management','regulatory','other')),
  jurisdiction_code text,
  authoritative_reference text,
  evidence_ref text,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_accounting_periods (
  accounting_period_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  accounting_framework_id uuid references public.setc_insurance_accounting_frameworks(accounting_framework_id),
  period_start date not null,
  period_end date not null,
  period_status text not null default 'open' check (period_status in ('open','review','closed_reference','restated_reference','void')),
  close_evidence_ref text,
  created_at timestamptz not null default now(),
  check (period_end >= period_start),
  check (period_status not in ('closed_reference','restated_reference') or close_evidence_ref is not null)
);

create table if not exists public.setc_insurance_ledger_mappings (
  insurance_ledger_mapping_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  accounting_framework_id uuid references public.setc_insurance_accounting_frameworks(accounting_framework_id),
  insurance_domain text not null check (insurance_domain in ('premium','claim','reserve','reinsurance','commission','expense','asset','liability','capital','other')),
  source_reference text not null,
  ledger_account_reference text not null,
  mapping_status text not null default 'draft' check (mapping_status in ('draft','reviewed','approved_reference','superseded','void')),
  approval_evidence_ref text,
  created_at timestamptz not null default now(),
  check (mapping_status <> 'approved_reference' or approval_evidence_ref is not null)
);

create table if not exists public.setc_insurance_technical_reserves (
  technical_reserve_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  accounting_period_id uuid not null references public.setc_insurance_accounting_periods(accounting_period_id),
  reserve_type text not null check (reserve_type in ('case','ibnr','unearned_premium','premium_deficiency','loss_adjustment_expense','reinsurance','other')),
  gross_amount numeric(24,6) not null check (gross_amount >= 0),
  ceded_amount numeric(24,6) not null default 0 check (ceded_amount >= 0),
  net_amount numeric(24,6) not null check (net_amount >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  valuation_status text not null default 'draft' check (valuation_status in ('draft','actuarial_reference','approved_reference','superseded','void')),
  valuation_evidence_ref text,
  created_at timestamptz not null default now(),
  check (ceded_amount <= gross_amount),
  check (abs(net_amount - (gross_amount - ceded_amount)) < 0.000001),
  check (valuation_status not in ('actuarial_reference','approved_reference') or valuation_evidence_ref is not null)
);

create table if not exists public.setc_insurance_actuarial_valuations (
  actuarial_valuation_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  accounting_period_id uuid not null references public.setc_insurance_accounting_periods(accounting_period_id),
  valuation_type text not null check (valuation_type in ('reserve','capital','pricing','experience','stress','other')),
  actuary_reference text,
  valuation_status text not null default 'draft' check (valuation_status in ('draft','reviewed','opinion_reference','superseded','withdrawn','void')),
  document_ref text,
  authority_evidence_ref text,
  content_sha256 text check (content_sha256 is null or content_sha256 ~ '^[0-9A-Fa-f]{64}$'),
  valuation_at timestamptz,
  created_at timestamptz not null default now(),
  check (valuation_status <> 'opinion_reference' or (document_ref is not null and authority_evidence_ref is not null))
);

create table if not exists public.setc_insurance_capital_requirements (
  capital_requirement_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  accounting_period_id uuid references public.setc_insurance_accounting_periods(accounting_period_id),
  requirement_type text not null check (requirement_type in ('minimum_capital','risk_based_capital','solvency_capital','minimum_solvency','internal_target','other')),
  required_amount numeric(24,6) not null check (required_amount >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  requirement_status text not null default 'unverified' check (requirement_status in ('unverified','calculated','evidence_verified','regulatory_reference','superseded','void')),
  methodology_reference text,
  external_evidence_ref text,
  created_at timestamptz not null default now(),
  check (requirement_status not in ('evidence_verified','regulatory_reference') or external_evidence_ref is not null)
);

create table if not exists public.setc_insurance_available_capital (
  available_capital_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  accounting_period_id uuid references public.setc_insurance_accounting_periods(accounting_period_id),
  capital_tier text not null check (capital_tier in ('core','tier_1','tier_2','tier_3','adjustment','other')),
  amount numeric(24,6) not null,
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  valuation_status text not null default 'unverified' check (valuation_status in ('unverified','calculated','evidence_verified','audited_reference','superseded','void')),
  valuation_evidence_ref text,
  created_at timestamptz not null default now(),
  check (valuation_status not in ('evidence_verified','audited_reference') or valuation_evidence_ref is not null)
);

create table if not exists public.setc_insurance_solvency_snapshots (
  solvency_snapshot_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  accounting_period_id uuid references public.setc_insurance_accounting_periods(accounting_period_id),
  capital_requirement_id uuid references public.setc_insurance_capital_requirements(capital_requirement_id),
  available_capital_amount numeric(24,6) not null check (available_capital_amount >= 0),
  required_capital_amount numeric(24,6) not null check (required_capital_amount >= 0),
  solvency_ratio numeric(18,8),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  snapshot_status text not null default 'draft' check (snapshot_status in ('draft','calculated','evidence_supported','regulatory_reference','superseded','void')),
  external_evidence_ref text,
  snapshot_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (solvency_ratio is null or solvency_ratio >= 0),
  check (required_capital_amount <> 0 or solvency_ratio is null),
  check (snapshot_status not in ('evidence_supported','regulatory_reference') or external_evidence_ref is not null)
);

create table if not exists public.setc_insurance_accounting_reconciliations (
  accounting_reconciliation_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  accounting_period_id uuid references public.setc_insurance_accounting_periods(accounting_period_id),
  reconciliation_type text not null check (reconciliation_type in ('ledger','reserve','premium','claim','reinsurance','capital','regulatory_filing','other')),
  internal_amount numeric(24,6),
  external_amount numeric(24,6),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  reconciliation_status text not null default 'unreconciled' check (reconciliation_status in ('unreconciled','matched','variance','investigating','resolved','void')),
  external_system text,
  external_reference text,
  external_evidence_ref text,
  reconciled_at timestamptz,
  created_at timestamptz not null default now(),
  check (reconciliation_status <> 'matched' or external_evidence_ref is not null)
);

create table if not exists public.setc_insurance_capital_filing_references (
  capital_filing_reference_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  accounting_period_id uuid references public.setc_insurance_accounting_periods(accounting_period_id),
  regulatory_authority_id uuid references public.setc_insurance_regulatory_authorities(regulatory_authority_id),
  filing_type text not null,
  filing_status text not null default 'draft' check (filing_status in ('draft','submitted_reference','accepted_reference','rejected_reference','amended_reference','void')),
  external_reference text,
  external_evidence_ref text,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  check (filing_status not in ('submitted_reference','accepted_reference','rejected_reference','amended_reference') or external_evidence_ref is not null)
);

create index if not exists idx_ins_acct_period_org on public.setc_insurance_accounting_periods(organization_oid);
create index if not exists idx_ins_acct_period_framework on public.setc_insurance_accounting_periods(accounting_framework_id);
create index if not exists idx_ins_ledger_org on public.setc_insurance_ledger_mappings(organization_oid);
create index if not exists idx_ins_ledger_framework on public.setc_insurance_ledger_mappings(accounting_framework_id);
create index if not exists idx_ins_reserve_org on public.setc_insurance_technical_reserves(organization_oid);
create index if not exists idx_ins_reserve_period on public.setc_insurance_technical_reserves(accounting_period_id);
create index if not exists idx_ins_actuarial_org on public.setc_insurance_actuarial_valuations(organization_oid);
create index if not exists idx_ins_actuarial_period on public.setc_insurance_actuarial_valuations(accounting_period_id);
create index if not exists idx_ins_capreq_org on public.setc_insurance_capital_requirements(organization_oid);
create index if not exists idx_ins_capreq_period on public.setc_insurance_capital_requirements(accounting_period_id);
create index if not exists idx_ins_availcap_org on public.setc_insurance_available_capital(organization_oid);
create index if not exists idx_ins_availcap_period on public.setc_insurance_available_capital(accounting_period_id);
create index if not exists idx_ins_solvency_org on public.setc_insurance_solvency_snapshots(organization_oid);
create index if not exists idx_ins_solvency_period on public.setc_insurance_solvency_snapshots(accounting_period_id);
create index if not exists idx_ins_solvency_capreq on public.setc_insurance_solvency_snapshots(capital_requirement_id);
create index if not exists idx_ins_acct_recon_org on public.setc_insurance_accounting_reconciliations(organization_oid);
create index if not exists idx_ins_acct_recon_period on public.setc_insurance_accounting_reconciliations(accounting_period_id);
create index if not exists idx_ins_capfiling_org on public.setc_insurance_capital_filing_references(organization_oid);
create index if not exists idx_ins_capfiling_period on public.setc_insurance_capital_filing_references(accounting_period_id);
create index if not exists idx_ins_capfiling_authority on public.setc_insurance_capital_filing_references(regulatory_authority_id);

alter table public.setc_insurance_accounting_frameworks enable row level security;
alter table public.setc_insurance_accounting_periods enable row level security;
alter table public.setc_insurance_ledger_mappings enable row level security;
alter table public.setc_insurance_technical_reserves enable row level security;
alter table public.setc_insurance_actuarial_valuations enable row level security;
alter table public.setc_insurance_capital_requirements enable row level security;
alter table public.setc_insurance_available_capital enable row level security;
alter table public.setc_insurance_solvency_snapshots enable row level security;
alter table public.setc_insurance_accounting_reconciliations enable row level security;
alter table public.setc_insurance_capital_filing_references enable row level security;

revoke all privileges on public.setc_insurance_accounting_frameworks,public.setc_insurance_accounting_periods,public.setc_insurance_ledger_mappings,public.setc_insurance_technical_reserves,public.setc_insurance_actuarial_valuations,public.setc_insurance_capital_requirements,public.setc_insurance_available_capital,public.setc_insurance_solvency_snapshots,public.setc_insurance_accounting_reconciliations,public.setc_insurance_capital_filing_references from anon,authenticated;
grant all privileges on public.setc_insurance_accounting_frameworks,public.setc_insurance_accounting_periods,public.setc_insurance_ledger_mappings,public.setc_insurance_technical_reserves,public.setc_insurance_actuarial_valuations,public.setc_insurance_capital_requirements,public.setc_insurance_available_capital,public.setc_insurance_solvency_snapshots,public.setc_insurance_accounting_reconciliations,public.setc_insurance_capital_filing_references to service_role;

comment on table public.setc_insurance_technical_reserves is 'Analytical reserve records only; do not independently constitute an actuarial opinion or legal reserve adequacy determination.';
comment on table public.setc_insurance_solvency_snapshots is 'Analytical solvency snapshot only; does not independently constitute regulatory solvency certification.';