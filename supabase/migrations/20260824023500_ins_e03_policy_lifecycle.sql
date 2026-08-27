-- SourceEnergy Insurance — INS-E03 policy administration and lifecycle
-- Registry/workflow state does not independently create legally binding coverage or regulated authority.

create table if not exists public.setc_insurance_policy_parties (
  policy_party_id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.setc_insurance_policies(policy_id),
  organization_oid text not null references public.setc_organizations(oid),
  party_role text not null check (party_role in ('insured','additional_insured','carrier','broker','mga','administrator','loss_payee','lienholder','beneficiary','reinsurer','other')),
  authority_status text not null default 'unverified' check (authority_status in ('unverified','pending','verified','restricted','expired','revoked','not_applicable')),
  authority_evidence_ref text,
  effective_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique(policy_id, organization_oid, party_role),
  check (expires_at is null or effective_at is null or expires_at > effective_at),
  check (authority_status <> 'verified' or authority_evidence_ref is not null)
);

create table if not exists public.setc_insurance_policy_coverages (
  policy_coverage_id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.setc_insurance_policies(policy_id),
  coverage_code text not null,
  coverage_name text not null,
  coverage_status text not null default 'scheduled' check (coverage_status in ('scheduled','active','suspended','cancelled','expired','void')),
  limit_amount numeric(24,6) check (limit_amount is null or limit_amount >= 0),
  aggregate_limit_amount numeric(24,6) check (aggregate_limit_amount is null or aggregate_limit_amount >= 0),
  deductible_amount numeric(24,6) check (deductible_amount is null or deductible_amount >= 0),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  effective_at timestamptz,
  expires_at timestamptz,
  terms jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(policy_id, coverage_code),
  check (expires_at is null or effective_at is null or expires_at > effective_at)
);

create table if not exists public.setc_insurance_policy_terms (
  policy_term_id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.setc_insurance_policies(policy_id),
  term_type text not null check (term_type in ('condition','exclusion','warranty','endorsement_reference','notice','definition','other')),
  term_code text,
  title text not null,
  term_text text,
  document_ref text,
  effective_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at is null or effective_at is null or expires_at > effective_at)
);

create table if not exists public.setc_insurance_policy_documents (
  policy_document_id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.setc_insurance_policies(policy_id),
  document_type text not null check (document_type in ('binder','policy','declarations','schedule','endorsement','certificate','notice','cancellation','renewal','other')),
  document_ref text not null,
  content_sha256 text check (content_sha256 is null or content_sha256 ~ '^[0-9A-Fa-f]{64}$'),
  authoritative boolean not null default false,
  authority_evidence_ref text,
  issued_at timestamptz,
  created_at timestamptz not null default now(),
  check (not authoritative or authority_evidence_ref is not null)
);

create table if not exists public.setc_insurance_policy_lifecycle_events (
  policy_lifecycle_event_id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.setc_insurance_policies(policy_id),
  actor_organization_oid text references public.setc_organizations(oid),
  event_type text not null check (event_type in ('issue','activate','suspend','reinstate','cancel','nonrenew','expire','renew','void','correct','other')),
  from_status text,
  to_status text,
  effective_at timestamptz not null,
  reason text,
  authority_status text not null default 'unverified' check (authority_status in ('unverified','pending','verified','restricted','expired','revoked','not_applicable')),
  authority_evidence_ref text,
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  check (authority_status <> 'verified' or authority_evidence_ref is not null)
);

create table if not exists public.setc_insurance_policy_renewals (
  policy_renewal_id uuid primary key default gen_random_uuid(),
  predecessor_policy_id uuid not null references public.setc_insurance_policies(policy_id),
  successor_policy_id uuid references public.setc_insurance_policies(policy_id),
  renewal_status text not null default 'planned' check (renewal_status in ('planned','quoted','offered','accepted','declined','issued','lapsed','cancelled')),
  proposed_effective_at timestamptz,
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique(predecessor_policy_id, successor_policy_id),
  check (successor_policy_id is null or successor_policy_id <> predecessor_policy_id)
);

create index if not exists idx_ins_policy_parties_policy on public.setc_insurance_policy_parties(policy_id);
create index if not exists idx_ins_policy_parties_org on public.setc_insurance_policy_parties(organization_oid);
create index if not exists idx_ins_policy_coverages_policy on public.setc_insurance_policy_coverages(policy_id);
create index if not exists idx_ins_policy_terms_policy on public.setc_insurance_policy_terms(policy_id);
create index if not exists idx_ins_policy_documents_policy on public.setc_insurance_policy_documents(policy_id);
create index if not exists idx_ins_policy_events_policy on public.setc_insurance_policy_lifecycle_events(policy_id);
create index if not exists idx_ins_policy_events_actor on public.setc_insurance_policy_lifecycle_events(actor_organization_oid);
create index if not exists idx_ins_policy_renewals_predecessor on public.setc_insurance_policy_renewals(predecessor_policy_id);
create index if not exists idx_ins_policy_renewals_successor on public.setc_insurance_policy_renewals(successor_policy_id);

alter table public.setc_insurance_policy_parties enable row level security;
alter table public.setc_insurance_policy_coverages enable row level security;
alter table public.setc_insurance_policy_terms enable row level security;
alter table public.setc_insurance_policy_documents enable row level security;
alter table public.setc_insurance_policy_lifecycle_events enable row level security;
alter table public.setc_insurance_policy_renewals enable row level security;

revoke all privileges on public.setc_insurance_policy_parties, public.setc_insurance_policy_coverages,
 public.setc_insurance_policy_terms, public.setc_insurance_policy_documents,
 public.setc_insurance_policy_lifecycle_events, public.setc_insurance_policy_renewals from anon, authenticated;
grant all privileges on public.setc_insurance_policy_parties, public.setc_insurance_policy_coverages,
 public.setc_insurance_policy_terms, public.setc_insurance_policy_documents,
 public.setc_insurance_policy_lifecycle_events, public.setc_insurance_policy_renewals to service_role;

comment on table public.setc_insurance_policy_documents is 'Policy document registry with integrity metadata. Registration or authoritative=true does not independently create coverage or regulated authority.';
comment on table public.setc_insurance_policy_lifecycle_events is 'Policy lifecycle evidence log. Events do not independently bind, amend, renew, cancel, or otherwise alter legal coverage without valid external authority.';