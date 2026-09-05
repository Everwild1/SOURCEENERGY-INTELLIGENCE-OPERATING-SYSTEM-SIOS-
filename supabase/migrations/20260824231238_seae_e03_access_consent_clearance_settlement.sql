create table seae.roles (
  role_code text primary key,
  role_name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table seae.permissions (
  permission_code text primary key,
  permission_name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table seae.role_permissions (
  role_code text not null references seae.roles(role_code) on delete cascade,
  permission_code text not null references seae.permissions(permission_code) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_code, permission_code)
);

create table seae.access_memberships (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  role_code text not null references seae.roles(role_code) on delete restrict,
  organization_oid text references public.setc_organizations(oid) on delete restrict,
  creator_id uuid references cruds.creators(id) on delete restrict,
  cultural_authority_id uuid references seae.cultural_authorities(id) on delete restrict,
  scope jsonb not null default '{}'::jsonb,
  assignment_state text not null default 'PENDING' check (assignment_state in ('PENDING','ACTIVE','SUSPENDED','REVOKED','EXPIRED')),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  evidence_reference text,
  granted_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from),
  unique (auth_user_id, role_code, organization_oid, creator_id, cultural_authority_id, effective_from)
);

create table seae.consent_records (
  id uuid primary key default gen_random_uuid(),
  grantor_creator_id uuid references cruds.creators(id),
  grantor_organization_oid text references public.setc_organizations(oid),
  grantor_cultural_authority_id uuid references seae.cultural_authorities(id),
  grantee_type text not null check (grantee_type in ('creator','organization','platform','production','event','public','other')),
  grantee_reference text not null,
  resource_type text not null,
  resource_reference text not null,
  purpose text not null,
  scope jsonb not null default '{}'::jsonb,
  restrictions jsonb not null default '{}'::jsonb,
  status text not null default 'active' check (status in ('active','revoked','expired','superseded','disputed')),
  effective_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  evidence_reference text,
  created_at timestamptz not null default now(),
  check (grantor_creator_id is not null or grantor_organization_oid is not null or grantor_cultural_authority_id is not null),
  check (expires_at is null or expires_at > effective_at),
  check (revoked_at is null or revoked_at >= effective_at),
  check ((status='revoked' and revoked_at is not null) or status<>'revoked')
);

create table seae.clearance_cases (
  id uuid primary key default gen_random_uuid(),
  case_reference text not null unique,
  case_type text not null check (case_type in ('work','production','event','distribution','cultural_asset','license','publication','other')),
  work_id uuid references cruds.works(id),
  production_id uuid references seae.productions(id),
  event_id uuid references seae.events(id),
  cultural_asset_id uuid references seae.cultural_assets(id),
  license_id uuid references seae.licenses(id),
  requesting_organization_oid text references public.setc_organizations(oid),
  status text not null default 'open' check (status in ('open','in_review','blocked','conditionally_cleared','cleared','rejected','withdrawn','expired')),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (num_nonnulls(work_id,production_id,event_id,cultural_asset_id,license_id) >= 1),
  check (closed_at is null or closed_at >= opened_at)
);

create table seae.clearance_requirements (
  id uuid primary key default gen_random_uuid(),
  clearance_case_id uuid not null references seae.clearance_cases(id) on delete cascade,
  requirement_code text not null,
  requirement_type text not null check (requirement_type in ('rights','consent','cultural_authority','contract','safeguarding','privacy','editorial','insurance','finance','distribution','other')),
  description text not null,
  mandatory boolean not null default true,
  status text not null default 'pending' check (status in ('pending','satisfied','waived','failed','not_applicable','disputed')),
  evidence_reference text,
  reviewed_by_reference text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (clearance_case_id, requirement_code)
);

