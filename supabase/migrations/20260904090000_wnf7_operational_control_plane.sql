create schema if not exists wnf7;
comment on schema wnf7 is 'Private WNF-7 governance and meaning control plane. Service-role-only, evidence-backed, and non-transactional.';

create table wnf7.dimension_registry (
  dimension_code text primary key,
  ordinal smallint not null unique check (ordinal between 1 and 7),
  display_name text not null unique,
  control_intent text not null
);
create table wnf7.component_profiles (
  profile_code text primary key,
  component_code text not null check (component_code in ('SETC','SOURCECUBE','CODEX_VERITAS','SOURCEONE','SIOS','SIDEKICK_OEL','SOURCECOIN','SOURCEBLOCK')),
  version_label text not null,
  lifecycle_state text not null check (lifecycle_state in ('DRAFT','PILOT','REVIEW','AUTHORIZED','RETIRED')),
  operational_scope text not null,
  execution_boundary text not null,
  production_authorized boolean not null default false,
  canonical_source_ref text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(profile_code,component_code),
  check (not production_authorized or lifecycle_state='AUTHORIZED')
);
create table wnf7.component_dimension_controls (
  profile_code text not null references wnf7.component_profiles(profile_code),
  dimension_code text not null references wnf7.dimension_registry(dimension_code),
  control_summary text not null,
  required boolean not null default true,
  primary key(profile_code,dimension_code)
);
create table wnf7.reviewer_roles (
  role_code text primary key,
  display_name text not null unique,
  control_scope text not null,
  required boolean not null default true
);
create table wnf7.pilot_scenarios (
  scenario_code text primary key,
  pilot_code text not null,
  dimension_codes text[] not null check(cardinality(dimension_codes) between 1 and 7),
  expected_automated_state text not null check(expected_automated_state in ('PASS','REVIEW','BLOCKED')),
  decision_eligibility text not null check(decision_eligibility in ('ELIGIBLE_FOR_HUMAN_DECISION','SIMULATION_ONLY','NOT_ELIGIBLE')),
  reviewer_role_code text not null references wnf7.reviewer_roles(role_code),
  required_evidence text not null,
  active boolean not null default true
);
create table wnf7.reviewer_assignments (
  assignment_id uuid primary key default gen_random_uuid(),
  pilot_code text not null,
  reviewer_role_code text not null references wnf7.reviewer_roles(role_code),
  reviewer_subject_id uuid,
  reviewer_display_ref text,
  appointment_evidence_ref text,
  conflict_status text not null default 'PENDING' check(conflict_status in ('PENDING','NO_CONFLICT_DECLARED','CONFLICT_DECLARED','RECUSED')),
  mobilization_status text not null default 'UNASSIGNED' check(mobilization_status in ('UNASSIGNED','NOMINATED','ASSIGNED','ACCEPTED','HOLD')),
  accepted_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(pilot_code,reviewer_role_code),
  check(mobilization_status<>'ACCEPTED' or (reviewer_subject_id is not null and appointment_evidence_ref is not null and conflict_status='NO_CONFLICT_DECLARED' and accepted_at is not null))
);
create table wnf7.evidence_items (
  evidence_id uuid primary key default gen_random_uuid(),
  scenario_code text not null references wnf7.pilot_scenarios(scenario_code),
  evidence_ref text not null,
  source_system text not null,
  content_sha256 text check(content_sha256 is null or content_sha256 ~ '^[0-9a-f]{64}$'),
  freshness_status text not null default 'PENDING' check(freshness_status in ('PENDING','CURRENT','STALE','EXPIRED','NOT_APPLICABLE')),
  validation_status text not null default 'PENDING' check(validation_status in ('PENDING','VALIDATED','GAP','CONTRADICTORY','REJECTED')),
  observed_at timestamptz,
  validated_at timestamptz,
  validated_by uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check(validation_status<>'VALIDATED' or (freshness_status in ('CURRENT','NOT_APPLICABLE') and validated_at is not null and validated_by is not null))
);
create table wnf7.adjudication_decisions (
  decision_id uuid primary key default gen_random_uuid(),
  scenario_code text not null references wnf7.pilot_scenarios(scenario_code),
  reviewer_subject_id uuid not null,
  reviewer_role_code text not null references wnf7.reviewer_roles(role_code),
  disposition text not null check(disposition in ('CONFIRM','OVERRIDE','HOLD')),
  decision_status text not null check(decision_status in ('IN_REVIEW','COMPLETE','HOLD','REMEDIATION_REQUIRED')),
  rationale_summary text not null,
  attestation_ref text,
  supersedes_decision_id uuid references wnf7.adjudication_decisions(decision_id),
  decided_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check(decision_status<>'COMPLETE' or attestation_ref is not null)
);
create table wnf7.release_gates (
  pilot_code text primary key,
  gate_code text not null,
  gate_state text not null check(gate_state in ('HOLD','READY_FOR_AUTHORITY_REVIEW','AUTHORIZED','REJECTED')),
  production_authorized boolean not null default false,
  authority_attestation_ref text,
  canonical_register_ref text not null,
  github_commit_ref text,
  supabase_validation_ref text,
  updated_at timestamptz not null default now(),
  check(not production_authorized or (gate_state='AUTHORIZED' and authority_attestation_ref is not null))
);

