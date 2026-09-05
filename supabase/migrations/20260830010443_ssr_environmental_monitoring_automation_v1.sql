alter table ecology.ssr_environmental_monitoring_runs
  add column if not exists dispatch_token_hash text,
  add column if not exists dispatch_expires_at timestamptz,
  add column if not exists network_request_id bigint,
  add column if not exists max_attempts integer not null default 4,
  add column if not exists last_dispatched_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='ecology.ssr_environmental_monitoring_runs'::regclass
      and conname='ssr_environmental_monitoring_runs_dispatch_hash_check'
  ) then
    alter table ecology.ssr_environmental_monitoring_runs
      add constraint ssr_environmental_monitoring_runs_dispatch_hash_check
      check (dispatch_token_hash is null or dispatch_token_hash ~ '^[0-9a-f]{64}$');
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid='ecology.ssr_environmental_monitoring_runs'::regclass
      and conname='ssr_environmental_monitoring_runs_max_attempts_check'
  ) then
    alter table ecology.ssr_environmental_monitoring_runs
      add constraint ssr_environmental_monitoring_runs_max_attempts_check
      check (max_attempts between 1 and 10);
  end if;
end $$;

create index if not exists ix_ssr_environmental_monitoring_runs_dispatch
  on ecology.ssr_environmental_monitoring_runs(run_status,scheduled_for,dispatch_expires_at)
  where run_status in ('queued','failed');

create table if not exists ecology.ssr_environmental_monitoring_run_audit (
  id bigserial primary key,
  run_id uuid not null references ecology.ssr_environmental_monitoring_runs(id) on delete restrict,
  watchlist_id uuid not null references ecology.ssr_environmental_monitoring_watchlist(id) on delete restrict,
  audit_action text not null,
  previous_status text,
  new_status text,
  worker_id text,
  audit_payload jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);

create index if not exists ix_ssr_environmental_monitoring_run_audit
  on ecology.ssr_environmental_monitoring_run_audit(run_id,recorded_at desc);

alter table ecology.ssr_environmental_monitoring_run_audit enable row level security;
drop policy if exists ssr_environmental_monitoring_run_audit_service_role on ecology.ssr_environmental_monitoring_run_audit;
create policy ssr_environmental_monitoring_run_audit_service_role
  on ecology.ssr_environmental_monitoring_run_audit
  for select to service_role using(true);
revoke all on ecology.ssr_environmental_monitoring_run_audit from anon,authenticated;
grant select on ecology.ssr_environmental_monitoring_run_audit to service_role;

create or replace function ecology.audit_ssr_environmental_monitoring_run()
returns trigger
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
begin
  if tg_op='INSERT' then
    insert into ecology.ssr_environmental_monitoring_run_audit(
      run_id,watchlist_id,audit_action,previous_status,new_status,worker_id,audit_payload
    ) values (
      new.id,new.watchlist_id,'created',null,new.run_status,new.worker_id,
      jsonb_build_object('run_type',new.run_type,'scheduled_for',new.scheduled_for,'requested_domains',new.requested_domains)
    );
    return new;
  end if;

  if tg_op='UPDATE' then
    insert into ecology.ssr_environmental_monitoring_run_audit(
      run_id,watchlist_id,audit_action,previous_status,new_status,worker_id,audit_payload
    ) values (
      new.id,new.watchlist_id,
      case
        when old.run_status is distinct from new.run_status then 'status_transition'
        when old.network_request_id is distinct from new.network_request_id then 'dispatched'
        else 'updated'
      end,
      old.run_status,new.run_status,new.worker_id,
      jsonb_build_object(
        'attempt_count',new.attempt_count,
        'network_request_id',new.network_request_id,
        'last_error',new.last_error,
        'completed_at',new.completed_at
      )
    );
    return new;
  end if;
  return new;
end $$;

drop trigger if exists trg_ssr_environmental_monitoring_run_audit on ecology.ssr_environmental_monitoring_runs;
create trigger trg_ssr_environmental_monitoring_run_audit
after insert or update on ecology.ssr_environmental_monitoring_runs
for each row execute function ecology.audit_ssr_environmental_monitoring_run();

create or replace function ecology.block_ssr_environmental_monitoring_run_audit_mutation()
returns trigger
language plpgsql
set search_path=ecology,public,pg_temp
as $$
begin
  raise exception 'ssr_environmental_monitoring_run_audit is append-only';
