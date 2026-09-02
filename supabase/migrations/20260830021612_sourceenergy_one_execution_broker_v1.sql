create or replace function sourceenergy_one.execute_authorized_action(
  p_authorization_request_id uuid,
  p_adapter_key text,
  p_external_ref text default null,
  p_receipt jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path = sourceenergy_one, pg_temp
as $$
declare
  ar sourceenergy_one.authorization_requests%rowtype;
  ad sourceenergy_one.domain_adapter_registry%rowtype;
  er_id uuid;
begin
  select * into ar from sourceenergy_one.authorization_requests where id = p_authorization_request_id for update;
  if not found then raise exception 'authorization request not found'; end if;
  if ar.status <> 'approved' then raise exception 'authorization request not approved'; end if;

  select * into ad from sourceenergy_one.domain_adapter_registry where adapter_key = p_adapter_key for update;
  if not found then raise exception 'adapter not found'; end if;
  if not ad.enabled then raise exception 'adapter disabled'; end if;
  if ad.mode <> 'execute' then raise exception 'adapter not executable'; end if;

  if exists (
    select 1 from sourceenergy_one.execution_receipts
    where correlation_id = ar.correlation_id
      and adapter_key = p_adapter_key
      and status = 'executed'
  ) then
    raise exception 'authorized action already executed for adapter';
  end if;

  insert into sourceenergy_one.execution_receipts(
    correlation_id, adapter_key, external_ref, status, receipt
  ) values (
    ar.correlation_id, p_adapter_key, p_external_ref, 'executed',
    coalesce(p_receipt,'{}'::jsonb) || jsonb_build_object(
      'authorization_request_id', ar.id,
      'action', ar.action,
      'resource_type', ar.resource_type,
      'resource_ref', ar.resource_ref
    )
  ) returning id into er_id;

  insert into sourceenergy_one.audit_events(
    correlation_id, subject_id, actor_id, event_type, object_type, object_ref, payload
  ) values (
    ar.correlation_id, ar.subject_id, auth.uid(), 'authorized_action_executed', 'execution_receipt', er_id::text,
    jsonb_build_object('authorization_request_id',ar.id,'adapter_key',p_adapter_key,'action',ar.action)
  );

  return er_id;
end;
$$;

revoke all on function sourceenergy_one.execute_authorized_action(uuid,text,text,jsonb) from public, anon, authenticated;
grant execute on function sourceenergy_one.execute_authorized_action(uuid,text,text,jsonb) to service_role;
comment on function sourceenergy_one.execute_authorized_action(uuid,text,text,jsonb) is 'Final execution gate: requires approved authorization request and enabled execute-mode adapter, prevents duplicate execution for correlation+adapter, and appends execution receipt/audit event.';