create function wnf7.prevent_record_mutation() returns trigger language plpgsql set search_path='' as $$
begin
  raise exception '% is append-only; create a superseding governed record',tg_table_name;
end;
$$;

create function wnf7.valid_dimension_results(p_results jsonb) returns boolean
language sql immutable strict set search_path='' as $$
  select
    jsonb_typeof(p_results)='array'
    and jsonb_array_length(p_results)=7
    and coalesce((
      select count(*)=7
        and count(distinct item->>'dimension')=7
        and bool_and(jsonb_typeof(item)='object')
        and bool_and(coalesce(item->>'dimension'=any(array['FEAR','PRESENCE','WISDOM','KNOWLEDGE','UNDERSTANDING','COUNSEL','MIGHT_POWER']),false))
        and bool_and(coalesce(item->>'status'=any(array['PASS','REVIEW','BLOCKED','NOT_APPLICABLE']),false))
        and bool_and(coalesce(length(btrim(item->>'finding'))>0,false))
        and bool_and(coalesce(length(btrim(item->>'owner_role'))>0,false))
        and bool_and(coalesce(jsonb_typeof(item->'evidence_refs')='array' and jsonb_array_length(item->'evidence_refs')>0,false))
        and bool_and(coalesce(jsonb_typeof(item->'control_refs')='array' and jsonb_array_length(item->'control_refs')>0,false))
        and bool_and(coalesce(
          item->>'status'<>'NOT_APPLICABLE'
          or (
            length(btrim(item->>'not_applicable_reason'))>0
            and length(btrim(item->>'approving_authority_ref'))>0
          )
        ,false))
      from jsonb_array_elements(p_results) item
    ),false);
$$;

create function wnf7.derive_automated_state(p_results jsonb) returns text
language sql immutable strict set search_path='' as $$
  select case
    when not wnf7.valid_dimension_results(p_results) then 'BLOCKED'
    when exists(
      select 1 from jsonb_array_elements(p_results) item
      where item->>'status'='BLOCKED'
         or (item->>'dimension'='FEAR' and item->>'status'<>'PASS')
    ) then 'BLOCKED'
    when exists(
      select 1 from jsonb_array_elements(p_results) item
      where item->>'status' in ('REVIEW','NOT_APPLICABLE')
    ) then 'REVIEW'
    else 'PASS'
  end;
$$;

create function wnf7.derive_decision_eligibility(p_results jsonb) returns text
language sql immutable strict set search_path='' as $$
  select case wnf7.derive_automated_state(p_results)
    when 'PASS' then 'ELIGIBLE_FOR_HUMAN_DECISION'
    when 'REVIEW' then 'SIMULATION_ONLY'
    else 'NOT_ELIGIBLE'
  end;
$$;

