create table if not exists ecology.ssr_air_observations (
  id uuid primary key default gen_random_uuid(),
  provider_code text not null default 'NASA-MERRA2',
  dataset_short_name text not null,
  granule_id text not null,
  granule_title text,
  observed_at timestamptz,
  latitude double precision not null,
  longitude double precision not null,
  pressure_level_hpa numeric,
  z_index integer,
  canonical_cube_address text,
  variables jsonb not null default '{}'::jsonb,
  units jsonb not null default '{}'::jsonb,
  source_links jsonb not null default '[]'::jsonb,
  retrieval_metadata jsonb not null default '{}'::jsonb,
  retrieved_at timestamptz not null default now(),
  unique(provider_code,dataset_short_name,granule_id,observed_at,latitude,longitude,pressure_level_hpa)
);
alter table ecology.ssr_air_observations enable row level security;
drop policy if exists ssr_air_observations_service_role on ecology.ssr_air_observations;
create policy ssr_air_observations_service_role on ecology.ssr_air_observations for all to service_role using (true) with check (true);
comment on table ecology.ssr_air_observations is 'Time-varying AIR environmental evidence. Does not create or modify canonical W3W/EGM96/SSR spatial identity.';

update ecology.ssr_scientific_data_providers set integration_status='cmr_validated', notes='NASA Earthdata token and CMR granule discovery validated for M2I3NPASM over Jamaica. Next stage: variable extraction/subsetting into ecology.ssr_air_observations.', updated_at=now() where provider_code='NASA-MERRA2';
