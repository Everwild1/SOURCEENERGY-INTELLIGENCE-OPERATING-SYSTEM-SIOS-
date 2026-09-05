insert into sourcecubes.setc_027_evidence_assessment(assessment_id,evidence_type,evidence_source,finding,significance,portfolio_effect) values
('SETC027-IMPL-004','IMPLEMENTATION_GAP_ASSESSMENT','Supabase cross-schema authority/intelligence scan','The database contains multiple authority/provenance primitives: energy.measurement_sources.authority_state; energy.executive_decision_cases.verification_state; ecology.regenerative_projections.governance_status and authority_reference; ecology.projection_corrections authority/evidence references; cruds.intelligence_projections provenance; insurance adapter authority_class plus intelligence lineage/explanations; and media claims requiring authoritative sources. However, no inspected schema/trigger currently provides a generalized authority class for derived/model-inferred intelligence together with a database-enforced prohibition on direct mutation of authoritative domain state.','This distinguishes documented architectural intent from implemented enforcement. Existing ai_governance execution-grant controls substantiate governed agent execution, but the narrower derived-to-authoritative state mutation boundary remains an implementation gap in the inspected database controls.','DO_NOT_PROMOTE_TO_LEGACY_SLOT_UNTIL_GENERALIZED_BOUNDARY_IS_IMPLEMENTED_OR_OTHER_CODE_EVIDENCE_IS_FOUND')
on conflict (assessment_id) do update set finding=excluded.finding,significance=excluded.significance,portfolio_effect=excluded.portfolio_effect;

update sourcecubes.setc_distinct_subfamily_review
set preliminary_review_status='NARROW_CLAIM_MECHANISM_IDENTIFIED_IMPLEMENTATION_GAP_CONFIRMED',
    legacy_49_slot_recommendation='DO_NOT_ASSIGN_SC_PAT_028',
    required_next_evidence='Implement or locate existing application code for a generalized authority-class registry and governed promotion mechanism that classifies SOURCE/LEDGER_VERIFIED/DERIVED/MODEL_INFERRED/HUMAN_REVIEWED/GOVERNANCE_APPROVED outputs and blocks DERIVED or MODEL_INFERRED artifacts from directly mutating designated authoritative resources without a recorded promotion authorization. Then produce tests demonstrating rejected bypass and accepted governed promotion; preserve commit provenance for inventorship/enablement review.',
    updated_at=now()
where setc_id='SETC-027';

update sourcecubes.setc_027_claim_decomposition
set status='IMPLEMENTATION_GAP_CONFIRMED', updated_at=now()
where concept_id in ('AI-AUTH-01','AI-AUTH-02','AI-AUTH-03');
