create table if not exists ecology.ssr_scientific_data_providers (
 provider_code text primary key,
 domain text not null check(domain in ('AIR','LAND','SEA','CROSS_DOMAIN')),
 provider_name text not null,
 service_name text not null,
 role text not null,
 authority_scope text not null,
 temporal_class text not null,
 integration_status text not null default 'planned',
 canonical_z_authority boolean not null default false,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
insert into ecology.ssr_scientific_data_providers(provider_code,domain,provider_name,service_name,role,authority_scope,temporal_class,integration_status,canonical_z_authority,notes) values
('NASA-MERRA2','AIR','NASA GMAO','MERRA-2','Atmospheric reanalysis and historical environmental state','AIR environmental evidence; not coordinate authority','historical/reanalysis','retain',false,'Preserve for atmospheric state, climate, aerosol, wind, pressure and related AIR evidence.'),
('NASA-GEOS','AIR','NASA GMAO','GEOS','Near-real-time and forecast atmospheric state','AIR operational environmental evidence; not coordinate authority','near-real-time/forecast','planned',false,'Complement MERRA-2 for current and forecast AIR state.'),
('OT-POINT','LAND','OpenTopography','Point Elevation API','Terrain/elevation evidence and dataset provenance','EGM96-compatible elevation evidence when provider response explicitly proves datum','static/slow-changing','active',true,'Connected SSR resolver; canonical Z only when vertical datum is explicitly verified as EGM96-compatible.'),
('OT-BATHY','SEA','OpenTopography','SRTM15+/GEBCO bathymetry access','Seabed geometry and bathymetric evidence','SEA geometry evidence; datum must be verified before canonical Z','static/slow-changing','available_via_existing_provider',false,'Use for seabed tests while retaining datum verification gate.'),
('COP-MARINE','SEA','Copernicus Marine Service','Marine Data Store / APIs','Dynamic ocean state: currents, temperature, salinity, sea state and related variables','SEA environmental state; not coordinate authority','observed/reanalysis/forecast','planned',false,'Primary planned dynamic SEA environmental service.'),
('NOAA-ERDDAP','SEA','NOAA/NCEI','ERDDAP','Independent observational and scientific cross-validation layer','Observational evidence; not coordinate authority','observational/time-series','planned',false,'Secondary validation and scientific observation access.'),
('W3W','CROSS_DOMAIN','what3words','Convert API','Horizontal surface address resolution','Surface address evidence only','static/address','active',false,'Does not determine elevation or Z.'),
('SSR-EGM96','CROSS_DOMAIN','SourceEnergy SSR','SSR-Z-EGM96-3M-V1','Canonical vertical identity','EGM96 datum + deterministic 3 m quantization','canonical','active',true,'Canonical Z standard; environmental providers do not redefine Z=0.')
on conflict(provider_code) do update set domain=excluded.domain,provider_name=excluded.provider_name,service_name=excluded.service_name,role=excluded.role,authority_scope=excluded.authority_scope,temporal_class=excluded.temporal_class,integration_status=excluded.integration_status,canonical_z_authority=excluded.canonical_z_authority,notes=excluded.notes,updated_at=now();

create or replace view ecology.ssr_air_land_sea_data_stack as
select domain,provider_code,provider_name,service_name,role,temporal_class,integration_status,canonical_z_authority,authority_scope
from ecology.ssr_scientific_data_providers
order by case domain when 'AIR' then 1 when 'LAND' then 2 when 'SEA' then 3 else 4 end, provider_code;

comment on table ecology.ssr_scientific_data_providers is 'SSR scientific-provider control registry. Separates canonical spatial identity from environmental state and occupancy evidence across AIR/LAND/SEA.';
