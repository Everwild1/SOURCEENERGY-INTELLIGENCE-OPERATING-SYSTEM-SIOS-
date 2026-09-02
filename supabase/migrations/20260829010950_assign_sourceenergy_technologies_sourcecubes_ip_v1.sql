create table if not exists sourcecubes.ip_governance (
  ip_record_id uuid primary key default gen_random_uuid(),
  asset_name text not null,
  asset_family text not null,
  assigned_ip_holder text not null,
  ip_role text not null default 'ASSIGNED_IP_HOLDER',
  assignment_authority text not null,
  assignment_status text not null default 'GOVERNANCE_ASSIGNED',
  legal_perfection_status text not null default 'PENDING_DOCUMENTARY_PERFECTION',
  candidate_venture text,
  creator_attribution_status text not null default 'SEPARATE_FROM_IP_OWNERSHIP',
  scope text not null,
  evidence_reference text,
  effective_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(asset_name, assigned_ip_holder)
);

insert into sourcecubes.ip_governance(asset_name,asset_family,assigned_ip_holder,ip_role,assignment_authority,assignment_status,legal_perfection_status,candidate_venture,scope,evidence_reference)
values (
  'SourceCubes™',
  'ELEO GDS / SourceCubes geospatial data intelligence and spatial digital-twin architecture',
  'SourceEnergy Technologies',
  'ASSIGNED_IP_HOLDER',
  'SourceEnergy Ecosystem governance directive',
  'GOVERNANCE_ASSIGNED',
  'PENDING_DOCUMENTARY_PERFECTION',
  'ELEO GDS / SourceCubes',
  'SourceCubes name/mark as used within the ecosystem, technical architecture, SSR integration specification, cube UID model, schemas, software implementations, data models, interoperability specifications, documentation, and derivative technical artifacts, subject to third-party rights and documentary chain-of-title validation.',
  'Governance assignment directive recorded 2026-08-29; legal ownership/perfection remains subject to executed assignment instruments, trademark/patent/copyright records, employment/contractor agreements, and third-party-rights review.'
)
on conflict (asset_name,assigned_ip_holder) do update set assignment_status=excluded.assignment_status, legal_perfection_status=excluded.legal_perfection_status, scope=excluded.scope, evidence_reference=excluded.evidence_reference, updated_at=now();

update sourcecubes.organization_candidates
set ip_status='ASSIGNED_TO_SOURCEENERGY_TECHNOLOGIES_PENDING_PERFECTION',
    notes='Candidate register linkage only; no cohort selection, endorsement, funding, or equity asserted. SourceCubes ecosystem IP is governance-assigned to SourceEnergy Technologies, subject to documentary chain-of-title perfection and third-party-rights review.',
    updated_at=now()
where candidate_name='ELEO GDS / SourceCubes';

update sourcecubes.integration_spec
set evidence_policy='SourceCubes ecosystem IP is governance-assigned to SourceEnergy Technologies. Legal perfection requires documentary chain-of-title validation. No third-party rights, creator attribution, organization verification, W3W validation, DCA-to-SSR concordance, or cohort selection is inferred without supporting evidence.',
    updated_at=now()
where spec_id='SC-SSR-001';

comment on table sourcecubes.ip_governance is 'Governance-level IP assignments and chain-of-title control status. GOVERNANCE_ASSIGNED does not itself represent a filed registration or substitute for executed legal assignment documents.';
