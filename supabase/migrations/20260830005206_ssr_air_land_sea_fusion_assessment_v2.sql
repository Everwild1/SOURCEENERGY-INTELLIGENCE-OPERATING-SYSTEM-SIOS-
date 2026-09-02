alter table ecology.ssr_air_cross_domain_validations
  add column if not exists required_for_fusion boolean not null default true;

update ecology.ssr_air_cross_domain_validations
set required_for_fusion=false,
    validation_status=case when provider_code='COP-MARINE' and validation_status='required' then 'not_applicable' else validation_status end,
    review_conclusion=case
      when provider_code='COP-MARINE' then 'Primary event-aligned SEA closure is satisfied by NOAA RTOFS. Copernicus Marine remains an optional independent cross-validation pathway and does not block fusion readiness.'
      else review_conclusion
    end,
    updated_at=now()
where provider_code in ('COP-MARINE','NOAA-ERDDAP');

create or replace view ecology.ssr_air_cross_domain_validation_status_v2 as
select
  e.id as event_id,
  e.severity,
  e.lifecycle_status,
  e.provider_code,
  e.event_time,
  x.id as exposure_candidate_id,
  x.subject_name,
  x.subject_type,
  x.review_status,
  x.impact_status,
  count(v.id) as validation_count,
  count(v.id) filter(where v.required_for_fusion) as required_validation_count,
  count(v.id) filter(where not v.required_for_fusion) as optional_validation_count,
  count(v.id) filter(where v.required_for_fusion and v.validation_status='validated') as required_validated_count,
  count(v.id) filter(where v.required_for_fusion and v.validation_status='evidence_available') as required_evidence_available_count,
  count(v.id) filter(where v.required_for_fusion and v.validation_status='required') as required_open_count,
  count(v.id) filter(where v.required_for_fusion and v.validation_status='insufficient') as required_insufficient_count,
  count(v.id) filter(where not v.required_for_fusion and v.validation_status in ('required','insufficient')) as optional_open_count,
  case
    when count(v.id) filter(where v.required_for_fusion)=0 then 'NO_REQUIRED_VALIDATION_PLAN'
    when count(v.id) filter(where v.required_for_fusion and v.validation_status='required')>0 then 'VALIDATION_REQUIRED'
    when count(v.id) filter(where v.required_for_fusion and v.validation_status='insufficient')>0 then 'INSUFFICIENT_REQUIRED_EVIDENCE'
    when count(v.id) filter(where v.required_for_fusion and v.validation_status in ('validated','evidence_available','not_applicable'))
         = count(v.id) filter(where v.required_for_fusion)
      then 'EVIDENCE_READY_FOR_HUMAN_REVIEW'
    else 'PARTIAL_REQUIRED_EVIDENCE'
  end as cross_domain_state,
  false::boolean as physical_impact_asserted,
  false::boolean as official_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_events e
join ecology.ssr_air_event_exposure_candidates x on x.event_id=e.id
left join ecology.ssr_air_cross_domain_validations v on v.exposure_candidate_id=x.id
 group by e.id,e.severity,e.lifecycle_status,e.provider_code,e.event_time,
          x.id,x.subject_name,x.subject_type,x.review_status,x.impact_status;

create table if not exists ecology.ssr_air_land_sea_fusion_assessments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  exposure_candidate_id uuid not null references ecology.ssr_air_event_exposure_candidates(id) on delete restrict,
  subject_infrastructure_type text,
  required_domains text[] not null default '{}'::text[],
  satisfied_domains text[] not null default '{}'::text[],
  missing_required_domains text[] not null default '{}'::text[],
  evidence_readiness text not null check(evidence_readiness in ('READY_FOR_GOVERNANCE_REVIEW','PARTIAL_EVIDENCE','BLOCKED')),
  governance_review_status text not null default 'pending' check(governance_review_status in ('pending','in_review','accepted','rejected','closed')),
  evidence_bundle jsonb not null default '{}'::jsonb,
  human_review_required boolean not null default true,
  impact_conclusion text not null default 'NOT_ASSESSED' check(impact_conclusion in ('NOT_ASSESSED','NO_IMPACT_EVIDENCE','POTENTIAL_RELEVANCE','VALIDATED_RELEVANCE')),
  physical_impact_asserted boolean not null default false,
  external_action_authority boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  generated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(event_id,exposure_candidate_id),
  check(physical_impact_asserted=false),
  check(external_action_authority=false),
  check(official_warning_authority=false),
  check(canonical_identity_authority=false)
);

