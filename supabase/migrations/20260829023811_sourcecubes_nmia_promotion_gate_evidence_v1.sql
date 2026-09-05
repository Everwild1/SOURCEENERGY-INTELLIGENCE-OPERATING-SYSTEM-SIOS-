create table if not exists sourcecubes.anchor_promotion_gate (
 gate_id text primary key,
 anchor_candidate_id uuid not null references ecology.ssr_anchor_candidate_registry(id),
 source_location_gate text not null,
 w3w_gate text not null,
 vertical_gate text not null,
 canonical_string_gate text not null,
 cube_uid_gate text not null,
 authority_review_gate text not null,
 registry_promotion_gate text not null,
 overall_status text not null,
 evidence_summary jsonb not null default '{}'::jsonb,
 updated_at timestamptz not null default now()
);
insert into sourcecubes.anchor_promotion_gate(gate_id,anchor_candidate_id,source_location_gate,w3w_gate,vertical_gate,canonical_string_gate,cube_uid_gate,authority_review_gate,registry_promotion_gate,overall_status,evidence_summary)
values('SC-ANCHOR-NMIA-001','d9da0740-b856-489d-bc61-a213e001b478','PENDING_AUTHORITATIVE_MATCH','SATISFIED_API_VALIDATED','SATISFIED_EGM96','SATISFIED','SATISFIED_SHA256','OPEN','BLOCKED','PROMOTION_BLOCKED',jsonb_build_object('canonical_address','///thing.pace.eagle@Z+0001','w3w_provider','what3words','vertical_standard','SSR-Z-EGM96-3M-V1','source_reference','https://nmia.aero/business/cargo-business/ | SSR_Phase_XVII_Cross_Reference_Index / Registry Entry 411.IX-01','remaining_blocker','Source record pending/needs_review; authoritative registry match and authority/evidence review required.'))
on conflict(gate_id) do update set source_location_gate=excluded.source_location_gate,w3w_gate=excluded.w3w_gate,vertical_gate=excluded.vertical_gate,canonical_string_gate=excluded.canonical_string_gate,cube_uid_gate=excluded.cube_uid_gate,authority_review_gate=excluded.authority_review_gate,registry_promotion_gate=excluded.registry_promotion_gate,overall_status=excluded.overall_status,evidence_summary=excluded.evidence_summary,updated_at=now();

update sourcecubes.anchor_tile_bindings
set binding_status='CANONICALIZED_PROMOTION_BLOCKED_AUTHORITY_REVIEW',authority_state='CANDIDATE_CANONICALIZED',updated_at=now()
where anchor_candidate_id='d9da0740-b856-489d-bc61-a213e001b478'::uuid;

comment on table sourcecubes.anchor_promotion_gate is 'SourceCubes mirror of SSR canonicalization/promotion gates. It must not override ecology SSR promotion authority.';
