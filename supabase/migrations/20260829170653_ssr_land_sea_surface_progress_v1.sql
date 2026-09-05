update ecology.ssr_scientific_data_providers
set integration_status='operational_point_elevation_and_canonicalization_validated',
    notes=coalesce(notes,'') || case when coalesce(notes,'')='' then '' else E'\n' end ||
      'OpenTopography point elevation resolver is active. EGM96-compatible point evidence and deterministic 3 m Z assignment have been validated for Jamaica reference anchors; full anchor coverage remains incomplete.',
    updated_at=now()
where provider_code='OT-POINT';

update ecology.ssr_scientific_data_providers
set integration_status='point_extraction_validated_egm96_port_kingston',
    notes=coalesce(notes,'') || case when coalesce(notes,'')='' then '' else E'\n' end ||
      'SRTM15Plus point extraction validated at the Port of Kingston reference coordinate with EPSG:5773 EGM96 metadata, +3 m elevation and candidate Z+0001. W3W/coastline/provenance promotion controls remain.',
    updated_at=now()
where provider_code='OT-SRTM15PLUS';

update ecology.ssr_scientific_data_providers
set integration_status='point_extraction_validated_msl_coastline_reconciliation_required',
    notes=coalesce(notes,'') || case when coalesce(notes,'')='' then '' else E'\n' end ||
      'GEBCO_2026 point extraction validated near Port of Kingston at -12 m relative to documented mean-sea-level reference. Grid-cell/coastline and vertical-reference reconciliation remain required before canonical SSR Z.',
    updated_at=now()
where provider_code='GEBCO-SOURCE';

update ecology.ssr_scientific_data_providers
set integration_status='surface_currents_and_sst_point_validated_temporal_alignment_pending',
    notes=coalesce(notes,'') || case when coalesce(notes,'')='' then '' else E'\n' end ||
      'NOAA ERDDAP point extraction validated for blended daily surface currents and sea-surface temperature near Kingston. Available observations lag the AIR event by 74-86 hours; salinity and sea-level evidence are not yet validated.',
    updated_at=now()
where provider_code='NOAA-ERDDAP';

update ecology.ssr_air_cross_domain_validations v
set evidence_snapshot=coalesce(v.evidence_snapshot,'{}'::jsonb) || jsonb_build_object(
      'provider_status',(select integration_status from ecology.ssr_scientific_data_providers p where p.provider_code=v.provider_code),
      'progress_refreshed_at',now()
    ),
    updated_at=now()
where v.provider_code in ('OT-SRTM15PLUS','GEBCO-SOURCE','NOAA-ERDDAP','COP-MARINE');

create or replace view ecology.ssr_land_sea_surface_progress as
with jm as (
  select
    count(*)::integer as total_anchors,
    count(*) filter(where elevation_m_egm96 is not null and z_index is not null)::integer as elevation_z_complete,
    count(*) filter(where canonical_address is not null)::integer as canonical_address_complete,
    count(*) filter(where promotion_eligible)::integer as promoted_complete
  from ecology.ssr_anchor_candidate_registry
  where jurisdiction_code='JM'
), sea_static as (
  select
    count(*) filter(where provider_code='OT-SRTM15PLUS' and validation_status='evidence_available')::integer as srtm15plus_ready,
    count(*) filter(where provider_code='GEBCO-SOURCE' and validation_status='evidence_available')::integer as gebco_ready,
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
       case when sea_static.srtm15plus_ready>0 and sea_static.gebco_ready>0 then 'POINT_EVIDENCE_VALIDATED_RECONCILIATION_PENDING' else 'PARTIAL' end,
       true,false,least(sea_static.srtm15plus_ready,1)+least(sea_static.gebco_ready,1),2,
       case when sea_static.reconciliation_required>0 then 'SRTM15Plus EGM96 exact-point elevation and GEBCO MSL nearby-grid evidence differ across coastline/grid/datum semantics; reconciliation remains required.' else null end,
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

comment on view ecology.ssr_land_sea_surface_progress is 'Evidence-based LAND and SEA surface progress. Engine readiness, point validation, coverage completeness and dynamic-event alignment are reported separately to prevent false completion claims.';
comment on view ecology.ssr_land_sea_surface_summary is 'Domain-level summary. COMPLETE requires every declared component gate to be satisfied; operational point proofs do not imply global or event-aligned coverage.';
