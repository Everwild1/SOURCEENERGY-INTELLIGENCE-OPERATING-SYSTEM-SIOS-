create table if not exists ecology.ssr_air_response_playbooks (
 id uuid primary key default gen_random_uuid(), playbook_code text not null unique, playbook_name text not null,
 event_types text[] not null default '{}'::text[], min_severity text not null check(min_severity in('ELEVATED','HIGH')),
 signal_flags_any text[] not null default '{}'::text[], response_scope text not null default 'internal_review', enabled boolean not null default true,
 steps jsonb not null default '[]'::jsonb, requires_human_activation boolean not null default true,
 external_action_authority boolean not null default false, impact_assertion_authority boolean not null default false,
 official_warning_authority boolean not null default false, canonical_identity_authority boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(external_action_authority=false),check(impact_assertion_authority=false),check(official_warning_authority=false),check(canonical_identity_authority=false));

create table if not exists ecology.ssr_air_event_exposure_candidates (
 id uuid primary key default gen_random_uuid(), event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
 subject_type text not null check(subject_type in('ORGANIZATION','SSR_ANCHOR_CANDIDATE','CAPITAL_PROJECT','PROJECT_ASSET','FUNDING_PROGRAM')),
 subject_reference text not null, subject_name text, association_method text not null,
 association_basis jsonb not null default '{}'::jsonb, review_status text not null default 'candidate' check(review_status in('candidate','reviewed_relevant','reviewed_not_relevant','closed')),
 impact_status text not null default 'NOT_ASSESSED' check(impact_status in('NOT_ASSESSED','POTENTIAL_REVIEW','NO_IMPACT_EVIDENCE','IMPACT_EVIDENCE_RECORDED')),
 reviewer text, reviewed_at timestamptz, review_notes jsonb not null default '{}'::jsonb,
 physical_impact_asserted boolean not null default false, external_action_authority boolean not null default false,
 official_warning_authority boolean not null default false, canonical_identity_authority boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(event_id,subject_type,subject_reference), check(physical_impact_asserted=false),check(external_action_authority=false),check(official_warning_authority=false),check(canonical_identity_authority=false));
create index if not exists ix_ssr_air_exposure_event on ecology.ssr_air_event_exposure_candidates(event_id,review_status,subject_type);

create table if not exists ecology.ssr_air_event_playbook_assignments (
 id uuid primary key default gen_random_uuid(), event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
 playbook_id uuid not null references ecology.ssr_air_response_playbooks(id) on delete restrict,
 assignment_status text not null default 'proposed' check(assignment_status in('proposed','activated','completed','cancelled')),
 proposed_reason jsonb not null default '{}'::jsonb, activated_by text, activated_at timestamptz, completed_at timestamptz,
 human_activation_required boolean not null default true, external_action_performed boolean not null default false,
 physical_impact_asserted boolean not null default false, official_warning_authority boolean not null default false,
 canonical_identity_authority boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(event_id,playbook_id),check(external_action_performed=false),check(physical_impact_asserted=false),check(official_warning_authority=false),check(canonical_identity_authority=false));

alter table ecology.ssr_air_response_playbooks enable row level security;
alter table ecology.ssr_air_event_exposure_candidates enable row level security;
alter table ecology.ssr_air_event_playbook_assignments enable row level security;
create policy ssr_air_response_playbooks_service_role on ecology.ssr_air_response_playbooks for all to service_role using(true) with check(true);
create policy ssr_air_exposure_service_role on ecology.ssr_air_event_exposure_candidates for all to service_role using(true) with check(true);
create policy ssr_air_playbook_assignments_service_role on ecology.ssr_air_event_playbook_assignments for all to service_role using(true) with check(true);
revoke all on ecology.ssr_air_response_playbooks,ecology.ssr_air_event_exposure_candidates,ecology.ssr_air_event_playbook_assignments from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_air_response_playbooks,ecology.ssr_air_event_exposure_candidates,ecology.ssr_air_event_playbook_assignments to service_role;

insert into ecology.ssr_air_response_playbooks(playbook_code,playbook_name,event_types,min_severity,signal_flags_any,response_scope,steps)
values
('AIR_HIGH_ENVIRONMENTAL_REVIEW','High AIR Environmental Review','{AIR_CHANGE_EVENT,AIR_COMPOSITE_EVENT}','HIGH','{}','internal_environmental_review',
 '[{"order":1,"action":"review_provider_evidence"},{"order":2,"action":"review_candidate_exposures"},{"order":3,"action":"request_independent_validation_if_needed"},{"order":4,"action":"record_governance_decision"}]'::jsonb),
('AIR_RAPID_CHANGE_REVIEW','Rapid Atmospheric Change Review','{}','ELEVATED','{RAPID_TEMPERATURE_CHANGE,RAPID_WIND_VECTOR_CHANGE,RAPID_HUMIDITY_CHANGE,VERTICAL_MOTION_CHANGE}','internal_environmental_review',
 '[{"order":1,"action":"compare_adjacent_profiles"},{"order":2,"action":"review_exposed_subject_candidates"},{"order":3,"action":"continue_monitoring_or_request_validation"}]'::jsonb)
