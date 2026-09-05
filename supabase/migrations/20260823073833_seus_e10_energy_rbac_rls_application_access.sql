create schema if not exists energy_access;
revoke all on schema energy_access from public, anon, authenticated;
grant usage on schema energy_access to authenticated, service_role;

create table if not exists energy_access.roles (
  role_code text primary key check (role_code ~ '^[A-Z_]{3,64}$'),
  role_name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists energy_access.permissions (
  permission_code text primary key check (permission_code ~ '^[a-z0-9_.-]{3,96}$'),
  permission_name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists energy_access.role_permissions (
  role_code text not null references energy_access.roles(role_code) on delete cascade,
  permission_code text not null references energy_access.permissions(permission_code) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(role_code, permission_code)
);

create table if not exists energy_access.user_role_assignments (
  assignment_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  organization_oid text references public.setc_organizations(oid) on delete restrict,
  role_code text not null references energy_access.roles(role_code) on delete restrict,
  assignment_state text not null default 'ACTIVE' check (assignment_state in ('PENDING','ACTIVE','SUSPENDED','REVOKED','EXPIRED')),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  evidence_reference text,
  granted_by_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from),
  unique(user_id, organization_oid, role_code, effective_from)
);
comment on table energy_access.user_role_assignments is 'Private SourceEnergy.us portal authorization assignments. Access is application authorization only and does not establish organizational office, legal authority, financial authority, trading authority, or regulatory standing.';

alter table energy_access.roles enable row level security;
alter table energy_access.permissions enable row level security;
alter table energy_access.role_permissions enable row level security;
alter table energy_access.user_role_assignments enable row level security;

revoke all on all tables in schema energy_access from public, anon, authenticated;
grant all on all tables in schema energy_access to service_role;

insert into energy_access.roles(role_code, role_name, description) values
('PORTAL_VIEWER','Portal Viewer','Read approved institutional reference data.'),
('ENERGY_ANALYST','Energy Analyst','Read reference, operational, environmental, financial-model and risk intelligence.'),
('ENERGY_OPERATOR','Energy Operator','Read operational and commercial operating data for authorized workflows.'),
('GOVERNANCE_REVIEWER','Governance Reviewer','Read all governed SourceEnergy.us energy-domain records for review.'),
('ENERGY_ADMIN','Energy Administrator','Administrative application role; write authority remains server-side and workflow governed.')
on conflict(role_code) do update set role_name=excluded.role_name, description=excluded.description;

insert into energy_access.permissions(permission_code,permission_name,description) values
('energy.reference.read','Reference Read','Read markets, regions, assets and projects approved for institutional portal access.'),
('energy.commercial.read','Commercial Read','Read commercial agreements, counterparties, terms and transaction-intent references.'),
('energy.operations.read','Operations Read','Read metering, generation, storage, outage and operating-performance records.'),
('energy.environmental.read','Environmental Read','Read environmental attributes, emissions and sustainability evidence.'),
('energy.finance.read','Finance Intelligence Read','Read financial models, assumptions, valuations and capital-readiness intelligence.'),
('energy.risk.read','Risk Intelligence Read','Read portfolios, scenarios, risk and executive analytical recommendations.'),
('energy.governance.read','Governance Read','Read governed evidence/reference structures across the energy domain.')
on conflict(permission_code) do update set permission_name=excluded.permission_name, description=excluded.description;

insert into energy_access.role_permissions(role_code,permission_code) values
('PORTAL_VIEWER','energy.reference.read'),
('ENERGY_ANALYST','energy.reference.read'),('ENERGY_ANALYST','energy.operations.read'),('ENERGY_ANALYST','energy.environmental.read'),('ENERGY_ANALYST','energy.finance.read'),('ENERGY_ANALYST','energy.risk.read'),
('ENERGY_OPERATOR','energy.reference.read'),('ENERGY_OPERATOR','energy.commercial.read'),('ENERGY_OPERATOR','energy.operations.read'),('ENERGY_OPERATOR','energy.environmental.read'),
('GOVERNANCE_REVIEWER','energy.reference.read'),('GOVERNANCE_REVIEWER','energy.commercial.read'),('GOVERNANCE_REVIEWER','energy.operations.read'),('GOVERNANCE_REVIEWER','energy.environmental.read'),('GOVERNANCE_REVIEWER','energy.finance.read'),('GOVERNANCE_REVIEWER','energy.risk.read'),('GOVERNANCE_REVIEWER','energy.governance.read'),
('ENERGY_ADMIN','energy.reference.read'),('ENERGY_ADMIN','energy.commercial.read'),('ENERGY_ADMIN','energy.operations.read'),('ENERGY_ADMIN','energy.environmental.read'),('ENERGY_ADMIN','energy.finance.read'),('ENERGY_ADMIN','energy.risk.read'),('ENERGY_ADMIN','energy.governance.read')
on conflict do nothing;

create index if not exists idx_energy_access_user_roles_user on energy_access.user_role_assignments(user_id, assignment_state);
create index if not exists idx_energy_access_user_roles_org on energy_access.user_role_assignments(organization_oid) where organization_oid is not null;
create index if not exists idx_energy_access_role_permissions_permission on energy_access.role_permissions(permission_code);

create or replace function energy_access.authorize(requested_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from energy_access.user_role_assignments ura
    join energy_access.role_permissions rp on rp.role_code = ura.role_code
    join energy_access.roles r on r.role_code = ura.role_code
    where ura.user_id = (select auth.uid())
      and ura.assignment_state = 'ACTIVE'
      and r.is_active = true
      and rp.permission_code = requested_permission
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  );
$$;
revoke all on function energy_access.authorize(text) from public, anon;
grant execute on function energy_access.authorize(text) to authenticated, service_role;

-- Expose SELECT privilege only; RLS policies remain the authorization boundary.
grant usage on schema energy to authenticated;

do $$
declare t text;
begin
  foreach t in array array['markets','market_regions','market_organization_links','market_external_references','assets','asset_market_links','asset_organization_links','asset_external_references','der_resources','storage_resources','projects','project_asset_links','project_organization_links','project_market_links','interconnection_queue_entries','project_permits','project_stage_events','project_external_links'] loop
    execute format('grant select on energy.%I to authenticated', t);
    execute format('drop policy if exists seus_reference_read on energy.%I', t);
    execute format('create policy seus_reference_read on energy.%I for select to authenticated using ((select energy_access.authorize(''energy.reference.read'')))', t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['commercial_agreements','agreement_counterparties','agreement_project_links','agreement_asset_links','agreement_market_links','agreement_terms','commercial_transaction_intents','execution_references'] loop
    execute format('grant select on energy.%I to authenticated', t);
    execute format('drop policy if exists seus_commercial_read on energy.%I', t);
    execute format('create policy seus_commercial_read on energy.%I for select to authenticated using ((select energy_access.authorize(''energy.commercial.read'')))', t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['measurement_sources','meters','meter_readings','generation_observations','storage_observations','outage_events','operational_performance_snapshots','operations_evidence_links'] loop
    execute format('grant select on energy.%I to authenticated', t);
    execute format('drop policy if exists seus_operations_read on energy.%I', t);
    execute format('create policy seus_operations_read on energy.%I for select to authenticated using ((select energy_access.authorize(''energy.operations.read'')))', t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['environmental_attribute_programs','environmental_attributes','attribute_generation_links','attribute_lifecycle_events','emissions_observations','sustainability_claims','claim_attribute_links','claim_emissions_links','environmental_external_references'] loop
    execute format('grant select on energy.%I to authenticated', t);
    execute format('drop policy if exists seus_environmental_read on energy.%I', t);
    execute format('create policy seus_environmental_read on energy.%I for select to authenticated using ((select energy_access.authorize(''energy.environmental.read'')))', t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['financial_models','financial_assumptions','cash_flow_projections','valuation_snapshots','capital_readiness_assessments','capital_requirements','finance_external_references'] loop
    execute format('grant select on energy.%I to authenticated', t);
    execute format('drop policy if exists seus_finance_read on energy.%I', t);
    execute format('create policy seus_finance_read on energy.%I for select to authenticated using ((select energy_access.authorize(''energy.finance.read'')))', t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['portfolios','portfolio_members','risk_register','scenarios','scenario_assumptions','scenario_results','exposure_snapshots','portfolio_performance_snapshots','executive_decision_cases','decision_external_references'] loop
    execute format('grant select on energy.%I to authenticated', t);
    execute format('drop policy if exists seus_risk_read on energy.%I', t);
    execute format('create policy seus_risk_read on energy.%I for select to authenticated using ((select energy_access.authorize(''energy.risk.read'')))', t);
  end loop;
end $$;

-- No direct write grants to authenticated users in E10.
revoke insert, update, delete, truncate, references, trigger on all tables in schema energy from authenticated;

