create table if not exists sourcecubes.setc_027_evidence_assessment (
  assessment_id text primary key,
  evidence_type text not null,
  evidence_source text not null,
  finding text not null,
  significance text not null,
  portfolio_effect text not null,
  created_at timestamptz not null default now()
);

insert into sourcecubes.setc_027_evidence_assessment(assessment_id,evidence_type,evidence_source,finding,significance,portfolio_effect) values
('SETC027-IMPL-001','IMPLEMENTATION','Supabase ai_governance schema','Existing ai_governance tables implement agents, mandates, action_requests, approval_requirements, action_approvals, execution_grants and append-only execution_events.','Strong implementation evidence for scoped machine identity, action authorization, human approval, execution-grant issuance and audit continuity.','STRENGTHENS_TECHNICAL_ENABLEMENT_BUT_DOES_NOT_ESTABLISH_NOVELTY'),
('SETC027-IMPL-002','IMPLEMENTATION','ai_governance.validate_execution_grant()','Database trigger denies execution grants unless action status is APPROVED, authorization is unexpired, agent/domain match, and C4-C6 actions have required distinct human approvals; grant lifetime cannot exceed one hour.','Concrete machine-enforced gate demonstrates that high-autonomy agent execution is technically blocked until governed authorization conditions are satisfied.','STRONG_SUPPORT_FOR_AI_AUTH_02_AND_AI_AGENT_01'),
('SETC027-IMPL-003','IMPLEMENTATION','ai_governance.execution_events append-only trigger','Execution event records are protected against update/delete mutation.','Supports immutable or append-only audit evidence for governed actions.','SUPPORTS_AI_LIN_01'),
('SETC027-PA-001','PRELIMINARY_PRIOR_ART','US20200082302A1 / US11574234B2 — Blockchain for Data and Model Governance','Prior art tracks AI/ML model approval chains and stores model governance/provenance information on blockchain.','Material overlap with generic blockchain-based model governance and provenance.','NARROWS_AI_LIN_01_AND_GENERAL_MODEL_GOVERNANCE_CLAIMS'),
('SETC027-PA-002','PRELIMINARY_PRIOR_ART','US20250125981A1 / US20240291679A1 — Proxy autonomous protocol for blockchain access control','Prior art uses ML-informed transaction risk/access evaluation and approval signatures for blockchain access control.','Material overlap with transaction-specific authorization and policy-mediated blockchain access.','NARROWS_GENERIC_AUTHORIZATION_GATE_CLAIMS'),
('SETC027-PA-003','PRELIMINARY_PRIOR_ART','US12580768B2 — decentralized persona agent governance in regulated environments','Prior art freezes agent execution when policy thresholds are exceeded and routes to supervisor approval, with audit and fallback controls.','Strong overlap with human-supervised agent gating, least-privilege and audit mechanisms.','NARROWS_AI_AGENT_01_AND_HUMAN_REVIEW_CLAIMS'),
('SETC027-PA-004','PRELIMINARY_PRIOR_ART','US20260023828A1 — AI lineage system with blockchain integration','Prior art covers blockchain-based AI model/data lineage, anomaly detection and tamper-evident audit trails.','Strong overlap with generic end-to-end AI lineage and blockchain audit concepts.','NARROWS_AI_LIN_01'),
('SETC027-PA-005','PRELIMINARY_PRIOR_ART','KR20260048179A — pre-validation AI governance policy gate','Prior art describes structurally blocking execution/output paths unless an activation identifier opens a policy gate.','Very close conceptual overlap with machine-enforced policy gates preventing bypass.','REQUIRES_NARROWER_CLAIM_AROUND_AUTHORITY_STATE_MUTATION_BOUNDARY')
on conflict (assessment_id) do update set finding=excluded.finding, significance=excluded.significance, portfolio_effect=excluded.portfolio_effect;

update sourcecubes.setc_distinct_subfamily_review
set preliminary_review_status='IMPLEMENTATION_SUBSTANTIATED_PRIOR_ART_CROWDED_NARROW_CLAIM_REVIEW_REQUIRED',
    legacy_49_slot_recommendation='DO_NOT_ASSIGN_SC_PAT_028_YET',
    required_next_evidence='Counsel-grade prior-art and claim chart focused narrowly on authoritative-state mutation prevention rather than generic AI governance, blockchain lineage, human approval, or agent gating; identify schema/trigger or application control that tags derived/model-inferred outputs with authority class and blocks direct mutation of authoritative domain state; claim-specific inventorship and executed assignment evidence.',
    updated_at=now()
where setc_id='SETC-027';
