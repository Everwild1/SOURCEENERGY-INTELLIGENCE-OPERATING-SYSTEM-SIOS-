alter table ecology.ssr_sea_validation_jobs
  add column if not exists worker_id text,
  add column if not exists lease_token uuid,
  add column if not exists leased_at timestamptz,
  add column if not exists leased_until timestamptz,
  add column if not exists started_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists output_observation_ids uuid[] not null default '{}'::uuid[],
  add column if not exists result_quality_gate text,
  add column if not exists callback_reference text;

create index if not exists ix_ssr_sea_validation_jobs_dispatch
  on ecology.ssr_sea_validation_jobs(provider_code,job_status,priority,requested_at)
  where job_status in ('queued','failed');

create table if not exists ecology.ssr_sea_validation_job_audit (
  id bigserial primary key,
  job_id uuid not null references ecology.ssr_sea_validation_jobs(id) on delete restrict,
  event_id uuid not null references ecology.ssr_air_events(id) on delete restrict,
  audit_action text not null,
  previous_status text,
  new_status text,
  worker_id text,
  audit_payload jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);

alter table ecology.ssr_sea_validation_job_audit enable row level security;
drop policy if exists ssr_sea_validation_job_audit_select on ecology.ssr_sea_validation_job_audit;
create policy ssr_sea_validation_job_audit_select on ecology.ssr_sea_validation_job_audit
  for select to service_role using(true);
revoke all on ecology.ssr_sea_validation_job_audit from anon,authenticated;
grant select on ecology.ssr_sea_validation_job_audit to service_role;

create or replace function ecology.audit_ssr_sea_validation_job()
returns trigger language plpgsql security definer set search_path=ecology,public,pg_temp as $$
begin
  if tg_op='INSERT' then
    insert into ecology.ssr_sea_validation_job_audit(job_id,event_id,audit_action,previous_status,new_status,worker_id,audit_payload)
    values(new.id,new.event_id,'created',null,new.job_status,new.worker_id,
      jsonb_build_object('provider_code',new.provider_code,'job_type',new.job_type,'priority',new.priority,'blocker_reason',new.blocker_reason));
    return new;
  end if;
  if tg_op='UPDATE' then
    insert into ecology.ssr_sea_validation_job_audit(job_id,event_id,audit_action,previous_status,new_status,worker_id,audit_payload)
    values(new.id,new.event_id,
      case when old.job_status is distinct from new.job_status then 'status_transition' else 'updated' end,
      old.job_status,new.job_status,new.worker_id,
      jsonb_build_object('attempts',new.attempts,'last_error',new.last_error,'quality_gate',new.result_quality_gate,'output_observation_ids',new.output_observation_ids));
    return new;
  end if;
  return new;
end $$;

drop trigger if exists trg_ssr_sea_validation_job_audit on ecology.ssr_sea_validation_jobs;
create trigger trg_ssr_sea_validation_job_audit
after insert or update on ecology.ssr_sea_validation_jobs
for each row execute function ecology.audit_ssr_sea_validation_job();

create or replace function ecology.block_ssr_sea_validation_job_audit_mutation()
returns trigger language plpgsql as $$ begin raise exception 'ssr_sea_validation_job_audit is append-only'; end $$;
drop trigger if exists trg_block_ssr_sea_validation_job_audit_mutation on ecology.ssr_sea_validation_job_audit;
create trigger trg_block_ssr_sea_validation_job_audit_mutation
before update or delete on ecology.ssr_sea_validation_job_audit
for each row execute function ecology.block_ssr_sea_validation_job_audit_mutation();

