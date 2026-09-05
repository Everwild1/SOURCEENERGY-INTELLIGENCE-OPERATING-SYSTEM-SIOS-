update ecology.ssr_scientific_data_providers
set integration_status='point_extraction_and_coastline_reconciliation_validated_port_kingston',
    notes=coalesce(notes,'') || case when coalesce(notes,'')='' then '' else E'\n' end ||
      'Port of Kingston exact-point SRTM15Plus EPSG:5773 EGM96 evidence reconciled against the nearby GEBCO MSL grid sample as distinct spatial footprints separated by approximately 319.7 m. Exact-point SRTM15Plus governs the canonical surface anchor; GEBCO remains non-canonical marine context.',
    updated_at=now()
where provider_code='OT-SRTM15PLUS';

update ecology.ssr_scientific_data_providers
set integration_status='point_extraction_validated_contextual_grid_reconciled_port_kingston',
    notes=coalesce(notes,'') || case when coalesce(notes,'')='' then '' else E'\n' end ||
      'GEBCO_2026 nearby grid-cell evidence at Port of Kingston has been reconciled as marine/bathymetric context, not a co-located canonical anchor measurement. Mean-sea-level semantics and non-canonical authority remain preserved.',
    updated_at=now()
where provider_code='GEBCO-SOURCE';

create or replace view ecology.ssr_land_sea_surface_progress as
with jm as (
  select
    count(*)::integer as total_anchors,
    count(*) filter(where elevation_m_egm96 is not null and z_index is not null)::integer as elevation_z_complete,
    count(*) filter(where canonical_address is not null)::integer as canonical_address_complete,
    count(*) filter(where promotion_eligible and canonicalization_status='promoted')::integer as promoted_complete
  from ecology.ssr_anchor_candidate_registry
  where jurisdiction_code='JM'
), sea_static as (
  select
    count(*) filter(where provider_code='OT-SRTM15PLUS' and validation_status='evidence_available')::integer as srtm15plus_ready,
    count(*) filter(where provider_code='GEBCO-SOURCE' and validation_status='evidence_available')::integer as gebco_ready,
    count(*) filter(where validation_type='COASTLINE_GRID_AND_DATUM_RECONCILIATION' and validation_status='validated')::integer as reconciliation_validated,
    count(*) filter(where validation_type='COASTLINE_GRID_AND_DATUM_RECONCILIATION' and validation_status='required')::integer as reconciliation_required
  from ecology.ssr_air_cross_domain_validations v
  join ecology.ssr_air_event_exposure_candidates x on x.id=v.exposure_candidate_id
  where x.subject_name ilike 'Port of Kingston%'
), noaa as (
  select
    count(distinct dataset_id)::integer as validated_datasets,
    bool_or(retrieval_metadata->>'event_alignment_gate'='INSUFFICIENT_TEMPORAL_ALIGNMENT') as alignment_pending
  from ecology.ssr_sea_observations
  where provider_code='NOAA-ERDDAP' and quality_gate='PASS_SEA_OBSERVATIONAL_VALUE'
), cop as (
  select
    count(*)::integer as total_jobs,
    count(*) filter(where job_status='completed')::integer as completed_jobs,
    count(*) filter(where job_status='blocked')::integer as blocked_jobs,
    max(blocker_reason) filter(where job_status='blocked') as blocker_reason
  from ecology.ssr_sea_validation_jobs
  where provider_code='COP-MARINE'
)
select 'LAND_POINT_ELEVATION_ENGINE'::text component_code,'LAND'::text domain,
       'Point elevation resolver and EGM96/Z quantization workflow'::text scope,
       'OPERATIONAL'::text progress_state,true operational,true complete_for_declared_scope,
       (select elevation_z_complete from jm) completed_units,(select total_anchors from jm) total_units,
       'Coverage completion is tracked separately from engine readiness.'::text blocker,
       false::boolean physical_impact_authority,true::boolean canonical_z_authority
union all
select 'LAND_JAMAICA_ANCHOR_COVERAGE','LAND','Current Jamaica reference-anchor canonicalization',
       case when jm.promoted_complete=jm.total_anchors and jm.total_anchors>0 then 'COMPLETE' else 'PARTIAL' end,
       true,(jm.promoted_complete=jm.total_anchors and jm.total_anchors>0),jm.promoted_complete,jm.total_anchors,
       case when jm.promoted_complete=jm.total_anchors and jm.total_anchors>0 then null else
         'Only fully promoted anchors count as complete; W3W, EGM96, source reconciliation, provenance/hash and promotion controls are still pending for remaining anchors.' end,
       false,true from jm
