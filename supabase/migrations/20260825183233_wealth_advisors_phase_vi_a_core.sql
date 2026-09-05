create schema if not exists wealth_advisors;
create schema if not exists wealth_security;

revoke all on schema wealth_security from public, anon, authenticated;
grant usage on schema wealth_advisors to authenticated, service_role;

create table if not exists wealth_advisors.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('client','advisor','senior_advisor','vp_wealth_advisors','compliance','executive','auditor')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table if not exists wealth_advisors.clients (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  legal_name text not null,
  preferred_name text,
  email text,
  phone text,
  client_type text not null default 'individual' check (client_type in ('individual','family','entrepreneur','enterprise','real_estate','community','advanced_wealth')),
  geographic_market text,
  status text not null default 'discover' check (status in ('lead','discover','assess','plan','prepare','ready','referred','execution_pending','outcome_recorded','grow','preserve','inactive')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wealth_advisors.advisor_assignments (
  client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  advisor_user_id uuid not null references auth.users(id) on delete cascade,
  assignment_role text not null default 'primary' check (assignment_role in ('primary','secondary','supervisor')),
  active boolean not null default true,
  assigned_at timestamptz not null default now(),
  primary key (client_id, advisor_user_id, assignment_role)
);

create table if not exists wealth_advisors.households (
  id uuid primary key default gen_random_uuid(),
  primary_client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  household_name text,
  household_size integer check (household_size is null or household_size >= 1),
  income_band text,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wealth_advisors.enterprises (
  id uuid primary key default gen_random_uuid(),
  primary_client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  legal_name text not null,
  trade_name text,
  entity_type text,
  jurisdiction text,
  industry text,
  business_stage text,
  revenue_band text,
  capital_requirement numeric(18,2) check (capital_requirement is null or capital_requirement >= 0),
  status text not null default 'active' check (status in ('active','inactive','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wealth_advisors.client_objectives (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  objective_type text not null,
  current_state text,
  target_state text,
  priority smallint check (priority is null or priority between 1 and 5),
  target_date date,
  status text not null default 'active' check (status in ('active','completed','paused','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wealth_advisors.assessments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  advisor_user_id uuid references auth.users(id) on delete set null,
  assessment_type text not null default 'financial_readiness',
  assessment_date timestamptz not null default now(),
  income_revenue_stability smallint not null check (income_revenue_stability between 0 and 4),
  cash_flow_management smallint not null check (cash_flow_management between 0 and 4),
  credit_readiness smallint not null check (credit_readiness between 0 and 4),
  debt_position smallint not null check (debt_position between 0 and 4),
  documentation_readiness smallint not null check (documentation_readiness between 0 and 4),
  asset_position smallint not null check (asset_position between 0 and 4),
  wealth_objective smallint not null check (wealth_objective between 0 and 4),
  total_score smallint generated always as (income_revenue_stability + cash_flow_management + credit_readiness + debt_position + documentation_readiness + asset_position + wealth_objective) stored,
  classification text generated always as (
    case
      when (income_revenue_stability + cash_flow_management + credit_readiness + debt_position + documentation_readiness + asset_position + wealth_objective) <= 7 then 'FRI-1 Foundation'
      when (income_revenue_stability + cash_flow_management + credit_readiness + debt_position + documentation_readiness + asset_position + wealth_objective) <= 14 then 'FRI-2 Developing'
      when (income_revenue_stability + cash_flow_management + credit_readiness + debt_position + documentation_readiness + asset_position + wealth_objective) <= 20 then 'FRI-3 Ready'
      when (income_revenue_stability + cash_flow_management + credit_readiness + debt_position + documentation_readiness + asset_position + wealth_objective) <= 25 then 'FRI-4 Capital Ready'
      else 'FRI-5 Wealth Stewardship'
    end
  ) stored,
  advisor_notes text,
  status text not null default 'completed' check (status in ('draft','completed','superseded')),
  created_at timestamptz not null default now()
);

create table if not exists wealth_advisors.wealth_roadmaps (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  advisor_user_id uuid references auth.users(id) on delete set null,
  primary_pathway text not null check (primary_pathway in ('individuals_families','entrepreneurs_enterprises','real_estate_asset_formation','community_intergenerational_wealth')),
  current_position text,
  target_position text,
  readiness_gaps text,
  thirty_day_objective text,
  ninety_day_objective text,
  twelve_month_objective text,
  status text not null default 'active' check (status in ('draft','active','completed','paused','superseded')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wealth_advisors.roadmap_actions (
  id uuid primary key default gen_random_uuid(),
  roadmap_id uuid not null references wealth_advisors.wealth_roadmaps(id) on delete cascade,
  action text not null,
  owner_user_id uuid references auth.users(id) on delete set null,
  due_date date,
  status text not null default 'required' check (status in ('required','in_progress','completed','verified','cancelled')),
  completion_date date,
  evidence_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wealth_advisors.partners (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null,
  partner_type text not null check (partner_type in ('bank','commercial_lender','cdfi','securities_professional','investment_professional','attorney','cpa','tax_professional','trust_professional','insurance_professional','mortgage_professional','real_estate_professional','other')),
  jurisdiction text,
  ecosystem_affiliation text,
  status text not null default 'reviewing' check (status in ('unverified','reviewing','verified','restricted','expired','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wealth_advisors.authority_records (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references wealth_advisors.partners(id) on delete cascade,
  authority_category text not null,
  license_registration_identifier text,
  regulator_credentialing_org text,
  verification_source text,
  verification_date date,
  permitted_activities text,
  restrictions text,
  review_date date,
  status text not null default 'unverified' check (status in ('unverified','reviewing','verified','restricted','expired','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wealth_advisors.capital_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  enterprise_id uuid references wealth_advisors.enterprises(id) on delete set null,
  amount_requested numeric(18,2) not null check (amount_requested > 0),
  currency char(3) not null default 'USD',
  purpose text not null,
  use_of_proceeds text,
  requested_structure text,
  proposed_repayment_source text,
  collateral_information text,
  readiness_status text not null default 'prepare' check (readiness_status in ('prepare','review','refer')),
  assigned_advisor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wealth_advisors.capital_events (
  id uuid primary key default gen_random_uuid(),
  capital_request_id uuid not null references wealth_advisors.capital_requests(id) on delete cascade,
  event_type text not null check (event_type in ('requested','prepared','referred','under_review','approved','declined','documentation','closed','funded')),
  event_amount numeric(18,2) check (event_amount is null or event_amount >= 0),
  institution_partner_id uuid references wealth_advisors.partners(id) on delete set null,
  evidence_reference text,
  recorded_by uuid references auth.users(id) on delete set null,
  verified_by uuid references auth.users(id) on delete set null,
  event_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists wealth_advisors.consents (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  consent_type text not null check (consent_type in ('privacy','information_sharing','referral_authorization','program_participation','other')),
  version text not null,
  accepted_at timestamptz not null default now(),
  expires_at timestamptz,
  withdrawn_at timestamptz,
  evidence_reference text,
  created_at timestamptz not null default now()
);

create table if not exists wealth_advisors.referrals (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  partner_id uuid not null references wealth_advisors.partners(id) on delete restrict,
  authority_record_id uuid references wealth_advisors.authority_records(id) on delete set null,
  advisor_user_id uuid references auth.users(id) on delete set null,
  consent_id uuid references wealth_advisors.consents(id) on delete set null,
  referral_category text not null,
  reason text not null,
  status text not null default 'draft' check (status in ('draft','approved_internally','sent','acknowledged','under_review','additional_information','accepted_approved','declined','closed')),
  compensation_relationship_disclosed boolean,
  date_referred timestamptz,
  follow_up_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wealth_advisors.client_outcomes (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references wealth_advisors.clients(id) on delete cascade,
  referral_id uuid references wealth_advisors.referrals(id) on delete set null,
  capital_request_id uuid references wealth_advisors.capital_requests(id) on delete set null,
  outcome_type text not null check (outcome_type in ('financing','home_purchase','property_acquisition','business_launch','business_expansion','productive_asset_acquisition','professional_planning_engagement','debt_improvement','financial_reserve_milestone','succession_milestone','other')),
  outcome_value numeric(18,2),
  currency char(3),
  description text,
  evidence_reference text,
  verified boolean not null default false,
  verified_by uuid references auth.users(id) on delete set null,
  outcome_date date,
  created_at timestamptz not null default now()
);

create table if not exists wealth_advisors.compliance_events (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references wealth_advisors.clients(id) on delete set null,
  advisor_user_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  severity text not null default 'medium' check (severity in ('low','medium','high','critical')),
  description text not null,
  immediate_action text,
  escalation text,
  resolution text,
  evidence_reference text,
  status text not null default 'open' check (status in ('open','investigating','resolved','closed')),
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_wa_clients_auth_user on wealth_advisors.clients(auth_user_id);
create index if not exists idx_wa_clients_status on wealth_advisors.clients(status);
create index if not exists idx_wa_assignments_advisor on wealth_advisors.advisor_assignments(advisor_user_id, active);
create index if not exists idx_wa_households_client on wealth_advisors.households(primary_client_id);
create index if not exists idx_wa_enterprises_client on wealth_advisors.enterprises(primary_client_id);
create index if not exists idx_wa_objectives_client on wealth_advisors.client_objectives(client_id);
create index if not exists idx_wa_assessments_client_date on wealth_advisors.assessments(client_id, assessment_date desc);
create index if not exists idx_wa_roadmaps_client on wealth_advisors.wealth_roadmaps(client_id);
create index if not exists idx_wa_roadmap_actions_roadmap on wealth_advisors.roadmap_actions(roadmap_id);
create index if not exists idx_wa_authority_partner on wealth_advisors.authority_records(partner_id, status);
create index if not exists idx_wa_capital_client on wealth_advisors.capital_requests(client_id);
create index if not exists idx_wa_capital_events_request on wealth_advisors.capital_events(capital_request_id, event_at);
create index if not exists idx_wa_consents_client on wealth_advisors.consents(client_id, consent_type);
create index if not exists idx_wa_referrals_client on wealth_advisors.referrals(client_id, status);
create index if not exists idx_wa_outcomes_client on wealth_advisors.client_outcomes(client_id, outcome_date);
create index if not exists idx_wa_compliance_client on wealth_advisors.compliance_events(client_id, status);

create or replace function wealth_security.has_staff_role(required_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1
    from wealth_advisors.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.active
      and ur.role = any(required_roles)
  );
$$;

create or replace function wealth_security.can_access_client(target_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null and (
    exists (
      select 1 from wealth_advisors.clients c
      where c.id = target_client_id and c.auth_user_id = (select auth.uid())
    )
    or exists (
      select 1 from wealth_advisors.advisor_assignments aa
      where aa.client_id = target_client_id and aa.advisor_user_id = (select auth.uid()) and aa.active
    )
    or exists (
      select 1 from wealth_advisors.user_roles ur
      where ur.user_id = (select auth.uid()) and ur.active
        and ur.role in ('senior_advisor','vp_wealth_advisors','compliance','executive','auditor')
    )
  );
$$;

revoke all on function wealth_security.has_staff_role(text[]) from public, anon;
revoke all on function wealth_security.can_access_client(uuid) from public, anon;
grant execute on function wealth_security.has_staff_role(text[]) to authenticated, service_role;
grant execute on function wealth_security.can_access_client(uuid) to authenticated, service_role;

alter table wealth_advisors.user_roles enable row level security;
alter table wealth_advisors.clients enable row level security;
alter table wealth_advisors.advisor_assignments enable row level security;
alter table wealth_advisors.households enable row level security;
alter table wealth_advisors.enterprises enable row level security;
alter table wealth_advisors.client_objectives enable row level security;
alter table wealth_advisors.assessments enable row level security;
alter table wealth_advisors.wealth_roadmaps enable row level security;
alter table wealth_advisors.roadmap_actions enable row level security;
alter table wealth_advisors.partners enable row level security;
alter table wealth_advisors.authority_records enable row level security;
alter table wealth_advisors.capital_requests enable row level security;
alter table wealth_advisors.capital_events enable row level security;
alter table wealth_advisors.consents enable row level security;
alter table wealth_advisors.referrals enable row level security;
alter table wealth_advisors.client_outcomes enable row level security;
alter table wealth_advisors.compliance_events enable row level security;

create policy wa_user_roles_self_select on wealth_advisors.user_roles for select to authenticated using (user_id = (select auth.uid()) or (select wealth_security.has_staff_role(array['vp_wealth_advisors','compliance','executive'])));
create policy wa_user_roles_admin_all on wealth_advisors.user_roles for all to authenticated using ((select wealth_security.has_staff_role(array['vp_wealth_advisors','executive']))) with check ((select wealth_security.has_staff_role(array['vp_wealth_advisors','executive'])));

create policy wa_clients_select on wealth_advisors.clients for select to authenticated using ((select wealth_security.can_access_client(id)));
create policy wa_clients_insert on wealth_advisors.clients for insert to authenticated with check (auth_user_id = (select auth.uid()) or (select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));
create policy wa_clients_staff_update on wealth_advisors.clients for update to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_assignments_select on wealth_advisors.advisor_assignments for select to authenticated using ((select wealth_security.can_access_client(client_id)));
create policy wa_assignments_manage on wealth_advisors.advisor_assignments for all to authenticated using ((select wealth_security.has_staff_role(array['senior_advisor','vp_wealth_advisors','executive']))) with check ((select wealth_security.has_staff_role(array['senior_advisor','vp_wealth_advisors','executive'])));

create policy wa_households_select on wealth_advisors.households for select to authenticated using ((select wealth_security.can_access_client(primary_client_id)));
create policy wa_households_staff_write on wealth_advisors.households for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_enterprises_select on wealth_advisors.enterprises for select to authenticated using ((select wealth_security.can_access_client(primary_client_id)));
create policy wa_enterprises_staff_write on wealth_advisors.enterprises for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_objectives_select on wealth_advisors.client_objectives for select to authenticated using ((select wealth_security.can_access_client(client_id)));
create policy wa_objectives_staff_write on wealth_advisors.client_objectives for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_assessments_select on wealth_advisors.assessments for select to authenticated using ((select wealth_security.can_access_client(client_id)));
create policy wa_assessments_staff_write on wealth_advisors.assessments for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_roadmaps_select on wealth_advisors.wealth_roadmaps for select to authenticated using ((select wealth_security.can_access_client(client_id)));
create policy wa_roadmaps_staff_write on wealth_advisors.wealth_roadmaps for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_actions_select on wealth_advisors.roadmap_actions for select to authenticated using (exists (select 1 from wealth_advisors.wealth_roadmaps wr where wr.id = roadmap_id and (select wealth_security.can_access_client(wr.client_id))));
create policy wa_actions_staff_write on wealth_advisors.roadmap_actions for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_partners_staff_select on wealth_advisors.partners for select to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive','auditor'])));
create policy wa_partners_admin_write on wealth_advisors.partners for all to authenticated using ((select wealth_security.has_staff_role(array['vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['vp_wealth_advisors','compliance','executive'])));

create policy wa_authority_staff_select on wealth_advisors.authority_records for select to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive','auditor'])));
create policy wa_authority_admin_write on wealth_advisors.authority_records for all to authenticated using ((select wealth_security.has_staff_role(array['vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['vp_wealth_advisors','compliance','executive'])));

create policy wa_capital_select on wealth_advisors.capital_requests for select to authenticated using ((select wealth_security.can_access_client(client_id)));
create policy wa_capital_staff_write on wealth_advisors.capital_requests for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_capital_events_select on wealth_advisors.capital_events for select to authenticated using (exists (select 1 from wealth_advisors.capital_requests cr where cr.id = capital_request_id and (select wealth_security.can_access_client(cr.client_id))));
create policy wa_capital_events_staff_write on wealth_advisors.capital_events for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_consents_select on wealth_advisors.consents for select to authenticated using ((select wealth_security.can_access_client(client_id)));
create policy wa_consents_insert on wealth_advisors.consents for insert to authenticated with check ((select wealth_security.can_access_client(client_id)));
create policy wa_consents_staff_update on wealth_advisors.consents for update to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_referrals_select on wealth_advisors.referrals for select to authenticated using ((select wealth_security.can_access_client(client_id)));
create policy wa_referrals_staff_write on wealth_advisors.referrals for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_outcomes_select on wealth_advisors.client_outcomes for select to authenticated using ((select wealth_security.can_access_client(client_id)));
create policy wa_outcomes_staff_write on wealth_advisors.client_outcomes for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

create policy wa_compliance_select on wealth_advisors.compliance_events for select to authenticated using ((client_id is not null and (select wealth_security.can_access_client(client_id))) or (select wealth_security.has_staff_role(array['compliance','vp_wealth_advisors','executive','auditor'])));
create policy wa_compliance_write on wealth_advisors.compliance_events for all to authenticated using ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive']))) with check ((select wealth_security.has_staff_role(array['advisor','senior_advisor','vp_wealth_advisors','compliance','executive'])));

grant select on all tables in schema wealth_advisors to authenticated;
grant insert on wealth_advisors.clients, wealth_advisors.consents to authenticated;
grant insert, update, delete on wealth_advisors.user_roles, wealth_advisors.advisor_assignments, wealth_advisors.households, wealth_advisors.enterprises, wealth_advisors.client_objectives, wealth_advisors.assessments, wealth_advisors.wealth_roadmaps, wealth_advisors.roadmap_actions, wealth_advisors.partners, wealth_advisors.authority_records, wealth_advisors.capital_requests, wealth_advisors.capital_events, wealth_advisors.referrals, wealth_advisors.client_outcomes, wealth_advisors.compliance_events to authenticated;
grant update on wealth_advisors.clients, wealth_advisors.consents to authenticated;
grant all on all tables in schema wealth_advisors to service_role;
grant usage, select on all sequences in schema wealth_advisors to authenticated, service_role;

alter default privileges for role postgres in schema wealth_advisors revoke all on tables from anon;
alter default privileges for role postgres in schema wealth_advisors revoke all on sequences from anon;
alter default privileges for role postgres in schema wealth_advisors revoke execute on functions from public, anon;

create or replace view wealth_advisors.executive_pipeline_summary
with (security_invoker = true)
as
select
  (select count(*) from wealth_advisors.clients where status <> 'inactive') as active_clients,
  (select count(*) from wealth_advisors.assessments where status = 'completed') as assessments_completed,
  (select coalesce(avg(total_score),0)::numeric(10,2) from wealth_advisors.assessments where status = 'completed') as average_fri_score,
  (select count(*) from wealth_advisors.capital_requests where readiness_status = 'refer') as capital_ready_requests,
  (select coalesce(sum(event_amount),0) from wealth_advisors.capital_events where event_type = 'requested') as capital_requested,
  (select coalesce(sum(event_amount),0) from wealth_advisors.capital_events where event_type = 'referred') as capital_referred,
  (select coalesce(sum(event_amount),0) from wealth_advisors.capital_events where event_type = 'approved') as capital_approved,
  (select coalesce(sum(event_amount),0) from wealth_advisors.capital_events where event_type = 'closed') as capital_closed,
  (select coalesce(sum(event_amount),0) from wealth_advisors.capital_events where event_type = 'funded') as capital_funded,
  (select count(*) from wealth_advisors.client_outcomes where verified) as verified_outcomes,
  (select count(*) from wealth_advisors.compliance_events where status in ('open','investigating')) as open_compliance_events;

grant select on wealth_advisors.executive_pipeline_summary to authenticated, service_role;

