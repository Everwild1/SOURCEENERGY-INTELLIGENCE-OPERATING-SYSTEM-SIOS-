-- Source Coin Sprint 1 / Supabase Postgres baseline
-- Governance: SC-01, SC-02, SC-04. Production economy remains disabled.

create extension if not exists pgcrypto;

create schema if not exists source_coin;

create table if not exists source_coin.accounts (
  account_id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED','FROZEN','CLOSED')),
  created_at timestamptz not null default now()
);

create table if not exists source_coin.organization_wallets (
  wallet_id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  account_id uuid not null references source_coin.accounts(account_id),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED','FROZEN','CLOSED')),
  created_at timestamptz not null default now(),
  unique (organization_id, account_id)
);

create table if not exists source_coin.transactions (
  transaction_id uuid primary key default gen_random_uuid(),
  asset_id uuid not null,
  transaction_type text not null check (transaction_type in ('TRANSFER','MINT','BURN','TREASURY_ALLOCATION','SETTLEMENT','REWARD')),
  source_account_id uuid references source_coin.accounts(account_id),
  destination_account_id uuid references source_coin.accounts(account_id),
  amount_minor bigint not null check (amount_minor > 0),
  status text not null default 'CREATED' check (status in ('CREATED','VALIDATED','AUTHORIZED','EXECUTING','SETTLED','REJECTED','FAILED','CANCELLED')),
  authorization_ref text,
  policy_decision_ref text,
  correlation_id text not null,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  authorized_at timestamptz,
  executed_at timestamptz,
  unique (idempotency_key)
);

create table if not exists source_coin.ledger_events (
  ledger_sequence bigint generated always as identity primary key,
  event_id uuid not null unique default gen_random_uuid(),
  transaction_id uuid not null references source_coin.transactions(transaction_id),
  event_type text not null,
  amount_minor bigint not null check (amount_minor > 0),
  source_account_id uuid references source_coin.accounts(account_id),
  destination_account_id uuid references source_coin.accounts(account_id),
  correlation_id text not null,
  occurred_at timestamptz not null default now()
);

-- Exposed economic tables are default-deny. Policies must be added only with approved organization-scoped authorization semantics.
alter table source_coin.accounts enable row level security;
alter table source_coin.organization_wallets enable row level security;
alter table source_coin.transactions enable row level security;
alter table source_coin.ledger_events enable row level security;

revoke all on schema source_coin from anon, authenticated;
revoke all on all tables in schema source_coin from anon, authenticated;

comment on schema source_coin is 'Governed Source Coin economic domain. Direct client ledger mutation prohibited.';
