create or replace view ecology.ssr_air_temporal_deltas as
with base as (
  select
    profile_id,
    provider_code,
    dataset_name,
    evidence_time,
    grid_latitude,
    grid_longitude,
    pressure_level_hpa,
    candidate_ssr_z_index,
    nullif(variables->>'t','')::double precision as t,
    nullif(variables->>'u','')::double precision as u,
    nullif(variables->>'v','')::double precision as v,
    nullif(variables->>'rh','')::double precision as rh,
    nullif(variables->>'h','')::double precision as h,
    nullif(variables->>'omega','')::double precision as omega
  from ecology.ssr_air_4d_samples
  where quality_gate in ('PASS_MERRA2_MULTI_VARIABLE','PASS_GEOS_CF_MULTI_VARIABLE')
), lagged as (
  select b.*,
    lag(evidence_time) over w as previous_evidence_time,
    lag(t) over w as previous_t,
    lag(u) over w as previous_u,
    lag(v) over w as previous_v,
    lag(rh) over w as previous_rh,
    lag(h) over w as previous_h,
    lag(omega) over w as previous_omega,
    lag(candidate_ssr_z_index) over w as previous_candidate_ssr_z_index
  from base b
  window w as (
    partition by provider_code,dataset_name,grid_latitude,grid_longitude,pressure_level_hpa
    order by evidence_time
  )
), deltas as (
  select *,
    extract(epoch from (evidence_time-previous_evidence_time))/3600.0 as interval_hours,
    t-previous_t as delta_t,
    u-previous_u as delta_u,
    v-previous_v as delta_v,
    rh-previous_rh as delta_rh,
    h-previous_h as delta_h,
    omega-previous_omega as delta_omega,
    candidate_ssr_z_index-previous_candidate_ssr_z_index as delta_candidate_ssr_z
  from lagged
)
select
  profile_id,provider_code,dataset_name,evidence_time,previous_evidence_time,
  grid_latitude,grid_longitude,pressure_level_hpa,candidate_ssr_z_index,
  interval_hours,
  t,u,v,rh,h,omega,
  delta_t,delta_u,delta_v,delta_rh,delta_h,delta_omega,delta_candidate_ssr_z,
  case when delta_u is null or delta_v is null then null
       else sqrt(power(delta_u,2)+power(delta_v,2)) end as wind_vector_change_mps,
  case when interval_hours is null or interval_hours=0 then null else delta_t/interval_hours end as temperature_change_k_per_hour,
  case when interval_hours is null or interval_hours=0 then null else delta_rh/interval_hours end as rh_change_per_hour,
  case when interval_hours is null or interval_hours=0 then null else delta_h/interval_hours end as provider_height_change_m_per_hour,
  false::boolean as canonical_identity_authority
from deltas;

create or replace view ecology.ssr_air_daily_completeness as
select
  provider_code,
  evidence_time::date as evidence_date,
  count(distinct profile_id) as profile_count,
  count(*) as vertical_sample_count,
  count(distinct pressure_level_hpa) as distinct_pressure_levels,
  min(evidence_time) as first_evidence_time,
  max(evidence_time) as last_evidence_time,
  case when provider_code='NASA-MERRA2' then 8 else null end as expected_profile_count,
  case
    when provider_code='NASA-MERRA2' and count(distinct profile_id)=8 then 'COMPLETE'
    when provider_code='NASA-MERRA2' then 'INCOMPLETE'
    else 'OBSERVED_WINDOW'
  end as completeness_status,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_4d_samples
group by provider_code,evidence_time::date;

create or replace view ecology.ssr_air_cross_day_boundary_deltas as
select *
from ecology.ssr_air_temporal_deltas
where previous_evidence_time is not null
  and evidence_time::date <> previous_evidence_time::date;

comment on view ecology.ssr_air_temporal_deltas is
'Temporal change analytics over provider atmospheric evidence. Candidate SSR Z and provider-native H remain scientific associations only and have no canonical identity authority.';
comment on view ecology.ssr_air_cross_day_boundary_deltas is
'Cross-midnight atmospheric deltas between consecutive provider samples; not canonical geometry changes.';
