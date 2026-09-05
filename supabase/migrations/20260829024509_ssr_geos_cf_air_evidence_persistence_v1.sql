create table if not exists ecology.ssr_geos_cf_observations (
  id uuid primary key default gen_random_uuid(),
  provider_code text not null default 'NASA-GEOS-CF',
  dataset_name text not null,
  observed_at timestamptz,
  forecast_time_coordinate double precision,
  latitude double precision not null,
  longitude double precision not null,
  pressure_level_hpa numeric,
  z_index integer,
  canonical_cube_address text,
  variables jsonb not null default '{}'::jsonb,
  retrieval_metadata jsonb not null default '{}'::jsonb,
  retrieved_at timestamptz not null default now(),
  constraint geos_cf_no_canonical_identity check (z_index is null and canonical_cube_address is null)
);
alter table ecology.ssr_geos_cf_observations enable row level security;
drop policy if exists service_role_all on ecology.ssr_geos_cf_observations;
create policy service_role_all on ecology.ssr_geos_cf_observations for all to service_role using (true) with check (true);
create or replace function public.persist_ssr_geos_cf_observation(payload jsonb)
returns uuid language plpgsql security invoker set search_path=public,ecology as $$
declare rid uuid;
begin
 insert into ecology.ssr_geos_cf_observations(dataset_name,observed_at,forecast_time_coordinate,latitude,longitude,pressure_level_hpa,variables,retrieval_metadata)
 values(payload->>'dataset_name', nullif(payload->>'observed_at','')::timestamptz, nullif(payload->>'forecast_time_coordinate','')::double precision, (payload->>'latitude')::double precision,(payload->>'longitude')::double precision,nullif(payload->>'pressure_level_hpa','')::numeric,coalesce(payload->'variables','{}'::jsonb),coalesce(payload->'retrieval_metadata','{}'::jsonb)) returning id into rid;
 return rid;
end $$;
revoke all on function public.persist_ssr_geos_cf_observation(jsonb) from public,anon,authenticated;
grant execute on function public.persist_ssr_geos_cf_observation(jsonb) to service_role;
