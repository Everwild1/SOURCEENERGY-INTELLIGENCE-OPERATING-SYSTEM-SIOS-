create table if not exists ecology.ssr_sea_observations (
  id uuid primary key default gen_random_uuid(),
  provider_code text not null,
  dataset_id text not null,
  observed_at timestamptz not null,
  event_time_reference timestamptz,
  requested_latitude double precision not null check(requested_latitude between -90 and 90),
  requested_longitude double precision not null check(requested_longitude between -180 and 180),
  grid_latitude double precision not null check(grid_latitude between -90 and 90),
  grid_longitude double precision not null check(grid_longitude between -180 and 180),
  variables jsonb not null default '{}'::jsonb,
  units jsonb not null default '{}'::jsonb,
  quality_gate text not null,
  source_urls jsonb not null default '[]'::jsonb,
  retrieval_metadata jsonb not null default '{}'::jsonb,
  canonical_z_authority boolean not null default false,
  physical_impact_authority boolean not null default false,
  official_warning_authority boolean not null default false,
  created_at timestamptz not null default now(),
  unique(provider_code,dataset_id,observed_at,grid_latitude,grid_longitude),
  check(canonical_z_authority=false),
  check(physical_impact_authority=false),
  check(official_warning_authority=false)
);

alter table ecology.ssr_sea_observations enable row level security;
drop policy if exists ssr_sea_observations_service_role on ecology.ssr_sea_observations;
create policy ssr_sea_observations_service_role on ecology.ssr_sea_observations for all to service_role using(true) with check(true);
revoke all on ecology.ssr_sea_observations from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_sea_observations to service_role;

create or replace function public.persist_ssr_sea_observation(p jsonb)
returns uuid language plpgsql security definer set search_path=public,ecology,pg_temp as $$
declare v_id uuid;
begin
  insert into ecology.ssr_sea_observations(
    provider_code,dataset_id,observed_at,event_time_reference,
    requested_latitude,requested_longitude,grid_latitude,grid_longitude,
    variables,units,quality_gate,source_urls,retrieval_metadata,
    canonical_z_authority,physical_impact_authority,official_warning_authority
  ) values (
    p->>'provider_code',p->>'dataset_id',(p->>'observed_at')::timestamptz,nullif(p->>'event_time_reference','')::timestamptz,
    (p->>'requested_latitude')::double precision,(p->>'requested_longitude')::double precision,
    (p->>'grid_latitude')::double precision,(p->>'grid_longitude')::double precision,
    coalesce(p->'variables','{}'::jsonb),coalesce(p->'units','{}'::jsonb),p->>'quality_gate',
    coalesce(p->'source_urls','[]'::jsonb),coalesce(p->'retrieval_metadata','{}'::jsonb),false,false,false
  ) on conflict(provider_code,dataset_id,observed_at,grid_latitude,grid_longitude)
  do update set event_time_reference=excluded.event_time_reference,variables=excluded.variables,units=excluded.units,
    quality_gate=excluded.quality_gate,source_urls=excluded.source_urls,retrieval_metadata=excluded.retrieval_metadata,
    canonical_z_authority=false,physical_impact_authority=false,official_warning_authority=false
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.persist_ssr_sea_observation(jsonb) from public,anon,authenticated;
grant execute on function public.persist_ssr_sea_observation(jsonb) to service_role;

create or replace view ecology.ssr_sea_observational_status as
select provider_code,dataset_id,count(*) observation_count,min(observed_at) earliest_observed_at,max(observed_at) latest_observed_at,
  bool_and(canonical_z_authority=false) canonical_boundary_preserved,
  bool_and(physical_impact_authority=false) impact_boundary_preserved,
  bool_and(official_warning_authority=false) warning_boundary_preserved
from ecology.ssr_sea_observations group by provider_code,dataset_id;

comment on table ecology.ssr_sea_observations is 'SEA observational/context evidence only. It cannot establish physical impact, official warning authority, or canonical SSR Z.';
