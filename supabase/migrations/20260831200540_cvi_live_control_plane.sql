create table if not exists public.cvi_interface_config (
  config_key text primary key,
  protocol text not null,
  seal_authority text not null,
  version_label text not null,
  dominion_cube_capacity integer not null check (dominion_cube_capacity > 0),
  documented_scroll_count integer not null check (documented_scroll_count >= 0),
  operational_definition text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.cvi_nodes (
  node_code text primary key,
  layer integer not null check (layer between 1 and 10),
  display_name text not null,
  node_type text not null,
  declared_state text not null check (declared_state in ('DECLARED_ACTIVE','DECLARED_PENDING','DECLARED_INACTIVE')),
  runtime_state text not null check (runtime_state in ('UNOBSERVED','REGISTERED','OBSERVED','VERIFIED','DEGRADED','BLOCKED')),
  verification_basis text not null default 'No independent runtime evidence recorded',
  source_authority text not null,
  last_observed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.cvi_watchtraces (
  trace_id text primary key,
  scroll_ref text,
  trigger_label text,
  linked_vault text,
  layer_path text[] not null default '{}'::text[],
  declared_state text not null check (declared_state in ('DECLARED_ACTIVE','DECLARED_PENDING','DECLARED_CLOSED')),
  verification_state text not null check (verification_state in ('UNOBSERVED','AWAITING_EVIDENCE','PARTIALLY_VERIFIED','VERIFIED','BLOCKED','REJECTED')),
  current_gate text,
  last_event_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.cvi_evidence_events (
  evidence_id uuid primary key default gen_random_uuid(),
  trace_id text references public.cvi_watchtraces(trace_id) on delete set null,
  node_code text references public.cvi_nodes(node_code) on delete set null,
  evidence_type text not null,
  evidence_ref text,
  source_system text not null,
  verification_state text not null check (verification_state in ('RECEIVED','VALIDATED','REJECTED','UNVERIFIED')),
  observed_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.cvi_interface_config enable row level security;
alter table public.cvi_nodes enable row level security;
alter table public.cvi_watchtraces enable row level security;
alter table public.cvi_evidence_events enable row level security;

comment on table public.cvi_nodes is 'Codex Veritas node registry. Declared state is governance-document state; runtime state is evidence-backed technical state.';
comment on table public.cvi_watchtraces is 'Evidence-governed watchtrace registry. A watchtrace cannot be represented as VERIFIED without corresponding validated evidence events.';
comment on table public.cvi_evidence_events is 'Evidence references only. Do not store account numbers, credentials, private keys, full payment messages, or other secrets.';

insert into public.cvi_interface_config(config_key, protocol, seal_authority, version_label, dominion_cube_capacity, documented_scroll_count, operational_definition)
values ('primary','CVI-ONLINE-PRIME','Dr. Oliver IHuoma Ocubaus','Tier III — Evidence-Governed Live Interface',729,392,'LIVE means the SourceEnergy command backend is reachable and the CVI control plane is recording evidence-backed runtime state. Governance declarations are displayed separately from independent technical verification.')
on conflict (config_key) do update set
 protocol=excluded.protocol,
 seal_authority=excluded.seal_authority,
 version_label=excluded.version_label,
 dominion_cube_capacity=excluded.dominion_cube_capacity,
 documented_scroll_count=excluded.documented_scroll_count,
 operational_definition=excluded.operational_definition,
 updated_at=now();

insert into public.cvi_nodes(node_code,layer,display_name,node_type,declared_state,runtime_state,verification_basis,source_authority,metadata)
values
 ('L5-SE-ROOT',5,'SourceEnergy Crown Trust Apex Governance Node','governance','DECLARED_ACTIVE','REGISTERED','Registered in public.codex_registry; no external financial-network confirmation inferred','Codex governance registry',jsonb_build_object('codex_ref','ROOT')),
 ('L6-D031',6,'Abu Dhabi Royal Receiver Node','interbank-receiver','DECLARED_ACTIVE','UNOBSERVED','Governance documents declare the node; no independent SWIFT/bank telemetry is present in CVI evidence registry','Codex governance documents','{}'::jsonb),
 ('L6-D045',6,'U.S. Interbank Witness Node','interbank-witness','DECLARED_ACTIVE','UNOBSERVED','Governance documents declare the node; no independent SWIFT/bank telemetry is present in CVI evidence registry','Codex governance documents','{}'::jsonb),
 ('L4-C023',4,'Remittance / Petroleum Scroll Node','remittance','DECLARED_ACTIVE','UNOBSERVED','Governance documents declare the node; no runtime node observation is present','Codex governance documents','{}'::jsonb),
 ('L7-VW001',7,'Silent Flame Witness Node','witness','DECLARED_ACTIVE','UNOBSERVED','Registered in governance artifacts; runtime witness telemetry not yet ingested','Codex governance documents','{}'::jsonb),
 ('L10-SSR411',10,'SourceEnergy Spatial Registry','spatial-governance','DECLARED_ACTIVE','REGISTERED','Registered in public.codex_registry; operational scope is internal SourceEnergy spatial governance','Codex registry / SSR charter',jsonb_build_object('scroll_ref','#411'))
on conflict (node_code) do update set
 display_name=excluded.display_name,
 node_type=excluded.node_type,
 declared_state=excluded.declared_state,
 verification_basis=excluded.verification_basis,
 source_authority=excluded.source_authority,
 metadata=public.cvi_nodes.metadata || excluded.metadata,
 updated_at=now();

insert into public.cvi_watchtraces(trace_id,scroll_ref,trigger_label,linked_vault,layer_path,declared_state,verification_state,current_gate,metadata)
values ('CV-ENTRY-002','Embedded Transaction | Royal Seed Flow','Royal Breach Release – Mensur Deployment','ALCA Royal Investment Management LLC',array['L10','L6-D031','L4-C023'],'DECLARED_ACTIVE','AWAITING_EVIDENCE','Bank-origin evidence / L6 witness validation required',jsonb_build_object('required_evidence',jsonb_build_array('UETR or bank trace reference','MT103/ISO 20022 evidence where lawfully available','receiving-bank confirmation or equivalent settlement evidence')))
on conflict (trace_id) do update set
 scroll_ref=excluded.scroll_ref,
 trigger_label=excluded.trigger_label,
 linked_vault=excluded.linked_vault,
 layer_path=excluded.layer_path,
 declared_state=excluded.declared_state,
 current_gate=excluded.current_gate,
 metadata=excluded.metadata,
 updated_at=now();

create or replace view public.cvi_live_status
with (security_invoker = true)
as
select
  c.protocol,
  c.seal_authority,
  c.version_label,
  c.dominion_cube_capacity,
  c.documented_scroll_count,
  (select count(*) from public.codex_registry) as runtime_registered_scrolls,
  (select count(*) from public.cvi_nodes) as registered_cvi_nodes,
  (select count(*) from public.cvi_nodes where runtime_state='VERIFIED') as verified_cvi_nodes,
  (select count(*) from public.cvi_watchtraces where verification_state='VERIFIED') as verified_watchtraces,
  (select count(*) from public.cvi_watchtraces where verification_state in ('AWAITING_EVIDENCE','PARTIALLY_VERIFIED')) as open_verification_watchtraces,
  (select max(observed_at) from public.system_heartbeat_registry) as latest_sios_heartbeat,
  c.operational_definition,
  c.updated_at
from public.cvi_interface_config c
where c.config_key='primary';
