-- SourceEnergy Insurance — INS-E05 claims records and loss-event workflow
-- Administrative evidence only; no row independently establishes coverage, entitlement,
-- liability, regulated claims authority, payment authority, or settlement finality.

create table if not exists public.setc_insurance_loss_events (
  loss_event_id uuid primary key default gen_random_uuid(),
  policy_id uuid references public.setc_insurance_policies(policy_id),
  risk_object_id uuid references public.setc_insurance_risk_objects(risk_object_id),
  loss_type text not null,
  occurred_at timestamptz,
  reported_at timestamptz not null default now(),
  jurisdiction_code text,
  description text,
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_fnol_records (
  fnol_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.setc_insurance_claims(claim_id),
  loss_event_id uuid not null references public.setc_insurance_loss_events(loss_event_id),
  reporting_organization_oid text references public.setc_organizations(oid),
  intake_channel text,
  intake_reference text,
  received_at timestamptz not null default now(),
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique(claim_id, loss_event_id)
);

create table if not exists public.setc_insurance_claim_parties (
  claim_party_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.setc_insurance_claims(claim_id),
  organization_oid text not null references public.setc_organizations(oid),
  party_role text not null check (party_role in ('claimant','insured','carrier','administrator','adjuster_org','vendor','counsel','beneficiary','reinsurer','other')),
  evidence_ref text,
  created_at timestamptz not null default now(),
  unique(claim_id, organization_oid, party_role)
);

create table if not exists public.setc_insurance_claim_assignments (
  claim_assignment_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.setc_insurance_claims(claim_id),
  assigned_organization_oid text not null references public.setc_organizations(oid),
  assignment_role text not null,
  assignment_status text not null default 'pending' check (assignment_status in ('pending','active','suspended','completed','revoked')),
  authority_status text not null default 'unverified' check (authority_status in ('unverified','pending','verified','restricted','expired','revoked','not_applicable')),
  authority_evidence_ref text,
  assigned_at timestamptz,
  created_at timestamptz not null default now(),
  check (authority_status <> 'verified' or authority_evidence_ref is not null)
);

create table if not exists public.setc_insurance_claim_reserve_movements (
  claim_reserve_movement_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.setc_insurance_claims(claim_id),
  movement_type text not null check (movement_type in ('establish','increase','decrease','release','correction')),
  amount_delta numeric(24,6) not null,
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  resulting_reserve numeric(24,6) not null check (resulting_reserve >= 0),
  reason text,
  evidence_ref text,
  effective_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_claim_documents (
  claim_document_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.setc_insurance_claims(claim_id),
  document_type text not null,
  document_ref text not null,
  content_sha256 text check (content_sha256 is null or content_sha256 ~ '^[0-9A-Fa-f]{64}$'),
  authoritative boolean not null default false,
  authority_evidence_ref text,
  created_at timestamptz not null default now(),
  check (not authoritative or authority_evidence_ref is not null)
);

create table if not exists public.setc_insurance_coverage_reviews (
  coverage_review_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.setc_insurance_claims(claim_id),
  reviewing_organization_oid text references public.setc_organizations(oid),
  review_status text not null default 'draft' check (review_status in ('draft','in_review','completed','superseded','withdrawn')),
  review_outcome text check (review_outcome is null or review_outcome in ('potentially_covered','potentially_excluded','mixed','insufficient_information','no_conclusion')),
  rationale text,
  evidence_refs jsonb not null default '[]'::jsonb,
  authority_status text not null default 'unverified' check (authority_status in ('unverified','pending','verified','restricted','expired','revoked','not_applicable')),
  authority_evidence_ref text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (authority_status <> 'verified' or authority_evidence_ref is not null)
);

create table if not exists public.setc_insurance_claim_financial_references (
  claim_financial_reference_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.setc_insurance_claims(claim_id),
  reference_type text not null check (reference_type in ('payment','recovery','refund','salvage','subrogation','expense','other')),
  amount numeric(24,6) check (amount is null or amount >= 0),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  external_system text,
  external_reference text,
  external_evidence_ref text,
  external_status text not null default 'unverified' check (external_status in ('unverified','pending','externally_confirmed','failed','reversed','void')),
  created_at timestamptz not null default now(),
  check (external_status <> 'externally_confirmed' or external_evidence_ref is not null)
);

create table if not exists public.setc_insurance_claim_recoveries (
  claim_recovery_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.setc_insurance_claims(claim_id),
  recovery_type text not null check (recovery_type in ('subrogation','salvage','reinsurance','third_party','other')),
  counterparty_organization_oid text references public.setc_organizations(oid),
  recovery_status text not null default 'identified' check (recovery_status in ('identified','pursuing','agreed','received_reference','closed','abandoned','void')),
  expected_amount numeric(24,6) check (expected_amount is null or expected_amount >= 0),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_claim_lifecycle_events (
  claim_lifecycle_event_id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.setc_insurance_claims(claim_id),
  actor_organization_oid text references public.setc_organizations(oid),
  event_type text not null check (event_type in ('report','acknowledge','assign','investigate','reserve','review','refer','close','reopen','correct','other')),
  from_status text,
  to_status text,
  effective_at timestamptz not null default now(),
  evidence_refs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_ins_loss_policy on public.setc_insurance_loss_events(policy_id);
create index if not exists idx_ins_loss_risk on public.setc_insurance_loss_events(risk_object_id);
create index if not exists idx_ins_fnol_claim on public.setc_insurance_fnol_records(claim_id);
create index if not exists idx_ins_fnol_loss on public.setc_insurance_fnol_records(loss_event_id);
create index if not exists idx_ins_fnol_reporter on public.setc_insurance_fnol_records(reporting_organization_oid);
create index if not exists idx_ins_claim_party_claim on public.setc_insurance_claim_parties(claim_id);
create index if not exists idx_ins_claim_party_org on public.setc_insurance_claim_parties(organization_oid);
create index if not exists idx_ins_claim_assignment_claim on public.setc_insurance_claim_assignments(claim_id);
create index if not exists idx_ins_claim_assignment_org on public.setc_insurance_claim_assignments(assigned_organization_oid);
create index if not exists idx_ins_claim_reserve_claim on public.setc_insurance_claim_reserve_movements(claim_id);
create index if not exists idx_ins_claim_doc_claim on public.setc_insurance_claim_documents(claim_id);
create index if not exists idx_ins_coverage_review_claim on public.setc_insurance_coverage_reviews(claim_id);
create index if not exists idx_ins_coverage_review_org on public.setc_insurance_coverage_reviews(reviewing_organization_oid);
create index if not exists idx_ins_claim_finref_claim on public.setc_insurance_claim_financial_references(claim_id);
create index if not exists idx_ins_claim_recovery_claim on public.setc_insurance_claim_recoveries(claim_id);
create index if not exists idx_ins_claim_recovery_org on public.setc_insurance_claim_recoveries(counterparty_organization_oid);
create index if not exists idx_ins_claim_event_claim on public.setc_insurance_claim_lifecycle_events(claim_id);
create index if not exists idx_ins_claim_event_actor on public.setc_insurance_claim_lifecycle_events(actor_organization_oid);

alter table public.setc_insurance_loss_events enable row level security;
alter table public.setc_insurance_fnol_records enable row level security;
alter table public.setc_insurance_claim_parties enable row level security;
alter table public.setc_insurance_claim_assignments enable row level security;
alter table public.setc_insurance_claim_reserve_movements enable row level security;
alter table public.setc_insurance_claim_documents enable row level security;
alter table public.setc_insurance_coverage_reviews enable row level security;
alter table public.setc_insurance_claim_financial_references enable row level security;
alter table public.setc_insurance_claim_recoveries enable row level security;
alter table public.setc_insurance_claim_lifecycle_events enable row level security;

revoke all privileges on public.setc_insurance_loss_events,public.setc_insurance_fnol_records,public.setc_insurance_claim_parties,public.setc_insurance_claim_assignments,public.setc_insurance_claim_reserve_movements,public.setc_insurance_claim_documents,public.setc_insurance_coverage_reviews,public.setc_insurance_claim_financial_references,public.setc_insurance_claim_recoveries,public.setc_insurance_claim_lifecycle_events from anon,authenticated;
grant all privileges on public.setc_insurance_loss_events,public.setc_insurance_fnol_records,public.setc_insurance_claim_parties,public.setc_insurance_claim_assignments,public.setc_insurance_claim_reserve_movements,public.setc_insurance_claim_documents,public.setc_insurance_coverage_reviews,public.setc_insurance_claim_financial_references,public.setc_insurance_claim_recoveries,public.setc_insurance_claim_lifecycle_events to service_role;

comment on table public.setc_insurance_coverage_reviews is 'Administrative coverage-review evidence only; not an independent legal coverage determination.';
comment on table public.setc_insurance_claim_financial_references is 'Reference to claim-related financial evidence; does not independently authorize payment or prove settlement finality.';