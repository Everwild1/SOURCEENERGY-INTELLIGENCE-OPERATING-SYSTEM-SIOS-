create or replace view ecology.ssr_air_profile_trajectory_metrics as
with samples as (
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
    nullif(variables->>'omega','')::double precision as omega,
    case
      when variables ? 'u' and variables ? 'v'
      then sqrt(power((variables->>'u')::double precision,2) + power((variables->>'v')::double precision,2))
      else null
    end as wind_speed_mps
  from ecology.ssr_air_4d_samples
  where quality_gate in ('PASS_MERRA2_MULTI_VARIABLE','PASS_GEOS_CF_MULTI_VARIABLE')
), grouped as (
  select
    profile_id,
    provider_code,
    dataset_name,
    evidence_time,
    grid_latitude,
    grid_longitude,
    count(*) as level_count,
    min(pressure_level_hpa) as min_pressure_hpa,
    max(pressure_level_hpa) as max_pressure_hpa,
    min(candidate_ssr_z_index) as min_candidate_ssr_z,
    max(candidate_ssr_z_index) as max_candidate_ssr_z,
    avg(t) as column_mean_t_k,
    avg(rh) as column_mean_rh,
    avg(omega) as column_mean_omega_pa_s,
    max(wind_speed_mps) as max_wind_speed_mps,
    avg(wind_speed_mps) as mean_wind_speed_mps,
    (array_agg(pressure_level_hpa order by wind_speed_mps desc nulls last))[1] as max_wind_pressure_hpa,
    (array_agg(t order by h asc nulls last))[1] as lower_level_t_k,
    (array_agg(t order by h desc nulls last))[1] as upper_level_t_k,
    min(h) as lower_provider_h_m,
    max(h) as upper_provider_h_m,
    max(h)-min(h) as provider_height_span_m
  from samples
  group by profile_id,provider_code,dataset_name,evidence_time,grid_latitude,grid_longitude
)
select
  grouped.*,
  case
    when provider_height_span_m is null or provider_height_span_m = 0 then null
    else (lower_level_t_k-upper_level_t_k)/provider_height_span_m*1000.0
  end as environmental_lapse_rate_k_per_km,
  false::boolean as canonical_identity_authority
from grouped;

create or replace view ecology.ssr_air_statistical_anomaly_scores as
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
    nullif(variables->>'omega','')::double precision as omega,
    sqrt(power(nullif(variables->>'u','')::double precision,2)+power(nullif(variables->>'v','')::double precision,2)) as wind_speed_mps
  from ecology.ssr_air_4d_samples
  where quality_gate in ('PASS_MERRA2_MULTI_VARIABLE','PASS_GEOS_CF_MULTI_VARIABLE')
), stats as (
  select
    provider_code,
    dataset_name,
    grid_latitude,
    grid_longitude,
    pressure_level_hpa,
    count(*) as sample_count,
    avg(t) as mean_t,
    stddev_samp(t) as sd_t,
    avg(rh) as mean_rh,
    stddev_samp(rh) as sd_rh,
    avg(wind_speed_mps) as mean_wind,
    stddev_samp(wind_speed_mps) as sd_wind,
    avg(omega) as mean_omega,
    stddev_samp(omega) as sd_omega
  from base
  group by provider_code,dataset_name,grid_latitude,grid_longitude,pressure_level_hpa
), scored as (
  select
    b.*,
    s.sample_count,
    case when s.sd_t is null or s.sd_t=0 then null else (b.t-s.mean_t)/s.sd_t end as z_t,
    case when s.sd_rh is null or s.sd_rh=0 then null else (b.rh-s.mean_rh)/s.sd_rh end as z_rh,
    case when s.sd_wind is null or s.sd_wind=0 then null else (b.wind_speed_mps-s.mean_wind)/s.sd_wind end as z_wind,
    case when s.sd_omega is null or s.sd_omega=0 then null else (b.omega-s.mean_omega)/s.sd_omega end as z_omega
  from base b
  join stats s using(provider_code,dataset_name,grid_latitude,grid_longitude,pressure_level_hpa)
)
select
  scored.*,
  greatest(abs(coalesce(z_t,0)),abs(coalesce(z_rh,0)),abs(coalesce(z_wind,0)),abs(coalesce(z_omega,0))) as max_abs_z,
  case
    when sample_count < 8 then 'INSUFFICIENT_BASELINE'
    when greatest(abs(coalesce(z_t,0)),abs(coalesce(z_rh,0)),abs(coalesce(z_wind,0)),abs(coalesce(z_omega,0))) >= 3 then 'HIGH_STATISTICAL_DEVIATION'
    when greatest(abs(coalesce(z_t,0)),abs(coalesce(z_rh,0)),abs(coalesce(z_wind,0)),abs(coalesce(z_omega,0))) >= 2 then 'ELEVATED_STATISTICAL_DEVIATION'
    else 'BASELINE_RANGE'
  end as statistical_classification,
  false::boolean as canonical_identity_authority
