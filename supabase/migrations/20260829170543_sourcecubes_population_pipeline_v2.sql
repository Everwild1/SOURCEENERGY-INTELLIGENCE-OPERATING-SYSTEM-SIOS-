create table if not exists sourcecubes.population_queue(
 queue_id uuid primary key default gen_random_uuid(),
 anchor_candidate_id uuid not null unique references ecology.ssr_anchor_candidate_registry(id) on delete cascade,
 priority integer not null default 100,
 population_state text not null,
 w3w_state text not null,
 vertical_state text not null,
 source_authority_state text not null,
 promotion_state text not null,
 next_action text not null,
 blocker_reason text,
 updated_at timestamptz not null default now()
);

insert into sourcecubes.population_queue(anchor_candidate_id,priority,population_state,w3w_state,vertical_state,source_authority_state,promotion_state,next_action,blocker_reason)
select c.id,
 case when c.jurisdiction_code='JM' then 10 when c.jurisdiction_code in ('US','CA') then 20 else 30 end,
 case when c.canonicalization_status='promoted' then 'AUTHORITATIVE_ACTIVE' when c.w3w_address is not null and c.z_index is not null then 'CANONICALIZATION_READY' when c.w3w_address is null then 'EVIDENCE_ACQUISITION' else 'VERTICAL_EVIDENCE_REQUIRED' end,
 case when c.w3w_address is not null and exists(select 1 from ecology.ssr_w3w_validation_log w where w.subject_id=c.id::text and lower(w.validation_status)='validated') then 'VALIDATED' when c.w3w_address is not null then 'PRESENT_UNVALIDATED' else 'REQUIRED' end,
 case when c.elevation_m_egm96 is not null and c.z_index is not null then 'EGM96_Z_ASSIGNED' else 'EGM96_REQUIRED' end,
 case when lower(coalesce(c.source_verification_status,''))='verified' then 'VERIFIED' else 'REVIEW_REQUIRED' end,
 case when c.canonicalization_status='promoted' then 'PROMOTED' else 'BLOCKED_UNTIL_GATES_PASS' end,
 case when c.canonicalization_status='promoted' then 'ATTACH_4D_EVIDENCE' when c.w3w_address is null then 'RESOLVE_W3W_FROM_VALIDATED_COORDINATES' when c.elevation_m_egm96 is null then 'RESOLVE_EGM96_ELEVATION' when lower(coalesce(c.source_verification_status,''))<>'verified' then 'RECONCILE_SOURCE_AUTHORITY' else 'RUN_CANONICALIZATION_GATES' end,
 c.blocker_reason
from ecology.ssr_anchor_candidate_registry c
on conflict(anchor_candidate_id) do update set priority=excluded.priority,population_state=excluded.population_state,w3w_state=excluded.w3w_state,vertical_state=excluded.vertical_state,source_authority_state=excluded.source_authority_state,promotion_state=excluded.promotion_state,next_action=excluded.next_action,blocker_reason=excluded.blocker_reason,updated_at=now();

create or replace view sourcecubes.population_dashboard as
select q.priority,c.infrastructure_name,c.infrastructure_type,c.jurisdiction_code,c.latitude,c.longitude,c.w3w_address,c.elevation_m_egm96,c.z_index,c.canonical_address,q.population_state,q.w3w_state,q.vertical_state,q.source_authority_state,q.promotion_state,q.next_action,q.blocker_reason,c.id as anchor_candidate_id
from sourcecubes.population_queue q join ecology.ssr_anchor_candidate_registry c on c.id=q.anchor_candidate_id;

comment on table sourcecubes.population_queue is 'Controlled SourceCube population work queue. Coordinates alone never authorize promotion; canonical evidence and authority gates remain mandatory.';
