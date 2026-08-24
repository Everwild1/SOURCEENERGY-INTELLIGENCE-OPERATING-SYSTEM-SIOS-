-- SourceEnergy Insurance — INS-E06 reinsurance and risk-transfer records
-- Administrative/analytical evidence only; no row independently creates a contract,
-- transfers legal risk, perfects collateral, authorizes funds movement, or proves settlement.

create table if not exists public.setc_insurance_reinsurance_arrangements (
  reinsurance_arrangement_id uuid primary key default gen_random_uuid(),
  arrangement_type text not null check (arrangement_type in ('treaty','facultative')),
  arrangement_code text not null unique,
  arrangement_status text not null default 'draft' check (arrangement_status in ('draft','proposed','documented','active_reference','expired','terminated','void')),
  effective_at timestamptz,
  expires_at timestamptz,
  governing_law text,
  authoritative_document_ref text,
  authority_evidence_ref text,
  created_at timestamptz not null default now(),
  check (expires_at is null or effective_at is null or expires_at > effective_at),
  check (arrangement_status <> 'active_reference' or (authoritative_document_ref is not null and authority_evidence_ref is not null))
);

create table if not exists public.setc_insurance_reinsurance_parties (
  reinsurance_party_id uuid primary key default gen_random_uuid(),
  reinsurance_arrangement_id uuid not null references public.setc_insurance_reinsurance_arrangements(reinsurance_arrangement_id),
  organization_oid text not null references public.setc_organizations(oid),
  party_role text not null check (party_role in ('cedent','reinsurer','broker','administrator','collateral_provider','trustee','other')),
  participation_pct numeric(9,6) check (participation_pct is null or (participation_pct >= 0 and participation_pct <= 100)),
  authority_status text not null default 'unverified' check (authority_status in ('unverified','pending','verified','restricted','expired','revoked','not_applicable')),
  authority_evidence_ref text,
  created_at timestamptz not null default now(),
  unique(reinsurance_arrangement_id,organization_oid,party_role),
  check (authority_status <> 'verified' or authority_evidence_ref is not null)
);

