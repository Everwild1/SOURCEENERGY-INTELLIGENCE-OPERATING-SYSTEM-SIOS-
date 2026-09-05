alter table public.sourcecube_execution_requests
  add column if not exists constitutional_authorization_id uuid references wealth_ecology.execution_authorizations(id) on delete restrict,
  add column if not exists constitutional_gate_version text default 'AGB-7D-L-v1';

alter table public.sourcecube_execution_requests
  drop constraint if exists sourcecube_execution_requests_constitutional_gate_version_check;
alter table public.sourcecube_execution_requests
  add constraint sourcecube_execution_requests_constitutional_gate_version_check
  check (constitutional_gate_version is null or constitutional_gate_version='AGB-7D-L-v1');

create or replace function private.sourcecube_require_constitutional_execution_authorization()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog'
as $$
declare
  a wealth_ecology.execution_authorizations%rowtype;
  readiness jsonb;
begin
  if new.constitutional_authorization_id is null then
    raise exception 'V38 SourceCube execution requires constitutional_authorization_id';
  end if;
  if new.constitutional_gate_version is distinct from 'AGB-7D-L-v1' then
    raise exception 'V38 SourceCube execution requires constitutional_gate_version AGB-7D-L-v1';
  end if;

  select * into a
  from wealth_ecology.execution_authorizations
  where id=new.constitutional_authorization_id;
  if not found then
    raise exception 'V38 constitutional execution authorization not found';
  end if;

  if a.authorization_state not in ('APPROVED','EXECUTING') then
    raise exception 'V38 constitutional execution authorization must be APPROVED or EXECUTING';
  end if;
  if a.constitutional_gate_version is distinct from 'AGB-7D-L-v1' then
    raise exception 'V38 linked authorization is not governed by AGB-7D-L-v1';
  end if;
  if a.constitutional_decision_id is null then
    raise exception 'V38 linked authorization lacks constitutional_decision_id';
  end if;

  readiness:=wealth_ecology.evaluate_decision_readiness_v2(a.constitutional_decision_id);
  if coalesce((readiness->>'authorization_ready')::boolean,false) is not true then
    raise exception 'V38 linked authorization is no longer constitutionally ready: %',readiness;
  end if;

  return new;
end;
$$;

drop trigger if exists sourcecube_execution_requests_constitutional_gate on public.sourcecube_execution_requests;
create trigger sourcecube_execution_requests_constitutional_gate
before insert on public.sourcecube_execution_requests
for each row execute function private.sourcecube_require_constitutional_execution_authorization();

create or replace function private.sourcecube_enqueue_aws_execution()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog'
as $$
begin
  insert into public.sourcecube_integration_outbox (execution_request_id)
  values (new.id);

  insert into public.sourcecube_events (
    assignment_id,event_type,actor_user_id,object_type,object_ref,payload
  ) values (
    new.assignment_id,
    'AWS_EXECUTION_REQUESTED',
    new.requested_by,
    'sourcecube_execution_request',
    new.id::text,
    jsonb_build_object(
      'integration_kind',new.integration_kind,
      'approval_id',new.approval_id,
      'idempotency_key',new.idempotency_key,
      'constitutional_authorization_id',new.constitutional_authorization_id,
      'constitutional_gate_version',new.constitutional_gate_version
    )
  );
  return new;
end;
$$;

comment on column public.sourcecube_execution_requests.constitutional_authorization_id is
'V38 binding to the canonical Wealth Ecology execution authorization. New SourceCube execution requests must reference an APPROVED/EXECUTING authorization that remains AGB-7D-L-v1 ready.';
comment on function private.sourcecube_require_constitutional_execution_authorization() is
'V38 fail-closed SourceCube execution gateway. Revalidates AGB-7D-L-v1 constitutional readiness at request insertion time before the AWS integration outbox is populated.';
