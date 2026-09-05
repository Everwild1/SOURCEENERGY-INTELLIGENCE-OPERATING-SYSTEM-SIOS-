create schema if not exists segm;

create table segm.institution_profiles (
  id uuid primary key default gen_random_uuid(),
  setc_organization_oid text not null references public.setc_organizations(oid),
  wim_organization_id uuid references wim.organizations(id),
  institution_class text not null check (institution_class in ('CIVIL_GOVERNMENT','DEFENSE_MILITARY','DIPLOMATIC','MULTILATERAL','PUBLIC_AUTHORITY','EMERGENCY_MANAGEMENT','RESEARCH_INSTITUTION','GOVERNMENT_CONTRACTOR','OTHER')),
  country_code text,
  jurisdiction_code text,
  government_level text,
  agency_or_service text,
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','DECLARED_CAPABILITY','VERIFIED_RELATIONSHIP','VERIFIED_AUTHORITY','SUSPENDED','ARCHIVED')),
  data_classification text not null default 'INTERNAL' check (data_classification in ('PUBLIC','INTERNAL','CONTROLLED','CONTRACT_RESTRICTED','REGULATED','EXPORT_CONTROLLED','CLASSIFIED')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(setc_organization_oid),
  unique(wim_organization_id)
);

create table segm.evidence_items (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid references segm.institution_profiles(id) on delete cascade,
  iotf_organization_evidence_id uuid references iotf.organization_evidence(id),
  evidence_type text not null,
  source_system text not null,
  source_reference text not null,
  title text not null,
  evidence_state text not null default 'RECEIVED' check (evidence_state in ('RECEIVED','UNDER_REVIEW','VERIFIED','REJECTED','SUPERSEDED')),
  authority_scope text,
  effective_from timestamptz,
  effective_to timestamptz,
  verified_at timestamptz,
  verification_notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(source_system, source_reference)
);

create table segm.authorities (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references segm.institution_profiles(id) on delete cascade,
  evidence_id uuid references segm.evidence_items(id),
  authority_type text not null,
  authority_scope text not null,
  jurisdiction_code text,
  status text not null default 'PENDING' check (status in ('PENDING','VERIFIED','EXPIRED','REVOKED','REJECTED')),
  effective_from timestamptz,
  effective_to timestamptz,
  verified_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table segm.procurement_cases (
  id uuid primary key default gen_random_uuid(),
  case_code text not null unique,
  opportunity_id uuid references wim.opportunities(id),
  originating_institution_id uuid references segm.institution_profiles(id),
  operating_organization_oid text references public.setc_organizations(oid),
  procurement_stage text not null default 'DISCOVERY' check (procurement_stage in ('DISCOVERY','QUALIFICATION','BID_NO_BID','PROPOSAL','SUBMITTED','EVALUATION','AWARDED','MOBILIZATION','PERFORMANCE','CLOSEOUT','CLOSED')),
  bid_decision text check (bid_decision is null or bid_decision in ('PENDING','BID','NO_BID')),
  award_status text not null default 'NOT_AWARDED' check (award_status in ('NOT_AWARDED','PENDING','AWARDED','NOT_SELECTED','CANCELLED')),
  jurisdiction_code text,
  source_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table segm.authorization_decisions (
  id uuid primary key default gen_random_uuid(),
  procurement_case_id uuid not null references segm.procurement_cases(id) on delete cascade,
  decision_type text not null check (decision_type in ('AUTHORITY_TO_BID','AUTHORITY_TO_PERFORM','SUSPEND','REVOKE')),
  decision_status text not null default 'PENDING' check (decision_status in ('PENDING','APPROVED','DENIED','EXPIRED','REVOKED')),
  authority_id uuid references segm.authorities(id),
  evidence_id uuid references segm.evidence_items(id),
  decision_reference text,
  decided_by text,
  decided_at timestamptz,
  expires_at timestamptz,
  rationale text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table segm.compliance_requirements (
  id uuid primary key default gen_random_uuid(),
  requirement_code text not null unique,
  category text not null,
  title text not null,
  jurisdiction_code text,
  controlling_authority text,
  applicability_rule jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table segm.compliance_assessments (
  id uuid primary key default gen_random_uuid(),
  procurement_case_id uuid not null references segm.procurement_cases(id) on delete cascade,
  requirement_id uuid not null references segm.compliance_requirements(id),
  assessment_status text not null default 'NOT_ASSESSED' check (assessment_status in ('NOT_ASSESSED','IN_PROGRESS','COMPLIANT','NONCOMPLIANT','NOT_APPLICABLE','EXCEPTION_APPROVED')),
  evidence_id uuid references segm.evidence_items(id),
  assessed_by text,
  assessed_at timestamptz,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(procurement_case_id, requirement_id)
);

create table segm.audit_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  entity_type text not null,
  entity_id uuid,
  actor_reference text,
  event_data jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index segm_institution_profiles_class_idx on segm.institution_profiles(institution_class);
create index segm_institution_profiles_verification_idx on segm.institution_profiles(verification_state);
create index segm_evidence_items_institution_idx on segm.evidence_items(institution_id);
create index segm_authorities_institution_status_idx on segm.authorities(institution_id,status);
create index segm_procurement_cases_opportunity_idx on segm.procurement_cases(opportunity_id);
create index segm_procurement_cases_stage_idx on segm.procurement_cases(procurement_stage);
create index segm_authorization_decisions_case_type_idx on segm.authorization_decisions(procurement_case_id,decision_type);
create index segm_compliance_assessments_case_status_idx on segm.compliance_assessments(procurement_case_id,assessment_status);
create index segm_audit_events_entity_idx on segm.audit_events(entity_type,entity_id);

alter table segm.institution_profiles enable row level security;
alter table segm.evidence_items enable row level security;
alter table segm.authorities enable row level security;
alter table segm.procurement_cases enable row level security;
alter table segm.authorization_decisions enable row level security;
alter table segm.compliance_requirements enable row level security;
alter table segm.compliance_assessments enable row level security;
alter table segm.audit_events enable row level security;

revoke all on schema segm from anon, authenticated;
revoke all on all tables in schema segm from anon, authenticated;