create table wnf7.assessment_records (
  assessment_id text primary key check(assessment_id ~ '^WNF7-[A-Z0-9][A-Z0-9_-]+$'),
  pilot_code text not null default 'PILOT-7D-001',
  component_code text not null,
  profile_code text not null,
  subject_ref text not null,
  correlation_id text not null,
  idempotency_key text not null,
  consequence_class text not null check(consequence_class in ('INFORMATIONAL','ADVISORY','OPERATIONAL','CONSEQUENTIAL')),
  observed_at timestamptz not null,
  authority_ref text,
  operational_reason text not null,
  interpretive_meaning text,
  dimension_results jsonb not null check(wnf7.valid_dimension_results(dimension_results)),
  automated_state text generated always as (wnf7.derive_automated_state(dimension_results)) stored,
  decision_eligibility text generated always as (wnf7.derive_decision_eligibility(dimension_results)) stored,
  human_review_required boolean not null default true check(human_review_required),
  execution_command jsonb check(execution_command is null),
  input_sha256 text not null check(input_sha256 ~ '^[0-9a-f]{64}$'),
  output_sha256 text not null check(output_sha256 ~ '^[0-9a-f]{64}$'),
  evaluator_version text not null,
  supersedes_assessment_id text references wnf7.assessment_records(assessment_id),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(component_code,idempotency_key),
  foreign key(profile_code,component_code) references wnf7.component_profiles(profile_code,component_code),
  constraint assessment_records_required_text_check check(
    length(btrim(pilot_code))>0
    and length(btrim(subject_ref))>0
    and length(btrim(correlation_id))>0
    and length(btrim(idempotency_key))>0
    and length(btrim(operational_reason))>0
    and length(btrim(evaluator_version))>0
  ),
  constraint assessment_records_optional_text_check check(
    (authority_ref is null or length(btrim(authority_ref))>0)
    and (interpretive_meaning is null or length(btrim(interpretive_meaning))>0)
  ),
  constraint assessment_records_metadata_object_check check(jsonb_typeof(metadata)='object'),
  check(
    authority_ref is not null
    or not jsonb_path_exists(dimension_results,'$[*] ? (@.dimension == "FEAR" && @.status == "PASS")')
  )
);

create index assessment_records_component_observed_idx
  on wnf7.assessment_records(component_code,observed_at desc);
create index assessment_records_correlation_idx
  on wnf7.assessment_records(correlation_id);
create index assessment_records_posture_idx
  on wnf7.assessment_records(automated_state,observed_at desc);
create index component_dimension_controls_dimension_idx
  on wnf7.component_dimension_controls(dimension_code);
create index pilot_scenarios_reviewer_role_idx
  on wnf7.pilot_scenarios(reviewer_role_code);
create index reviewer_assignments_reviewer_role_idx
  on wnf7.reviewer_assignments(reviewer_role_code);
create index evidence_items_scenario_idx
  on wnf7.evidence_items(scenario_code);
create index adjudication_decisions_scenario_idx
  on wnf7.adjudication_decisions(scenario_code);
create index adjudication_decisions_reviewer_role_idx
  on wnf7.adjudication_decisions(reviewer_role_code);
create index adjudication_decisions_supersedes_idx
  on wnf7.adjudication_decisions(supersedes_decision_id)
  where supersedes_decision_id is not null;
create index assessment_records_profile_component_idx
  on wnf7.assessment_records(profile_code,component_code);
create index assessment_records_supersedes_idx
  on wnf7.assessment_records(supersedes_assessment_id)
  where supersedes_assessment_id is not null;

create trigger evidence_append_only before update or delete on wnf7.evidence_items for each row execute function wnf7.prevent_record_mutation();
create trigger decisions_append_only before update or delete on wnf7.adjudication_decisions for each row execute function wnf7.prevent_record_mutation();
create trigger assessments_append_only before update or delete on wnf7.assessment_records for each row execute function wnf7.prevent_record_mutation();

alter table wnf7.dimension_registry enable row level security;
alter table wnf7.component_profiles enable row level security;
alter table wnf7.component_dimension_controls enable row level security;
alter table wnf7.reviewer_roles enable row level security;
alter table wnf7.pilot_scenarios enable row level security;
alter table wnf7.reviewer_assignments enable row level security;
alter table wnf7.evidence_items enable row level security;
alter table wnf7.adjudication_decisions enable row level security;
alter table wnf7.release_gates enable row level security;
alter table wnf7.assessment_records enable row level security;