create table seae.clearance_decisions (
  id uuid primary key default gen_random_uuid(),
  clearance_case_id uuid not null references seae.clearance_cases(id) on delete cascade,
  decision text not null check (decision in ('approve','approve_with_conditions','deny','hold','request_evidence')),
  conditions jsonb not null default '{}'::jsonb,
  rationale text,
  decided_by_reference text not null,
  evidence_reference text,
  decided_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table seae.royalty_approval_batches (
  id uuid primary key default gen_random_uuid(),
  batch_reference text not null unique,
  currency text not null,
  period_start date,
  period_end date,
  status text not null default 'draft' check (status in ('draft','calculated','under_review','approved','rejected','submitted_for_settlement','partially_settled','settled','cancelled')),
  prepared_by_reference text,
  approved_by_reference text,
  approved_at timestamptz,
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (period_end is null or period_start is null or period_end >= period_start),
  check ((status in ('approved','submitted_for_settlement','partially_settled','settled') and approved_at is not null and approved_by_reference is not null) or status not in ('approved','submitted_for_settlement','partially_settled','settled'))
);

create table seae.royalty_approval_items (
  batch_id uuid not null references seae.royalty_approval_batches(id) on delete cascade,
  royalty_allocation_id uuid not null references seae.royalty_allocations(id) on delete restrict,
  approval_state text not null default 'pending' check (approval_state in ('pending','approved','held','rejected','disputed')),
  review_note text,
  created_at timestamptz not null default now(),
  primary key (batch_id, royalty_allocation_id)
);

create table seae.settlement_requests (
  id uuid primary key default gen_random_uuid(),
  settlement_reference text not null unique,
  royalty_batch_id uuid references seae.royalty_approval_batches(id) on delete restrict,
  revenue_event_id uuid references seae.revenue_events(id) on delete restrict,
  settlement_method text not null,
  destination_reference text not null,
  amount numeric(20,2) not null check (amount >= 0),
  currency text not null,
  status text not null default 'requested' check (status in ('requested','authorized','submitted','processing','settled','failed','cancelled','disputed')),
  requested_by_reference text not null,
  authorized_by_reference text,
  authorized_at timestamptz,
  external_system_reference text,
  evidence_reference text,
  requested_at timestamptz not null default now(),
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (royalty_batch_id is not null or revenue_event_id is not null),
  check ((status in ('authorized','submitted','processing','settled') and authorized_by_reference is not null and authorized_at is not null) or status not in ('authorized','submitted','processing','settled')),
  check (settled_at is null or settled_at >= requested_at)
);
comment on table seae.settlement_requests is 'Control-plane requests only. This table does not move funds or create a payment, token, or Source Coin transaction.';

create table seae.settlement_events (
  id uuid primary key default gen_random_uuid(),
  settlement_request_id uuid not null references seae.settlement_requests(id) on delete cascade,
  event_type text not null check (event_type in ('requested','authorized','submitted','processing','confirmed','failed','cancelled','reversed','disputed')),
  external_reference text,
  event_payload jsonb not null default '{}'::jsonb,
  evidence_reference text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

insert into seae.roles(role_code,role_name,description) values
('seae_admin','SEAE Administrator','Administrative control-plane role'),
('seae_governance_steward','SEAE Governance Steward','Governance and cultural-rights oversight'),
('rights_manager','Rights Manager','Rights, licensing and clearance administration'),
('production_manager','Production Manager','Production and event operations'),
('royalty_accountant','Royalty Accountant','Revenue and royalty preparation'),
('auditor','Auditor','Read-only assurance and audit role'),
('creator','Creator','Creator-scoped participation role'),
('cultural_authority','Cultural Authority','Cultural authority and consent participation'),
('read_only','Read Only','Restricted read-only role')
on conflict (role_code) do nothing;

insert into seae.permissions(permission_code,permission_name,description) values
('creator.read','Read Creators','Read permitted creator records'),
('creator.manage','Manage Creators','Manage permitted creator profiles'),
('work.read','Read Works','Read permitted works'),
('work.manage','Manage Works','Manage works governance metadata'),
('rights.read','Read Rights','Read rights and licensing records'),
('rights.manage','Manage Rights','Create and manage rights interests'),
('license.approve','Approve Licenses','Approve licensing decisions'),
('consent.manage','Manage Consent','Create, revoke and supersede consent records'),
('clearance.review','Review Clearance','Review clearance requirements'),
('clearance.decide','Decide Clearance','Issue clearance decisions'),
('production.manage','Manage Productions','Manage production and event controls'),
('royalty.calculate','Calculate Royalties','Prepare royalty allocations and batches'),
('royalty.approve','Approve Royalties','Approve royalty batches'),
('settlement.request','Request Settlement','Create settlement control requests'),
('settlement.authorize','Authorize Settlement','Authorize settlement requests'),
('audit.read','Read Audit','Read audit and assurance records')
on conflict (permission_code) do nothing;

insert into seae.role_permissions(role_code,permission_code)
select r.role_code,p.permission_code from seae.roles r cross join seae.permissions p
where r.role_code='seae_admin'
on conflict do nothing;

insert into seae.role_permissions(role_code,permission_code) values
('seae_governance_steward','creator.read'),('seae_governance_steward','work.read'),('seae_governance_steward','rights.read'),('seae_governance_steward','consent.manage'),('seae_governance_steward','clearance.review'),('seae_governance_steward','clearance.decide'),('seae_governance_steward','audit.read'),
('rights_manager','creator.read'),('rights_manager','work.read'),('rights_manager','rights.read'),('rights_manager','rights.manage'),('rights_manager','license.approve'),('rights_manager','clearance.review'),('rights_manager','audit.read'),
('production_manager','creator.read'),('production_manager','work.read'),('production_manager','production.manage'),('production_manager','clearance.review'),
('royalty_accountant','work.read'),('royalty_accountant','rights.read'),('royalty_accountant','royalty.calculate'),('royalty_accountant','settlement.request'),('royalty_accountant','audit.read'),
('auditor','creator.read'),('auditor','work.read'),('auditor','rights.read'),('auditor','audit.read'),
('creator','creator.read'),('creator','work.read'),('creator','rights.read'),
('cultural_authority','creator.read'),('cultural_authority','work.read'),('cultural_authority','rights.read'),('cultural_authority','consent.manage'),('cultural_authority','clearance.review'),
('read_only','creator.read'),('read_only','work.read')
on conflict do nothing;

create index seae_access_memberships_user_idx on seae.access_memberships(auth_user_id);
create index seae_access_memberships_org_idx on seae.access_memberships(organization_oid);
create index seae_access_memberships_creator_idx on seae.access_memberships(creator_id);
create index seae_access_memberships_authority_idx on seae.access_memberships(cultural_authority_id);
create index seae_consent_grantor_creator_idx on seae.consent_records(grantor_creator_id);
create index seae_consent_grantor_org_idx on seae.consent_records(grantor_organization_oid);
create index seae_consent_grantor_authority_idx on seae.consent_records(grantor_cultural_authority_id);
create index seae_clearance_work_idx on seae.clearance_cases(work_id);
create index seae_clearance_production_idx on seae.clearance_cases(production_id);
create index seae_clearance_event_idx on seae.clearance_cases(event_id);
create index seae_clearance_asset_idx on seae.clearance_cases(cultural_asset_id);
create index seae_clearance_license_idx on seae.clearance_cases(license_id);
create index seae_clearance_org_idx on seae.clearance_cases(requesting_organization_oid);
create index seae_clearance_requirements_case_idx on seae.clearance_requirements(clearance_case_id);
create index seae_clearance_decisions_case_idx on seae.clearance_decisions(clearance_case_id);
create index seae_royalty_items_allocation_idx on seae.royalty_approval_items(royalty_allocation_id);
create index seae_settlement_batch_idx on seae.settlement_requests(royalty_batch_id);
create index seae_settlement_revenue_idx on seae.settlement_requests(revenue_event_id);
create index seae_settlement_events_request_idx on seae.settlement_events(settlement_request_id);

create index if not exists seae_creator_profiles_authority_idx on seae.creator_profiles(cultural_authority_id);
create index if not exists seae_creator_profiles_org_idx on seae.creator_profiles(organization_oid);
create index if not exists seae_cultural_assets_creator_idx on seae.cultural_assets(creator_id);
create index if not exists seae_cultural_assets_owner_org_idx on seae.cultural_assets(owner_organization_oid);
create index if not exists seae_cultural_assets_steward_org_idx on seae.cultural_assets(steward_organization_oid);
create index if not exists seae_cultural_authorities_org_idx on seae.cultural_authorities(organization_oid);
create index if not exists seae_cultural_claims_authority_idx on seae.cultural_claims(claimant_authority_id);
create index if not exists seae_cultural_claims_creator_idx on seae.cultural_claims(claimant_creator_id);
create index if not exists seae_cultural_claims_org_idx on seae.cultural_claims(claimant_organization_oid);
create index if not exists seae_cultural_claims_asset_idx on seae.cultural_claims(cultural_asset_id);
create index if not exists seae_cultural_claims_work_idx on seae.cultural_claims(work_id);
create index if not exists seae_distribution_rights_distributor_idx on seae.distribution_rights(distributor_organization_oid);
create index if not exists seae_distribution_rights_license_idx on seae.distribution_rights(license_id);
create index if not exists seae_event_participants_creator_idx on seae.event_participants(creator_id);
create index if not exists seae_event_participants_event_idx on seae.event_participants(event_id);
create index if not exists seae_event_participants_org_idx on seae.event_participants(organization_oid);
create index if not exists seae_events_authority_idx on seae.events(cultural_authority_id);
create index if not exists seae_heritage_plans_asset_idx on seae.heritage_stewardship_plans(cultural_asset_id);
create index if not exists seae_heritage_plans_org_idx on seae.heritage_stewardship_plans(responsible_organization_oid);
create index if not exists seae_licenses_licensee_org_idx on seae.licenses(licensee_organization_oid);
create index if not exists seae_licenses_licensor_creator_idx on seae.licenses(licensor_creator_id);
create index if not exists seae_licenses_licensor_org_idx on seae.licenses(licensor_organization_oid);
create index if not exists seae_production_participants_creator_idx on seae.production_participants(creator_id);
create index if not exists seae_production_participants_org_idx on seae.production_participants(organization_oid);
create index if not exists seae_productions_primary_work_idx on seae.productions(primary_work_id);
create index if not exists seae_revenue_events_source_org_idx on seae.revenue_events(source_organization_oid);
create index if not exists seae_rights_authority_idx on seae.rights_interests(cultural_authority_id);
create index if not exists seae_rights_holder_creator_idx on seae.rights_interests(holder_creator_id);
create index if not exists seae_rights_holder_org_idx on seae.rights_interests(holder_organization_oid);
create index if not exists seae_royalty_beneficiary_creator_idx on seae.royalty_allocations(beneficiary_creator_id);
create index if not exists seae_royalty_beneficiary_org_idx on seae.royalty_allocations(beneficiary_organization_oid);
create index if not exists seae_royalty_authority_idx on seae.royalty_allocations(cultural_authority_id);
create index if not exists seae_wim_offering_asset_idx on seae.wim_offering_links(cultural_asset_id);
create index if not exists seae_wim_offering_event_idx on seae.wim_offering_links(event_id);
create index if not exists seae_wim_offering_production_idx on seae.wim_offering_links(production_id);
create index if not exists seae_wim_offering_work_idx on seae.wim_offering_links(work_id);
create index if not exists seae_wim_opportunity_asset_idx on seae.wim_opportunity_links(cultural_asset_id);
create index if not exists seae_wim_opportunity_event_idx on seae.wim_opportunity_links(event_id);
create index if not exists seae_wim_opportunity_production_idx on seae.wim_opportunity_links(production_id);
create index if not exists seae_wim_opportunity_work_idx on seae.wim_opportunity_links(work_id);
create index if not exists seae_wim_org_wim_id_idx on seae.wim_organization_links(wim_organization_id);
create index if not exists seae_work_registry_authority_idx on seae.work_registry(cultural_authority_id);

alter table seae.roles enable row level security;
alter table seae.permissions enable row level security;
alter table seae.role_permissions enable row level security;
alter table seae.access_memberships enable row level security;
alter table seae.consent_records enable row level security;
alter table seae.clearance_cases enable row level security;
alter table seae.clearance_requirements enable row level security;
alter table seae.clearance_decisions enable row level security;
alter table seae.royalty_approval_batches enable row level security;
alter table seae.royalty_approval_items enable row level security;
alter table seae.settlement_requests enable row level security;
alter table seae.settlement_events enable row level security;

grant all privileges on all tables in schema seae to service_role;
grant usage, select on all sequences in schema seae to service_role;

create policy seae_roles_service_role_all on seae.roles for all to service_role using (true) with check (true);
create policy seae_permissions_service_role_all on seae.permissions for all to service_role using (true) with check (true);
create policy seae_role_permissions_service_role_all on seae.role_permissions for all to service_role using (true) with check (true);
create policy seae_access_memberships_service_role_all on seae.access_memberships for all to service_role using (true) with check (true);
create policy seae_consent_records_service_role_all on seae.consent_records for all to service_role using (true) with check (true);
create policy seae_clearance_cases_service_role_all on seae.clearance_cases for all to service_role using (true) with check (true);
create policy seae_clearance_requirements_service_role_all on seae.clearance_requirements for all to service_role using (true) with check (true);
create policy seae_clearance_decisions_service_role_all on seae.clearance_decisions for all to service_role using (true) with check (true);
create policy seae_royalty_approval_batches_service_role_all on seae.royalty_approval_batches for all to service_role using (true) with check (true);
create policy seae_royalty_approval_items_service_role_all on seae.royalty_approval_items for all to service_role using (true) with check (true);
create policy seae_settlement_requests_service_role_all on seae.settlement_requests for all to service_role using (true) with check (true);
create policy seae_settlement_events_service_role_all on seae.settlement_events for all to service_role using (true) with check (true);
