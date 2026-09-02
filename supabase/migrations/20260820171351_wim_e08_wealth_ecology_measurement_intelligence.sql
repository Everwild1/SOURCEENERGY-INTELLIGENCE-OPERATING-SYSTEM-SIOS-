create table if not exists wim.impact_metric_registry (
  metric_code text primary key,
  metric_name text not null,
  metric_family text not null check (metric_family in ('jobs','local_supplier_participation','sme_revenue','diaspora_capital','regional_trade','knowledge_transfer','productive_capacity','community_wealth','tax_base','environmental_impact')),
  default_unit text,
  methodology_version text not null,
  description text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table wim.impact_metrics
  add column if not exists measurement_kind text not null default 'estimate' check (measurement_kind in ('estimate','observed','verified')),
  add column if not exists registry_metric_code text references wim.impact_metric_registry(metric_code) on delete restrict,
  add column if not exists source_event_reference text,
  add column if not exists deduplication_key text,
  add column if not exists confidence_score numeric check (confidence_score is null or (confidence_score >= 0 and confidence_score <= 1)),
  add column if not exists corrected_from_impact_metric_id uuid references wim.impact_metrics(id) on delete restrict,
  add column if not exists status text not null default 'active' check (status in ('active','superseded','withdrawn'));

create unique index if not exists uq_wim_impact_dedup_active on wim.impact_metrics(deduplication_key) where deduplication_key is not null and status='active';
create index if not exists idx_wim_impact_metric_code on wim.impact_metrics(registry_metric_code,status);
create index if not exists idx_wim_impact_transaction on wim.impact_metrics(transaction_id);
create index if not exists idx_wim_impact_project on wim.impact_metrics(commercialization_project_id);

create table if not exists wim.impact_metric_corrections (
  id uuid primary key default gen_random_uuid(),
  impact_metric_id uuid not null references wim.impact_metrics(id) on delete cascade,
  correction_type text not null,
  prior_state jsonb not null,
  corrected_state jsonb not null,
  reason text not null,
  evidence_reference text,
  created_at timestamptz not null default now()
);

create table if not exists wim.intelligence_projections (
  id uuid primary key default gen_random_uuid(),
  projection_type text not null check (projection_type in ('market','research','commercialization','impact','organization')),
  subject_reference text not null,
  projection_version text not null,
  payload jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(projection_type,subject_reference,projection_version)
);

alter table wim.impact_metric_registry enable row level security;
alter table wim.impact_metric_corrections enable row level security;
alter table wim.intelligence_projections enable row level security;
revoke all on wim.impact_metric_registry, wim.impact_metric_corrections, wim.intelligence_projections from anon, authenticated;
grant all on wim.impact_metric_registry, wim.impact_metric_corrections, wim.intelligence_projections to service_role;

create or replace function wim.enforce_impact_metric()
returns trigger
language plpgsql
as $$
declare
  registry_methodology text;
begin
  if new.registry_metric_code is null then
    new.registry_metric_code := new.metric_code;
  end if;
  select methodology_version into registry_methodology from wim.impact_metric_registry where metric_code = new.registry_metric_code and active=true;
  if registry_methodology is null then
    raise exception 'impact metric must resolve to active registry definition';
  end if;
  if new.methodology_version is null or btrim(new.methodology_version) = '' then
    raise exception 'impact metric requires methodology version';
  end if;
  if new.methodology_version <> registry_methodology then
    raise exception 'impact metric methodology version must match active registry';
  end if;
  if new.evidence_reference is null or btrim(new.evidence_reference) = '' then
    raise exception 'impact metric requires evidence reference';
  end if;
  if new.measurement_kind='verified' and (new.confidence_score is null or new.confidence_score < 0.8) then
    raise exception 'verified metric requires confidence_score >= 0.8';
  end if;
  if new.transaction_id is null and new.commercialization_project_id is null then
    raise exception 'impact metric requires transaction or commercialization project';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_wim_impact_metric on wim.impact_metrics;
create trigger trg_wim_impact_metric
before insert or update on wim.impact_metrics
for each row execute function wim.enforce_impact_metric();

create or replace function wim.audit_impact_correction()
returns trigger
language plpgsql
as $$
begin
  if new.corrected_from_impact_metric_id is not null and new.corrected_from_impact_metric_id = new.id then
    raise exception 'impact metric cannot correct itself';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_wim_impact_correction_guard on wim.impact_metrics;
create trigger trg_wim_impact_correction_guard
before insert or update on wim.impact_metrics
for each row execute function wim.audit_impact_correction();

insert into wim.impact_metric_registry(metric_code,metric_name,metric_family,default_unit,methodology_version,description) values
('WEM-JOBS-001','Jobs Created or Sustained','jobs','jobs','1.0','Employment effect attributable to a WIM transaction or commercialization project.'),
('WEM-LSP-001','Local Supplier Participation','local_supplier_participation','percent','1.0','Share of eligible spend or participation attributable to local suppliers.'),
('WEM-SME-REV-001','SME Revenue Activated','sme_revenue','currency','1.0','Revenue activated for qualifying SME participants.'),
('WEM-DIASPORA-001','Diaspora Capital Activated','diaspora_capital','currency','1.0','Diaspora-originating capital mobilized through a governed commercial pathway.'),
('WEM-REGTRADE-001','Regional Trade Value','regional_trade','currency','1.0','Value of trade occurring across governed regional market corridors.'),
('WEM-KT-001','Knowledge Transfer Events','knowledge_transfer','events','1.0','Documented knowledge-transfer events tied to commercialization or trade.'),
('WEM-PCAP-001','Productive Capacity Change','productive_capacity','index','1.0','Measured change in productive capacity using the declared methodology.'),
('WEM-CW-001','Community Wealth Effect','community_wealth','currency','1.0','Measured community wealth effect supported by evidence and declared methodology.'),
('WEM-TAX-001','Tax Base Expansion','tax_base','currency','1.0','Documented incremental tax-base effect where legally and methodologically supportable.'),
('WEM-ENV-001','Environmental Impact','environmental_impact','index','1.0','Environmental outcome measured under a versioned methodology.')
on conflict (metric_code) do update set metric_name=excluded.metric_name, metric_family=excluded.metric_family, default_unit=excluded.default_unit, methodology_version=excluded.methodology_version, description=excluded.description, active=true, updated_at=now();

comment on table wim.impact_metric_registry is 'Versioned Wealth Ecology metric definitions. Registry and measurements do not create financial, legal, or economic authority.';
comment on column wim.impact_metrics.measurement_kind is 'Explicitly distinguishes estimate, observed and verified measurements.';
comment on column wim.impact_metrics.deduplication_key is 'Optional anti-double-counting key; only one active metric may occupy a deduplication key.';
comment on table wim.impact_metric_corrections is 'Append-only correction evidence preserving impact-measurement history.';
