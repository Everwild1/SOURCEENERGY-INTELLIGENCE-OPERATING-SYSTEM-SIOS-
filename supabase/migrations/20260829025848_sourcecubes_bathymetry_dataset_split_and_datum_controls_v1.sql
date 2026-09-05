insert into ecology.ssr_scientific_data_providers(provider_code,domain,provider_name,service_name,role,authority_scope,temporal_class,integration_status,canonical_z_authority,notes)
values
('OT-SRTM15PLUS','SEA','OpenTopography','Point Elevation / Global DEM API — SRTM15Plus','Primary bathymetry/topography point evidence','SRTM15+ bathymetry/topography evidence; OpenTopography documents SRTM15Plus vertical datum as EGM96. Eligible for direct SSR-Z-EGM96-3M-V1 quantization when response metadata confirms dataset and datum.','static/slow-changing','api_key_required',true,'SRTM15+ is approximately 15 arc-second / 500 m global bathymetry-topography. Preserve dataset version, vertical CRS, coordinates and provider response.'),
('OT-GEBCO','SEA','OpenTopography','Point Elevation / Global DEM API — GEBCO IceTopo/SubIceTopo','Primary/secondary bathymetry evidence from GEBCO through OpenTopography','GEBCO bathymetry evidence. OpenTopography documents GEBCO IceTopo/SubIceTopo vertical reference as Mean Sea Level, not EGM96. Store raw value and datum; transformation/reconciliation is required before canonical SSR Z.','static/slow-changing','api_key_required',false,'GEBCO 2026 is also available from the source dataset provider at 15 arc-second resolution with TID/source-type grid. Preserve GEBCO release/version and TID/source provenance where available.'),
('GEBCO-SOURCE','SEA','GEBCO Bathymetric Compilation Group','GEBCO_2026 Grid / TID Grid / OPeNDAP','Authoritative source dataset and provenance cross-reference','Source-grid bathymetry/topography plus TID source-type provenance. Source values must retain their documented reference surface and be reconciled before SSR canonical Z when not explicitly EGM96.','static/annual release','available_source_dataset',false,'GEBCO_2026 published April 2026; 15 arc-second grid, elevation in metres, with TID grid and OPeNDAP access. Use as source-dataset provenance and independent dataset lane.')
on conflict(provider_code) do update set domain=excluded.domain,provider_name=excluded.provider_name,service_name=excluded.service_name,role=excluded.role,authority_scope=excluded.authority_scope,temporal_class=excluded.temporal_class,integration_status=excluded.integration_status,canonical_z_authority=excluded.canonical_z_authority,notes=excluded.notes,updated_at=now();

update ecology.ssr_scientific_data_providers
set integration_status='umbrella_split_into_dataset_specific_providers', canonical_z_authority=false,
notes='Umbrella bathymetry lane retained for compatibility. Use OT-SRTM15PLUS and OT-GEBCO for dataset-specific datum controls, plus GEBCO-SOURCE for source-grid/TID provenance.' ,updated_at=now()
where provider_code='OT-BATHY';

create table if not exists sourcecubes.vertical_datum_transform_policy (
 policy_id text primary key,
 provider_code text not null references ecology.ssr_scientific_data_providers(provider_code),
 source_vertical_datum text not null,
 canonical_vertical_datum text not null default 'EGM96',
 direct_quantization_allowed boolean not null default false,
 transformation_required boolean not null default true,
 transformation_method text,
 evidence_requirements text not null,
 status text not null,
 updated_at timestamptz not null default now()
);
insert into sourcecubes.vertical_datum_transform_policy(policy_id,provider_code,source_vertical_datum,direct_quantization_allowed,transformation_required,transformation_method,evidence_requirements,status) values
('SC-VDT-SRTM15P-001','OT-SRTM15PLUS','EGM96',true,false,'None when API response explicitly identifies EGM96; apply SSR 3 m quantization only.','Provider response, dataset/version, coordinates, returned vertical CRS/EPSG or WKT, raw elevation, timestamp and request evidence.','ACTIVE'),
('SC-VDT-GEBCO-001','OT-GEBCO','MEAN_SEA_LEVEL',false,true,'Transform/reconcile MSL-referenced bathymetric elevation to EGM96 only with a documented geodetic method appropriate to the dataset/reference surface; never assume MSL equals EGM96.','Provider response, GEBCO dataset/version, source reference surface, raw elevation/depth, transformation method/model/version, uncertainty, transformed value and reviewer/authority evidence.','ACTIVE'),
('SC-VDT-GEBCO-SOURCE-001','GEBCO-SOURCE','DATASET_DOCUMENTED_REFERENCE',false,true,'Retain source-grid value and documented reference surface; transform only when the release metadata and chosen geodetic method establish a defensible path to EGM96.','GEBCO release/version, grid/TID provenance, coordinate/grid cell, raw elevation, source reference metadata, transformation evidence and uncertainty.','ACTIVE')
on conflict(policy_id) do update set source_vertical_datum=excluded.source_vertical_datum,direct_quantization_allowed=excluded.direct_quantization_allowed,transformation_required=excluded.transformation_required,transformation_method=excluded.transformation_method,evidence_requirements=excluded.evidence_requirements,status=excluded.status,updated_at=now();

create table if not exists sourcecubes.bathymetry_ingest_queue (
 request_id uuid primary key default gen_random_uuid(),
 request_name text not null,
 latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180),
 requested_datasets text[] not null default array['OT-SRTM15PLUS','OT-GEBCO','GEBCO-SOURCE'],
 request_status text not null default 'PENDING_EXTERNAL_FETCH',
 purpose text not null,
 authority_reference text not null default 'SC-CAC-001 / SSR-Z-EGM96-3M-V1',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(request_name,latitude,longitude)
);

comment on table sourcecubes.vertical_datum_transform_policy is 'Dataset-specific vertical-datum policy. SRTM15Plus is EGM96 per OpenTopography documentation; GEBCO via OpenTopography is documented as Mean Sea Level and is not automatically equivalent to EGM96.';
comment on table sourcecubes.bathymetry_ingest_queue is 'Controlled queue for real bathymetry point requests. Populate coordinates from governed use cases; do not invent observations when external provider fetch evidence is absent.';
