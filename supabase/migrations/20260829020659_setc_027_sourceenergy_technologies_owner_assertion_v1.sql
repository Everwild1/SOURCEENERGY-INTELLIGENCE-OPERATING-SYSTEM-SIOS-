insert into sourcecubes.setc_027_inventorship_evidence(evidence_id,evidence_type,person_or_entity,source_reference,evidence_date,evidentiary_weight,finding,legal_effect) values
('SETC027-OWNER-001','OWNER_ASSERTION','SourceEnergy Technologies','User governance directive — 2026-08-29',now(),'OWNER_ATTESTATION','Oliver Jones states that he owns SourceEnergy Technologies.','Establishes a controlled owner attestation for ecosystem governance and counterparty-resolution purposes. It does not by itself prove entity formation, equity ownership in an official registry, patent inventorship, or transfer of personally owned invention rights to the company.')
on conflict (evidence_id) do update set finding=excluded.finding,legal_effect=excluded.legal_effect,evidence_date=excluded.evidence_date;

update sourcecubes.setc_027_legal_gates
set status='OWNER_ATTESTED_ASSIGNMENT_STILL_OPEN',
    required_evidence='Owner attestation recorded. For patent chain of title, identify claim-specific inventor(s) and execute an assignment to SourceEnergy Technologies to the extent invention rights are personally or otherwise separately held, unless documentary evidence establishes company ownership from inception.',
    notes='Ownership/control of the assignee and ownership of the invention are distinct legal questions. The owner attestation resolves the internal assignee-control question but not patent chain of title.',
    updated_at=now()
where gate_code='G3';

update sourcecubes.setc_distinct_subfamily_review
set preliminary_review_status='TECHNICALLY_ENABLED_ASSIGNEE_OWNER_ATTESTED_INVENTORSHIP_AND_IP_TRANSFER_GATES_OPEN',
    legacy_49_slot_recommendation='SC_PAT_028_BLOCKED_PENDING_INVENTORSHIP_IP_TRANSFER_PRIOR_ART_DISCLOSURE_AND_COUNSEL',
    required_next_evidence='Treat SourceEnergy Technologies as the owner-attested intended assignee. Complete claim-specific contribution/inventorship matrix for AI-AUTH-01/02/03; determine whether invention rights arose in the company or are personally/otherwise held; execute assignment where required; complete disclosure audit, counsel-grade prior-art/claim chart and filing decision.',
    updated_at=now()
where setc_id='SETC-027';
