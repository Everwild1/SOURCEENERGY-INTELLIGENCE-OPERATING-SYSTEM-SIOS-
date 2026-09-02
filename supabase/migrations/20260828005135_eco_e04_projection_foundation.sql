create schema if not exists ecology;
revoke all on schema ecology from public, anon, authenticated;
grant usage on schema ecology to service_role;

create table ecology.object_references (
  id uuid primary key default gen_random_uuid(),
  domain text not null check (domain in ('setc','source_block','wim','cruds','hei','gsc','rgl','capitalization','source_coin','external_authority')),
  object_type text not null check (btrim(object_type) <> ''),
  object_id text not null check (btrim(object_id) <> ''),
  source_authority text not null check (btrim(source_authority) <> ''),
  organization_oid text null check (organization_oid is null or organization_oid ~ '^SETC-OID-[0-9a-f]{32}$'),
  posture text not null default 'reference_only' check (posture in ('reference_only','request_only','derived_projection')),
  evidence_authority text,
  evidence_reference text,
  created_at timestamptz not null default now(),
  unique(domain, object_type, object_id, source_authority),
  check ((evidence_authority is null) = (evidence_reference is null))
);

create table ecology.journeys (
  id uuid primary key default gen_random_uuid(),
  journey_key text not null unique check (btrim(journey_key) <> ''),
  organization_oid text null check (organization_oid is null or organization_oid ~ '^SETC-OID-[0-9a-f]{32}$'),
  cycle_number integer not null default 1 check (cycle_number > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table ecology.journey_edges (
  id uuid primary key default gen_random_uuid(),
  journey_id uuid not null references ecology.journeys(id) on delete cascade,
  from_reference_id uuid references ecology.object_references(id),
  to_reference_id uuid references ecology.object_references(id),
  edge_type text not null check (edge_type in ('evidence_to_research','research_to_ip','ip_to_commercialization','commercialization_to_venture','venture_to_market','market_to_capital_readiness','capital_readiness_to_capital','capital_to_transaction','transaction_to_settlement_reference','settlement_reference_to_impact','impact_to_regenerative_allocation','regenerative_allocation_to_reinvestment','reinvestment_to_research')),
  source_authority text not null check (btrim(source_authority) <> ''),
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (from_reference_id is not null or to_reference_id is not null)
);

create table ecology.event_receipts (
  event_id text primary key check (btrim(event_id) <> ''),
  event_name text not null check (btrim(event_name) <> ''),
  contract_version text not null check (contract_version = '1.0'),
  producer_domain text not null,
  source_authority text not null check (btrim(source_authority) <> ''),
  correlation_id text not null check (btrim(correlation_id) <> ''),
  causation_id text,
  idempotency_key text,
  subject_reference_id uuid references ecology.object_references(id),
  occurred_at timestamptz not null,
  recorded_at timestamptz not null default now(),
  check (recorded_at >= occurred_at)
);
create unique index ecology_event_receipts_idempotency_uq on ecology.event_receipts(idempotency_key) where idempotency_key is not null;

create table ecology.value_flow_references (
  id uuid primary key default gen_random_uuid(),
  journey_id uuid not null references ecology.journeys(id) on delete cascade,
  source_reference_id uuid not null references ecology.object_references(id),
  flow_type text not null check (flow_type in ('capital','transaction','settlement_reference','revenue','impact','reinvestment')),
  amount numeric,
  currency_or_unit text,
  source_authority text not null,
  occurred_at timestamptz,
  created_at timestamptz not null default now(),
  check (amount is null or amount >= 0),
  check ((amount is null) = (currency_or_unit is null))
);

create table ecology.impact_lineage (
  id uuid primary key default gen_random_uuid(),
  journey_id uuid not null references ecology.journeys(id) on delete cascade,
  impact_reference_id uuid not null references ecology.object_references(id),
  metric_family text not null check (btrim(metric_family) <> ''),
  measurement_posture text not null check (measurement_posture in ('estimate','observed','verified')),
  value numeric,
  unit text,
  methodology_reference text,
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),
  source_authority text not null,
  created_at timestamptz not null default now()
);

create table ecology.regenerative_projections (
  id uuid primary key default gen_random_uuid(),
  journey_id uuid not null references ecology.journeys(id) on delete cascade,
  impact_lineage_id uuid references ecology.impact_lineage(id),
  target_reference_id uuid references ecology.object_references(id),
  allocation_type text not null check (allocation_type in ('research','enterprise','community','infrastructure','human_capital','ecosystem')),
  proposed_amount numeric,
  currency_or_unit text,
  governance_status text not null default 'projection_only' check (governance_status in ('projection_only','proposed','reviewed','authorized_external')),
  authority_reference text,
  created_at timestamptz not null default now(),
  check (proposed_amount is null or proposed_amount >= 0),
  check ((proposed_amount is null) = (currency_or_unit is null)),
  check (governance_status <> 'authorized_external' or authority_reference is not null)
);

alter table ecology.object_references enable row level security;
alter table ecology.journeys enable row level security;
alter table ecology.journey_edges enable row level security;
alter table ecology.event_receipts enable row level security;
alter table ecology.value_flow_references enable row level security;
alter table ecology.impact_lineage enable row level security;
alter table ecology.regenerative_projections enable row level security;

revoke all on all tables in schema ecology from public, anon, authenticated;
grant select, insert, update, delete on all tables in schema ecology to service_role;

comment on schema ecology is 'ECO-E04 cross-domain projection/read model. Never authoritative for source-domain identity, ownership, ledger, transaction, logistics, treasury, or settlement finality.';
