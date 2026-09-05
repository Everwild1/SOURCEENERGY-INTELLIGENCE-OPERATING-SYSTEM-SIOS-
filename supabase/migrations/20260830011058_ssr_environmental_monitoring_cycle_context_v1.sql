create or replace function public.ssr_environmental_monitoring_context(p_watchlist_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_result jsonb;
begin
  if not exists(select 1 from ecology.ssr_environmental_monitoring_watchlist where id=p_watchlist_id) then
    raise exception 'monitoring watchlist not found';
  end if;

  select jsonb_build_object(
    'watchlist',to_jsonb(w),
    'event',jsonb_build_object(
      'id',e.id,'event_type',e.event_type,'severity',e.severity,'lifecycle_status',e.lifecycle_status,
      'event_time',e.event_time,'detected_at',e.detected_at,'provider_code',e.provider_code,
      'dataset_name',e.dataset_name,'grid_latitude',e.grid_latitude,'grid_longitude',e.grid_longitude,
      'pressure_level_hpa',e.pressure_level_hpa,'signal_flags',e.signal_flags,
      'source_profile_id',e.source_profile_id
    ),
    'subject',jsonb_build_object(
      'exposure_candidate_id',x.id,'subject_reference',x.subject_reference,'subject_name',x.subject_name,
      'subject_type',x.subject_type,'association_method',x.association_method,
      'latitude',a.latitude,'longitude',a.longitude,'infrastructure_type',a.infrastructure_type
    ),
    'land',case when a.id is null then null else jsonb_build_object(
      'anchor_id',a.id,'w3w_address',a.w3w_address,'elevation_m_egm96',a.elevation_m_egm96,
      'z_index',a.z_index,'canonical_address',a.canonical_address,'cube_uid',a.cube_uid,
      'canonicalization_status',a.canonicalization_status,'promotion_eligible',a.promotion_eligible,
      'source_verification_status',a.source_verification_status,
      'source_reconciliation_status',a.source_reconciliation_status
    ) end,
    'fusion_baseline',f.evidence_bundle,
    'previous_run',coalesce((
      select jsonb_build_object(
        'id',r.id,'run_type',r.run_type,'run_status',r.run_status,'scheduled_for',r.scheduled_for,
        'completed_at',r.completed_at,'result_summary',r.result_summary
      )
      from ecology.ssr_environmental_monitoring_runs r
      where r.watchlist_id=w.id
        and r.run_status='completed'
        and (
          r.run_type='baseline'
          or r.result_summary->>'monitoring_quality_gate'='PASS_GOVERNED_ENVIRONMENTAL_MONITORING_SNAPSHOT'
        )
      order by r.completed_at desc nulls last,r.created_at desc
      limit 1
    ),'{}'::jsonb),
    'sea_observations',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',o.id,'provider_code',o.provider_code,'dataset_id',o.dataset_id,
        'observed_at',o.observed_at,'event_time_reference',o.event_time_reference,
        'grid_latitude',o.grid_latitude,'grid_longitude',o.grid_longitude,
        'variables',o.variables,'units',o.units,'quality_gate',o.quality_gate,
        'retrieval_metadata',o.retrieval_metadata
      ) order by o.observed_at,o.dataset_id)
      from ecology.ssr_sea_observations o
      where o.event_time_reference=e.event_time
        and o.provider_code in ('NOAA-RTOFS','NOAA-ERDDAP')
    ),'[]'::jsonb),
    'rtofs_job',coalesce((
      select jsonb_build_object(
        'id',j.id,'job_status',j.job_status,'attempts',j.attempts,'completed_at',j.completed_at,
        'updated_at',j.updated_at,'quality_gate',j.result_quality_gate,'last_error',j.last_error,
        'result_summary',j.result_summary
      )
      from ecology.ssr_sea_validation_jobs j
      where j.event_id=w.event_id and j.exposure_candidate_id=w.exposure_candidate_id
        and j.provider_code='NOAA-RTOFS'
      order by j.updated_at desc
      limit 1
    ),'{}'::jsonb),
    'authority_boundary',jsonb_build_object(
      'physical_impact_asserted',false,'external_action_authority',false,
      'official_warning_authority',false,'canonical_identity_authority',false
    )
  ) into v_result
  from ecology.ssr_environmental_monitoring_watchlist w
  join ecology.ssr_air_events e on e.id=w.event_id
  join ecology.ssr_air_event_exposure_candidates x on x.id=w.exposure_candidate_id
  join ecology.ssr_air_land_sea_fusion_assessments f on f.id=w.fusion_assessment_id
  left join ecology.ssr_anchor_candidate_registry a
    on x.subject_type='SSR_ANCHOR_CANDIDATE' and x.subject_reference=a.id::text
  where w.id=p_watchlist_id;

  return v_result;
end $$;

comment on function public.ssr_environmental_monitoring_context(uuid) is 'Returns governed monitoring context and excludes partial or failed snapshots from the comparison baseline.';
