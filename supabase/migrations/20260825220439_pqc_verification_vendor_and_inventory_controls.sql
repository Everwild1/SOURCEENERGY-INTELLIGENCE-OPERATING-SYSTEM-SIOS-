create table if not exists pqc.verification_events (
  id uuid primary key default gen_random_uuid(),
  verification_type text not null,
  subject_type text not null,
  subject_id text not null,
  expected_state jsonb not null default '{}'::jsonb,
  observed_state jsonb not null default '{}'::jsonb,
  result text not null check (result in ('passed','failed','warning','pending','exception')),
  verifier text not null,
  evidence_reference text,
  verified_at timestamptz not null default now(),
  expires_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists verification_events_subject_idx on pqc.verification_events (subject_type, subject_id, verified_at desc);
create index if not exists verification_events_result_idx on pqc.verification_events (result, verified_at desc);

create table if not exists pqc.vendor_registry (
  id uuid primary key default gen_random_uuid(),
  vendor_name text not null,
  product_name text not null,
  product_category text not null,
  current_crypto_profile jsonb not null default '{}'::jsonb,
  pqc_support_status text not null default 'unknown' check (pqc_support_status in ('unknown','roadmap','hybrid_supported','pqc_supported','not_supported','exception')),
  supported_algorithms text[] not null default '{}'::text[],
  roadmap_date date,
  source_reference text,
  verification_status text not null default 'unverified' check (verification_status in ('unverified','pending','verified','rejected','expired')),
  last_verified_at timestamptz,
  owner_role text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(vendor_name, product_name)
);
create index if not exists vendor_registry_status_idx on pqc.vendor_registry (pqc_support_status, verification_status);

alter table pqc.verification_events enable row level security;
alter table pqc.vendor_registry enable row level security;
revoke all on pqc.verification_events, pqc.vendor_registry from anon, authenticated;
grant select, insert, update, delete on pqc.verification_events, pqc.vendor_registry to service_role;
create policy service_role_all on pqc.verification_events for all to service_role using (true) with check (true);
create policy service_role_all on pqc.vendor_registry for all to service_role using (true) with check (true);

insert into pqc.crypto_assets (system_name, system_component, environment, asset_type, protocol, algorithm_family, algorithm_name, owner_role, data_classification, confidentiality_years, quantum_vulnerable, harvest_now_decrypt_later_risk, migration_priority, discovery_method, metadata, last_verified_at)
values
 ('SourceEnergy Supabase','Project API authentication','production','api_auth','HTTPS/JWT','asymmetric','Legacy Supabase JWT / API key model','Platform Engineering','restricted',10,true,'medium',85,'Supabase Management API',jsonb_build_object('project_ref','veopccdltsklczlmdbri','evidence','Management API project settings'),'2026-08-25T00:00:00Z'),
 ('SourceEnergy Supabase','Database TLS endpoint','production','transport','TLS','public_key','Provider-managed TLS certificate','Platform Engineering','restricted',10,true,'medium',80,'Supabase project endpoint verification',jsonb_build_object('provider','Supabase'),'2026-08-25T00:00:00Z'),
 ('SourceEnergy SIOS GitHub','Repository signing and Actions trust boundary','production','code_supply_chain','GitHub HTTPS / Actions','provider_managed','Provider-managed signing and identity controls','Platform Engineering','confidential',25,null,'high',90,'GitHub repository review',jsonb_build_object('repository','Everwild1/SOURCEENERGY-INTELLIGENCE-OPERATING-SYSTEM-SIOS-','classification','verification-required'),'2026-08-25T00:00:00Z')
on conflict (system_name, system_component, environment, asset_type) do update set metadata=excluded.metadata, last_verified_at=excluded.last_verified_at, updated_at=now();

insert into pqc.migration_register (component, system_owner, current_algorithm, current_protocol, quantum_risk, data_lifetime_years, vendor_dependency, replacement_algorithm, migration_stage, verification_status, approval_reference)
values
 ('Supabase API authentication','Platform Engineering','Legacy JWT signing / legacy API keys','HTTPS/JWT','high',10,'Supabase','Asymmetric signing keys plus publishable/secret API keys; PQC overlay when provider support is verified','classified','pending','Supabase Management API evidence 2026-08-25'),
 ('SIOS durable evidence signatures','Knowledge Governance','Classical provider-managed signing','GitHub / application signatures','critical',50,'GitHub + application crypto provider','ML-DSA primary; SLH-DSA alternative; hybrid during transition','planned','pending','PQ-CGL Phase II')
on conflict (component, current_algorithm, current_protocol) do update set migration_stage=excluded.migration_stage, verification_status=excluded.verification_status, updated_at=now();

insert into pqc.verification_events (verification_type, subject_type, subject_id, expected_state, observed_state, result, verifier, evidence_reference, notes)
values
 ('supabase_key_inventory','platform','supabase:veopccdltsklczlmdbri',jsonb_build_object('legacy_keys','discoverable'),jsonb_build_object('legacy_keys',true,'modern_key_families','not_yet_verified'),'passed','OpenAI Supabase connector','Supabase Management API','Legacy key state evidenced; migration target requires staged verification.'),
 ('github_repo_inventory','repository','github:Everwild1/SOURCEENERGY-INTELLIGENCE-OPERATING-SYSTEM-SIOS-',jsonb_build_object('repository','reachable'),jsonb_build_object('repository','reachable','crypto_implementation','not_claimed'),'passed','OpenAI GitHub connector','GitHub repository metadata','Repository boundary verified; PQC implementation remains governed migration work.'),
 ('pqc_schema_contract','database','supabase:pqc',jsonb_build_object('private_key_storage',false),jsonb_build_object('private_key_storage',false),'passed','SourceEnergy PQ-CGL','Database schema inspection','Database stores provider references and fingerprints only, not private key material.');