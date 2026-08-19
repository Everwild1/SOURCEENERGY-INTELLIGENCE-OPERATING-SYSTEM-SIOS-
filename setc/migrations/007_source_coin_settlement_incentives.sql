-- SC-E05 / SC-E06: settlement and incentive control plane.
-- Server-only economic execution. This migration does not enable minting.

create table if not exists source_coin.settlement_instructions (
  settlement_id uuid primary key,
  settlement_class text not null check (settlement_class in ('INSTITUTIONAL','PROGRAM','RESEARCH','SOURCE_BLOCK','TREASURY','SERVICE')),
  source_account_id uuid not null references source_coin.accounts(account_id),
  destination_account_id uuid not null references source_coin.accounts(account_id),
  amount_minor bigint not null check (amount_minor > 0),
  obligation_ref text not null,
  policy_ref text not null,
  compliance_decision_id uuid not null references source_coin.compliance_decisions(decision_id),
  authorization_ref text not null,
  idempotency_key text not null unique,
  expires_at timestamptz not null,
  status text not null default 'CREATED' check (status in ('CREATED','AUTHORIZED','SETTLED','REJECTED','EXPIRED','FAILED')),
  transaction_id uuid references source_coin.transactions(transaction_id),
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  check (source_account_id <> destination_account_id)
);

create table if not exists source_coin.contributions (
  contribution_id uuid primary key,
  contributor_organization_id text not null check (contributor_organization_id ~ '^SETC-OID-[0-9A-F]{16}$'),
  evidence_ref text not null,
  validator_ref text not null,
  contributor_principal_ref text not null,
  status text not null default 'SUBMITTED' check (status in ('SUBMITTED','VALIDATED','REJECTED')),
  created_at timestamptz not null default now(),
  unique (contributor_organization_id, evidence_ref),
  check (validator_ref <> contributor_principal_ref)
);

create table if not exists source_coin.reward_policies (
  reward_policy_id uuid primary key,
  version text not null,
  max_reward_minor bigint not null check (max_reward_minor > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (reward_policy_id, version)
);

create table if not exists source_coin.reward_grants (
  reward_grant_id uuid primary key,
  contribution_id uuid not null references source_coin.contributions(contribution_id),
  recipient_organization_id text not null check (recipient_organization_id ~ '^SETC-OID-[0-9A-F]{16}$'),
  recipient_account_id uuid not null references source_coin.accounts(account_id),
  reward_policy_id uuid not null references source_coin.reward_policies(reward_policy_id),
  amount_minor bigint not null check (amount_minor > 0),
  funding_account_id uuid not null references source_coin.accounts(account_id),
  compliance_decision_id uuid not null references source_coin.compliance_decisions(decision_id),
  authorization_ref text not null,
  status text not null default 'PROPOSED' check (status in ('PROPOSED','APPROVED','EXECUTED','REJECTED')),
  transaction_id uuid references source_coin.transactions(transaction_id),
  created_at timestamptz not null default now(),
  executed_at timestamptz,
  unique (contribution_id, reward_policy_id),
  check (funding_account_id <> recipient_account_id)
);

alter table source_coin.settlement_instructions enable row level security;
alter table source_coin.contributions enable row level security;
alter table source_coin.reward_policies enable row level security;
alter table source_coin.reward_grants enable row level security;

revoke all on source_coin.settlement_instructions from anon, authenticated;
revoke all on source_coin.contributions from anon, authenticated;
revoke all on source_coin.reward_policies from anon, authenticated;
revoke all on source_coin.reward_grants from anon, authenticated;

-- Economic execution remains delegated to the canonical server-only ledger RPC.
-- Source Blocks and ordinary clients receive no direct balance mutation privilege.
