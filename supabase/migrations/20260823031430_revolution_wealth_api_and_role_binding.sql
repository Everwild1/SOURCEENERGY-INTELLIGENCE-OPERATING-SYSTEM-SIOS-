-- Service-operated role binding helper. Kept in a non-exposed schema.
create or replace function rw_private.grant_registry_access(
  p_auth_user_id uuid,
  p_role rw_private.registry_access_role,
  p_organization_id uuid default null,
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if current_user not in ('postgres','service_role') then
    raise exception 'registry access grants require service role';
  end if;

  if not exists (select 1 from auth.users u where u.id = p_auth_user_id) then
    raise exception 'auth user does not exist';
  end if;

  if p_role = 'organization_participant' and p_organization_id is null then
    raise exception 'organization participant requires organization_id';
  end if;

  if p_organization_id is not null and not exists (select 1 from rw.organizations o where o.id = p_organization_id) then
    raise exception 'organization does not exist';
  end if;

  insert into rw_private.registry_access_memberships (
    auth_user_id, role, organization_id, is_active, effective_at, expires_at, granted_by
  ) values (
    p_auth_user_id, p_role, p_organization_id, true, now(), p_expires_at, auth.uid()
  )
  on conflict (auth_user_id, role, organization_id)
  do update set
    is_active = true,
    effective_at = now(),
    expires_at = excluded.expires_at,
    granted_by = auth.uid(),
    updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function rw_private.grant_registry_access(uuid, rw_private.registry_access_role, uuid, timestamptz) from public, anon, authenticated;
grant execute on function rw_private.grant_registry_access(uuid, rw_private.registry_access_role, uuid, timestamptz) to service_role;

create or replace function rw_private.revoke_registry_access(p_membership_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_user not in ('postgres','service_role') then
    raise exception 'registry access revocation requires service role';
  end if;

  update rw_private.registry_access_memberships
  set is_active = false, updated_at = now()
  where id = p_membership_id;

  return found;
end;
$$;

revoke all on function rw_private.revoke_registry_access(uuid) from public, anon, authenticated;
grant execute on function rw_private.revoke_registry_access(uuid) to service_role;

-- First governed read models. Security-invoker ensures underlying RLS remains authoritative.
create or replace view rw.registry_fund_overview
with (security_invoker = true)
as
select
  f.id,
  f.registry_code,
  f.legal_name,
  f.display_name,
  f.fund_type,
  f.jurisdiction,
  f.stated_target_amount,
  f.currency_code,
  f.status,
  f.verification_status,
  f.effective_date,
  f.managing_organization_id,
  count(distinct v.id) as vehicle_count,
  count(distinct p.id) as project_count,
  count(distinct a.id) as asset_count,
  f.created_at,
  f.updated_at
from rw.funds f
left join rw.fund_vehicles v on v.fund_id = f.id
left join rw.investment_projects p on p.fund_id = f.id
left join rw.investment_assets a on a.fund_id = f.id
group by f.id;

create or replace view rw.registry_capital_activity
with (security_invoker = true)
as
select
  ce.id,
  ce.registry_code,
  ce.event_type,
  ce.amount,
  ce.currency_code,
  ce.occurred_at,
  ce.verification_status,
  ce.fund_id,
  f.registry_code as fund_registry_code,
  f.display_name as fund_name,
  ce.vehicle_id,
  ce.project_id,
  p.registry_code as project_registry_code,
  p.name as project_name,
  ce.asset_id,
  ce.organization_id,
  ce.external_reference,
  ce.created_at
from rw.capital_events ce
join rw.funds f on f.id = ce.fund_id
left join rw.investment_projects p on p.id = ce.project_id;

create or replace view rw.registry_claim_overview
with (security_invoker = true)
as
select
  c.id,
  c.registry_code,
  c.subject_type,
  c.subject_id,
  c.claim_key,
  c.claim_value,
  c.status,
  c.jurisdiction,
  c.effective_date,
  c.expires_at,
  c.approved_at,
  c.created_at,
  c.updated_at
from rw.registry_claims c;

revoke all on rw.registry_fund_overview, rw.registry_capital_activity, rw.registry_claim_overview from public, anon;
grant select on rw.registry_fund_overview, rw.registry_capital_activity, rw.registry_claim_overview to authenticated, service_role;

