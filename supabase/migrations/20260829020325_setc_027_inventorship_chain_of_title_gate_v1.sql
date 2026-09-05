create table if not exists sourcecubes.setc_027_inventorship_evidence (
  evidence_id text primary key,
  evidence_type text not null,
  person_or_entity text,
  source_reference text not null,
  evidence_date timestamptz,
  evidentiary_weight text not null,
  finding text not null,
  legal_effect text not null,
  created_at timestamptz not null default now()
);

insert into sourcecubes.setc_027_inventorship_evidence(evidence_id,evidence_type,person_or_entity,source_reference,evidence_date,evidentiary_weight,finding,legal_effect) values
('SETC027-PROV-001','DRIVE_REVISION_ATTRIBUTION','Oliver Jones','Google Drive SETC-027 revision 1 / document 1ha2IpWHTfCQRFoq2Y8vYkY9Uj0iwsEl8mTaeymsri2I','2026-08-12T05:32:40.027Z','DOCUMENT_PROVENANCE','Google Drive revision metadata identifies Oliver Jones as the last modifying user for the initial recorded revision.','Supports document provenance/authorship investigation only; does not by itself establish patent inventorship or ownership.'),
('SETC027-PROV-002','DRIVE_REVISION_ATTRIBUTION','Oliver Jones','Google Drive SETC-027 revision 2 / document 1ha2IpWHTfCQRFoq2Y8vYkY9Uj0iwsEl8mTaeymsri2I','2026-08-12T05:34:08.527Z','DOCUMENT_PROVENANCE','Google Drive revision metadata identifies Oliver Jones as the last modifying user for the second/current recorded revision.','Supports document provenance/authorship investigation only; claim-specific inventive contribution remains to be determined.'),
('SETC027-GOV-001','IP_GOVERNANCE_STANDARD','SourceEnergy Ecosystem','SETC-104 — Intellectual Property, Invention Disclosure & Technology Transfer Governance — Version 1.0',null,'GOVERNANCE_STANDARD','SETC-104 states that registry, discussion, commercialization activity, authorship or related records do not independently establish legal ownership, inventorship, patent validity, freedom to operate, or license rights.','Requires separate invention disclosure, contribution/inventorship analysis, ownership/assignment evidence and counsel review before legal status is asserted.'),
('SETC027-ASSIGN-001','ASSIGNMENT_SEARCH','SourceEnergy Technologies','Drive search for SETC-027 assignment / SourceEnergy Technologies intellectual property assignment',null,'NEGATIVE_SEARCH_RESULT','No SETC-027-specific executed assignment instrument was identified in the searched Drive evidence. SourceCubes has a separate governance assignment record, but that does not automatically assign SETC-027.','Chain of title for SETC-027 remains UNPERFECTED/UNESTABLISHED pending an executed assignment or other valid ownership basis.')
on conflict (evidence_id) do update set finding=excluded.finding,legal_effect=excluded.legal_effect;

create table if not exists sourcecubes.setc_027_legal_gates (
  gate_code text primary key,
  gate_name text not null,
  status text not null,
  required_evidence text not null,
  notes text,
  updated_at timestamptz not null default now()
);

insert into sourcecubes.setc_027_legal_gates(gate_code,gate_name,status,required_evidence,notes) values
('G1','Technical Enablement','SATISFIED_INITIAL','Implemented intelligence_authority control plane, bound triggers and passing bypass/promotion tests.','Further code/commit provenance should still be preserved.'),
('G2','Claim-Specific Inventorship','OPEN','Contribution matrix for AI-AUTH-01/02/03 and any other claims identifying who conceived each claimed element and when.','Drive edit metadata is supporting provenance, not inventorship proof.'),
('G3','Chain of Title / Assignment','OPEN','Executed assignment to SourceEnergy Technologies or documented ownership basis covering the relevant invention and contributor rights.','No SETC-027-specific executed assignment identified in current Drive search.'),
('G4','Prior Art / Claim Chart','OPEN','Counsel-grade search and element-by-element claim chart against identified AI governance, agent gating, blockchain lineage and policy-gate art.','Broad field is crowded; focus narrowly on authoritative-state mutation boundary.'),
('G5','Public Disclosure Audit','OPEN','Dates, channels, confidentiality and subject matter of any disclosures before filing.','Required by filing-readiness controls.'),
('G6','Counsel Patentability / Filing Decision','OPEN','Counsel determination on novelty/nonobviousness/eligibility, claim strategy and filing lane.','Internal governance review is not a legal opinion.'),
('G7','Legacy Slot Promotion','BLOCKED','G2-G6 materially resolved and SourceEnergy portfolio authority approves promotion.','SC-PAT-028 remains unassigned.')
on conflict (gate_code) do update set status=excluded.status,required_evidence=excluded.required_evidence,notes=excluded.notes,updated_at=now();

update sourcecubes.setc_distinct_subfamily_review
set preliminary_review_status='TECHNICALLY_ENABLED_LEGAL_PROVENANCE_GATES_OPEN',
    legacy_49_slot_recommendation='SC_PAT_028_BLOCKED_PENDING_INVENTORSHIP_ASSIGNMENT_PRIOR_ART_DISCLOSURE_AND_COUNSEL',
    required_next_evidence='Complete claim-specific contribution matrix; execute or locate valid assignment/ownership basis to SourceEnergy Technologies; complete public-disclosure audit; obtain counsel-grade prior-art/claim chart and filing decision. Preserve Drive revision and Supabase migration provenance.',
    updated_at=now()
where setc_id='SETC-027';
