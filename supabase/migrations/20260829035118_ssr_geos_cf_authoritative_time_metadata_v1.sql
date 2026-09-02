update ecology.ssr_geos_cf_observations
set retrieval_metadata = retrieval_metadata || jsonb_build_object(
  'time_units_authority','NASA NCCS GEOS-CF GrADS Data Server metadata',
  'time_units','days since 1-1-1 00:00:0.0',
  'time_step','60mn',
  'time_metadata_verified',true,
  'time_metadata_verified_at',now()
)
where provider_code='NASA-GEOS-CF'
  and retrieval_metadata->>'time_quality_gate'='PASS_TIME_PLAUSIBILITY';

update ecology.ssr_scientific_data_providers
set integration_status='air_evidence_time_and_persistence_validated',
    notes='GEOS-CF v2 public NASA NCCS GrADS/OPeNDAP extraction validated over Jamaica with T/U/V/RH/H/OMEGA scientific gating and controlled persistence. NASA NCCS dataset metadata explicitly defines time units as days since 1-1-1 00:00:0.0 with 60-minute steps, validating the resolver UTC conversion. GEOS-CF remains dynamic AIR evidence only; pressure coordinates do not define SSR Z and do not alter canonical SSR identity.',
    canonical_z_authority=false,
    updated_at=now()
where provider_code='NASA-GEOS-CF';

create or replace view ecology.ssr_air_evidence_status as
select 'NASA-MERRA2'::text provider_code,
       count(*)::bigint observation_count,
       max(retrieved_at) latest_retrieval,
       max(observed_at) latest_evidence_time,
       bool_and(z_index is null and canonical_cube_address is null) identity_boundary_intact
from ecology.ssr_air_observations
union all
select 'NASA-GEOS-CF'::text,
       count(*)::bigint,
       max(retrieved_at),
       max(observed_at),
       bool_and(z_index is null and canonical_cube_address is null)
from ecology.ssr_geos_cf_observations;
