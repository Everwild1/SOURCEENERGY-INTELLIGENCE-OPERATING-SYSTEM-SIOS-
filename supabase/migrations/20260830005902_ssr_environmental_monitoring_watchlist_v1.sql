create table if not exists ecology.ssr_environmental_monitoring_watchlist (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  fusion_assessment_id uuid not null references ecology.ssr_air_land_sea_fusion_assessments(id) on delete restrict,
  exposure_candidate_id uuid not null references ecology.ssr_air_event_exposure_candidates(id) on delete restrict,
  subject_reference text not null,
  subject_name text not null,
  subject_infrastructure_type text,
  monitoring_status text not null default 'active' check (monitoring_status in ('active','paused','closed')),
  monitoring_domains text[] not null default '{}'::text[],
  provider_plan jsonb not null default '{}'::jsonb,
  variable_plan jsonb not null default '{}'::jsonb,
  cadence_minutes integer not null check (cadence_minutes between 15 and 1440),
  monitoring_window_start timestamptz not null,
  monitoring_window_end timestamptz not null,
  next_due_at timestamptz,
  last_enqueued_at timestamptz,
  last_completed_at timestamptz,
  last_successful_run_id uuid,
  monitoring_reason jsonb not null default '{}'::jsonb,
  accepted_by text not null,
  accepted_at timestamptz not null,
  human_governance_required boolean not null default true,
  physical_impact_asserted boolean not null default false check (physical_impact_asserted=false),
  external_action_authority boolean not null default false check (external_action_authority=false),
  official_warning_authority boolean not null default false check (official_warning_authority=false),
  canonical_identity_authority boolean not null default false check (canonical_identity_authority=false),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(event_id,exposure_candidate_id),
  check (monitoring_window_end > monitoring_window_start)
);

create table if not exists ecology.ssr_environmental_monitoring_runs (
  id uuid primary key default gen_random_uuid(),
  watchlist_id uuid not null references ecology.ssr_environmental_monitoring_watchlist(id) on delete restrict,
  run_type text not null default 'scheduled' check (run_type in ('baseline','scheduled','manual','recovery')),
  run_status text not null default 'queued' check (run_status in ('queued','leased','completed','partial','failed','cancelled')),
  scheduled_for timestamptz not null,
  requested_domains text[] not null default '{}'::text[],
  run_payload jsonb not null default '{}'::jsonb,
  result_summary jsonb not null default '{}'::jsonb,
  worker_id text,
  lease_token uuid,
  leased_at timestamptz,
  leased_until timestamptz,
  attempt_count integer not null default 0 check (attempt_count>=0),
  started_at timestamptz,
  completed_at timestamptz,
  last_error text,
  physical_impact_asserted boolean not null default false check (physical_impact_asserted=false),
  external_action_authority boolean not null default false check (external_action_authority=false),
  official_warning_authority boolean not null default false check (official_warning_authority=false),
  canonical_identity_authority boolean not null default false check (canonical_identity_authority=false),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(watchlist_id,run_type,scheduled_for)
);

alter table ecology.ssr_environmental_monitoring_watchlist
  add constraint ssr_environmental_monitoring_watchlist_last_run_fk
  foreign key(last_successful_run_id)
  references ecology.ssr_environmental_monitoring_runs(id)
  on delete set null;

create index if not exists ix_ssr_environmental_monitoring_watchlist_due
  on ecology.ssr_environmental_monitoring_watchlist(monitoring_status,next_due_at)
  where monitoring_status='active';
create index if not exists ix_ssr_environmental_monitoring_runs_queue
  on ecology.ssr_environmental_monitoring_runs(run_status,scheduled_for,created_at)
  where run_status in ('queued','failed');
create index if not exists ix_ssr_environmental_monitoring_runs_watch
  on ecology.ssr_environmental_monitoring_runs(watchlist_id,scheduled_for desc);

alter table ecology.ssr_environmental_monitoring_watchlist enable row level security;
alter table ecology.ssr_environmental_monitoring_runs enable row level security;
drop policy if exists ssr_environmental_monitoring_watchlist_service_role on ecology.ssr_environmental_monitoring_watchlist;
create policy ssr_environmental_monitoring_watchlist_service_role
  on ecology.ssr_environmental_monitoring_watchlist
  for all to service_role using (true) with check (true);
drop policy if exists ssr_environmental_monitoring_runs_service_role on ecology.ssr_environmental_monitoring_runs;
create policy ssr_environmental_monitoring_runs_service_role
  on ecology.ssr_environmental_monitoring_runs
  for all to service_role using (true) with check (true);
revoke all on ecology.ssr_environmental_monitoring_watchlist,ecology.ssr_environmental_monitoring_runs from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_environmental_monitoring_watchlist,ecology.ssr_environmental_monitoring_runs to service_role;

