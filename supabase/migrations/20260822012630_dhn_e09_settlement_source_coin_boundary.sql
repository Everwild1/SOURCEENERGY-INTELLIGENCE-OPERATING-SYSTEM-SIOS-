create table if not exists dhn_integration.settlement_boundary_requests (
  settlement_boundary_request_id uuid primary key default gen_random_uuid(), actor_id text, service_reference text not null,
  economic_basis_type text not null check (economic_basis_type in ('service_completion','benefit_entitlement','invoice','grant','refund','other')),
  economic_basis_reference text not null, eligibility_attestation_id uuid references dhn_attestation.attestations(attestation_id),
  settlement_rail text not null check (settlement_rail in ('fiat_external','source_coin')), requested_amount numeric, currency_code text,
  idempotency_key text not null unique, status text not null default 'prepared' check (status in ('prepared','submitted','confirmed','failed','cancelled','restricted')),
  external_request_reference text, authoritative_confirmation_reference text, correlation_id text not null,
  settlement_metadata jsonb not null default '{}'::jsonb, requested_by text not null, requested_at timestamptz not null default now(), submitted_at timestamptz, confirmed_at timestamptz,
  check (requested_amount is null or requested_amount >= 0), check (currency_code is null or currency_code ~ '^[A-Z0-9]{3,12}$'),
  check (settlement_metadata::text !~* '"(patient_id|actor_id|principal_ref|health_credential_id|cardiac_credential_id|clinical_resource_ref_id|storage_object_ref|payload_location_ref|diagnosis|medication|ecg|waveform|samples|raw_payload|biometric_template|phi)"[[:space:]]*:')
);
create index if not exists idx_dhn_settlement_boundary_actor on dhn_integration.settlement_boundary_requests(actor_id, requested_at desc);
create index if not exists idx_dhn_settlement_boundary_attestation on dhn_integration.settlement_boundary_requests(eligibility_attestation_id);
create index if not exists idx_dhn_settlement_boundary_status on dhn_integration.settlement_boundary_requests(status, requested_at desc);
create index if not exists idx_dhn_settlement_boundary_correlation on dhn_integration.settlement_boundary_requests(correlation_id);
alter table dhn_integration.settlement_boundary_requests enable row level security;
revoke all privileges on dhn_integration.settlement_boundary_requests from public, anon, authenticated;
grant all privileges on dhn_integration.settlement_boundary_requests to service_role;
alter table dhn_integration.settlement_references add constraint settlement_references_metadata_privacy_boundary check (metadata::text !~* '"(patient_id|principal_ref|health_credential_id|cardiac_credential_id|clinical_resource_ref_id|storage_object_ref|payload_location_ref|diagnosis|medication|ecg|waveform|samples|raw_payload|biometric_template|phi)"[[:space:]]*:') not valid;
alter table dhn_integration.settlement_references validate constraint settlement_references_metadata_privacy_boundary;
