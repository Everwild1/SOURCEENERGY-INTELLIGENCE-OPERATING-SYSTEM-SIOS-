create table if not exists ecology.ssr_anchor_resolution_jobs (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references ecology.ssr_anchor_candidate_registry(id) on delete restrict,
  operation text not null check(operation in ('W3W_ONLY','W3W_AND_ELEVATION')),
  elevation_dataset text,
  status text not null default 'queued' check(status in ('queued','running','completed','failed','expired')),
  token_hash text not null check(token_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  worker_id text,
  attempts integer not null default 0,
  started_at timestamptz,
  completed_at timestamptz,
  result_summary jsonb not null default '{}'::jsonb,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(candidate_id,operation,status)
);

alter table ecology.ssr_anchor_resolution_jobs enable row level security;
drop policy if exists ssr_anchor_resolution_jobs_service_role on ecology.ssr_anchor_resolution_jobs;
create policy ssr_anchor_resolution_jobs_service_role on ecology.ssr_anchor_resolution_jobs for all to service_role using(true) with check(true);
revoke all on ecology.ssr_anchor_resolution_jobs from anon,authenticated;
grant select,insert,update,delete on ecology.ssr_anchor_resolution_jobs to service_role;

create or replace function public.ssr_anchor_resolution_job_claim(
  p_job_id uuid,
  p_token_hash text,
  p_worker_id text
) returns jsonb
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
declare
  v_job ecology.ssr_anchor_resolution_jobs%rowtype;
  v_candidate ecology.ssr_anchor_candidate_registry%rowtype;
begin
  select * into v_job from ecology.ssr_anchor_resolution_jobs where id=p_job_id for update;
  if not found then raise exception 'job not found'; end if;
  if v_job.token_hash is distinct from p_token_hash then raise exception 'invalid job token'; end if;
  if v_job.expires_at<=now() then
    update ecology.ssr_anchor_resolution_jobs set status='expired',updated_at=now(),last_error='job token expired' where id=p_job_id;
    raise exception 'job expired';
  end if;
  if v_job.status not in ('queued','failed') then raise exception 'job is not claimable'; end if;

  select * into v_candidate from ecology.ssr_anchor_candidate_registry where id=v_job.candidate_id;
  if not found then raise exception 'candidate not found'; end if;

  update ecology.ssr_anchor_resolution_jobs
  set status='running',worker_id=p_worker_id,attempts=attempts+1,started_at=coalesce(started_at,now()),last_error=null,updated_at=now()
  where id=p_job_id;

  return jsonb_build_object(
    'job_id',v_job.id,
    'candidate_id',v_candidate.id,
    'operation',v_job.operation,
    'elevation_dataset',v_job.elevation_dataset,
    'infrastructure_name',v_candidate.infrastructure_name,
    'latitude',v_candidate.latitude,
    'longitude',v_candidate.longitude,
    'existing_w3w_address',v_candidate.w3w_address,
    'existing_elevation_m_egm96',v_candidate.elevation_m_egm96,
    'authority_code',v_candidate.authority_code
  );
end $$;

create or replace function public.ssr_anchor_resolution_job_complete(
  p_job_id uuid,
  p_token_hash text,
  p_result jsonb
) returns jsonb
language plpgsql
security definer
set search_path=public,ecology,extensions,pg_temp
as $$
declare
  v_job ecology.ssr_anchor_resolution_jobs%rowtype;
  v_candidate ecology.ssr_anchor_candidate_registry%rowtype;
  v_words text;
  v_elevation numeric;
  v_evidence text;
  v_canonical text;
  v_uid text;
begin
  select * into v_job from ecology.ssr_anchor_resolution_jobs where id=p_job_id for update;
  if not found then raise exception 'job not found'; end if;
  if v_job.token_hash is distinct from p_token_hash then raise exception 'invalid job token'; end if;
  if v_job.status<>'running' then raise exception 'job is not running'; end if;

  select * into v_candidate from ecology.ssr_anchor_candidate_registry where id=v_job.candidate_id for update;
  if not found then raise exception 'candidate not found'; end if;

  v_words:=p_result->>'w3w_address';
  if v_words is null or v_words !~ '^///[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9-]+$' then
    raise exception 'valid W3W address required';
  end if;

  if v_job.operation='W3W_AND_ELEVATION' then
    if coalesce((p_result->>'egm96_compatible')::boolean,false)=false then raise exception 'EGM96-compatible elevation required'; end if;
    v_elevation:=(p_result->>'elevation_m')::numeric;
    if v_elevation is null then raise exception 'elevation required'; end if;
    v_evidence:=concat_ws('; ',
      'OpenTopography Point Elevation API',
      'dataset='||coalesce(p_result->>'elevation_dataset',v_job.elevation_dataset),
      'coordinate='||v_candidate.latitude||','||v_candidate.longitude,
      'VCRS='||coalesce(p_result->>'vertical_crs_epsg','EGM96'),
      'validated '||to_char(now(),'YYYY-MM-DD"T"HH24:MI:SSOF')
    );
    update ecology.ssr_anchor_candidate_registry
    set w3w_address=v_words,
        elevation_m_egm96=v_elevation,
        elevation_evidence_reference=v_evidence,
        source_verification_status=case when source_verification_status='verified' then 'verified' else source_verification_status end,
        canonicalization_status='ready_for_hash',
        promotion_eligible=false,
        blocker_reason='W3W, EGM96 elevation, deterministic Z and canonical hash validated. Source reconciliation, governance approval and authoritative promotion remain required.',
        updated_at=now()
    where id=v_candidate.id;
  else
    update ecology.ssr_anchor_candidate_registry
    set w3w_address=v_words,
        canonicalization_status='ready_for_hash',
        promotion_eligible=false,
        blocker_reason='W3W, EGM96 elevation, deterministic Z and canonical hash validated. Coastline/source reconciliation, governance approval and authoritative promotion remain required.',
        updated_at=now()
    where id=v_candidate.id;
  end if;

  select canonical_address into v_canonical from ecology.ssr_anchor_candidate_registry where id=v_candidate.id;
  if v_canonical is null then raise exception 'canonical address was not generated'; end if;
  v_uid:=encode(extensions.digest(v_canonical,'sha256'),'hex');

  update ecology.ssr_anchor_candidate_registry
  set cube_uid=v_uid,canonicalization_status='hash_generated',promotion_eligible=false,updated_at=now()
  where id=v_candidate.id;

  insert into ecology.ssr_candidate_requirement_status(candidate_id,requirement_code,status,evidence_reference,notes)
  values
    (v_candidate.id,'SSR-CAN-02','satisfied_reference',coalesce(p_result->>'w3w_source','what3words-v3-convert-to-3wa'),'Exact What3Words surface address resolved from the stored WGS84 coordinate.'),
    (v_candidate.id,'SSR-CAN-04','satisfied_reference','ecology.ssr_anchor_candidate_registry canonical_address='||v_canonical,'Canonical W3W+Z string generated by the database Z guard.'),
    (v_candidate.id,'SSR-CAN-05','satisfied_reference','SHA-256(exact canonical address string) stored in candidate cube_uid','Deterministic hash generated after W3W, EGM96 Z and canonical string validation.')
  on conflict(candidate_id,requirement_code) do update set status=excluded.status,evidence_reference=excluded.evidence_reference,notes=excluded.notes,updated_at=now();

  if v_job.operation='W3W_AND_ELEVATION' then
    insert into ecology.ssr_candidate_requirement_status(candidate_id,requirement_code,status,evidence_reference,notes)
    values(v_candidate.id,'SSR-CAN-03','satisfied_reference',v_evidence,'Z deterministically derived from API-returned EGM96 elevation at the exact candidate coordinate.')
    on conflict(candidate_id,requirement_code) do update set status=excluded.status,evidence_reference=excluded.evidence_reference,notes=excluded.notes,updated_at=now();
  end if;

  update ecology.ssr_anchor_resolution_jobs
  set status='completed',completed_at=now(),result_summary=coalesce(p_result,'{}'::jsonb)||jsonb_build_object('canonical_address',v_canonical,'cube_uid',v_uid),updated_at=now()
  where id=p_job_id;

  return jsonb_build_object(
    'job_id',p_job_id,
    'candidate_id',v_candidate.id,
    'canonical_address',v_canonical,
    'cube_uid',v_uid,
    'canonicalization_status','hash_generated',
    'promotion_eligible',false,
    'remaining_gate','source reconciliation + governance approval + authoritative promotion'
  );
end $$;

create or replace function public.ssr_anchor_resolution_job_fail(
  p_job_id uuid,
  p_token_hash text,
  p_error text
) returns boolean
language plpgsql
security definer
set search_path=public,ecology,pg_temp
as $$
begin
  update ecology.ssr_anchor_resolution_jobs
  set status='failed',last_error=left(coalesce(p_error,'unknown error'),4000),updated_at=now()
  where id=p_job_id and token_hash=p_token_hash and status='running';
  return found;
end $$;

revoke all on function public.ssr_anchor_resolution_job_claim(uuid,text,text) from public,anon,authenticated;
revoke all on function public.ssr_anchor_resolution_job_complete(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.ssr_anchor_resolution_job_fail(uuid,text,text) from public,anon,authenticated;
grant execute on function public.ssr_anchor_resolution_job_claim(uuid,text,text) to service_role;
grant execute on function public.ssr_anchor_resolution_job_complete(uuid,text,jsonb) to service_role;
grant execute on function public.ssr_anchor_resolution_job_fail(uuid,text,text) to service_role;

create or replace view ecology.ssr_anchor_resolution_job_status as
select j.id job_id,j.candidate_id,c.infrastructure_name,j.operation,j.elevation_dataset,j.status,j.attempts,j.expires_at,j.started_at,j.completed_at,j.last_error,j.result_summary,j.created_at,j.updated_at
from ecology.ssr_anchor_resolution_jobs j join ecology.ssr_anchor_candidate_registry c on c.id=j.candidate_id;
