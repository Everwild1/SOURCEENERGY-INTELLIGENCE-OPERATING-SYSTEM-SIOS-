create table if not exists ecology.ssr_air_land_sea_fusion_review_audit (
  id bigserial primary key,
  fusion_assessment_id uuid not null references ecology.ssr_air_land_sea_fusion_assessments(id) on delete restrict,
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  exposure_candidate_id uuid not null references ecology.ssr_air_event_exposure_candidates(id) on delete restrict,
  review_action text not null check(review_action in ('START_REVIEW','ACCEPT_FOR_MONITORING','REJECT_RELEVANCE','CLOSE_REVIEW')),
  status_before text not null,
  status_after text not null,
  actor text not null,
  review_notes jsonb not null default '{}'::jsonb,
  impact_conclusion text not null,
  physical_impact_asserted boolean not null default false,
  external_action_authority boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  recorded_at timestamptz not null default now(),
  check(length(trim(actor))>0),
  check(physical_impact_asserted=false),
  check(external_action_authority=false),
  check(official_warning_authority=false),
  check(canonical_identity_authority=false)
);

create index if not exists ix_ssr_air_land_sea_fusion_review_audit
  on ecology.ssr_air_land_sea_fusion_review_audit(fusion_assessment_id,recorded_at desc);

alter table ecology.ssr_air_land_sea_fusion_review_audit enable row level security;
drop policy if exists ssr_air_land_sea_fusion_review_audit_service_role on ecology.ssr_air_land_sea_fusion_review_audit;
create policy ssr_air_land_sea_fusion_review_audit_service_role
  on ecology.ssr_air_land_sea_fusion_review_audit for select to service_role using(true);
revoke all on ecology.ssr_air_land_sea_fusion_review_audit from anon,authenticated;
grant select on ecology.ssr_air_land_sea_fusion_review_audit to service_role;

create or replace function ecology.block_ssr_air_land_sea_fusion_review_audit_mutation()
returns trigger
language plpgsql
set search_path=ecology,public,pg_temp
as $$
begin
  raise exception 'ssr_air_land_sea_fusion_review_audit is append-only';
end $$;

drop trigger if exists trg_block_ssr_air_land_sea_fusion_review_audit_mutation on ecology.ssr_air_land_sea_fusion_review_audit;
create trigger trg_block_ssr_air_land_sea_fusion_review_audit_mutation
before update or delete on ecology.ssr_air_land_sea_fusion_review_audit
for each row execute function ecology.block_ssr_air_land_sea_fusion_review_audit_mutation();

