create table segm.onboarding_batches (
  id uuid primary key default gen_random_uuid(),
  batch_code text not null unique,
  source_scope text not null,
  source_description text,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  batch_status text not null default 'OPEN' check (batch_status in ('OPEN','IN_REVIEW','COMPLETE','CANCELLED')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table segm.onboarding_candidates (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references segm.onboarding_batches(id) on delete cascade,
  setc_organization_oid text references public.setc_organizations(oid),
  candidate_name text not null,
  candidate_role text not null check (candidate_role in ('GOVERNMENT_INSTITUTION','PUBLIC_AUTHORITY','DEFENSE_ORGANIZATION','DIPLOMATIC_ENTITY','MULTILATERAL_INSTITUTION','OPERATING_ENTITY','PARTNER','OTHER')),
  proposed_institution_class text check (proposed_institution_class is null or proposed_institution_class in ('CIVIL_GOVERNMENT','DEFENSE_MILITARY','DIPLOMATIC','MULTILATERAL','PUBLIC_AUTHORITY','EMERGENCY_MANAGEMENT','RESEARCH_INSTITUTION','GOVERNMENT_CONTRACTOR','OTHER')),
  evidence_disposition text not null default 'NO_EVIDENCE' check (evidence_disposition in ('NO_EVIDENCE','CONCEPTUAL_ONLY','DECLARED_CAPABILITY','RELATIONSHIP_EVIDENCE','AUTHORITY_EVIDENCE','REJECTED')),
  onboarding_state text not null default 'DISCOVERED' check (onboarding_state in ('DISCOVERED','EVIDENCE_REQUIRED','UNDER_REVIEW','READY_FOR_PROFILE','ONBOARDED','REJECTED','DEFERRED')),
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','DECLARED_CAPABILITY','VERIFIED_RELATIONSHIP','VERIFIED_AUTHORITY','SUSPENDED','ARCHIVED')),
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(batch_id, candidate_name)
);

create index segm_onboarding_candidates_batch_state_idx on segm.onboarding_candidates(batch_id, onboarding_state);
create index segm_onboarding_candidates_setc_oid_idx on segm.onboarding_candidates(setc_organization_oid);
create index segm_onboarding_candidates_verification_idx on segm.onboarding_candidates(verification_state);

alter table segm.onboarding_batches enable row level security;
alter table segm.onboarding_candidates enable row level security;
revoke all on segm.onboarding_batches from anon, authenticated;
revoke all on segm.onboarding_candidates from anon, authenticated;

insert into segm.onboarding_batches (batch_code, source_scope, source_description, batch_status, metadata)
values (
  'SEGM-08-2026-08-24-A',
  'SOURCEENERGY_ECOSYSTEM_AND_CANONICAL_ORG_REGISTRY',
  'Initial SEGM evidence-driven onboarding pass. No authority is inferred from capability, relationship, naming, or conceptual material.',
  'IN_REVIEW',
  jsonb_build_object('control_posture','FAIL_CLOSED','authority_inference_allowed',false)
)
on conflict (batch_code) do nothing;

insert into segm.onboarding_candidates (
  batch_id, setc_organization_oid, candidate_name, candidate_role, evidence_disposition, onboarding_state, verification_state, notes, metadata
)
select b.id, o.oid, o.legal_name, 'OPERATING_ENTITY',
       'NO_EVIDENCE', 'EVIDENCE_REQUIRED', 'UNVERIFIED',
       'Operating-entity candidate only; not a government or military institution. Requires documentary evidence before any SEGM capability, eligibility, contract-vehicle, relationship, or authority promotion.',
       jsonb_build_object('setc_verification_state',o.verification_state,'organization_type',o.organization_type)
from segm.onboarding_batches b
join public.setc_organizations o on o.legal_name in ('Robert Global Logistics LLC','Energy Source Business','SourceEnergy Group')
where b.batch_code='SEGM-08-2026-08-24-A'
on conflict (batch_id, candidate_name) do nothing;
