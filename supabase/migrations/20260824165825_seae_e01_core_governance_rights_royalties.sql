create schema if not exists seae;

create table seae.cultural_authorities (
  id uuid primary key default gen_random_uuid(),
  authority_name text not null check (length(btrim(authority_name)) > 0),
  authority_type text not null check (authority_type in ('community','indigenous','lineage','religious','heritage','institutional','other')),
  organization_oid text references public.setc_organizations(oid),
  jurisdiction text,
  evidence_reference text,
  authority_status text not null default 'asserted' check (authority_status in ('asserted','pending_verification','verified','disputed','suspended','revoked','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table seae.creator_profiles (
  creator_id uuid primary key references cruds.creators(id) on delete cascade,
  organization_oid text references public.setc_organizations(oid),
  representation_status text not null default 'independent' check (representation_status in ('independent','represented','institutional','community-held','other')),
  professional_roles text[] not null default '{}',
  safeguarding_required boolean not null default false,
  cultural_authority_id uuid references seae.cultural_authorities(id),
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table seae.work_registry (
  work_id uuid primary key references cruds.works(id) on delete cascade,
  asset_class text not null default 'creative_work',
  cultural_context text,
  provenance_reference text,
  cultural_authority_id uuid references seae.cultural_authorities(id),
  ownership_status text not null default 'unverified' check (ownership_status in ('unverified','asserted','partially_verified','verified','disputed','restricted')),
  consent_status text not null default 'not_required' check (consent_status in ('not_required','required','pending','granted','restricted','withdrawn','disputed')),
  permitted_uses text[],
  restrictions text[],
  lifecycle_status text not null default 'active' check (lifecycle_status in ('draft','active','restricted','disputed','archived','withdrawn')),
  review_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table seae.work_registry is 'SEAE extension registry. A registry entry records governance metadata only and does not create, transfer, extinguish, or adjudicate ownership or community, moral, customary, or third-party rights.';

create table seae.rights_interests (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references cruds.works(id) on delete cascade,
  holder_creator_id uuid references cruds.creators(id),
  holder_organization_oid text references public.setc_organizations(oid),
  cultural_authority_id uuid references seae.cultural_authorities(id),
  right_type text not null,
  interest_type text not null default 'ownership' check (interest_type in ('ownership','license','performer','publicity','moral','community','custodial','security','other')),
  share_percent numeric(7,4) check (share_percent is null or (share_percent >= 0 and share_percent <= 100)),
  territory text,
  effective_from date,
  effective_to date,
  evidence_reference text,
  verification_state text not null default 'asserted' check (verification_state in ('asserted','pending_verification','verified','disputed','expired','revoked')),
  created_at timestamptz not null default now(),
  check (holder_creator_id is not null or holder_organization_oid is not null or cultural_authority_id is not null),
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create table seae.licenses (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references cruds.works(id) on delete cascade,
  licensor_creator_id uuid references cruds.creators(id),
  licensor_organization_oid text references public.setc_organizations(oid),
  licensee_organization_oid text references public.setc_organizations(oid),
  license_type text not null,
  territory text,
  permitted_uses text[] not null default '{}',
  restrictions text[] not null default '{}',
  effective_from date,
  effective_to date,
  compensation_terms text,
  contract_reference text,
  status text not null default 'draft' check (status in ('draft','pending','active','suspended','expired','terminated','disputed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (licensor_creator_id is not null or licensor_organization_oid is not null),
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create table seae.productions (
  id uuid primary key default gen_random_uuid(),
  production_reference text not null unique,
  title text not null check (length(btrim(title)) > 0),
  production_type text not null,
  lead_organization_oid text references public.setc_organizations(oid),
  primary_work_id uuid references cruds.works(id),
  budget_amount numeric(20,2) check (budget_amount is null or budget_amount >= 0),
  budget_currency text,
  status text not null default 'development' check (status in ('development','financing','preproduction','production','postproduction','distribution','completed','suspended','cancelled')),
  rights_clearance_status text not null default 'pending' check (rights_clearance_status in ('pending','partial','cleared','restricted','blocked','disputed')),
  start_date date,
  end_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date is null or start_date is null or end_date >= start_date)
);

create table seae.production_participants (
  production_id uuid not null references seae.productions(id) on delete cascade,
  creator_id uuid references cruds.creators(id),
  organization_oid text references public.setc_organizations(oid),
  participant_role text not null,
  contract_reference text,
  compensation_terms text,
  rights_terms text,
  created_at timestamptz not null default now(),
  primary key (production_id, participant_role, creator_id, organization_oid),
  check (creator_id is not null or organization_oid is not null)
);

create table seae.revenue_events (
  id uuid primary key default gen_random_uuid(),
  event_reference text not null unique,
  work_id uuid references cruds.works(id),
  production_id uuid references seae.productions(id),
  source_organization_oid text references public.setc_organizations(oid),
  revenue_type text not null,
  gross_amount numeric(20,2) not null check (gross_amount >= 0),
  currency text not null,
  deductions_amount numeric(20,2) not null default 0 check (deductions_amount >= 0),
  distributable_amount numeric(20,2) generated always as (gross_amount - deductions_amount) stored,
  territory text,
  occurred_at timestamptz not null,
  evidence_reference text,
  status text not null default 'recorded' check (status in ('recorded','verified','disputed','reversed','settled')),
  created_at timestamptz not null default now(),
  check (work_id is not null or production_id is not null),
  check (deductions_amount <= gross_amount)
);

create table seae.royalty_allocations (
  id uuid primary key default gen_random_uuid(),
  revenue_event_id uuid not null references seae.revenue_events(id) on delete cascade,
  beneficiary_creator_id uuid references cruds.creators(id),
  beneficiary_organization_oid text references public.setc_organizations(oid),
  cultural_authority_id uuid references seae.cultural_authorities(id),
  allocation_basis text not null,
  allocation_percent numeric(9,6) check (allocation_percent is null or (allocation_percent >= 0 and allocation_percent <= 100)),
  allocation_amount numeric(20,2) not null check (allocation_amount >= 0),
  recoupment_amount numeric(20,2) not null default 0 check (recoupment_amount >= 0),
  payable_amount numeric(20,2) generated always as (allocation_amount - recoupment_amount) stored,
  payment_status text not null default 'calculated' check (payment_status in ('calculated','approved','payable','paid','held','disputed','reversed')),
  statement_reference text,
  created_at timestamptz not null default now(),
  check (beneficiary_creator_id is not null or beneficiary_organization_oid is not null or cultural_authority_id is not null),
  check (recoupment_amount <= allocation_amount)
);

create table seae.audit_events (
  id bigint generated always as identity primary key,
  entity_type text not null,
  entity_id text not null,
  action text not null,
  actor_reference text,
  evidence_reference text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index seae_rights_interests_work_idx on seae.rights_interests(work_id);
create index seae_licenses_work_idx on seae.licenses(work_id);
create index seae_productions_org_idx on seae.productions(lead_organization_oid);
create index seae_revenue_events_work_idx on seae.revenue_events(work_id);
create index seae_revenue_events_production_idx on seae.revenue_events(production_id);
create index seae_royalty_allocations_event_idx on seae.royalty_allocations(revenue_event_id);

alter table seae.cultural_authorities enable row level security;
alter table seae.creator_profiles enable row level security;
alter table seae.work_registry enable row level security;
alter table seae.rights_interests enable row level security;
alter table seae.licenses enable row level security;
alter table seae.productions enable row level security;
alter table seae.production_participants enable row level security;
alter table seae.revenue_events enable row level security;
alter table seae.royalty_allocations enable row level security;
alter table seae.audit_events enable row level security;

revoke all on schema seae from public, anon, authenticated;
grant usage on schema seae to service_role;
grant all privileges on all tables in schema seae to service_role;
grant usage, select on all sequences in schema seae to service_role;

create policy seae_cultural_authorities_service_role_all on seae.cultural_authorities for all to service_role using (true) with check (true);
create policy seae_creator_profiles_service_role_all on seae.creator_profiles for all to service_role using (true) with check (true);
create policy seae_work_registry_service_role_all on seae.work_registry for all to service_role using (true) with check (true);
create policy seae_rights_interests_service_role_all on seae.rights_interests for all to service_role using (true) with check (true);
create policy seae_licenses_service_role_all on seae.licenses for all to service_role using (true) with check (true);
create policy seae_productions_service_role_all on seae.productions for all to service_role using (true) with check (true);
create policy seae_production_participants_service_role_all on seae.production_participants for all to service_role using (true) with check (true);
create policy seae_revenue_events_service_role_all on seae.revenue_events for all to service_role using (true) with check (true);
create policy seae_royalty_allocations_service_role_all on seae.royalty_allocations for all to service_role using (true) with check (true);
create policy seae_audit_events_service_role_all on seae.audit_events for all to service_role using (true) with check (true);
