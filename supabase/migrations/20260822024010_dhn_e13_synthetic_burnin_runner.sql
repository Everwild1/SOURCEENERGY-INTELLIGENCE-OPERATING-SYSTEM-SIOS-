create or replace function dhn_ops.run_synthetic_burnin()
returns jsonb
language plpgsql
security invoker
set search_path=pg_catalog,dhn_ops
as $$
declare
  v_before_measurements bigint;
  v_before_incidents bigint;
  v_after_measurements bigint;
  v_after_incidents bigint;
  v_pass bigint;
  v_fail bigint;
  v_gate_count bigint;
  v_summary jsonb;
begin
  select count(*) into v_before_measurements from dhn_ops.slo_measurements;
  select count(*) into v_before_incidents from dhn_ops.incidents;

  perform dhn_ops.evaluate_slo('E13-SLO-AUTH-AVAIL',99.95,now()-interval '30 days',now(),'synthetic_burnin',jsonb_build_object('synthetic',true));
  perform dhn_ops.evaluate_slo('E13-SLO-AUTH-P95',850,now()-interval '24 hours',now(),'synthetic_burnin',jsonb_build_object('synthetic',true));
  perform dhn_ops.evaluate_slo('E13-SLO-TELEM-VALID',99.5,now()-interval '24 hours',now(),'synthetic_burnin',jsonb_build_object('synthetic',true));
  perform dhn_ops.evaluate_slo('E13-SLO-AUDIT',100,now()-interval '24 hours',now(),'synthetic_burnin',jsonb_build_object('synthetic',true));
  perform dhn_ops.evaluate_slo('E13-SLO-SETTLE',0,now()-interval '30 days',now(),'synthetic_burnin',jsonb_build_object('synthetic',true));

  select count(*) filter(where status='within_target'), count(*) filter(where status='breach')
    into v_pass,v_fail
  from dhn_ops.slo_measurements
  where source='synthetic_burnin' and measured_at >= now()-interval '5 minutes';

  select count(*) into v_gate_count
  from dhn_ops.rollout_gate_results r
  join dhn_ops.rollout_cohorts c on c.rollout_cohort_id=r.rollout_cohort_id
  where c.cohort_code='DHN-E13-COHORT-01';

  select count(*) into v_after_measurements from dhn_ops.slo_measurements;
  select count(*) into v_after_incidents from dhn_ops.incidents;

  v_summary:=jsonb_build_object(
    'slo_pass',v_pass,
    'slo_fail',v_fail,
    'rollout_gate_count',v_gate_count,
    'new_measurements',v_after_measurements-v_before_measurements,
    'new_incidents',v_after_incidents-v_before_incidents,
    'ready_for_gate_evaluation',(v_pass=5 and v_fail=0 and v_gate_count=8 and (v_after_incidents-v_before_incidents)=0)
  );

  delete from dhn_ops.slo_measurements where source='synthetic_burnin' and measured_at >= now()-interval '5 minutes';
  delete from dhn_ops.incidents where summary like 'SLO breach:%' and opened_at >= now()-interval '5 minutes' and evidence->>'measurement_id' is not null and not exists(select 1 from dhn_ops.slo_measurements m where m.slo_measurement_id::text=dhn_ops.incidents.evidence->>'measurement_id');

  return v_summary;
end $$;

revoke all on function dhn_ops.run_synthetic_burnin() from public,anon,authenticated;
grant execute on function dhn_ops.run_synthetic_burnin() to service_role;