union all
select 'LAND_EGM96_Z_COVERAGE','LAND','EGM96 elevation plus deterministic 3 m Z across current Jamaica anchors',
       case when jm.elevation_z_complete=jm.total_anchors and jm.total_anchors>0 then 'COMPLETE' else 'PARTIAL' end,
       true,(jm.elevation_z_complete=jm.total_anchors and jm.total_anchors>0),jm.elevation_z_complete,jm.total_anchors,
       case when jm.elevation_z_complete=jm.total_anchors and jm.total_anchors>0 then null else 'Authoritative EGM96 elevation/Z remains missing for at least one current anchor.' end,
       false,true from jm
union all
select 'SEA_STATIC_PORT_POINT_GEOMETRY','SEA','Port of Kingston static coastal/seabed point evidence',
       case when sea_static.srtm15plus_ready>0 and sea_static.gebco_ready>0 and sea_static.reconciliation_validated>0
              then 'COMPLETE_POINT_GEOMETRY_RECONCILED'
            when sea_static.srtm15plus_ready>0 and sea_static.gebco_ready>0
              then 'POINT_EVIDENCE_VALIDATED_RECONCILIATION_PENDING'
            else 'PARTIAL' end,
       (sea_static.srtm15plus_ready>0 or sea_static.gebco_ready>0),
       (sea_static.srtm15plus_ready>0 and sea_static.gebco_ready>0 and sea_static.reconciliation_validated>0),
       least(sea_static.srtm15plus_ready,1)+least(sea_static.gebco_ready,1)+least(sea_static.reconciliation_validated,1),3,
       case when sea_static.reconciliation_validated>0 then null
            when sea_static.reconciliation_required>0 then 'SRTM15Plus EGM96 exact-point elevation and GEBCO MSL nearby-grid evidence require coastline/grid/datum reconciliation.'
            else 'Static point evidence or reconciliation remains incomplete.' end,
       false,false from sea_static
union all
select 'SEA_SURFACE_OBSERVATIONAL_POINT','SEA','NOAA point observations near Kingston: surface current vector and SST',
       case when noaa.validated_datasets>=2 and noaa.alignment_pending then 'POINT_VALIDATED_TEMPORAL_ALIGNMENT_PENDING'
            when noaa.validated_datasets>=2 then 'POINT_VALIDATED' else 'PARTIAL' end,
       (noaa.validated_datasets>0),false,noaa.validated_datasets,4,
       'Currents and SST are validated. Event-aligned evidence, salinity and sea-level/height remain incomplete.',
       false,false from noaa
union all
select 'SEA_EVENT_ALIGNED_DYNAMIC_STATE','SEA','Event-aligned dynamic ocean analysis/forecast via Copernicus Marine',
       case when cop.total_jobs>0 and cop.completed_jobs=cop.total_jobs then 'COMPLETE'
            when cop.blocked_jobs>0 then 'BLOCKED' else 'NOT_STARTED' end,
       false,(cop.total_jobs>0 and cop.completed_jobs=cop.total_jobs),cop.completed_jobs,greatest(cop.total_jobs,1),
       coalesce(cop.blocker_reason,'Copernicus Marine Toolbox runtime and credentials are required.'),
       false,false from cop;

create or replace view ecology.ssr_land_sea_surface_summary as
select
  domain,
  count(*)::integer as component_count,
  count(*) filter(where operational)::integer as operational_components,
  count(*) filter(where complete_for_declared_scope)::integer as completed_components,
  bool_and(complete_for_declared_scope) as domain_complete,
  case
    when bool_and(complete_for_declared_scope) then 'COMPLETE'
    when bool_or(operational) then 'OPERATIONAL_WITH_OPEN_GATES'
    else 'BLOCKED_OR_NOT_STARTED'
  end as domain_state,
  array_agg(component_code order by component_code) filter(where not complete_for_declared_scope) as open_components,
  false::boolean physical_impact_authority,
  false::boolean official_warning_authority
from ecology.ssr_land_sea_surface_progress
group by domain;