on conflict(playbook_code) do update set enabled=true,updated_at=now();

create or replace function public.ssr_air_build_response_case(p_event_id uuid)
returns jsonb language plpgsql security definer set search_path=public,ecology,pg_temp as $$
declare v_event ecology.ssr_air_events%rowtype; v_exposure integer:=0; v_playbooks integer:=0;
begin
 select * into v_event from ecology.ssr_air_events where id=p_event_id; if not found then raise exception 'event not found'; end if;

 -- Geographic associations are candidates only. A conservative 0.35-degree window is used solely to identify records for human review.
 insert into ecology.ssr_air_event_exposure_candidates(event_id,subject_type,subject_reference,subject_name,association_method,association_basis)
 select v_event.id,'SSR_ANCHOR_CANDIDATE',a.id::text,a.infrastructure_name,'GEOGRAPHIC_REVIEW_WINDOW',
 jsonb_build_object('event_grid_latitude',v_event.grid_latitude,'event_grid_longitude',v_event.grid_longitude,'anchor_latitude',a.latitude,'anchor_longitude',a.longitude,'latitude_delta',abs(a.latitude-v_event.grid_latitude),'longitude_delta',abs(a.longitude-v_event.grid_longitude),'note','candidate association only; no physical impact inferred')
 from ecology.ssr_anchor_candidate_registry a
 where abs(a.latitude-v_event.grid_latitude)<=0.35 and abs(a.longitude-v_event.grid_longitude)<=0.35
 on conflict(event_id,subject_type,subject_reference) do nothing;
 get diagnostics v_exposure=row_count;

 insert into ecology.ssr_air_event_playbook_assignments(event_id,playbook_id,proposed_reason)
 select v_event.id,p.id,jsonb_build_object('severity',v_event.severity,'event_type',v_event.event_type,'signal_flags',v_event.signal_flags,'reason','policy match; human activation required')
 from ecology.ssr_air_response_playbooks p where p.enabled and (p.min_severity='ELEVATED' or v_event.severity='HIGH')
 and (cardinality(p.event_types)=0 or v_event.event_type=any(p.event_types))
 and (cardinality(p.signal_flags_any)=0 or v_event.signal_flags && p.signal_flags_any)
 on conflict(event_id,playbook_id) do nothing;
 get diagnostics v_playbooks=row_count;

 return jsonb_build_object('event_id',p_event_id,'exposure_candidates_inserted',v_exposure,'playbooks_proposed',v_playbooks,
 'physical_impact_asserted',false,'external_action_performed',false,'official_warning_authority',false,'canonical_identity_authority',false);
end $$;
revoke all on function public.ssr_air_build_response_case(uuid) from public,anon,authenticated; grant execute on function public.ssr_air_build_response_case(uuid) to service_role;

create or replace function public.ssr_air_activate_playbook(p_assignment_id uuid,p_actor text)
returns jsonb language plpgsql security definer set search_path=public,ecology,pg_temp as $$
declare v ecology.ssr_air_event_playbook_assignments%rowtype;
begin if p_actor is null or length(trim(p_actor))=0 then raise exception 'actor required'; end if;
 update ecology.ssr_air_event_playbook_assignments set assignment_status='activated',activated_by=p_actor,activated_at=now(),updated_at=now()
 where id=p_assignment_id and assignment_status='proposed' returning * into v; if not found then raise exception 'proposed assignment not found'; end if;
 return jsonb_build_object('assignment_id',v.id,'event_id',v.event_id,'status',v.assignment_status,'activated_by',v.activated_by,'external_action_performed',false,'physical_impact_asserted',false);
end $$;
revoke all on function public.ssr_air_activate_playbook(uuid,text) from public,anon,authenticated; grant execute on function public.ssr_air_activate_playbook(uuid,text) to service_role;

create or replace view ecology.ssr_air_operational_response_status as
select e.id event_id,e.severity,e.lifecycle_status,e.provider_code,e.event_time,
 count(distinct x.id) exposure_candidate_count,
 count(distinct x.id) filter(where x.review_status='reviewed_relevant') reviewed_relevant_count,
 count(distinct p.id) playbook_assignment_count,
 count(distinct p.id) filter(where p.assignment_status='activated') activated_playbook_count,
 bool_or(coalesce(x.physical_impact_asserted,false)) physical_impact_asserted,
 bool_or(coalesce(p.external_action_performed,false)) external_action_performed,
 false::boolean official_warning_authority,false::boolean canonical_identity_authority
from ecology.ssr_air_events e left join ecology.ssr_air_event_exposure_candidates x on x.event_id=e.id
left join ecology.ssr_air_event_playbook_assignments p on p.event_id=e.id
group by e.id,e.severity,e.lifecycle_status,e.provider_code,e.event_time;

comment on table ecology.ssr_air_event_exposure_candidates is 'Candidate ecosystem associations for human review only. Geographic proximity does not establish exposure, causation, or physical impact.';
comment on table ecology.ssr_air_event_playbook_assignments is 'Proposed internal response playbooks require human activation and cannot themselves perform external actions.';
