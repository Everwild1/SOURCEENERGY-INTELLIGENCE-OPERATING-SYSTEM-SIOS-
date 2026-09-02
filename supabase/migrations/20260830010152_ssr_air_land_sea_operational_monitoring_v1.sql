create table if not exists ecology.ssr_environmental_monitoring_plans (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  fusion_assessment_id uuid not null references ecology.ssr_air_land_sea_fusion_assessments(id) on delete restrict,
  exposure_candidate_id uuid not null references ecology.ssr_air_event_exposure_candidates(id) on delete restrict,
  governance_decision_id uuid not null references ecology.ssr_air_event_decisions(id) on delete restrict,
  plan_code text not null unique,
  plan_status text not null default 'active' check (plan_status in ('active','review_required','completed','cancelled')),
  monitoring_mode text not null default 'forecast_and_post_event_verification',
  required_domains text[] not null,
  window_start timestamptz not null,
  event_time timestamptz not null,
  forecast_window_end timestamptz not null,
  post_event_verification_due timestamptz not null,
  cadence_minutes integer not null default 60 check (cadence_minutes between 15 and 1440),
  activation_actor text not null,
  activation_source text not null default 'CONTINUE_MONITORING_DECISION',
  closure_criteria jsonb not null default '{}'::jsonb,
  escalation_criteria jsonb not null default '{}'::jsonb,
  last_refreshed_at timestamptz,
  human_review_required boolean not null default true,
  impact_conclusion text not null default 'NOT_ASSESSED' check (impact_conclusion in ('NOT_ASSESSED','NO_IMPACT_EVIDENCE','POTENTIAL_RELEVANCE','VALIDATED_RELEVANCE')),
  physical_impact_asserted boolean not null default false,
  external_action_authority boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(event_id,exposure_candidate_id),
  check (physical_impact_asserted=false),
  check (external_action_authority=false),
  check (official_warning_authority=false),
  check (canonical_identity_authority=false),
  check (window_start <= event_time and event_time <= forecast_window_end),
  check (forecast_window_end < post_event_verification_due)
);

create index if not exists ix_ssr_environmental_monitoring_plans_status
  on ecology.ssr_environmental_monitoring_plans(plan_status,event_time,post_event_verification_due);

create table if not exists ecology.ssr_environmental_monitoring_checkpoints (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references ecology.ssr_environmental_monitoring_plans(id) on delete restrict,
  scheduled_time timestamptz not null,
  checkpoint_kind text not null check (checkpoint_kind in ('PRE_EVENT_FORECAST','EVENT_TIME_FORECAST','POST_EVENT_FORECAST','POST_EVENT_VERIFICATION')),
  required_domains text[] not null,
  checkpoint_status text not null default 'pending' check (checkpoint_status in ('pending','evidence_available','review_required','reviewed','closed')),
  air_profile_id uuid references ecology.ssr_air_profiles(id) on delete restrict,
  land_anchor_id uuid references ecology.ssr_anchor_candidate_registry(id) on delete restrict,
  sea_observation_ids uuid[] not null default '{}'::uuid[],
  evidence_quality_gate text,
  evidence_summary jsonb not null default '{}'::jsonb,
  review_status text not null default 'not_reviewed' check (review_status in ('not_reviewed','reviewed','validation_requested')),
  reviewer text,
  reviewed_at timestamptz,
  impact_conclusion text not null default 'NOT_ASSESSED' check (impact_conclusion in ('NOT_ASSESSED','NO_IMPACT_EVIDENCE','POTENTIAL_RELEVANCE','VALIDATED_RELEVANCE')),
  physical_impact_asserted boolean not null default false,
  external_action_authority boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(plan_id,scheduled_time,checkpoint_kind),
  check (physical_impact_asserted=false),
  check (external_action_authority=false),
  check (official_warning_authority=false),
  check (canonical_identity_authority=false)
);

create index if not exists ix_ssr_environmental_monitoring_checkpoints_queue
  on ecology.ssr_environmental_monitoring_checkpoints(checkpoint_status,scheduled_time);
create index if not exists ix_ssr_environmental_monitoring_checkpoints_plan
  on ecology.ssr_environmental_monitoring_checkpoints(plan_id,scheduled_time);

