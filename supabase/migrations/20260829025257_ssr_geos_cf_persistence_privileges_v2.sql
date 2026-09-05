grant usage on schema ecology to service_role;
grant select, insert, update, delete on table ecology.ssr_geos_cf_observations to service_role;
create or replace function public.persist_ssr_geos_cf_observation(payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, ecology, pg_temp
as $$
declare rid uuid;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service_role required' using errcode='42501';
  end if;
  insert into ecology.ssr_geos_cf_observations(
    dataset_name, observed_at, forecast_time_coordinate,
    latitude, longitude, pressure_level_hpa, variables, retrieval_metadata
  ) values (
    payload->>'dataset_name',
    nullif(payload->>'observed_at','')::timestamptz,
    nullif(payload->>'forecast_time_coordinate','')::double precision,
    (payload->>'latitude')::double precision,
    (payload->>'longitude')::double precision,
    nullif(payload->>'pressure_level_hpa','')::numeric,
    coalesce(payload->'variables','{}'::jsonb),
    coalesce(payload->'retrieval_metadata','{}'::jsonb)
  ) returning id into rid;
  return rid;
end $$;
revoke all on function public.persist_ssr_geos_cf_observation(jsonb) from public, anon, authenticated;
grant execute on function public.persist_ssr_geos_cf_observation(jsonb) to service_role;
