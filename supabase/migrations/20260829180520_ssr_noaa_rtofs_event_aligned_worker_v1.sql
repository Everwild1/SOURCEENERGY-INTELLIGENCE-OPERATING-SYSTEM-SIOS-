insert into ecology.ssr_scientific_data_providers(
  domain,provider_code,provider_name,service_name,role,temporal_class,integration_status,
  canonical_z_authority,authority_scope,notes,updated_at
) values (
  'SEA','NOAA-RTOFS','NOAA/NCEP','Global Real-Time Ocean Forecast System (RTOFS)',
  'Public event-aligned ocean forecast context: sea-surface temperature, salinity and water velocity',
  'near-real-time/forecast','worker_deployed_validation_pending',false,
  'SEA environmental forecast evidence only; not coordinate, physical-impact or official-warning authority',
  'Public NOAA RTOFS prognostic surface variables are accessed through the NOAA CoastWatch ERDDAP transformation layer. Sea-surface elevation remains a separate open gate.',now()
)
on conflict(provider_code) do update set
  domain=excluded.domain,provider_name=excluded.provider_name,service_name=excluded.service_name,
  role=excluded.role,temporal_class=excluded.temporal_class,integration_status=excluded.integration_status,
  canonical_z_authority=false,authority_scope=excluded.authority_scope,notes=excluded.notes,updated_at=now();

insert into ecology.ssr_sea_provider_access_requirements(
  provider_code,supported_access_method,runtime_requirement,credential_requirement,readiness_status,
  required_variables,provider_metadata,external_action_authority,official_warning_authority,canonical_identity_authority,updated_at
) values (
  'NOAA-RTOFS','NOAA CoastWatch ERDDAP griddap point subset','Supabase Edge Function / standards-based HTTPS fetch',
  'None for public NOAA ERDDAP access','ready',array['sst','sss','u_velocity','v_velocity']::text[],
  jsonb_build_object(
    'dataset_id','ncepRtofsG2DFore3hrlyProg_LonPM180',
    'source_model','NOAA/NCEP Global RTOFS',
    'access_role','public forecast subset',
    'sea_surface_elevation_included',false,
    'authority_boundary','environmental forecast evidence only'
  ),false,false,false,now()
)
on conflict(provider_code) do update set
  supported_access_method=excluded.supported_access_method,runtime_requirement=excluded.runtime_requirement,
  credential_requirement=excluded.credential_requirement,readiness_status='ready',required_variables=excluded.required_variables,
  provider_metadata=excluded.provider_metadata,external_action_authority=false,official_warning_authority=false,
  canonical_identity_authority=false,updated_at=now();

alter table ecology.ssr_sea_validation_jobs
  add column if not exists dispatch_token_hash text,
  add column if not exists dispatch_expires_at timestamptz,
  add column if not exists network_request_id bigint;

insert into ecology.ssr_air_cross_domain_validations(
  event_id,exposure_candidate_id,validation_domain,validation_type,provider_code,validation_status,
  evidence_snapshot,impact_conclusion,physical_impact_asserted,external_action_authority,
  official_warning_authority,canonical_identity_authority
)
select x.event_id,x.id,'SEA','EVENT_ALIGNED_SURFACE_PROGNOSTIC_REVIEW','NOAA-RTOFS','required',
       jsonb_build_object(
         'required_variables',array['sst','sss','u_velocity','v_velocity'],
         'dataset_id','ncepRtofsG2DFore3hrlyProg_LonPM180',
         'reason','Acquire event-aligned public NOAA RTOFS forecast context while Copernicus full-state validation remains blocked.',
         'sea_surface_elevation_gate','NOT_INCLUDED'
       ),'NOT_ASSESSED',false,false,false,false
from ecology.ssr_air_event_exposure_candidates x
where x.event_id='db232a8d-4d10-43ad-82af-53bc16d8c02c'::uuid
  and x.subject_name ilike 'Port of Kingston%'
on conflict(event_id,exposure_candidate_id,validation_domain,validation_type,provider_code) do nothing;

create or replace function public.ssr_noaa_rtofs_job_claim(
  p_job_id uuid,
  p_token_hash text,
  p_worker_id text,
  p_lease_seconds integer default 600
) returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare v ecology.ssr_sea_validation_jobs%rowtype; v_token uuid:=gen_random_uuid();
begin
  if p_worker_id is null or length(trim(p_worker_id))=0 then raise exception 'worker id required'; end if;
  if p_lease_seconds<60 or p_lease_seconds>1800 then raise exception 'lease seconds must be 60..1800'; end if;

  select * into v from ecology.ssr_sea_validation_jobs where id=p_job_id for update;
  if not found then raise exception 'job not found'; end if;
  if v.provider_code<>'NOAA-RTOFS' then raise exception 'job provider mismatch'; end if;
  if v.dispatch_token_hash is distinct from p_token_hash then raise exception 'invalid dispatch token'; end if;
  if v.dispatch_expires_at is null or v.dispatch_expires_at<=now() then raise exception 'dispatch token expired'; end if;
  if v.job_status not in ('queued','failed') then raise exception 'job is not claimable'; end if;

  update ecology.ssr_sea_validation_jobs
  set job_status='running',worker_id=p_worker_id,lease_token=v_token,leased_at=now(),
      leased_until=now()+make_interval(secs=>p_lease_seconds),started_at=coalesce(started_at,now()),
      attempts=attempts+1,last_error=null,updated_at=now()
  where id=p_job_id
  returning * into v;

  return jsonb_build_object(
    'job_id',v.id,'event_id',v.event_id,'exposure_candidate_id',v.exposure_candidate_id,
    'provider_code',v.provider_code,'job_type',v.job_type,'lease_token',v.lease_token,
    'leased_until',v.leased_until,'attempt_number',v.attempts,'request_payload',v.request_payload,
    'contract_version','NOAA_RTOFS_POINT_WORKER_V1','physical_impact_authority',false,
    'official_warning_authority',false,'canonical_identity_authority',false
  );
