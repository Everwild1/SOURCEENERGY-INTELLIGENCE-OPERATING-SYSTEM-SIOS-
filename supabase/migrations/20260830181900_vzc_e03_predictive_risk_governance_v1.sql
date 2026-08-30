-- VZC-E03 — Safety Intelligence & Predictive Risk governance contract

create table vzc.risk_model_registry (
  risk_model_id uuid primary key default gen_random_uuid(), model_key text not null, model_version text not null,
  model_status text not null default 'candidate' check (model_status in ('candidate','validated','pilot_approved','pilot_active','retired')),
  intended_use text not null,
  prohibited_use text not null default 'May not confer authorization, command physical infrastructure, dispatch resources, or establish legal/clinical fact.',
  feature_contract jsonb not null default '{}'::jsonb, validation_evidence jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), unique (model_key, model_version)
);

create table vzc.risk_assessments (
  risk_assessment_id uuid primary key default gen_random_uuid(), risk_model_id uuid not null references vzc.risk_model_registry(risk_model_id) on delete restrict,
  subject_type text not null, subject_key text not null, spatial_binding_id uuid references vzc.spatial_bindings(binding_id) on delete restrict,
  assessment_window_start timestamptz not null, assessment_window_end timestamptz not null,
  risk_score numeric not null check (risk_score >= 0 and risk_score <= 1), risk_band text not null check (risk_band in ('minimal','low','moderate','high','critical')),
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)), feature_snapshot jsonb not null default '{}'::jsonb,
  explanation jsonb not null default '{}'::jsonb,
  evidence_state text not null default 'evidence_identified' check (evidence_state in ('concept','evidence_identified','validated','integration_designed','prototype','pilot_approved','pilot_active','production_approved')),
  operational_authority boolean not null default false check (operational_authority = false), created_at timestamptz not null default now(),
  check (assessment_window_end >= assessment_window_start)
);

create table vzc.risk_assessment_evidence (
  risk_assessment_id uuid not null references vzc.risk_assessments(risk_assessment_id) on delete cascade,
  observation_id uuid references vzc.observation_registry(observation_id) on delete restrict,
  safety_event_id uuid references vzc.safety_events(safety_event_id) on delete restrict,
  relationship text not null default 'supports' check (relationship in ('supports','corroborates','contradicts','contextualizes','supersedes')),
  created_at timestamptz not null default now(),
  check ((observation_id is not null)::int + (safety_event_id is not null)::int = 1),
  unique nulls not distinct (risk_assessment_id, observation_id, safety_event_id)
);

create table vzc.risk_recommendations (
  recommendation_id uuid primary key default gen_random_uuid(), risk_assessment_id uuid not null references vzc.risk_assessments(risk_assessment_id) on delete restrict,
  recommendation_type text not null, recommendation_text text not null,
  recommendation_state text not null default 'proposed' check (recommendation_state in ('proposed','human_review_required','accepted_for_planning','rejected','expired')),
  human_review_required boolean not null default true check (human_review_required = true), authority_reference text, execution_reference text,
  created_at timestamptz not null default now(), reviewed_at timestamptz,
  check (execution_reference is null), check (recommendation_state <> 'accepted_for_planning' or authority_reference is not null)
);

create index vzc_risk_assessments_subject_time_idx on vzc.risk_assessments(subject_type, subject_key, assessment_window_end desc);
create index vzc_risk_assessments_spatial_idx on vzc.risk_assessments(spatial_binding_id) where spatial_binding_id is not null;
create index vzc_risk_assessments_model_idx on vzc.risk_assessments(risk_model_id, created_at desc);
create index vzc_risk_evidence_observation_idx on vzc.risk_assessment_evidence(observation_id) where observation_id is not null;
create index vzc_risk_evidence_event_idx on vzc.risk_assessment_evidence(safety_event_id) where safety_event_id is not null;
create index vzc_risk_recommendations_assessment_idx on vzc.risk_recommendations(risk_assessment_id, created_at desc);

alter table vzc.risk_model_registry enable row level security;
alter table vzc.risk_assessments enable row level security;
alter table vzc.risk_assessment_evidence enable row level security;
alter table vzc.risk_recommendations enable row level security;
create policy vzc_risk_model_registry_service_role_all on vzc.risk_model_registry for all to service_role using (true) with check (true);
create policy vzc_risk_assessments_service_role_all on vzc.risk_assessments for all to service_role using (true) with check (true);
create policy vzc_risk_assessment_evidence_service_role_all on vzc.risk_assessment_evidence for all to service_role using (true) with check (true);
create policy vzc_risk_recommendations_service_role_all on vzc.risk_recommendations for all to service_role using (true) with check (true);
grant select, insert, update, delete on vzc.risk_model_registry, vzc.risk_assessments, vzc.risk_assessment_evidence, vzc.risk_recommendations to service_role;

comment on table vzc.risk_model_registry is 'Governed VZC predictive-risk model/version registry. Registration or validation does not confer operational authority.';
comment on table vzc.risk_assessments is 'Explainable VZC predictive/derived risk output. Database invariant prohibits operational authority on an assessment.';
comment on table vzc.risk_recommendations is 'Human-review planning recommendations derived from risk assessments. Recommendations cannot record execution and accepted planning requires explicit authority evidence.';
