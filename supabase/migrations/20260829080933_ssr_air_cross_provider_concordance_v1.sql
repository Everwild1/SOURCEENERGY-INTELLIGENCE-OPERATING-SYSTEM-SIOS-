alter table ecology.ssr_air_pressure_to_z_mapping
  add column if not exists source_height_semantics text,
  add column if not exists source_vertical_datum text,
  add column if not exists canonical_identity_authority boolean not null default false;

alter table ecology.ssr_air_pressure_to_z_mapping
  drop constraint if exists ssr_air_mapping_no_canonical_authority;
alter table ecology.ssr_air_pressure_to_z_mapping
  add constraint ssr_air_mapping_no_canonical_authority check (canonical_identity_authority = false);

update ecology.ssr_air_pressure_to_z_mapping
set derived_geometric_height_m = null,
    source_height_semantics = case provider_code
      when 'NASA-MERRA2' then 'provider_native_geopotential_height_H'
      when 'NASA-GEOS-CF' then 'provider_native_GEOS_CF_H'
      else coalesce(source_height_semantics,'provider_native_height') end,
    source_vertical_datum = coalesce(source_vertical_datum,'not_established_as_EGM96'),
    canonical_identity_authority = false,
    mapping_metadata = coalesce(mapping_metadata,'{}'::jsonb) || jsonb_build_object(
      'height_semantics_hardened',true,
      'derived_geometric_height_withheld',true,
      'vertical_datum_status','not_established_as_EGM96',
      'canonical_identity_authority',false
    )
where provider_code in ('NASA-MERRA2','NASA-GEOS-CF');

comment on column ecology.ssr_air_pressure_to_z_mapping.geopotential_height_m is
'Provider-native H evidence. It is not, by itself, an EGM96 orthometric or geometric height.';
comment on column ecology.ssr_air_pressure_to_z_mapping.derived_geometric_height_m is
'Populate only after an explicit validated conversion from provider-native height semantics. Do not copy provider-native H into this field.';
comment on column ecology.ssr_air_pressure_to_z_mapping.candidate_ssr_z_index is
'Scientific association only. Never canonical SSR identity or canonical EGM96 Z.';

create or replace view ecology.ssr_air_cross_provider_concordance as
with m as (
  select evidence_time, grid_latitude, grid_longitude, pressure_level_hpa,
         geopotential_height_m as merra2_h_m, candidate_ssr_z_index as merra2_candidate_z
  from ecology.ssr_air_pressure_to_z_mapping where provider_code='NASA-MERRA2'
), g as (
  select evidence_time, grid_latitude, grid_longitude, pressure_level_hpa,
         geopotential_height_m as geos_cf_h_m, candidate_ssr_z_index as geos_cf_candidate_z
  from ecology.ssr_air_pressure_to_z_mapping where provider_code='NASA-GEOS-CF'
)
select m.pressure_level_hpa,
       m.evidence_time as merra2_time,
       g.evidence_time as geos_cf_time,
       m.merra2_h_m, g.geos_cf_h_m,
       case when g.geos_cf_h_m is null then null else m.merra2_h_m-g.geos_cf_h_m end as height_difference_m,
       m.merra2_candidate_z, g.geos_cf_candidate_z,
       case when g.geos_cf_candidate_z is null then null else m.merra2_candidate_z-g.geos_cf_candidate_z end as candidate_z_difference,
       case when g.pressure_level_hpa is null then 'NO_MATCHED_PRESSURE_LEVEL' else 'MATCHED_PRESSURE_LEVEL_DIFFERENT_EVIDENCE_TIME' end as concordance_status,
       false::boolean as canonical_identity_authority
from m left join g using (pressure_level_hpa);

create or replace view ecology.ssr_air_evidence_operational_status as
select provider_code,
       count(*) as mapping_count,
       min(evidence_time) as earliest_evidence_time,
       max(evidence_time) as latest_evidence_time,
       count(*) filter (where derived_geometric_height_m is null) as mappings_with_geometric_height_withheld,
       bool_and(canonical_identity_authority = false) as identity_boundary_preserved
from ecology.ssr_air_pressure_to_z_mapping
where provider_code in ('NASA-MERRA2','NASA-GEOS-CF')
group by provider_code;
