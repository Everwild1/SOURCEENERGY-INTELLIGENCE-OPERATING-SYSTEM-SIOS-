insert into sourcecubes.setc_027_evidence_assessment(assessment_id,evidence_type,evidence_source,finding,significance,portfolio_effect) values
('SETC027-IMPL-005','IMPLEMENTATION','Supabase intelligence_authority schema — SETC Intelligence Authority Boundary v1','Implemented six authority classes, artifact provenance registry, protected-resource registry, governed promotion events, scoped mutation authorizations, enforcement-event ledger, and control functions for promotion, authorization and mutation enforcement.','Converts the previously identified derived-to-authoritative mutation boundary from architectural intent into an executable control-plane mechanism. The enforcement function denies SOURCE, LEDGER_VERIFIED, DERIVED, MODEL_INFERRED and HUMAN_REVIEWED artifacts from direct authoritative mutation and requires GOVERNANCE_APPROVED status plus a matching active scoped authorization.','STRONG_ENABLEMENT_EVIDENCE_FOR_AI_AUTH_01_AI_AUTH_02_AI_AUTH_03'),
('SETC027-TEST-001','CONTROL_TEST','Transactional authority-boundary verification','A MODEL_INFERRED test artifact attempting UPDATE of ENERGY_EXECUTIVE_DECISIONS was denied (false). After explicit promotion to GOVERNANCE_APPROVED and issuance of a matching five-minute mutation authorization, the same operation was allowed (true). Test transaction was rolled back after verification.','Demonstrates both bypass rejection and governed-promotion success through the implemented control plane without persisting test artifacts.','SATISFIES_INITIAL_BYPASS_AND_PROMOTION_TEST_GATE')
on conflict (assessment_id) do update set finding=excluded.finding,significance=excluded.significance,portfolio_effect=excluded.portfolio_effect;

update sourcecubes.setc_distinct_subfamily_review
set preliminary_review_status='IMPLEMENTED_AND_CONTROL_TESTED_PENDING_BINDING_PRIOR_ART_INVENTORSHIP_AND_COUNSEL',
    legacy_49_slot_recommendation='CANDIDATE_FOR_SC_PAT_028_AFTER_REMAINING_GATES',
    required_next_evidence='Bind enforcement to selected authoritative domain write paths or application service layer; preserve migration/commit provenance; conduct counsel-grade prior-art and claim chart against identified art; complete claim-specific inventor contribution matrix and executed assignment/chain-of-title evidence before legacy-slot promotion.',
    updated_at=now()
where setc_id='SETC-027';

update sourcecubes.setc_027_claim_decomposition
set status='IMPLEMENTED_CONTROL_PLANE_PENDING_DOMAIN_BINDING_AND_COUNSEL', updated_at=now()
where concept_id in ('AI-AUTH-01','AI-AUTH-02','AI-AUTH-03');
