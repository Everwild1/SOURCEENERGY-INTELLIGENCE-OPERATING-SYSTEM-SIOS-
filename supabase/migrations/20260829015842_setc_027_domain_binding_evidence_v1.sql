insert into sourcecubes.setc_027_evidence_assessment(assessment_id,evidence_type,evidence_source,finding,significance,portfolio_effect) values
('SETC027-IMPL-006','DOMAIN_BINDING','Supabase intelligence_authority resource bindings','Bound public.setc_organizations and energy.executive_decision_cases to context-aware BEFORE INSERT/UPDATE/DELETE authority-boundary triggers. When an application transaction declares setc.intelligence_artifact_id, the write must pass governed mutation authorization.','Demonstrates enforcement at actual authoritative domain write paths rather than only a callable control-plane function. Binding remains context-aware for backward compatibility; callers that fail to declare AI/intelligence context are outside this v1 trigger enforcement and require application-service integration or stricter future binding.','MATERIALLY_STRENGTHENS_AI_AUTH_02_ENABLEMENT'),
('SETC027-TEST-002','BOUND_DOMAIN_CONTROL_TEST','public.setc_organizations trigger-bound transactional test','A MODEL_INFERRED artifact with declared intelligence context was denied a direct INSERT into setc_organizations. After promotion to GOVERNANCE_APPROVED and issuance of a matching scoped INSERT authorization for the target OID, the identical bound-table operation was allowed. Entire test transaction was rolled back.','Confirms bypass rejection and governed-promotion success at a real protected domain table.','SATISFIES_INITIAL_BOUND_DOMAIN_TEST_GATE')
on conflict (assessment_id) do update set finding=excluded.finding,significance=excluded.significance,portfolio_effect=excluded.portfolio_effect;

update sourcecubes.setc_distinct_subfamily_review
set preliminary_review_status='IMPLEMENTED_BOUND_AND_CONTROL_TESTED_PENDING_PRIOR_ART_INVENTORSHIP_ASSIGNMENT_AND_COUNSEL',
    legacy_49_slot_recommendation='STRONG_CANDIDATE_FOR_SC_PAT_028_AFTER_LEGAL_AND_PROVENANCE_GATES',
    required_next_evidence='Preserve migration/repository provenance; integrate intelligence-context declaration into AI/application service writers; consider strict bindings after compatibility review; conduct counsel-grade claim chart and prior-art search focused on typed authority-state mutation boundary; complete claim-specific inventor contribution matrix and executed assignment/chain-of-title evidence before SC-PAT-028 promotion.',
    updated_at=now()
where setc_id='SETC-027';

update sourcecubes.setc_027_claim_decomposition
set status='IMPLEMENTED_BOUND_CONTROL_TESTED_PENDING_COUNSEL_AND_RIGHTS',updated_at=now()
where concept_id in ('AI-AUTH-01','AI-AUTH-02','AI-AUTH-03');