create or replace function public.ssr_activate_environmental_monitoring(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_watch_count integer:=0;
  v_baseline_count integer:=0;
  v_watch_ids uuid[]:='{}'::uuid[];
begin
  if not exists(select 1 from ecology.ssr_air_events where id=p_event_id) then
    raise exception 'event not found';
  end if;
  if exists(
    select 1 from ecology.ssr_air_land_sea_fusion_assessments
    where event_id=p_event_id and governance_review_status not in ('accepted','rejected','closed')
  ) then
    raise exception 'all fusion assessments must have a governance determination before monitoring activation';
  end if;

  with accepted as (
    select
      f.id as fusion_assessment_id,
      f.event_id,
      f.exposure_candidate_id,
      f.required_domains,
      f.evidence_bundle,
      e.severity,
      e.event_time,
      x.subject_reference,
      x.subject_name,
      f.subject_infrastructure_type,
      x.reviewer,
      x.reviewed_at,
      r.recommendation,
      r.recommendation_confidence,
      r.evidence_digest_sha256
    from ecology.ssr_air_land_sea_fusion_assessments f
    join ecology.ssr_air_events e on e.id=f.event_id
    join ecology.ssr_air_event_exposure_candidates x on x.id=f.exposure_candidate_id
    left join ecology.ssr_air_land_sea_review_recommendations r
      on r.fusion_assessment_id=f.id and r.algorithm_version='ALS-REVIEW-SUPPORT-V1'
    where f.event_id=p_event_id and f.governance_review_status='accepted'
  ), upserted as (
    insert into ecology.ssr_environmental_monitoring_watchlist(
      event_id,fusion_assessment_id,exposure_candidate_id,subject_reference,subject_name,subject_infrastructure_type,
      monitoring_status,monitoring_domains,provider_plan,variable_plan,cadence_minutes,
      monitoring_window_start,monitoring_window_end,next_due_at,
      monitoring_reason,accepted_by,accepted_at,human_governance_required,
      physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
    )
    select
      a.event_id,a.fusion_assessment_id,a.exposure_candidate_id,a.subject_reference,a.subject_name,a.subject_infrastructure_type,
      'active',a.required_domains,
      jsonb_build_object(
        'AIR',jsonb_build_array('NASA-GEOS-CF','NASA-MERRA2'),
        'LAND',jsonb_build_array('SSR-EGM96'),
        'SEA',case when 'SEA'=any(a.required_domains)
          then jsonb_build_array('NOAA-RTOFS','NOAA-ERDDAP') else '[]'::jsonb end,
        'optional_secondary_validation',case when 'SEA'=any(a.required_domains)
          then jsonb_build_array('COP-MARINE') else '[]'::jsonb end
      ),
      jsonb_build_object(
        'AIR',jsonb_build_array('T','U','V','RH','H','OMEGA'),
        'LAND',jsonb_build_array('W3W','EGM96_ELEVATION','SSR_Z'),
        'SEA',case when 'SEA'=any(a.required_domains)
          then jsonb_build_array('SST','SSS','U_CURRENT','V_CURRENT','CURRENT_SPEED','SSHG') else '[]'::jsonb end
      ),
      case when a.severity='HIGH' then 60 else 180 end,
      now(),greatest(a.event_time+interval '24 hours',now()+interval '24 hours'),now()+interval '60 minutes',
      jsonb_build_object(
        'fusion_assessment_id',a.fusion_assessment_id,
        'governance_determination','ACCEPT_FOR_MONITORING',
        'recommendation',a.recommendation,
        'recommendation_confidence',a.recommendation_confidence,
        'evidence_digest_sha256',a.evidence_digest_sha256,
        'scope_boundary','environmental monitoring only; no physical-impact assertion, official warning, external action, or canonical identity mutation'
      ),
      coalesce(nullif(a.reviewer,''),'GOVERNANCE_REVIEW'),coalesce(a.reviewed_at,now()),true,
      false,false,false,false
    from accepted a
    on conflict(event_id,exposure_candidate_id) do update set
      fusion_assessment_id=excluded.fusion_assessment_id,
      subject_reference=excluded.subject_reference,
      subject_name=excluded.subject_name,
      subject_infrastructure_type=excluded.subject_infrastructure_type,
      monitoring_status='active',
      monitoring_domains=excluded.monitoring_domains,
      provider_plan=excluded.provider_plan,
      variable_plan=excluded.variable_plan,
      cadence_minutes=excluded.cadence_minutes,
      monitoring_window_end=greatest(ecology.ssr_environmental_monitoring_watchlist.monitoring_window_end,excluded.monitoring_window_end),
      next_due_at=coalesce(ecology.ssr_environmental_monitoring_watchlist.next_due_at,excluded.next_due_at),
      monitoring_reason=excluded.monitoring_reason,
      accepted_by=excluded.accepted_by,
      accepted_at=excluded.accepted_at,
      physical_impact_asserted=false,
      external_action_authority=false,
      official_warning_authority=false,
      canonical_identity_authority=false,
      updated_at=now()
    returning *
  )
  select count(*),coalesce(array_agg(id),'{}'::uuid[])
  into v_watch_count,v_watch_ids
  from upserted;

  insert into ecology.ssr_environmental_monitoring_runs(
    watchlist_id,run_type,run_status,scheduled_for,requested_domains,run_payload,result_summary,
    started_at,completed_at,
    physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
  )
  select
    w.id,'baseline','completed',now(),w.monitoring_domains,
    jsonb_build_object(
      'source','AIR-LAND-SEA fusion assessment',
      'fusion_assessment_id',w.fusion_assessment_id,
      'provider_plan',w.provider_plan,
      'variable_plan',w.variable_plan
    ),
    jsonb_build_object(
      'quality_gate','PASS_MONITORING_BASELINE_FROM_GOVERNED_FUSION',
      'evidence_bundle',(select f.evidence_bundle from ecology.ssr_air_land_sea_fusion_assessments f where f.id=w.fusion_assessment_id),
      'governance_status','accepted_for_monitoring',
      'physical_impact_asserted',false,
      'official_warning_authority',false,
      'canonical_identity_authority',false
    ),
    now(),now(),false,false,false,false
  from ecology.ssr_environmental_monitoring_watchlist w
  where w.id=any(v_watch_ids)
    and not exists(
      select 1 from ecology.ssr_environmental_monitoring_runs r
      where r.watchlist_id=w.id and r.run_type='baseline'
    );
  get diagnostics v_baseline_count=row_count;

  update ecology.ssr_environmental_monitoring_watchlist w
  set last_completed_at=coalesce((select max(r.completed_at) from ecology.ssr_environmental_monitoring_runs r where r.watchlist_id=w.id and r.run_type='baseline'),w.last_completed_at),
      last_successful_run_id=coalesce((select r.id from ecology.ssr_environmental_monitoring_runs r where r.watchlist_id=w.id and r.run_type='baseline' order by r.completed_at desc limit 1),w.last_successful_run_id),
      updated_at=now()
  where w.id=any(v_watch_ids);

  update ecology.ssr_air_event_action_items
  set action_status='completed',
      completion_payload=jsonb_build_object(
        'completion_basis','All governed AIR-LAND-SEA fusion assessments received ACCEPT_FOR_MONITORING determinations and monitoring watch entries were activated.',
        'watchlist_ids',to_jsonb(v_watch_ids),
        'physical_impact_asserted',false,
        'official_warning_authority',false,
        'canonical_identity_authority',false
      ),
      completed_at=now(),
      completed_by='SOURCEENERGY_SYSTEM',
      updated_at=now()
  where event_id=p_event_id
    and action_code='REVIEW_AIR_LAND_SEA_FUSION'
    and action_status in ('open','in_progress');

  return jsonb_build_object(
    'event_id',p_event_id,
    'watch_count',v_watch_count,
    'watchlist_ids',v_watch_ids,
    'baseline_runs_created',v_baseline_count,
    'monitoring_status','active',
    'human_governance_required',true,
    'physical_impact_asserted',false,
    'external_action_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

create or replace function public.ssr_environmental_monitoring_run_claim(
  p_run_id uuid,
  p_worker_id text,
  p_lease_seconds integer default 300
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_run ecology.ssr_environmental_monitoring_runs%rowtype;
  v_watch ecology.ssr_environmental_monitoring_watchlist%rowtype;
  v_token uuid:=gen_random_uuid();
begin
  if p_worker_id is null or length(trim(p_worker_id))=0 then raise exception 'worker id required'; end if;
  if p_lease_seconds<60 or p_lease_seconds>1800 then raise exception 'lease seconds must be 60..1800'; end if;

  update ecology.ssr_environmental_monitoring_runs
  set run_status='leased',worker_id=p_worker_id,lease_token=v_token,leased_at=now(),
      leased_until=now()+make_interval(secs=>p_lease_seconds),attempt_count=attempt_count+1,
      started_at=coalesce(started_at,now()),last_error=null,updated_at=now()
  where id=p_run_id
    and run_status in ('queued','failed')
    and scheduled_for<=now()
    and (leased_until is null or leased_until<now())
  returning * into v_run;
  if not found then raise exception 'monitoring run is not claimable'; end if;

  select * into v_watch from ecology.ssr_environmental_monitoring_watchlist where id=v_run.watchlist_id;
  return jsonb_build_object(
    'run_id',v_run.id,
    'watchlist_id',v_watch.id,
    'lease_token',v_token,
    'leased_until',v_run.leased_until,
    'attempt_number',v_run.attempt_count,
    'subject_name',v_watch.subject_name,
    'subject_reference',v_watch.subject_reference,
    'monitoring_domains',v_watch.monitoring_domains,
    'provider_plan',v_watch.provider_plan,
    'variable_plan',v_watch.variable_plan,
    'scheduled_for',v_run.scheduled_for,
    'run_payload',v_run.run_payload,
    'physical_impact_authority',false,
    'official_warning_authority',false,
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
begin
  if p_status not in ('completed','partial','failed','cancelled') then raise exception 'unsupported result status'; end if;
  select * into v_run from ecology.ssr_environmental_monitoring_runs where id=p_run_id for update;
  if not found then raise exception 'monitoring run not found'; end if;
  if v_run.lease_token is distinct from p_lease_token or v_run.worker_id is distinct from p_worker_id then
    raise exception 'lease token or worker mismatch';
  end if;

  update ecology.ssr_environmental_monitoring_runs
  set run_status=p_status,result_summary=coalesce(p_result,'{}'::jsonb),last_error=p_error,
      completed_at=case when p_status in ('completed','partial','failed','cancelled') then now() else completed_at end,
      lease_token=null,leased_until=null,updated_at=now()
  where id=p_run_id;

  if p_status in ('completed','partial') then
    update ecology.ssr_environmental_monitoring_watchlist
    set last_completed_at=now(),
        last_successful_run_id=case when p_status='completed' then p_run_id else last_successful_run_id end,
        next_due_at=now()+make_interval(mins=>cadence_minutes),
        updated_at=now()
    where id=v_run.watchlist_id;
  end if;

  return jsonb_build_object(
    'run_id',p_run_id,'watchlist_id',v_run.watchlist_id,'run_status',p_status,
    'physical_impact_asserted',false,'external_action_authority',false,
    'official_warning_authority',false,'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_activate_environmental_monitoring(uuid) from public,anon,authenticated;
revoke all on function public.ssr_environmental_monitoring_run_claim(uuid,text,integer) from public,anon,authenticated;
revoke all on function public.ssr_environmental_monitoring_run_record_result(uuid,uuid,text,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.ssr_activate_environmental_monitoring(uuid) to service_role;
grant execute on function public.ssr_environmental_monitoring_run_claim(uuid,text,integer) to service_role;
grant execute on function public.ssr_environmental_monitoring_run_record_result(uuid,uuid,text,text,jsonb,text) to service_role;

create or replace view ecology.ssr_environmental_monitoring_portfolio as
select
  w.id as watchlist_id,w.event_id,w.fusion_assessment_id,w.exposure_candidate_id,
  w.subject_name,w.subject_infrastructure_type,w.monitoring_status,w.monitoring_domains,
  w.provider_plan,w.variable_plan,w.cadence_minutes,w.monitoring_window_start,w.monitoring_window_end,
  w.next_due_at,w.last_enqueued_at,w.last_completed_at,w.last_successful_run_id,
  w.accepted_by,w.accepted_at,
  case
    when w.monitoring_status='closed' then 'CLOSED'
    when w.monitoring_window_end<=now() then 'WINDOW_EXPIRED'
    when w.next_due_at is not null and w.next_due_at<=now() then 'MONITORING_DUE'
    else 'ACTIVE'
  end as monitoring_state,
  coalesce((select count(*) from ecology.ssr_environmental_monitoring_runs r where r.watchlist_id=w.id),0)::integer as run_count,
  coalesce((select count(*) from ecology.ssr_environmental_monitoring_runs r where r.watchlist_id=w.id and r.run_status='queued'),0)::integer as queued_run_count,
  false::boolean as physical_impact_asserted,
  false::boolean as official_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_environmental_monitoring_watchlist w;

create or replace view ecology.ssr_environmental_monitoring_due as
select *
from ecology.ssr_environmental_monitoring_portfolio
where monitoring_status='active'
  and monitoring_window_end>now()
  and next_due_at is not null
  and next_due_at<=now();

comment on table ecology.ssr_environmental_monitoring_watchlist is 'Governed environmental monitoring watchlist created from accepted AIR-LAND-SEA fusion assessments. Watch activation indicates monitoring relevance only and never physical impact, official warning authority, external action authority, or canonical identity mutation.';
comment on table ecology.ssr_environmental_monitoring_runs is 'Leased monitoring execution ledger. Results are environmental evidence only and remain subject to human governance.';