create table if not exists ecology.ssr_environmental_monitoring_review_audit (
  id bigserial primary key,
  plan_id uuid not null references ecology.ssr_environmental_monitoring_plans(id) on delete restrict,
  checkpoint_id uuid references ecology.ssr_environmental_monitoring_checkpoints(id) on delete restrict,
  review_action text not null,
  status_before text,
  status_after text,
  actor text not null,
  review_notes jsonb not null default '{}'::jsonb,
  physical_impact_asserted boolean not null default false,
  external_action_authority boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  recorded_at timestamptz not null default now(),
  check (physical_impact_asserted=false),
  check (external_action_authority=false),
  check (official_warning_authority=false),
  check (canonical_identity_authority=false)
);

alter table ecology.ssr_environmental_monitoring_plans enable row level security;
alter table ecology.ssr_environmental_monitoring_checkpoints enable row level security;
alter table ecology.ssr_environmental_monitoring_review_audit enable row level security;

drop policy if exists ssr_environmental_monitoring_plans_service_role on ecology.ssr_environmental_monitoring_plans;
create policy ssr_environmental_monitoring_plans_service_role on ecology.ssr_environmental_monitoring_plans
  for all to service_role using (true) with check (true);
drop policy if exists ssr_environmental_monitoring_checkpoints_service_role on ecology.ssr_environmental_monitoring_checkpoints;
create policy ssr_environmental_monitoring_checkpoints_service_role on ecology.ssr_environmental_monitoring_checkpoints
  for all to service_role using (true) with check (true);
drop policy if exists ssr_environmental_monitoring_review_audit_service_role on ecology.ssr_environmental_monitoring_review_audit;
create policy ssr_environmental_monitoring_review_audit_service_role on ecology.ssr_environmental_monitoring_review_audit
  for select to service_role using (true);

revoke all on ecology.ssr_environmental_monitoring_plans,ecology.ssr_environmental_monitoring_checkpoints,ecology.ssr_environmental_monitoring_review_audit from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_environmental_monitoring_plans,ecology.ssr_environmental_monitoring_checkpoints to service_role;
grant select on ecology.ssr_environmental_monitoring_review_audit to service_role;

create or replace function ecology.block_ssr_environmental_monitoring_review_audit_mutation()
returns trigger
language plpgsql
set search_path=ecology,public,pg_temp
as $$
begin
  raise exception 'ssr_environmental_monitoring_review_audit is append-only';
end $$;

drop trigger if exists trg_block_ssr_environmental_monitoring_review_audit_mutation on ecology.ssr_environmental_monitoring_review_audit;
create trigger trg_block_ssr_environmental_monitoring_review_audit_mutation
before update or delete on ecology.ssr_environmental_monitoring_review_audit
for each row execute function ecology.block_ssr_environmental_monitoring_review_audit_mutation();

