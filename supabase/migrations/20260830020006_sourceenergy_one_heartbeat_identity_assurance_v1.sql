create table sourceenergy_one.heartbeat_enrollment_refs (
  id uuid primary key default gen_random_uuid(),
  subject_id text not null,
  heartbeat_system_ref text not null,
  modality text not null default 'cardiac' check (modality in ('cardiac','cardiac_multimodal')),
  enrollment_status text not null default 'active' check (enrollment_status in ('active','suspended','revoked','superseded')),
  consent_receipt_id text,
  algorithm_version text,
  credential_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(subject_id, heartbeat_system_ref)
);

create table sourceenergy_one.heartbeat_verification_assertions (
  id uuid primary key default gen_random_uuid(),
  subject_id text not null,
  enrollment_ref_id uuid references sourceenergy_one.heartbeat_enrollment_refs(id) on delete restrict,
  challenge_id uuid not null default gen_random_uuid(),
  verification_status text not null check (verification_status in ('verified','failed','indeterminate')),
  liveness_status text not null default 'not_evaluated' check (liveness_status in ('passed','failed','not_evaluated','indeterminate')),
  assurance_level text not null check (assurance_level in ('standard','elevated','institutional')),
  sensor_attestation_ref text,
  algorithm_version text,
  policy_version text,
  consent_receipt_id text,
  assertion_digest text not null,
  evidence_refs jsonb not null default '[]'::jsonb,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  unique(assertion_digest)
);

alter table sourceenergy_one.access_contexts add column if not exists heartbeat_assertion_id uuid references sourceenergy_one.heartbeat_verification_assertions(id) on delete set null;
alter table sourceenergy_one.access_contexts add column if not exists authentication_factors jsonb not null default '[]'::jsonb;

create index on sourceenergy_one.heartbeat_enrollment_refs(subject_id, enrollment_status);
create index on sourceenergy_one.heartbeat_verification_assertions(subject_id, issued_at desc);
create index on sourceenergy_one.heartbeat_verification_assertions(challenge_id);

alter table sourceenergy_one.heartbeat_enrollment_refs enable row level security;
alter table sourceenergy_one.heartbeat_verification_assertions enable row level security;
revoke all on sourceenergy_one.heartbeat_enrollment_refs, sourceenergy_one.heartbeat_verification_assertions from public, anon, authenticated;
grant all on sourceenergy_one.heartbeat_enrollment_refs, sourceenergy_one.heartbeat_verification_assertions to service_role;
create policy heartbeat_enrollment_refs_service_role_all on sourceenergy_one.heartbeat_enrollment_refs for all to service_role using (true) with check (true);
create policy heartbeat_verification_assertions_service_role_all on sourceenergy_one.heartbeat_verification_assertions for all to service_role using (true) with check (true);

insert into sourceenergy_one.domain_adapter_registry(adapter_key,domain,authority,mode,consequence_ceiling,enabled,metadata)
values ('heartbeat-id','human_identity','SETC-HB-001 / DHN HeartBeatID','read','consequential',false,
'{"purpose":"Consume bounded HeartBeatID verification assertions for identity assurance and step-up authorization","raw_biometric_data_prohibited":true,"health_inference_prohibited":true,"licensing_gate_required":true}'::jsonb)
on conflict (adapter_key) do update set metadata=excluded.metadata, authority=excluded.authority, updated_at=now();

comment on table sourceenergy_one.heartbeat_enrollment_refs is 'Opaque references to HeartBeatID enrollment only. No raw ECG, reusable biometric templates, or diagnostic data may be stored here.';
comment on table sourceenergy_one.heartbeat_verification_assertions is 'Bounded HeartBeatID verification assertions for identity/liveness assurance. No raw physiological signal or reusable biometric template.';
comment on column sourceenergy_one.access_contexts.heartbeat_assertion_id is 'Optional verified HeartBeatID assertion used as an authentication/step-up factor; does not establish purpose, health status, or authority by itself.';
