-- SourceEnergy Insurance — INS-E10 ecosystem adapters
-- Reference/synchronization/provenance artifacts only; no independent legal, coverage, authority, title, liability or settlement effect.

create table if not exists public.setc_insurance_adapter_systems (
  insurance_adapter_system_id uuid primary key default gen_random_uuid(),
  system_code text not null unique,
  system_name text not null,
  domain_type text not null check (domain_type in ('organization','risk','policy','claims','settlement','reinsurance','source_coin','wim','treasury','logistics','procurement','asset','intelligence','external','other')),
  authority_class text not null default 'reference' check (authority_class in ('reference','authoritative_external','internal_system_of_record','derived','other')),
  endpoint_reference text,
  evidence_ref text,
  system_status text not null default 'draft' check (system_status in ('draft','active_reference','suspended','retired','void')),
  created_at timestamptz not null default now(),
  check (authority_class <> 'authoritative_external' or evidence_ref is not null)
);

create table if not exists public.setc_insurance_adapter_bindings (
  insurance_adapter_binding_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  insurance_adapter_system_id uuid not null references public.setc_insurance_adapter_systems(insurance_adapter_system_id),
  insurance_entity_type text not null check (insurance_entity_type in ('risk_object','policy','coverage','claim','loss_event','premium','payment','reinsurance','portfolio_snapshot','scenario','other')),
  insurance_entity_reference text not null,
  external_entity_type text not null,
  external_entity_reference text not null,
  correlation_key text not null,
  binding_status text not null default 'unverified' check (binding_status in ('unverified','mapped','evidence_supported','verified_reference','superseded','void')),
  evidence_ref text,
  created_at timestamptz not null default now(),
  unique(insurance_adapter_system_id, correlation_key),
  unique(insurance_adapter_system_id, insurance_entity_type, insurance_entity_reference, external_entity_type, external_entity_reference),
  check (binding_status not in ('evidence_supported','verified_reference') or evidence_ref is not null)
);

create table if not exists public.setc_insurance_adapter_events (
  insurance_adapter_event_id uuid primary key default gen_random_uuid(),
  insurance_adapter_binding_id uuid references public.setc_insurance_adapter_bindings(insurance_adapter_binding_id),
  organization_oid text not null references public.setc_organizations(oid),
  insurance_adapter_system_id uuid not null references public.setc_insurance_adapter_systems(insurance_adapter_system_id),
  event_type text not null check (event_type in ('observe','import','export','sync','reconcile','checkpoint','error','retry','supersede','other')),
  idempotency_key text not null,
  source_record_reference text,
  target_record_reference text,
  transformation_reference text,
  payload_hash text check (payload_hash is null or payload_hash ~ '^[0-9A-Fa-f]{64}$'),
  event_status text not null default 'recorded' check (event_status in ('recorded','processed','evidence_supported','failed','superseded','void')),
  evidence_ref text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(insurance_adapter_system_id,idempotency_key),
  check (event_status <> 'evidence_supported' or evidence_ref is not null)
);

create table if not exists public.setc_insurance_adapter_checkpoints (
  insurance_adapter_checkpoint_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  insurance_adapter_system_id uuid not null references public.setc_insurance_adapter_systems(insurance_adapter_system_id),
  checkpoint_scope text not null,
  cursor_reference text,
  watermark_at timestamptz,
  checkpoint_status text not null default 'open' check (checkpoint_status in ('open','verified_reference','failed','superseded','void')),
  evidence_ref text,
  created_at timestamptz not null default now(),
  unique(organization_oid,insurance_adapter_system_id,checkpoint_scope),
  check (checkpoint_status <> 'verified_reference' or evidence_ref is not null)
);

create table if not exists public.setc_insurance_adapter_errors (
  insurance_adapter_error_id uuid primary key default gen_random_uuid(),
  insurance_adapter_event_id uuid references public.setc_insurance_adapter_events(insurance_adapter_event_id),
  organization_oid text not null references public.setc_organizations(oid),
  insurance_adapter_system_id uuid not null references public.setc_insurance_adapter_systems(insurance_adapter_system_id),
  error_code text,
  error_class text not null check (error_class in ('validation','authorization','mapping','transport','conflict','source_unavailable','target_unavailable','integrity','other')),
  error_reference text not null,
  remediation_status text not null default 'open' check (remediation_status in ('open','investigating','remediated_reference','accepted_reference','superseded','void')),
  remediation_evidence_ref text,
  created_at timestamptz not null default now(),
  check (remediation_status not in ('remediated_reference','accepted_reference') or remediation_evidence_ref is not null)
);

create table if not exists public.setc_insurance_adapter_settlement_references (
  insurance_adapter_settlement_reference_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  insurance_adapter_system_id uuid not null references public.setc_insurance_adapter_systems(insurance_adapter_system_id),
  insurance_entity_type text not null check (insurance_entity_type in ('premium','payment','claim_payment','refund','reinsurance_premium','reinsurance_recovery','other')),
  insurance_entity_reference text not null,
  settlement_network text not null,
  external_settlement_reference text not null,
  currency_or_asset_code text,
  amount numeric(24,6) check (amount is null or amount >= 0),
  settlement_status text not null default 'reference_only' check (settlement_status in ('reference_only','pending_external','evidence_supported','finality_reference','reversed_reference','void')),
  evidence_ref text,
  created_at timestamptz not null default now(),
  unique(insurance_adapter_system_id,settlement_network,external_settlement_reference),
  check (settlement_status not in ('evidence_supported','finality_reference','reversed_reference') or evidence_ref is not null)
);

