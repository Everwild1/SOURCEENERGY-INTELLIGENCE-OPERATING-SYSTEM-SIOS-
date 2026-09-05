create table if not exists public.system_heartbeat_registry (
  heartbeat_id uuid primary key default gen_random_uuid(),
  ecosystem text not null default 'SourceEnergyEcosystem',
  component text not null,
  environment text not null default 'production',
  status text not null check (status in ('healthy','degraded','offline','maintenance')),
  source text not null,
  correlation_id text,
  metadata jsonb not null default '{}'::jsonb,
  observed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_system_heartbeat_component_observed
  on public.system_heartbeat_registry (component, observed_at desc);

create index if not exists idx_system_heartbeat_status_observed
  on public.system_heartbeat_registry (status, observed_at desc);

alter table public.system_heartbeat_registry enable row level security;

comment on table public.system_heartbeat_registry is 'Operational heartbeat registry for SourceEnergy ecosystem components. Records health/provenance only and does not confer financial, legal, regulatory, or institutional authority.';
comment on column public.system_heartbeat_registry.heartbeat_id is 'Canonical UUID for a single heartbeat observation.';
comment on column public.system_heartbeat_registry.correlation_id is 'Optional external correlation key for CI, deployment, transaction, or service trace linkage.';
