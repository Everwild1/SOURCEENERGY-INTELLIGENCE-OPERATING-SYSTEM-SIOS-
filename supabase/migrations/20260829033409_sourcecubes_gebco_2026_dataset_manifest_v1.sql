create table if not exists sourcecubes.gebco_dataset_manifest (
 manifest_id text primary key,
 release_code text not null,
 variant text not null,
 dataset_file text not null,
 dataset_url text not null,
 file_format text not null,
 approximate_size_gb numeric,
 grid_resolution_arcsec integer not null,
 variables text[] not null,
 horizontal_reference text not null,
 vertical_reference text not null,
 canonical_z_authority boolean not null default false,
 extraction_status text not null,
 evidence_reference text not null,
 created_at timestamptz not null default now(),
 unique(release_code,variant,dataset_file)
);
insert into sourcecubes.gebco_dataset_manifest(manifest_id,release_code,variant,dataset_file,dataset_url,file_format,approximate_size_gb,grid_resolution_arcsec,variables,horizontal_reference,vertical_reference,canonical_z_authority,extraction_status,evidence_reference) values
('GEBCO2026-ICE-NC','GEBCO_2026','ice_surface_elevation','GEBCO_2026.nc','https://dap.ceda.ac.uk/bodc/gebco/global/gebco_2026/ice_surface_elevation/netcdf/GEBCO_2026.nc','NetCDF',7.0,15,array['crs','height_above_mean_sea_level','latitude','longitude'],'WGS84 geographic grid','height_above_mean_sea_level / GEBCO source reference; reconcile before SSR EGM96 canonicalization',false,'EXACT_FILE_IDENTIFIED_POINT_EXTRACTION_PENDING','CEDA GEBCO_2026 archive'),
('GEBCO2026-SUBICE-NC','GEBCO_2026','sub_ice_topography_bathymetry','GEBCO_2026_sub_ice.nc','https://dap.ceda.ac.uk/bodc/gebco/global/gebco_2026/sub_ice_topography_bathymetry/netcdf/GEBCO_2026_sub_ice.nc','NetCDF',7.0,15,array['crs','height_above_mean_sea_level','latitude','longitude'],'WGS84 geographic grid','height_above_mean_sea_level / GEBCO source reference; reconcile before SSR EGM96 canonicalization',false,'EXACT_FILE_IDENTIFIED_POINT_EXTRACTION_PENDING','CEDA GEBCO_2026 archive')
on conflict (manifest_id) do update set dataset_url=excluded.dataset_url, extraction_status=excluded.extraction_status;
update ecology.ssr_scientific_data_providers set integration_status='exact_gebco2026_netcdf_files_identified_point_extraction_pending',updated_at=now() where provider_code='GEBCO-SOURCE';
comment on table sourcecubes.gebco_dataset_manifest is 'Controlled exact-file manifest for GEBCO source datasets. Identification of a NetCDF file does not confer canonical SSR vertical authority.';