from scored;

create or replace view ecology.ssr_air_operational_change_signals as
select
  d.profile_id,
  d.provider_code,
  d.dataset_name,
  d.evidence_time,
  d.previous_evidence_time,
  d.grid_latitude,
  d.grid_longitude,
  d.pressure_level_hpa,
  d.candidate_ssr_z_index,
  d.interval_hours,
  d.t,
  d.u,
  d.v,
  d.rh,
  d.h,
  d.omega,
  d.delta_t,
  d.delta_u,
  d.delta_v,
  d.delta_rh,
  d.delta_h,
  d.delta_omega,
  d.delta_candidate_ssr_z,
  d.wind_vector_change_mps,
  d.temperature_change_k_per_hour,
  d.rh_change_per_hour,
  d.provider_height_change_m_per_hour,
  a.sample_count,
  a.z_t,
  a.z_rh,
  a.z_wind,
  a.z_omega,
  a.max_abs_z,
  a.statistical_classification,
  array_remove(array[
    case when abs(d.temperature_change_k_per_hour) >= 0.75 then 'RAPID_TEMPERATURE_CHANGE' end,
    case when d.wind_vector_change_mps >= 4.0 then 'RAPID_WIND_VECTOR_CHANGE' end,
    case when abs(d.rh_change_per_hour) >= 0.08 then 'RAPID_HUMIDITY_CHANGE' end,
    case when abs(d.delta_omega) >= 0.15 then 'VERTICAL_MOTION_CHANGE' end,
    case when a.max_abs_z >= 2.0 and a.sample_count >= 8 then 'MULTIVARIATE_STATISTICAL_DEVIATION' end
  ],null) as signal_flags,
  case
    when a.sample_count >= 8 and a.max_abs_z >= 3 then 'HIGH'
    when d.wind_vector_change_mps >= 6 or abs(d.temperature_change_k_per_hour) >= 1.25 then 'HIGH'
    when a.sample_count >= 8 and a.max_abs_z >= 2 then 'ELEVATED'
    when d.wind_vector_change_mps >= 4 or abs(d.temperature_change_k_per_hour) >= 0.75 or abs(d.rh_change_per_hour) >= 0.08 then 'ELEVATED'
    else 'BASELINE'
  end as operational_intensity,
  false::boolean as meteorological_warning_authority,
  d.canonical_identity_authority
from ecology.ssr_air_temporal_deltas d
left join ecology.ssr_air_statistical_anomaly_scores a
  on a.profile_id=d.profile_id and a.pressure_level_hpa=d.pressure_level_hpa;

create or replace view ecology.ssr_air_daily_trajectory_summary as
select
  m.provider_code,
  m.evidence_time::date as evidence_date,
  count(*) as profile_count,
  min(m.evidence_time) as first_profile_time,
  max(m.evidence_time) as last_profile_time,
  avg(m.column_mean_t_k) as daily_mean_column_t_k,
  avg(m.column_mean_rh) as daily_mean_column_rh,
  max(m.max_wind_speed_mps) as daily_max_wind_speed_mps,
  avg(m.environmental_lapse_rate_k_per_km) as daily_mean_lapse_rate_k_per_km,
  max(m.provider_height_span_m) as max_provider_height_span_m,
  c.completeness_status,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_profile_trajectory_metrics m
left join ecology.ssr_air_daily_completeness c
  on c.provider_code=m.provider_code and c.evidence_date=m.evidence_time::date
group by m.provider_code,m.evidence_time::date,c.completeness_status;

create or replace view ecology.ssr_air_analytics_operational_status as
select
  p.provider_code,
  count(distinct p.profile_id) as profile_count,
  min(p.evidence_time) as earliest_profile_time,
  max(p.evidence_time) as latest_profile_time,
  count(*) filter (where s.operational_intensity='HIGH') as high_signal_count,
  count(*) filter (where s.operational_intensity='ELEVATED') as elevated_signal_count,
  count(*) filter (where s.operational_intensity='BASELINE') as baseline_signal_count,
  bool_and(p.canonical_identity_authority=false) as identity_boundary_preserved
from ecology.ssr_air_profile_trajectory_metrics p
left join ecology.ssr_air_operational_change_signals s on s.profile_id=p.profile_id
group by p.provider_code;

comment on view ecology.ssr_air_operational_change_signals is 'Operational analytical signals only. Not an official meteorological warning product and never canonical SSR identity authority.';
