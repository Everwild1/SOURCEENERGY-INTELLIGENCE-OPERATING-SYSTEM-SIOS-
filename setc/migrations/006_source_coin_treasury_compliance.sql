-- SC-E03 / SC-E07: treasury, supply-policy and compliance control plane.
-- Production issuance remains disabled by application/configuration governance.

create table if not exists source_coin.supply_policies (
  policy_id uuid primary key,
  version text not null,
  mode text not null check (mode in ('FIXED_GENESIS','CAPPED','SCHEDULED','GOVERNED')),
  approved boolean not null default false,
  max_supply_minor bigint check (max_supply_minor is null or max_supply_minor > 0),
  per_period_limit_minor bigint check (per_period_limit_minor is null or per_period_limit_minor > 0),
  effective_at timestamptz,
  created_at timestamptz not null default now(),
  unique (version)
);

create table if not exists source_coin.treasury_accounts (
  treasury_account_id uuid primary key,
  coin_account_id uuid not null references source_coin.accounts(account_id),
  purpose text not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED','CLOSED')),
  created_at timestamptz not null default now()
);

create table if not exists source_coin.treasury_authorizations (
  authorization_id uuid primary key,
  policy_id uuid not null references source_coin.supply_policies(policy_id),
  proposer_ref text not null,
  approver_ref text not null,
  amount_minor bigint not null check (amount_minor > 0),
  purpose text not null,
  approved boolean not null default false,
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  check (proposer_ref <> approver_ref)
);

create table if not exists source_coin.treasury_allocations (
  allocation_id uuid primary key,
  treasury_account_id uuid not null references source_coin.treasury_accounts(treasury_account_id),
  destination_account_id uuid not null references source_coin.accounts(account_id),
  amount_minor bigint not null check (amount_minor > 0),
  authorization_id uuid not null references source_coin.treasury_authorizations(authorization_id),
  policy_id uuid not null references source_coin.supply_policies(policy_id),
  transaction_id uuid references source_coin.transactions(transaction_id),
  created_at timestamptz not null default now()
);

create table if not exists source_coin.policy_profiles (
  profile_id uuid primary key,
  version text not null,
  jurisdiction_ref text not null,
  active boolean not null default true,
  mandatory_screening boolean not null default false,
  created_at timestamptz not null default now(),
  unique (version, jurisdiction_ref)
);

create table if not exists source_coin.compliance_decisions (
  decision_id uuid primary key,
  subject_type text not null,
  subject_id text not null,
  operation_type text not null,
  policy_profile_id uuid not null references source_coin.policy_profiles(profile_id),
  policy_version text not null,
  result text not null check (result in ('ALLOW','DENY','REVIEW','RESTRICT')),
  reason_codes text[] not null,
  evidence_refs text[] not null default '{}',
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  created_at timestamptz not null default now(),
  check (cardinality(reason_codes) > 0),
  check (valid_until is null or valid_until >= valid_from)
);

alter table source_coin.supply_policies enable row level security;
alter table source_coin.treasury_accounts enable row level security;
alter table source_coin.treasury_authorizations enable row level security;
alter table source_coin.treasury_allocations enable row level security;
alter table source_coin.policy_profiles enable row level security;
alter table source_coin.compliance_decisions enable row level security;

revoke all on source_coin.supply_policies from anon, authenticated;
revoke all on source_coin.treasury_accounts from anon, authenticated;
revoke all on source_coin.treasury_authorizations from anon, authenticated;
revoke all on source_coin.treasury_allocations from anon, authenticated;
revoke all on source_coin.policy_profiles from anon, authenticated;
revoke all on source_coin.compliance_decisions from anon, authenticated;

create or replace function source_coin.current_supply_minor()
returns bigint
language sql
stable
security definer
set search_path = source_coin, pg_temp
as $$
  select coalesce(sum(
    case
      when transaction_type = 'MINT' and status = 'SETTLED' then amount_minor
      when transaction_type = 'BURN' and status = 'SETTLED' then -amount_minor
      else 0
    end
  ), 0)::bigint
  from source_coin.transactions;
$$;

revoke all on function source_coin.current_supply_minor() from public, anon, authenticated;
