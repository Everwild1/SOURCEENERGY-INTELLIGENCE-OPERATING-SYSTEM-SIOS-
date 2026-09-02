create table if not exists sourcecubes.setc_family_deduplication_crosswalk (
  setc_id text primary key references sourcecubes.setc_patent_landscape_evidence(setc_id) on delete restrict,
  primary_canonical_family text,
  secondary_canonical_families text[],
  dedup_classification text not null,
  standalone_family_candidate boolean not null default false,
  legacy_49_slot_candidate boolean not null default false,
  rationale text not null,
  counsel_gate text not null default 'REQUIRED',
  updated_at timestamptz not null default now()
);

insert into sourcecubes.setc_family_deduplication_crosswalk
(setc_id,primary_canonical_family,secondary_canonical_families,dedup_classification,standalone_family_candidate,legacy_49_slot_candidate,rationale)
values
('SETC-001','SIOS-IP-001',array['SETC-IP-001'],'EXISTING_FAMILY_UMBRELLA',false,false,'System architecture is already substantially represented by the SIOS parent software architecture and SETC institutional-governance family.'),
('SETC-002','SETC-IP-001',array['SIOS-IP-001'],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Canonical on-chain object model is a technical substructure of SETC/SIOS; preserve as claim-support evidence unless counsel establishes a distinct inventive family.'),
('SETC-003','SETC-IP-001',array[]::text[],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Identity and authority registry falls directly within SETC institutional identity, governance and lifecycle control architecture.'),
('SETC-004',null,array['SIOS-IP-001'],'TRADE_SECRET_COPYRIGHT_SUPPORTING_EVIDENCE',false,false,'Source register classifies this item for trade-secret/copyright review. Geospatial subject matter supports SSR/SourceCubes work but is not currently a standalone patent-family candidate.'),
('SETC-005','SEG-IP-QIP-001',array['SIOS-IP-001'],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'IP/document provenance overlaps QIP provenance and SIOS evidence/audit architecture.'),
('SETC-006','SIOS-IP-001',array['SEG-IP-SK-001','SEG-IP-QIP-001'],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Smart-contract governance is better treated as a governed implementation/claim set within existing orchestration families unless a specific new mechanism is identified.'),
('SETC-007','SEG-IP-SC-001',array['SEG-IP-QIP-001','SETC-IP-CAP-001'],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Tokenization and digital-asset governance overlaps Source Coin/QIP and capitalization control architecture.'),
('SETC-008','SEG-IP-WIM-COLOR-001',array['SIOS-IP-001'],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Validator/consensus governance materially overlaps PF-11 consensus concepts in the Color/IP Blockchain Matrix and SIOS implementation architecture.'),
('SETC-009','SIOS-IP-001',array['SETC-IP-001','SEG-IP-HBID-001'],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Key/signature governance is infrastructure within SIOS/SETC and biometric-authentication implementations; generic cryptographic primitives are excluded.'),
('SETC-010','SIOS-IP-001',array[]::text[],'CONTINUATION_OR_COMBINATION_CANDIDATE',false,false,'Genesis deployment/readiness is portfolio-combination or continuation material, not a demonstrated separate family.'),
('SETC-011','SIOS-IP-001',array[]::text[],'TRADE_SECRET_COPYRIGHT_SUPPORTING_EVIDENCE',false,false,'Implementation blueprint is best preserved as know-how/copyright and implementation evidence.'),
('SETC-012','SETC-IP-001',array['SIOS-IP-001'],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Canonical data schemas/object model overlaps SETC-002 and the existing SETC institutional data/governance family.'),
('SETC-013','SETC-IP-001',array[]::text[],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Identity/authority/access-control specification is within SETC-IP-001.'),
('SETC-014','SIOS-IP-001',array['SEG-IP-SK-001'],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Smart-contract/chaincode implementation is an implementation subfamily unless a distinct technical mechanism survives prior-art review.'),
('SETC-015','SIOS-IP-001',array[]::text[],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'API gateway, integration and event architecture is core SIOS infrastructure.'),
('SETC-016','SIOS-IP-001',array[]::text[],'CONTINUATION_OR_COMBINATION_CANDIDATE',false,false,'DevSecOps/CI/CD/IaC is deployment architecture; generic components are public/third-party and SourceEnergy-specific composition is supporting continuation material.'),
('SETC-017','SIOS-IP-001',array[]::text[],'CONTINUATION_OR_COMBINATION_CANDIDATE',false,false,'Observability/security operations are implementation/continuation evidence within SIOS.'),
('SETC-018','SIOS-IP-001',array[]::text[],'TRADE_SECRET_COPYRIGHT_SUPPORTING_EVIDENCE',false,false,'Testing/validation/certification is presently preservation and assurance evidence, not a separate family.'),
('SETC-019','SIOS-IP-001',array[]::text[],'TRADE_SECRET_COPYRIGHT_SUPPORTING_EVIDENCE',false,false,'Launch/commissioning procedures are operational know-how and supporting documentation.'),
('SETC-020','SIOS-IP-001',array['SETC-IP-001'],'CONTINUATION_OR_COMBINATION_CANDIDATE',false,false,'Production governance and lifecycle management are continuation/combination material under SIOS/SETC.'),
('SETC-021','SETC-IP-CAP-001',array['WIM-IP-001','SEG-IP-SC-001','SEG-IP-IOTF-001'],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Treasury/settlement/economic-network architecture is already distributed across capitalization, WIM, Source Coin and IOTF authoritative domains.'),
('SETC-022','SEG-IP-SC-001',array['SEG-IP-QIP-001','SEG-IP-IOTF-001','SETC-IP-CAP-001'],'EXISTING_FAMILY_SUBFAMILY_OR_CLAIM_SET',false,false,'Digital asset, reserve attestation and programmable instrument concepts overlap existing Source Coin/QIP/IOTF/capital control families.'),
('SETC-023','SEG-IP-SC-001',array['SETC-IP-CAP-001'],'POTENTIAL_DISTINCT_SUBFAMILY_REVIEW',true,false,'Wallet/custody/account/authorization architecture may support a distinct subfamily, but overlaps Source Coin and capital controls. Requires claim-specific novelty and rights review before any legacy-slot promotion.'),
('SETC-024','SIOS-IP-001',array['SEG-IP-QIP-001'],'CONTINUATION_OR_COMBINATION_CANDIDATE',false,false,'Explorer/audit/transparency/evidence verification is a continuation/implementation layer of SIOS/QIP provenance architecture.'),
('SETC-025','SIOS-IP-001',array['SEG-IP-WIM-COLOR-001'],'POTENTIAL_DISTINCT_SUBFAMILY_REVIEW',true,false,'NOC/validator command/resilience architecture may contain a distinct systems-control subfamily, but overlaps SIOS and PF-11 consensus; novelty must be established before promotion.'),
('SETC-026','SIOS-IP-001',array['SETC-IP-001'],'POTENTIAL_DISTINCT_SUBFAMILY_REVIEW',true,false,'Developer platform/SDK/toolchain/sandbox may be a distinct software subfamily if SourceEnergy-specific technical orchestration is novel; current evidence is insufficient for a standalone family.'),
('SETC-027','SIOS-IP-001',array['SETC-IP-001'],'POTENTIAL_DISTINCT_SUBFAMILY_REVIEW',true,false,'AI/ML analytics/risk/decision-support may be a distinct intelligence subfamily only if a concrete technical mechanism and claim-specific novelty are demonstrated.')
on conflict (setc_id) do update set
 primary_canonical_family=excluded.primary_canonical_family,
 secondary_canonical_families=excluded.secondary_canonical_families,
 dedup_classification=excluded.dedup_classification,
 standalone_family_candidate=excluded.standalone_family_candidate,
 legacy_49_slot_candidate=excluded.legacy_49_slot_candidate,
 rationale=excluded.rationale,
 counsel_gate=excluded.counsel_gate,
 updated_at=now();

comment on table sourcecubes.setc_family_deduplication_crosswalk is 'Conservative portfolio deduplication crosswalk. Classifications are internal governance assessments only and do not determine patentability, inventorship, ownership, or legal claim scope.';
