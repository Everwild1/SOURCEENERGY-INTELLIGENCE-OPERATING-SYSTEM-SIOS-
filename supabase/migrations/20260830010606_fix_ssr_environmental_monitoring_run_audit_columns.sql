create or replace function ecology.audit_ssr_environmental_monitoring_run()
returns trigger
language plpgsql
security definer
set search_path=ecology,public,pg_temp
as $$
begin
  if tg_op='INSERT' then
    insert into ecology.ssr_environmental_monitoring_run_audit(
      run_id,watchlist_id,audit_action,status_before,status_after,worker_id,audit_payload
    ) values (
      new.id,new.watchlist_id,'created',null,new.run_status,new.worker_id,
      jsonb_build_object(
        'run_type',new.run_type,
        'scheduled_for',new.scheduled_for,
        'requested_domains',new.requested_domains,
        'network_request_id',new.network_request_id
      )
    );
    return new;
  end if;

  if tg_op='UPDATE' then
    insert into ecology.ssr_environmental_monitoring_run_audit(
      run_id,watchlist_id,audit_action,status_before,status_after,worker_id,audit_payload
    ) values (
      new.id,new.watchlist_id,
      case
        when old.run_status is distinct from new.run_status then 'status_transition'
        when old.network_request_id is distinct from new.network_request_id then 'dispatched'
        else 'updated'
      end,
      old.run_status,new.run_status,new.worker_id,
      jsonb_build_object(
        'attempt_count',new.attempt_count,
        'network_request_id',new.network_request_id,
        'leased_until',new.leased_until,
        'last_error',new.last_error,
        'completed_at',new.completed_at,
        'quality_gate',new.result_summary->>'quality_gate'
      )
    );
    return new;
  end if;
  return new;
end $$;
