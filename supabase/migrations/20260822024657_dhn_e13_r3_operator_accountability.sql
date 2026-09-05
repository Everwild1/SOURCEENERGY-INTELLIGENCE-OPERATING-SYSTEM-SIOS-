create table if not exists dhn_ops.rollout_operators (
 rollout_operator_id uuid primary key default gen_random_uuid(),
 operator_reference text not null unique,
 operator_role text not null check(operator_role in ('enrollment_operator','enrollment_approver','security_operator','incident_commander')),
 status text not null default 'pending' check(status in ('pending','active','suspended','revoked')),
 scope jsonb not null default '{}'::jsonb,
 assurance_metadata jsonb not null default '{}'::jsonb,
 approved_by text,
 approved_at timestamptz,
 created_at timestamptz not null default now()
);
create table if not exists dhn_ops.authorization_approval_events (
 approval_event_id uuid primary key default gen_random_uuid(),
 authorization_code text not null,
 action text not null check(action in ('approve','suspend','revoke','expire')),
 approver_reference text not null,
 reason text not null,
 correlation_id text not null,
 evidence jsonb not null default '{}'::jsonb,
 occurred_at timestamptz not null default now(),
 check(evidence::text !~* '"(patient_id|actor_id|principal_ref|health_credential_id|cardiac_credential_id|clinical_resource_ref_id|diagnosis|medication|ecg|waveform|samples|raw_payload|biometric_template|phi)"[[:space:]]*:')
);
alter table dhn_ops.rollout_operators enable row level security;
alter table dhn_ops.authorization_approval_events enable row level security;
revoke all privileges on dhn_ops.rollout_operators,dhn_ops.authorization_approval_events from public,anon,authenticated;
grant all privileges on dhn_ops.rollout_operators,dhn_ops.authorization_approval_events to service_role;
create policy rollout_operators_service_role on dhn_ops.rollout_operators for all to service_role using(true) with check(true);
create policy authorization_approval_events_service_role on dhn_ops.authorization_approval_events for all to service_role using(true) with check(true);

create or replace function dhn_ops.approve_enrollment_authorization(p_authorization_code text,p_approver_reference text,p_reason text,p_correlation_id text)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,dhn_ops as $$
declare o dhn_ops.rollout_operators%rowtype; a dhn_ops.enrollment_authorizations%rowtype;
begin
 select * into o from dhn_ops.rollout_operators where operator_reference=p_approver_reference and operator_role='enrollment_approver' and status='active';
 if not found then return jsonb_build_object('approved',false,'reason','active_enrollment_approver_required'); end if;
 select * into a from dhn_ops.enrollment_authorizations where authorization_code=p_authorization_code for update;
 if not found then return jsonb_build_object('approved',false,'reason','authorization_not_found'); end if;
 if a.status<>'draft' then return jsonb_build_object('approved',false,'reason','authorization_not_draft','status',a.status); end if;
 update dhn_ops.enrollment_authorizations set status='approved',approved_by=p_approver_reference,approved_at=now() where enrollment_authorization_id=a.enrollment_authorization_id;
 insert into dhn_ops.authorization_approval_events(authorization_code,action,approver_reference,reason,correlation_id,evidence) values(p_authorization_code,'approve',p_approver_reference,p_reason,p_correlation_id,jsonb_build_object('operator_role','enrollment_approver','control_version','dhn-e13-r3-v1'));
 return jsonb_build_object('approved',true,'authorization_code',p_authorization_code,'approver_reference',p_approver_reference);
end $$;
revoke all on function dhn_ops.approve_enrollment_authorization(text,text,text,text) from public,anon,authenticated;
grant execute on function dhn_ops.approve_enrollment_authorization(text,text,text,text) to service_role;
