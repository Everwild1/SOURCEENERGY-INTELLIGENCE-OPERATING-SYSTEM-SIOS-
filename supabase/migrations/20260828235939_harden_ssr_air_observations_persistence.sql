alter table ecology.ssr_air_observations enable row level security;
alter table ecology.ssr_air_observations force row level security;

alter table ecology.ssr_air_observations
  drop constraint if exists ssr_air_observations_lat_check,
  add constraint ssr_air_observations_lat_check check (latitude between -90 and 90),
  drop constraint if exists ssr_air_observations_lon_check,
  add constraint ssr_air_observations_lon_check check (longitude between -180 and 180),
  drop constraint if exists ssr_air_observations_pressure_check,
  add constraint ssr_air_observations_pressure_check check (pressure_level_hpa is null or pressure_level_hpa > 0);

create unique index if not exists ux_ssr_air_observation_evidence
on ecology.ssr_air_observations (
  provider_code,
  dataset_short_name,
  granule_id,
  coalesce(observed_at, '-infinity'::timestamptz),
  latitude,
  longitude,
  coalesce(pressure_level_hpa, -1::numeric)
);

revoke all on ecology.ssr_air_observations from anon, authenticated;
grant select, insert, update on ecology.ssr_air_observations to service_role;

create or replace function public.persist_ssr_air_observation(p jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, ecology
as $$
declare
  v_id uuid;
begin
  if coalesce(p->>'quality_gate','') <> 'PASS_NUMERIC_EXTRACTION' then
    raise exception 'quality gate not passed';
  end if;

  insert into ecology.ssr_air_observations (
    provider_code,
    dataset_short_name,
    granule_id,
    granule_title,
    observed_at,
    latitude,
    longitude,
    pressure_level_hpa,
    z_index,
    canonical_cube_address,
    variables,
    units,
    source_links,
    retrieval_metadata
  ) values (
    coalesce(p->>'provider_code','NASA-MERRA2'),
    p->>'dataset_short_name',
    p->>'granule_id',
    p->>'granule_title',
    nullif(p->>'observed_at','')::timestamptz,
    (p->>'latitude')::double precision,
    (p->>'longitude')::double precision,
    nullif(p->>'pressure_level_hpa','')::numeric,
    nullif(p->>'z_index','')::integer,
    nullif(p->>'canonical_cube_address',''),
    coalesce(p->'variables','{}'::jsonb),
    coalesce(p->'units','{}'::jsonb),
    coalesce(p->'source_links','[]'::jsonb),
    coalesce(p->'retrieval_metadata','{}'::jsonb)
  )
  on conflict (
    provider_code,
    dataset_short_name,
    granule_id,
    (coalesce(observed_at, '-infinity'::timestamptz)),
    latitude,
    longitude,
    (coalesce(pressure_level_hpa, -1::numeric))
  ) do update set
    granule_title = excluded.granule_title,
    variables = excluded.variables,
    units = excluded.units,
    source_links = excluded.source_links,
    retrieval_metadata = excluded.retrieval_metadata,
    retrieved_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.persist_ssr_air_observation(jsonb) from public, anon, authenticated;
grant execute on function public.persist_ssr_air_observation(jsonb) to service_role;

