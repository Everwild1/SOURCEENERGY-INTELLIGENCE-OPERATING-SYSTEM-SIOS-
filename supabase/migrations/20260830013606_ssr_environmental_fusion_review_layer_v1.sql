create table if not exists ecology.ssr_environmental_fusion_cases (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  exposure_candidate_id uuid not null references ecology.ssr_air_event_exposure_candidates(id) on delete restrict,
  subject_type text not null,
  subject_reference text not null,
  subject_name text,
  fusion_scope text not null check (fusion_scope in ('AIR_LAND','AIR_LAND_SEA','AIR_ONLY')),
  air_evidence_status text not null check (air_evidence_status in ('READY','PARTIAL','MISSING')),
  land_evidence_status text not null check (land_evidence_status in ('READY','PARTIAL','MISSING','NOT_APPLICABLE')),
  sea_evidence_status text not null check (sea_evidence_status in ('READY','PARTIAL','MISSING','NOT_APPLICABLE')),
  overall_readiness_status text not null check (overall_readiness_status in ('READY_FOR_HUMAN_RELEVANCE_REVIEW','PARTIAL_EVIDENCE','EVIDENCE_GAP')),
  review_status text not null default 'queued' check (review_status in ('queued','in_review','completed','closed')),
  operational_relevance_status text not null default 'NOT_ASSESSED' check (operational_relevance_status in ('NOT_ASSESSED','REQUIRES_FURTHER_VALIDATION','POTENTIAL_RELEVANCE','NO_OPERATIONAL_RELEVANCE','OPERATIONALLY_RELEVANT')),
  air_snapshot jsonb not null default '{}'::jsonb,
  land_snapshot jsonb not null default '{}'::jsonb,
  sea_snapshot jsonb not null default '{}'::jsonb,
  evidence_manifest jsonb not null default '[]'::jsonb,
  reviewer text,
  reviewed_at timestamptz,
  review_conclusion jsonb not null default '{}'::jsonb,
  physical_impact_asserted boolean not null default false,
  external_action_authority boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(event_id,exposure_candidate_id),
  constraint ssr_fusion_no_physical_impact_assertion check (physical_impact_asserted=false),
  constraint ssr_fusion_no_external_action_authority check (external_action_authority=false),
  constraint ssr_fusion_no_official_warning_authority check (official_warning_authority=false),
  constraint ssr_fusion_no_canonical_identity_authority check (canonical_identity_authority=false)
);

create index if not exists ix_ssr_environmental_fusion_review_queue
  on ecology.ssr_environmental_fusion_cases(review_status,overall_readiness_status,created_at);
create index if not exists ix_ssr_environmental_fusion_event
  on ecology.ssr_environmental_fusion_cases(event_id,exposure_candidate_id);

alter table ecology.ssr_environmental_fusion_cases enable row level security;
drop policy if exists ssr_environmental_fusion_cases_service_role on ecology.ssr_environmental_fusion_cases;
create policy ssr_environmental_fusion_cases_service_role on ecology.ssr_environmental_fusion_cases
  for all to service_role using (true) with check (true);
revoke all on ecology.ssr_environmental_fusion_cases from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_environmental_fusion_cases to service_role;

create table if not exists ecology.ssr_environmental_fusion_case_audit (
  id bigserial primary key,
  fusion_case_id uuid not null references ecology.ssr_environmental_fusion_cases(id) on delete restrict,
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  audit_action text not null,
  previous_review_status text,
  new_review_status text,
  previous_relevance_status text,
  new_relevance_status text,
  actor text,
  audit_payload jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);

create index if not exists ix_ssr_environmental_fusion_audit_case
  on ecology.ssr_environmental_fusion_case_audit(fusion_case_id,recorded_at desc);

alter table ecology.ssr_environmental_fusion_case_audit enable row level security;
drop policy if exists ssr_environmental_fusion_case_audit_service_role_select on ecology.ssr_environmental_fusion_case_audit;
create policy ssr_environmental_fusion_case_audit_service_role_select on ecology.ssr_environmental_fusion_case_audit
  for select to service_role using (true);
revoke all on ecology.ssr_environmental_fusion_case_audit from anon,authenticated;
grant select on ecology.ssr_environmental_fusion_case_audit to service_role;

