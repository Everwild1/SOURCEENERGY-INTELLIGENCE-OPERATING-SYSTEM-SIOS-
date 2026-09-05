create table if not exists dhn_ops.enrollment_authorizations (
 enrollment_authorization_id uuid primary key default gen_random_uuid(),
 rollout_cohort_id uuid not null references dhn_ops.rollout_cohorts(rollout_cohort_id),
 authorization_code text not null unique,
 status text not null default 'draft' check(status in ('draft','approved','suspended','revoked','expired')),
 max_enrollments integer not null check(max_enrollments>0),
 minimum_data_profile jsonb not null default '{}'::jsonb,
 required_controls jsonb not null default '{}'::jsonb,
 suspension_triggers jsonb not null default '{}'::jsonb,
 approved_by text,
 approved_at timestamptz,
 expires_at timestamptz,
 created_at timestamptz not null default now()
);
create table if not exists dhn_ops.enrollment_events (
 enrollment_event_id uuid primary key default gen_random_uuid(),
 rollout_cohort_id uuid not null references dhn_ops.rollout_cohorts(rollout_cohort_id),
 authorization_code text not null,
 participant_reference_digest text not null,
 consent_reference_digest text not null,
 identity_reference_digest text not null,
 outcome text not null check(outcome in ('enrolled','denied','suspended','withdrawn')),
 reason_code text,
 operator_reference text not null,
 correlation_id text not null,
 evidence jsonb not null default '{}'::jsonb,
 occurred_at timestamptz not null default now(),
 check(evidence::text !~* '"(patient_id|actor_id|principal_ref|health_credential_id|cardiac_credential_id|clinical_resource_ref_id|diagnosis|medication|ecg|waveform|samples|raw_payload|biometric_template|phi)"[[:space:]]*:')
);
alter table dhn_ops.enrollment_authorizations enable row level security;
alter table dhn_ops.enrollment_events enable row level security;
revoke all privileges on dhn_ops.enrollment_authorizations,dhn_ops.enrollment_events from public,anon,authenticated;
grant all privileges on dhn_ops.enrollment_authorizations,dhn_ops.enrollment_events to service_role;
create policy enrollment_auth_service_role on dhn_ops.enrollment_authorizations for all to service_role using(true) with check(true);
create policy enrollment_events_service_role on dhn_ops.enrollment_events for all to service_role using(true) with check(true);
insert into dhn_ops.enrollment_authorizations(rollout_cohort_id,authorization_code,status,max_enrollments,minimum_data_profile,required_controls,suspension_triggers)
select rollout_cohort_id,'DHN-E13-R1-AUTH-01','draft',least(participant_limit,25),
 jsonb_build_object('operations_evidence','digests_and_references_only','raw_phi',false,'raw_biometric',false,'raw_telemetry',false),
 jsonb_build_object('identity_active',true,'consent_active',true,'heartbeatid_governed',true,'audit_required',true,'operator_accountability',true),
 jsonb_build_object('critical_security_incident',true,'audit_capture_below_100_pct',true,'duplicate_economic_execution',true,'identity_or_consent_control_failure',true)
from dhn_ops.rollout_cohorts where cohort_code='DHN-E13-COHORT-01'
on conflict(authorization_code) do nothing;
