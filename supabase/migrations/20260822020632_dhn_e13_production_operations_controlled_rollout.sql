create table if not exists dhn_ops.rollout_cohorts (
  rollout_cohort_id uuid primary key default gen_random_uuid(),
  cohort_code text not null unique,
  cohort_type text not null check (cohort_type in ('internal','controlled_external','general_availability')),
  status text not null default 'planned' check (status in ('planned','active','paused','completed','rolled_back')),
  participant_limit integer not null check (participant_limit > 0),
  enrolled_count integer not null default 0 check (enrolled_count >= 0 and enrolled_count <= participant_limit),
  entry_criteria jsonb not null default '{}'::jsonb,
  exit_criteria jsonb not null default '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists dhn_ops.slo_definitions (
  slo_code text primary key,
  component text not null,
  metric_name text not null,
  target_operator text not null check (target_operator in ('gte','lte','eq')),
  target_value numeric not null,
  measurement_window text not null,
  severity_on_breach text not null check (severity_on_breach in ('low','medium','high','critical')),
  status text not null default 'active' check (status in ('active','suspended','retired')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists dhn_ops.rollout_gate_results (
  rollout_gate_result_id uuid primary key default gen_random_uuid(),
  rollout_cohort_id uuid not null references dhn_ops.rollout_cohorts(rollout_cohort_id) on delete cascade,
  gate_code text not null,
  domain text not null,
  status text not null default 'not_run' check (status in ('pass','fail','blocked','not_run')),
  expected_outcome text not null,
  observed_outcome text,
  evidence jsonb not null default '{}'::jsonb,
  evaluated_at timestamptz,
  unique(rollout_cohort_id,gate_code)
);

alter table dhn_ops.rollout_cohorts enable row level security;
alter table dhn_ops.slo_definitions enable row level security;
alter table dhn_ops.rollout_gate_results enable row level security;
revoke all privileges on dhn_ops.rollout_cohorts,dhn_ops.slo_definitions,dhn_ops.rollout_gate_results from public,anon,authenticated;
grant all privileges on dhn_ops.rollout_cohorts,dhn_ops.slo_definitions,dhn_ops.rollout_gate_results to service_role;
create policy rollout_cohorts_service_role on dhn_ops.rollout_cohorts for all to service_role using (true) with check (true);
create policy slo_definitions_service_role on dhn_ops.slo_definitions for all to service_role using (true) with check (true);
create policy rollout_gate_results_service_role on dhn_ops.rollout_gate_results for all to service_role using (true) with check (true);

insert into dhn_ops.rollout_cohorts(cohort_code,cohort_type,status,participant_limit,entry_criteria,exit_criteria)
values('DHN-E13-COHORT-01','internal','planned',25,
 jsonb_build_object('e12_final_go',true,'synthetic_first',true,'phi_in_ops_evidence',false,'biometric_template_in_ops_evidence',false),
 jsonb_build_object('zero_critical_security_incidents',true,'identity_consent_audit_controls_verified',true,'rollout_gates_pass',true))
on conflict (cohort_code) do nothing;

insert into dhn_ops.slo_definitions(slo_code,component,metric_name,target_operator,target_value,measurement_window,severity_on_breach,metadata) values
('E13-SLO-AUTH-AVAIL','heartbeatid','verification_availability_pct','gte',99.9,'rolling_30d','high',jsonb_build_object('synthetic_baseline_required',true)),
('E13-SLO-AUTH-P95','heartbeatid','verification_latency_p95_ms','lte',1500,'rolling_24h','medium',jsonb_build_object('excludes_external_network_outages',true)),
('E13-SLO-TELEM-VALID','rencat','trusted_event_validation_pct','gte',99.0,'rolling_24h','medium',jsonb_build_object('raw_payload_storage',false)),
('E13-SLO-AUDIT','audit','security_sensitive_audit_capture_pct','gte',100,'rolling_24h','critical',jsonb_build_object('privacy_minimized',true)),
('E13-SLO-SETTLE','settlement','duplicate_economic_execution_count','eq',0,'rolling_30d','critical',jsonb_build_object('idempotency_required',true))
on conflict (slo_code) do update set target_operator=excluded.target_operator,target_value=excluded.target_value,measurement_window=excluded.measurement_window,severity_on_breach=excluded.severity_on_breach,metadata=excluded.metadata,status='active';

insert into dhn_ops.rollout_gate_results(rollout_cohort_id,gate_code,domain,expected_outcome)
select c.rollout_cohort_id,v.code,v.domain,v.expected
from dhn_ops.rollout_cohorts c cross join (values
('E13-G01','identity','Every enrolled subject has one active scoped identity mapping and valid credential.'),
('E13-G02','consent','Every protected action is purpose-bound to active consent or a documented lawful authorization path.'),
('E13-G03','heartbeatid','HeartbeatID verification remains within availability/latency SLO and rejects suspended or invalid credentials.'),
('E13-G04','rencat','Telemetry validation/quarantine remains reference-only and excludes raw payloads from operations evidence.'),
('E13-G05','audit','Security-sensitive actions maintain correlated audit and privacy-minimized attestation evidence.'),
('E13-G06','settlement','Settlement and ledger boundaries preserve no-PHI/no-biometric payload rules and external finality.'),
('E13-G07','security','No critical DHN-owned security finding or unauthorized public access is present.'),
('E13-G08','operations','SLO breach and incident escalation controls are operational before cohort expansion.')
) v(code,domain,expected)
where c.cohort_code='DHN-E13-COHORT-01'
on conflict (rollout_cohort_id,gate_code) do nothing;
