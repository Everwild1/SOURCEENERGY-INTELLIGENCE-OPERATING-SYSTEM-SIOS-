-- SC-E08 Source Coin API/event persistence boundary
-- Economic authority remains in governed ledger functions; these tables transport evidence/events only.

create table if not exists source_coin.event_outbox (
  event_id uuid primary key,
  event_type text not null,
  aggregate_type text not null,
  aggregate_id text not null,
  schema_version text not null,
  correlation_id text not null,
  causation_id text,
  organization_ref text,
  policy_ref text,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  published_at timestamptz
);

create index if not exists source_coin_event_outbox_unpublished_idx
  on source_coin.event_outbox (occurred_at)
  where published_at is null;

create table if not exists source_coin.event_inbox (
  consumer_name text not null,
  event_id uuid not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  primary key (consumer_name, event_id)
);

create table if not exists source_coin.api_idempotency (
  idempotency_key text primary key,
  request_id uuid not null,
  actor_ref text not null,
  correlation_id text not null,
  request_fingerprint text not null,
  response_status integer,
  response_body jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

alter table source_coin.event_outbox enable row level security;
alter table source_coin.event_inbox enable row level security;
alter table source_coin.api_idempotency enable row level security;

revoke all on source_coin.event_outbox from anon, authenticated;
revoke all on source_coin.event_inbox from anon, authenticated;
revoke all on source_coin.api_idempotency from anon, authenticated;

-- Realtime may publish selected projections/events, but these transport tables are server-controlled.
-- Consumers claim an event by inserting (consumer_name,event_id); duplicate delivery then conflicts safely.
