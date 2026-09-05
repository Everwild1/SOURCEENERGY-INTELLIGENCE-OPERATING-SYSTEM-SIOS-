create or replace view rgl.ssr_gateway_reconciliation_dashboard with (security_invoker=true) as
select
 n.id infrastructure_node_id,n.name,n.node_type,n.iata_code,n.icao_code,n.latitude,n.longitude,
 g.country_name,g.iso_alpha2,g.rgl_region_code,
 s.id spatial_link_id,s.reconciliation_status,s.reconciliation_confidence,s.ssr_registry_designation,s.ssr_cube_uid,s.ssr_anchor_address,
 count(e.id) filter(where e.verification_status='verified') verified_evidence_count,
 count(e.id) filter(where e.evidence_type='authoritative_coordinate' and e.verification_status='verified') verified_coordinate_count,
 case
   when s.ssr_cube_uid is not null then 'canonicalized'
   when n.latitude is null or n.longitude is null then 'awaiting_coordinate_evidence'
   when not exists(select 1 from public.anchor_tiles) then 'blocked_on_anchor_roster'
   when exists(select 1 from rgl.spatial_reconciliation_queue q where q.spatial_link_id=s.id and q.review_status in ('pending','needs_review')) then 'candidate_review'
   else 'ready_for_candidate_generation'
 end as pipeline_state
from rgl.infrastructure_nodes n
join rgl.geography_registry g on g.id=n.geography_id
join rgl.spatial_registry_links s on s.entity_type='infrastructure_node' and s.entity_id=n.id
left join rgl.spatial_match_evidence e on e.spatial_link_id=s.id
group by n.id,n.name,n.node_type,n.iata_code,n.icao_code,n.latitude,n.longitude,g.country_name,g.iso_alpha2,g.rgl_region_code,s.id,s.reconciliation_status,s.reconciliation_confidence,s.ssr_registry_designation,s.ssr_cube_uid,s.ssr_anchor_address;

create or replace view rgl.ssr_activation_readiness with (security_invoker=true) as
select
 (select count(*) from public.anchor_tiles) anchor_tile_count,
 (select count(*) from public.spatial_cubes) spatial_cube_count,
 (select count(*) from rgl.spatial_registry_links where entity_type='infrastructure_node') staged_gateway_count,
 (select count(*) from rgl.spatial_registry_links s join rgl.infrastructure_nodes n on n.id=s.entity_id where s.entity_type='infrastructure_node' and n.latitude is not null and n.longitude is not null) coordinate_ready_gateway_count,
 (select count(*) from rgl.spatial_registry_links where entity_type='infrastructure_node' and ssr_cube_uid is not null) canonicalized_gateway_count,
 case when (select count(*) from public.anchor_tiles)=729 then 'ready_for_reconciliation' else 'blocked_on_authoritative_729_roster' end activation_state;

revoke all on rgl.ssr_gateway_reconciliation_dashboard,rgl.ssr_activation_readiness from anon,authenticated;
