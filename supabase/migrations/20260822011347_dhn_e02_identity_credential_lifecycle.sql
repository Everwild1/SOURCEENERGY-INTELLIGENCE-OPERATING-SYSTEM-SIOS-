alter table dhn_identity.health_credentials
  add constraint health_credentials_revocation_consistency
  check ((status = 'revoked' and revoked_at is not null) or (status <> 'revoked'));

create index if not exists idx_dhn_identity_mappings_actor
  on dhn_identity.identity_mappings(actor_id);

create index if not exists idx_dhn_biometric_actor_verified
  on dhn_biometric.verification_events(actor_id, verified_at desc);

create index if not exists idx_dhn_audit_actor_time
  on dhn_audit.audit_events(actor_id, occurred_at desc);
