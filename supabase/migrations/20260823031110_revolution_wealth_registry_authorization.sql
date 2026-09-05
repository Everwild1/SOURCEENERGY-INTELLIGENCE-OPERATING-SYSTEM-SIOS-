create schema if not exists rw_private;
revoke all on schema rw_private from public, anon, authenticated;

do $$ begin
  create type rw_private.registry_access_role as enum (
    'administrator',
    'investment_reviewer',
    'governance_reviewer',
    'organization_participant',
    'auditor'
  );
exception when duplicate_object then null;
end $$;

create table if not exists rw_private.registry_access_memberships (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  role rw_private.registry_access_role not null,
  organization_id uuid references rw.organizations(id) on delete cascade,
  is_active boolean not null default true,
  effective_at timestamptz not null default now(),
  expires_at timestamptz,
  granted_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((role = 'organization_participant' and organization_id is not null) or role <> 'organization_participant'),
  unique(auth_user_id, role, organization_id)
);

create index if not exists registry_access_user_idx on rw_private.registry_access_memberships(auth_user_id) where is_active;
create index if not exists registry_access_org_idx on rw_private.registry_access_memberships(organization_id, auth_user_id) where is_active and organization_id is not null;

create or replace function rw_private.is_registry_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from rw_private.registry_access_memberships m
    where m.auth_user_id = (select auth.uid())
      and m.role = 'administrator'
      and m.is_active
      and m.effective_at <= now()
      and (m.expires_at is null or m.expires_at > now())
  );
$$;

create or replace function rw_private.can_read_all_registry()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from rw_private.registry_access_memberships m
    where m.auth_user_id = (select auth.uid())
      and m.role in ('administrator','investment_reviewer','governance_reviewer','auditor')
      and m.is_active
      and m.effective_at <= now()
      and (m.expires_at is null or m.expires_at > now())
  );
$$;

create or replace function rw_private.can_review_registry()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from rw_private.registry_access_memberships m
    where m.auth_user_id = (select auth.uid())
      and m.role in ('administrator','investment_reviewer','governance_reviewer')
      and m.is_active
      and m.effective_at <= now()
      and (m.expires_at is null or m.expires_at > now())
  );
$$;

create or replace function rw_private.can_read_organization(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select rw_private.can_read_all_registry()) or exists (
    select 1
    from rw_private.registry_access_memberships m
    where m.auth_user_id = (select auth.uid())
      and m.role = 'organization_participant'
      and m.organization_id = p_organization_id
      and m.is_active
      and m.effective_at <= now()
      and (m.expires_at is null or m.expires_at > now())
  );
$$;

revoke all on all functions in schema rw_private from public, anon;
grant usage on schema rw_private to authenticated;
grant execute on function rw_private.is_registry_admin() to authenticated;
grant execute on function rw_private.can_read_all_registry() to authenticated;
grant execute on function rw_private.can_review_registry() to authenticated;
grant execute on function rw_private.can_read_organization(uuid) to authenticated;

-- Explicitly expose only the six governed registry tables to signed-in users; RLS remains authoritative.
grant usage on schema rw to authenticated;
grant select on rw.funds, rw.fund_vehicles, rw.investment_projects, rw.investment_assets, rw.capital_events, rw.registry_claims to authenticated;
grant insert, update, delete on rw.funds, rw.fund_vehicles, rw.investment_projects, rw.investment_assets, rw.capital_events to authenticated;
grant insert, update on rw.registry_claims to authenticated;

-- Funds: global registry readers can see all; organization participants see funds managed by their organization.
drop policy if exists rw_funds_select on rw.funds;
create policy rw_funds_select on rw.funds for select to authenticated using (
  (select rw_private.can_read_all_registry())
  or (managing_organization_id is not null and (select rw_private.can_read_organization(managing_organization_id)))
);
drop policy if exists rw_funds_write_admin on rw.funds;
create policy rw_funds_write_admin on rw.funds for all to authenticated using ((select rw_private.is_registry_admin())) with check ((select rw_private.is_registry_admin()));

-- Vehicles inherit visibility from their fund.
drop policy if exists rw_fund_vehicles_select on rw.fund_vehicles;
create policy rw_fund_vehicles_select on rw.fund_vehicles for select to authenticated using (
  (select rw_private.can_read_all_registry())
  or exists (
    select 1 from rw.funds f
    where f.id = fund_id
      and f.managing_organization_id is not null
      and (select rw_private.can_read_organization(f.managing_organization_id))
  )
);
drop policy if exists rw_fund_vehicles_write_admin on rw.fund_vehicles;
create policy rw_fund_vehicles_write_admin on rw.fund_vehicles for all to authenticated using ((select rw_private.is_registry_admin())) with check ((select rw_private.is_registry_admin()));

