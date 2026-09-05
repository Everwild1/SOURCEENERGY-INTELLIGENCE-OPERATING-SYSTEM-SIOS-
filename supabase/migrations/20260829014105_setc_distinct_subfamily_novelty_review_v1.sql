create table if not exists sourcecubes.setc_distinct_subfamily_review (
  setc_id text primary key references sourcecubes.setc_patent_landscape_evidence(setc_id) on delete restrict,
  candidate_title text not null,
  evidence_source_url text not null,
  distinctiveness_basis text not null,
  overlap_risk text not null,
  preliminary_review_status text not null,
  legacy_49_slot_recommendation text not null,
  required_next_evidence text not null,
  updated_at timestamptz not null default now()
);

insert into sourcecubes.setc_distinct_subfamily_review
(setc_id,candidate_title,evidence_source_url,distinctiveness_basis,overlap_risk,preliminary_review_status,legacy_49_slot_recommendation,required_next_evidence)
values
('SETC-023','Wallet, Digital Custody, Holder Account & Transaction Authorization','https://docs.google.com/document/d/1lsrPzQDt_VsZVGnge-BRXlDBlMvacbsrmx5MpExtvag/edit','Governed wallet types, custody, signing policy, transaction intent, approval, recovery, monitoring and lifecycle controls across multiple actor classes.','HIGH overlap with Source Coin, capitalization controls, cryptographic key governance, and later digital-asset lifecycle specifications including SETC-040 and SETC-047.','DISTINCT_SUBFAMILY_POSSIBLE_BUT_NOT_ESTABLISHED','DO_NOT_PROMOTE_YET','Claim chart against SEG-IP-SC-001 and SETC-IP-CAP-001; identify concrete non-generic technical mechanism; inventor contribution matrix; prior-art search; executed assignment/ownership evidence.'),
('SETC-025','Network Operations Center, Validator Command, Monitoring, Incident Response & Resilience','https://docs.google.com/document/d/1JQIP1eOmckfx6srYIzMEnCt4izzSjhc3aFvv43nQ9cg/edit','Integrated NOC/SOC, validator command, quorum protection, failover, evidence preservation and resilience testing for governed trust-chain operations.','HIGH overlap with SIOS operations, SETC-008 validator governance, PF-11 consensus concepts, and ordinary NOC/SOC practices.','DISTINCT_SUBFAMILY_POSSIBLE_BUT_NOT_ESTABLISHED','DO_NOT_PROMOTE_YET','Show a specific trust-chain control mechanism not taught by standard NOC/SOC/validator systems; claim chart; architecture-to-code evidence; prior-art review; inventor/assignee evidence.'),
('SETC-026','Developer Platform, SDK, Smart Contract Toolchain, Sandbox & Partner Integration','https://docs.google.com/document/d/1McjclrzDPunpgxO-tXj9C9rsK_Mk2luKapJ3JaTH12k/edit','Governed developer credentials, SDK/toolchain, sandbox, conformance testing, partner onboarding and controlled promotion across environments.','VERY HIGH overlap with generic developer-platform patterns and SIOS/SETC implementation architecture.','PRESUMPTIVE_IMPLEMENTATION_SUBFAMILY','DO_NOT_PROMOTE_YET','Identify a concrete SourceEnergy-specific technical enforcement mechanism beyond ordinary SDK/sandbox/conformance tooling; prior art; code provenance; contributor/assignment evidence.'),
('SETC-027','Blockchain Data Intelligence, Analytics, AI/ML, Risk Scoring & Decision-Support','https://docs.google.com/document/d/1ha2IpWHTfCQRFoq2Y8vYkY9Uj0iwsEl8mTaeymsri2I/edit','Derived-intelligence layer with model governance, explainability, lineage, feature controls, human oversight and explicit boundary preventing analytics from silently becoming authoritative state.','HIGH overlap with SIOS intelligence/governance architecture and generic responsible-AI/risk-scoring patterns; potential distinctiveness may lie in authoritative-state separation and evidence lineage.','HIGHEST_PRIORITY_DISTINCT_SUBFAMILY_REVIEW','DO_NOT_PROMOTE_YET','Technical claim decomposition focused on derived-vs-authoritative state separation, immutable lineage, model-to-governance interfaces and machine-enforced decision boundaries; prior-art search; implementation evidence; inventor/assignment review.')
on conflict (setc_id) do update set
 candidate_title=excluded.candidate_title,
 evidence_source_url=excluded.evidence_source_url,
 distinctiveness_basis=excluded.distinctiveness_basis,
 overlap_risk=excluded.overlap_risk,
 preliminary_review_status=excluded.preliminary_review_status,
 legacy_49_slot_recommendation=excluded.legacy_49_slot_recommendation,
 required_next_evidence=excluded.required_next_evidence,
 updated_at=now();

update sourcecubes.setc_family_deduplication_crosswalk
set legacy_49_slot_candidate = false,
    counsel_gate = 'REQUIRED_BEFORE_SLOT_PROMOTION',
    updated_at = now()
where setc_id in ('SETC-023','SETC-025','SETC-026','SETC-027');

comment on table sourcecubes.setc_distinct_subfamily_review is 'Focused novelty and family-boundary review for SETC specifications surviving first-pass deduplication. Internal governance assessment only; not a legal patentability opinion.';
