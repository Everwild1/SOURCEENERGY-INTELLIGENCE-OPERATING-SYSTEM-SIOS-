create or replace view ecology.ssr_air_4d_samples as
select
  p.id as profile_id,
  p.provider_code,
  p.dataset_name,
  p.evidence_time,
  p.requested_latitude,
  p.requested_longitude,
  p.grid_latitude,
  p.grid_longitude,
  (lvl->>'level_index')::integer as provider_level_index,
  nullif(lvl->>'pressure_level_hpa','')::numeric as pressure_level_hpa,
  nullif(lvl->>'candidate_ssr_z_index','')::integer as candidate_ssr_z_index,
  lvl->'variables' as variables,
  lvl->>'quality_gate' as quality_gate,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_profiles p
cross join lateral jsonb_array_elements(p.profile) lvl;

create table if not exists ecology.ssr_air_timeseries_runs (
  id uuid primary key default gen_random_uuid(),
  provider_code text not null check (provider_code in ('NASA-MERRA2','NASA-GEOS-CF')),
  requested_latitude double precision not null,
  requested_longitude double precision not null,
  request_payload jsonb not null,
  status text not null default 'created' check (status in ('created','running','completed','partial','failed','blocked')),
  profile_ids uuid[] not null default '{}'::uuid[],
  succeeded_count integer not null default 0,
  failed_count integer not null default 0,
  result_summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table ecology.ssr_air_timeseries_runs enable row level security;
drop policy if exists ssr_air_timeseries_runs_service_role on ecology.ssr_air_timeseries_runs;
create policy ssr_air_timeseries_runs_service_role on ecology.ssr_air_timeseries_runs for all to service_role using (true) with check (true);
revoke all on ecology.ssr_air_timeseries_runs from anon, authenticated;
grant select,insert,update,delete on ecology.ssr_air_timeseries_runs to service_role;

create or replace view ecology.ssr_air_4d_operational_status as
select
  provider_code,
  count(distinct profile_id) as profile_count,
  count(*) as vertical_sample_count,
  min(evidence_time) as earliest_evidence_time,
  max(evidence_time) as latest_evidence_time,
  count(distinct pressure_level_hpa) as distinct_pressure_levels,
  bool_and(canonical_identity_authority=false) as identity_boundary_preserved
from ecology.ssr_air_4d_samples
group by provider_code;

comment on view ecology.ssr_air_4d_samples is 'Normalized 4D AIR evidence view: horizontal grid, provider vertical coordinate/candidate SSR association, and evidence time. Candidate SSR Z is scientific association only, never canonical identity.';
