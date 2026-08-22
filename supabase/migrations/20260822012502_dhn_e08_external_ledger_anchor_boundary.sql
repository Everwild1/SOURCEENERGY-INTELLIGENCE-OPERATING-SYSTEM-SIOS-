create table if not exists dhn_attestation.ledger_anchor_requests (
  ledger_anchor_request_id uuid primary key default gen_random_uuid(),
  attestation_export_id uuid not null references dhn_attestation.attestation_exports(attestation_export_id),
  ledger_network text not null,
  anchor_digest text not null,
  anchor_protocol_version text not null default 'dhn-ledger-anchor-v1',
  status text not null default 'prepared' check (status in ('prepared','submitted','confirmed','failed','cancelled')),
  transaction_reference text,
  block_reference text,
  requested_by text not null,
  correlation_id text not null,
  submission_metadata jsonb not null default '{}'::jsonb,
  requested_at timestamptz not null default now(),
  submitted_at timestamptz,
  confirmed_at timestamptz,
  unique(attestation_export_id, ledger_network, anchor_digest),
  check (transaction_reference is null or length(transaction_reference) <= 512),
  check (block_reference is null or length(block_reference) <= 512)
);
create index if not exists idx_dhn_anchor_status on dhn_attestation.ledger_anchor_requests(status, requested_at desc);
create index if not exists idx_dhn_anchor_export on dhn_attestation.ledger_anchor_requests(attestation_export_id);
create index if not exists idx_dhn_anchor_correlation on dhn_attestation.ledger_anchor_requests(correlation_id);
alter table dhn_attestation.ledger_anchor_requests enable row level security;
revoke all privileges on dhn_attestation.ledger_anchor_requests from public, anon, authenticated;
grant all privileges on dhn_attestation.ledger_anchor_requests to service_role;
alter table dhn_attestation.attestation_exports add constraint attestation_exports_ledger_privacy_boundary check (export_class <> 'ledger_anchor' or (disclosure_profile = 'privacy_minimized_v1' and not (export_payload ?| array['actor_id','principal_ref','patient_id','health_credential_id','cardiac_credential_id','clinical_resource_ref_id','storage_object_ref','payload_location_ref','ecg','waveform','samples','raw_payload','biometric_template']))) not valid;
alter table dhn_attestation.attestation_exports validate constraint attestation_exports_ledger_privacy_boundary;
