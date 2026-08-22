alter table setc_heartbeat.audit_attestations
  add column if not exists device_attestation_id uuid references setc_heartbeat.device_attestations(device_attestation_id),
  add column if not exists device_integrity_digest text,
  add column if not exists device_trust_policy_version text;

-- Safe because this migration was introduced before production audit attestations existed.
alter table setc_heartbeat.audit_attestations
  alter column device_attestation_id set not null,
  alter column device_integrity_digest set not null,
  alter column device_trust_policy_version set not null;

create index if not exists idx_hb_audit_device_attestation
  on setc_heartbeat.audit_attestations(device_attestation_id);

comment on column setc_heartbeat.audit_attestations.device_attestation_id is 'Ledger-safe reference to device trust evidence used for the authenticated action.';
comment on column setc_heartbeat.audit_attestations.device_integrity_digest is 'Integrity digest only; no raw sensor or cardiac material.';
comment on column setc_heartbeat.audit_attestations.device_trust_policy_version is 'Version of the device-trust policy evaluated before assertion issuance.';