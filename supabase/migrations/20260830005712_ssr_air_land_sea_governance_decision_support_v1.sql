create table if not exists ecology.ssr_air_land_sea_review_recommendations (
  id uuid primary key default gen_random_uuid(),
  fusion_assessment_id uuid not null references ecology.ssr_air_land_sea_fusion_assessments(id) on delete restrict,
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  exposure_candidate_id uuid not null references ecology.ssr_air_event_exposure_candidates(id) on delete restrict,
  algorithm_version text not null,
  recommendation text not null check (recommendation in (
    'ACCEPT_FOR_MONITORING_RECOMMENDED',
    'REQUEST_MORE_EVIDENCE_RECOMMENDED',
    'NO_AUTOMATED_DETERMINATION'
  )),
  recommendation_confidence text not null check (recommendation_confidence in ('LOW','MODERATE','HIGH')),
  evidence_completeness_score numeric(6,5) not null check (evidence_completeness_score between 0 and 1),
  temporal_alignment_score numeric(6,5) not null check (temporal_alignment_score between 0 and 1),
  spatial_context_score numeric(6,5) not null check (spatial_context_score between 0 and 1),
  composite_readiness_score numeric(6,5) not null check (composite_readiness_score between 0 and 1),
  evidence_digest_sha256 text not null check (evidence_digest_sha256 ~ '^[0-9a-f]{64}$'),
  recommendation_rationale jsonb not null default '{}'::jsonb,
  advisory_only boolean not null default true check (advisory_only=true),
  human_determination_required boolean not null default true check (human_determination_required=true),
  physical_impact_asserted boolean not null default false check (physical_impact_asserted=false),
  external_action_authority boolean not null default false check (external_action_authority=false),
  official_warning_authority boolean not null default false check (official_warning_authority=false),
  canonical_identity_authority boolean not null default false check (canonical_identity_authority=false),
  generated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(fusion_assessment_id,algorithm_version)
);

create index if not exists ix_ssr_air_land_sea_review_recommendations_event
  on ecology.ssr_air_land_sea_review_recommendations(event_id,recommendation,generated_at desc);

alter table ecology.ssr_air_land_sea_review_recommendations enable row level security;
drop policy if exists ssr_air_land_sea_review_recommendations_service_role on ecology.ssr_air_land_sea_review_recommendations;
create policy ssr_air_land_sea_review_recommendations_service_role
  on ecology.ssr_air_land_sea_review_recommendations
  for all to service_role using (true) with check (true);
revoke all on ecology.ssr_air_land_sea_review_recommendations from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_air_land_sea_review_recommendations to service_role;

