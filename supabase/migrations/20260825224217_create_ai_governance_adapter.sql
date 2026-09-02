create schema if not exists ai_governance;

comment on schema ai_governance is 'Private SourceEnergy AI governance adapter. AI capability does not confer institutional, financial, legal, settlement, or sovereignty authority.';

create table ai_governance.policy_versions (
  id uuid primary key default gen_random_uuid(),
  policy_code text not null,
  version text not null,
  title text not null,
  status text not null check (status in ('DRAFT','ACTIVE','RETIRED')),
  effective_from timestamptz,
  effective_to timestamptz,
  document_reference text,
  control_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (policy_code, version)
);

create table ai_governance.agents (
  id uuid primary key default gen_random_uuid(),
  agent_code text not null unique,
  agent_name text not null,
  agent_type text not null check (agent_type in ('MODEL','ASSISTANT','AGENT','WORKFLOW','SERVICE')),
  principal_user_id uuid references auth.users(id) on delete set null,
  principal_reference text,
  organization_reference text,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED','RETIRED')),
  model_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (principal_user_id is not null or principal_reference is not null)
);

create table ai_governance.agent_mandates (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references ai_governance.agents(id) on delete cascade,
  mandate_code text not null,
  purpose text not null,
  authority_reference text,
  jurisdiction_code text,
  permitted_resources jsonb not null default '[]'::jsonb,
  prohibited_actions jsonb not null default '[]'::jsonb,
  max_autonomy_class text not null default 'C1' check (max_autonomy_class in ('C0','C1','C2','C3','C4','C5','C6')),
  financial_limit numeric(24,6),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED','EXPIRED','REVOKED')),
  evidence_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agent_id, mandate_code),
  check (effective_to is null or effective_to > effective_from),
  check (financial_limit is null or financial_limit >= 0)
);

create table ai_governance.action_requests (
  id uuid primary key default gen_random_uuid(),
  correlation_id text not null unique,
  agent_id uuid not null references ai_governance.agents(id),
  mandate_id uuid not null references ai_governance.agent_mandates(id),
  requested_by_user_id uuid references auth.users(id) on delete set null,
  action_type text not null,
  target_domain text not null,
  target_resource text,
  action_payload jsonb not null default '{}'::jsonb,
  autonomy_class text not null check (autonomy_class in ('C0','C1','C2','C3','C4','C5','C6')),
  reversibility text not null check (reversibility in ('REVERSIBLE','PARTIALLY_REVERSIBLE','DIFFICULT_TO_REVERSE','IRREVERSIBLE')),
  consequence_level text not null check (consequence_level in ('LOW','MODERATE','HIGH','SYSTEMIC','SOVEREIGNTY_CRITICAL')),
  authority_reference text,
  governance_gate_reference text,
  policy_version_id uuid references ai_governance.policy_versions(id),
  status text not null default 'REQUESTED' check (status in ('REQUESTED','CLASSIFIED','PENDING_APPROVAL','APPROVED','DENIED','CANCELLED','EXECUTING','EXECUTED','FAILED')),
  requested_at timestamptz not null default now(),
  decision_at timestamptz,
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  check (expires_at is null or expires_at > requested_at)
);

create table ai_governance.approval_requirements (
  id uuid primary key default gen_random_uuid(),
  action_id uuid not null references ai_governance.action_requests(id) on delete cascade,
  requirement_code text not null,
  required_approvals integer not null default 1 check (required_approvals > 0),
  approver_authority_class text,
  separation_of_duties_required boolean not null default true,
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (action_id, requirement_code)
);

create table ai_governance.action_approvals (
  id uuid primary key default gen_random_uuid(),
  action_id uuid not null references ai_governance.action_requests(id) on delete cascade,
  requirement_id uuid references ai_governance.approval_requirements(id) on delete cascade,
  approver_user_id uuid references auth.users(id) on delete set null,
  approver_reference text not null,
  authority_reference text,
  decision text not null check (decision in ('APPROVE','DENY','REVOKE')),
  rationale text,
  evidence jsonb not null default '{}'::jsonb,
  decided_at timestamptz not null default now(),
  unique (action_id, requirement_id, approver_reference)
);

create table ai_governance.execution_grants (
  id uuid primary key default gen_random_uuid(),
  action_id uuid not null references ai_governance.action_requests(id),
  grant_code text not null unique,
  issued_to_agent_id uuid not null references ai_governance.agents(id),
  authority_reference text not null,
  allowed_operation text not null,
  target_domain text not null,
  target_resource text,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  max_uses integer not null default 1 check (max_uses > 0),
  use_count integer not null default 0 check (use_count >= 0),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','USED','EXPIRED','REVOKED')),
  grant_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (expires_at > issued_at),
  check (use_count <= max_uses)
);

