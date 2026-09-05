alter table ecology.ssr_anchor_resolution_jobs
  add column if not exists network_request_id bigint;

create or replace function public.ssr_anchor_resolution_dispatch(
  p_candidate_id uuid,
  p_operation text,
  p_elevation_dataset text default null
) returns jsonb
language plpgsql
security definer
set search_path=public,ecology,extensions,net,pg_temp
as $$
declare
  v_token text;
  v_hash text;
  v_job_id uuid;
  v_request_id bigint;
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

  v_request_id:=net.http_post(
    url:='https://veopccdltsklczlmdbri.supabase.co/functions/v1/ssr-anchor-resolution-worker',
    body:=jsonb_build_object(
      'job_id',v_job_id,
      'job_token',v_token,
      'worker_id','LAND_CLOSURE_PG_NET'
    ),
    params:='{}'::jsonb,
    headers:=jsonb_build_object('Content-Type','application/json'),
    timeout_milliseconds:=120000
  );

  update ecology.ssr_anchor_resolution_jobs
  set network_request_id=v_request_id,
      result_summary=jsonb_build_object('dispatch_method','pg_net','network_request_id',v_request_id),
      updated_at=now()
  where id=v_job_id;

  return jsonb_build_object(
    'job_id',v_job_id,
    'network_request_id',v_request_id,
    'job_status','queued',
    'dispatch_method','pg_net_after_commit'
  );
end $$;
