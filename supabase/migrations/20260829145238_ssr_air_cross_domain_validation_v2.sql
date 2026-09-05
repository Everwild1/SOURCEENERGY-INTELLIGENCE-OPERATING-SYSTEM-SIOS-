create table if not exists ecology.ssr_air_cross_domain_validations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  exposure_candidate_id uuid not null references ecology.ssr_air_event_exposure_candidates(id) on delete restrict,
  validation_domain text not null check(validation_domain in('LAND','SEA','CROSS_DOMAIN')),
  validation_type text not null,
  provider_code text not null,
  validation_status text not null default 'required' check(validation_status in('required','evidence_available','validated','insufficient','not_applicable')),
  evidence_reference text,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  review_conclusion text,
  impact_conclusion text not null default 'NOT_ASSESSED' check(impact_conclusion in('NOT_ASSESSED','NO_IMPACT_EVIDENCE','POTENTIAL_RELEVANCE','VALIDATED_RELEVANCE')),
  reviewer text,
  reviewed_at timestamptz,
  physical_impact_asserted boolean not null default false,
  external_action_authority boolean not null default false,
  official_warning_authority boolean not null default false,
  canonical_identity_authority boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(event_id,exposure_candidate_id,validation_domain,validation_type,provider_code),
  check(physical_impact_asserted=false),
  check(external_action_authority=false),
  check(official_warning_authority=false),
  check(canonical_identity_authority=false)
);

create index if not exists ix_ssr_air_cross_domain_validation_queue
  on ecology.ssr_air_cross_domain_validations(validation_status,validation_domain,created_at);

alter table ecology.ssr_air_cross_domain_validations enable row level security;
drop policy if exists ssr_air_cross_domain_validations_service_role on ecology.ssr_air_cross_domain_validations;
create policy ssr_air_cross_domain_validations_service_role on ecology.ssr_air_cross_domain_validations
  for all to service_role using(true) with check(true);
revoke all on ecology.ssr_air_cross_domain_validations from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_air_cross_domain_validations to service_role;

create table if not exists ecology.ssr_air_cross_domain_validation_audit (
  id bigserial primary key,
  validation_id uuid not null references ecology.ssr_air_cross_domain_validations(id) on delete restrict,
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  audit_action text not null,
  previous_status text,
  new_status text,
  actor text,
  audit_payload jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);

alter table ecology.ssr_air_cross_domain_validation_audit enable row level security;
drop policy if exists ssr_air_cross_domain_validation_audit_select on ecology.ssr_air_cross_domain_validation_audit;
create policy ssr_air_cross_domain_validation_audit_select on ecology.ssr_air_cross_domain_validation_audit
  for select to service_role using(true);
revoke all on ecology.ssr_air_cross_domain_validation_audit from anon,authenticated;
grant select on ecology.ssr_air_cross_domain_validation_audit to service_role;

create or replace function ecology.audit_ssr_air_cross_domain_validation()
returns trigger language plpgsql security definer set search_path=ecology,public,pg_temp as $$
begin
  if tg_op='INSERT' then
    insert into ecology.ssr_air_cross_domain_validation_audit(validation_id,event_id,audit_action,previous_status,new_status,actor,audit_payload)
    values(new.id,new.event_id,'created',null,new.validation_status,new.reviewer,
      jsonb_build_object('domain',new.validation_domain,'validation_type',new.validation_type,'provider_code',new.provider_code));
    return new;
  end if;
  if tg_op='UPDATE' then
    insert into ecology.ssr_air_cross_domain_validation_audit(validation_id,event_id,audit_action,previous_status,new_status,actor,audit_payload)
    values(new.id,new.event_id,'updated',old.validation_status,new.validation_status,new.reviewer,
      jsonb_build_object('impact_conclusion',new.impact_conclusion,'review_conclusion',new.review_conclusion,'evidence_reference',new.evidence_reference));
    return new;
  end if;
  return new;
end $$;

drop trigger if exists trg_ssr_air_cross_domain_validation_audit on ecology.ssr_air_cross_domain_validations;
create trigger trg_ssr_air_cross_domain_validation_audit
after insert or update on ecology.ssr_air_cross_domain_validations
for each row execute function ecology.audit_ssr_air_cross_domain_validation();

