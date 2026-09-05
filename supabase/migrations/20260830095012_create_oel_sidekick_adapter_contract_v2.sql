create table if not exists oel.adapter_clients (
  id uuid primary key default gen_random_uuid(),
  client_code text not null unique,
  client_name text not null,
  status text not null default 'active' check (status in ('active','suspended','revoked')),
  allowed_org_oids text[] not null default '{}',
  allowed_actions text[] not null default '{}',
  maximum_control_level oel.control_level not null default 'C2',
  signature_algorithm text not null default 'HMAC-SHA256',
  key_reference text,
  clock_skew_seconds integer not null default 300 check (clock_skew_seconds between 30 and 900),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists oel.adapter_commands (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references oel.adapter_clients(id),
  command_id uuid not null,
  idempotency_key text not null,
  nonce text not null,
  request_timestamp timestamptz not null,
  received_at timestamptz not null default now(),
  correlation_id uuid not null,
  trace_id uuid not null,
  actor_external_ref text,
  channel_identity text,
  setc_org_oid text not null references public.setc_organizations(oid),
  action text not null,
  resource_type text not null,
  resource_id text,
  requested_control_level oel.control_level not null,
  payload jsonb not null default '{}'::jsonb,
  payload_hash text not null,
  signature text,
  signature_verified boolean not null default false,
  status text not null default 'RECEIVED' check (status in ('RECEIVED','REJECTED','ACCEPTED','EXECUTED','FAILED','REQUIRES_HUMAN_APPROVAL','DUPLICATE')),
  rejection_reason text,
  command_receipt_id uuid references oel.command_receipts(id),
  response jsonb,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (client_id, command_id),
  unique (client_id, idempotency_key),
  unique (client_id, nonce)
);

create index if not exists oel_adapter_commands_corr_idx on oel.adapter_commands(correlation_id);
create index if not exists oel_adapter_commands_status_idx on oel.adapter_commands(status, received_at desc);
create index if not exists oel_adapter_commands_actor_idx on oel.adapter_commands(actor_external_ref, received_at desc);

create table if not exists oel.adapter_receipts (
  id uuid primary key default gen_random_uuid(),
  adapter_command_id uuid not null unique references oel.adapter_commands(id) on delete cascade,
  receipt_type text not null check (receipt_type in ('ACCEPTED','REJECTED','EXECUTED','FAILED','REQUIRES_HUMAN_APPROVAL','DUPLICATE')),
  decision text,
  authorization_request_id uuid references sourceenergy_one.authorization_requests(id),
  event_ids uuid[] not null default '{}',
  response_hash text,
  response jsonb not null default '{}'::jsonb,
  issued_at timestamptz not null default now()
);

alter table oel.adapter_clients enable row level security;
alter table oel.adapter_commands enable row level security;
alter table oel.adapter_receipts enable row level security;
revoke all on oel.adapter_clients,oel.adapter_commands,oel.adapter_receipts from public,anon,authenticated;

create or replace function oel.register_adapter_command(
  p_client_code text,
  p_command_id uuid,
  p_idempotency_key text,
  p_nonce text,
  p_request_timestamp timestamptz,
  p_correlation_id uuid,
  p_trace_id uuid,
  p_setc_org_oid text,
  p_action text,
  p_resource_type text,
  p_resource_id text,
  p_requested_control_level oel.control_level,
  p_payload jsonb,
  p_payload_hash text,
  p_signature text default null,
  p_signature_verified boolean default false,
  p_actor_external_ref text default null,
  p_channel_identity text default null
) returns jsonb
language plpgsql
security invoker
set search_path=oel,public
as $$
declare
  v_client oel.adapter_clients%rowtype;
  v_existing oel.adapter_commands%rowtype;
  v_id uuid;
  v_now timestamptz:=now();
begin
  select * into v_client from oel.adapter_clients where client_code=p_client_code and status='active';
  if v_client.id is null then return jsonb_build_object('status','REJECTED','reason','unknown_or_inactive_client'); end if;
  if cardinality(v_client.allowed_org_oids)>0 and not (p_setc_org_oid=any(v_client.allowed_org_oids)) then return jsonb_build_object('status','REJECTED','reason','organization_not_allowed'); end if;
  if cardinality(v_client.allowed_actions)>0 and not (p_action=any(v_client.allowed_actions)) then return jsonb_build_object('status','REJECTED','reason','action_not_allowed'); end if;
  if p_requested_control_level > v_client.maximum_control_level then return jsonb_build_object('status','REJECTED','reason','control_level_exceeds_client_limit'); end if;
  if abs(extract(epoch from (v_now-p_request_timestamp))) > v_client.clock_skew_seconds then return jsonb_build_object('status','REJECTED','reason','request_timestamp_outside_allowed_window'); end if;

  select * into v_existing from oel.adapter_commands where client_id=v_client.id and (command_id=p_command_id or idempotency_key=p_idempotency_key or nonce=p_nonce) order by created_at desc limit 1;
  if v_existing.id is not null then
    return jsonb_build_object('status','DUPLICATE','adapter_command_id',v_existing.id,'previous_status',v_existing.status,'response',v_existing.response);
  end if;

  insert into oel.adapter_commands(client_id,command_id,idempotency_key,nonce,request_timestamp,correlation_id,trace_id,actor_external_ref,channel_identity,setc_org_oid,action,resource_type,resource_id,requested_control_level,payload,payload_hash,signature,signature_verified,status)
  values(v_client.id,p_command_id,p_idempotency_key,p_nonce,p_request_timestamp,p_correlation_id,p_trace_id,p_actor_external_ref,p_channel_identity,p_setc_org_oid,p_action,p_resource_type,p_resource_id,p_requested_control_level,coalesce(p_payload,'{}'::jsonb),p_payload_hash,p_signature,p_signature_verified,case when p_signature_verified then 'ACCEPTED' else 'REJECTED' end)
  returning id into v_id;

  if not p_signature_verified then
    update oel.adapter_commands set rejection_reason='signature_not_verified',completed_at=now() where id=v_id;
    insert into oel.adapter_receipts(adapter_command_id,receipt_type,decision,response)
    values(v_id,'REJECTED','DENY',jsonb_build_object('reason','signature_not_verified'));
    return jsonb_build_object('status','REJECTED','adapter_command_id',v_id,'reason','signature_not_verified');
  end if;

  insert into oel.adapter_receipts(adapter_command_id,receipt_type,decision,response)
  values(v_id,'ACCEPTED','ACCEPTED',jsonb_build_object('correlation_id',p_correlation_id,'trace_id',p_trace_id));

  return jsonb_build_object('status','ACCEPTED','adapter_command_id',v_id,'correlation_id',p_correlation_id,'trace_id',p_trace_id);
end;
$$;

create or replace function oel.finalize_adapter_command(
  p_adapter_command_id uuid,
  p_status text,
  p_response jsonb,
  p_authorization_request_id uuid default null,
  p_event_ids uuid[] default '{}'
) returns jsonb
language plpgsql
security invoker
set search_path=oel,sourceenergy_one,public
as $$
declare v_cmd oel.adapter_commands%rowtype; begin
  if p_status not in ('EXECUTED','FAILED','REQUIRES_HUMAN_APPROVAL') then raise exception 'invalid_final_status'; end if;
  select * into v_cmd from oel.adapter_commands where id=p_adapter_command_id for update;
  if v_cmd.id is null then raise exception 'adapter_command_not_found'; end if;
  if v_cmd.status in ('EXECUTED','FAILED','REQUIRES_HUMAN_APPROVAL','REJECTED') then return jsonb_build_object('status','DUPLICATE','previous_status',v_cmd.status,'response',v_cmd.response); end if;
  update oel.adapter_commands set status=p_status,response=coalesce(p_response,'{}'::jsonb),completed_at=now() where id=p_adapter_command_id;
  update oel.adapter_receipts set receipt_type=p_status,decision=case when p_status='EXECUTED' then 'ALLOW' when p_status='REQUIRES_HUMAN_APPROVAL' then 'REQUIRES_HUMAN_APPROVAL' else 'DENY' end,authorization_request_id=p_authorization_request_id,event_ids=coalesce(p_event_ids,'{}'),response=coalesce(p_response,'{}'::jsonb),issued_at=now() where adapter_command_id=p_adapter_command_id;
  return jsonb_build_object('status',p_status,'adapter_command_id',p_adapter_command_id,'authorization_request_id',p_authorization_request_id,'event_ids',p_event_ids);
end;
$$;

revoke all on function oel.register_adapter_command(text,uuid,text,text,timestamptz,uuid,uuid,text,text,text,text,oel.control_level,jsonb,text,text,boolean,text,text) from public,anon,authenticated;
revoke all on function oel.finalize_adapter_command(uuid,text,jsonb,uuid,uuid[]) from public,anon,authenticated;

comment on table oel.adapter_commands is 'OEL-ADAPTER-001 immutable command intake registry with per-client command-id, idempotency-key, nonce replay protection and request provenance.';
comment on function oel.register_adapter_command(text,uuid,text,text,timestamptz,uuid,uuid,text,text,text,text,oel.control_level,jsonb,text,text,boolean,text,text) is 'Registers a validated Sidekick adapter command after external signature verification. No direct user grant; intended for trusted server/edge adapter only.';