create or replace function public.ssr_refresh_air_land_sea_review_recommendations(
  p_event_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,extensions,pg_temp
as $$
declare
  v_count integer:=0;
  v_rows jsonb:='[]'::jsonb;
begin
  if not exists(select 1 from ecology.ssr_air_events where id=p_event_id) then
    raise exception 'event not found';
  end if;

  with source_rows as (
    select
      f.id as fusion_assessment_id,
      f.event_id,
      f.exposure_candidate_id,
      f.evidence_readiness,
      f.required_domains,
      f.satisfied_domains,
      f.missing_required_domains,
      f.evidence_bundle,
      e.severity,
      e.event_time,
      e.grid_latitude as event_latitude,
      e.grid_longitude as event_longitude,
      x.subject_name,
      f.subject_infrastructure_type,
      a.latitude as subject_latitude,
      a.longitude as subject_longitude,
      a.canonicalization_status,
      a.source_verification_status,
      a.source_reconciliation_status,
      case
        when cardinality(f.required_domains)=0 then 0::numeric
        else cardinality(f.satisfied_domains)::numeric/cardinality(f.required_domains)::numeric
      end as completeness_score,
      case
        when not ('SEA'=any(f.required_domains)) then 1::numeric
        when exists (
          select 1
          from ecology.ssr_sea_observations s
          where s.event_time_reference=e.event_time
            and s.retrieval_metadata->>'event_alignment_gate'='PASS_EVENT_ALIGNMENT'
            and abs(s.requested_latitude-a.latitude)<=0.02
            and abs(s.requested_longitude-a.longitude)<=0.02
        ) then 1::numeric
        else 0::numeric
      end as temporal_score,
      case
        when a.canonicalization_status='promoted'
          and a.source_verification_status='verified'
          and a.source_reconciliation_status='matched' then 1::numeric
        when a.canonical_address is not null then 0.75::numeric
        else 0.25::numeric
      end as spatial_score,
      case when a.latitude is not null and a.longitude is not null then
        111.195*sqrt(
          power(a.latitude-e.grid_latitude,2)+
          power((a.longitude-e.grid_longitude)*cos(radians((a.latitude+e.grid_latitude)/2.0)),2)
        )
      else null end as approximate_event_distance_km,
      (select count(*)
       from ecology.ssr_sea_observations s
       where s.event_time_reference=e.event_time
         and s.retrieval_metadata->>'event_alignment_gate'='PASS_EVENT_ALIGNMENT'
         and abs(s.requested_latitude-a.latitude)<=0.02
         and abs(s.requested_longitude-a.longitude)<=0.02) as event_aligned_sea_observation_count
    from ecology.ssr_air_land_sea_fusion_assessments f
    join ecology.ssr_air_events e on e.id=f.event_id
    join ecology.ssr_air_event_exposure_candidates x on x.id=f.exposure_candidate_id
    left join ecology.ssr_anchor_candidate_registry a
      on x.subject_type='SSR_ANCHOR_CANDIDATE' and x.subject_reference=a.id::text
    where f.event_id=p_event_id
  ), scored as (
    select
      s.*,
      least(1::numeric,greatest(0::numeric,
        0.60*s.completeness_score+0.25*s.temporal_score+0.15*s.spatial_score
      )) as composite_score,
      encode(extensions.digest(s.evidence_bundle::text,'sha256'),'hex') as evidence_digest
    from source_rows s
  ), upserted as (
    insert into ecology.ssr_air_land_sea_review_recommendations(
      fusion_assessment_id,event_id,exposure_candidate_id,algorithm_version,
      recommendation,recommendation_confidence,
      evidence_completeness_score,temporal_alignment_score,spatial_context_score,composite_readiness_score,
      evidence_digest_sha256,recommendation_rationale,
      advisory_only,human_determination_required,
      physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
    )
    select
      s.fusion_assessment_id,s.event_id,s.exposure_candidate_id,'ALS-REVIEW-SUPPORT-V1',
      case
        when s.evidence_readiness='READY_FOR_GOVERNANCE_REVIEW'
          and cardinality(s.missing_required_domains)=0
          and s.completeness_score=1
          and s.temporal_score=1
          and s.spatial_score>=0.75
          then 'ACCEPT_FOR_MONITORING_RECOMMENDED'
        when s.evidence_readiness in ('PARTIAL_EVIDENCE','BLOCKED')
          or cardinality(s.missing_required_domains)>0
          or s.completeness_score<1
          or s.temporal_score<1
          then 'REQUEST_MORE_EVIDENCE_RECOMMENDED'
        else 'NO_AUTOMATED_DETERMINATION'
      end,
      case
        when s.evidence_readiness='READY_FOR_GOVERNANCE_REVIEW'
          and s.subject_infrastructure_type='seaport'
          and s.event_aligned_sea_observation_count>=2
          and s.composite_score>=0.95 then 'HIGH'
        when s.evidence_readiness='READY_FOR_GOVERNANCE_REVIEW'
          and s.composite_score>=0.85 then 'MODERATE'
        else 'LOW'
      end,
      round(s.completeness_score,5),round(s.temporal_score,5),round(s.spatial_score,5),round(s.composite_score,5),
      s.evidence_digest,
      jsonb_build_object(
        'subject_name',s.subject_name,
        'subject_infrastructure_type',s.subject_infrastructure_type,
        'event_severity',s.severity,
        'event_time',s.event_time,
        'required_domains',s.required_domains,
        'satisfied_domains',s.satisfied_domains,
        'missing_required_domains',s.missing_required_domains,
        'event_aligned_sea_observation_count',s.event_aligned_sea_observation_count,
        'approximate_event_distance_km',s.approximate_event_distance_km,
        'interpretation','Recommendation concerns internal monitoring relevance only. It is not evidence of physical impact and is not an official warning.',
        'permitted_human_actions',jsonb_build_array('ACCEPT_FOR_MONITORING','REJECT_RELEVANCE'),
        'no_automatic_rejection_rule',true
      ),
      true,true,false,false,false,false
    from scored s
    on conflict(fusion_assessment_id,algorithm_version) do update set
      recommendation=excluded.recommendation,
      recommendation_confidence=excluded.recommendation_confidence,
      evidence_completeness_score=excluded.evidence_completeness_score,
      temporal_alignment_score=excluded.temporal_alignment_score,
      spatial_context_score=excluded.spatial_context_score,
      composite_readiness_score=excluded.composite_readiness_score,
      evidence_digest_sha256=excluded.evidence_digest_sha256,
      recommendation_rationale=excluded.recommendation_rationale,
      advisory_only=true,
      human_determination_required=true,
      physical_impact_asserted=false,
      external_action_authority=false,
      official_warning_authority=false,
      canonical_identity_authority=false,
      updated_at=now()
    returning *
  )
  select count(*),coalesce(jsonb_agg(jsonb_build_object(
    'recommendation_id',u.id,
    'fusion_assessment_id',u.fusion_assessment_id,
    'exposure_candidate_id',u.exposure_candidate_id,
    'recommendation',u.recommendation,
    'confidence',u.recommendation_confidence,
    'composite_readiness_score',u.composite_readiness_score,
    'evidence_digest_sha256',u.evidence_digest_sha256
  ) order by u.generated_at),'[]'::jsonb)
  into v_count,v_rows
  from upserted u;

  update ecology.ssr_air_event_action_items i
  set action_payload=coalesce(i.action_payload,'{}'::jsonb)||jsonb_build_object(
        'decision_support_algorithm','ALS-REVIEW-SUPPORT-V1',
        'decision_support_generated_at',now(),
        'decision_support_advisory_only',true,
        'human_determination_required',true,
        'recommendations',v_rows
      ),
      updated_at=now()
  where i.event_id=p_event_id
    and i.action_code='REVIEW_AIR_LAND_SEA_FUSION'
    and i.action_status in ('open','in_progress');

  return jsonb_build_object(
    'event_id',p_event_id,
    'recommendation_count',v_count,
    'recommendations',v_rows,
    'advisory_only',true,
    'human_determination_required',true,
    'physical_impact_asserted',false,
    'external_action_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_refresh_air_land_sea_review_recommendations(uuid) from public,anon,authenticated;
grant execute on function public.ssr_refresh_air_land_sea_review_recommendations(uuid) to service_role;

create or replace view ecology.ssr_air_land_sea_governance_decision_support as
select
  q.*,
  r.id as recommendation_id,
  r.algorithm_version,
  r.recommendation,
  r.recommendation_confidence,
  r.evidence_completeness_score,
  r.temporal_alignment_score,
  r.spatial_context_score,
  r.composite_readiness_score,
  r.evidence_digest_sha256,
  r.recommendation_rationale,
  r.advisory_only,
  r.human_determination_required,
  false::boolean as physical_impact_asserted_by_recommendation,
  false::boolean as official_warning_authority_by_recommendation,
  false::boolean as canonical_identity_authority_by_recommendation
from ecology.ssr_air_land_sea_fusion_review_queue q
left join ecology.ssr_air_land_sea_review_recommendations r
  on r.fusion_assessment_id=q.fusion_assessment_id
 and r.algorithm_version='ALS-REVIEW-SUPPORT-V1';

comment on table ecology.ssr_air_land_sea_review_recommendations is 'Deterministic advisory decision support for human AIR-LAND-SEA governance review. Recommendations concern monitoring relevance only and never establish physical impact, official warning authority, external action authority, or canonical identity authority.';
comment on view ecology.ssr_air_land_sea_governance_decision_support is 'Human review queue augmented with advisory-only evidence completeness and monitoring recommendations.';
