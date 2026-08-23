create schema if not exists rw_private;
revoke all on schema rw_private from public, anon, authenticated;

do $$ begin
  create type rw_private.registry_access_role as enum ('administrator','investment_reviewer','governance_reviewer','organization_participant','auditor');
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

create or replace function rw_private.is_registry_admin() returns boolean language sql stable security definer set search_path = '' as $$
select exists (select 1 from rw_private.registry_access_memberships m where m.auth_user_id=(select auth.uid()) and m.role='administrator' and m.is_active and m.effective_at<=now() and (m.expires_at is null or m.expires_at>now())); $$;
create or replace function rw_private.can_read_all_registry() returns boolean language sql stable security definer set search_path = '' as $$
select exists (select 1 from rw_private.registry_access_memberships m where m.auth_user_id=(select auth.uid()) and m.role in ('administrator','investment_reviewer','governance_reviewer','auditor') and m.is_active and m.effective_at<=now() and (m.expires_at is null or m.expires_at>now())); $$;
create or replace function rw_private.can_review_registry() returns boolean language sql stable security definer set search_path = '' as $$
select exists (select 1 from rw_private.registry_access_memberships m where m.auth_user_id=(select auth.uid()) and m.role in ('administrator','investment_reviewer','governance_reviewer') and m.is_active and m.effective_at<=now() and (m.expires_at is null or m.expires_at>now())); $$;
create or replace function rw_private.can_read_organization(p_organization_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
select (select rw_private.can_read_all_registry()) or exists (select 1 from rw_private.registry_access_memberships m where m.auth_user_id=(select auth.uid()) and m.role='organization_participant' and m.organization_id=p_organization_id and m.is_active and m.effective_at<=now() and (m.expires_at is null or m.expires_at>now())); $$;

revoke all on all functions in schema rw_private from public, anon;
grant usage on schema rw_private to authenticated;
grant execute on function rw_private.is_registry_admin() to authenticated;
grant execute on function rw_private.can_read_all_registry() to authenticated;
grant execute on function rw_private.can_review_registry() to authenticated;
grant execute on function rw_private.can_read_organization(uuid) to authenticated;

grant usage on schema rw to authenticated;
grant select on rw.funds,rw.fund_vehicles,rw.investment_projects,rw.investment_assets,rw.capital_events,rw.registry_claims to authenticated;
grant insert,update,delete on rw.funds,rw.fund_vehicles,rw.investment_projects,rw.investment_assets,rw.capital_events to authenticated;
grant insert,update on rw.registry_claims to authenticated;

create policy rw_funds_select on rw.funds for select to authenticated using ((select rw_private.can_read_all_registry()) or (managing_organization_id is not null and (select rw_private.can_read_organization(managing_organization_id))));
create policy rw_funds_write_admin on rw.funds for all to authenticated using ((select rw_private.is_registry_admin())) with check ((select rw_private.is_registry_admin()));
create policy rw_fund_vehicles_select on rw.fund_vehicles for select to authenticated using ((select rw_private.can_read_all_registry()) or exists (select 1 from rw.funds f where f.id=fund_id and f.managing_organization_id is not null and (select rw_private.can_read_organization(f.managing_organization_id))));
create policy rw_fund_vehicles_write_admin on rw.fund_vehicles for all to authenticated using ((select rw_private.is_registry_admin())) with check ((select rw_private.is_registry_admin()));
create policy rw_investment_projects_select on rw.investment_projects for select to authenticated using ((select rw_private.can_read_all_registry()) or (organization_id is not null and (select rw_private.can_read_organization(organization_id))));
create policy rw_investment_projects_write_admin on rw.investment_projects for all to authenticated using ((select rw_private.is_registry_admin())) with check ((select rw_private.is_registry_admin()));
create policy rw_investment_assets_select on rw.investment_assets for select to authenticated using ((select rw_private.can_read_all_registry()) or (owner_organization_id is not null and (select rw_private.can_read_organization(owner_organization_id))) or exists (select 1 from rw.investment_projects p where p.id=project_id and p.organization_id is not null and (select rw_private.can_read_organization(p.organization_id))));
create policy rw_investment_assets_write_admin on rw.investment_assets for all to authenticated using ((select rw_private.is_registry_admin())) with check ((select rw_private.is_registry_admin()));
create policy rw_capital_events_select on rw.capital_events for select to authenticated using ((select rw_private.can_read_all_registry()) or (organization_id is not null and (select rw_private.can_read_organization(organization_id))) or exists (select 1 from rw.investment_projects p where p.id=project_id and p.organization_id is not null and (select rw_private.can_read_organization(p.organization_id))));
create policy rw_capital_events_write_admin on rw.capital_events for all to authenticated using ((select rw_private.is_registry_admin())) with check ((select rw_private.is_registry_admin()));
create policy rw_registry_claims_select on rw.registry_claims for select to authenticated using ((select rw_private.can_read_all_registry()));
create policy rw_registry_claims_insert_review on rw.registry_claims for insert to authenticated with check ((select rw_private.can_review_registry()));
create policy rw_registry_claims_update_review on rw.registry_claims for update to authenticated using ((select rw_private.can_review_registry())) with check ((select rw_private.can_review_registry()));
create policy rw_registry_claims_delete_admin on rw.registry_claims for delete to authenticated using ((select rw_private.is_registry_admin()));

create or replace function rw_private.grant_registry_access(p_auth_user_id uuid,p_role rw_private.registry_access_role,p_organization_id uuid default null,p_expires_at timestamptz default null) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; begin
if current_user not in ('postgres','service_role') then raise exception 'registry access grants require service role'; end if;
if not exists(select 1 from auth.users where id=p_auth_user_id) then raise exception 'auth user does not exist'; end if;
if p_role='organization_participant' and p_organization_id is null then raise exception 'organization participant requires organization_id'; end if;
if p_organization_id is not null and not exists(select 1 from rw.organizations where id=p_organization_id) then raise exception 'organization does not exist'; end if;
insert into rw_private.registry_access_memberships(auth_user_id,role,organization_id,is_active,effective_at,expires_at,granted_by) values(p_auth_user_id,p_role,p_organization_id,true,now(),p_expires_at,auth.uid()) on conflict(auth_user_id,role,organization_id) do update set is_active=true,effective_at=now(),expires_at=excluded.expires_at,granted_by=auth.uid(),updated_at=now() returning id into v_id; return v_id; end; $$;
revoke all on function rw_private.grant_registry_access(uuid,rw_private.registry_access_role,uuid,timestamptz) from public,anon,authenticated;
grant execute on function rw_private.grant_registry_access(uuid,rw_private.registry_access_role,uuid,timestamptz) to service_role;

create or replace function rw_private.revoke_registry_access(p_membership_id uuid) returns boolean language plpgsql security definer set search_path='' as $$ begin
if current_user not in ('postgres','service_role') then raise exception 'registry access revocation requires service role'; end if;
update rw_private.registry_access_memberships set is_active=false,updated_at=now() where id=p_membership_id; return found; end; $$;
revoke all on function rw_private.revoke_registry_access(uuid) from public,anon,authenticated;
grant execute on function rw_private.revoke_registry_access(uuid) to service_role;

create or replace view rw.registry_fund_overview with(security_invoker=true) as select f.id,f.registry_code,f.legal_name,f.display_name,f.fund_type,f.jurisdiction,f.stated_target_amount,f.currency_code,f.status,f.verification_status,f.effective_date,f.managing_organization_id,count(distinct v.id) vehicle_count,count(distinct p.id) project_count,count(distinct a.id) asset_count,f.created_at,f.updated_at from rw.funds f left join rw.fund_vehicles v on v.fund_id=f.id left join rw.investment_projects p on p.fund_id=f.id left join rw.investment_assets a on a.fund_id=f.id group by f.id;
create or replace view rw.registry_capital_activity with(security_invoker=true) as select ce.id,ce.registry_code,ce.event_type,ce.amount,ce.currency_code,ce.occurred_at,ce.verification_status,ce.fund_id,f.registry_code fund_registry_code,f.display_name fund_name,ce.vehicle_id,ce.project_id,p.registry_code project_registry_code,p.name project_name,ce.asset_id,ce.organization_id,ce.external_reference,ce.created_at from rw.capital_events ce join rw.funds f on f.id=ce.fund_id left join rw.investment_projects p on p.id=ce.project_id;
create or replace view rw.registry_claim_overview with(security_invoker=true) as select id,registry_code,subject_type,subject_id,claim_key,claim_value,status,jurisdiction,effective_date,expires_at,approved_at,created_at,updated_at from rw.registry_claims;
revoke all on rw.registry_fund_overview,rw.registry_capital_activity,rw.registry_claim_overview from public,anon;
grant select on rw.registry_fund_overview,rw.registry_capital_activity,rw.registry_claim_overview to authenticated,service_role;
