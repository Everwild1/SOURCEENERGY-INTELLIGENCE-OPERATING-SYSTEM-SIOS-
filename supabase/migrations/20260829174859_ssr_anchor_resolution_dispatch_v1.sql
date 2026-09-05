alter table ecology.ssr_anchor_resolution_jobs
  drop constraint if exists ssr_anchor_resolution_jobs_candidate_id_operation_status_key;

create unique index if not exists ux_ssr_anchor_resolution_jobs_active
  on ecology.ssr_anchor_resolution_jobs(candidate_id,operation)
  where status in ('queued','running');

create or replace function public.ssr_anchor_resolution_dispatch(
  p_candidate_id uuid,
  p_operation text,
  p_elevation_dataset text default null
) returns jsonb
language plpgsql
security definer
set search_path=public,ecology,extensions,pg_temp
as $$
declare
  v_token text;
  v_hash text;
  v_job_id uuid;
  v_response extensions.http_response;
  v_body jsonb;
  v_status integer;
begin
  if p_operation not in ('W3W_ONLY','W3W_AND_ELEVATION') then
    raise exception 'unsupported operation';
  end if;
  if not exists(select 1 from ecology.ssr_anchor_candidate_registry where id=p_candidate_id) then
    raise exception 'candidate not found';
  end if;
  if exists(select 1 from ecology.ssr_anchor_resolution_jobs where candidate_id=p_candidate_id and operation=p_operation and status in ('queued','running')) then
    raise exception 'active job already exists for candidate and operation';
  end if;

  v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
  v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');

  insert into ecology.ssr_anchor_resolution_jobs(
    candidate_id,operation,elevation_dataset,status,token_hash,expires_at
  ) values (
    p_candidate_id,p_operation,p_elevation_dataset,'queued',v_hash,now()+interval '30 minutes'
  ) returning id into v_job_id;

  select * into v_response
  from extensions.http_post(
    'https://veopccdltsklczlmdbri.supabase.co/functions/v1/ssr-anchor-resolution-worker'::varchar,
    jsonb_build_object(
      'job_id',v_job_id,
      'job_token',v_token,
      'worker_id','LAND_CLOSURE_DB_DISPATCH'
    )::text::varchar,
    'application/json'::varchar
  );

  v_status:=v_response.status;
  begin
    v_body:=v_response.content::jsonb;
  exception when others then
    v_body:=jsonb_build_object('raw_content',left(coalesce(v_response.content,''),4000));
  end;

  if v_status<200 or v_status>=300 then
    update ecology.ssr_anchor_resolution_jobs
    set status=case when status='queued' then 'failed' else status end,
        last_error=coalesce(v_body->>'detail',v_body->>'error','dispatcher received HTTP '||v_status),
        updated_at=now()
    where id=v_job_id;
  end if;

  return jsonb_build_object(
    'job_id',v_job_id,
    'http_status',v_status,
    'worker_response',v_body,
    'job_status',(select status from ecology.ssr_anchor_resolution_jobs where id=v_job_id)
  );
end $$;

revoke all on function public.ssr_anchor_resolution_dispatch(uuid,text,text) from public,anon,authenticated;
grant execute on function public.ssr_anchor_resolution_dispatch(uuid,text,text) to service_role;