revoke all on schema wnf7 from public,anon,authenticated;
revoke all on all tables in schema wnf7 from public,anon,authenticated;
revoke all on all sequences in schema wnf7 from public,anon,authenticated;
revoke execute on function wnf7.prevent_record_mutation() from public,anon,authenticated;
revoke execute on function wnf7.valid_dimension_results(jsonb) from public,anon,authenticated;
revoke execute on function wnf7.derive_automated_state(jsonb) from public,anon,authenticated;
revoke execute on function wnf7.derive_decision_eligibility(jsonb) from public,anon,authenticated;
grant usage on schema wnf7 to service_role;
grant select,insert,update,delete on all tables in schema wnf7 to service_role;
grant usage,select on all sequences in schema wnf7 to service_role;
grant execute on function wnf7.prevent_record_mutation() to service_role;
grant execute on function wnf7.valid_dimension_results(jsonb) to service_role;
grant execute on function wnf7.derive_automated_state(jsonb) to service_role;
grant execute on function wnf7.derive_decision_eligibility(jsonb) to service_role;

create policy dimensions_service on wnf7.dimension_registry for all to service_role using(true) with check(true);
create policy profiles_service on wnf7.component_profiles for all to service_role using(true) with check(true);
create policy controls_service on wnf7.component_dimension_controls for all to service_role using(true) with check(true);
create policy roles_service on wnf7.reviewer_roles for all to service_role using(true) with check(true);
create policy scenarios_service on wnf7.pilot_scenarios for all to service_role using(true) with check(true);
create policy assignments_service on wnf7.reviewer_assignments for all to service_role using(true) with check(true);
create policy evidence_service on wnf7.evidence_items for all to service_role using(true) with check(true);
create policy decisions_service on wnf7.adjudication_decisions for all to service_role using(true) with check(true);
create policy gates_service on wnf7.release_gates for all to service_role using(true) with check(true);
create policy assessments_service on wnf7.assessment_records for all to service_role using(true) with check(true);

insert into wnf7.dimension_registry values
('FEAR',1,'Fear of the Lord','Authority, legitimacy, limits, and fail-closed behavior'),
('PRESENCE',2,'Presence of the Lord','Identity, existence, provenance, and contextual integrity'),
('WISDOM',3,'Wisdom','Purpose alignment, long-horizon value, and stewardship'),
('KNOWLEDGE',4,'Knowledge','Evidence quality, freshness, classification, and traceability'),
('UNDERSTANDING',5,'Understanding','Context, jurisdiction, affected parties, and consequence analysis'),
('COUNSEL',6,'Counsel','Review, approval, exception, and escalation pathways'),
('MIGHT_POWER',7,'Might / Power','Bounded capability, confirmation, idempotency, and execution control');

insert into wnf7.component_profiles(profile_code,component_code,version_label,lifecycle_state,operational_scope,execution_boundary,canonical_source_ref,metadata) values
('SETC-PROFILE-7D-001','SETC','1.0','PILOT','Authority, evidence, context, counsel, and bounded execution controls','No consequential action without verified authority and accountable human authorization','SETC-PROFILE-7D-001','{}'),
('SOURCECUBE-PROFILE-7D-001','SOURCECUBE','1.0','PILOT','Context classification, evidence lineage, and advisory recommendations','Advisory-only; outputs cannot authorize transactions or mutate authoritative systems','PILOT-7D-001','{}'),
('SOURCECOIN-PROFILE-7D-001','SOURCECOIN','1.0','PILOT','Eligibility and governance signals for SourceCoin-related records','No minting, transfer, custody, valuation, redemption, or settlement authority','PILOT-7D-001','{"reference_only":true}'),
('CODEX-VERITAS-PROFILE-7D-001','CODEX_VERITAS','1.0','PILOT','Provenance, claim state, confidence, contradiction history, supersession, and truth/meaning separation','Evidence and interpretation cannot manufacture truth, authority, certainty, endorsement, or external finality','SETC-PROFILE-7D-001','{"truth_meaning_separation":true}'),
('SOURCEONE-PROFILE-7D-001','SOURCEONE','1.0','PILOT','Human-facing seven-dimensional context, explanation, warnings, approvals, and outcome visibility','Interface actions cannot bypass blocked gates, obscure uncertainty, or convert advice into authorization','SETC-PROFILE-7D-001','{"human_interface":true}'),
('SIOS-PROFILE-7D-001','SIOS','1.0','PILOT','Governed APIs, events, state machines, observability, control enforcement, and cross-domain confirmation','Orchestration cannot aggregate missing authority or represent unconfirmed external effects as complete','SETC-PROFILE-7D-001','{"ecosystem_runtime":true}'),
('SIDEKICK-OEL-PROFILE-7D-001','SIDEKICK_OEL','1.0','PILOT','Convert approved organizational intent into accountable work, controls, evidence, escalation, and outcome review','Commands remain bounded by delegated authority, OEL control level, confirmation, and SETC approval','SETC-PROFILE-7D-001','{"organizational_execution":true}'),
('SOURCEBLOCK-PROFILE-7D-001','SOURCEBLOCK','1.0','PILOT','Bounded project, activity, or value-producing unit carrying a seven-dimensional profile from initiation through closure','A SourceBlock record or anchor cannot manufacture ownership, authority, valuation, completion, or external finality','SETC-PROFILE-7D-001','{"bounded_value_unit":true}');

