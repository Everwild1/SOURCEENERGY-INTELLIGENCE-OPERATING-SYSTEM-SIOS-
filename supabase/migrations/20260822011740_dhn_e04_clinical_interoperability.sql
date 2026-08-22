create table if not exists dhn_clinical.interoperability_exchanges (
  interoperability_exchange_id uuid primary key default gen_random_uuid(),
  clinical_resource_ref_id uuid not null references dhn_clinical.clinical_resource_refs(clinical_resource_ref_id),
  actor_id text not null,
  principal_ref text not null,
  organization_id uuid references dhn_org.organizations(organization_id),
  authorization_decision_id uuid not null references dhn_consent.authorization_decisions(authorization_decision_id),
  standard_family text not null default 'FHIR',
  standard_version text,
  exchange_action text not null check (exchange_action in ('read','search','create','update','transmit','receive')),
  purpose text not null,
  endpoint_ref text,
  payload_location_ref text,
  integrity_digest text,
  status text not null default 'authorized' check (status in ('authorized','submitted','completed','failed','denied')),
  correlation_id text not null,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists idx_dhn_clinical_resource_actor on dhn_clinical.clinical_resource_refs(actor_id);
create index if not exists idx_dhn_clinical_resource_org on dhn_clinical.clinical_resource_refs(organization_id);
create index if not exists idx_dhn_exchange_resource on dhn_clinical.interoperability_exchanges(clinical_resource_ref_id);
create index if not exists idx_dhn_exchange_actor_time on dhn_clinical.interoperability_exchanges(actor_id, created_at desc);
create index if not exists idx_dhn_exchange_org on dhn_clinical.interoperability_exchanges(organization_id);
create index if not exists idx_dhn_exchange_authz on dhn_clinical.interoperability_exchanges(authorization_decision_id);
create index if not exists idx_dhn_exchange_correlation on dhn_clinical.interoperability_exchanges(correlation_id);
alter table dhn_clinical.interoperability_exchanges enable row level security;
revoke all privileges on dhn_clinical.interoperability_exchanges from public, anon, authenticated;
grant all privileges on dhn_clinical.interoperability_exchanges to service_role;
alter default privileges in schema dhn_clinical revoke all on tables from anon, authenticated;