create table if not exists public.setc_insurance_reinsurance_layers (
  reinsurance_layer_id uuid primary key default gen_random_uuid(),
  reinsurance_arrangement_id uuid not null references public.setc_insurance_reinsurance_arrangements(reinsurance_arrangement_id),
  layer_number integer not null check (layer_number > 0),
  attachment_amount numeric(24,6) not null default 0 check (attachment_amount >= 0),
  limit_amount numeric(24,6) not null check (limit_amount > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  participation_pct numeric(9,6) not null default 100 check (participation_pct > 0 and participation_pct <= 100),
  created_at timestamptz not null default now(),
  unique(reinsurance_arrangement_id,layer_number)
);

create table if not exists public.setc_insurance_ceded_risk_allocations (
  ceded_risk_allocation_id uuid primary key default gen_random_uuid(),
  reinsurance_arrangement_id uuid not null references public.setc_insurance_reinsurance_arrangements(reinsurance_arrangement_id),
  reinsurance_layer_id uuid references public.setc_insurance_reinsurance_layers(reinsurance_layer_id),
  policy_id uuid references public.setc_insurance_policies(policy_id),
  risk_object_id uuid references public.setc_insurance_risk_objects(risk_object_id),
  ceded_pct numeric(9,6) not null check (ceded_pct > 0 and ceded_pct <= 100),
  ceded_limit_amount numeric(24,6) check (ceded_limit_amount is null or ceded_limit_amount >= 0),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  check (policy_id is not null or risk_object_id is not null)
);

create table if not exists public.setc_insurance_reinsurance_financial_references (
  reinsurance_financial_reference_id uuid primary key default gen_random_uuid(),
  reinsurance_arrangement_id uuid not null references public.setc_insurance_reinsurance_arrangements(reinsurance_arrangement_id),
  reference_type text not null check (reference_type in ('ceded_premium','recoverable','commission','claim_recovery','refund','adjustment','other')),
  amount numeric(24,6) not null check (amount >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  external_status text not null default 'unverified' check (external_status in ('unverified','pending','externally_confirmed','disputed','reversed','void')),
  external_system text,
  external_reference text,
  external_evidence_ref text,
  created_at timestamptz not null default now(),
  check (external_status <> 'externally_confirmed' or external_evidence_ref is not null)
);

create table if not exists public.setc_insurance_reinsurance_documents (
  reinsurance_document_id uuid primary key default gen_random_uuid(),
  reinsurance_arrangement_id uuid not null references public.setc_insurance_reinsurance_arrangements(reinsurance_arrangement_id),
  document_type text not null check (document_type in ('slip','treaty','facultative_certificate','bordereau','statement','endorsement','collateral_document','notice','other')),
  document_ref text not null,
  content_sha256 text check (content_sha256 is null or content_sha256 ~ '^[0-9A-Fa-f]{64}$'),
  authoritative boolean not null default false,
  authority_evidence_ref text,
  created_at timestamptz not null default now(),
  check (not authoritative or authority_evidence_ref is not null)
);

create table if not exists public.setc_insurance_reinsurance_collateral_references (
  collateral_reference_id uuid primary key default gen_random_uuid(),
  reinsurance_arrangement_id uuid not null references public.setc_insurance_reinsurance_arrangements(reinsurance_arrangement_id),
  provider_organization_oid text references public.setc_organizations(oid),
  collateral_type text not null check (collateral_type in ('trust','letter_of_credit','funds_withheld','security_agreement','other')),
  stated_amount numeric(24,6) check (stated_amount is null or stated_amount >= 0),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  status text not null default 'unverified' check (status in ('unverified','pending','evidence_verified','expired','released','disputed','void')),
  external_reference text,
  external_evidence_ref text,
  created_at timestamptz not null default now(),
  check (status <> 'evidence_verified' or external_evidence_ref is not null)
);

create table if not exists public.setc_insurance_reinsurance_reconciliations (
  reinsurance_reconciliation_id uuid primary key default gen_random_uuid(),
  reinsurance_arrangement_id uuid not null references public.setc_insurance_reinsurance_arrangements(reinsurance_arrangement_id),
  reconciliation_type text not null check (reconciliation_type in ('premium','recoverable','bordereau','collateral','settlement','other')),
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

create index if not exists idx_ins_re_parties_arrangement on public.setc_insurance_reinsurance_parties(reinsurance_arrangement_id);
create index if not exists idx_ins_re_parties_org on public.setc_insurance_reinsurance_parties(organization_oid);
create index if not exists idx_ins_re_layers_arrangement on public.setc_insurance_reinsurance_layers(reinsurance_arrangement_id);
create index if not exists idx_ins_ceded_arrangement on public.setc_insurance_ceded_risk_allocations(reinsurance_arrangement_id);
create index if not exists idx_ins_ceded_layer on public.setc_insurance_ceded_risk_allocations(reinsurance_layer_id);
create index if not exists idx_ins_ceded_policy on public.setc_insurance_ceded_risk_allocations(policy_id);
create index if not exists idx_ins_ceded_risk on public.setc_insurance_ceded_risk_allocations(risk_object_id);
create index if not exists idx_ins_re_fin_arrangement on public.setc_insurance_reinsurance_financial_references(reinsurance_arrangement_id);
create index if not exists idx_ins_re_docs_arrangement on public.setc_insurance_reinsurance_documents(reinsurance_arrangement_id);
create index if not exists idx_ins_re_collateral_arrangement on public.setc_insurance_reinsurance_collateral_references(reinsurance_arrangement_id);
create index if not exists idx_ins_re_collateral_provider on public.setc_insurance_reinsurance_collateral_references(provider_organization_oid);
create index if not exists idx_ins_re_recon_arrangement on public.setc_insurance_reinsurance_reconciliations(reinsurance_arrangement_id);

alter table public.setc_insurance_reinsurance_arrangements enable row level security;
alter table public.setc_insurance_reinsurance_parties enable row level security;
alter table public.setc_insurance_reinsurance_layers enable row level security;
alter table public.setc_insurance_ceded_risk_allocations enable row level security;
alter table public.setc_insurance_reinsurance_financial_references enable row level security;
alter table public.setc_insurance_reinsurance_documents enable row level security;
alter table public.setc_insurance_reinsurance_collateral_references enable row level security;
alter table public.setc_insurance_reinsurance_reconciliations enable row level security;

revoke all privileges on public.setc_insurance_reinsurance_arrangements,public.setc_insurance_reinsurance_parties,public.setc_insurance_reinsurance_layers,public.setc_insurance_ceded_risk_allocations,public.setc_insurance_reinsurance_financial_references,public.setc_insurance_reinsurance_documents,public.setc_insurance_reinsurance_collateral_references,public.setc_insurance_reinsurance_reconciliations from anon,authenticated;
grant all privileges on public.setc_insurance_reinsurance_arrangements,public.setc_insurance_reinsurance_parties,public.setc_insurance_reinsurance_layers,public.setc_insurance_ceded_risk_allocations,public.setc_insurance_reinsurance_financial_references,public.setc_insurance_reinsurance_documents,public.setc_insurance_reinsurance_collateral_references,public.setc_insurance_reinsurance_reconciliations to service_role;

comment on table public.setc_insurance_reinsurance_arrangements is 'Administrative reinsurance registry; does not independently create or evidence legal risk transfer without authoritative external documentation.';
comment on table public.setc_insurance_reinsurance_collateral_references is 'Collateral evidence reference only; does not independently perfect, value, or establish enforceability of security.';