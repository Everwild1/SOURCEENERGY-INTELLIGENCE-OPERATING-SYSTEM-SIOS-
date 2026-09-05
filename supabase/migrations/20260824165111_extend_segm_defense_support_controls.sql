create table segm.capability_registry (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid references segm.institution_profiles(id) on delete cascade,
  operating_organization_oid text not null references public.setc_organizations(oid),
  capability_code text not null,
  capability_class text not null check (capability_class in ('LOGISTICS','HEALTH','ENERGY','CRITICAL_INFRASTRUCTURE','EMERGENCY_MANAGEMENT','TRAINING','RESEARCH','CYBERSECURITY','COMMUNICATIONS','SUPPLY_CHAIN','ENGINEERING','OTHER')),
  capability_title text not null,
  claim_state text not null default 'DECLARED' check (claim_state in ('DECLARED','EVIDENCE_RECEIVED','VERIFIED','SUSPENDED','REJECTED','ARCHIVED')),
  government_use_allowed boolean not null default false,
  defense_use_allowed boolean not null default false,
  evidence_id uuid references segm.evidence_items(id),
  restrictions jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(operating_organization_oid, capability_code)
);

create table segm.contract_vehicle_references (
  id uuid primary key default gen_random_uuid(),
  operating_organization_oid text not null references public.setc_organizations(oid),
  institution_id uuid references segm.institution_profiles(id),
  vehicle_type text not null,
  vehicle_reference text not null,
  rgl_contract_id uuid references rgl.contracts(id),
  energy_agreement_id uuid references energy.commercial_agreements(agreement_id),
  evidence_id uuid references segm.evidence_items(id),
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','EVIDENCE_RECEIVED','VERIFIED','EXPIRED','SUSPENDED','REJECTED')),
  effective_from date,
  effective_to date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(operating_organization_oid, vehicle_reference)
);

create table segm.organizational_eligibility (
  id uuid primary key default gen_random_uuid(),
  operating_organization_oid text not null references public.setc_organizations(oid),
  eligibility_type text not null,
  jurisdiction_code text,
  sponsoring_or_issuing_authority text,
  eligibility_reference text,
  evidence_id uuid references segm.evidence_items(id),
  status text not null default 'UNVERIFIED' check (status in ('UNVERIFIED','PENDING','VERIFIED','EXPIRED','SUSPENDED','REVOKED','NOT_ELIGIBLE')),
  effective_from date,
  effective_to date,
  handling_restrictions jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table segm.export_control_reviews (
  id uuid primary key default gen_random_uuid(),
  procurement_case_id uuid references segm.procurement_cases(id) on delete cascade,
  capability_id uuid references segm.capability_registry(id),
  operating_organization_oid text references public.setc_organizations(oid),
  jurisdiction_code text,
  control_regime text,
  classification_reference text,
  review_status text not null default 'NOT_ASSESSED' check (review_status in ('NOT_ASSESSED','IN_REVIEW','NOT_CONTROLLED','CONTROLLED','LICENSE_REQUIRED','LICENSE_VERIFIED','PROHIBITED','ESCALATED')),
  license_or_authorization_reference text,
  evidence_id uuid references segm.evidence_items(id),
  reviewed_by text,
  reviewed_at timestamptz,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (procurement_case_id is not null or capability_id is not null)
);

create table segm.rgl_adapter_links (
  id uuid primary key default gen_random_uuid(),
  procurement_case_id uuid references segm.procurement_cases(id) on delete cascade,
  institution_id uuid references segm.institution_profiles(id),
  rgl_contract_id uuid references rgl.contracts(id),
  government_corridor_mandate_id uuid references rgl.government_corridor_mandates(id),
  link_state text not null default 'REFERENCE_ONLY' check (link_state in ('REFERENCE_ONLY','EVIDENCE_RECEIVED','VERIFIED','AUTHORIZED_FOR_EXECUTION','SUSPENDED','CLOSED')),
  evidence_id uuid references segm.evidence_items(id),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (rgl_contract_id is not null or government_corridor_mandate_id is not null)
);

create table segm.dhn_adapter_links (
  id uuid primary key default gen_random_uuid(),
  procurement_case_id uuid references segm.procurement_cases(id) on delete cascade,
  institution_id uuid references segm.institution_profiles(id),
  dhn_organization_id uuid not null references dhn_org.organizations(organization_id),
  dhn_authorization_approval_event_id uuid references dhn_ops.authorization_approval_events(approval_event_id),
  link_state text not null default 'REFERENCE_ONLY' check (link_state in ('REFERENCE_ONLY','EVIDENCE_RECEIVED','VERIFIED','AUTHORIZED_FOR_EXECUTION','SUSPENDED','CLOSED')),
  evidence_id uuid references segm.evidence_items(id),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table segm.energy_adapter_links (
  id uuid primary key default gen_random_uuid(),
  procurement_case_id uuid references segm.procurement_cases(id) on delete cascade,
  institution_id uuid references segm.institution_profiles(id),
  project_organization_link_id uuid references energy.project_organization_links(link_id),
  energy_agreement_id uuid references energy.commercial_agreements(agreement_id),
  link_state text not null default 'REFERENCE_ONLY' check (link_state in ('REFERENCE_ONLY','EVIDENCE_RECEIVED','VERIFIED','AUTHORIZED_FOR_EXECUTION','SUSPENDED','CLOSED')),
  evidence_id uuid references segm.evidence_items(id),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (project_organization_link_id is not null or energy_agreement_id is not null)
);

create index segm_capability_registry_org_idx on segm.capability_registry(operating_organization_oid, claim_state);
create index segm_contract_vehicle_org_idx on segm.contract_vehicle_references(operating_organization_oid, verification_state);
create index segm_eligibility_org_idx on segm.organizational_eligibility(operating_organization_oid, status);
create index segm_export_control_case_idx on segm.export_control_reviews(procurement_case_id, review_status);
create index segm_rgl_adapter_case_idx on segm.rgl_adapter_links(procurement_case_id, link_state);
create index segm_dhn_adapter_case_idx on segm.dhn_adapter_links(procurement_case_id, link_state);
create index segm_energy_adapter_case_idx on segm.energy_adapter_links(procurement_case_id, link_state);

alter table segm.capability_registry enable row level security;
alter table segm.contract_vehicle_references enable row level security;
alter table segm.organizational_eligibility enable row level security;
alter table segm.export_control_reviews enable row level security;
alter table segm.rgl_adapter_links enable row level security;
alter table segm.dhn_adapter_links enable row level security;
alter table segm.energy_adapter_links enable row level security;

revoke all on all tables in schema segm from anon, authenticated;