create or replace function ecology.audit_ssr_environmental_fusion_case()
returns trigger
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
begin
  if tg_op='INSERT' then
    insert into ecology.ssr_environmental_fusion_case_audit(
      fusion_case_id,event_id,audit_action,previous_review_status,new_review_status,
      previous_relevance_status,new_relevance_status,actor,audit_payload
    ) values (
      new.id,new.event_id,'materialized',null,new.review_status,null,new.operational_relevance_status,
      'SSR_ENVIRONMENTAL_FUSION_CONTROL',
      jsonb_build_object('fusion_scope',new.fusion_scope,'overall_readiness_status',new.overall_readiness_status,
                         'air_evidence_status',new.air_evidence_status,'land_evidence_status',new.land_evidence_status,
                         'sea_evidence_status',new.sea_evidence_status)
    );
    return new;
  end if;

  if tg_op='UPDATE' then
    insert into ecology.ssr_environmental_fusion_case_audit(
      fusion_case_id,event_id,audit_action,previous_review_status,new_review_status,
      previous_relevance_status,new_relevance_status,actor,audit_payload
    ) values (
      new.id,new.event_id,
      case when old.review_status is distinct from new.review_status or old.operational_relevance_status is distinct from new.operational_relevance_status
           then 'governance_transition' else 'evidence_refresh' end,
      old.review_status,new.review_status,old.operational_relevance_status,new.operational_relevance_status,
      coalesce(new.reviewer,'SSR_ENVIRONMENTAL_FUSION_CONTROL'),
      jsonb_build_object('old_readiness',old.overall_readiness_status,'new_readiness',new.overall_readiness_status,
                         'review_conclusion',new.review_conclusion)
    );
    return new;
  end if;
  return new;
end $$;

drop trigger if exists trg_ssr_environmental_fusion_case_audit on ecology.ssr_environmental_fusion_cases;
create trigger trg_ssr_environmental_fusion_case_audit
after insert or update on ecology.ssr_environmental_fusion_cases
for each row execute function ecology.audit_ssr_environmental_fusion_case();

create or replace function ecology.block_ssr_environmental_fusion_audit_mutation()
returns trigger
language plpgsql
set search_path=ecology,public,pg_temp
as $$
begin
  raise exception 'ssr_environmental_fusion_case_audit is append-only';
end $$;

drop trigger if exists trg_block_ssr_environmental_fusion_audit_mutation on ecology.ssr_environmental_fusion_case_audit;
create trigger trg_block_ssr_environmental_fusion_audit_mutation
before update or delete on ecology.ssr_environmental_fusion_case_audit
for each row execute function ecology.block_ssr_environmental_fusion_audit_mutation();

