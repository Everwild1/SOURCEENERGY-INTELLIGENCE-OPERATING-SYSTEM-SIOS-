create table if not exists pqc.vendor_registry (
  id uuid primary key default gen_random_uuid(),
  vendor_name text not null,
  service_name text,
  service_category text not null,
  current_crypto_profile jsonb not null default '{}'::jsonb,
  pqc_support_status text not null default 'unknown' check (pqc_support_status in ('unknown','not_planned','planned','pilot','partial','production')),
  supports_ml_kem boolean,
  supports_ml_dsa boolean,
  supports_slh_dsa boolean,
  supports_hybrid boolean,
  hsm_pqc_support boolean,
  attestation_reference text,
  evidence_date date,
  review_due date,
  owner_role text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(vendor_name, service_name)
);

create table if not exists pqc.verification_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  subject_type text not null,
  subject_ref text not null,
  algorithm_code text references pqc.algorithm_registry(algorithm_code),
  policy_code text,
  verification_status text not null check (verification_status in ('pending','passed','failed','exception')),
  verification_engine text,
  verifier_identity text,
  evidence_reference text,
  correlation_id text not null,
  result_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists pqc_verification_events_subject_idx on pqc.verification_events(subject_type, subject_ref, occurred_at desc);
create index if not exists pqc_verification_events_status_idx on pqc.verification_events(verification_status, occurred_at desc);

alter table pqc.vendor_registry enable row level security;
alter table pqc.verification_events enable row level security;
revoke all on pqc.vendor_registry, pqc.verification_events from anon, authenticated;
grant select, insert, update, delete on pqc.vendor_registry, pqc.verification_events to service_role;

create policy vendor_registry_service_only on pqc.vendor_registry for all to service_role using (true) with check (true);
create policy verification_events_service_only on pqc.verification_events for all to service_role using (true) with check (true);

insert into pqc.crypto_assets(system_name, system_component, environment, asset_type, protocol, algorithm_family, algorithm_name, owner_role, data_classification, confidentiality_years, quantum_vulnerable, harvest_now_decrypt_later_risk, migration_priority, discovery_method, metadata, last_verified_at)
values
('SourceEnergy-command-backend','Supabase legacy anon API key','production','api_credential','JWT','HMAC','HS256','Platform Security','internal',5,false,'low',55,'Supabase API key inspection',jsonb_build_object('key_type','legacy_anon','migration_required_by','2026-12-31','secret_material_stored',false),now()),
('SourceEnergy-command-backend','Supabase publishable API key','production','api_credential','apikey','opaque_rotatable','publishable','Platform Security','internal',5,false,'none',10,'Supabase API key inspection',jsonb_build_object('key_type','publishable','recommended',true,'secret_material_stored',false),now()),
('SourceEnergy-command-backend','Supabase Auth access tokens','production','identity_token','JWT','JWT-signing','project_signing_key','Identity Security','confidential',10,null,'medium',70,'Supabase platform inspection',jsonb_build_object('requires_signing_key_inventory',true,'secret_material_stored',false),now())
on conflict (system_name, system_component, environment, asset_type) do nothing;

insert into pqc.migration_register(component, system_owner, current_algorithm, current_protocol, quantum_risk, data_lifetime_years, vendor_dependency, replacement_algorithm, migration_stage, target_date, verification_status, approval_reference)
values
('Supabase legacy anon API key','Platform Security','HS256','JWT','low',5,'Supabase','Publishable API key','planned','2026-12-31','pending','PQC discovery sweep 2026-08-25'),
('Supabase Auth token signing','Identity Security','Project signing key','JWT','unknown',10,'Supabase','Rotatable signing-key architecture / future PQC-capable identity stack','classified',null,'pending','PQC discovery sweep 2026-08-25')
on conflict (component, current_algorithm, current_protocol) do nothing;