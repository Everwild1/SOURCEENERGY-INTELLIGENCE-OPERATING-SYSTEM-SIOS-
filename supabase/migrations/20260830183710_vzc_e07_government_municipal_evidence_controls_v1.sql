create table vzc.government_relationships (
  government_relationship_id uuid primary key default gen_random_uuid(), organization_binding_id uuid not null references vzc.organization_bindings(binding_id) on delete restrict,
  jurisdiction_ref text not null, relationship_type text not null check (relationship_type in ('prospect','discussion','letter_of_support','mou','evaluation','agreement','pilot_participant','contracted_relationship','other')),
  relationship_state text not null default 'prospect' check (relationship_state in ('prospect','contact_identified','discussion','interest_evidenced','formal_evaluation','agreement_or_authority_verified','pilot_participant','production_or_contracted','closed')),
  evidence_reference text, authority_reference text, effective_at timestamptz, expires_at timestamptz, provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (relationship_state not in ('agreement_or_authority_verified','pilot_participant','production_or_contracted') or (evidence_reference is not null and authority_reference is not null)),
  check (expires_at is null or effective_at is null or expires_at > effective_at)
);
create table vzc.government_evidence_bindings (
  government_evidence_binding_id uuid primary key default gen_random_uuid(), government_relationship_id uuid not null references vzc.government_relationships(government_relationship_id) on delete restrict,
  source_schema text not null, source_table text not null, source_record_key text not null,
  evidence_class text not null check (evidence_class in ('official_record','law_or_regulation','policy','mandate','agreement','mou','letter_of_support','meeting_record','grant','procurement_record','permit_or_approval','other')),
  verification_state text not null default 'identified' check (verification_state in ('identified','corroborated','verified','superseded','rejected')),
  source_authority_ref text, evidence_reference text not null, provenance jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(),
  unique(government_relationship_id, source_schema, source_table, source_record_key, evidence_class)
);
create table vzc.public_authority_grants (
  public_authority_grant_id uuid primary key default gen_random_uuid(), government_relationship_id uuid not null references vzc.government_relationships(government_relationship_id) on delete restrict,
  authority_domain text not null check (authority_domain in ('data_access','right_of_way','infrastructure_control','traffic_operations','emergency_operations','public_communications','pilot_operation','production_operation','other')),
  authority_scope text not null, competent_authority_ref text not null, authority_reference text not null, evidence_reference text not null,
  grant_state text not null default 'proposed' check (grant_state in ('proposed','verified','active','expired','revoked','superseded')), valid_from timestamptz, valid_until timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (grant_state not in ('verified','active') or valid_from is not null), check (valid_until is null or valid_from is null or valid_until > valid_from),
  unique(government_relationship_id, authority_domain, authority_reference)
);
create table vzc.procurement_status_bindings (
  procurement_binding_id uuid primary key default gen_random_uuid(), government_relationship_id uuid not null references vzc.government_relationships(government_relationship_id) on delete restrict,
  source_schema text not null, source_table text not null, source_record_key text not null,
  procurement_stage text not null check (procurement_stage in ('none','market_research','rfp_or_solicitation','bid_submitted','evaluation','notice_of_intent','award','contract_executed','closed')),
  evidence_reference text, authority_reference text, contract_reference text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (procurement_stage not in ('award','contract_executed') or (evidence_reference is not null and authority_reference is not null)),
  check (procurement_stage <> 'contract_executed' or contract_reference is not null), unique(government_relationship_id, source_schema, source_table, source_record_key)
);
create table vzc.deployment_authorization_gates (
  deployment_gate_id uuid primary key default gen_random_uuid(), government_relationship_id uuid not null references vzc.government_relationships(government_relationship_id) on delete restrict,
  deployment_scope text not null, deployment_stage text not null default 'candidate' check (deployment_stage in ('candidate','feasibility','evidence_complete','integration_designed','prototype','pilot_approved','pilot_active','production_approved','closed')),
  public_authority_grant_id uuid references vzc.public_authority_grants(public_authority_grant_id) on delete restrict,
  procurement_binding_id uuid references vzc.procurement_status_bindings(procurement_binding_id) on delete restrict,
  safety_case_reference text, governance_approval_reference text, operational_owner_ref text, valid_from timestamptz, valid_until timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (deployment_stage not in ('pilot_approved','pilot_active','production_approved') or (public_authority_grant_id is not null and safety_case_reference is not null and governance_approval_reference is not null and operational_owner_ref is not null)),
  check (valid_until is null or valid_from is null or valid_until > valid_from)
);
create index vzc_government_relationship_org_idx on vzc.government_relationships(organization_binding_id, relationship_state);
create index vzc_government_evidence_relationship_idx on vzc.government_evidence_bindings(government_relationship_id, verification_state);
create index vzc_public_authority_relationship_idx on vzc.public_authority_grants(government_relationship_id, authority_domain, grant_state);
create index vzc_procurement_relationship_idx on vzc.procurement_status_bindings(government_relationship_id, procurement_stage);
create index vzc_deployment_relationship_idx on vzc.deployment_authorization_gates(government_relationship_id, deployment_stage);
alter table vzc.government_relationships enable row level security; alter table vzc.government_evidence_bindings enable row level security; alter table vzc.public_authority_grants enable row level security; alter table vzc.procurement_status_bindings enable row level security; alter table vzc.deployment_authorization_gates enable row level security;
revoke all on table vzc.government_relationships, vzc.government_evidence_bindings, vzc.public_authority_grants, vzc.procurement_status_bindings, vzc.deployment_authorization_gates from anon, authenticated;
grant select, insert, update, delete on vzc.government_relationships, vzc.government_evidence_bindings, vzc.public_authority_grants, vzc.procurement_status_bindings, vzc.deployment_authorization_gates to service_role;
create policy vzc_government_relationship_service_role_all on vzc.government_relationships for all to service_role using (true) with check (true);
create policy vzc_government_evidence_service_role_all on vzc.government_evidence_bindings for all to service_role using (true) with check (true);
create policy vzc_public_authority_service_role_all on vzc.public_authority_grants for all to service_role using (true) with check (true);
create policy vzc_procurement_status_service_role_all on vzc.procurement_status_bindings for all to service_role using (true) with check (true);
create policy vzc_deployment_gate_service_role_all on vzc.deployment_authorization_gates for all to service_role using (true) with check (true);
comment on table vzc.government_relationships is 'Evidence-governed VZC relationship projection for public institutions. Listing, meetings, interest, grants or MOUs do not by themselves confer public authority, procurement award or production status.';
comment on table vzc.government_evidence_bindings is 'References authoritative government evidence without duplicating the authoritative source record.';
comment on table vzc.public_authority_grants is 'Explicit bounded public-authority evidence. VZC never acquires municipal, regulatory, traffic, emergency or infrastructure authority by implication.';
comment on table vzc.procurement_status_bindings is 'Procurement evidence projection. Meetings, demonstrations, pilots, grants, MOUs and letters of support are not procurement awards or executed contracts.';
comment on table vzc.deployment_authorization_gates is 'Government/municipal deployment gate. Pilot or production status requires explicit authority, safety case, governance approval and operational ownership.';