create or replace function public.ssr_air_land_sea_fusion_review(
  p_fusion_assessment_id uuid,
  p_review_action text,
  p_actor text,
  p_review_notes jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_fusion ecology.ssr_air_land_sea_fusion_assessments%rowtype;
  v_before text;
  v_after text;
  v_impact text;
  v_exposure_review text;
  v_exposure_impact text;
begin
  if p_review_action not in ('START_REVIEW','ACCEPT_FOR_MONITORING','REJECT_RELEVANCE','CLOSE_REVIEW') then
    raise exception 'unsupported fusion review action';
  end if;
  if p_actor is null or length(trim(p_actor))=0 then raise exception 'actor required'; end if;

  select * into v_fusion
  from ecology.ssr_air_land_sea_fusion_assessments
  where id=p_fusion_assessment_id
  for update;
  if not found then raise exception 'fusion assessment not found'; end if;
  if v_fusion.evidence_readiness<>'READY_FOR_GOVERNANCE_REVIEW' and p_review_action in ('ACCEPT_FOR_MONITORING','REJECT_RELEVANCE') then
    raise exception 'fusion evidence is not ready for governance determination';
  end if;

  v_before:=v_fusion.governance_review_status;
  if p_review_action='START_REVIEW' then
    if v_before<>'pending' then raise exception 'only pending assessments can enter review'; end if;
    v_after:='in_review';
    v_impact:='NOT_ASSESSED';
    v_exposure_review:=null;
    v_exposure_impact:=null;
  elsif p_review_action='ACCEPT_FOR_MONITORING' then
    if v_before not in ('pending','in_review') then raise exception 'assessment is not reviewable'; end if;
    v_after:='accepted';
    v_impact:='POTENTIAL_RELEVANCE';
    v_exposure_review:='reviewed_relevant';
    v_exposure_impact:='POTENTIAL_REVIEW';
  elsif p_review_action='REJECT_RELEVANCE' then
    if v_before not in ('pending','in_review') then raise exception 'assessment is not reviewable'; end if;
    v_after:='rejected';
    v_impact:='NO_IMPACT_EVIDENCE';
    v_exposure_review:='reviewed_not_relevant';
    v_exposure_impact:='NO_IMPACT_EVIDENCE';
  else
    if v_before not in ('accepted','rejected') then raise exception 'only determined assessments can be closed'; end if;
    v_after:='closed';
    v_impact:=v_fusion.impact_conclusion;
    v_exposure_review:=null;
    v_exposure_impact:=null;
  end if;

  update ecology.ssr_air_land_sea_fusion_assessments
  set governance_review_status=v_after,
      impact_conclusion=v_impact,
      physical_impact_asserted=false,
      external_action_authority=false,
      official_warning_authority=false,
      canonical_identity_authority=false,
      updated_at=now()
  where id=v_fusion.id;

  if v_exposure_review is not null then
    update ecology.ssr_air_event_exposure_candidates
    set review_status=v_exposure_review,
        impact_status=v_exposure_impact,
        reviewer=p_actor,
        reviewed_at=now(),
        review_notes=coalesce(review_notes,'{}'::jsonb)||jsonb_build_object(
          'fusion_assessment_id',v_fusion.id,
          'review_action',p_review_action,
          'review_notes',coalesce(p_review_notes,'{}'::jsonb),
          'operational_relevance_only',true,
          'physical_impact_asserted',false),
        physical_impact_asserted=false,
        external_action_authority=false,
        official_warning_authority=false,
        canonical_identity_authority=false,
        updated_at=now()
    where id=v_fusion.exposure_candidate_id;
  end if;

  insert into ecology.ssr_air_land_sea_fusion_review_audit(
    fusion_assessment_id,event_id,exposure_candidate_id,review_action,
    status_before,status_after,actor,review_notes,impact_conclusion,
    physical_impact_asserted,external_action_authority,official_warning_authority,canonical_identity_authority
  ) values (
    v_fusion.id,v_fusion.event_id,v_fusion.exposure_candidate_id,p_review_action,
    v_before,v_after,p_actor,coalesce(p_review_notes,'{}'::jsonb),v_impact,
    false,false,false,false
  );

  return jsonb_build_object(
    'fusion_assessment_id',v_fusion.id,
    'event_id',v_fusion.event_id,
    'exposure_candidate_id',v_fusion.exposure_candidate_id,
    'review_action',p_review_action,
    'status_before',v_before,
    'status_after',v_after,
    'impact_conclusion',v_impact,
    'operational_relevance_only',true,
    'physical_impact_asserted',false,
    'external_action_authority',false,
    'official_warning_authority',false,
    'canonical_identity_authority',false
  );
end $$;

revoke all on function public.ssr_air_land_sea_fusion_review(uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.ssr_air_land_sea_fusion_review(uuid,text,text,jsonb) to service_role;

create or replace view ecology.ssr_air_land_sea_fusion_review_queue as
select
  s.*,
  case
    when s.evidence_readiness='READY_FOR_GOVERNANCE_REVIEW' and s.governance_review_status='pending' then 'REVIEW_DUE'
    when s.governance_review_status='in_review' then 'REVIEW_IN_PROGRESS'
    when s.governance_review_status in ('accepted','rejected') then 'DETERMINATION_RECORDED'
    else 'CLOSED'
  end as review_queue_state
from ecology.ssr_air_land_sea_fusion_status s
where s.governance_review_status<>'closed';

comment on function public.ssr_air_land_sea_fusion_review(uuid,text,text,jsonb) is 'Human-actor fusion review gateway. ACCEPT_FOR_MONITORING records operational review relevance only and never asserts physical impact, official warning authority, external action authority, or canonical identity authority.';