create table ai_governance.execution_events (
  id uuid primary key default gen_random_uuid(),
  execution_grant_id uuid not null references ai_governance.execution_grants(id),
  action_id uuid not null references ai_governance.action_requests(id),
  agent_id uuid not null references ai_governance.agents(id),
  event_type text not null check (event_type in ('STARTED','SUCCEEDED','FAILED','ROLLED_BACK','BLOCKED')),
  target_domain text not null,
  target_resource text,
  outcome jsonb not null default '{}'::jsonb,
  external_reference text,
  occurred_at timestamptz not null default now()
);

create index ai_governance_action_requests_agent_idx on ai_governance.action_requests(agent_id, requested_at desc);
create index ai_governance_action_requests_status_idx on ai_governance.action_requests(status, autonomy_class);
create index ai_governance_action_approvals_action_idx on ai_governance.action_approvals(action_id, decision);
create index ai_governance_execution_grants_action_idx on ai_governance.execution_grants(action_id, status, expires_at);
create index ai_governance_execution_events_action_idx on ai_governance.execution_events(action_id, occurred_at desc);

alter table ai_governance.policy_versions enable row level security;
alter table ai_governance.agents enable row level security;
alter table ai_governance.agent_mandates enable row level security;
alter table ai_governance.action_requests enable row level security;
alter table ai_governance.approval_requirements enable row level security;
alter table ai_governance.action_approvals enable row level security;
alter table ai_governance.execution_grants enable row level security;
alter table ai_governance.execution_events enable row level security;

create policy policy_versions_service_role on ai_governance.policy_versions for all to service_role using (true) with check (true);
create policy agents_service_role on ai_governance.agents for all to service_role using (true) with check (true);
create policy agent_mandates_service_role on ai_governance.agent_mandates for all to service_role using (true) with check (true);
create policy action_requests_service_role on ai_governance.action_requests for all to service_role using (true) with check (true);
create policy approval_requirements_service_role on ai_governance.approval_requirements for all to service_role using (true) with check (true);
create policy action_approvals_service_role on ai_governance.action_approvals for all to service_role using (true) with check (true);
create policy execution_grants_service_role on ai_governance.execution_grants for all to service_role using (true) with check (true);
create policy execution_events_service_role on ai_governance.execution_events for all to service_role using (true) with check (true);

revoke all on schema ai_governance from public, anon, authenticated;
revoke all on all tables in schema ai_governance from public, anon, authenticated;
grant usage on schema ai_governance to service_role;
grant all on all tables in schema ai_governance to service_role;

create or replace function ai_governance.validate_execution_grant()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_action ai_governance.action_requests%rowtype;
  v_required integer;
  v_approved integer;
begin
  select * into v_action
  from ai_governance.action_requests
  where id = new.action_id;

  if not found then
    raise exception 'AI governance execution grant denied: action request not found';
  end if;

  if v_action.status <> 'APPROVED' then
    raise exception 'AI governance execution grant denied: action status must be APPROVED';
  end if;

  if v_action.expires_at is not null and v_action.expires_at <= now() then
    raise exception 'AI governance execution grant denied: action authorization expired';
  end if;

  if new.issued_to_agent_id <> v_action.agent_id then
    raise exception 'AI governance execution grant denied: grant agent does not match requesting agent';
  end if;

  if new.target_domain <> v_action.target_domain then
    raise exception 'AI governance execution grant denied: target domain mismatch';
  end if;

  if v_action.autonomy_class in ('C4','C5','C6') then
    select coalesce(sum(required_approvals),0) into v_required
    from ai_governance.approval_requirements
    where action_id = new.action_id
      and (expires_at is null or expires_at > now());

    select count(distinct approver_reference) into v_approved
    from ai_governance.action_approvals
    where action_id = new.action_id
      and decision = 'APPROVE';

    if v_required = 0 or v_approved < v_required then
      raise exception 'AI governance execution grant denied: required human approvals are incomplete';
    end if;
  end if;

  if new.expires_at > now() + interval '1 hour' then
    raise exception 'AI governance execution grant denied: execution grants may not exceed one hour';
  end if;

  return new;
end;
$$;

create trigger trg_validate_execution_grant
before insert or update on ai_governance.execution_grants
for each row execute function ai_governance.validate_execution_grant();

create or replace function ai_governance.prevent_audit_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'AI governance audit history is append-only';
end;
$$;

create trigger trg_execution_events_append_only
before update or delete on ai_governance.execution_events
for each row execute function ai_governance.prevent_audit_mutation();

comment on table ai_governance.action_requests is 'AI action proposals. Records do not confer authority; execution requires applicable existing institutional governance plus an active execution grant.';
comment on table ai_governance.execution_grants is 'Short-lived bounded execution authorization. Capability alone does not confer permission or sovereignty.';
comment on table ai_governance.execution_events is 'Append-only AI execution evidence for audit and governance reconstruction.';