create or replace function ecology.block_ssr_air_cross_domain_validation_audit_mutation()
returns trigger language plpgsql as $$ begin raise exception 'ssr_air_cross_domain_validation_audit is append-only'; end $$;
drop trigger if exists trg_block_ssr_air_cross_domain_validation_audit_mutation on ecology.ssr_air_cross_domain_validation_audit;
create trigger trg_block_ssr_air_cross_domain_validation_audit_mutation
before update or delete on ecology.ssr_air_cross_domain_validation_audit
for each row execute function ecology.block_ssr_air_cross_domain_validation_audit_mutation();

create or replace function public.ssr_air_seed_cross_domain_validation(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare v_count integer:=0; v_rows integer:=0;
begin
  if not exists(select 1 from ecology.ssr_air_events where id=p_event_id) then raise exception 'event not found'; end if;

  insert into ecology.ssr_air_cross_domain_validations(
    event_id,exposure_candidate_id,validation_domain,validation_type,provider_code,validation_status,evidence_reference,evidence_snapshot
  )
  select x.event_id,x.id,'LAND','ANCHOR_ELEVATION_AND_IDENTITY_REVIEW',
         case when a.elevation_m_egm96 is not null then 'SSR-EGM96' else 'OT-POINT' end,
         case when a.elevation_m_egm96 is not null then 'evidence_available' else 'required' end,
         coalesce(a.elevation_evidence_reference,a.source_reference),
         jsonb_build_object(
           'anchor_id',a.id,'name',a.infrastructure_name,'type',a.infrastructure_type,
           'latitude',a.latitude,'longitude',a.longitude,'w3w_address',a.w3w_address,
           'elevation_m_egm96',a.elevation_m_egm96,'z_index',a.z_index,
           'canonicalization_status',a.canonicalization_status,'promotion_eligible',a.promotion_eligible,
           'blocker_reason',a.blocker_reason,
           'note','LAND identity/elevation evidence is spatial context only and does not prove AIR event impact')
  from ecology.ssr_air_event_exposure_candidates x
  join ecology.ssr_anchor_candidate_registry a on x.subject_type='SSR_ANCHOR_CANDIDATE' and x.subject_reference=a.id::text
  where x.event_id=p_event_id
  on conflict(event_id,exposure_candidate_id,validation_domain,validation_type,provider_code) do nothing;
  get diagnostics v_rows=ROW_COUNT; v_count:=v_count+v_rows;

  insert into ecology.ssr_air_cross_domain_validations(
    event_id,exposure_candidate_id,validation_domain,validation_type,provider_code,validation_status,evidence_snapshot
  )
  select x.event_id,x.id,'SEA','MARINE_STATE_REVIEW','COP-MARINE','required',
         jsonb_build_object('subject_name',x.subject_name,'reason','seaport/coastal candidate requires dynamic marine-state evidence before operational relevance can be assessed','provider_status',(select integration_status from ecology.ssr_scientific_data_providers where provider_code='COP-MARINE'))
  from ecology.ssr_air_event_exposure_candidates x
  join ecology.ssr_anchor_candidate_registry a on x.subject_reference=a.id::text
  where x.event_id=p_event_id and x.subject_type='SSR_ANCHOR_CANDIDATE' and a.infrastructure_type in('seaport','port','harbor','marine_terminal')
  on conflict(event_id,exposure_candidate_id,validation_domain,validation_type,provider_code) do nothing;
  get diagnostics v_rows=ROW_COUNT; v_count:=v_count+v_rows;

  insert into ecology.ssr_air_cross_domain_validations(
    event_id,exposure_candidate_id,validation_domain,validation_type,provider_code,validation_status,evidence_snapshot
  )
  select x.event_id,x.id,'SEA','BATHYMETRY_DATUM_REVIEW','OT-SRTM15PLUS','required',
         jsonb_build_object('subject_name',x.subject_name,'reason','coastal/seaport geometry review; direct canonical use requires response metadata confirming SRTM15Plus and EGM96','provider_status',(select integration_status from ecology.ssr_scientific_data_providers where provider_code='OT-SRTM15PLUS'))
  from ecology.ssr_air_event_exposure_candidates x
  join ecology.ssr_anchor_candidate_registry a on x.subject_reference=a.id::text
  where x.event_id=p_event_id and x.subject_type='SSR_ANCHOR_CANDIDATE' and a.infrastructure_type in('seaport','port','harbor','marine_terminal')
  on conflict(event_id,exposure_candidate_id,validation_domain,validation_type,provider_code) do nothing;
  get diagnostics v_rows=ROW_COUNT; v_count:=v_count+v_rows;

  return jsonb_build_object('event_id',p_event_id,'validation_records_seeded',v_count,'physical_impact_asserted',false,'external_action_performed',false,'official_warning_authority',false,'canonical_identity_authority',false);
end $$;

create or replace function public.ssr_air_record_cross_domain_validation(
  p_validation_id uuid,
  p_status text,
  p_impact_conclusion text,
  p_reviewer text,
  p_review_conclusion text,
  p_evidence_reference text default null,
  p_evidence_snapshot jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare v ecology.ssr_air_cross_domain_validations%rowtype;
begin
  if p_status not in('evidence_available','validated','insufficient','not_applicable') then raise exception 'unsupported validation status'; end if;
  if p_impact_conclusion not in('NOT_ASSESSED','NO_IMPACT_EVIDENCE','POTENTIAL_RELEVANCE','VALIDATED_RELEVANCE') then raise exception 'unsupported impact conclusion'; end if;
  if p_reviewer is null or length(trim(p_reviewer))=0 then raise exception 'reviewer required'; end if;
  update ecology.ssr_air_cross_domain_validations
  set validation_status=p_status,impact_conclusion=p_impact_conclusion,reviewer=p_reviewer,reviewed_at=now(),
      review_conclusion=p_review_conclusion,evidence_reference=coalesce(p_evidence_reference,evidence_reference),
      evidence_snapshot=evidence_snapshot||coalesce(p_evidence_snapshot,'{}'::jsonb),updated_at=now(),
      physical_impact_asserted=false,external_action_authority=false,official_warning_authority=false,canonical_identity_authority=false
  where id=p_validation_id returning * into v;
  if not found then raise exception 'validation record not found'; end if;
  return jsonb_build_object('validation_id',v.id,'event_id',v.event_id,'validation_status',v.validation_status,'impact_conclusion',v.impact_conclusion,'reviewed_at',v.reviewed_at,'physical_impact_asserted',false,'official_warning_authority',false,'canonical_identity_authority',false);
end $$;

revoke all on function public.ssr_air_seed_cross_domain_validation(uuid) from public,anon,authenticated;
revoke all on function public.ssr_air_record_cross_domain_validation(uuid,text,text,text,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.ssr_air_seed_cross_domain_validation(uuid) to service_role;
grant execute on function public.ssr_air_record_cross_domain_validation(uuid,text,text,text,text,text,jsonb) to service_role;

create or replace view ecology.ssr_air_cross_domain_validation_status as
select e.id event_id,e.severity,e.lifecycle_status,e.provider_code,e.event_time,
 x.id exposure_candidate_id,x.subject_name,x.subject_type,x.review_status,x.impact_status,
 count(v.id) validation_count,
 count(v.id) filter(where v.validation_status='validated') validated_count,
 count(v.id) filter(where v.validation_status='evidence_available') evidence_available_count,
 count(v.id) filter(where v.validation_status='required') required_count,
 count(v.id) filter(where v.validation_status='insufficient') insufficient_count,
 case
   when count(v.id)=0 then 'NO_VALIDATION_PLAN'
   when count(v.id) filter(where v.validation_status='required')>0 then 'VALIDATION_REQUIRED'
   when count(v.id) filter(where v.validation_status='insufficient')>0 then 'INSUFFICIENT_EVIDENCE'
   when count(v.id) filter(where v.validation_status in('validated','evidence_available'))=count(v.id) then 'EVIDENCE_READY_FOR_HUMAN_REVIEW'
   else 'PARTIAL_EVIDENCE'
 end as cross_domain_state,
 false::boolean physical_impact_asserted,false::boolean official_warning_authority,false::boolean canonical_identity_authority
from ecology.ssr_air_events e
join ecology.ssr_air_event_exposure_candidates x on x.event_id=e.id
left join ecology.ssr_air_cross_domain_validations v on v.exposure_candidate_id=x.id
group by e.id,e.severity,e.lifecycle_status,e.provider_code,e.event_time,x.id,x.subject_name,x.subject_type,x.review_status,x.impact_status;

comment on table ecology.ssr_air_cross_domain_validations is 'Cross-domain validation ledger for AIR event exposure candidates. Evidence may support review relevance but never automatically asserts physical impact, official warning authority, external action authority, or canonical SSR identity.';