create or replace function public.ssr_environmental_fusion_materialize(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_event ecology.ssr_air_events%rowtype;
  v_exposure ecology.ssr_air_event_exposure_candidates%rowtype;
  v_anchor ecology.ssr_anchor_candidate_registry%rowtype;
  v_case_id uuid;
  v_air_status text;
  v_land_status text;
  v_sea_status text;
  v_scope text;
  v_readiness text;
  v_air_snapshot jsonb;
  v_land_snapshot jsonb;
  v_sea_snapshot jsonb;
  v_manifest jsonb;
  v_materialized integer:=0;
  v_ready integer:=0;
  v_actions integer:=0;
  v_is_marine boolean;
begin
  select * into v_event from ecology.ssr_air_events where id=p_event_id;
  if not found then raise exception 'event not found'; end if;

  for v_exposure in
    select * from ecology.ssr_air_event_exposure_candidates where event_id=p_event_id order by subject_name
  loop
    v_air_status:=case when v_event.source_profile_id is not null and coalesce(cardinality(v_event.signal_flags),0)>0 then 'READY' else 'PARTIAL' end;
    v_land_status:='NOT_APPLICABLE';
    v_sea_status:='NOT_APPLICABLE';
    v_is_marine:=false;
    v_land_snapshot:='{}'::jsonb;

    if v_exposure.subject_type='SSR_ANCHOR_CANDIDATE' then
      select * into v_anchor from ecology.ssr_anchor_candidate_registry where id=v_exposure.subject_reference::uuid;
      if found then
        v_land_status:=case
          when v_anchor.canonicalization_status='promoted' and v_anchor.promotion_eligible
               and v_anchor.canonical_address is not null and v_anchor.cube_uid is not null
               and v_anchor.elevation_m_egm96 is not null and v_anchor.z_index is not null
               and v_anchor.source_verification_status='verified' and v_anchor.source_reconciliation_status='matched'
            then 'READY'
          when v_anchor.canonical_address is not null or v_anchor.elevation_m_egm96 is not null then 'PARTIAL'
          else 'MISSING' end;
        v_is_marine:=lower(coalesce(v_anchor.infrastructure_type,'')) in ('seaport','port','harbor','marine_terminal');
        v_land_snapshot:=jsonb_build_object(
          'anchor_id',v_anchor.id,'infrastructure_name',v_anchor.infrastructure_name,
          'infrastructure_type',v_anchor.infrastructure_type,'latitude',v_anchor.latitude,'longitude',v_anchor.longitude,
          'w3w_address',v_anchor.w3w_address,'elevation_m_egm96',v_anchor.elevation_m_egm96,
          'z_index',v_anchor.z_index,'canonical_address',v_anchor.canonical_address,'cube_uid',v_anchor.cube_uid,
          'canonicalization_status',v_anchor.canonicalization_status,'promotion_eligible',v_anchor.promotion_eligible,
          'source_verification_status',v_anchor.source_verification_status,
          'source_reconciliation_status',v_anchor.source_reconciliation_status,
          'z_assignment_standard',v_anchor.z_assignment_standard
        );
      else
        v_land_status:='MISSING';
      end if;
    end if;

    if v_is_marine then
      if exists(
          select 1 from ecology.ssr_air_cross_domain_validations v
          where v.event_id=p_event_id and v.exposure_candidate_id=v_exposure.id
            and v.provider_code='NOAA-RTOFS' and v.validation_status='evidence_available'
        )
        and exists(
          select 1 from ecology.ssr_air_cross_domain_validations v
          where v.event_id=p_event_id and v.exposure_candidate_id=v_exposure.id
            and v.validation_type='COASTLINE_GRID_AND_DATUM_RECONCILIATION' and v.validation_status='validated'
        )
        and exists(
          select 1 from ecology.ssr_air_cross_domain_validations v
          where v.event_id=p_event_id and v.exposure_candidate_id=v_exposure.id
            and v.provider_code='OT-SRTM15PLUS' and v.validation_status='evidence_available'
        )
        and exists(
          select 1 from ecology.ssr_air_cross_domain_validations v
          where v.event_id=p_event_id and v.exposure_candidate_id=v_exposure.id
            and v.provider_code='GEBCO-SOURCE' and v.validation_status='evidence_available'
        ) then
        v_sea_status:='READY';
      elsif exists(
          select 1 from ecology.ssr_air_cross_domain_validations v
          where v.event_id=p_event_id and v.exposure_candidate_id=v_exposure.id and v.validation_domain in ('SEA','CROSS_DOMAIN')
        ) then
        v_sea_status:='PARTIAL';
      else
        v_sea_status:='MISSING';
      end if;
    end if;

    v_scope:=case when v_is_marine then 'AIR_LAND_SEA'
                  when v_land_status<>'NOT_APPLICABLE' then 'AIR_LAND'
                  else 'AIR_ONLY' end;
    v_readiness:=case
      when v_air_status='READY' and v_land_status in ('READY','NOT_APPLICABLE') and v_sea_status in ('READY','NOT_APPLICABLE')
        then 'READY_FOR_HUMAN_RELEVANCE_REVIEW'
      when v_air_status='MISSING' or v_land_status='MISSING' or v_sea_status='MISSING'
        then 'EVIDENCE_GAP'
      else 'PARTIAL_EVIDENCE' end;

    v_air_snapshot:=jsonb_build_object(
      'event_id',v_event.id,'event_type',v_event.event_type,'severity',v_event.severity,
      'lifecycle_status',v_event.lifecycle_status,'provider_code',v_event.provider_code,
      'dataset_name',v_event.dataset_name,'source_profile_id',v_event.source_profile_id,
      'event_time',v_event.event_time,'previous_event_time',v_event.previous_event_time,
      'grid_latitude',v_event.grid_latitude,'grid_longitude',v_event.grid_longitude,
      'pressure_level_hpa',v_event.pressure_level_hpa,'signal_flags',v_event.signal_flags,
      'signal_snapshot',v_event.signal_snapshot,'statistical_snapshot',v_event.statistical_snapshot
    );

    v_sea_snapshot:=jsonb_build_object(
      'applicable',v_is_marine,
      'validations',coalesce((
        select jsonb_agg(jsonb_build_object(
          'validation_id',v.id,'validation_domain',v.validation_domain,'validation_type',v.validation_type,
          'provider_code',v.provider_code,'validation_status',v.validation_status,
          'evidence_reference',v.evidence_reference,'review_conclusion',v.review_conclusion,
          'impact_conclusion',v.impact_conclusion,'evidence_snapshot',v.evidence_snapshot
        ) order by v.validation_domain,v.provider_code,v.validation_type)
        from ecology.ssr_air_cross_domain_validations v
        where v.event_id=p_event_id and v.exposure_candidate_id=v_exposure.id
      ),'[]'::jsonb),
      'event_aligned_observations',coalesce((
        select jsonb_agg(jsonb_build_object(
          'observation_id',o.id,'provider_code',o.provider_code,'dataset_id',o.dataset_id,
          'observed_at',o.observed_at,'event_time_reference',o.event_time_reference,
          'grid_latitude',o.grid_latitude,'grid_longitude',o.grid_longitude,
          'variables',o.variables,'units',o.units,'quality_gate',o.quality_gate,
          'retrieval_metadata',o.retrieval_metadata
        ) order by o.observed_at,o.provider_code)
        from ecology.ssr_sea_observations o
        where v_is_marine and o.event_time_reference=v_event.event_time
      ),'[]'::jsonb)
    );

    v_manifest:=coalesce((
      select jsonb_agg(jsonb_build_object(
        'domain',v.validation_domain,'provider_code',v.provider_code,'validation_type',v.validation_type,
        'validation_status',v.validation_status,'evidence_reference',v.evidence_reference
      ) order by v.validation_domain,v.provider_code,v.validation_type)
      from ecology.ssr_air_cross_domain_validations v
      where v.event_id=p_event_id and v.exposure_candidate_id=v_exposure.id
    ),'[]'::jsonb);

    insert into ecology.ssr_environmental_fusion_cases as f(
      event_id,exposure_candidate_id,subject_type,subject_reference,subject_name,fusion_scope,
      air_evidence_status,land_evidence_status,sea_evidence_status,overall_readiness_status,
      air_snapshot,land_snapshot,sea_snapshot,evidence_manifest,
      physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
    ) values (
      p_event_id,v_exposure.id,v_exposure.subject_type,v_exposure.subject_reference,v_exposure.subject_name,v_scope,
      v_air_status,v_land_status,v_sea_status,v_readiness,
      v_air_snapshot,v_land_snapshot,v_sea_snapshot,v_manifest,false,false,false,false
    )
    on conflict(event_id,exposure_candidate_id) do update set
      subject_type=excluded.subject_type,subject_reference=excluded.subject_reference,subject_name=excluded.subject_name,
      fusion_scope=excluded.fusion_scope,air_evidence_status=excluded.air_evidence_status,
      land_evidence_status=excluded.land_evidence_status,sea_evidence_status=excluded.sea_evidence_status,
      overall_readiness_status=excluded.overall_readiness_status,
      air_snapshot=excluded.air_snapshot,land_snapshot=excluded.land_snapshot,sea_snapshot=excluded.sea_snapshot,
      evidence_manifest=excluded.evidence_manifest,updated_at=now(),
      physical_impact_asserted=false,external_action_authority=false,official_warning_authority=false,canonical_identity_authority=false
    returning id into v_case_id;

    v_materialized:=v_materialized+1;
    if v_readiness='READY_FOR_HUMAN_RELEVANCE_REVIEW' then v_ready:=v_ready+1; end if;

    if not exists(
      select 1 from ecology.ssr_air_event_action_items i
      where i.event_id=p_event_id
        and i.action_payload->>'fusion_case_id'=v_case_id::text
        and i.action_status in ('open','in_progress')
    ) then
      insert into ecology.ssr_air_event_action_items(
        event_id,decision_id,action_code,action_title,assignee,action_status,priority,due_at,
        action_payload,created_by,official_warning_authority,meteorological_warning_authority,canonical_identity_authority
      ) values (
        p_event_id,null,
        case when v_scope='AIR_LAND_SEA' then 'REVIEW_AIR_LAND_SEA_FUSION' when v_scope='AIR_LAND' then 'REVIEW_AIR_LAND_FUSION' else 'REVIEW_AIR_FUSION' end,
        'Human operational-relevance review — '||coalesce(v_exposure.subject_name,v_exposure.subject_reference),
        null,'open',case when v_event.severity='HIGH' then 'high' else 'normal' end,
        now()+case when v_event.severity='HIGH' then interval '4 hours' else interval '12 hours' end,
        jsonb_build_object(
          'fusion_case_id',v_case_id,'fusion_scope',v_scope,'overall_readiness_status',v_readiness,
          'subject_name',v_exposure.subject_name,
          'authority_boundary',jsonb_build_object('physical_impact_asserted',false,'external_action_authority',false,
                                                   'official_warning_authority',false,'canonical_identity_authority',false)
        ),
        'SSR_ENVIRONMENTAL_FUSION_CONTROL',false,false,false
      );
      v_actions:=v_actions+1;
    end if;
  end loop;

  return jsonb_build_object(
    'event_id',p_event_id,'fusion_cases_materialized',v_materialized,
    'ready_for_human_review',v_ready,'review_actions_created',v_actions,
    'physical_impact_asserted',false,'external_action_performed',false,
    'official_warning_authority',false,'canonical_identity_authority',false
  );
end $$;

create or replace function public.ssr_environmental_fusion_record_review(
  p_fusion_case_id uuid,
  p_actor text,
  p_operational_relevance_status text,
  p_conclusion jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_case ecology.ssr_environmental_fusion_cases%rowtype;
  v_exposure_status text;
  v_completed_actions integer:=0;
begin
  if p_actor is null or length(trim(p_actor))=0 then raise exception 'actor required'; end if;
  if p_operational_relevance_status not in ('REQUIRES_FURTHER_VALIDATION','POTENTIAL_RELEVANCE','NO_OPERATIONAL_RELEVANCE','OPERATIONALLY_RELEVANT') then
    raise exception 'unsupported operational relevance status';
  end if;

  select * into v_case from ecology.ssr_environmental_fusion_cases where id=p_fusion_case_id for update;
  if not found then raise exception 'fusion case not found'; end if;
  if v_case.review_status in ('completed','closed') then raise exception 'fusion case review is terminal'; end if;

  update ecology.ssr_environmental_fusion_cases
  set review_status='completed',operational_relevance_status=p_operational_relevance_status,
      reviewer=p_actor,reviewed_at=now(),review_conclusion=coalesce(p_conclusion,'{}'::jsonb),updated_at=now(),
      physical_impact_asserted=false,external_action_authority=false,official_warning_authority=false,canonical_identity_authority=false
  where id=p_fusion_case_id
  returning * into v_case;

  v_exposure_status:=case when p_operational_relevance_status='NO_OPERATIONAL_RELEVANCE'
                          then 'reviewed_not_relevant' else 'reviewed_relevant' end;
  update ecology.ssr_air_event_exposure_candidates
  set review_status=v_exposure_status,reviewer=p_actor,reviewed_at=now(),
      review_notes=coalesce(review_notes,'{}'::jsonb)||jsonb_build_object(
        'fusion_case_id',p_fusion_case_id,'operational_relevance_status',p_operational_relevance_status,
        'fusion_review_conclusion',coalesce(p_conclusion,'{}'::jsonb),
        'physical_impact_asserted',false
      ),updated_at=now(),physical_impact_asserted=false,external_action_authority=false,
      official_warning_authority=false,canonical_identity_authority=false
  where id=v_case.exposure_candidate_id;

  with updated as (
    update ecology.ssr_air_event_action_items
    set action_status='completed',completion_payload=jsonb_build_object(
          'fusion_case_id',p_fusion_case_id,'operational_relevance_status',p_operational_relevance_status,
          'conclusion',coalesce(p_conclusion,'{}'::jsonb),'physical_impact_asserted',false
        ),completed_at=now(),completed_by=p_actor,updated_at=now()
    where event_id=v_case.event_id
      and action_payload->>'fusion_case_id'=p_fusion_case_id::text
      and action_status in ('open','in_progress')
    returning id
  ) select count(*) into v_completed_actions from updated;

  return jsonb_build_object(
    'fusion_case_id',p_fusion_case_id,'event_id',v_case.event_id,
    'review_status',v_case.review_status,'operational_relevance_status',v_case.operational_relevance_status,
    'reviewer',v_case.reviewer,'reviewed_at',v_case.reviewed_at,
    'completed_review_actions',v_completed_actions,
    'physical_impact_asserted',false,'external_action_performed',false,
    'official_warning_authority',false,'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_environmental_fusion_materialize(uuid) from public,anon,authenticated;
revoke all on function public.ssr_environmental_fusion_record_review(uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.ssr_environmental_fusion_materialize(uuid) to service_role;
grant execute on function public.ssr_environmental_fusion_record_review(uuid,text,text,jsonb) to service_role;

create or replace view ecology.ssr_environmental_fusion_review_queue as
select
  f.id as fusion_case_id,f.event_id,f.exposure_candidate_id,f.subject_name,f.subject_type,f.fusion_scope,
  e.severity,e.lifecycle_status as event_lifecycle_status,e.provider_code as air_provider_code,e.event_time,
  f.air_evidence_status,f.land_evidence_status,f.sea_evidence_status,f.overall_readiness_status,
  f.review_status,f.operational_relevance_status,f.reviewer,f.reviewed_at,
  count(i.id) filter(where i.action_status in ('open','in_progress')) as open_review_action_count,
  min(i.due_at) filter(where i.action_status in ('open','in_progress')) as next_review_due_at,
  bool_or(i.due_at<now()) filter(where i.action_status in ('open','in_progress')) as review_overdue,
  false::boolean as physical_impact_asserted,false::boolean as official_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_environmental_fusion_cases f
join ecology.ssr_air_events e on e.id=f.event_id
left join ecology.ssr_air_event_action_items i on i.event_id=f.event_id and i.action_payload->>'fusion_case_id'=f.id::text
group by f.id,e.severity,e.lifecycle_status,e.provider_code,e.event_time;

create or replace view ecology.ssr_environmental_fusion_operational_status as
select
  e.provider_code as air_provider_code,e.severity,
  count(*) as fusion_case_count,
  count(*) filter(where f.overall_readiness_status='READY_FOR_HUMAN_RELEVANCE_REVIEW') as ready_for_human_review_count,
  count(*) filter(where f.review_status='completed') as completed_review_count,
  count(*) filter(where f.review_status in ('queued','in_review')) as open_review_count,
  count(*) filter(where f.operational_relevance_status='OPERATIONALLY_RELEVANT') as operationally_relevant_count,
  count(*) filter(where f.operational_relevance_status='POTENTIAL_RELEVANCE') as potential_relevance_count,
  count(*) filter(where f.operational_relevance_status='NO_OPERATIONAL_RELEVANCE') as not_relevant_count,
  bool_and(f.physical_impact_asserted=false) as physical_impact_boundary_preserved,
  bool_and(f.official_warning_authority=false) as official_warning_boundary_preserved,
  bool_and(f.canonical_identity_authority=false) as canonical_identity_boundary_preserved
from ecology.ssr_environmental_fusion_cases f
join ecology.ssr_air_events e on e.id=f.event_id
group by e.provider_code,e.severity;

comment on table ecology.ssr_environmental_fusion_cases is 'Governed AIR-LAND-SEA evidence fusion cases for human operational-relevance review. Readiness does not assert physical impact, authorize external action, issue an official warning, or alter canonical SSR identity.';
comment on view ecology.ssr_environmental_fusion_review_queue is 'Human review queue for evidence-complete environmental fusion cases. Operational relevance remains NOT_ASSESSED until an identified reviewer records a decision.';
