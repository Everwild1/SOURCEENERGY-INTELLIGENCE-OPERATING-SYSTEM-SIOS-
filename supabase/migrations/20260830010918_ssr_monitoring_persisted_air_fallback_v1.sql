create or replace function ecology.ssr_monitoring_persisted_air_snapshot(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=ecology,public,extensions,pg_temp
as $$
declare
  v_event_time timestamptz;
  v_profile record;
  v_levels jsonb;
  v_level_count integer;
  v_surface_pressure numeric;
  v_surface_t double precision;
  v_surface_rh double precision;
  v_surface_wind double precision;
  v_surface_omega double precision;
  v_mean_t double precision;
  v_mean_rh double precision;
  v_mean_omega double precision;
  v_max_wind double precision;
  v_max_wind_pressure numeric;
  v_h_min double precision;
  v_h_max double precision;
  v_lag_hours double precision;
  v_digest text;
begin
  select event_time into v_event_time
  from ecology.ssr_air_events
  where id=p_event_id;
  if not found then raise exception 'event not found'; end if;

  select p.id,p.provider_code,p.dataset_name,p.evidence_time,p.grid_latitude,p.grid_longitude,
         p.quality_gate,p.retrieval_metadata
  into v_profile
  from ecology.ssr_air_profiles p
  where p.provider_code='NASA-GEOS-CF'
    and p.quality_gate='PASS_GEOS_CF_PROFILE'
    and abs(extract(epoch from (p.evidence_time-v_event_time)))<=3.1*3600
  order by abs(extract(epoch from (p.evidence_time-v_event_time))),p.created_at desc
  limit 1;

  if not found then return null; end if;

  with s as (
    select
      row_number() over(order by pressure_level_hpa::numeric desc)::integer as level_index,
      pressure_level_hpa::numeric as pressure_level_hpa,
      candidate_ssr_z_index,
      (variables->>'t')::double precision as t,
      (variables->>'u')::double precision as u,
      (variables->>'v')::double precision as v,
      (variables->>'rh')::double precision as rh,
      (variables->>'h')::double precision as h,
      (variables->>'omega')::double precision as omega,
      sqrt(power((variables->>'u')::double precision,2)+power((variables->>'v')::double precision,2)) as wind_speed_mps
    from ecology.ssr_air_4d_samples
    where profile_id=v_profile.id
      and quality_gate='PASS_GEOS_CF_MULTI_VARIABLE'
  )
  select
    jsonb_agg(jsonb_build_object(
      'level_index',level_index,
      'pressure_level_hpa',pressure_level_hpa,
      't',t,'u',u,'v',v,'rh',rh,'h',h,'omega',omega,
      'wind_speed_mps',wind_speed_mps,
      'candidate_ssr_z_index',candidate_ssr_z_index
    ) order by pressure_level_hpa desc),
    count(*)::integer,
    (array_agg(pressure_level_hpa order by pressure_level_hpa desc))[1],
    (array_agg(t order by pressure_level_hpa desc))[1],
    (array_agg(rh order by pressure_level_hpa desc))[1],
    (array_agg(wind_speed_mps order by pressure_level_hpa desc))[1],
    (array_agg(omega order by pressure_level_hpa desc))[1],
    avg(t),avg(rh),avg(omega),
    max(wind_speed_mps),
    (array_agg(pressure_level_hpa order by wind_speed_mps desc))[1],
    min(h),max(h)
  into
    v_levels,v_level_count,v_surface_pressure,v_surface_t,v_surface_rh,v_surface_wind,v_surface_omega,
    v_mean_t,v_mean_rh,v_mean_omega,v_max_wind,v_max_wind_pressure,v_h_min,v_h_max
  from s;

  if v_level_count is null or v_level_count=0 then return null; end if;

  v_lag_hours:=abs(extract(epoch from (v_profile.evidence_time-v_event_time)))/3600.0;
  v_digest:=encode(extensions.digest(v_levels::text,'sha256'),'hex');

  return jsonb_build_object(
    'provider','NASA-GEOS-CF',
    'dataset',v_profile.dataset_name,
    'quality_gate','PASS_GEOS_CF_PROFILE',
    'evidence_mode','PERSISTED_FORECAST_SNAPSHOT',
    'source_freshness_gate','SOURCE_LATEST_ROLLED_PERSISTED_SNAPSHOT_USED',
    'evidence_time_utc',v_profile.evidence_time,
    'target_event_time_utc',v_event_time,
    'target_lag_hours',v_lag_hours,
    'time_alignment_gate',case when v_lag_hours<=1.1 then 'PASS_EVENT_TIME_ALIGNMENT' else 'FAIL_EVENT_TIME_ALIGNMENT' end,
    'time_index',nullif(v_profile.retrieval_metadata->>'time_index','')::integer,
    'valid_level_count',v_level_count,
    'total_level_count',v_level_count,
    'grid',jsonb_build_object(
      'latitude',v_profile.grid_latitude,
      'longitude',v_profile.grid_longitude,
      'lat_index',nullif(v_profile.retrieval_metadata->>'lat_index','')::integer,
      'lon_index',nullif(v_profile.retrieval_metadata->>'lon_index','')::integer
    ),
    'summary',jsonb_build_object(
      'surface_pressure_hpa',v_surface_pressure,
      'surface_temperature_k',v_surface_t,
      'surface_relative_humidity',v_surface_rh,
      'surface_wind_speed_mps',v_surface_wind,
      'surface_omega_pa_s',v_surface_omega,
      'column_mean_temperature_k',v_mean_t,
      'column_mean_relative_humidity',v_mean_rh,
      'column_mean_omega_pa_s',v_mean_omega,
      'max_wind_speed_mps',v_max_wind,
      'max_wind_pressure_hpa',v_max_wind_pressure,
      'provider_height_min_m',v_h_min,
      'provider_height_max_m',v_h_max
    ),
    'levels',v_levels,
    'profile_id',v_profile.id,
    'profile_digest_sha256',v_digest,
    'resolver_version',coalesce(v_profile.retrieval_metadata->>'resolver_version','persisted-profile-fallback-v1'),
    'invocation_attempt',0,
    'authority_boundary',jsonb_build_object(
      'physical_impact_asserted',false,
      'external_action_authority',false,
      'official_warning_authority',false,
      'canonical_identity_authority',false
    )
  );
end $$;

revoke all on function ecology.ssr_monitoring_persisted_air_snapshot(uuid) from public,anon,authenticated;
grant execute on function ecology.ssr_monitoring_persisted_air_snapshot(uuid) to service_role;

create or replace function public.ssr_environmental_monitoring_run_record_result(
  p_run_id uuid,
  p_lease_token uuid,
  p_worker_id text,
  p_status text,
  p_result jsonb,
  p_error text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_run ecology.ssr_environmental_monitoring_runs%rowtype;
  v_next timestamptz;
  v_event_id uuid;
  v_status text:=p_status;
  v_result jsonb:=coalesce(p_result,'{}'::jsonb);
  v_error text:=p_error;
  v_air jsonb;
  v_land_pass boolean:=false;
  v_sea_required boolean:=false;
  v_sea_pass boolean:=false;
begin
  if v_status not in ('completed','partial','failed','cancelled') then raise exception 'unsupported result status'; end if;
  select * into v_run from ecology.ssr_environmental_monitoring_runs where id=p_run_id for update;
  if not found then raise exception 'monitoring run not found'; end if;
  if v_run.lease_token is distinct from p_lease_token or v_run.worker_id is distinct from p_worker_id then
    raise exception 'lease token or worker mismatch';
  end if;

  select event_id into v_event_id
  from ecology.ssr_environmental_monitoring_watchlist
  where id=v_run.watchlist_id;

  if v_status='partial'
     and v_result->>'monitoring_quality_gate'='PARTIAL_GOVERNED_ENVIRONMENTAL_MONITORING_SNAPSHOT'
     and v_result#>>'{snapshot,air,time_alignment_gate}'='FAIL_EVENT_TIME_ALIGNMENT' then
    v_air:=ecology.ssr_monitoring_persisted_air_snapshot(v_event_id);
    v_land_pass:=coalesce(v_result#>>'{snapshot,land,identity_invariant_gate}','')='PASS_CANONICAL_IDENTITY_INVARIANT';
    v_sea_required:=coalesce((v_result#>>'{snapshot,sea,required}')::boolean,false);
    v_sea_pass:=not v_sea_required or coalesce((v_result#>>'{snapshot,sea,evidence_ready}')::boolean,false);

    if v_air is not null
       and v_air->>'time_alignment_gate'='PASS_EVENT_TIME_ALIGNMENT'
       and v_land_pass and v_sea_pass then
      v_result:=jsonb_set(v_result,'{snapshot,air}',v_air,true);
      v_result:=jsonb_set(v_result,'{ok}','true'::jsonb,true);
      v_result:=jsonb_set(v_result,'{monitoring_quality_gate}',to_jsonb('PASS_GOVERNED_ENVIRONMENTAL_MONITORING_SNAPSHOT'::text),true);
      v_result:=jsonb_set(v_result,'{assessment}',jsonb_build_object(
        'classification','PERSISTED_EVENT_ALIGNED_FORECAST_SNAPSHOT',
        'material_revision',false,
        'source_resolution','SOURCE_LATEST_ROLLED_PERSISTED_SNAPSHOT_USED'
      ),true);
      v_status:='completed';
      v_error:=null;
    end if;
  end if;

  update ecology.ssr_environmental_monitoring_runs
  set run_status=v_status,result_summary=v_result,last_error=v_error,
      completed_at=now(),lease_token=null,leased_until=null,
      dispatch_token_hash=null,dispatch_expires_at=null,updated_at=now()
  where id=p_run_id;

  if v_status in ('completed','partial') then
    select least(
      w.monitoring_window_end,
      greatest(now(),v_run.scheduled_for)+make_interval(mins=>w.cadence_minutes)
    ) into v_next
    from ecology.ssr_environmental_monitoring_watchlist w
    where w.id=v_run.watchlist_id;

    update ecology.ssr_environmental_monitoring_watchlist
    set last_completed_at=now(),
        last_successful_run_id=case when v_status='completed' then p_run_id else last_successful_run_id end,
        next_due_at=case when v_next<monitoring_window_end then v_next else monitoring_window_end end,
        updated_at=now()
    where id=v_run.watchlist_id;
  end if;

  update ecology.ssr_air_event_action_items a
  set action_status='completed',completed_at=now(),completed_by='SOURCEENERGY_MONITORING_SYSTEM',
      completion_payload=jsonb_build_object(
        'completion_basis','A governed monitoring run completed at or after the forecast event time for every active subject watchlist.',
        'event_id',a.event_id,'completed_by_run',p_run_id,
        'physical_impact_asserted',false,'official_warning_authority',false,
        'canonical_identity_authority',false
      ),updated_at=now()
  where a.action_code='MONITOR_FORECAST_EVENT_WINDOW'
    and a.action_status in ('open','in_progress')
    and a.event_id=v_event_id
    and now()>=(select e.event_time from ecology.ssr_air_events e where e.id=a.event_id)
    and not exists(
      select 1
      from ecology.ssr_environmental_monitoring_watchlist w
      where w.event_id=a.event_id and w.monitoring_status='active'
        and not exists(
          select 1 from ecology.ssr_environmental_monitoring_runs r
          where r.watchlist_id=w.id and r.run_status='completed'
            and r.scheduled_for>=(select e2.event_time-interval '15 minutes' from ecology.ssr_air_events e2 where e2.id=a.event_id)
        )
    );

  return jsonb_build_object(
    'run_id',p_run_id,'watchlist_id',v_run.watchlist_id,'run_status',v_status,
    'persisted_air_fallback_applied',v_status='completed' and v_result#>>'{snapshot,air,evidence_mode}'='PERSISTED_FORECAST_SNAPSHOT',
    'physical_impact_asserted',false,'external_action_authority',false,
    'official_warning_authority',false,'canonical_identity_authority',false
  );
end $$;

comment on function ecology.ssr_monitoring_persisted_air_snapshot(uuid) is 'Returns the nearest governed, previously persisted GEOS-CF forecast snapshot for an AIR event when the provider latest collection has rolled forward. It does not create physical-impact, warning, external-action, or canonical-identity authority.';
