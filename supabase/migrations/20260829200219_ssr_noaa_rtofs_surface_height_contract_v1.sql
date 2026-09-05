create or replace function public.ssr_noaa_rtofs_job_record_result(
  p_job_id uuid,
  p_lease_token uuid,
  p_worker_id text,
  p_result jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to public, ecology, pg_temp
as $$
declare
  v_job ecology.ssr_sea_validation_jobs%rowtype;
  v_obs jsonb;
  v_obs_id uuid;
  v_ids uuid[] := '{}'::uuid[];
  v_ok boolean := coalesce((p_result->>'ok')::boolean,false);
  v_gate text := p_result->>'quality_gate';
  v_alignment text := coalesce(p_result->>'event_alignment_gate','FAIL_EVENT_ALIGNMENT');
  v_status text;
  v_error text;
  v_has_ssh boolean := coalesce((p_result->'variables') ? 'sea_surface_height_relative_to_geoid_m',false)
    or coalesce((p_result->'surface_height') ? 'value_m',false);
begin
  select * into v_job
  from ecology.ssr_sea_validation_jobs
  where id=p_job_id
  for update;

  if not found then raise exception 'job not found'; end if;
  if v_job.provider_code<>'NOAA-RTOFS' then raise exception 'job provider mismatch'; end if;
  if v_job.lease_token is distinct from p_lease_token or v_job.worker_id is distinct from p_worker_id then
    raise exception 'lease token or worker mismatch';
  end if;

  if not v_ok or v_gate not in ('PASS_NOAA_RTOFS_POINT_FORECAST','PASS_NOAA_RTOFS_EVENT_ALIGNED_SURFACE_STATE') then
    v_error:=coalesce(p_result->>'error',p_result->>'detail','RTOFS worker result failed quality gate');
    update ecology.ssr_sea_validation_jobs
    set job_status='failed',last_error=v_error,result_summary=coalesce(p_result,'{}'::jsonb),
        result_quality_gate=v_gate,lease_token=null,leased_until=null,dispatch_token_hash=null,
        dispatch_expires_at=null,updated_at=now()
    where id=p_job_id;
    return jsonb_build_object('job_id',p_job_id,'job_status','failed','error',v_error,'observation_ids',v_ids);
  end if;

  if jsonb_typeof(coalesce(p_result->'observations','[]'::jsonb))<>'array' then
    raise exception 'observations must be a JSON array';
  end if;

  for v_obs in select value from jsonb_array_elements(coalesce(p_result->'observations','[]'::jsonb))
  loop
    v_obs:=v_obs||jsonb_build_object('provider_code','NOAA-RTOFS','event_time_reference',v_job.request_payload->>'event_time');
    v_obs_id:=public.persist_ssr_sea_observation(v_obs);
    v_ids:=array_append(v_ids,v_obs_id);
  end loop;

  if cardinality(v_ids)=0 then raise exception 'successful result contained no observations'; end if;
  v_status:=case when v_alignment='PASS_EVENT_ALIGNMENT' then 'evidence_available' else 'insufficient' end;

  update ecology.ssr_air_cross_domain_validations
  set validation_status=v_status,
      evidence_reference=coalesce(p_result->>'evidence_reference',evidence_reference),
      evidence_snapshot=coalesce(evidence_snapshot,'{}'::jsonb)||coalesce(p_result,'{}'::jsonb),
      review_conclusion=case
        when v_alignment='PASS_EVENT_ALIGNMENT' and v_has_ssh then
          'Event-aligned NOAA RTOFS surface-state evidence acquired for currents, sea-surface temperature, salinity and sea-surface height relative to geoid. Human operational-relevance review remains required.'
        when v_alignment='PASS_EVENT_ALIGNMENT' then
          'Event-aligned NOAA RTOFS surface prognostic evidence acquired for currents, SST and salinity. Sea-surface height and human relevance review remain open.'
        else
          'NOAA RTOFS evidence acquired but did not satisfy the governed event-time alignment gate.'
      end,
      impact_conclusion='NOT_ASSESSED',reviewer='NOAA_RTOFS_POINT_WORKER',reviewed_at=now(),
      physical_impact_asserted=false,external_action_authority=false,official_warning_authority=false,
      canonical_identity_authority=false,updated_at=now()
  where event_id=v_job.event_id and exposure_candidate_id=v_job.exposure_candidate_id
    and provider_code='NOAA-RTOFS' and validation_type='EVENT_ALIGNED_SURFACE_PROGNOSTIC_REVIEW';

  update ecology.ssr_sea_validation_jobs
  set job_status='completed',output_observation_ids=v_ids,result_summary=coalesce(p_result,'{}'::jsonb),
      result_quality_gate=v_gate,callback_reference=p_result->>'callback_reference',completed_at=now(),
      lease_token=null,leased_until=null,last_error=null,dispatch_token_hash=null,dispatch_expires_at=null,updated_at=now()
  where id=p_job_id;

  update ecology.ssr_scientific_data_providers
  set integration_status=case
        when v_alignment='PASS_EVENT_ALIGNMENT' and v_has_ssh then 'event_aligned_surface_state_with_ssh_validated'
        when v_alignment='PASS_EVENT_ALIGNMENT' then 'event_aligned_surface_prognostic_point_validated'
        else 'surface_prognostic_point_validated_alignment_insufficient'
      end,
      notes=case
        when v_has_ssh and position('SSHG point forecast passed' in coalesce(notes,''))=0 then
          coalesce(notes,'')||case when coalesce(notes,'')='' then '' else E'\n' end||
          'NOAA RTOFS event-aligned point validation completed for currents, SST, salinity and SSHG. SSHG is retained as dynamic environmental evidence relative to geoid and does not redefine canonical SSR elevation or Z.'
        when not v_has_ssh and position('RTOFS point forecast worker completed' in coalesce(notes,''))=0 then
          coalesce(notes,'')||case when coalesce(notes,'')='' then '' else E'\n' end||
          'NOAA RTOFS point forecast worker completed. Currents, SST and salinity passed scientific gates; sea-surface elevation remains outside this result.'
        else notes
      end,
      updated_at=now()
  where provider_code='NOAA-RTOFS';

  return jsonb_build_object(
    'job_id',p_job_id,'job_status','completed','quality_gate',v_gate,
    'event_alignment_gate',v_alignment,'surface_height_included',v_has_ssh,
    'observation_ids',v_ids,'physical_impact_asserted',false,
    'official_warning_authority',false,'canonical_identity_authority',false
  );
end $$;

create or replace function public.ssr_noaa_rtofs_dispatch(
  p_event_id uuid,
  p_exposure_candidate_id uuid,
  p_event_time timestamptz,
  p_latitude double precision,
  p_longitude double precision
)
returns jsonb
language plpgsql
security definer
set search_path to public, ecology, extensions, net, pg_temp
as $$
declare
  v_token text;
  v_hash text;
  v_job_id uuid;
  v_request_id bigint;
begin
  if not exists(select 1 from ecology.ssr_air_events where id=p_event_id) then raise exception 'event not found'; end if;
  if not exists(select 1 from ecology.ssr_air_event_exposure_candidates where id=p_exposure_candidate_id and event_id=p_event_id) then
    raise exception 'exposure candidate not found for event';
  end if;

  v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
  v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');

  insert into ecology.ssr_sea_validation_jobs(
    event_id,exposure_candidate_id,provider_code,job_type,job_status,priority,requested_at,due_at,
    request_payload,result_summary,attempts,dispatch_token_hash,dispatch_expires_at,
    external_action_performed,physical_impact_asserted,official_warning_authority,canonical_identity_authority
  ) values (
    p_event_id,p_exposure_candidate_id,'NOAA-RTOFS','EVENT_ALIGNED_SURFACE_PROGNOSTIC','queued','critical',now(),
    p_event_time+interval '2 hours',
    jsonb_build_object(
      'event_time',p_event_time,'latitude',p_latitude,'longitude',p_longitude,
      'surface_state_sources',array['CARICOOS_RTOFS_2D_THREDDS','NOAA_NOMADS_RTOFS_REGIONAL_GRIB2'],
      'variables',array['sst','sss','u_velocity','v_velocity','sshg'],
      'nearest_marine_grid_search',true,'max_temporal_lag_hours',3.1,'max_spatial_distance_km',30
    ),'{}'::jsonb,0,v_hash,now()+interval '30 minutes',false,false,false,false
  )
  on conflict(event_id,exposure_candidate_id,provider_code,job_type) do update set
    job_status='queued',priority='critical',requested_at=now(),due_at=excluded.due_at,
    request_payload=excluded.request_payload,result_summary='{}'::jsonb,last_error=null,
    dispatch_token_hash=v_hash,dispatch_expires_at=now()+interval '30 minutes',
    lease_token=null,leased_until=null,worker_id=null,completed_at=null,output_observation_ids='{}'::uuid[],
    result_quality_gate=null,callback_reference=null,updated_at=now()
  returning id into v_job_id;

  v_request_id:=net.http_post(
    url:='https://veopccdltsklczlmdbri.supabase.co/functions/v1/ssr-noaa-rtofs-point-worker',
    body:=jsonb_build_object('job_id',v_job_id,'job_token',v_token,'worker_id','NOAA_RTOFS_PG_NET'),
    params:='{}'::jsonb,
    headers:=jsonb_build_object('Content-Type','application/json'),
    timeout_milliseconds:=150000
  );

  update ecology.ssr_sea_validation_jobs
  set network_request_id=v_request_id,
      result_summary=jsonb_build_object('dispatch_method','pg_net','network_request_id',v_request_id),updated_at=now()
  where id=v_job_id;

  return jsonb_build_object('job_id',v_job_id,'network_request_id',v_request_id,'job_status','queued',
    'dispatch_method','pg_net_after_commit','requested_variables',array['sst','sss','u_velocity','v_velocity','sshg'],
    'physical_impact_asserted',false,'official_warning_authority',false,
    'canonical_identity_authority',false);
end $$;

revoke all on function public.ssr_noaa_rtofs_job_record_result(uuid,uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.ssr_noaa_rtofs_dispatch(uuid,uuid,timestamptz,double precision,double precision) from public,anon,authenticated;
grant execute on function public.ssr_noaa_rtofs_job_record_result(uuid,uuid,text,jsonb) to service_role;
grant execute on function public.ssr_noaa_rtofs_dispatch(uuid,uuid,timestamptz,double precision,double precision) to service_role;
