create or replace view sourcecubes.population_governance_dashboard as
select p.anchor_candidate_id,c.infrastructure_name,c.jurisdiction_code,c.latitude,c.longitude,c.w3w_address,c.elevation_m_egm96,c.z_index,
p.priority,p.population_state,p.w3w_state,p.vertical_state,p.source_authority_state,p.promotion_state,p.next_action,p.blocker_reason,
case when exists(select 1 from sourcecubes.external_evidence_intake i where i.anchor_candidate_id=p.anchor_candidate_id and i.provider_code='W3W' and i.acquisition_state='QUEUED') then 'QUEUED'
     when exists(select 1 from sourcecubes.external_evidence_intake i where i.anchor_candidate_id=p.anchor_candidate_id and i.provider_code='W3W' and i.acquisition_state='RECEIVED') then 'RECEIVED'
     when c.w3w_address is not null then 'AVAILABLE' else 'NOT_QUEUED' end as w3w_acquisition_state,
case when exists(select 1 from sourcecubes.external_evidence_intake i where i.anchor_candidate_id=p.anchor_candidate_id and i.provider_code like 'OT-%' and i.acquisition_state='QUEUED') then 'QUEUED'
     when exists(select 1 from sourcecubes.external_evidence_intake i where i.anchor_candidate_id=p.anchor_candidate_id and i.provider_code like 'OT-%' and i.acquisition_state='RECEIVED') then 'RECEIVED'
     when c.elevation_m_egm96 is not null then 'AVAILABLE' else 'NOT_QUEUED' end as vertical_acquisition_state,
case when b.binding_status='AUTHORITATIVE_ACTIVE' then b.canonical_address end as authoritative_cube_address,
case when b.binding_status='AUTHORITATIVE_ACTIVE' then b.cube_uid end as authoritative_cube_uid,
coalesce(d.air_count,0) air_evidence_count,coalesce(d.land_count,0) land_evidence_count,coalesce(d.sea_count,0) sea_evidence_count,coalesce(d.subsurface_count,0) subsurface_evidence_count,
coalesce(sq.queue_state,case when b.binding_status='AUTHORITATIVE_ACTIVE' then 'NOT_QUEUED' else 'NOT_APPLICABLE_PRE_PROMOTION' end) subsurface_state
from sourcecubes.population_queue p
join ecology.ssr_anchor_candidate_registry c on c.id=p.anchor_candidate_id
left join sourcecubes.cube_bindings b on b.anchor_candidate_id=c.id and b.binding_status='AUTHORITATIVE_ACTIVE'
left join sourcecubes.domain_completion_dashboard d on d.cube_uid=b.cube_uid
left join sourcecubes.subsurface_evidence_queue sq on sq.cube_uid=b.cube_uid;
comment on view sourcecubes.population_governance_dashboard is 'Unified SourceCubes population control plane: candidate evidence acquisition, canonical promotion state, 4D evidence coverage, and subsurface validation state. DCA is not treated as geographic authority.';