create or replace function public.ssr_sea_provider_set_readiness(
  p_provider_code text,
  p_readiness_status text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare v_count integer:=0;
begin
  if p_readiness_status not in ('ready','credentials_required','runtime_required','credentials_and_runtime_required','blocked','planned') then
    raise exception 'unsupported readiness status';
  end if;

  update ecology.ssr_sea_provider_access_requirements
  set readiness_status=p_readiness_status,
      provider_metadata=provider_metadata||coalesce(p_metadata,'{}'::jsonb),
      updated_at=now(),
      external_action_authority=false,official_warning_authority=false,canonical_identity_authority=false
  where provider_code=p_provider_code;
  if not found then raise exception 'provider access requirement not found'; end if;

  if p_readiness_status='ready' then
    update ecology.ssr_sea_validation_jobs
    set job_status='queued',blocker_reason=null,updated_at=now()
    where provider_code=p_provider_code and job_status='blocked';
    get diagnostics v_count=ROW_COUNT;
  end if;

  return jsonb_build_object('provider_code',p_provider_code,'readiness_status',p_readiness_status,'jobs_unblocked',v_count,
    'external_action_performed',false,'official_warning_authority',false,'canonical_identity_authority',false);
end $$;

create or replace function public.ssr_sea_validation_job_claim_one(
  p_job_id uuid,
  p_worker_id text,
  p_lease_seconds integer default 600
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare v ecology.ssr_sea_validation_jobs%rowtype; v_ready text; v_token uuid:=gen_random_uuid();
begin
  if p_worker_id is null or length(trim(p_worker_id))=0 then raise exception 'worker id required'; end if;
  if p_lease_seconds<60 or p_lease_seconds>3600 then raise exception 'lease seconds must be 60..3600'; end if;

  select readiness_status into v_ready from ecology.ssr_sea_provider_access_requirements r
  join ecology.ssr_sea_validation_jobs j on j.provider_code=r.provider_code
  where j.id=p_job_id;
  if v_ready is distinct from 'ready' then raise exception 'provider is not ready'; end if;

  update ecology.ssr_sea_validation_jobs
  set job_status='running',worker_id=p_worker_id,lease_token=v_token,leased_at=now(),
      leased_until=now()+make_interval(secs=>p_lease_seconds),started_at=coalesce(started_at,now()),
      attempts=attempts+1,last_error=null,updated_at=now()
  where id=p_job_id
    and job_status in ('queued','failed')
    and (leased_until is null or leased_until<now())
  returning * into v;
  if not found then raise exception 'job not claimable'; end if;

  return jsonb_build_object('job_id',v.id,'event_id',v.event_id,'exposure_candidate_id',v.exposure_candidate_id,
    'provider_code',v.provider_code,'job_type',v.job_type,'lease_token',v.lease_token,'leased_until',v.leased_until,
    'attempt_number',v.attempts,'request_payload',v.request_payload,
    'contract_version','COPERNICUS_MARINE_WORKER_V1','physical_impact_authority',false,
    'official_warning_authority',false,'canonical_identity_authority',false);
end $$;

create or replace function public.ssr_sea_validation_job_record_result(
  p_job_id uuid,
  p_lease_token uuid,
  p_worker_id text,
  p_result jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_job ecology.ssr_sea_validation_jobs%rowtype;
  v_obs jsonb;
  v_obs_id uuid;
  v_ids uuid[]:='{}'::uuid[];
  v_ok boolean:=coalesce((p_result->>'ok')::boolean,false);
  v_gate text:=p_result->>'quality_gate';
  v_alignment text:=coalesce(p_result->>'event_alignment_gate','FAIL_EVENT_ALIGNMENT');
  v_validation_status text;
  v_error text;
begin
  select * into v_job from ecology.ssr_sea_validation_jobs where id=p_job_id for update;
  if not found then raise exception 'job not found'; end if;
  if v_job.lease_token is distinct from p_lease_token or v_job.worker_id is distinct from p_worker_id then
    raise exception 'lease token or worker mismatch';
  end if;

  if not v_ok or v_gate is distinct from 'PASS_COPERNICUS_MARINE_POINT_VALIDATION' then
    v_error:=coalesce(p_result->>'error',p_result->>'detail','worker result failed quality gate');
    update ecology.ssr_sea_validation_jobs
    set job_status='failed',last_error=v_error,result_summary=coalesce(p_result,'{}'::jsonb),
        result_quality_gate=v_gate,lease_token=null,leased_until=null,updated_at=now()
    where id=p_job_id;
    return jsonb_build_object('job_id',p_job_id,'job_status','failed','error',v_error,'observation_ids',v_ids);
  end if;

  if jsonb_typeof(coalesce(p_result->'observations','[]'::jsonb))<>'array' then
    raise exception 'observations must be a JSON array';
  end if;

  for v_obs in select value from jsonb_array_elements(coalesce(p_result->'observations','[]'::jsonb))
  loop
    v_obs:=v_obs||jsonb_build_object('provider_code','COP-MARINE','event_time_reference',v_job.request_payload->>'event_time');
    v_obs_id:=public.persist_ssr_sea_observation(v_obs);
    v_ids:=array_append(v_ids,v_obs_id);
  end loop;

  if cardinality(v_ids)=0 then raise exception 'successful result contained no observations'; end if;
  v_validation_status:=case when v_alignment='PASS_EVENT_ALIGNMENT' then 'evidence_available' else 'insufficient' end;

  update ecology.ssr_air_cross_domain_validations
  set validation_status=v_validation_status,
      evidence_reference=coalesce(p_result->>'evidence_reference',evidence_reference),
      evidence_snapshot=evidence_snapshot||coalesce(p_result,'{}'::jsonb),
      review_conclusion=case when v_alignment='PASS_EVENT_ALIGNMENT'
        then 'Event-aligned Copernicus Marine scientific evidence acquired; human relevance review remains required.'
        else 'Copernicus Marine evidence acquired but does not satisfy the event-time alignment gate.' end,
      impact_conclusion='NOT_ASSESSED',reviewer='COPERNICUS_MARINE_WORKER',reviewed_at=now(),
      physical_impact_asserted=false,external_action_authority=false,official_warning_authority=false,canonical_identity_authority=false,updated_at=now()
  where event_id=v_job.event_id and exposure_candidate_id=v_job.exposure_candidate_id
    and provider_code='COP-MARINE' and validation_type='MARINE_STATE_REVIEW';

  update ecology.ssr_sea_validation_jobs
  set job_status='completed',output_observation_ids=v_ids,result_summary=coalesce(p_result,'{}'::jsonb),
      result_quality_gate=v_gate,callback_reference=p_result->>'callback_reference',completed_at=now(),
      lease_token=null,leased_until=null,last_error=null,updated_at=now()
  where id=p_job_id;

  return jsonb_build_object('job_id',p_job_id,'job_status','completed','quality_gate',v_gate,
    'event_alignment_gate',v_alignment,'observation_ids',v_ids,'physical_impact_asserted',false,
    'official_warning_authority',false,'canonical_identity_authority',false);
end $$;

revoke all on function public.ssr_sea_provider_set_readiness(text,text,jsonb) from public,anon,authenticated;
revoke all on function public.ssr_sea_validation_job_claim_one(uuid,text,integer) from public,anon,authenticated;
revoke all on function public.ssr_sea_validation_job_record_result(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.ssr_sea_provider_set_readiness(text,text,jsonb) to service_role;
grant execute on function public.ssr_sea_validation_job_claim_one(uuid,text,integer) to service_role;
grant execute on function public.ssr_sea_validation_job_record_result(uuid,uuid,text,jsonb) to service_role;

create or replace view ecology.ssr_copernicus_marine_worker_status as
select
  r.provider_code,r.supported_access_method,r.runtime_requirement,r.credential_requirement,r.readiness_status,
  count(j.id) filter(where j.job_status='blocked') blocked_jobs,
  count(j.id) filter(where j.job_status='queued') queued_jobs,
  count(j.id) filter(where j.job_status='running') running_jobs,
  count(j.id) filter(where j.job_status='completed') completed_jobs,
  count(j.id) filter(where j.job_status='failed') failed_jobs,
  max(j.updated_at) latest_job_update,
  false::boolean external_action_authority,
  false::boolean physical_impact_authority,
  false::boolean official_warning_authority,
  false::boolean canonical_identity_authority
from ecology.ssr_sea_provider_access_requirements r
left join ecology.ssr_sea_validation_jobs j on j.provider_code=r.provider_code
where r.provider_code='COP-MARINE'
group by r.provider_code,r.supported_access_method,r.runtime_requirement,r.credential_requirement,r.readiness_status;

comment on function public.ssr_sea_validation_job_record_result(uuid,uuid,text,jsonb) is 'Governed Copernicus Marine worker callback. A successful scientific result updates evidence only; it cannot assert physical impact, issue warnings, perform external actions, or alter canonical SSR identity.';
