alter table wim.opportunities
  add column if not exists provenance_reference text,
  add column if not exists matched_organization_id uuid references wim.organizations(id) on delete restrict,
  add column if not exists matched_at timestamptz,
  add column if not exists reviewed_at timestamptz,
  add column if not exists closed_reason text;

create index if not exists idx_wim_opportunities_status on wim.opportunities(status);
create index if not exists idx_wim_opportunities_type on wim.opportunities(opportunity_type);
create index if not exists idx_wim_opportunities_org on wim.opportunities(originating_organization_id);
create index if not exists idx_wim_opportunities_market on wim.opportunities(market_id);
create index if not exists idx_wim_opportunities_cluster on wim.opportunities(cluster_id, subcluster_id);

create table if not exists wim.opportunity_responses (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references wim.opportunities(id) on delete cascade,
  responding_organization_id uuid not null references wim.organizations(id) on delete restrict,
  response_type text not null check (response_type in ('interest','offer','proposal','bid','partnership','information')),
  status text not null default 'submitted' check (status in ('submitted','under_review','accepted','rejected','withdrawn','expired','restricted')),
  response_reference text not null,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(opportunity_id, responding_organization_id, response_reference)
);

alter table wim.opportunity_responses enable row level security;
revoke all on wim.opportunity_responses from anon, authenticated;
grant all on wim.opportunity_responses to service_role;

create or replace function wim.enforce_opportunity_state()
returns trigger
language plpgsql
as $$
declare
  org_status text;
  org_verification text;
begin
  if new.originating_organization_id is not null then
    select economic_status, verification_status into org_status, org_verification
    from wim.organizations where id = new.originating_organization_id;
  end if;

  if new.status in ('open','matched','under_review') then
    if new.originating_organization_id is null then
      raise exception 'active opportunity requires originating organization';
    end if;
    if org_status <> 'active' or org_verification <> 'verified' then
      raise exception 'originating organization must be verified and active';
    end if;
    if new.provenance_reference is null or btrim(new.provenance_reference) = '' then
      raise exception 'active opportunity requires provenance reference';
    end if;
    if new.opens_at is null then new.opens_at := now(); end if;
  end if;

  if new.closes_at is not null and new.opens_at is not null and new.closes_at <= new.opens_at then
    raise exception 'opportunity closes_at must be after opens_at';
  end if;

  if new.status = 'matched' then
    if new.matched_organization_id is null then
      raise exception 'matched opportunity requires matched organization';
    end if;
    if new.matched_organization_id = new.originating_organization_id then
      raise exception 'opportunity cannot match to originating organization';
    end if;
    if new.matched_at is null then new.matched_at := now(); end if;
  end if;

  if new.status in ('closed','cancelled','restricted') and new.closed_reason is null then
    new.closed_reason := lower(new.status);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_wim_opportunity_state on wim.opportunities;
create trigger trg_wim_opportunity_state
before insert or update on wim.opportunities
for each row execute function wim.enforce_opportunity_state();

create or replace function wim.enforce_opportunity_response()
returns trigger
language plpgsql
as $$
declare
  opp_status text;
  origin_org uuid;
  resp_status text;
  resp_verification text;
begin
  select status, originating_organization_id into opp_status, origin_org
  from wim.opportunities where id = new.opportunity_id;
  select economic_status, verification_status into resp_status, resp_verification
  from wim.organizations where id = new.responding_organization_id;

  if opp_status <> 'open' then
    raise exception 'responses are only accepted for open opportunities';
  end if;
  if new.responding_organization_id = origin_org then
    raise exception 'originating organization cannot respond to its own opportunity';
  end if;
  if resp_status <> 'active' or resp_verification <> 'verified' then
    raise exception 'responding organization must be verified and active';
  end if;
  if btrim(new.response_reference) = '' then
    raise exception 'response reference is required';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_wim_opportunity_response on wim.opportunity_responses;
create trigger trg_wim_opportunity_response
before insert or update on wim.opportunity_responses
for each row execute function wim.enforce_opportunity_response();

create or replace function wim.restrict_opportunities_for_organization()
returns trigger
language plpgsql
as $$
begin
  if new.economic_status in ('restricted','suspended','inactive') or new.verification_status in ('restricted','suspended') then
    update wim.opportunities
      set status = 'restricted', closed_reason = 'organization_restricted', updated_at = now()
      where originating_organization_id = new.id and status in ('open','matched','under_review');
    update wim.opportunity_responses
      set status = 'restricted', updated_at = now()
      where responding_organization_id = new.id and status in ('submitted','under_review','accepted');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_wim_org_restrict_opportunities on wim.organizations;
create trigger trg_wim_org_restrict_opportunities
after update of economic_status, verification_status on wim.organizations
for each row when (
  old.economic_status is distinct from new.economic_status
  or old.verification_status is distinct from new.verification_status
)
execute function wim.restrict_opportunities_for_organization();

comment on table wim.opportunity_responses is 'Non-binding commercial responses to WIM opportunities. Acceptance does not create a transaction, settlement, investment authorization, or legal award by itself.';