create or replace function ecology.ssr_refresh_environmental_monitoring_internal(p_event_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
declare
  v_row record;
  v_air_profile_id uuid;
  v_air_summary jsonb;
  v_air_ok boolean;
  v_land_anchor_id uuid;
  v_land_summary jsonb;
  v_land_ok boolean;
  v_sea_ids uuid[];
  v_sea_summary jsonb;
  v_sea_height_ok boolean;
  v_sea_state_ok boolean;
  v_sea_ok boolean;
  v_satisfied text[];
  v_missing text[];
  v_required text[];
  v_all_ok boolean;
  v_checkpoint_status text;
  v_count integer:=0;
  v_evidence_count integer:=0;
  v_review_count integer:=0;
begin
  for v_row in
    select c.*,p.event_id,p.event_time as plan_event_time,p.exposure_candidate_id,
           p.plan_status,p.required_domains as plan_required_domains,
           x.subject_type,x.subject_reference,x.subject_name,
           e.provider_code as air_provider_code
    from ecology.ssr_environmental_monitoring_checkpoints c
    join ecology.ssr_environmental_monitoring_plans p on p.id=c.plan_id
    join ecology.ssr_air_event_exposure_candidates x on x.id=p.exposure_candidate_id
    join ecology.ssr_air_events e on e.id=p.event_id
    where p.plan_status in ('active','review_required')
      and (p_event_id is null or p.event_id=p_event_id)
    order by c.scheduled_time
  loop
    v_count:=v_count+1;
    v_required:=v_row.required_domains;

    select ap.id,
           jsonb_build_object(
             'profile_id',ap.id,
             'provider_code',ap.provider_code,
             'dataset_name',ap.dataset_name,
             'evidence_time',ap.evidence_time,
             'quality_gate',ap.quality_gate,
             'trajectory_metrics',(select to_jsonb(m) from ecology.ssr_air_profile_trajectory_metrics m where m.profile_id=ap.id),
             'signal_counts',jsonb_build_object(
               'high',(select count(*) from ecology.ssr_air_operational_change_signals s where s.profile_id=ap.id and s.operational_intensity='HIGH'),
               'elevated',(select count(*) from ecology.ssr_air_operational_change_signals s where s.profile_id=ap.id and s.operational_intensity='ELEVATED')
             )
           )
      into v_air_profile_id,v_air_summary
    from ecology.ssr_air_profiles ap
    where ap.provider_code=v_row.air_provider_code
      and ap.evidence_time=v_row.scheduled_time
      and ap.quality_gate in ('PASS_GEOS_CF_PROFILE','PASS_MERRA2_PROFILE')
    order by ap.created_at desc
    limit 1;
    v_air_ok:=v_air_profile_id is not null;

    v_land_anchor_id:=null;
    v_land_summary:='{}'::jsonb;
    v_land_ok:=false;
    if v_row.subject_type='SSR_ANCHOR_CANDIDATE' and v_row.subject_reference ~ '^[0-9a-fA-F-]{36}$' then
      select a.id,
             jsonb_build_object(
               'anchor_id',a.id,
               'infrastructure_name',a.infrastructure_name,
               'canonical_address',a.canonical_address,
               'cube_uid',a.cube_uid,
               'elevation_m_egm96',a.elevation_m_egm96,
               'z_index',a.z_index,
               'canonicalization_status',a.canonicalization_status,
               'promotion_eligible',a.promotion_eligible,
               'source_verification_status',a.source_verification_status,
               'source_reconciliation_status',a.source_reconciliation_status
             )
        into v_land_anchor_id,v_land_summary
      from ecology.ssr_anchor_candidate_registry a
      where a.id=v_row.subject_reference::uuid;
      v_land_ok:=v_land_anchor_id is not null
        and coalesce(v_land_summary->>'canonicalization_status','')='promoted'
        and coalesce((v_land_summary->>'promotion_eligible')::boolean,false)=true;
    end if;

    select coalesce(array_agg(o.id order by o.observed_at),'{}'::uuid[]),
           coalesce(jsonb_agg(jsonb_build_object(
             'observation_id',o.id,
             'provider_code',o.provider_code,
             'dataset_id',o.dataset_id,
             'observed_at',o.observed_at,
             'quality_gate',o.quality_gate,
             'grid_latitude',o.grid_latitude,
             'grid_longitude',o.grid_longitude,
             'variables',o.variables,
             'retrieval_metadata',o.retrieval_metadata
           ) order by o.observed_at),'[]'::jsonb),
           coalesce(bool_or(o.variables ? 'sea_surface_height_relative_to_geoid_m'),false),
           coalesce(bool_or(
             o.variables ? 'sea_surface_temperature_c'
             and o.variables ? 'sea_surface_salinity_psu'
             and o.variables ? 'u_velocity_mps'
             and o.variables ? 'v_velocity_mps'
           ),false)
      into v_sea_ids,v_sea_summary,v_sea_height_ok,v_sea_state_ok
    from ecology.ssr_sea_observations o
    where o.event_time_reference=v_row.plan_event_time
      and o.provider_code='NOAA-RTOFS'
      and (
        (v_row.checkpoint_kind='EVENT_TIME_FORECAST' and o.observed_at between v_row.plan_event_time-interval '1 hour' and v_row.plan_event_time+interval '1 hour')
        or
        (v_row.checkpoint_kind<>'EVENT_TIME_FORECAST' and o.observed_at between v_row.scheduled_time-interval '1 hour' and v_row.scheduled_time+interval '1 hour')
      );
    v_sea_ok:=v_sea_height_ok and v_sea_state_ok;

    v_satisfied:='{}'::text[];
    if v_air_ok then v_satisfied:=array_append(v_satisfied,'AIR'); end if;
    if v_land_ok then v_satisfied:=array_append(v_satisfied,'LAND'); end if;
    if v_sea_ok then v_satisfied:=array_append(v_satisfied,'SEA'); end if;

    select coalesce(array_agg(d),'{}'::text[]) into v_missing
    from unnest(v_required) d
    where not (d=any(v_satisfied));

    v_all_ok:=cardinality(v_missing)=0;
    if v_all_ok then
      v_checkpoint_status:='evidence_available';
      v_evidence_count:=v_evidence_count+1;
    elsif v_row.scheduled_time>now() then
      v_checkpoint_status:='pending';
    else
      v_checkpoint_status:='review_required';
      v_review_count:=v_review_count+1;
    end if;

    update ecology.ssr_environmental_monitoring_checkpoints
    set checkpoint_status=v_checkpoint_status,
        air_profile_id=v_air_profile_id,
        land_anchor_id=v_land_anchor_id,
        sea_observation_ids=v_sea_ids,
        evidence_quality_gate=case when v_all_ok then 'PASS_MONITORING_EVIDENCE_LINKAGE' else 'PARTIAL_MONITORING_EVIDENCE' end,
        evidence_summary=jsonb_build_object(
          'subject_name',v_row.subject_name,
          'required_domains',v_required,
          'satisfied_domains',v_satisfied,
          'missing_required_domains',v_missing,
          'air',coalesce(v_air_summary,'{}'::jsonb),
          'land',coalesce(v_land_summary,'{}'::jsonb),
          'sea',coalesce(v_sea_summary,'[]'::jsonb),
          'evidence_class',case when v_row.checkpoint_kind='POST_EVENT_VERIFICATION' then 'post_event_verification' else 'forecast_monitoring' end,
          'physical_impact_asserted',false,
          'official_warning_authority',false,
          'canonical_identity_authority',false
        ),
        physical_impact_asserted=false,
        external_action_authority=false,
        official_warning_authority=false,
        canonical_identity_authority=false,
        updated_at=now()
    where id=v_row.id;
  end loop;

  update ecology.ssr_environmental_monitoring_plans p
  set plan_status=case
        when p.plan_status in ('completed','cancelled') then p.plan_status
        when exists(select 1 from ecology.ssr_environmental_monitoring_checkpoints c where c.plan_id=p.id and c.checkpoint_status='review_required') then 'review_required'
        else 'active'
      end,
      last_refreshed_at=now(),
      updated_at=now()
  where p.plan_status in ('active','review_required')
    and (p_event_id is null or p.event_id=p_event_id);

  return jsonb_build_object(
    'event_id',p_event_id,
    'checkpoints_processed',v_count,
    'evidence_available_count',v_evidence_count,
    'review_required_count',v_review_count,
    'physical_impact_asserted',false,
    'external_action_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

create or replace function public.ssr_initialize_environmental_monitoring(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_event ecology.ssr_air_events%rowtype;
  v_decision ecology.ssr_air_event_decisions%rowtype;
  v_fusion record;
  v_plan_id uuid;
  v_plan_count integer:=0;
  v_checkpoint_count integer:=0;
  v_time timestamptz;
  v_required text[];
  v_kind text;
  v_refresh jsonb;
begin
  select * into v_event from ecology.ssr_air_events where id=p_event_id;
  if not found then raise exception 'event not found'; end if;

  select * into v_decision
  from ecology.ssr_air_event_decisions
  where event_id=p_event_id and decision_type='CONTINUE_MONITORING'
  order by created_at desc limit 1;
  if not found then raise exception 'CONTINUE_MONITORING governance decision required'; end if;

  for v_fusion in
    select f.*,x.subject_name
    from ecology.ssr_air_land_sea_fusion_assessments f
    join ecology.ssr_air_event_exposure_candidates x on x.id=f.exposure_candidate_id
    where f.event_id=p_event_id
      and f.governance_review_status='accepted'
      and cardinality(f.missing_required_domains)=0
  loop
    insert into ecology.ssr_environmental_monitoring_plans(
      event_id,fusion_assessment_id,exposure_candidate_id,governance_decision_id,plan_code,
      plan_status,monitoring_mode,required_domains,window_start,event_time,forecast_window_end,
      post_event_verification_due,cadence_minutes,activation_actor,activation_source,
      closure_criteria,escalation_criteria,human_review_required,impact_conclusion,
      physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
    ) values (
      p_event_id,v_fusion.id,v_fusion.exposure_candidate_id,v_decision.id,
      'ENV-MON-'||substr(md5(p_event_id::text||'|'||v_fusion.exposure_candidate_id::text),1,20),
      'active','forecast_and_post_event_verification',v_fusion.required_domains,
      v_event.event_time-interval '4 hours',v_event.event_time,v_event.event_time+interval '4 hours',
      v_event.event_time+interval '24 hours',60,v_decision.actor,'CONTINUE_MONITORING_DECISION',
      jsonb_build_object(
        'all_required_forecast_checkpoints_linked',true,
        'post_event_verification_recorded',true,
        'human_completion_decision_required',true,
        'no_physical_impact_assumption',true
      ),
      jsonb_build_object(
        'new_high_air_signal','internal_governance_review',
        'missing_required_checkpoint_after_due_time','internal_governance_review',
        'sea_event_alignment_failure','internal_governance_review',
        'external_action_automatic',false
      ),
      true,'POTENTIAL_RELEVANCE',false,false,false,false
    )
    on conflict(event_id,exposure_candidate_id) do update set
      fusion_assessment_id=excluded.fusion_assessment_id,
      governance_decision_id=excluded.governance_decision_id,
      required_domains=excluded.required_domains,
      activation_actor=excluded.activation_actor,
      closure_criteria=excluded.closure_criteria,
      escalation_criteria=excluded.escalation_criteria,
      physical_impact_asserted=false,
      external_action_authority=false,
      official_warning_authority=false,
      canonical_identity_authority=false,
      updated_at=now()
    returning id into v_plan_id;
    v_plan_count:=v_plan_count+1;

    v_time:=v_event.event_time-interval '4 hours';
    while v_time<=v_event.event_time+interval '4 hours' loop
      v_kind:=case
        when v_time<v_event.event_time then 'PRE_EVENT_FORECAST'
        when v_time=v_event.event_time then 'EVENT_TIME_FORECAST'
        else 'POST_EVENT_FORECAST'
      end;
      v_required:=case
        when v_time=v_event.event_time then v_fusion.required_domains
        else array['AIR','LAND']::text[]
      end;
      insert into ecology.ssr_environmental_monitoring_checkpoints(
        plan_id,scheduled_time,checkpoint_kind,required_domains,checkpoint_status,
        physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
      ) values (v_plan_id,v_time,v_kind,v_required,'pending',false,false,false,false)
      on conflict(plan_id,scheduled_time,checkpoint_kind) do nothing;
      if found then v_checkpoint_count:=v_checkpoint_count+1; end if;
      v_time:=v_time+interval '1 hour';
    end loop;

    insert into ecology.ssr_environmental_monitoring_checkpoints(
      plan_id,scheduled_time,checkpoint_kind,required_domains,checkpoint_status,
      physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
    ) values (
      v_plan_id,v_event.event_time+interval '24 hours','POST_EVENT_VERIFICATION',v_fusion.required_domains,'pending',
      false,false,false,false
    )
    on conflict(plan_id,scheduled_time,checkpoint_kind) do nothing;
    if found then v_checkpoint_count:=v_checkpoint_count+1; end if;
  end loop;

  v_refresh:=ecology.ssr_refresh_environmental_monitoring_internal(p_event_id);
  return jsonb_build_object(
    'event_id',p_event_id,
    'monitoring_plans_initialized',v_plan_count,
    'checkpoints_seeded',v_checkpoint_count,
    'refresh',v_refresh,
    'physical_impact_asserted',false,
    'external_action_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

create or replace function public.ssr_refresh_environmental_monitoring(p_event_id uuid default null)
returns jsonb
language sql
security definer
set search_path=public,ecology,pg_temp
as $$ select ecology.ssr_refresh_environmental_monitoring_internal(p_event_id) $$;

create or replace function public.ssr_environmental_monitoring_review(
  p_plan_id uuid,
  p_action text,
  p_actor text,
  p_review_notes jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_plan ecology.ssr_environmental_monitoring_plans%rowtype;
  v_before text;
  v_after text;
begin
  if p_actor is null or length(trim(p_actor))=0 then raise exception 'actor required'; end if;
  if p_action not in ('CONTINUE_MONITORING','REQUEST_VALIDATION','COMPLETE_MONITORING','CANCEL_MONITORING') then
    raise exception 'unsupported monitoring review action';
  end if;

  select * into v_plan from ecology.ssr_environmental_monitoring_plans where id=p_plan_id for update;
  if not found then raise exception 'monitoring plan not found'; end if;
  if v_plan.plan_status in ('completed','cancelled') then raise exception 'terminal monitoring plan cannot transition'; end if;
  v_before:=v_plan.plan_status;

  if p_action='COMPLETE_MONITORING' and exists(
    select 1 from ecology.ssr_environmental_monitoring_checkpoints c
    where c.plan_id=p_plan_id and c.checkpoint_kind='POST_EVENT_VERIFICATION'
      and c.checkpoint_status not in ('evidence_available','reviewed','closed')
  ) then
    raise exception 'post-event verification checkpoint is not ready';
  end if;

  v_after:=case
    when p_action='CONTINUE_MONITORING' then 'active'
    when p_action='REQUEST_VALIDATION' then 'review_required'
    when p_action='COMPLETE_MONITORING' then 'completed'
    when p_action='CANCEL_MONITORING' then 'cancelled'
  end;

  update ecology.ssr_environmental_monitoring_plans
  set plan_status=v_after,
      impact_conclusion=case
        when p_action='COMPLETE_MONITORING' and coalesce(p_review_notes->>'impact_conclusion','')='NO_IMPACT_EVIDENCE' then 'NO_IMPACT_EVIDENCE'
        else impact_conclusion
      end,
      physical_impact_asserted=false,
      external_action_authority=false,
      official_warning_authority=false,
      canonical_identity_authority=false,
      updated_at=now()
  where id=p_plan_id;

  insert into ecology.ssr_environmental_monitoring_review_audit(
    plan_id,review_action,status_before,status_after,actor,review_notes,
    physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
  ) values (p_plan_id,p_action,v_before,v_after,p_actor,coalesce(p_review_notes,'{}'::jsonb),false,false,false,false);

  return jsonb_build_object(
    'plan_id',p_plan_id,
    'review_action',p_action,
    'status_before',v_before,
    'status_after',v_after,
    'physical_impact_asserted',false,
    'external_action_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_initialize_environmental_monitoring(uuid) from public,anon,authenticated;
revoke all on function public.ssr_refresh_environmental_monitoring(uuid) from public,anon,authenticated;
revoke all on function public.ssr_environmental_monitoring_review(uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.ssr_initialize_environmental_monitoring(uuid) to service_role;
grant execute on function public.ssr_refresh_environmental_monitoring(uuid) to service_role;
grant execute on function public.ssr_environmental_monitoring_review(uuid,text,text,jsonb) to service_role;

create or replace view ecology.ssr_environmental_monitoring_status as
select
  p.id as monitoring_plan_id,
  p.event_id,
  p.plan_code,
  p.plan_status,
  p.monitoring_mode,
  p.required_domains,
  p.window_start,
  p.event_time,
  p.forecast_window_end,
  p.post_event_verification_due,
  p.activation_actor,
  p.last_refreshed_at,
  x.id as exposure_candidate_id,
  x.subject_name,
  x.review_status as exposure_review_status,
  x.impact_status as exposure_impact_status,
  count(c.id)::integer as checkpoint_count,
  count(c.id) filter(where c.checkpoint_status='evidence_available')::integer as evidence_available_count,
  count(c.id) filter(where c.checkpoint_status='pending')::integer as pending_count,
  count(c.id) filter(where c.checkpoint_status='review_required')::integer as review_required_count,
  count(c.id) filter(where c.checkpoint_kind='POST_EVENT_VERIFICATION' and c.checkpoint_status in ('evidence_available','reviewed','closed'))::integer as post_event_verification_complete_count,
  min(c.scheduled_time) filter(where c.checkpoint_status in ('pending','review_required')) as next_open_checkpoint_time,
  case
    when p.plan_status='completed' then 'COMPLETED'
    when p.plan_status='cancelled' then 'CANCELLED'
    when count(c.id) filter(where c.checkpoint_status='review_required')>0 then 'REVIEW_REQUIRED'
    when count(c.id) filter(where c.checkpoint_kind='POST_EVENT_VERIFICATION' and c.checkpoint_status in ('evidence_available','reviewed','closed'))=0 then 'POST_EVENT_VERIFICATION_PENDING'
    else 'ACTIVE'
  end as monitoring_state,
  false::boolean as physical_impact_asserted,
  false::boolean as external_action_authority,
  false::boolean as official_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_environmental_monitoring_plans p
join ecology.ssr_air_event_exposure_candidates x on x.id=p.exposure_candidate_id
left join ecology.ssr_environmental_monitoring_checkpoints c on c.plan_id=p.id
group by p.id,x.id,x.subject_name,x.review_status,x.impact_status;

create or replace view ecology.ssr_environmental_monitoring_checkpoint_queue as
select
  c.id as checkpoint_id,
  c.plan_id,
  p.event_id,
  x.subject_name,
  c.scheduled_time,
  c.checkpoint_kind,
  c.required_domains,
  c.checkpoint_status,
  c.evidence_quality_gate,
  c.air_profile_id,
  c.land_anchor_id,
  c.sea_observation_ids,
  c.review_status,
  c.impact_conclusion,
  c.updated_at,
  false::boolean as physical_impact_asserted,
  false::boolean as official_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_environmental_monitoring_checkpoints c
join ecology.ssr_environmental_monitoring_plans p on p.id=c.plan_id
join ecology.ssr_air_event_exposure_candidates x on x.id=p.exposure_candidate_id
where p.plan_status in ('active','review_required')
order by c.scheduled_time,x.subject_name;

create or replace view ecology.ssr_environmental_monitoring_dashboard as
select
  e.id as event_id,
  e.severity,
  e.lifecycle_status,
  e.event_time,
  count(s.monitoring_plan_id)::integer as plan_count,
  count(*) filter(where s.plan_status='active')::integer as active_plan_count,
  count(*) filter(where s.plan_status='review_required')::integer as review_required_plan_count,
  sum(s.checkpoint_count)::integer as checkpoint_count,
  sum(s.evidence_available_count)::integer as evidence_available_count,
  sum(s.pending_count)::integer as pending_count,
  sum(s.review_required_count)::integer as review_required_checkpoint_count,
  min(s.next_open_checkpoint_time) as next_open_checkpoint_time,
  bool_and(s.physical_impact_asserted=false) as impact_boundary_preserved,
  bool_and(s.official_warning_authority=false) as warning_boundary_preserved,
  bool_and(s.canonical_identity_authority=false) as identity_boundary_preserved
from ecology.ssr_air_events e
join ecology.ssr_environmental_monitoring_status s on s.event_id=e.id
group by e.id,e.severity,e.lifecycle_status,e.event_time;

create or replace function public.ssr_environmental_monitoring_maintenance()
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare v_result jsonb;
begin
  v_result:=ecology.ssr_refresh_environmental_monitoring_internal(null);
  return jsonb_build_object(
    'generated_at',now(),
    'refresh',v_result,
    'external_data_acquisition_performed',false,
    'physical_impact_asserted',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;
revoke all on function public.ssr_environmental_monitoring_maintenance() from public,anon,authenticated;
grant execute on function public.ssr_environmental_monitoring_maintenance() to service_role;

do $$
declare v_job_id bigint;
begin
  if exists(select 1 from pg_namespace where nspname='cron') then
    for v_job_id in select jobid from cron.job where jobname='ssr-environmental-monitoring-maintenance-v1' loop
      perform cron.unschedule(v_job_id);
    end loop;
    perform cron.schedule(
      'ssr-environmental-monitoring-maintenance-v1',
      '*/15 * * * *',
      'select public.ssr_environmental_monitoring_maintenance();'
    );
  end if;
end $$;

comment on table ecology.ssr_environmental_monitoring_plans is 'Governed AIR-LAND-SEA monitoring plans created from accepted fusion assessments and an explicit CONTINUE_MONITORING decision. Plans do not assert physical impact or confer official warning, external action, or canonical identity authority.';
comment on table ecology.ssr_environmental_monitoring_checkpoints is 'Evidence-linkage checkpoints for forecast-window and post-event verification. Forecast evidence is not treated as observed physical impact.';
comment on view ecology.ssr_environmental_monitoring_dashboard is 'Operational monitoring control surface with explicit authority boundaries and no automatic external action.';
