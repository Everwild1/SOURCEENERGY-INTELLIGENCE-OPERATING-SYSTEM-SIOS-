alter table ecology.ssr_environmental_monitoring_runs
  add column if not exists dispatch_token_hash text,
  add column if not exists dispatch_expires_at timestamptz,
  add column if not exists network_request_id bigint;

create index if not exists ix_ssr_environmental_monitoring_runs_dispatch
  on ecology.ssr_environmental_monitoring_runs(run_status,scheduled_for,dispatch_expires_at)
  where run_status in ('queued','failed','leased');

create table if not exists ecology.ssr_environmental_monitoring_run_audit (
  id bigserial primary key,
  run_id uuid not null references ecology.ssr_environmental_monitoring_runs(id) on delete restrict,
  watchlist_id uuid not null references ecology.ssr_environmental_monitoring_watchlist(id) on delete restrict,
  audit_action text not null,
  status_before text,
  status_after text,
  worker_id text,
  audit_payload jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);

create index if not exists ix_ssr_environmental_monitoring_run_audit
  on ecology.ssr_environmental_monitoring_run_audit(run_id,recorded_at desc);

alter table ecology.ssr_environmental_monitoring_run_audit enable row level security;
drop policy if exists ssr_environmental_monitoring_run_audit_service_role_select on ecology.ssr_environmental_monitoring_run_audit;
create policy ssr_environmental_monitoring_run_audit_service_role_select
  on ecology.ssr_environmental_monitoring_run_audit for select to service_role using(true);
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
      run_id,watchlist_id,audit_action,status_before,status_after,worker_id,audit_payload
    ) values (
      new.id,new.watchlist_id,'created',null,new.run_status,new.worker_id,
      jsonb_build_object('run_type',new.run_type,'scheduled_for',new.scheduled_for,'requested_domains',new.requested_domains)
    );
    return new;
  end if;

  if tg_op='UPDATE' then
    insert into ecology.ssr_environmental_monitoring_run_audit(
      run_id,watchlist_id,audit_action,status_before,status_after,worker_id,audit_payload
    ) values (
      new.id,new.watchlist_id,
      case when old.run_status is distinct from new.run_status then 'status_transition' else 'updated' end,
      old.run_status,new.run_status,new.worker_id,
      jsonb_build_object(
        'attempt_count',new.attempt_count,
        'network_request_id',new.network_request_id,
        'leased_until',new.leased_until,
        'last_error',new.last_error,
        'quality_gate',new.result_summary->>'quality_gate'
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

create or replace function public.ssr_environmental_monitoring_run_claim_v2(
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
  v_watch ecology.ssr_environmental_monitoring_watchlist%rowtype;
  v_event ecology.ssr_air_events%rowtype;
  v_anchor ecology.ssr_anchor_candidate_registry%rowtype;
  v_token uuid:=gen_random_uuid();
begin
  if p_worker_id is null or length(trim(p_worker_id))=0 then raise exception 'worker id required'; end if;
  if p_lease_seconds<60 or p_lease_seconds>1800 then raise exception 'lease seconds must be 60..1800'; end if;

  select * into v_run
  from ecology.ssr_environmental_monitoring_runs
  where id=p_run_id
  for update;
  if not found then raise exception 'monitoring run not found'; end if;
  if v_run.dispatch_token_hash is distinct from p_token_hash then raise exception 'invalid dispatch token'; end if;
  if v_run.dispatch_expires_at is null or v_run.dispatch_expires_at<=now() then raise exception 'dispatch token expired'; end if;
  if v_run.run_status not in ('queued','failed') then raise exception 'monitoring run is not claimable'; end if;
  if v_run.scheduled_for>now() then raise exception 'monitoring run is not due'; end if;

  select * into v_watch from ecology.ssr_environmental_monitoring_watchlist where id=v_run.watchlist_id;
  if not found then raise exception 'monitoring watchlist not found'; end if;
  select * into v_event from ecology.ssr_air_events where id=v_watch.event_id;
  if not found then raise exception 'event not found'; end if;
  select * into v_anchor from ecology.ssr_anchor_candidate_registry where id::text=v_watch.subject_reference;

  update ecology.ssr_environmental_monitoring_runs
  set run_status='leased',worker_id=p_worker_id,lease_token=v_token,leased_at=now(),
      leased_until=now()+make_interval(secs=>p_lease_seconds),attempt_count=attempt_count+1,
      started_at=coalesce(started_at,now()),last_error=null,updated_at=now()
  where id=p_run_id
  returning * into v_run;

  return jsonb_build_object(
    'run_id',v_run.id,
    'watchlist_id',v_watch.id,
    'event_id',v_watch.event_id,
    'fusion_assessment_id',v_watch.fusion_assessment_id,
    'exposure_candidate_id',v_watch.exposure_candidate_id,
    'lease_token',v_token,
    'leased_until',v_run.leased_until,
    'attempt_number',v_run.attempt_count,
    'run_type',v_run.run_type,
    'scheduled_for',v_run.scheduled_for,
    'event_time',v_event.event_time,
    'subject_name',v_watch.subject_name,
    'subject_reference',v_watch.subject_reference,
    'subject_infrastructure_type',v_watch.subject_infrastructure_type,
    'latitude',v_anchor.latitude,
    'longitude',v_anchor.longitude,
    'canonical_address',v_anchor.canonical_address,
    'cube_uid',v_anchor.cube_uid,
    'canonicalization_status',v_anchor.canonicalization_status,
    'promotion_eligible',v_anchor.promotion_eligible,
    'source_verification_status',v_anchor.source_verification_status,
    'source_reconciliation_status',v_anchor.source_reconciliation_status,
    'monitoring_domains',v_watch.monitoring_domains,
    'provider_plan',v_watch.provider_plan,
    'variable_plan',v_watch.variable_plan,
    'run_payload',v_run.run_payload,
    'physical_impact_authority',false,
    'external_action_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_environmental_monitoring_run_claim_v2(uuid,text,text,integer) from public,anon,authenticated;
grant execute on function public.ssr_environmental_monitoring_run_claim_v2(uuid,text,text,integer) to service_role;

create or replace function public.ssr_environmental_monitoring_enqueue_due(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v record;
  v_run_id uuid;
  v_count integer:=0;
  v_ids uuid[]:='{}'::uuid[];
  v_scheduled timestamptz;
  v_next timestamptz;
begin
  if p_limit<1 or p_limit>100 then raise exception 'limit must be 1..100'; end if;

  for v in
    select
      w.*,e.event_time,e.event_type,e.severity,
      a.latitude,a.longitude,a.canonical_address,a.cube_uid
    from ecology.ssr_environmental_monitoring_watchlist w
    join ecology.ssr_air_events e on e.id=w.event_id
    left join ecology.ssr_anchor_candidate_registry a on a.id::text=w.subject_reference
    where w.monitoring_status='active'
      and w.monitoring_window_end>now()
      and w.next_due_at is not null
      and w.next_due_at<=now()
    order by w.next_due_at,w.created_at
    for update of w skip locked
    limit p_limit
  loop
    v_run_id:=null;
    v_scheduled:=v.next_due_at;
    insert into ecology.ssr_environmental_monitoring_runs(
      watchlist_id,run_type,run_status,scheduled_for,requested_domains,run_payload,result_summary,
      physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
    ) values (
      v.id,'scheduled','queued',v_scheduled,v.monitoring_domains,
      jsonb_build_object(
        'event_id',v.event_id,
        'event_time',v.event_time,
        'event_type',v.event_type,
        'severity',v.severity,
        'fusion_assessment_id',v.fusion_assessment_id,
        'exposure_candidate_id',v.exposure_candidate_id,
        'subject_name',v.subject_name,
        'subject_infrastructure_type',v.subject_infrastructure_type,
        'latitude',v.latitude,
        'longitude',v.longitude,
        'canonical_address',v.canonical_address,
        'cube_uid',v.cube_uid,
        'provider_plan',v.provider_plan,
        'variable_plan',v.variable_plan,
        'target_time',v.event_time,
        'monitoring_scope','environmental evidence refresh only; no physical-impact assertion, official warning, external action, or canonical identity mutation'
      ),'{}'::jsonb,false,false,false,false
    )
    on conflict(watchlist_id,run_type,scheduled_for) do nothing
    returning id into v_run_id;

    if v_run_id is not null then
      v_count:=v_count+1;
      v_ids:=array_append(v_ids,v_run_id);
    end if;

    v_next:=v_scheduled+make_interval(mins=>v.cadence_minutes);
    update ecology.ssr_environmental_monitoring_watchlist
    set last_enqueued_at=now(),
        next_due_at=case when v_next<=monitoring_window_end then v_next else null end,
        updated_at=now()
    where id=v.id;
  end loop;

  return jsonb_build_object('enqueued_count',v_count,'run_ids',v_ids);
end $$;

create or replace function public.ssr_environmental_monitoring_dispatch_queued(p_limit integer default 5)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,extensions,net,pg_temp
as $$
declare
  v record;
  v_token text;
  v_hash text;
  v_request_id bigint;
  v_count integer:=0;
  v_ids uuid[]:='{}'::uuid[];
begin
  if p_limit<1 or p_limit>20 then raise exception 'limit must be 1..20'; end if;

  update ecology.ssr_environmental_monitoring_runs
  set run_status='failed',last_error='monitoring worker lease expired',lease_token=null,leased_until=null,
      dispatch_token_hash=null,dispatch_expires_at=null,updated_at=now()
  where run_status='leased' and leased_until<now();

  for v in
    select r.id
    from ecology.ssr_environmental_monitoring_runs r
    join ecology.ssr_environmental_monitoring_watchlist w on w.id=r.watchlist_id
    where r.run_status in ('queued','failed')
      and r.scheduled_for<=now()
      and r.attempt_count<5
      and w.monitoring_status='active'
      and w.monitoring_window_end>now()-interval '2 hours'
      and (r.dispatch_expires_at is null or r.dispatch_expires_at<now())
    order by r.scheduled_for,r.created_at
    for update of r skip locked
    limit p_limit
  loop
    v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
    v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');

    update ecology.ssr_environmental_monitoring_runs
    set dispatch_token_hash=v_hash,dispatch_expires_at=now()+interval '20 minutes',
        last_error=null,updated_at=now()
    where id=v.id;

    v_request_id:=net.http_post(
      url:='https://veopccdltsklczlmdbri.supabase.co/functions/v1/ssr-environmental-monitoring-worker',
      body:=jsonb_build_object('run_id',v.id,'run_token',v_token,'worker_id','SSR_ENVIRONMENTAL_MONITOR'),
      params:='{}'::jsonb,
      headers:=jsonb_build_object('Content-Type','application/json'),
      timeout_milliseconds:=120000
    );

    update ecology.ssr_environmental_monitoring_runs
    set network_request_id=v_request_id,
        result_summary=coalesce(result_summary,'{}'::jsonb)||jsonb_build_object('dispatch_method','pg_net','network_request_id',v_request_id),
        updated_at=now()
    where id=v.id;

    v_count:=v_count+1;
    v_ids:=array_append(v_ids,v.id);
  end loop;

  return jsonb_build_object('dispatched_count',v_count,'run_ids',v_ids);
end $$;

create or replace function ecology.apply_ssr_environmental_monitoring_result()
returns trigger
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
declare
  v_event_id uuid;
  v_event_time timestamptz;
  v_quality text;
  v_post_gate text;
begin
  if new.run_status not in ('completed','partial') or old.run_status is not distinct from new.run_status then
    return new;
  end if;

  select w.event_id,e.event_time into v_event_id,v_event_time
  from ecology.ssr_environmental_monitoring_watchlist w
  join ecology.ssr_air_events e on e.id=w.event_id
  where w.id=new.watchlist_id;

  v_quality:=new.result_summary->>'quality_gate';
  v_post_gate:=new.result_summary->>'post_event_observational_gate';

  if new.run_status='completed'
     and v_quality='PASS_ENVIRONMENTAL_MONITORING_RUN'
     and abs(extract(epoch from (new.scheduled_for-v_event_time)))<=7200 then
    update ecology.ssr_air_event_action_items
    set action_status='completed',completed_at=now(),completed_by='SOURCEENERGY_MONITORING_SYSTEM',
        completion_payload=jsonb_build_object(
          'monitoring_run_id',new.id,
          'quality_gate',v_quality,
          'scheduled_for',new.scheduled_for,
          'event_time',v_event_time,
          'physical_impact_asserted',false,
          'official_warning_authority',false,
          'canonical_identity_authority',false
        ),updated_at=now()
    where event_id=v_event_id and action_code='MONITOR_FORECAST_EVENT_WINDOW'
      and action_status in ('open','in_progress');
  end if;

  if v_post_gate='PASS_POST_EVENT_OBSERVATIONAL_VERIFICATION' then
    update ecology.ssr_air_event_action_items
    set action_status='completed',completed_at=now(),completed_by='SOURCEENERGY_MONITORING_SYSTEM',
        completion_payload=jsonb_build_object(
          'monitoring_run_id',new.id,
          'post_event_observational_gate',v_post_gate,
          'physical_impact_asserted',false,
          'official_warning_authority',false,
          'canonical_identity_authority',false
        ),updated_at=now()
    where event_id=v_event_id and action_code='POST_EVENT_OBSERVATIONAL_VERIFICATION'
      and action_status in ('open','in_progress');
  end if;

  return new;
end $$;

drop trigger if exists trg_apply_ssr_environmental_monitoring_result on ecology.ssr_environmental_monitoring_runs;
create trigger trg_apply_ssr_environmental_monitoring_result
after update on ecology.ssr_environmental_monitoring_runs
for each row execute function ecology.apply_ssr_environmental_monitoring_result();

create or replace function public.ssr_environmental_monitoring_maintenance()
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_enqueue jsonb;
  v_dispatch jsonb;
  v_closed integer:=0;
begin
  v_enqueue:=public.ssr_environmental_monitoring_enqueue_due(20);
  v_dispatch:=public.ssr_environmental_monitoring_dispatch_queued(5);

  update ecology.ssr_environmental_monitoring_watchlist w
  set monitoring_status='closed',next_due_at=null,updated_at=now()
  where w.monitoring_status='active'
    and w.monitoring_window_end<=now()
    and not exists(
      select 1 from ecology.ssr_environmental_monitoring_runs r
      where r.watchlist_id=w.id and r.run_status in ('queued','leased')
    );
  get diagnostics v_closed=row_count;

  return jsonb_build_object(
    'generated_at',now(),
    'enqueue',v_enqueue,
    'dispatch',v_dispatch,
    'watchlists_closed',v_closed,
    'physical_impact_asserted',false,
    'external_action_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_environmental_monitoring_enqueue_due(integer) from public,anon,authenticated;
revoke all on function public.ssr_environmental_monitoring_dispatch_queued(integer) from public,anon,authenticated;
revoke all on function public.ssr_environmental_monitoring_maintenance() from public,anon,authenticated;
grant execute on function public.ssr_environmental_monitoring_enqueue_due(integer) to service_role;
grant execute on function public.ssr_environmental_monitoring_dispatch_queued(integer) to service_role;
grant execute on function public.ssr_environmental_monitoring_maintenance() to service_role;

create or replace view ecology.ssr_environmental_monitoring_execution_status as
select
  w.id as watchlist_id,w.event_id,w.subject_name,w.subject_infrastructure_type,w.monitoring_status,
  w.monitoring_window_start,w.monitoring_window_end,w.next_due_at,w.last_enqueued_at,w.last_completed_at,
  count(r.id) as run_count,
  count(r.id) filter(where r.run_status='completed') as completed_run_count,
  count(r.id) filter(where r.run_status='partial') as partial_run_count,
  count(r.id) filter(where r.run_status='failed') as failed_run_count,
  count(r.id) filter(where r.run_status in ('queued','leased')) as active_run_count,
  max(r.completed_at) as latest_run_completed_at,
  (array_agg(r.result_summary->>'quality_gate' order by r.completed_at desc nulls last))[1] as latest_quality_gate,
  false::boolean as physical_impact_asserted,
  false::boolean as official_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_environmental_monitoring_watchlist w
left join ecology.ssr_environmental_monitoring_runs r on r.watchlist_id=w.id
group by w.id,w.event_id,w.subject_name,w.subject_infrastructure_type,w.monitoring_status,
         w.monitoring_window_start,w.monitoring_window_end,w.next_due_at,w.last_enqueued_at,w.last_completed_at;

comment on table ecology.ssr_environmental_monitoring_run_audit is 'Append-only monitoring execution audit. Monitoring evidence never asserts physical impact, issues official warnings, performs external actions, or mutates canonical SSR identity.';
comment on view ecology.ssr_environmental_monitoring_execution_status is 'Operational monitoring execution status for governed AIR-LAND-SEA watch entries.';

do $$
declare v_jobid bigint;
begin
  select jobid into v_jobid from cron.job where jobname='ssr-environmental-monitoring-maintenance-v1';
  if v_jobid is not null then perform cron.unschedule(v_jobid); end if;
  perform cron.schedule(
    'ssr-environmental-monitoring-maintenance-v1',
    '*/5 * * * *',
    'select public.ssr_environmental_monitoring_maintenance();'
  );
end $$;
