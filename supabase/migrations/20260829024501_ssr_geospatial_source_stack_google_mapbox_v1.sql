insert into ecology.ssr_scientific_data_providers(provider_code,domain,provider_name,service_name,role,authority_scope,temporal_class,integration_status,canonical_z_authority,notes)
values
('GOOGLE-ELEV','CROSS_DOMAIN','Google','Elevation API','Independent elevation cross-check','Secondary elevation cross-check only; must not independently redefine SSR canonical vertical datum','static/slow-changing','planned_secondary_crosscheck',false,'Use as an independent cross-check against canonical SSR elevation evidence. Differences must be recorded and reconciled; Google Elevation is not SSR datum authority.'),
('MAPBOX-TERRAIN','CROSS_DOMAIN','Mapbox','Terrain-DEM','Visualization and 3D terrain rendering','Visualization/terrain rendering only; not SSR datum authority and must not promote or mutate canonical Z','static/visualization','planned_visualization',false,'Use for visualization and 3D terrain experiences. Never treat Mapbox Terrain-DEM as canonical SSR vertical datum authority.')
on conflict(provider_code) do update set domain=excluded.domain,provider_name=excluded.provider_name,service_name=excluded.service_name,role=excluded.role,authority_scope=excluded.authority_scope,temporal_class=excluded.temporal_class,integration_status=excluded.integration_status,canonical_z_authority=excluded.canonical_z_authority,notes=excluded.notes,updated_at=now();

update ecology.ssr_scientific_data_providers
set role='Ocean/bathymetry geometry and seabed evidence', authority_scope='SEA bathymetry/geometry evidence; use GEBCO/SRTM15+ through OpenTopography and source datasets; datum must be verified before canonical Z', integration_status='use', notes='Primary ocean/bathymetry source lane. Use GEBCO/SRTM15+ through OpenTopography plus source datasets. Retain datum verification and provenance before any canonical SSR Z assignment.', updated_at=now()
where provider_code='OT-BATHY';

create table if not exists sourcecubes.geospatial_source_policy (
 policy_code text primary key,
 source_role text not null,
 provider_codes text[] not null,
 usage_policy text not null,
 canonical_datum_authority boolean not null default false,
 conflict_policy text not null,
 status text not null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
insert into sourcecubes.geospatial_source_policy(policy_code,source_role,provider_codes,usage_policy,canonical_datum_authority,conflict_policy,status) values
('SC-GEO-OCEAN-001','Ocean/bathymetry',array['OT-BATHY'],'USE GEBCO/SRTM15+ through OpenTopography plus underlying/source datasets for bathymetry and seabed evidence. Verify source vertical datum before conversion or assignment into SSR-Z-EGM96-3M-V1.',false,'Do not silently convert bathymetric depth/elevation into canonical SSR Z when datum/reference surface is uncertain. Preserve raw value, source dataset, datum and transformation evidence.','CONTROLLED_USE'),
('SC-GEO-XCHECK-001','Independent elevation cross-check',array['GOOGLE-ELEV'],'Use Google Elevation API as a secondary independent cross-check against the canonical evidence lane.',false,'A discrepancy does not overwrite canonical Z. Record variance and route material disagreement to reconciliation/evidence review.','SECONDARY'),
('SC-GEO-VIZ-001','Visualization/3D terrain',array['MAPBOX-TERRAIN'],'Use Mapbox Terrain-DEM for visualization and 3D terrain rendering only.',false,'Mapbox-derived elevation must never promote, overwrite or serve as authority for SSR canonical Z.','VISUALIZATION_ONLY')
on conflict(policy_code) do update set source_role=excluded.source_role,provider_codes=excluded.provider_codes,usage_policy=excluded.usage_policy,canonical_datum_authority=excluded.canonical_datum_authority,conflict_policy=excluded.conflict_policy,status=excluded.status,updated_at=now();

comment on table sourcecubes.geospatial_source_policy is 'SourceCubes/SSR controlled policy for geospatial evidence, independent cross-checks and visualization sources. Canonical vertical identity remains governed separately by SSR-Z-EGM96-3M-V1.';
