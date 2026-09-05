create or replace function dhn_ops.evaluate_enrollment(
 p_authorization_code text,
 p_participant_reference_digest text,
 p_consent_reference_digest text,
 p_identity_reference_digest text,
 p_identity_active boolean,
 p_consent_active boolean,
 p_heartbeatid_governed boolean,
 p_operator_reference text,
 p_correlation_id text,
 p_commit boolean default false
) returns jsonb
language plpgsql security invoker set search_path=pg_catalog,dhn_ops as $$
declare a dhn_ops.enrollment_authorizations%rowtype; c dhn_ops.rollout_cohorts%rowtype; decision text:='denied'; reason text; current_count integer; ev uuid;
begin
 select * into a from dhn_ops.enrollment_authorizations where authorization_code=p_authorization_code for update;
 if not found then return jsonb_build_object('decision','denied','reason','authorization_not_found'); end if;
 select * into c from dhn_ops.rollout_cohorts where rollout_cohort_id=a.rollout_cohort_id for update;
 current_count:=c.enrolled_count;
 if a.status<>'approved' then reason:='authorization_not_approved';
 elsif c.status<>'active' then reason:='cohort_not_active';
 elsif a.expires_at is not null and a.expires_at<=now() then reason:='authorization_expired';
 elsif current_count>=least(a.max_enrollments,c.participant_limit) then reason:='cohort_capacity_reached';
 elsif not p_identity_active then reason:='identity_not_active';
 elsif not p_consent_active then reason:='consent_not_active';
 elsif not p_heartbeatid_governed then reason:='heartbeatid_control_not_satisfied';
 elsif exists(select 1 from dhn_ops.incidents where status in ('open','investigating') and severity='critical') then reason:='critical_incident_open';
 else decision:='enrolled'; reason:='all_controls_satisfied'; end if;
 if p_commit then
   insert into dhn_ops.enrollment_events(rollout_cohort_id,authorization_code,participant_reference_digest,consent_reference_digest,identity_reference_digest,outcome,reason_code,operator_reference,correlation_id,evidence)
   values(c.rollout_cohort_id,p_authorization_code,p_participant_reference_digest,p_consent_reference_digest,p_identity_reference_digest,decision,reason,p_operator_reference,p_correlation_id,jsonb_build_object('decision_engine','dhn-e13-r2-v1')) returning enrollment_event_id into ev;
   if decision='enrolled' then update dhn_ops.rollout_cohorts set enrolled_count=enrolled_count+1 where rollout_cohort_id=c.rollout_cohort_id; end if;
 end if;
 return jsonb_build_object('decision',decision,'reason',reason,'committed',p_commit,'enrollment_event_id',ev,'current_enrolled_count',current_count,'capacity',least(a.max_enrollments,c.participant_limit));
end $$;
revoke all on function dhn_ops.evaluate_enrollment(text,text,text,text,boolean,boolean,boolean,text,text,boolean) from public,anon,authenticated;
grant execute on function dhn_ops.evaluate_enrollment(text,text,text,text,boolean,boolean,boolean,text,text,boolean) to service_role;
