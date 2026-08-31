create table if not exists pqc.readiness_assessments (
  id uuid primary key default gen_random_uuid(),
  assessment_code text not null unique,
  scope_type text not null,
  scope_ref text not null,
  assessment_status text not null default 'draft' check (assessment_status in ('draft','in_review','approved','superseded','retired')),
  methodology_version text not null,
  evidence_reference text,
  assessed_by text,
  assessed_at timestamptz,
  approved_by text,
  approved_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists pqc.readiness_scores (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references pqc.readiness_assessments(id) on delete cascade,
  qei numeric(5,2) not null check (qei between 0 and 100),
  pmi numeric(5,2) not null check (pmi between 0 and 100),
  cai numeric(5,2) not null check (cai between 0 and 100),
  lde numeric(5,2) not null check (lde between 0 and 100),
  qir numeric(5,2) not null check (qir between 0 and 100),
  sqrs numeric(5,2) not null check (sqrs between 0 and 100),
  weighting_profile jsonb not null default '{"qei":0.20,"pmi":0.25,"cai":0.20,"lde":0.15,"qir":0.20}'::jsonb,
  calculation_evidence jsonb not null default '{}'::jsonb,
  calculated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (assessment_id, calculated_at)
);

create table if not exists pqc.infrastructure_readiness (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references pqc.readiness_assessments(id) on delete cascade,
  infrastructure_type text not null,
  infrastructure_ref text not null,
  classical_quantum_coexistence_ready boolean,
  optical_path_ready boolean,
  timing_sync_ready boolean,
  trusted_node_model text,
  segmentation_ready boolean,
  telemetry_ready boolean,
  provider_dependency text,
  readiness_score numeric(5,2) check (readiness_score between 0 and 100),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_id, infrastructure_type, infrastructure_ref)
);

create table if not exists pqc.crypto_agility_assessments (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references pqc.readiness_assessments(id) on delete cascade,
  system_ref text not null,
  algorithm_abstraction boolean not null default false,
  key_provider_abstraction boolean not null default false,
  protocol_negotiation boolean not null default false,
  certificate_rotation_automated boolean not null default false,
  configuration_externalized boolean not null default false,
  dependency_pinning_verified boolean not null default false,
  rollback_tested boolean not null default false,
  agility_score numeric(5,2) not null check (agility_score between 0 and 100),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_id, system_ref)
);

create table if not exists pqc.governance_recommendations (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references pqc.readiness_assessments(id) on delete cascade,
  recommendation_code text not null unique,
  recommendation_type text not null,
  priority integer not null check (priority between 0 and 100),
  recommendation_text text not null,
  rationale text not null,
  evidence_reference text,
  requires_human_authorization boolean not null default true,
  governance_gate text,
  decision_status text not null default 'pending' check (decision_status in ('pending','approved','rejected','deferred','superseded')),
  decided_by text,
  decided_at timestamptz,
  decision_reference text,
  execution_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists readiness_assessments_scope_idx on pqc.readiness_assessments(scope_type, scope_ref);
create index if not exists readiness_assessments_status_idx on pqc.readiness_assessments(assessment_status);
create index if not exists readiness_scores_assessment_idx on pqc.readiness_scores(assessment_id);
create index if not exists infrastructure_readiness_assessment_idx on pqc.infrastructure_readiness(assessment_id);
create index if not exists crypto_agility_assessments_assessment_idx on pqc.crypto_agility_assessments(assessment_id);
create index if not exists governance_recommendations_assessment_idx on pqc.governance_recommendations(assessment_id);
create index if not exists governance_recommendations_status_idx on pqc.governance_recommendations(decision_status, priority desc);

alter table pqc.readiness_assessments enable row level security;
alter table pqc.readiness_scores enable row level security;
alter table pqc.infrastructure_readiness enable row level security;
alter table pqc.crypto_agility_assessments enable row level security;
alter table pqc.governance_recommendations enable row level security;

create policy qri_service_role_all_readiness_assessments on pqc.readiness_assessments for all to service_role using (true) with check (true);
create policy qri_service_role_all_readiness_scores on pqc.readiness_scores for all to service_role using (true) with check (true);
create policy qri_service_role_all_infrastructure_readiness on pqc.infrastructure_readiness for all to service_role using (true) with check (true);
create policy qri_service_role_all_crypto_agility on pqc.crypto_agility_assessments for all to service_role using (true) with check (true);
create policy qri_service_role_all_governance_recommendations on pqc.governance_recommendations for all to service_role using (true) with check (true);

grant select, insert, update, delete on pqc.readiness_assessments to service_role;
grant select, insert, update, delete on pqc.readiness_scores to service_role;
grant select, insert, update, delete on pqc.infrastructure_readiness to service_role;
grant select, insert, update, delete on pqc.crypto_agility_assessments to service_role;
grant select, insert, update, delete on pqc.governance_recommendations to service_role;

revoke all on pqc.readiness_assessments from anon, authenticated;
revoke all on pqc.readiness_scores from anon, authenticated;
revoke all on pqc.infrastructure_readiness from anon, authenticated;
revoke all on pqc.crypto_agility_assessments from anon, authenticated;
revoke all on pqc.governance_recommendations from anon, authenticated;