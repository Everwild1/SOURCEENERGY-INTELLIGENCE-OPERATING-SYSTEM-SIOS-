create table vzc.research_project_bindings (
  research_binding_id uuid primary key default gen_random_uuid(), organization_binding_id uuid references vzc.organization_bindings(binding_id) on delete restrict,
  source_schema text not null, source_table text not null, source_record_key text not null,
  research_role text not null check (research_role in ('lead','participant','validator','data_provider','technology_provider','sponsor','other')),
  relationship_state text not null default 'identified' check (relationship_state in ('identified','contacted','discussion','research_interest_evidenced','scope_defined','agreement_or_approval_verified','research_active','findings_submitted','findings_validated','closed_or_extended')),
  evidence_reference text, agreement_or_approval_reference text, provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (relationship_state not in ('agreement_or_approval_verified','research_active','findings_submitted','findings_validated','closed_or_extended') or agreement_or_approval_reference is not null),
  unique(source_schema, source_table, source_record_key, research_role)
);
create table vzc.technology_candidate_bindings (
  technology_candidate_binding_id uuid primary key default gen_random_uuid(), source_schema text not null, source_table text not null, source_record_key text not null,
  technology_reference text, candidate_source text not null check (candidate_source in ('sourceenergy_registry','nasa_registry','university','government','vendor','publication','other')),
  candidate_state text not null default 'discovery' check (candidate_state in ('discovery','evidence_review','rights_review','technical_assessment','integration_design','sandbox_validation','bounded_prototype','pilot_candidate','pilot_approved','pilot_evaluation','scale_or_commercial_decision','closed')),
  evidence_reference text not null, rights_status text not null default 'unverified' check (rights_status in ('unverified','review_required','verified_for_evaluation','licensed_or_authorized','restricted','rejected','expired')),
  rights_reference text, ownership_claimed_by_vzc boolean not null default false check (ownership_claimed_by_vzc = false), deployment_authority boolean not null default false check (deployment_authority = false),
  provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (rights_status not in ('verified_for_evaluation','licensed_or_authorized') or rights_reference is not null), unique(source_schema, source_table, source_record_key)
);
create table vzc.research_validation_records (
  validation_record_id uuid primary key default gen_random_uuid(), research_binding_id uuid references vzc.research_project_bindings(research_binding_id) on delete restrict,
  technology_candidate_binding_id uuid references vzc.technology_candidate_bindings(technology_candidate_binding_id) on delete restrict,
  validation_stage text not null check (validation_stage in ('evidence_review','rights_review','technical_assessment','laboratory_or_sandbox','bounded_prototype','pilot_evaluation','findings_review')),
  validation_state text not null default 'planned' check (validation_state in ('planned','active','passed','failed','inconclusive','superseded','closed')),
  method_reference text not null, evidence_reference text, reproducibility_reference text, negative_or_null_result boolean not null default false, reviewer_authority_ref text, completed_at timestamptz,
  findings jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(),
  check (research_binding_id is not null or technology_candidate_binding_id is not null),
  check (validation_state not in ('passed','failed','inconclusive') or (evidence_reference is not null and reviewer_authority_ref is not null and completed_at is not null))
);
create table vzc.research_data_access_controls (
  research_data_access_control_id uuid primary key default gen_random_uuid(), research_binding_id uuid not null references vzc.research_project_bindings(research_binding_id) on delete restrict,
  data_domain text not null check (data_domain in ('mobility_safety','spatial','infrastructure','health','biometric','person_level','commercial','critical_infrastructure','other')),
  purpose_reference text not null, lawful_basis_or_authority_ref text, ethics_or_irb_reference text, consent_reference text,
  access_state text not null default 'proposed' check (access_state in ('proposed','approved','active','expired','revoked','closed')),
  production_access boolean not null default false check (production_access = false), valid_from timestamptz, valid_until timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (access_state not in ('approved','active') or lawful_basis_or_authority_ref is not null),
  check (data_domain not in ('health','biometric','person_level') or access_state not in ('approved','active') or ethics_or_irb_reference is not null or consent_reference is not null),
  check (valid_until is null or valid_from is null or valid_until > valid_from)
);
create table vzc.research_findings_return (
  findings_return_id uuid primary key default gen_random_uuid(), research_binding_id uuid references vzc.research_project_bindings(research_binding_id) on delete restrict,
  validation_record_id uuid not null references vzc.research_validation_records(validation_record_id) on delete restrict,
  sourcecube_domain text not null default 'mobility_safety', knowledge_state text not null default 'candidate' check (knowledge_state in ('candidate','validated','contradictory','negative_result','superseded','published_to_sourcecube')),
  evidence_reference text not null, rights_reference text, sensitivity_class text not null default 'internal' check (sensitivity_class in ('public','internal','restricted','sensitive')), sourcecube_reference text,
  created_at timestamptz not null default now(), check (knowledge_state <> 'published_to_sourcecube' or sourcecube_reference is not null)
);
create index vzc_research_project_org_idx on vzc.research_project_bindings(organization_binding_id, relationship_state);
create index vzc_technology_candidate_state_idx on vzc.technology_candidate_bindings(candidate_source, candidate_state, rights_status);
create index vzc_research_validation_research_idx on vzc.research_validation_records(research_binding_id, validation_state);
create index vzc_research_validation_technology_idx on vzc.research_validation_records(technology_candidate_binding_id, validation_state);
create index vzc_research_access_binding_idx on vzc.research_data_access_controls(research_binding_id, data_domain, access_state);
create index vzc_research_findings_validation_idx on vzc.research_findings_return(validation_record_id, knowledge_state);
alter table vzc.research_project_bindings enable row level security; alter table vzc.technology_candidate_bindings enable row level security; alter table vzc.research_validation_records enable row level security; alter table vzc.research_data_access_controls enable row level security; alter table vzc.research_findings_return enable row level security;
revoke all on table vzc.research_project_bindings, vzc.technology_candidate_bindings, vzc.research_validation_records, vzc.research_data_access_controls, vzc.research_findings_return from anon, authenticated;
grant select, insert, update, delete on vzc.research_project_bindings, vzc.technology_candidate_bindings, vzc.research_validation_records, vzc.research_data_access_controls, vzc.research_findings_return to service_role;
create policy vzc_research_project_service_role_all on vzc.research_project_bindings for all to service_role using (true) with check (true); create policy vzc_technology_candidate_service_role_all on vzc.technology_candidate_bindings for all to service_role using (true) with check (true); create policy vzc_research_validation_service_role_all on vzc.research_validation_records for all to service_role using (true) with check (true); create policy vzc_research_access_service_role_all on vzc.research_data_access_controls for all to service_role using (true) with check (true); create policy vzc_research_findings_service_role_all on vzc.research_findings_return for all to service_role using (true) with check (true);
comment on table vzc.research_project_bindings is 'VZC research participation projection over authoritative SourceCube/HEI organization and research records. Listing an institution does not establish partnership or active research.';
comment on table vzc.technology_candidate_bindings is 'Candidate technology discovery and validation binding. NASA or other registry presence does not establish VZC ownership, licensing, commercialization rights, deployment authorization or production status.';
comment on table vzc.research_validation_records is 'Governed validation record preserving passed, failed, inconclusive, negative and contradictory research outcomes.';
comment on table vzc.research_data_access_controls is 'Purpose-limited research data access evidence. Research access never confers production access; sensitive human data requires additional ethics, consent or applicable authority evidence.';
comment on table vzc.research_findings_return is 'Governed return of validated, negative or contradictory VZC research knowledge to SourceCube/SIOS with provenance, rights and sensitivity controls.';