create table if not exists public.setc_insurance_adapter_asset_references (
  insurance_adapter_asset_reference_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  insurance_adapter_system_id uuid not null references public.setc_insurance_adapter_systems(insurance_adapter_system_id),
  insurance_entity_type text not null check (insurance_entity_type in ('risk_object','policy','coverage','claim','loss_event','other')),
  insurance_entity_reference text not null,
  asset_domain text not null check (asset_domain in ('logistics','procurement','inventory','facility','vehicle','cargo','infrastructure','energy','health','other')),
  external_asset_reference text not null,
  relationship_type text not null check (relationship_type in ('insured_asset','subject_of_risk','claim_subject','coverage_subject','benefit_subject','reference','other')),
  relationship_status text not null default 'unverified' check (relationship_status in ('unverified','mapped','evidence_supported','verified_reference','superseded','void')),
  evidence_ref text,
  created_at timestamptz not null default now(),
  unique(insurance_adapter_system_id,insurance_entity_type,insurance_entity_reference,asset_domain,external_asset_reference,relationship_type),
  check (relationship_status not in ('evidence_supported','verified_reference') or evidence_ref is not null)
);

create table if not exists public.setc_insurance_adapter_intelligence_references (
  insurance_adapter_intelligence_reference_id uuid primary key default gen_random_uuid(),
  organization_oid text not null references public.setc_organizations(oid),
  insurance_adapter_system_id uuid not null references public.setc_insurance_adapter_systems(insurance_adapter_system_id),
  intelligence_artifact_type text not null check (intelligence_artifact_type in ('portfolio_snapshot','metric','aggregation','scenario','scenario_result','model_output','explanation','report','other')),
  intelligence_artifact_reference text not null,
  external_context_type text not null,
  external_context_reference text not null,
  usage_class text not null default 'decision_support' check (usage_class in ('decision_support','reporting_reference','workflow_context','research','other')),
  evidence_ref text,
  created_at timestamptz not null default now(),
  unique(insurance_adapter_system_id,intelligence_artifact_type,intelligence_artifact_reference,external_context_type,external_context_reference)
);

create index if not exists idx_ins_adapter_binding_org on public.setc_insurance_adapter_bindings(organization_oid);
create index if not exists idx_ins_adapter_binding_system on public.setc_insurance_adapter_bindings(insurance_adapter_system_id);
create index if not exists idx_ins_adapter_event_binding on public.setc_insurance_adapter_events(insurance_adapter_binding_id);
create index if not exists idx_ins_adapter_event_org on public.setc_insurance_adapter_events(organization_oid);
create index if not exists idx_ins_adapter_event_system on public.setc_insurance_adapter_events(insurance_adapter_system_id);
create index if not exists idx_ins_adapter_checkpoint_org on public.setc_insurance_adapter_checkpoints(organization_oid);
create index if not exists idx_ins_adapter_checkpoint_system on public.setc_insurance_adapter_checkpoints(insurance_adapter_system_id);
create index if not exists idx_ins_adapter_error_event on public.setc_insurance_adapter_errors(insurance_adapter_event_id);
create index if not exists idx_ins_adapter_error_org on public.setc_insurance_adapter_errors(organization_oid);
create index if not exists idx_ins_adapter_error_system on public.setc_insurance_adapter_errors(insurance_adapter_system_id);
create index if not exists idx_ins_adapter_settlement_org on public.setc_insurance_adapter_settlement_references(organization_oid);
create index if not exists idx_ins_adapter_settlement_system on public.setc_insurance_adapter_settlement_references(insurance_adapter_system_id);
create index if not exists idx_ins_adapter_asset_org on public.setc_insurance_adapter_asset_references(organization_oid);
create index if not exists idx_ins_adapter_asset_system on public.setc_insurance_adapter_asset_references(insurance_adapter_system_id);
create index if not exists idx_ins_adapter_intel_org on public.setc_insurance_adapter_intelligence_references(organization_oid);
create index if not exists idx_ins_adapter_intel_system on public.setc_insurance_adapter_intelligence_references(insurance_adapter_system_id);

alter table public.setc_insurance_adapter_systems enable row level security;
alter table public.setc_insurance_adapter_bindings enable row level security;
alter table public.setc_insurance_adapter_events enable row level security;
alter table public.setc_insurance_adapter_checkpoints enable row level security;
alter table public.setc_insurance_adapter_errors enable row level security;
alter table public.setc_insurance_adapter_settlement_references enable row level security;
alter table public.setc_insurance_adapter_asset_references enable row level security;
alter table public.setc_insurance_adapter_intelligence_references enable row level security;

revoke all privileges on public.setc_insurance_adapter_systems,public.setc_insurance_adapter_bindings,public.setc_insurance_adapter_events,public.setc_insurance_adapter_checkpoints,public.setc_insurance_adapter_errors,public.setc_insurance_adapter_settlement_references,public.setc_insurance_adapter_asset_references,public.setc_insurance_adapter_intelligence_references from anon,authenticated;
grant all privileges on public.setc_insurance_adapter_systems,public.setc_insurance_adapter_bindings,public.setc_insurance_adapter_events,public.setc_insurance_adapter_checkpoints,public.setc_insurance_adapter_errors,public.setc_insurance_adapter_settlement_references,public.setc_insurance_adapter_asset_references,public.setc_insurance_adapter_intelligence_references to service_role;

comment on table public.setc_insurance_adapter_settlement_references is 'External settlement provenance only. A database status does not independently establish bank, Source Coin, WIM, treasury or other settlement finality.';
comment on table public.setc_insurance_adapter_asset_references is 'Cross-domain asset references only. Records do not independently establish title, insurable interest, coverage, valuation or claims entitlement.';