end $$;

drop trigger if exists trg_block_ssr_environmental_monitoring_run_audit_mutation on ecology.ssr_environmental_monitoring_run_audit;
create trigger trg_block_ssr_environmental_monitoring_run_audit_mutation
before update or delete on ecology.ssr_environmental_monitoring_run_audit
for each row execute function ecology.block_ssr_environmental_monitoring_run_audit_mutation();

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
      'pressure_level_hpa',e.pressure_level_hpa,'signal_flags',e.signal_flags
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
      where r.watchlist_id=w.id and r.run_status in ('completed','partial')
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

create or replace function public.ssr_environmental_monitoring_run_claim_token(
  p_run_id uuid,
  p_token_hash text,
  p_worker_id text,
  p_lease_seconds integer default 600
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_run ecology.ssr_environmental_monitoring_runs%rowtype;
  v_context jsonb;
begin
  if p_worker_id is null or length(trim(p_worker_id))=0 then raise exception 'worker id required'; end if;
  if p_lease_seconds<60 or p_lease_seconds>1800 then raise exception 'lease seconds must be 60..1800'; end if;

  update ecology.ssr_environmental_monitoring_runs
  set run_status='leased',worker_id=p_worker_id,lease_token=gen_random_uuid(),leased_at=now(),
      leased_until=now()+make_interval(secs=>p_lease_seconds),attempt_count=attempt_count+1,
      started_at=coalesce(started_at,now()),last_error=null,
      dispatch_token_hash=null,dispatch_expires_at=null,updated_at=now()
  where id=p_run_id
    and dispatch_token_hash=p_token_hash
    and dispatch_expires_at>now()
    and run_status in ('queued','failed')
    and scheduled_for<=now()+interval '2 minutes'
    and attempt_count<max_attempts
    and (leased_until is null or leased_until<now())
  returning * into v_run;

  if not found then raise exception 'monitoring run is not claimable'; end if;
  v_context:=public.ssr_environmental_monitoring_context(v_run.watchlist_id);

  return jsonb_build_object(
    'run_id',v_run.id,'watchlist_id',v_run.watchlist_id,'run_type',v_run.run_type,
    'lease_token',v_run.lease_token,'leased_until',v_run.leased_until,
    'attempt_number',v_run.attempt_count,'scheduled_for',v_run.scheduled_for,
    'requested_domains',v_run.requested_domains,'run_payload',v_run.run_payload,
    'context',v_context,
    'physical_impact_authority',false,'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

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
begin
  if p_status not in ('completed','partial','failed','cancelled') then raise exception 'unsupported result status'; end if;
  select * into v_run from ecology.ssr_environmental_monitoring_runs where id=p_run_id for update;
  if not found then raise exception 'monitoring run not found'; end if;
  if v_run.lease_token is distinct from p_lease_token or v_run.worker_id is distinct from p_worker_id then
    raise exception 'lease token or worker mismatch';
  end if;

  update ecology.ssr_environmental_monitoring_runs
  set run_status=p_status,result_summary=coalesce(p_result,'{}'::jsonb),last_error=p_error,
      completed_at=now(),lease_token=null,leased_until=null,
      dispatch_token_hash=null,dispatch_expires_at=null,updated_at=now()
  where id=p_run_id;

  if p_status in ('completed','partial') then
    select least(
      w.monitoring_window_end,
      greatest(now(),v_run.scheduled_for)+make_interval(mins=>w.cadence_minutes)
    ) into v_next
    from ecology.ssr_environmental_monitoring_watchlist w
    where w.id=v_run.watchlist_id;

    update ecology.ssr_environmental_monitoring_watchlist
    set last_completed_at=now(),
        last_successful_run_id=case when p_status='completed' then p_run_id else last_successful_run_id end,
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
    and a.event_id=(select w.event_id from ecology.ssr_environmental_monitoring_watchlist w where w.id=v_run.watchlist_id)
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
    'run_id',p_run_id,'watchlist_id',v_run.watchlist_id,'run_status',p_status,
    'physical_impact_asserted',false,'external_action_authority',false,
    'official_warning_authority',false,'canonical_identity_authority',false
  );
end $$;

create or replace function public.ssr_environmental_monitoring_maintenance()
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,extensions,net,cron,pg_temp
as $$
declare
  v_recovered integer:=0;
  v_enqueued integer:=0;
  v_dispatched integer:=0;
  v_closed integer:=0;
  v_token text;
  v_hash text;
  v_request_id bigint;
  v_row record;
begin
  update ecology.ssr_environmental_monitoring_runs
  set run_status='failed',last_error='monitoring worker lease expired before result was recorded',
      lease_token=null,leased_until=null,dispatch_token_hash=null,dispatch_expires_at=null,updated_at=now()
  where run_status='leased' and leased_until<now();
  get diagnostics v_recovered=row_count;

  insert into ecology.ssr_environmental_monitoring_runs(
    watchlist_id,run_type,run_status,scheduled_for,requested_domains,run_payload,
    physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
  )
  select
    w.id,'scheduled','queued',w.next_due_at,w.monitoring_domains,
    jsonb_build_object(
      'event_id',w.event_id,'fusion_assessment_id',w.fusion_assessment_id,
      'exposure_candidate_id',w.exposure_candidate_id,'subject_name',w.subject_name,
      'provider_plan',w.provider_plan,'variable_plan',w.variable_plan,
      'monitoring_window_start',w.monitoring_window_start,'monitoring_window_end',w.monitoring_window_end,
      'authority_boundary',jsonb_build_object(
        'physical_impact_asserted',false,'external_action_authority',false,
        'official_warning_authority',false,'canonical_identity_authority',false)
    ),false,false,false,false
  from ecology.ssr_environmental_monitoring_watchlist w
  where w.monitoring_status='active'
    and w.next_due_at is not null
    and w.next_due_at<=now()
    and w.next_due_at<=w.monitoring_window_end
  on conflict(watchlist_id,run_type,scheduled_for) do nothing;
  get diagnostics v_enqueued=row_count;

  for v_row in
    select r.id
    from ecology.ssr_environmental_monitoring_runs r
    where r.run_status in ('queued','failed')
      and r.scheduled_for<=now()+interval '1 minute'
      and r.attempt_count<r.max_attempts
      and (r.dispatch_expires_at is null or r.dispatch_expires_at<now())
      and (r.leased_until is null or r.leased_until<now())
    order by r.scheduled_for,r.created_at
    for update skip locked
    limit 12
  loop
    begin
      v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
      v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');

      update ecology.ssr_environmental_monitoring_runs
      set dispatch_token_hash=v_hash,dispatch_expires_at=now()+interval '15 minutes',
          last_dispatched_at=now(),last_error=null,updated_at=now()
      where id=v_row.id;

      v_request_id:=net.http_post(
        url:='https://veopccdltsklczlmdbri.supabase.co/functions/v1/ssr-environmental-monitoring-worker',
        body:=jsonb_build_object('run_id',v_row.id,'run_token',v_token,'worker_id','SSR_ENVIRONMENTAL_MONITOR'),
        params:='{}'::jsonb,
        headers:=jsonb_build_object('Content-Type','application/json'),
        timeout_milliseconds:=120000
      );

      update ecology.ssr_environmental_monitoring_runs
      set network_request_id=v_request_id,updated_at=now()
      where id=v_row.id;
      v_dispatched:=v_dispatched+1;
    exception when others then
      update ecology.ssr_environmental_monitoring_runs
      set last_error='dispatch failure: '||sqlerrm,dispatch_token_hash=null,dispatch_expires_at=null,updated_at=now()
      where id=v_row.id;
    end;
  end loop;

  update ecology.ssr_environmental_monitoring_watchlist w
  set monitoring_status='closed',next_due_at=null,updated_at=now()
  where w.monitoring_status='active'
    and now()>w.monitoring_window_end
    and not exists(
      select 1 from ecology.ssr_environmental_monitoring_runs r
      where r.watchlist_id=w.id and r.run_status in ('queued','leased')
    );
  get diagnostics v_closed=row_count;

  return jsonb_build_object(
    'recovered_expired_leases',v_recovered,'runs_enqueued',v_enqueued,
    'runs_dispatched',v_dispatched,'watchlists_closed',v_closed,
    'physical_impact_asserted',false,'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

create or replace function public.ssr_environmental_monitoring_manual_dispatch(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_created integer:=0;
  v_time timestamptz:=date_trunc('second',clock_timestamp());
  v_maintenance jsonb;
begin
  insert into ecology.ssr_environmental_monitoring_runs(
    watchlist_id,run_type,run_status,scheduled_for,requested_domains,run_payload,
    physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
  )
  select w.id,'manual','queued',v_time,w.monitoring_domains,
    jsonb_build_object(
      'event_id',w.event_id,'fusion_assessment_id',w.fusion_assessment_id,
      'exposure_candidate_id',w.exposure_candidate_id,'subject_name',w.subject_name,
      'manual_validation',true,'provider_plan',w.provider_plan,'variable_plan',w.variable_plan,
      'authority_boundary',jsonb_build_object(
        'physical_impact_asserted',false,'external_action_authority',false,
        'official_warning_authority',false,'canonical_identity_authority',false)
    ),false,false,false,false
  from ecology.ssr_environmental_monitoring_watchlist w
  where w.event_id=p_event_id and w.monitoring_status='active'
  on conflict(watchlist_id,run_type,scheduled_for) do nothing;
  get diagnostics v_created=row_count;

  v_maintenance:=public.ssr_environmental_monitoring_maintenance();
  return jsonb_build_object('event_id',p_event_id,'manual_runs_created',v_created,'maintenance',v_maintenance);
end $$;

revoke all on function public.ssr_environmental_monitoring_context(uuid) from public,anon,authenticated;
revoke all on function public.ssr_environmental_monitoring_run_claim_token(uuid,text,text,integer) from public,anon,authenticated;
revoke all on function public.ssr_environmental_monitoring_run_record_result(uuid,uuid,text,text,jsonb,text) from public,anon,authenticated;
revoke all on function public.ssr_environmental_monitoring_maintenance() from public,anon,authenticated;
revoke all on function public.ssr_environmental_monitoring_manual_dispatch(uuid) from public,anon,authenticated;
grant execute on function public.ssr_environmental_monitoring_context(uuid) to service_role;
grant execute on function public.ssr_environmental_monitoring_run_claim_token(uuid,text,text,integer) to service_role;
grant execute on function public.ssr_environmental_monitoring_run_record_result(uuid,uuid,text,text,jsonb,text) to service_role;
grant execute on function public.ssr_environmental_monitoring_maintenance() to service_role;
grant execute on function public.ssr_environmental_monitoring_manual_dispatch(uuid) to service_role;

revoke all on function public.ssr_environmental_monitoring_run_claim(uuid,text,integer) from public,anon,authenticated,service_role;

create or replace view ecology.ssr_environmental_monitoring_operational_status as
select
  w.event_id,w.id as watchlist_id,w.subject_name,w.subject_infrastructure_type,
  w.monitoring_status,w.monitoring_domains,w.cadence_minutes,w.monitoring_window_start,w.monitoring_window_end,
  w.next_due_at,w.last_completed_at,w.last_successful_run_id,
  count(r.id)::integer as run_count,
  count(r.id) filter(where r.run_status='completed')::integer as completed_run_count,
  count(r.id) filter(where r.run_status='partial')::integer as partial_run_count,
  count(r.id) filter(where r.run_status='failed')::integer as failed_run_count,
  count(r.id) filter(where r.run_status in ('queued','leased'))::integer as active_run_count,
  max(r.completed_at) as latest_run_completed_at,
  false::boolean as physical_impact_asserted,
  false::boolean as official_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_environmental_monitoring_watchlist w
left join ecology.ssr_environmental_monitoring_runs r on r.watchlist_id=w.id
group by w.event_id,w.id,w.subject_name,w.subject_infrastructure_type,w.monitoring_status,
         w.monitoring_domains,w.cadence_minutes,w.monitoring_window_start,w.monitoring_window_end,
         w.next_due_at,w.last_completed_at,w.last_successful_run_id;

comment on table ecology.ssr_environmental_monitoring_runs is 'Governed AIR-LAND-SEA monitoring executions. Run results are environmental intelligence only and cannot assert physical impact, issue official warnings, perform external action, or mutate canonical SSR identity.';
comment on view ecology.ssr_environmental_monitoring_operational_status is 'Operational monitoring status for governed AIR-LAND-SEA watchlists.';

do $$
declare v_job bigint;
begin
  for v_job in select jobid from cron.job where jobname='ssr-environmental-monitoring-maintenance-v1'
  loop
    perform cron.unschedule(v_job);
  end loop;
  perform cron.schedule(
    'ssr-environmental-monitoring-maintenance-v1',
    '*/5 * * * *',
    'select public.ssr_environmental_monitoring_maintenance();'
  );
end $$;