-- Projects are scoped directly by organization_id, with global registry readers seeing all.
drop policy if exists rw_investment_projects_select on rw.investment_projects;
create policy rw_investment_projects_select on rw.investment_projects for select to authenticated using (
  (select rw_private.can_read_all_registry())
  or (organization_id is not null and (select rw_private.can_read_organization(organization_id)))
);
drop policy if exists rw_investment_projects_write_admin on rw.investment_projects;
create policy rw_investment_projects_write_admin on rw.investment_projects for all to authenticated using ((select rw_private.is_registry_admin())) with check ((select rw_private.is_registry_admin()));

-- Assets are visible to their owner organization or through a participant-visible project.
drop policy if exists rw_investment_assets_select on rw.investment_assets;
create policy rw_investment_assets_select on rw.investment_assets for select to authenticated using (
  (select rw_private.can_read_all_registry())
  or (owner_organization_id is not null and (select rw_private.can_read_organization(owner_organization_id)))
  or exists (
    select 1 from rw.investment_projects p
    where p.id = project_id
      and p.organization_id is not null
      and (select rw_private.can_read_organization(p.organization_id))
  )
);
drop policy if exists rw_investment_assets_write_admin on rw.investment_assets;
create policy rw_investment_assets_write_admin on rw.investment_assets for all to authenticated using ((select rw_private.is_registry_admin())) with check ((select rw_private.is_registry_admin()));

-- Capital events are read-only to non-admin roles and scoped to organization/project relationships.
drop policy if exists rw_capital_events_select on rw.capital_events;
create policy rw_capital_events_select on rw.capital_events for select to authenticated using (
  (select rw_private.can_read_all_registry())
  or (organization_id is not null and (select rw_private.can_read_organization(organization_id)))
  or exists (
    select 1 from rw.investment_projects p
    where p.id = project_id
      and p.organization_id is not null
      and (select rw_private.can_read_organization(p.organization_id))
  )
);
drop policy if exists rw_capital_events_write_admin on rw.capital_events;
create policy rw_capital_events_write_admin on rw.capital_events for all to authenticated using ((select rw_private.is_registry_admin())) with check ((select rw_private.is_registry_admin()));

-- Claims are globally readable to reviewer/auditor roles. Admins and reviewers may create/update claims; deletion remains admin-only.
drop policy if exists rw_registry_claims_select on rw.registry_claims;
create policy rw_registry_claims_select on rw.registry_claims for select to authenticated using ((select rw_private.can_read_all_registry()));
drop policy if exists rw_registry_claims_insert_review on rw.registry_claims;
create policy rw_registry_claims_insert_review on rw.registry_claims for insert to authenticated with check ((select rw_private.can_review_registry()));
drop policy if exists rw_registry_claims_update_review on rw.registry_claims;
create policy rw_registry_claims_update_review on rw.registry_claims for update to authenticated using ((select rw_private.can_review_registry())) with check ((select rw_private.can_review_registry()));
drop policy if exists rw_registry_claims_delete_admin on rw.registry_claims;
create policy rw_registry_claims_delete_admin on rw.registry_claims for delete to authenticated using ((select rw_private.is_registry_admin()));

-- Complete FK index coverage for the new capital registry.
create index if not exists fund_vehicles_parent_idx on rw.fund_vehicles(parent_vehicle_id) where parent_vehicle_id is not null;
create index if not exists investment_projects_vehicle_idx on rw.investment_projects(vehicle_id) where vehicle_id is not null;
create index if not exists investment_assets_fund_idx on rw.investment_assets(fund_id) where fund_id is not null;
create index if not exists investment_assets_vehicle_idx on rw.investment_assets(vehicle_id) where vehicle_id is not null;
create index if not exists investment_assets_owner_org_idx on rw.investment_assets(owner_organization_id) where owner_organization_id is not null;
create index if not exists capital_events_vehicle_idx on rw.capital_events(vehicle_id) where vehicle_id is not null;
create index if not exists capital_events_asset_idx on rw.capital_events(asset_id) where asset_id is not null;
create index if not exists capital_events_org_idx on rw.capital_events(organization_id) where organization_id is not null;
create index if not exists capital_events_capital_request_idx on rw.capital_events(capital_request_id) where capital_request_id is not null;