insert into wnf7.component_dimension_controls
select p.profile_code,d.dimension_code,
p.operational_scope || ' | ' || case d.dimension_code
when 'FEAR' then 'Resolve governing authority, rule scope, and fail closed when authority is absent, expired, or insufficient.'
when 'PRESENCE' then 'Bind canonical identity, time, place, provenance, correlation, and version without collision.'
when 'WISDOM' then 'Demonstrate purpose alignment, architectural fit, stewardship, alternatives, and durable value.'
when 'KNOWLEDGE' then 'Require attributable, current, classified, reproducible, and contradiction-aware evidence.'
when 'UNDERSTANDING' then 'Evaluate jurisdiction, affected parties, dependencies, uncertainty, asymmetry, and consequences.'
when 'COUNSEL' then 'Route approvals, dissent, exceptions, escalation, and accountable human review without self-approval.'
when 'MIGHT_POWER' then 'Constrain capability by authorization, allowlists, confirmation, idempotency, reversibility, receipts, and audit evidence.'
end,true from wnf7.component_profiles p cross join wnf7.dimension_registry d;

insert into wnf7.reviewer_roles values
('QA_LEAD','Quality and Assurance Lead','Scenario evidence, defects, and completeness',true),
('TECH_AUTHORITY','Technical Authority','Schema, validator, ledger, and limitations',true),
('SETC_OWNER','SETC Control Owner','Authority resolution and fail-closed Fear controls',true),
('SOURCECUBE_OWNER','SourceCube Technical Owner','Advisory-only behavior, reproducibility, and null command',true),
('PILOT_OWNER','Pilot Product Owner','Data boundary, privacy, and readiness',true),
('KNOWLEDGE_GOVERNOR','Knowledge Governor / Executive Sponsor','Final non-production ruling',true);

insert into wnf7.pilot_scenarios values
('SCN-001','PILOT-7D-001',array['FEAR'],'PASS','ELIGIBLE_FOR_HUMAN_DECISION','SETC_OWNER','Authority and rule references',true),
('SCN-002','PILOT-7D-001',array['FEAR'],'BLOCKED','NOT_ELIGIBLE','SETC_OWNER','Negative resolver result and governing requirement',true),
('SCN-003','PILOT-7D-001',array['FEAR'],'BLOCKED','NOT_ELIGIBLE','SETC_OWNER','Authority metadata, expiry, scope, and denial trace',true),
('SCN-004','PILOT-7D-001',array['PRESENCE'],'REVIEW','SIMULATION_ONLY','TECH_AUTHORITY','Identity registry results and collision trace',true),
('SCN-005','PILOT-7D-001',array['KNOWLEDGE'],'REVIEW','SIMULATION_ONLY','QA_LEAD','Evidence timestamp and freshness policy',true),
('SCN-006','PILOT-7D-001',array['KNOWLEDGE'],'REVIEW','SIMULATION_ONLY','QA_LEAD','Both sources, contradiction record, and reviewer route',true),
('SCN-007','PILOT-7D-001',array['KNOWLEDGE'],'BLOCKED','NOT_ELIGIBLE','QA_LEAD','Prompt/output trace and classification rule',true),
('SCN-008','PILOT-7D-001',array['WISDOM'],'BLOCKED','NOT_ELIGIBLE','PILOT_OWNER','Purpose statement and architecture rule',true),
('SCN-009','PILOT-7D-001',array['UNDERSTANDING'],'REVIEW','SIMULATION_ONLY','QA_LEAD','Jurisdiction inputs and unresolved lookup',true),
('SCN-010','PILOT-7D-001',array['UNDERSTANDING'],'BLOCKED','NOT_ELIGIBLE','QA_LEAD','Affected-party and risk analysis',true),
('SCN-011','PILOT-7D-001',array['COUNSEL'],'BLOCKED','NOT_ELIGIBLE','KNOWLEDGE_GOVERNOR','Approval matrix and missing approval trace',true),
('SCN-012','PILOT-7D-001',array['COUNSEL'],'BLOCKED','NOT_ELIGIBLE','KNOWLEDGE_GOVERNOR','Exception policy and lookup result',true),
('SCN-013','PILOT-7D-001',array['MIGHT_POWER'],'BLOCKED','NOT_ELIGIBLE','SOURCECUBE_OWNER','Idempotency key and replay detection trace',true),
('SCN-014','PILOT-7D-001',array['MIGHT_POWER'],'REVIEW','SIMULATION_ONLY','SOURCECUBE_OWNER','Instruction trace and missing confirmation',true),
('SCN-015','PILOT-7D-001',array['FEAR','PRESENCE','WISDOM','KNOWLEDGE','UNDERSTANDING','COUNSEL','MIGHT_POWER'],'BLOCKED','NOT_ELIGIBLE','KNOWLEDGE_GOVERNOR','Before/after records and mutation-isolation trace',true);

