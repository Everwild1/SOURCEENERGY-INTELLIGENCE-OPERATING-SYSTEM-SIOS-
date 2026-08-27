-- SourceEnergy Insurance — INS-E07 regulatory, licensing, compliance and reporting records
-- Administrative evidence/workflow only; does not independently grant authority, approval or compliance.

create table if not exists public.setc_insurance_regulatory_authorities (
  regulatory_authority_id uuid primary key default gen_random_uuid(),
  authority_code text not null unique,
  authority_name text not null,
  jurisdiction_code text not null,
  authority_type text not null check (authority_type in ('insurance_regulator','financial_regulator','corporate_registry','tax_authority','data_privacy','other')),
  authoritative_reference text,
  evidence_ref text,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_license_records (
  insurance_license_record_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  regulatory_authority_id uuid not null references public.setc_insurance_regulatory_authorities(regulatory_authority_id),
  license_type text not null,
  license_number text,
  jurisdiction_code text not null,
  license_status text not null default 'unverified' check (license_status in ('unverified','pending','evidence_verified','active_reference','restricted','suspended','expired','revoked','withdrawn','void')),
  effective_at timestamptz,
  expires_at timestamptz,
  scope_description text,
  authoritative_document_ref text,
  external_evidence_ref text,
  created_at timestamptz not null default now(),
  check (expires_at is null or effective_at is null or expires_at > effective_at),
  check (license_status not in ('evidence_verified','active_reference') or external_evidence_ref is not null),
  check (license_status <> 'active_reference' or authoritative_document_ref is not null)
);

create table if not exists public.setc_insurance_regulatory_obligations (
  regulatory_obligation_id uuid primary key default gen_random_uuid(),
  regulatory_authority_id uuid references public.setc_insurance_regulatory_authorities(regulatory_authority_id),
  organization_oid text references public.setc_organizations(oid),
  obligation_code text not null,
  obligation_type text not null check (obligation_type in ('filing','report','fee','capital','licensing','consumer_protection','data_privacy','recordkeeping','audit','other')),
  jurisdiction_code text not null,
  requirement_reference text,
  cadence text,
  effective_at timestamptz,
  expires_at timestamptz,
  evidence_ref text,
  created_at timestamptz not null default now(),
  check (expires_at is null or effective_at is null or expires_at > effective_at)
);

create table if not exists public.setc_insurance_regulatory_filings (
  regulatory_filing_id uuid primary key default gen_random_uuid(),
  regulatory_obligation_id uuid references public.setc_insurance_regulatory_obligations(regulatory_obligation_id),
  regulatory_authority_id uuid references public.setc_insurance_regulatory_authorities(regulatory_authority_id),
  organization_oid text not null references public.setc_organizations(oid),
  filing_type text not null,
  period_start date,
  period_end date,
  due_at timestamptz,
  filing_status text not null default 'draft' check (filing_status in ('draft','in_review','ready','submitted_reference','accepted_reference','rejected_reference','amended_reference','withdrawn','void')),
  external_reference text,
  external_evidence_ref text,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  check (period_end is null or period_start is null or period_end >= period_start),
  check (filing_status not in ('submitted_reference','accepted_reference','rejected_reference','amended_reference') or external_evidence_ref is not null)
);

create table if not exists public.setc_insurance_compliance_attestations (
  compliance_attestation_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  regulatory_obligation_id uuid references public.setc_insurance_regulatory_obligations(regulatory_obligation_id),
  attestation_type text not null,
  attestation_status text not null default 'draft' check (attestation_status in ('draft','pending_review','evidence_supported','superseded','withdrawn','void')),
  attested_by_reference text,
  evidence_refs jsonb not null default '[]'::jsonb,
  authority_evidence_ref text,
  attested_at timestamptz,
  created_at timestamptz not null default now(),
  check (attestation_status <> 'evidence_supported' or (authority_evidence_ref is not null and jsonb_array_length(evidence_refs) > 0))
);

create table if not exists public.setc_insurance_compliance_exceptions (
  compliance_exception_id uuid primary key default gen_random_uuid(),
  organization_oid text references public.setc_organizations(oid),
  regulatory_obligation_id uuid references public.setc_insurance_regulatory_obligations(regulatory_obligation_id),
  exception_type text not null,
  severity text not null default 'unrated' check (severity in ('unrated','low','medium','high','critical')),
  exception_status text not null default 'open' check (exception_status in ('open','investigating','remediation_planned','remediated_reference','accepted_reference','closed','void')),
  description text,
  remediation_plan text,
  disposition_reference text,
  disposition_evidence_ref text,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  check (closed_at is null or closed_at >= opened_at),
  check (exception_status not in ('remediated_reference','accepted_reference','closed') or disposition_evidence_ref is not null)
);

create table if not exists public.setc_insurance_regulatory_correspondence (
  regulatory_correspondence_id uuid primary key default gen_random_uuid(),
  regulatory_authority_id uuid references public.setc_insurance_regulatory_authorities(regulatory_authority_id),
  organization_oid text references public.setc_organizations(oid),
  correspondence_type text not null check (correspondence_type in ('inquiry','notice','request','response','examination','order_reference','guidance','other')),
  direction text not null check (direction in ('inbound','outbound','internal_reference')),
  external_reference text,
  document_ref text,
  content_sha256 text check (content_sha256 is null or content_sha256 ~ '^[0-9A-Fa-f]{64}$'),
  evidence_ref text,
  occurred_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.setc_insurance_compliance_audit_events (
  compliance_audit_event_id uuid primary key default gen_random_uuid(),
  organization_oid text references public.setc_organizations(oid),
  regulatory_obligation_id uuid references public.setc_insurance_regulatory_obligations(regulatory_obligation_id),
  event_type text not null check (event_type in ('review','test','evidence_capture','exception','remediation','filing','correspondence','status_change','other')),
  actor_reference text,
  event_at timestamptz not null default now(),
  evidence_refs jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_ins_license_org on public.setc_insurance_license_records(organization_oid);
create index if not exists idx_ins_license_authority on public.setc_insurance_license_records(regulatory_authority_id);
create index if not exists idx_ins_obligation_authority on public.setc_insurance_regulatory_obligations(regulatory_authority_id);
create index if not exists idx_ins_obligation_org on public.setc_insurance_regulatory_obligations(organization_oid);
create index if not exists idx_ins_filing_obligation on public.setc_insurance_regulatory_filings(regulatory_obligation_id);
create index if not exists idx_ins_filing_authority on public.setc_insurance_regulatory_filings(regulatory_authority_id);
create index if not exists idx_ins_filing_org on public.setc_insurance_regulatory_filings(organization_oid);
create index if not exists idx_ins_attestation_org on public.setc_insurance_compliance_attestations(organization_oid);
create index if not exists idx_ins_attestation_obligation on public.setc_insurance_compliance_attestations(regulatory_obligation_id);
create index if not exists idx_ins_exception_org on public.setc_insurance_compliance_exceptions(organization_oid);
create index if not exists idx_ins_exception_obligation on public.setc_insurance_compliance_exceptions(regulatory_obligation_id);
create index if not exists idx_ins_corr_authority on public.setc_insurance_regulatory_correspondence(regulatory_authority_id);
create index if not exists idx_ins_corr_org on public.setc_insurance_regulatory_correspondence(organization_oid);
create index if not exists idx_ins_audit_org on public.setc_insurance_compliance_audit_events(organization_oid);
create index if not exists idx_ins_audit_obligation on public.setc_insurance_compliance_audit_events(regulatory_obligation_id);

alter table public.setc_insurance_regulatory_authorities enable row level security;
alter table public.setc_insurance_license_records enable row level security;
alter table public.setc_insurance_regulatory_obligations enable row level security;
alter table public.setc_insurance_regulatory_filings enable row level security;
alter table public.setc_insurance_compliance_attestations enable row level security;
alter table public.setc_insurance_compliance_exceptions enable row level security;
alter table public.setc_insurance_regulatory_correspondence enable row level security;
alter table public.setc_insurance_compliance_audit_events enable row level security;

revoke all privileges on public.setc_insurance_regulatory_authorities,public.setc_insurance_license_records,public.setc_insurance_regulatory_obligations,public.setc_insurance_regulatory_filings,public.setc_insurance_compliance_attestations,public.setc_insurance_compliance_exceptions,public.setc_insurance_regulatory_correspondence,public.setc_insurance_compliance_audit_events from anon,authenticated;
grant all privileges on public.setc_insurance_regulatory_authorities,public.setc_insurance_license_records,public.setc_insurance_regulatory_obligations,public.setc_insurance_regulatory_filings,public.setc_insurance_compliance_attestations,public.setc_insurance_compliance_exceptions,public.setc_insurance_regulatory_correspondence,public.setc_insurance_compliance_audit_events to service_role;

comment on table public.setc_insurance_license_records is 'Administrative licensing evidence registry only; does not independently confer authority to transact insurance.';
comment on table public.setc_insurance_compliance_attestations is 'Internal compliance evidence artifact; does not independently prove legal or regulatory compliance.';