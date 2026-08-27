create index if not exists idx_dhn_adapter_health_credential on dhn_biometric.adapter_evaluations(health_credential_id);
drop index if exists dhn_clinical.idx_dhn_clinical_resource_actor;
drop index if exists dhn_clinical.idx_dhn_clinical_resource_org;
