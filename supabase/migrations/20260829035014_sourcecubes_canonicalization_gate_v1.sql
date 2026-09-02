create table if not exists sourcecubes.canonicalization_gate (
 gate_id uuid primary key default gen_random_uuid(),
 subject_key text not null,
 anchor_candidate_id uuid references ecology.ssr_anchor_candidate_registry(id),
 horizontal_address_state text not null,
 vertical_evidence_state text not null,
 vertical_datum_state text not null,
 z_assignment_state text not null,
 authority_review_state text not null,
 registry_promotion_state text not null,
 overall_state text not null,
 blocker_reason text,
 evidence_reference text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(subject_key)
);

insert into sourcecubes.canonicalization_gate(subject_key,anchor_candidate_id,horizontal_address_state,vertical_evidence_state,vertical_datum_state,z_assignment_state,authority_review_state,registry_promotion_state,overall_state,blocker_reason,evidence_reference)
select 'ANCHOR_CANDIDATE:'||c.id,c.id,
 case when c.w3w_address is not null then 'W3W_VALIDATED_REFERENCE_PRESENT' else 'OPEN' end,
 case when c.elevation_m_egm96 is not null then 'PRIMARY_EGM96_EVIDENCE_PRESENT' else 'OPEN' end,
 case when c.elevation_m_egm96 is not null then 'EGM96_ESTABLISHED' else 'OPEN' end,
 case when c.z_index is not null and c.canonical_address is not null then 'ASSIGNED_UNDER_SSR_STANDARD' else 'OPEN' end,
 'OPEN','BLOCKED', 'PROMOTION_BLOCKED_AUTHORITY_REVIEW',
 'Canonical spatial identity is generated, but authoritative source/provenance review and registry promotion remain open. GEBCO evidence is supplementary and does not override the existing EGM96 assignment.',
 'ecology.ssr_anchor_candidate_registry; ecology.ssr_candidate_requirement_status; sourcecubes.anchor_promotion_gate; sourcecubes.vertical_evidence_reconciliation'
from ecology.ssr_anchor_candidate_registry c where c.id='d9da0740-b856-489d-bc61-a213e001b478'::uuid
on conflict(subject_key) do update set horizontal_address_state=excluded.horizontal_address_state,vertical_evidence_state=excluded.vertical_evidence_state,vertical_datum_state=excluded.vertical_datum_state,z_assignment_state=excluded.z_assignment_state,authority_review_state=excluded.authority_review_state,registry_promotion_state=excluded.registry_promotion_state,overall_state=excluded.overall_state,blocker_reason=excluded.blocker_reason,evidence_reference=excluded.evidence_reference,updated_at=now();

create or replace view sourcecubes.canonicalization_readiness_dashboard as
select g.*,c.infrastructure_name,c.infrastructure_type,c.jurisdiction_code,c.w3w_address,c.z_index,c.canonical_address,c.cube_uid,c.promotion_eligible
from sourcecubes.canonicalization_gate g left join ecology.ssr_anchor_candidate_registry c on c.id=g.anchor_candidate_id;
comment on table sourcecubes.canonicalization_gate is 'Fail-closed gate separating generated canonical identity from authoritative registry promotion. SourceCube binding cannot treat supplementary GEBCO/Google/visualization evidence as promotion authority.';
