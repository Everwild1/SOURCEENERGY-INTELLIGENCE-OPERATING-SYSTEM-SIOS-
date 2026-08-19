-- SC-E10: SETC / Source Block integration boundary.
-- Requests and projections are integration evidence, never direct ledger authority.

create table if not exists source_coin.integration_requests (
    request_id uuid primary key,
    source_block_id text not null,
    organization_id text not null check (organization_id ~ '^SETC-OID-[0-9a-f]{32}$'),
    request_type text not null check (request_type in ('SETTLEMENT', 'REWARD')),
    provenance_ref text not null,
    correlation_id text not null,
    causation_id text not null,
    idempotency_key text not null unique,
    obligation_ref text,
    contribution_ref text,
    chain_network_ref text,
    chain_anchor_ref text,
    chain_proof_ref text,
    status text not null default 'RECEIVED' check (status in ('RECEIVED','VALIDATED','REJECTED','FORWARDED')),
    created_at timestamptz not null default now(),
    check (
      (request_type = 'SETTLEMENT' and obligation_ref is not null)
      or (request_type = 'REWARD' and contribution_ref is not null)
    )
);

create table if not exists source_coin.integration_projections (
    projection_name text not null,
    aggregate_id text not null,
    source_event_id uuid not null,
    source_event_version text not null,
    projection_payload jsonb not null,
    projected_at timestamptz not null default now(),
    primary key (projection_name, aggregate_id)
);

alter table source_coin.integration_requests enable row level security;
alter table source_coin.integration_projections enable row level security;

-- No direct participant access to integration ingress or projections by default.
revoke all on source_coin.integration_requests from anon, authenticated;
revoke all on source_coin.integration_projections from anon, authenticated;

-- Explicitly document that integration tables cannot alter economic state.
comment on table source_coin.integration_requests is
  'SC-E10 integration ingress only. Rows cannot directly mutate Source Coin balances or ledger events.';
comment on table source_coin.integration_projections is
  'Read-model projection storage. Projection state is non-authoritative for economic execution.';