end $$;

create or replace function public.ssr_noaa_rtofs_job_record_result(
  p_job_id uuid,
  p_lease_token uuid,
  p_worker_id text,
  p_result jsonb
) returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_job ecology.ssr_sea_validation_jobs%rowtype;
  v_obs jsonb;
  v_obs_id uuid;
  v_ids uuid[]:='{}'::uuid[];
  v_ok boolean:=coalesce((p_result->>'ok')::boolean,false);
  v_gate text:=p_result->>'quality_gate';
  v_alignment text:=coalesce(p_result->>'event_alignment_gate','FAIL_EVENT_ALIGNMENT');
  v_status text;
  v_error text;
begin
  select * into v_job from ecology.ssr_sea_validation_jobs where id=p_job_id for update;
  if not found then raise exception 'job not found'; end if;
  if v_job.provider_code<>'NOAA-RTOFS' then raise exception 'job provider mismatch'; end if;
  if v_job.lease_token is distinct from p_lease_token or v_job.worker_id is distinct from p_worker_id then
    raise exception 'lease token or worker mismatch';
  end if;

  if not v_ok or v_gate is distinct from 'PASS_NOAA_RTOFS_POINT_FORECAST' then
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
      review_conclusion=case when v_alignment='PASS_EVENT_ALIGNMENT'
        then 'Event-aligned NOAA RTOFS surface prognostic evidence acquired for currents, SST and salinity. Sea-surface elevation and human relevance review remain open.'
        else 'NOAA RTOFS evidence acquired but did not satisfy the governed event-time alignment gate.' end,
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
  set integration_status=case when v_alignment='PASS_EVENT_ALIGNMENT'
        then 'event_aligned_surface_prognostic_point_validated'
        else 'surface_prognostic_point_validated_alignment_insufficient' end,
      notes=coalesce(notes,'')||E'\n'||'NOAA RTOFS point forecast worker completed. Currents, SST and salinity passed scientific gates; sea-surface elevation remains outside this prognostic dataset.',
      updated_at=now()
  where provider_code='NOAA-RTOFS';

  return jsonb_build_object('job_id',p_job_id,'job_status','completed','quality_gate',v_gate,
    'event_alignment_gate',v_alignment,'observation_ids',v_ids,'physical_impact_asserted',false,
    'official_warning_authority',false,'canonical_identity_authority',false);
end $$;

create or replace function public.ssr_noaa_rtofs_dispatch(
  p_event_id uuid,
  p_exposure_candidate_id uuid,
  p_event_time timestamptz,
  p_latitude double precision,
  p_longitude double precision
) returns jsonb
language plpgsql
security definer
set search_path=public,ecology,extensions,net,pg_temp
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
      'dataset_id','ncepRtofsG2DFore3hrlyProg_LonPM180',
      'variables',array['sst','sss','u_velocity','v_velocity'],
      'nearest_marine_grid_search',true,'max_temporal_lag_hours',3.1,'max_spatial_distance_km',30
    ),'{}'::jsonb,0,v_hash,now()+interval '30 minutes',false,false,false,false
  )
  on conflict(event_id,exposure_candidate_id,provider_code,job_type) do update set
    job_status='queued',priority='critical',requested_at=now(),due_at=excluded.due_at,
    request_payload=excluded.request_payload,result_summary='{}'::jsonb,last_error=null,
    dispatch_token_hash=v_hash,dispatch_expires_at=now()+interval '30 minutes',
    lease_token=null,leased_until=null,worker_id=null,updated_at=now()
  returning id into v_job_id;

  v_request_id:=net.http_post(
    url:='https://veopccdltsklczlmdbri.supabase.co/functions/v1/ssr-noaa-rtofs-point-worker',
    body:=jsonb_build_object('job_id',v_job_id,'job_token',v_token,'worker_id','NOAA_RTOFS_PG_NET'),
    params:='{}'::jsonb,
    headers:=jsonb_build_object('Content-Type','application/json'),
    timeout_milliseconds:=120000
  );

  update ecology.ssr_sea_validation_jobs
  set network_request_id=v_request_id,
      result_summary=jsonb_build_object('dispatch_method','pg_net','network_request_id',v_request_id),updated_at=now()
  where id=v_job_id;

  return jsonb_build_object('job_id',v_job_id,'network_request_id',v_request_id,'job_status','queued',
    'dispatch_method','pg_net_after_commit','physical_impact_asserted',false,'official_warning_authority',false,
    'canonical_identity_authority',false);
end $$;

revoke all on function public.ssr_noaa_rtofs_job_claim(uuid,text,text,integer) from public,anon,authenticated;
revoke all on function public.ssr_noaa_rtofs_job_record_result(uuid,uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.ssr_noaa_rtofs_dispatch(uuid,uuid,timestamptz,double precision,double precision) from public,anon,authenticated;
grant execute on function public.ssr_noaa_rtofs_job_claim(uuid,text,text,integer) to service_role;
grant execute on function public.ssr_noaa_rtofs_job_record_result(uuid,uuid,text,jsonb) to service_role;
grant execute on function public.ssr_noaa_rtofs_dispatch(uuid,uuid,timestamptz,double precision,double precision) to service_role;