create index if not exists ix_ssr_air_land_sea_fusion_readiness
  on ecology.ssr_air_land_sea_fusion_assessments(evidence_readiness,governance_review_status,generated_at desc);

alter table ecology.ssr_air_land_sea_fusion_assessments enable row level security;
drop policy if exists ssr_air_land_sea_fusion_service_role on ecology.ssr_air_land_sea_fusion_assessments;
create policy ssr_air_land_sea_fusion_service_role
  on ecology.ssr_air_land_sea_fusion_assessments for all to service_role using(true) with check(true);
revoke all on ecology.ssr_air_land_sea_fusion_assessments from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_air_land_sea_fusion_assessments to service_role;

create or replace function public.ssr_refresh_air_land_sea_fusion(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_upserted integer:=0;
  v_ready integer:=0;
begin
  if not exists(select 1 from ecology.ssr_air_events where id=p_event_id) then
    raise exception 'event not found';
  end if;

  with base as (
    select
      e.id as event_id,
      e.event_type,
      e.severity,
      e.event_time,
      e.provider_code as air_provider_code,
      e.source_profile_id,
      e.signal_flags,
      x.id as exposure_candidate_id,
      x.subject_name,
      x.subject_reference,
      a.id as anchor_id,
      a.infrastructure_type,
      a.latitude as anchor_latitude,
      a.longitude as anchor_longitude,
      a.w3w_address,
      a.elevation_m_egm96,
      a.z_index,
      a.canonical_address,
      a.cube_uid,
      a.canonicalization_status,
      a.promotion_eligible,
      a.source_verification_status,
      a.source_reconciliation_status,
      true as air_ready,
      (
        a.id is not null
        and a.w3w_address is not null
        and a.elevation_m_egm96 is not null
        and a.z_index is not null
        and a.canonical_address is not null
        and a.cube_uid is not null
        and a.canonicalization_status='promoted'
        and a.promotion_eligible
        and a.source_verification_status='verified'
        and a.source_reconciliation_status='matched'
      ) as land_ready,
      case
        when a.infrastructure_type in ('seaport','port','harbor','marine_terminal') then
          exists(
            select 1
            from ecology.ssr_air_cross_domain_validations v
            where v.event_id=e.id
              and v.exposure_candidate_id=x.id
              and v.provider_code='NOAA-RTOFS'
              and v.required_for_fusion
              and v.validation_status in ('evidence_available','validated')
          )
          and exists(
            select 1 from ecology.ssr_sea_observations o
            where o.provider_code='NOAA-RTOFS'
              and o.event_time_reference=e.event_time
              and o.quality_gate='PASS_NOAA_RTOFS_POINT_FORECAST'
              and o.retrieval_metadata->>'event_alignment_gate'='PASS_EVENT_ALIGNMENT'
              and o.variables ? 'sea_surface_temperature_c'
              and o.variables ? 'sea_surface_salinity_psu'
              and o.variables ? 'u_velocity_mps'
              and o.variables ? 'v_velocity_mps'
          )
          and exists(
            select 1 from ecology.ssr_sea_observations o
            where o.provider_code='NOAA-RTOFS'
              and o.event_time_reference=e.event_time
              and o.quality_gate='PASS_NOAA_RTOFS_SSHG_POINT_FORECAST'
              and o.retrieval_metadata->>'event_alignment_gate'='PASS_EVENT_ALIGNMENT'
              and o.variables ? 'sea_surface_height_relative_to_geoid_m'
          )
        else true
      end as sea_ready
    from ecology.ssr_air_events e
    join ecology.ssr_air_event_exposure_candidates x on x.event_id=e.id
    left join ecology.ssr_anchor_candidate_registry a
      on x.subject_type='SSR_ANCHOR_CANDIDATE' and x.subject_reference=a.id::text
    where e.id=p_event_id
  ), shaped as (
    select
      b.*,
      case when b.infrastructure_type in ('seaport','port','harbor','marine_terminal')
        then array['AIR','LAND','SEA']::text[]
        else array['AIR','LAND']::text[]
      end as required_domains,
      array_remove(array[
        case when b.air_ready then 'AIR' end,
        case when b.land_ready then 'LAND' end,
        case when b.infrastructure_type in ('seaport','port','harbor','marine_terminal') and b.sea_ready then 'SEA' end
      ],null) as satisfied_domains
    from base b
  ), prepared as (
    select
      s.*,
      array(select unnest(s.required_domains) except select unnest(s.satisfied_domains)) as missing_domains
    from shaped s
  ), upserted as (
    insert into ecology.ssr_air_land_sea_fusion_assessments(
      event_id,exposure_candidate_id,subject_infrastructure_type,
      required_domains,satisfied_domains,missing_required_domains,evidence_readiness,
      governance_review_status,evidence_bundle,human_review_required,impact_conclusion,
      physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority,
      generated_at,updated_at
    )
    select
      p.event_id,p.exposure_candidate_id,p.infrastructure_type,
      p.required_domains,p.satisfied_domains,p.missing_domains,
      case when cardinality(p.missing_domains)=0 then 'READY_FOR_GOVERNANCE_REVIEW' else 'PARTIAL_EVIDENCE' end,
      'pending',
      jsonb_build_object(
        'subject',jsonb_build_object(
          'name',p.subject_name,'infrastructure_type',p.infrastructure_type,
          'anchor_id',p.anchor_id,'latitude',p.anchor_latitude,'longitude',p.anchor_longitude),
        'air',jsonb_build_object(
          'provider_code',p.air_provider_code,'event_type',p.event_type,'severity',p.severity,
          'event_time',p.event_time,'source_profile_id',p.source_profile_id,'signal_flags',p.signal_flags,
          'evidence_ready',p.air_ready),
        'land',jsonb_build_object(
          'w3w_address',p.w3w_address,'elevation_m_egm96',p.elevation_m_egm96,'z_index',p.z_index,
          'canonical_address',p.canonical_address,'cube_uid',p.cube_uid,
          'canonicalization_status',p.canonicalization_status,'promotion_eligible',p.promotion_eligible,
          'source_verification_status',p.source_verification_status,
          'source_reconciliation_status',p.source_reconciliation_status,
          'evidence_ready',p.land_ready),
        'sea',jsonb_build_object(
          'required',p.infrastructure_type in ('seaport','port','harbor','marine_terminal'),
          'evidence_ready',p.sea_ready,
          'event_aligned_observations',coalesce((
            select jsonb_agg(jsonb_build_object(
              'observation_id',o.id,'dataset_id',o.dataset_id,'observed_at',o.observed_at,
              'grid_latitude',o.grid_latitude,'grid_longitude',o.grid_longitude,
              'variables',o.variables,'quality_gate',o.quality_gate,
              'retrieval_metadata',o.retrieval_metadata
            ) order by o.observed_at)
            from ecology.ssr_sea_observations o
            where o.provider_code='NOAA-RTOFS' and o.event_time_reference=p.event_time
          ),'[]'::jsonb)),
        'validation_status',coalesce((
          select to_jsonb(vs)
          from ecology.ssr_air_cross_domain_validation_status_v2 vs
          where vs.event_id=p.event_id and vs.exposure_candidate_id=p.exposure_candidate_id
        ),'{}'::jsonb),
        'authority_boundary',jsonb_build_object(
          'physical_impact_asserted',false,'external_action_authority',false,
          'official_warning_authority',false,'canonical_identity_authority',false)
      ),
      true,'NOT_ASSESSED',false,false,false,false,now(),now()
    from prepared p
    on conflict(event_id,exposure_candidate_id) do update set
      subject_infrastructure_type=excluded.subject_infrastructure_type,
      required_domains=excluded.required_domains,
      satisfied_domains=excluded.satisfied_domains,
      missing_required_domains=excluded.missing_required_domains,
      evidence_readiness=excluded.evidence_readiness,
      evidence_bundle=excluded.evidence_bundle,
      human_review_required=true,
      impact_conclusion='NOT_ASSESSED',
      physical_impact_asserted=false,
      external_action_authority=false,
      official_warning_authority=false,
      canonical_identity_authority=false,
      generated_at=now(),updated_at=now()
    returning evidence_readiness
  )
  select count(*),count(*) filter(where evidence_readiness='READY_FOR_GOVERNANCE_REVIEW')
    into v_upserted,v_ready
  from upserted;

  return jsonb_build_object(
    'event_id',p_event_id,
    'assessments_refreshed',v_upserted,
    'ready_for_governance_review',v_ready,
    'human_review_required',true,
    'physical_impact_asserted',false,
    'external_action_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_refresh_air_land_sea_fusion(uuid) from public,anon,authenticated;
grant execute on function public.ssr_refresh_air_land_sea_fusion(uuid) to service_role;

create or replace view ecology.ssr_air_land_sea_fusion_status as
select
  f.id as fusion_assessment_id,
  f.event_id,
  e.event_type,
  e.severity,
  e.lifecycle_status,
  e.event_time,
  f.exposure_candidate_id,
  x.subject_name,
  f.subject_infrastructure_type,
  f.required_domains,
  f.satisfied_domains,
  f.missing_required_domains,
  f.evidence_readiness,
  f.governance_review_status,
  f.human_review_required,
  f.impact_conclusion,
  f.generated_at,
  f.updated_at,
  false::boolean as physical_impact_asserted,
  false::boolean as official_warning_authority,
  false::boolean as canonical_identity_authority
from ecology.ssr_air_land_sea_fusion_assessments f
join ecology.ssr_air_events e on e.id=f.event_id
join ecology.ssr_air_event_exposure_candidates x on x.id=f.exposure_candidate_id;

create or replace function public.ssr_air_land_sea_fusion_case(p_event_id uuid)
returns jsonb
language sql
security definer
set search_path=public,ecology,pg_temp
as $$
  select jsonb_build_object(
    'event_id',p_event_id,
    'generated_at',now(),
    'assessments',coalesce(jsonb_agg(jsonb_build_object(
      'status',to_jsonb(s),
      'evidence_bundle',f.evidence_bundle
    ) order by s.subject_name),'[]'::jsonb),
    'human_review_required',true,
    'physical_impact_asserted',false,
    'external_action_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  )
  from ecology.ssr_air_land_sea_fusion_status s
  join ecology.ssr_air_land_sea_fusion_assessments f on f.id=s.fusion_assessment_id
  where s.event_id=p_event_id
$$;

revoke all on function public.ssr_air_land_sea_fusion_case(uuid) from public,anon,authenticated;
grant execute on function public.ssr_air_land_sea_fusion_case(uuid) to service_role;

comment on table ecology.ssr_air_land_sea_fusion_assessments is 'AIR-LAND-SEA evidence fusion readiness for governance review. Fusion readiness does not establish exposure relevance, physical impact, official warning authority, external action authority, or canonical identity authority.';
comment on view ecology.ssr_air_land_sea_fusion_status is 'Governed evidence-readiness status by exposure candidate. Human review remains mandatory.';
