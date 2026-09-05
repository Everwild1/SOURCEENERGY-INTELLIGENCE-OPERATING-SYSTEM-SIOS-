alter table public.anchor_tiles add column if not exists authority_signature text;
alter table public.anchor_tiles add column if not exists metadata_hash text;
alter table ssr_ingest.anchor_tiles_stage add column if not exists authority_signature text;
alter table ssr_ingest.anchor_tiles_stage add column if not exists metadata_hash text;

alter table public.anchor_tiles add constraint anchor_tiles_metadata_hash_format check (metadata_hash is null or metadata_hash ~ '^[0-9a-fA-F]{64}$') not valid;
alter table ssr_ingest.anchor_tiles_stage add constraint anchor_tiles_stage_metadata_hash_format check (metadata_hash is null or metadata_hash ~ '^[0-9a-fA-F]{64}$') not valid;

drop view if exists rgl.ssr_activation_readiness;
create view rgl.ssr_activation_readiness with (security_invoker=true) as
select
 (select count(*) from public.anchor_tiles) anchor_tile_count,
 (select count(*) from public.anchor_tiles where nullif(trim(authority_signature),'') is not null) anchor_tiles_with_authority_signature,
 (select count(*) from public.anchor_tiles where metadata_hash ~ '^[0-9a-fA-F]{64}$') anchor_tiles_with_metadata_hash,
 (select count(*) from public.spatial_cubes) spatial_cube_count,
 (select count(*) from rgl.spatial_registry_links where entity_type='infrastructure_node') staged_gateway_count,
 (select count(*) from rgl.spatial_registry_links s join rgl.infrastructure_nodes n on n.id=s.entity_id where s.entity_type='infrastructure_node' and n.latitude is not null and n.longitude is not null) coordinate_ready_gateway_count,
 (select count(*) from rgl.spatial_registry_links where entity_type='infrastructure_node' and ssr_cube_uid is not null) canonicalized_gateway_count,
 case when (select count(*) from public.anchor_tiles)=729 then 'ready_for_reconciliation' else 'blocked_on_authoritative_729_roster' end activation_state;

revoke all on rgl.ssr_activation_readiness from anon,authenticated;
