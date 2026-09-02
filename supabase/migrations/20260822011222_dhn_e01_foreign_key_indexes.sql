create index if not exists idx_dhn_identity_mappings_health_credential on dhn_identity.identity_mappings(health_credential_id);
create index if not exists idx_dhn_authz_consent on dhn_consent.authorization_decisions(consent_id);
create index if not exists idx_dhn_biometric_health_credential on dhn_biometric.verification_events(health_credential_id);
create index if not exists idx_dhn_biometric_cardiac_credential on dhn_biometric.verification_events(cardiac_credential_id);
create index if not exists idx_dhn_biometric_consent on dhn_biometric.verification_events(consent_id);
create index if not exists idx_dhn_telemetry_consent on dhn_telemetry.telemetry_events(consent_id);
create index if not exists idx_dhn_clinical_organization on dhn_clinical.clinical_resource_refs(organization_id);