insert into wnf7.release_gates values('PILOT-7D-001','GATE-3','HOLD',false,null,'SRC-013',null,null,now());

create view wnf7.operational_readiness with(security_invoker=true) as
select g.*,
(select count(*) from wnf7.reviewer_roles where required) reviewer_target,
(select count(*) from wnf7.reviewer_assignments where pilot_code=g.pilot_code and mobilization_status='ACCEPTED') accepted_reviewers,
(select count(*) from wnf7.pilot_scenarios where pilot_code=g.pilot_code and active) evidence_target,
(select count(distinct e.scenario_code) from wnf7.evidence_items e join wnf7.pilot_scenarios s using(scenario_code) where s.pilot_code=g.pilot_code and e.validation_status='VALIDATED') validated_evidence_packets,
(select count(*) from wnf7.pilot_scenarios where pilot_code=g.pilot_code and active) decision_target,
(select count(distinct d.scenario_code) from wnf7.adjudication_decisions d join wnf7.pilot_scenarios s using(scenario_code) where s.pilot_code=g.pilot_code and d.decision_status='COMPLETE') completed_decisions,
case when g.production_authorized then 'PRODUCTION_AUTHORIZED'
when g.gate_state='AUTHORIZED' then 'AUTHORITY_ATTESTED_NON_PRODUCTION'
when (select count(*) from wnf7.reviewer_assignments where pilot_code=g.pilot_code and mobilization_status='ACCEPTED')=6
and (select count(distinct e.scenario_code) from wnf7.evidence_items e join wnf7.pilot_scenarios s using(scenario_code) where s.pilot_code=g.pilot_code and e.validation_status='VALIDATED')=15
and (select count(distinct d.scenario_code) from wnf7.adjudication_decisions d join wnf7.pilot_scenarios s using(scenario_code) where s.pilot_code=g.pilot_code and d.decision_status='COMPLETE')=15
then 'READY_FOR_AUTHORITY_REVIEW' else 'HOLD_INCOMPLETE' end derived_readiness
from wnf7.release_gates g;

revoke all on wnf7.operational_readiness from public,anon,authenticated;
grant select on wnf7.operational_readiness to service_role;
comment on table wnf7.evidence_items is 'Append-only evidence references. Never store credentials, private keys, full payment messages, or unnecessary personal data.';
comment on table wnf7.adjudication_decisions is 'Append-only human decisions; no independent legal, financial, regulatory, custody, minting, transfer, or settlement authority.';
comment on table wnf7.release_gates is 'Human-controlled release posture. Derived readiness never auto-authorizes production.';
comment on table wnf7.assessment_records is 'Append-only WNF-7 runtime assessments for all governed ecosystem components. Records advisory eligibility and never carries an execution command.';
comment on view wnf7.operational_readiness is 'READY_FOR_AUTHORITY_REVIEW is not authorization.';
