create table if not exists ecology.ssr_air_profiles (
  id uuid primary key default gen_random_uuid(),
  provider_code text not null check (provider_code in ('NASA-MERRA2','NASA-GEOS-CF')),
  dataset_name text not null,
  evidence_time timestamptz not null,
  requested_latitude double precision not null check (requested_latitude between -90 and 90),
  requested_longitude double precision not null check (requested_longitude between -180 and 180),
  grid_latitude double precision not null check (grid_latitude between -90 and 90),
  grid_longitude double precision not null check (grid_longitude between -180 and 180),
  profile jsonb not null,
  quality_gate text not null,
  retrieval_metadata jsonb not null default '{}'::jsonb,
  canonical_cube_address text,
  z_index integer,
  created_at timestamptz not null default now(),
  constraint air_profile_identity_boundary check (canonical_cube_address is null and z_index is null),
  unique(provider_code,dataset_name,evidence_time,grid_latitude,grid_longitude)
);

alter table ecology.ssr_air_profiles enable row level security;
drop policy if exists ssr_air_profiles_service_role on ecology.ssr_air_profiles;
create policy ssr_air_profiles_service_role on ecology.ssr_air_profiles for all to service_role using (true) with check (true);
revoke all on ecology.ssr_air_profiles from anon, authenticated;
grant select,insert,update,delete on ecology.ssr_air_profiles to service_role;

create table if not exists ecology.ssr_air_pressure_to_z_mapping (
  id bigserial primary key,
  provider_code text not null,
  evidence_time timestamptz not null,
  grid_latitude double precision not null,
  grid_longitude double precision not null,
  pressure_level_hpa numeric not null check (pressure_level_hpa > 0),
  geopotential_height_m double precision,
  derived_geometric_height_m double precision,
  candidate_ssr_z_index integer,
  method text not null,
  quality_gate text not null,
  mapping_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint pressure_z_mapping_not_identity check (method <> 'identity_equivalence'),
  unique(provider_code,evidence_time,grid_latitude,grid_longitude,pressure_level_hpa)
);

alter table ecology.ssr_air_pressure_to_z_mapping enable row level security;
drop policy if exists ssr_air_pressure_to_z_service_role on ecology.ssr_air_pressure_to_z_mapping;
create policy ssr_air_pressure_to_z_service_role on ecology.ssr_air_pressure_to_z_mapping for all to service_role using (true) with check (true);
revoke all on ecology.ssr_air_pressure_to_z_mapping from anon, authenticated;
grant select,insert,update,delete on ecology.ssr_air_pressure_to_z_mapping to service_role;

create table if not exists ecology.ssr_air_ingestion_queue (
  id uuid primary key default gen_random_uuid(),
  provider_code text not null check (provider_code in ('NASA-MERRA2','NASA-GEOS-CF')),
  requested_latitude double precision not null,
  requested_longitude double precision not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  requested_variables text[] not null default array['T','U','V','RH','H','OMEGA']::text[],
  requested_levels integer[] not null default '{}'::integer[],
  status text not null default 'queued' check (status in ('queued','running','completed','failed','blocked')),
  attempts integer not null default 0,
  last_error text,
  result_summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_time >= start_time)
);

alter table ecology.ssr_air_ingestion_queue enable row level security;
drop policy if exists ssr_air_ingestion_queue_service_role on ecology.ssr_air_ingestion_queue;
create policy ssr_air_ingestion_queue_service_role on ecology.ssr_air_ingestion_queue for all to service_role using (true) with check (true);
revoke all on ecology.ssr_air_ingestion_queue from anon, authenticated;
grant select,insert,update,delete on ecology.ssr_air_ingestion_queue to service_role;

create or replace view ecology.ssr_air_profile_operational_status as
select
  (select count(*) from ecology.ssr_air_profiles) as profile_count,
  (select count(*) from ecology.ssr_air_pressure_to_z_mapping) as pressure_z_mapping_count,
  (select count(*) from ecology.ssr_air_ingestion_queue where status='queued') as queued_jobs,
  (select count(*) from ecology.ssr_air_ingestion_queue where status='failed') as failed_jobs,
  (select max(evidence_time) from ecology.ssr_air_profiles) as latest_profile_time;

comment on table ecology.ssr_air_pressure_to_z_mapping is 'Scientific pressure/geopotential-height to candidate SSR Z mapping only. Never canonical identity authority; pressure levels are not SSR Z.';
